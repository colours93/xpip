import Cocoa
import ApplicationServices

class PacManGame: GameBase {

    // MARK: - Grid — Classic 28 × 31
    private let gridCols = 28
    private let gridRows = 31
    private let tunnelRow = 13
    private let houseExitCol: CGFloat = 13
    private let houseExitRow: CGFloat = 9
    private var cellSize: CGFloat = 0
    private var level = 1
    private var savedScreen = CGRect.zero

    // MARK: - Maze  (0=wall, 1=dot, 2=power, 3=empty, 4=ghost house, 5=gate)
    private var maze: [[Int]] = []
    private let mazeTemplate: [[Int]] = [
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], //  0
        [0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0], //  1
        [0,1,0,0,0,0,1,0,0,0,0,0,1,0,0,1,0,0,0,0,0,1,0,0,0,0,1,0], //  2
        [0,2,0,0,0,0,1,0,0,0,0,0,1,0,0,1,0,0,0,0,0,1,0,0,0,0,2,0], //  3  power pellets
        [0,1,0,0,0,0,1,0,0,0,0,0,1,0,0,1,0,0,0,0,0,1,0,0,0,0,1,0], //  4
        [0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0], //  5  long corridor
        [0,1,0,0,0,0,1,0,0,1,0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,0,1,0], //  6
        [0,1,0,0,0,0,1,0,0,1,0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,0,1,0], //  7
        [0,1,1,1,1,1,1,0,0,1,1,1,1,0,0,1,1,1,1,0,0,1,1,1,1,1,1,0], //  8
        [0,0,0,0,0,0,1,0,0,0,0,0,3,3,3,3,0,0,0,0,0,1,0,0,0,0,0,0], //  9  open above house
        [0,0,0,0,0,0,1,0,0,0,0,0,3,3,3,3,0,0,0,0,0,1,0,0,0,0,0,0], // 10
        [0,0,0,0,0,0,1,0,0,0,0,0,3,5,5,3,0,0,0,0,0,1,0,0,0,0,0,0], // 11  gate cols 13-14
        [0,0,0,0,0,0,1,0,0,0,0,4,4,4,4,4,4,0,0,0,0,1,0,0,0,0,0,0], // 12  ghost house
        [3,3,3,3,3,3,1,0,0,0,0,4,4,4,4,4,4,0,0,0,0,1,3,3,3,3,3,3], // 13  tunnel + house
        [0,0,0,0,0,0,1,0,0,0,0,4,4,4,4,4,4,0,0,0,0,1,0,0,0,0,0,0], // 14  ghost house
        [0,0,0,0,0,0,1,0,0,0,0,0,3,3,3,3,0,0,0,0,0,1,0,0,0,0,0,0], // 15
        [0,0,0,0,0,0,1,0,0,0,0,0,3,3,3,3,0,0,0,0,0,1,0,0,0,0,0,0], // 16
        [0,0,0,0,0,0,1,0,0,1,1,1,1,1,1,1,1,1,1,0,0,1,0,0,0,0,0,0], // 17  U-top below house
        [0,0,0,0,0,0,1,0,0,1,0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,0,0,0], // 18
        [0,0,0,0,0,0,1,0,0,1,0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,0,0,0], // 19
        [0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0], // 20
        [0,1,0,0,0,0,1,0,0,0,0,0,1,0,0,1,0,0,0,0,0,1,0,0,0,0,1,0], // 21
        [0,1,0,0,0,0,1,0,0,0,0,0,1,0,0,1,0,0,0,0,0,1,0,0,0,0,1,0], // 22
        [0,2,1,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,2,0], // 23  power pellets
        [0,0,1,0,0,0,1,0,0,1,0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,1,0,0], // 24
        [0,0,1,0,0,0,1,0,0,1,0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,1,0,0], // 25
        [0,1,1,1,1,1,1,0,0,1,1,1,1,0,0,1,1,1,1,0,0,1,1,1,1,1,1,0], // 26
        [0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,1,0], // 27
        [0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,1,0], // 28
        [0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0], // 29  full bottom corridor
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], // 30
    ]

    // MARK: - Direction  (0=right, 1=down-AX, 2=left, 3=up-AX)
    private let dirDelta: [(dc: Int, dr: Int)] = [(1,0),(0,1),(-1,0),(0,-1)]

    // MARK: - Player
    private var playerCol: CGFloat = 13
    private var playerRow: CGFloat = 23
    private var playerDir: Int = 0
    private var nextDir: Int = 0
    private var playerSpeed: CGFloat = 3.2

    // MARK: - Ghost Director
    private var director = GhostDirector(gridCols: 28, gridRows: 31, tunnelRow: 13)
    private var ghostsEatenThisPower = 0
    private var gameTime: CGFloat = 0

    // MARK: - Lives & Dots
    private var lives = 3
    private var dotsRemaining = 0

    // MARK: - Play Flow (within a single GameBase session)
    private enum PlayState { case ready, playing, dying, levelComplete }
    private var playState: PlayState = .ready
    private var stateTimer: CGFloat = 0

    // MARK: - Death
    private var deathFreeze = false
    private var deathFreezeTimer: CGFloat = 0

    // MARK: - Camera
    private var cameraX: CGFloat = 0
    private var cameraY: CGFloat = 0

    // MARK: - Layers
    private var overlayWindow: NSWindow?
    private var glassWindow: NSWindow?
    private var mazeContainer: CALayer?
    private var dotContainer: CALayer?
    private var glassMaskLayer: CALayer?
    private var dotLayers: [[CALayer?]] = []
    private var readyLabel: CATextLayer?

    // MARK: - GameBase Hooks

    override func onStart(screen: CGRect, pip: PipWindowInfo) {
        timerIntervalMs = 8
        savedScreen = screen
        level = 1
        lives = 3
        gameTime = 0
        // Cell is sized so the PiP window == ~85% of one cell — Pac-Man IS the PiP
        cellSize = max(cachedPipSize.width, cachedPipSize.height) * 0.55
        scaleSpeedsToLevel()
        initLevel(screen: screen)

        if Thread.isMainThread { createOverlays(screen: screen) }
        else { DispatchQueue.main.sync { self.createOverlays(screen: screen) } }

        print("Pac-Man L\(level) (cell=\(Int(cellSize)) maze=\(gridCols)×\(gridRows) dots=\(dotsRemaining))")
    }

    override func onStop() {
        let ow = overlayWindow; let gw = glassWindow
        let cleanup = { ow?.orderOut(nil); gw?.orderOut(nil) }
        if Thread.isMainThread { cleanup() } else { DispatchQueue.main.async { cleanup() } }
        overlayWindow = nil; glassWindow = nil
        mazeContainer = nil; dotContainer = nil; glassMaskLayer = nil
        readyLabel = nil
        director.ghosts = []; dotLayers = []
    }

    // MARK: - Speed Scaling

    private func scaleSpeedsToLevel() {
        let l = min(level, 8)
        playerSpeed               = 3.2 + CGFloat(l - 1) * 0.12
        director.normalSpeed      = 2.8 + CGFloat(l - 1) * 0.10
        director.frightenedSpeed  = max(1.2, 1.8 - CGFloat(l - 1) * 0.08)
        director.frightenDuration = max(2.0, 7.0 - CGFloat(l - 1) * 0.7)
    }

    // MARK: - Level Init

    private func initLevel(screen: CGRect) {
        maze = mazeTemplate
        dotsRemaining = 0
        for r in 0..<gridRows {
            for c in 0..<gridCols {
                if maze[r][c] == 1 || maze[r][c] == 2 { dotsRemaining += 1 }
            }
        }
        // Clear dot at player spawn
        if maze[23][13] == 1 { maze[23][13] = 3 }

        playerCol = 13; playerRow = 23; playerDir = 0; nextDir = 0
        ghostsEatenThisPower = 0
        deathFreeze = false; deathFreezeTimer = 0
        playState = .ready; stateTimer = 2.0

        let pw = gridToWorld(col: playerCol, row: playerRow)
        cameraX = pw.x - screen.width / 2
        cameraY = pw.y - screen.height / 2
    }

    // MARK: - Overlay Creation

    private func createOverlays(screen: CGRect) {
        overlayWindow?.orderOut(nil); glassWindow?.orderOut(nil)
        overlayWindow = nil; glassWindow = nil

        let mazeW = cellSize * CGFloat(gridCols)
        let mazeH = cellSize * CGFloat(gridRows)

        // ── Game overlay (dots, ghosts) ───────────────────────────────────────
        let ow = NSWindow(contentRect: NSRect(x: screen.minX, y: 0,
                                              width: screen.width, height: CGFloat(screenH)),
                          styleMask: .borderless, backing: .buffered, defer: false)
        ow.isOpaque = false; ow.backgroundColor = .clear
        ow.level = .floating; ow.ignoresMouseEvents = true; ow.hasShadow = false
        ow.collectionBehavior = [.canJoinAllSpaces, .stationary, .transient, .ignoresCycle]
        ow.contentView!.wantsLayer = true
        let rootLayer = ow.contentView!.layer!
        rootLayer.masksToBounds = true

        let container = CALayer()
        container.frame = CGRect(x: 0, y: 0, width: mazeW, height: mazeH)
        rootLayer.addSublayer(container)
        mazeContainer = container

        // Dot sublayer (below ghosts)
        let dotCont = CALayer()
        dotCont.frame = CGRect(x: 0, y: 0, width: mazeW, height: mazeH)
        container.addSublayer(dotCont)
        dotContainer = dotCont

        // ── Glass-blur wall window ─────────────────────────────────────────────
        let gw = NSWindow(contentRect: NSRect(x: screen.minX, y: 0,
                                              width: screen.width, height: CGFloat(screenH)),
                          styleMask: .borderless, backing: .buffered, defer: false)
        gw.isOpaque = false; gw.backgroundColor = .clear
        gw.level = .floating; gw.ignoresMouseEvents = true; gw.hasShadow = false
        gw.collectionBehavior = [.canJoinAllSpaces, .stationary, .transient, .ignoresCycle]

        let vibrancy = NSVisualEffectView(frame: NSRect(x: 0, y: 0,
                                                        width: screen.width, height: CGFloat(screenH)))
        vibrancy.material = .hudWindow
        vibrancy.blendingMode = .behindWindow
        vibrancy.state = .active
        vibrancy.wantsLayer = true
        gw.contentView = vibrancy

        let maskRoot = CALayer()
        maskRoot.frame = CGRect(x: 0, y: 0, width: screen.width, height: CGFloat(screenH))
        let maskContainer = CALayer()
        maskContainer.frame = CGRect(x: 0, y: 0, width: mazeW, height: mazeH)

        let wallPath = CGMutablePath()
        let cr: CGFloat = cellSize * 0.18
        for r in 0..<gridRows {
            for c in 0..<gridCols {
                guard maze[r][c] == 0 else { continue }
                let cx = CGFloat(c) * cellSize
                let ny = mazeH - CGFloat(r + 1) * cellSize
                wallPath.addRoundedRect(in: CGRect(x: cx, y: ny, width: cellSize, height: cellSize),
                                        cornerWidth: cr, cornerHeight: cr)
            }
        }
        let maskShape = CAShapeLayer()
        maskShape.path = wallPath
        maskShape.fillColor = NSColor.white.cgColor
        maskContainer.mask = maskShape
        maskContainer.backgroundColor = NSColor.white.cgColor
        maskRoot.addSublayer(maskContainer)
        vibrancy.layer!.mask = maskRoot
        glassMaskLayer = maskContainer

        gw.orderFrontRegardless()
        glassWindow = gw

        // ── Dots & power pellets ───────────────────────────────────────────────
        buildDotLayers(in: dotCont, mazeH: mazeH)

        // ── Ghost gate indicator ───────────────────────────────────────────────
        let gateY = mazeH - CGFloat(12) * cellSize
        let gateL = CALayer()
        let gateW = cellSize * 2.0; let gateH: CGFloat = 3
        gateL.frame = CGRect(x: CGFloat(13) * cellSize, y: gateY - gateH / 2,
                             width: gateW, height: gateH)
        gateL.backgroundColor = NSColor(red: 1, green: 0.55, blue: 0.8, alpha: 0.9).cgColor
        gateL.cornerRadius = gateH / 2
        container.addSublayer(gateL)

        // ── Ghosts ────────────────────────────────────────────────────────────
        buildGhostLayers(in: container)

        // ── READY! label ──────────────────────────────────────────────────────
        let rl = CATextLayer()
        rl.string = "READY!"
        rl.foregroundColor = NSColor(red: 1, green: 1, blue: 0, alpha: 1).cgColor
        rl.fontSize = cellSize * 0.52
        rl.alignmentMode = .center
        rl.contentsScale = 2
        let rlW = cellSize * 6, rlH = cellSize * 0.9
        let spawnNsY = mazeH - CGFloat(24) * cellSize
        rl.frame = CGRect(x: CGFloat(13) * cellSize + cellSize / 2 - rlW / 2,
                          y: spawnNsY,
                          width: rlW, height: rlH)
        container.addSublayer(rl)
        readyLabel = rl

        ow.orderFrontRegardless()
        overlayWindow = ow

        createScoreOverlay(screen: screen, width: 220)
        updateScoreDisplay()
    }

    private func buildDotLayers(in parent: CALayer, mazeH: CGFloat) {
        dotLayers = Array(repeating: Array(repeating: nil, count: gridCols), count: gridRows)
        let dotColor = NSColor(red: 1.0, green: 0.85, blue: 0.5, alpha: 1.0).cgColor
        for r in 0..<gridRows {
            for c in 0..<gridCols {
                let v = maze[r][c]
                guard v == 1 || v == 2 else { continue }
                let nsY = mazeH - CGFloat(r + 1) * cellSize
                let layer = CALayer()
                if v == 1 {
                    let s = cellSize * 0.15
                    layer.frame = CGRect(x: CGFloat(c) * cellSize + (cellSize - s) / 2,
                                        y: nsY + (cellSize - s) / 2, width: s, height: s)
                    layer.backgroundColor = dotColor
                    layer.cornerRadius = s / 2
                } else {
                    let s = cellSize * 0.4
                    layer.frame = CGRect(x: CGFloat(c) * cellSize + (cellSize - s) / 2,
                                        y: nsY + (cellSize - s) / 2, width: s, height: s)
                    layer.backgroundColor = dotColor
                    layer.cornerRadius = s / 2
                    layer.shadowColor = dotColor
                    layer.shadowOffset = .zero
                    layer.shadowRadius = 5; layer.shadowOpacity = 0.8
                    let a = CABasicAnimation(keyPath: "shadowRadius")
                    a.fromValue = 5; a.toValue = 14; a.duration = 0.75
                    a.autoreverses = true; a.repeatCount = .infinity
                    layer.add(a, forKey: "g")
                }
                parent.addSublayer(layer)
                dotLayers[r][c] = layer
            }
        }
    }

    private func buildGhostLayers(in parent: CALayer) {
        for g in director.ghosts { g.layer.removeFromSuperlayer() }

        let startCols: [CGFloat] = [13, 13, 11, 15]
        let startRows: [CGFloat] = [9,  13, 13, 13]
        var states: [GhostState] = []
        for i in 0..<4 {
            let sz = cellSize * 0.82
            let layer = CALayer()
            layer.bounds = CGRect(origin: .zero, size: CGSize(width: sz, height: sz))
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.contents = PacManSprites.allGhosts[i]
            layer.magnificationFilter = .nearest
            layer.minificationFilter = .nearest
            parent.addSublayer(layer)
            states.append(GhostState(
                col: startCols[i], row: startRows[i],
                dir: i == 0 ? 2 : 3,
                layer: layer,
                colorIndex: i,
                mode: i == 0 ? .scatter : .inHouse,
                released: i == 0,
                personalDots: 0
            ))
        }
        director.setup(ghosts: states, totalDots: dotsRemaining, level: level)
    }

    // MARK: - Game Loop

    override func gameTick() {
        guard active, let _ = cachedAXWindow else { return }

        if gameOver {
            if machToSeconds(mach_absolute_time() - gameEndMach) > gameOverDelay { stop() }
            return
        }

        let screen = getScreenFrame()
        savedScreen = screen
        let dt = deltaTime()
        refreshPipSize()
        let size = cachedPipSize

        // ── READY! countdown ─────────────────────────────────────────────────
        if playState == .ready {
            stateTimer -= dt
            if stateTimer <= 0 {
                playState = .playing
                DispatchQueue.main.async { self.readyLabel?.isHidden = true }
            }
            updateCameraAndVisuals(screen: screen, size: size, dt: dt)
            return
        }

        // ── Level clear animation ─────────────────────────────────────────────
        if playState == .levelComplete {
            stateTimer -= dt
            if stateTimer <= 0 {
                level += 1
                scaleSpeedsToLevel()
                gameTime = 0
                initLevel(screen: screen)
                DispatchQueue.main.async { self.onLevelReset() }
            }
            updateCameraAndVisuals(screen: screen, size: size, dt: dt)
            return
        }

        gameTime += dt

        // ── Death freeze ──────────────────────────────────────────────────────
        if deathFreeze {
            deathFreezeTimer -= dt
            if deathFreezeTimer <= 0 { deathFreeze = false }
            updateCameraAndVisuals(screen: screen, size: size, dt: dt)
            return
        }

        // ── Player input: steer toward cursor ────────────────────────────────
        if let mousePos = mousePosition() {
            let pw = gridToWorld(col: playerCol, row: playerRow)
            let ps = worldToScreen(worldX: pw.x, worldY: pw.y)
            let dx = mousePos.x - ps.x
            let dy = mousePos.y - ps.y
            if abs(dx) > abs(dy) { nextDir = dx > 0 ? 0 : 2 }
            else                  { nextDir = dy > 0 ? 1 : 3 }
        }

        // ── Move player ───────────────────────────────────────────────────────
        movePlayer(dt: dt)

        // ── Collect dots ──────────────────────────────────────────────────────
        let pC = Int(round(playerCol)), pR = Int(round(playerRow))
        if pC >= 0, pC < gridCols, pR >= 0, pR < gridRows {
            let cell = maze[pR][pC]
            if cell == 1 {
                maze[pR][pC] = 3
                dotsRemaining -= 1; score += 10
                dotLayers[pR][pC]?.removeFromSuperlayer(); dotLayers[pR][pC] = nil
                emitDotParticles(atCol: pC, row: pR)
                director.dotEaten(gameTime: gameTime)
                updateScoreDisplay(); pulseScoreOverlay()
            } else if cell == 2 {
                maze[pR][pC] = 3
                dotsRemaining -= 1; score += 50
                dotLayers[pR][pC]?.removeFromSuperlayer(); dotLayers[pR][pC] = nil
                emitDotParticles(atCol: pC, row: pR)
                ghostsEatenThisPower = 0
                director.activateFrightened()
                updateScoreDisplay(); pulseScoreOverlay()
                SoundKit.shared.play(.score)
            }
        }

        // ── Level cleared? ────────────────────────────────────────────────────
        if dotsRemaining <= 0 {
            playState = .levelComplete; stateTimer = 2.2
            scoreLabel?.attributedStringValue = Self.styledMessage("LEVEL \(level) CLEAR!")
            SoundKit.shared.play(.score)
            updateCameraAndVisuals(screen: screen, size: size, dt: dt)
            return
        }

        // ── Update ghost director ─────────────────────────────────────────────
        director.update(dt: dt, maze: maze,
                        playerCol: playerCol, playerRow: playerRow, playerDir: playerDir,
                        dotsRemaining: dotsRemaining, gameTime: gameTime)

        // ── Ghost collision ───────────────────────────────────────────────────
        let now = mach_absolute_time()
        for i in 0..<director.ghosts.count {
            guard director.isCollidable(index: i) else { continue }
            let d = hypot(director.ghosts[i].col - playerCol,
                          director.ghosts[i].row - playerRow)
            guard d < 0.65 else { continue }
            if director.ghosts[i].mode == .frightened {
                director.eatGhost(index: i)
                ghostsEatenThisPower += 1
                let bonus = 200 * (1 << (ghostsEatenThisPower - 1))
                score += bonus
                showScorePopup(bonus, col: director.ghosts[i].col, row: director.ghosts[i].row)
                updateScoreDisplay(); pulseScoreOverlay()
                SoundKit.shared.play(.hit)
            } else {
                hitPlayer(now: now)
                if gameOver { return }
                break
            }
        }

        updateCameraAndVisuals(screen: screen, size: size, dt: dt)
    }

    // MARK: - Level Reset (main thread)

    private func onLevelReset() {
        guard let dotCont = dotContainer, let container = mazeContainer else { return }
        for row in dotLayers { for l in row { l?.removeFromSuperlayer() } }
        let mazeH = cellSize * CGFloat(gridRows)
        buildDotLayers(in: dotCont, mazeH: mazeH)
        buildGhostLayers(in: container)
        readyLabel?.isHidden = false
        updateScoreDisplay()
    }

    // MARK: - Camera & Visuals

    private func updateCameraAndVisuals(screen: CGRect, size: CGSize, dt: CGFloat) {
        let mazeW = cellSize * CGFloat(gridCols)
        let mazeH = cellSize * CGFloat(gridRows)
        let pw = gridToWorld(col: playerCol, row: playerRow)

        // Smooth camera
        let targetCamX = pw.x - screen.width / 2
        let targetCamY = pw.y - screen.height / 2
        let lerp: CGFloat = 1.0 - pow(0.85, dt * 120)
        cameraX += (targetCamX - cameraX) * lerp
        cameraY += (targetCamY - cameraY) * lerp
        cameraX = max(0, min(cameraX, mazeW - screen.width))
        cameraY = max(0, min(cameraY, mazeH - screen.height))

        // Move PiP to player position
        let pipPos = worldToScreen(worldX: pw.x - size.width / 2, worldY: pw.y - size.height / 2)
        if !movePip(to: pipPos) { return }
        let bounds = CGRect(origin: pipPos, size: size)

        withTransaction {
            let cx = -cameraX + screen.minX
            let cy = -(mazeH - CGFloat(screenH) - cameraY)
            mazeContainer?.frame.origin = CGPoint(x: cx, y: cy)
            glassMaskLayer?.frame.origin = CGPoint(x: cx, y: cy)

            // Ghosts
            for i in 0..<director.ghosts.count {
                let g = director.ghosts[i]
                let gw = gridToWorld(col: g.col, row: g.row)
                g.layer.position = CGPoint(x: gw.x, y: mazeH - gw.y)

                switch g.mode {
                case .eaten:
                    g.layer.contents = PacManSprites.eaten
                    g.layer.opacity = 1.0
                case .frightened:
                    let flash = director.frightenTimer < 2.0 && Int(director.frightenTimer * 5) % 2 == 0
                    g.layer.contents = flash ? PacManSprites.scaredFlash : PacManSprites.scared
                    g.layer.opacity = 1.0
                case .inHouse:
                    g.layer.contents = PacManSprites.allGhosts[g.colorIndex]
                    g.layer.opacity = 0.55
                default:
                    g.layer.contents = PacManSprites.allGhosts[g.colorIndex]
                    g.layer.opacity = 1.0
                }
            }

            syncBorder(around: bounds)
        }
    }

    // MARK: - Movement

    private func movePlayer(dt: CGFloat) {
        let speed = playerSpeed * dt
        let nC = Int(round(playerCol)), nR = Int(round(playerRow))

        // Try to turn if close enough to cell center
        let nd = dirDelta[nextDir]
        if isPlayerWalkable(nC + nd.dc, nR + nd.dr) {
            if abs(playerCol - CGFloat(nC)) < 0.40 && abs(playerRow - CGFloat(nR)) < 0.40 {
                playerDir = nextDir
            }
        }

        // Tunnel wrap
        if Int(round(playerRow)) == tunnelRow {
            if playerCol < -1 { playerCol = CGFloat(gridCols); return }
            if playerCol > CGFloat(gridCols) { playerCol = -1; return }
        }

        let d = dirDelta[playerDir]
        if isPlayerWalkable(Int(round(playerCol)) + d.dc, Int(round(playerRow)) + d.dr) {
            playerCol += CGFloat(d.dc) * speed
            playerRow += CGFloat(d.dr) * speed
        } else {
            playerCol = round(playerCol); playerRow = round(playerRow)
        }
    }

    // MARK: - Grid Helpers

    private func isPlayerWalkable(_ col: Int, _ row: Int) -> Bool {
        guard col >= 0, col < gridCols, row >= 0, row < gridRows else {
            return row == tunnelRow && (col < 0 || col >= gridCols)
        }
        let v = maze[row][col]
        return v == 1 || v == 2 || v == 3
    }

    private func gridToWorld(col: CGFloat, row: CGFloat) -> CGPoint {
        CGPoint(x: col * cellSize + cellSize / 2, y: row * cellSize + cellSize / 2)
    }

    private func worldToScreen(worldX: CGFloat, worldY: CGFloat) -> CGPoint {
        CGPoint(x: worldX - cameraX + savedScreen.minX,
                y: worldY - cameraY + savedScreen.minY)
    }

    // MARK: - Player Hit

    private func hitPlayer(now: UInt64) {
        lives -= 1
        SoundKit.shared.play(.death)
        if lives <= 0 {
            state = .gameOver
            gameEndMach = now
            scoreLabel?.attributedStringValue = Self.styledMessage("GAME OVER  \(score)")
            return
        }

        deathFreeze = true; deathFreezeTimer = 1.2
        playerCol = 13; playerRow = 23; playerDir = 0; nextDir = 0
        ghostsEatenThisPower = 0

        // Reset ghosts to start positions, keeping existing CALayer references
        let startCols: [CGFloat] = [13, 13, 11, 15]
        let startRows: [CGFloat] = [9,  13, 13, 13]
        var states: [GhostState] = []
        for i in 0..<director.ghosts.count {
            var gs = director.ghosts[i]
            gs.col = startCols[i]; gs.row = startRows[i]
            gs.dir = i == 0 ? 2 : 3
            gs.mode = i == 0 ? .scatter : .inHouse
            gs.released = i == 0
            gs.personalDots = 0
            states.append(gs)
        }
        director.setup(ghosts: states, totalDots: dotsRemaining, level: level)
        updateScoreDisplay()
    }

    // MARK: - Score Display

    private func updateScoreDisplay() {
        let hearts = String(repeating: "♥", count: max(0, lives))
        let levelStr = level > 1 ? "L\(level) " : ""
        scoreLabel?.attributedStringValue = Self.styledScore("\(levelStr)\(hearts)  \(score)")
    }

    // MARK: - Ghost Score Popup

    private func showScorePopup(_ pts: Int, col: CGFloat, row: CGFloat) {
        guard let container = mazeContainer else { return }
        let mazeH = cellSize * CGFloat(gridRows)
        let world = gridToWorld(col: col, row: row)
        let w = cellSize * 2.5, h = cellSize * 0.7
        let nsX = world.x - w / 2, nsY = mazeH - world.y + h

        let label = CATextLayer()
        label.string = "+\(pts)"
        label.foregroundColor = NSColor.cyan.cgColor
        label.fontSize = cellSize * 0.42
        label.alignmentMode = .center
        label.contentsScale = 2
        label.frame = CGRect(x: nsX, y: nsY, width: w, height: h)
        container.addSublayer(label)

        let fadeAnim = CABasicAnimation(keyPath: "opacity")
        fadeAnim.fromValue = 1.0; fadeAnim.toValue = 0.0
        fadeAnim.duration = 0.85; fadeAnim.beginTime = CACurrentMediaTime() + 0.15
        label.add(fadeAnim, forKey: nil)

        let moveAnim = CABasicAnimation(keyPath: "position.y")
        moveAnim.byValue = cellSize * 1.4; moveAnim.duration = 1.0
        label.add(moveAnim, forKey: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { label.removeFromSuperlayer() }
    }

    // MARK: - Dot Particles

    private func emitDotParticles(atCol col: Int, row: Int) {
        guard let container = mazeContainer else { return }
        let mazeH = cellSize * CGFloat(gridRows)
        let wx = CGFloat(col) * cellSize + cellSize / 2
        let wy = mazeH - CGFloat(row) * cellSize - cellSize / 2

        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: wx, y: wy)
        emitter.emitterSize = .zero; emitter.emitterShape = .point
        emitter.renderMode = .additive

        let cell = CAEmitterCell()
        cell.lifetime = 0.35; cell.velocity = 38; cell.velocityRange = 18
        cell.emissionRange = .pi * 2; cell.scale = 0.034; cell.scaleSpeed = -0.05
        cell.color = NSColor(red: 1, green: 0.85, blue: 0.5, alpha: 1).cgColor
        cell.contents = {
            let s: CGFloat = 8
            let img = NSImage(size: NSSize(width: s, height: s))
            img.lockFocus()
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: s, height: s)).fill()
            img.unlockFocus()
            return img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }()
        emitter.emitterCells = [cell]
        container.addSublayer(emitter)

        DispatchQueue.main.async {
            cell.birthRate = 12; emitter.emitterCells = [cell]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                cell.birthRate = 0; emitter.emitterCells = [cell]
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    emitter.removeFromSuperlayer()
                }
            }
        }
    }
}
