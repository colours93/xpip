import Cocoa
import ApplicationServices
import UserNotifications

class XPipDaemon {
    private struct PipTracker {
        var axWindow: AXUIElement
        var source: String
        var kind: PipWindowKind
        var contentInsets: NSEdgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        var wasOnPip = false
        var interacting = false
        var lastDodgeTime = Date.distantPast
        var animating = false
        var animStart = CGPoint.zero
        var animEnd = CGPoint.zero
        var animCurrentPos = CGPoint.zero
        var animStartMach: UInt64 = 0
        var animSize = CGSize.zero
        var animTimer: DispatchSourceTimer?
        var border: RGBBorder
    }

    // MARK: - Audio State (per-PiP volume control)

    struct AudioState {
        var reportedVolume: Double = 1.0
        var reportedMuted: Bool = false
        var desiredVolume: Double? = nil
        var desiredMuted: Bool? = nil
        var lastReportTime: Date = .distantPast
        var hasReported: Bool = false
    }

    var audioStates: [String: AudioState] = [:]

    func audioStateForSource(_ source: String) -> AudioState? {
        guard let state = audioStates[source], state.hasReported else { return nil }
        return state
    }

    func setDesiredVolume(_ volume: Double, source: String) {
        if audioStates[source] == nil {
            audioStates[source] = AudioState()
        }
        audioStates[source]?.desiredVolume = max(0, min(1, volume))
    }

    func setDesiredMuted(_ muted: Bool, source: String) {
        if audioStates[source] == nil {
            audioStates[source] = AudioState()
        }
        audioStates[source]?.desiredMuted = muted
    }

    func switchAudioTo(source: String) {
        for key in audioStates.keys {
            if key == source {
                audioStates[key]?.desiredMuted = false
                audioStates[key]?.desiredVolume = 1.0
            } else {
                audioStates[key]?.desiredMuted = true
            }
        }
    }

    func reportAudio(source: String, volume: Double, muted: Bool) -> (volume: Double, muted: Bool) {
        if audioStates[source] == nil {
            audioStates[source] = AudioState()
        }
        audioStates[source]?.reportedVolume = volume
        audioStates[source]?.reportedMuted = muted
        audioStates[source]?.lastReportTime = Date()
        audioStates[source]?.hasReported = true

        // Check convergence: clear desired if it matches reported
        if let dv = audioStates[source]?.desiredVolume, abs(dv - volume) < 0.01 {
            audioStates[source]?.desiredVolume = nil
        }
        if let dm = audioStates[source]?.desiredMuted, dm == muted {
            audioStates[source]?.desiredMuted = nil
        }

        let retVolume = audioStates[source]?.desiredVolume ?? volume
        let retMuted = audioStates[source]?.desiredMuted ?? muted
        return (retVolume, retMuted)
    }

    func clearAudioState(source: String) {
        audioStates.removeValue(forKey: source)
    }

    // MARK: - Browser-hosted Content Sessions

    struct ContentSession {
        let name: String
        let source: String
        let startedAt: Date
    }

    private var activeContentSessions: [String: [String: ContentSession]] = [:]

    func setContentSessionActive(_ name: String, source: String, active: Bool) {
        if active {
            if activeContentSessions[source] == nil {
                activeContentSessions[source] = [:]
            }
            activeContentSessions[source]?[name] = ContentSession(name: name, source: source, startedAt: Date())
        } else {
            activeContentSessions[source]?.removeValue(forKey: name)
            if activeContentSessions[source]?.isEmpty == true {
                activeContentSessions.removeValue(forKey: source)
            }
        }
    }

    func isContentSessionActive(_ name: String) -> Bool {
        activeContentSessions.values.contains { $0[name] != nil }
    }

    func isContentSessionActiveOnSource(_ name: String, source: String) -> Bool {
        activeContentSessions[source]?[name] != nil
    }

    func activeContentSessionNames(for source: String? = nil) -> [String] {
        if let source = source {
            return Array((activeContentSessions[source] ?? [:]).keys).sorted()
        }
        return Array(Set(activeContentSessions.values.flatMap { $0.keys })).sorted()
    }

    // MARK: - Active Games (multi-PiP)

    struct ActiveGame {
        let game: MiniGame
        let border: RGBBorder
        let name: String
        let paddleMode: Bool
    }

    var activeGames: [PipID: ActiveGame] = [:]
    var hasActiveGames: Bool { !activeGames.isEmpty }

    func isGameActive(_ name: String) -> Bool {
        activeGames.values.contains { $0.name == name }
    }

    func isGameActiveOnSource(_ name: String, source: String) -> Bool {
        activeGames.contains { (id, entry) in
            entry.name == name && trackers[id]?.source == source
        }
    }

    func isBounceActive(paddleMode: Bool) -> Bool {
        activeGames.values.contains { $0.name == "bounce" && $0.paddleMode == paddleMode }
    }

    func sourceForPipID(_ id: PipID) -> String? {
        trackers[id]?.source
    }

    func stopAllGames() {
        for (id, entry) in activeGames {
            entry.game.stop()
            entry.border.tilt(0)
            entry.border.hide()
            activeGames.removeValue(forKey: id)
        }
    }

    func stopGamesForSource(_ source: String) {
        for (id, entry) in activeGames {
            if trackers[id]?.source == source {
                entry.game.stop()
                entry.border.tilt(0)
                entry.border.hide()
                activeGames.removeValue(forKey: id)
            }
        }
    }

    func isBounceActiveOnSource(paddleMode: Bool, source: String) -> Bool {
        activeGames.contains { (id, entry) in
            entry.name == "bounce" && entry.paddleMode == paddleMode && trackers[id]?.source == source
        }
    }

    // MARK: - State

    private var trackers: [PipID: PipTracker] = [:]

    private let animDuration: Double = 0.18
    private var lastDiscoveryTime = Date.distantPast
    private let discoveryInterval: TimeInterval = 0.5
    private var tickTimer: DispatchSourceTimer?
    private static var timebaseInfo: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    private var accessibilityPollTimer: DispatchSourceTimer?
    private var onboardingWindow: OnboardingWindow?

    func start() {
        if AXIsProcessTrusted() {
            finishStart()
        } else {
            print("Accessibility permission not granted — waiting for grant…")
            let onboarding = OnboardingWindow()
            onboardingWindow = onboarding
            onboarding.show()
            startAccessibilityPoll()
        }
    }

    private func startAccessibilityPoll() {
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + 3, repeating: 3)
        t.setEventHandler { [weak self] in
            if AXIsProcessTrusted() {
                self?.accessibilityPollTimer?.cancel()
                self?.accessibilityPollTimer = nil
                self?.onboardingWindow = nil
                print("Accessibility permission granted")
                self?.finishStart()
            }
        }
        t.resume()
        accessibilityPollTimer = t
    }

    private func finishStart() {
        installHotkey()
        print("XPip daemon started")

        let t = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        t.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .microseconds(500))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        tickTimer = t
    }

    private func showAccessibilityNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "XPip"
            content.body = "Accessibility access required. Opening System Settings…"
            content.sound = .default
            let request = UNNotificationRequest(identifier: "accessibility", content: content, trigger: nil)
            center.add(request)
        }
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func quickCheck(_ element: AXUIElement, source: String, kind: PipWindowKind) -> PipWindowInfo? {
        var posVal: AnyObject?
        var sizeVal: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posVal) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeVal) == .success
        else { return nil }

        var pos = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posVal as! AXValue, .cgPoint, &pos),
              AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
        else { return nil }

        return PipWindowInfo(bounds: CGRect(origin: pos, size: size), axWindow: element, source: source, kind: kind)
    }

    // MARK: - Tick

    private func tick() {
        // Clean up stale audio states (no report in 5+ seconds)
        let audioNow = Date()
        for (source, state) in audioStates {
            if state.hasReported && audioNow.timeIntervalSince(state.lastReportTime) > 5 {
                audioStates.removeValue(forKey: source)
            }
        }

        // Clean up ended games
        for (id, entry) in activeGames where !entry.game.active {
            entry.border.tilt(0)
            entry.border.hide()
            activeGames.removeValue(forKey: id)
        }

        // Update cross-PiP bounds for active games
        if activeGames.count > 1 {
            updateOtherPipBounds()
        }

        // Skip all dodge logic while any PiP is animating
        let anyAnimating = trackers.values.contains { $0.animating }
        if anyAnimating { return }

        guard let event = CGEvent(source: nil) else { return }
        let mousePos = event.location

        // Reconcile trackers every discoveryInterval
        let now = Date()
        if now.timeIntervalSince(lastDiscoveryTime) >= discoveryInterval {
            lastDiscoveryTime = now
            let found = findAllPipWindows()
            let foundIDs = Set(found.map { $0.id })
            let documentSources = Set(found.filter { $0.kind == .document }.map { $0.source })

            // Remove stale trackers
            for id in trackers.keys where !foundIDs.contains(id) {
                trackers[id]?.animTimer?.cancel()
                trackers[id]?.border.hide()
                trackers.removeValue(forKey: id)
            }

            for source in activeContentSessions.keys where !documentSources.contains(source) {
                activeContentSessions.removeValue(forKey: source)
            }

            // Add new trackers + refresh content insets for existing ones
            for pip in found {
                if trackers[pip.id] == nil {
                    // PIPAgent (Safari) sits at kCGUtilityWindowLevel (19), far above
                    // kCGFloatingWindowLevel (3) where Chrome PiP lives.  Place the
                    // behind-pip border one level below the actual PiP window.
                    let level: NSWindow.Level? = pip.source == "safari"
                        ? NSWindow.Level(rawValue: 18)  // utility - 1
                        : nil                           // default: floating - 1
                    let border = RGBBorder(behindPip: true, windowLevel: level)
                    trackers[pip.id] = PipTracker(axWindow: pip.axWindow, source: pip.source, kind: pip.kind,
                                                  contentInsets: pip.contentInsets, border: border)
                } else {
                    trackers[pip.id]?.kind = pip.kind
                    trackers[pip.id]?.contentInsets = pip.contentInsets
                }
            }
        }

        // Process each tracked PiP
        for (id, var tracker) in trackers {
            // Skip PiPs that are running a game — the game owns border and position
            if activeGames[id] != nil {
                trackers[id] = tracker
                continue
            }

            if tracker.kind == .document, activeContentSessions[tracker.source] != nil {
                tracker.border.hide()
                trackers[id] = tracker
                continue
            }

            guard let pip = quickCheck(tracker.axWindow, source: tracker.source, kind: tracker.kind) else {
                // quickCheck failed — PiP likely closed; will be cleaned up next reconcile
                tracker.border.hide()
                trackers[id] = tracker
                continue
            }

            if settings.glow {
                let borderRect = borderRectForGlow(bounds: pip.bounds, contentInsets: tracker.contentInsets, source: tracker.source)
                tracker.border.show(around: borderRect)
            } else {
                tracker.border.hide()
            }

            guard settings.enabled else {
                trackers[id] = tracker
                continue
            }

            let onPip = pip.bounds.contains(mousePos)

            if onPip && !tracker.wasOnPip {
                if isInPipCorner(mousePos: mousePos, pipBounds: pip.bounds) {
                    tracker.interacting = true
                } else {
                    tracker.interacting = false
                    tracker.wasOnPip = onPip
                    trackers[id] = tracker
                    dodgeIfReady(id: id, pip: pip, mousePos: mousePos)
                    continue
                }
            }

            if !onPip && tracker.wasOnPip {
                tracker.interacting = false
            }

            tracker.wasOnPip = onPip
            trackers[id] = tracker
        }
    }

    // MARK: - Animation

    private func stepAnimation(id: PipID) {
        guard var tracker = trackers[id] else { return }

        let elapsed = mach_absolute_time() - tracker.animStartMach
        let info = Self.timebaseInfo
        let sec = Double(elapsed * UInt64(info.numer) / UInt64(info.denom)) / 1_000_000_000
        let t = min(sec / animDuration, 1.0)
        let ease = 1.0 - pow(1.0 - t, 3.0)

        let x = tracker.animStart.x + (tracker.animEnd.x - tracker.animStart.x) * CGFloat(ease)
        let y = tracker.animStart.y + (tracker.animEnd.y - tracker.animStart.y) * CGFloat(ease)
        var pos = CGPoint(x: x, y: y)
        tracker.animCurrentPos = pos

        if let val = AXValueCreate(.cgPoint, &pos) {
            AXUIElementSetAttributeValue(tracker.axWindow, kAXPositionAttribute as CFString, val)
        }
        if settings.glow {
            let fullRect = CGRect(origin: pos, size: tracker.animSize)
            let rect = borderRectForGlow(bounds: fullRect, contentInsets: tracker.contentInsets, source: tracker.source)
            tracker.border.show(around: rect)
        } else {
            tracker.border.hide()
        }

        if t >= 1.0 {
            tracker.animTimer?.cancel()
            tracker.animTimer = nil
            tracker.animating = false
        }

        trackers[id] = tracker
    }

    private func dodgeIfReady(id: PipID, pip: PipWindowInfo, mousePos: CGPoint) {
        guard var tracker = trackers[id] else { return }

        let now = Date()
        guard now.timeIntervalSince(tracker.lastDodgeTime) >= settings.cooldown else { return }

        let screen = getScreenFrame()
        let target = getFurthestCorner(from: mousePos, windowSize: pip.bounds.size, screen: screen)

        let alreadyThere = abs(pip.bounds.origin.x - target.x) < 30
            && abs(pip.bounds.origin.y - target.y) < 30
        guard !alreadyThere else { return }

        tracker.animStart = pip.bounds.origin
        tracker.animEnd = target
        tracker.animSize = pip.bounds.size
        tracker.animCurrentPos = pip.bounds.origin
        tracker.animStartMach = mach_absolute_time()
        tracker.animating = true
        tracker.lastDodgeTime = now

        tracker.animTimer?.cancel()
        let t = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        t.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(2))
        t.setEventHandler { [weak self] in self?.stepAnimation(id: id) }
        tracker.animTimer = t
        trackers[id] = tracker
        t.resume()
    }

    // MARK: - Game Toggle (multi-PiP)

    /// Toggle a game on a specific source PiP, all PiPs, or first available.
    func toggleGame(_ name: String, source: String? = nil, paddleMode: Bool = false) {
        if source == "both" {
            toggleGameBoth(name, paddleMode: paddleMode)
            return
        }

        if let source, !activeContentSessions[source, default: [:]].isEmpty {
            print("Game '\(name)' not started: content session active for source '\(source)'")
            return
        }

        // Find target PiP
        let pip: PipWindowInfo?
        if let source = source {
            pip = findPipWindow(source: source)
        } else {
            pip = findPipWindow()
        }
        guard let pip = pip else {
            print("Game '\(name)' not started: no PiP window found\(source.map { " for source '\($0)'" } ?? "")")
            return
        }

        // If game already running on this PiP, stop it
        if let existing = activeGames[pip.id] {
            existing.game.stop()
            existing.border.tilt(0)
            existing.border.hide()
            activeGames.removeValue(forKey: pip.id)
            return
        }

        // Create new game instance
        guard let game = Games.create(name) else { return }
        if let bounce = game as? BounceGame {
            bounce.paddleMode = paddleMode
        }

        let border = RGBBorder()
        trackers[pip.id]?.border.hide()
        game.start(screen: getScreenFrame(), pip: pip, border: border)
        activeGames[pip.id] = ActiveGame(game: game, border: border, name: name, paddleMode: paddleMode)

        updateOtherPipBounds()
    }

    /// Toggle a game on ALL available PiPs simultaneously.
    private func toggleGameBoth(_ name: String, paddleMode: Bool) {
        // If this game is active on any PiP, stop all instances
        let existingIDs = activeGames.filter { $0.value.name == name }.map { $0.key }
        if !existingIDs.isEmpty {
            for id in existingIDs {
                activeGames[id]?.game.stop()
                activeGames[id]?.border.tilt(0)
                activeGames[id]?.border.hide()
                activeGames.removeValue(forKey: id)
            }
            return
        }

        // Start on all available PiPs
        let allPips = findAllPipWindows().filter { $0.kind == .video }
        if allPips.isEmpty {
            print("Game '\(name)' not started (both): no PiP windows found")
            return
        }
        for pip in allPips {
            if activeGames[pip.id] != nil { continue }

            guard let game = Games.create(name) else { continue }
            if let bounce = game as? BounceGame {
                bounce.paddleMode = paddleMode
            }

            let border = RGBBorder()
            trackers[pip.id]?.border.hide()
            game.start(screen: getScreenFrame(), pip: pip, border: border)
            activeGames[pip.id] = ActiveGame(game: game, border: border, name: name, paddleMode: paddleMode)
        }

        updateOtherPipBounds()
    }

    func hasVideoPip(forSource source: String? = nil) -> Bool {
        if let source {
            return findAllPipWindows().contains { $0.source == source && $0.kind == .video }
        }
        return findAllPipWindows().contains { $0.kind == .video }
    }

    func hasDocumentPip(forSource source: String? = nil) -> Bool {
        if let source {
            return findAllPipWindows().contains { $0.source == source && $0.kind == .document }
        }
        return findAllPipWindows().contains { $0.kind == .document }
    }

    /// Update each active game's otherActivePipBounds for cross-PiP collision.
    private func updateOtherPipBounds() {
        for (id, entry) in activeGames {
            if let base = entry.game as? GameBase {
                base.otherActivePipBounds = activeGames
                    .filter { $0.key != id }
                    .map { $0.value.game.lastBounds }
            }
        }
    }

    /// Rect to use for the glow border so it hugs the visible PiP content.
    /// Safari: AX window bounds include the collapsed "tab" area; content insets (from AX children)
    /// give the visible video rect. Use at least minPad so we never get an invalid rect.
    /// Chrome: constant inset only (no content insets).
    private func borderRectForGlow(bounds: CGRect, contentInsets: NSEdgeInsets, source: String) -> CGRect {
        let minPad: CGFloat = 14
        let insets: NSEdgeInsets
        if source == "safari" {
            insets = NSEdgeInsets(
                top: max(minPad, contentInsets.top),
                left: max(minPad, contentInsets.left),
                bottom: max(minPad, contentInsets.bottom),
                right: max(minPad, contentInsets.right))
        } else {
            insets = NSEdgeInsets(top: minPad, left: minPad, bottom: minPad, right: minPad)
        }
        var rect = bounds.insetBy(insets)
        let minSide: CGFloat = 20
        if rect.width < minSide || rect.height < minSide {
            rect = bounds.insetBy(NSEdgeInsets(top: minPad, left: minPad, bottom: minPad, right: minPad))
        }
        return rect
    }

    private func isInPipCorner(mousePos: CGPoint, pipBounds: CGRect) -> Bool {
        let cs = min(settings.cornerSize, min(pipBounds.width, pipBounds.height) / 2)
        let nearLeft = mousePos.x - pipBounds.minX < cs
        let nearRight = pipBounds.maxX - mousePos.x < cs
        let nearTop = mousePos.y - pipBounds.minY < cs
        let nearBottom = pipBounds.maxY - mousePos.y < cs
        return (nearLeft || nearRight) && (nearTop || nearBottom)
    }
}
