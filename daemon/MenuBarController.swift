import Cocoa

class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()

    // Static items (always present)
    private var dodgeItem: NSMenuItem!
    private var glowItem: NSMenuItem!
    private var accessibilityItem: NSMenuItem!

    // Dynamic section (rebuilt each open)
    private var dynamicStartIndex: Int = 0
    private var dynamicEndIndex: Int = 0

    // Game definitions
    private struct GameDef {
        let label: String
        let name: String
        let paddleMode: Bool
    }

    private let gameDefs: [GameDef] = [
        GameDef(label: "PiPong (1P)", name: "pipong", paddleMode: false),
        GameDef(label: "PiPong (2P)", name: "pipong2", paddleMode: false),
        GameDef(label: "Flappy", name: "flappy", paddleMode: false),
        GameDef(label: "Bounce (Auto)", name: "bounce", paddleMode: false),
        GameDef(label: "Bounce (Paddle)", name: "bounce", paddleMode: true),
        GameDef(label: "Invaders", name: "invaders", paddleMode: false),
        GameDef(label: "Frogger", name: "frogger", paddleMode: false),
        GameDef(label: "Runner", name: "runner", paddleMode: false),
        GameDef(label: "Snake", name: "snake", paddleMode: false),
        GameDef(label: "Breakout", name: "breakout", paddleMode: false),
        GameDef(label: "Asteroids", name: "asteroids", paddleMode: false),
        GameDef(label: "Cursor Hunt", name: "cursorhunt", paddleMode: false),
        GameDef(label: "Doodle Jump", name: "doodlejump", paddleMode: false),
        GameDef(label: "Pac-Man", name: "pacman", paddleMode: false),
        GameDef(label: "Mario", name: "mario", paddleMode: false),
        GameDef(label: "Doom", name: "doom", paddleMode: false),
    ]

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                button.image = NSImage(systemSymbolName: "pip", accessibilityDescription: "XPip")
            } else {
                button.title = "XP"
            }
        }

        buildMenu()
        statusItem.menu = menu
        menu.delegate = self
    }

    private func buildMenu() {
        // Title
        let titleItem = NSMenuItem(title: "XPip", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        titleItem.attributedTitle = NSAttributedString(
            string: "XPip",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
        )
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // Dodge toggle
        dodgeItem = NSMenuItem(title: "Dodge", action: #selector(toggleDodge), keyEquivalent: "")
        dodgeItem.target = self
        menu.addItem(dodgeItem)

        // Glow toggle
        glowItem = NSMenuItem(title: "Glow", action: #selector(toggleGlow), keyEquivalent: "")
        glowItem.target = self
        menu.addItem(glowItem)

        menu.addItem(NSMenuItem.separator())

        // Mark where dynamic PiP/game section starts
        dynamicStartIndex = menu.items.count

        // Placeholder — rebuilt on each open
        let placeholder = NSMenuItem(title: "No PiP detected", action: nil, keyEquivalent: "")
        placeholder.isEnabled = false
        menu.addItem(placeholder)

        menu.addItem(NSMenuItem.separator())

        // Mark where dynamic section ends
        dynamicEndIndex = menu.items.count

        // Accessibility status
        accessibilityItem = NSMenuItem(title: "Accessibility: Checking…", action: nil, keyEquivalent: "")
        accessibilityItem.isEnabled = false
        menu.addItem(accessibilityItem)

        menu.addItem(NSMenuItem.separator())

        // Restart
        let restartItem = NSMenuItem(title: "Restart Daemon", action: #selector(restartDaemon), keyEquivalent: "")
        restartItem.target = self
        menu.addItem(restartItem)

        // Uninstall
        let uninstallItem = NSMenuItem(title: "Uninstall…", action: #selector(uninstallApp), keyEquivalent: "")
        uninstallItem.target = self
        menu.addItem(uninstallItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit XPip", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // Toggle states
        dodgeItem.state = settings.enabled ? .on : .off
        glowItem.state = settings.glow ? .on : .off

        // Rebuild dynamic PiP/game section
        rebuildDynamicSection()

        // Accessibility status
        if AXIsProcessTrusted() {
            accessibilityItem.title = "Accessibility: Granted"
            accessibilityItem.attributedTitle = nil
        } else {
            accessibilityItem.title = "Accessibility: Required"
            accessibilityItem.attributedTitle = NSAttributedString(
                string: "Accessibility: Required",
                attributes: [.foregroundColor: NSColor.systemRed]
            )
        }

        // Dim icon when disabled
        statusItem.button?.alphaValue = settings.enabled ? 1.0 : 0.5
    }

    // MARK: - Dynamic PiP/Game Section

    private func rebuildDynamicSection() {
        // Remove old dynamic items
        while dynamicEndIndex > dynamicStartIndex {
            menu.removeItem(at: dynamicStartIndex)
            dynamicEndIndex -= 1
        }

        let pips = findAllPipWindows()
        let sources = Array(Set(pips.map { $0.source })).sorted()

        if pips.isEmpty {
            // No PiP detected
            let item = NSMenuItem(title: "No PiP detected", action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.attributedTitle = NSAttributedString(
                string: "No PiP detected",
                attributes: [.foregroundColor: NSColor.secondaryLabelColor]
            )
            insertDynamic(item)
            insertDynamic(NSMenuItem.separator())
        } else {
            // Per-PiP items with game submenus
            for source in sources {
                let runningGame = activeGameName(forSource: source)
                var title: String
                if let game = runningGame {
                    title = "\(source.capitalized) PiP — \(game)"
                } else {
                    title = "\(source.capitalized) PiP"
                }

                // Append volume indicator
                if let audioState = daemon.audioStateForSource(source) {
                    let muted = audioState.desiredMuted ?? audioState.reportedMuted
                    if muted {
                        title += " \u{1F507}"
                    } else {
                        let vol = audioState.desiredVolume ?? audioState.reportedVolume
                        let pct = Int(round(vol * 100))
                        title += " \u{1F50A}\(pct)%"
                    }
                }

                let pipItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                if runningGame != nil {
                    pipItem.attributedTitle = NSAttributedString(
                        string: title,
                        attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
                    )
                }
                pipItem.submenu = buildGameSubmenu(source: source)
                insertDynamic(pipItem)
            }

            // "Both PiPs" submenu when 2+ sources
            if sources.count >= 2 {
                insertDynamic(NSMenuItem.separator())

                let bothItem = NSMenuItem(title: "Both PiPs", action: nil, keyEquivalent: "")
                bothItem.submenu = buildGameSubmenu(source: "both")
                insertDynamic(bothItem)
            }

            // "Stop All Games" when any game is active
            if daemon.hasActiveGames {
                insertDynamic(NSMenuItem.separator())
                let stopItem = NSMenuItem(title: "Stop All Games", action: #selector(stopAllGames), keyEquivalent: "")
                stopItem.target = self
                stopItem.attributedTitle = NSAttributedString(
                    string: "Stop All Games",
                    attributes: [.foregroundColor: NSColor.systemRed]
                )
                insertDynamic(stopItem)
            }

            insertDynamic(NSMenuItem.separator())
        }
    }

    private func insertDynamic(_ item: NSMenuItem) {
        menu.insertItem(item, at: dynamicEndIndex)
        dynamicEndIndex += 1
    }

    // MARK: - Game Submenus

    private func buildGameSubmenu(source: String) -> NSMenu {
        let sub = NSMenu()

        // Audio controls
        let reportingSources = daemon.audioStates.filter { $0.value.hasReported }.map { $0.key }.sorted()
        let audioSources: [String] = source == "both" ? reportingSources : (daemon.audioStateForSource(source) != nil ? [source] : [])

        if !audioSources.isEmpty {
            // Compute displayed volume/muted (average for "both", exact for single)
            let currentVol: Double
            let currentMuted: Bool
            if source == "both" {
                let vols = audioSources.compactMap { daemon.audioStateForSource($0) }.map { $0.desiredVolume ?? $0.reportedVolume }
                let mutes = audioSources.compactMap { daemon.audioStateForSource($0) }.map { $0.desiredMuted ?? $0.reportedMuted }
                currentVol = vols.isEmpty ? 1.0 : vols.reduce(0, +) / Double(vols.count)
                currentMuted = !mutes.isEmpty && mutes.allSatisfy { $0 }
            } else {
                let audioState = daemon.audioStateForSource(source)!
                currentVol = audioState.desiredVolume ?? audioState.reportedVolume
                currentMuted = audioState.desiredMuted ?? audioState.reportedMuted
            }
            let pct = Int(round(currentVol * 100))

            // Volume display
            let volLabel = currentMuted ? "\u{1F507} Muted" : "\u{1F50A} Volume: \(pct)%"
            let volItem = NSMenuItem(title: volLabel, action: nil, keyEquivalent: "")
            volItem.isEnabled = false
            sub.addItem(volItem)

            // Mute/Unmute toggle
            let muteTitle = currentMuted ? "Unmute" : "Mute"
            let muteItem = NSMenuItem(title: muteTitle, action: #selector(audioActionClicked(_:)), keyEquivalent: "")
            muteItem.target = self
            muteItem.representedObject = AudioAction(source: source, muted: !currentMuted)
            sub.addItem(muteItem)

            // Volume presets submenu
            let volSubMenu = NSMenu()
            for preset in [25, 50, 75, 100] {
                let presetItem = NSMenuItem(
                    title: "\(preset)%",
                    action: #selector(audioActionClicked(_:)),
                    keyEquivalent: ""
                )
                presetItem.target = self
                presetItem.representedObject = AudioAction(source: source, volume: Double(preset) / 100.0)
                if abs(pct - preset) <= 2 && !currentMuted {
                    presetItem.state = .on
                }
                volSubMenu.addItem(presetItem)
            }
            let volPresetsItem = NSMenuItem(title: "Volume", action: nil, keyEquivalent: "")
            volPresetsItem.submenu = volSubMenu
            sub.addItem(volPresetsItem)

            // Switch Audio Here (only for single source when 2+ sources have audio)
            if source != "both" && reportingSources.count >= 2 {
                let switchItem = NSMenuItem(
                    title: "Switch Audio Here",
                    action: #selector(audioActionClicked(_:)),
                    keyEquivalent: ""
                )
                switchItem.target = self
                switchItem.representedObject = AudioAction(source: source, switchAudio: true)
                sub.addItem(switchItem)
            }

            sub.addItem(NSMenuItem.separator())
        }

        for (i, def) in gameDefs.enumerated() {
            let isActive: Bool
            if source == "both" {
                // "Both" is on if active on ALL current PiP sources
                let sources = Array(Set(findAllPipWindows().map { $0.source }))
                isActive = !sources.isEmpty && sources.allSatisfy { gameIsActiveOnSource(def, source: $0) }
            } else {
                isActive = gameIsActiveOnSource(def, source: source)
            }

            let item = NSMenuItem(
                title: def.label,
                action: #selector(gameTargetClicked(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = GameAction(name: def.name, source: source, paddleMode: def.paddleMode)
            item.state = isActive ? .on : .off

            // Separator before Bounce group and before Invaders
            if i == 3 || i == 5 {
                sub.addItem(NSMenuItem.separator())
            }

            sub.addItem(item)
        }

        // Stop game for this source
        let hasGame: Bool
        if source == "both" {
            hasGame = daemon.hasActiveGames
        } else {
            hasGame = daemon.activeGames.contains { (id, _) in
                daemon.sourceForPipID(id) == source
            }
        }

        if hasGame {
            sub.addItem(NSMenuItem.separator())
            let stopItem = NSMenuItem(
                title: source == "both" ? "Stop All" : "Stop",
                action: #selector(stopSourceGames(_:)),
                keyEquivalent: ""
            )
            stopItem.target = self
            stopItem.representedObject = source
            stopItem.attributedTitle = NSAttributedString(
                string: source == "both" ? "Stop All" : "Stop",
                attributes: [.foregroundColor: NSColor.systemRed]
            )
            sub.addItem(stopItem)
        }

        return sub
    }

    // MARK: - Helpers

    private func activeGameName(forSource source: String) -> String? {
        for (id, entry) in daemon.activeGames {
            if daemon.sourceForPipID(id) == source {
                // Find the label for this game
                for def in gameDefs where def.name == entry.name {
                    if entry.name == "bounce" {
                        if def.paddleMode == entry.paddleMode { return def.label }
                    } else {
                        return def.label
                    }
                }
                return entry.name.capitalized
            }
        }
        return nil
    }

    private func gameIsActiveOnSource(_ def: GameDef, source: String) -> Bool {
        if def.name == "bounce" {
            return daemon.isBounceActiveOnSource(paddleMode: def.paddleMode, source: source)
        }
        return daemon.isGameActiveOnSource(def.name, source: source)
    }

    // MARK: - Game Action

    private class GameAction: NSObject {
        let name: String
        let source: String?
        let paddleMode: Bool
        init(name: String, source: String?, paddleMode: Bool) {
            self.name = name
            self.source = source
            self.paddleMode = paddleMode
        }
    }

    // MARK: - Audio Action

    private class AudioAction: NSObject {
        let source: String
        var volume: Double?
        var muted: Bool?
        var switchAudio: Bool
        init(source: String, volume: Double? = nil, muted: Bool? = nil, switchAudio: Bool = false) {
            self.source = source
            self.volume = volume
            self.muted = muted
            self.switchAudio = switchAudio
        }
    }

    @objc private func gameTargetClicked(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? GameAction else { return }
        daemon.toggleGame(action.name, source: action.source, paddleMode: action.paddleMode)
    }

    @objc private func audioActionClicked(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? AudioAction else { return }
        let targets: [String]
        if action.source == "both" {
            targets = daemon.audioStates.filter { $0.value.hasReported }.map { $0.key }
        } else {
            targets = [action.source]
        }
        for src in targets {
            if action.switchAudio {
                daemon.switchAudioTo(source: src)
            } else if let vol = action.volume {
                daemon.setDesiredVolume(vol, source: src)
            } else if let muted = action.muted {
                daemon.setDesiredMuted(muted, source: src)
            }
        }
    }

    @objc private func stopSourceGames(_ sender: NSMenuItem) {
        guard let source = sender.representedObject as? String else { return }
        if source == "both" {
            daemon.stopAllGames()
        } else {
            daemon.stopGamesForSource(source)
        }
    }

    @objc private func stopAllGames() {
        daemon.stopAllGames()
    }

    // MARK: - Actions

    @objc private func toggleDodge() {
        settings.enabled.toggle()
        settings.save()
        statusItem.button?.alphaValue = settings.enabled ? 1.0 : 0.5
        print(settings.enabled ? "Dodge enabled (menu)" : "Dodge paused (menu)")
    }

    @objc private func toggleGlow() {
        settings.glow.toggle()
        settings.save()
        print(settings.glow ? "Glow enabled (menu)" : "Glow disabled (menu)")
    }

    @objc private func restartDaemon() {
        cleanup()
        exit(0) // launchd KeepAlive will restart
    }

    @objc private func uninstallApp() {
        Uninstaller.confirmAndUninstall()
    }

    @objc private func quitApp() {
        cleanup()
        let label = "com.xpip.daemon"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = ["bootout", "gui/\(getuid())/\(label)"]
        try? proc.run()
        proc.waitUntilExit()
        exit(0)
    }
}
