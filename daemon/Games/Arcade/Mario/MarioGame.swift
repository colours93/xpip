import Cocoa
import ApplicationServices

/// World 1-1 — faithful 1:1 recreation with the PiP as Mario.
/// Auto-running; click/hold to jump. Variable-height jump, goombas, pits, pipes,
/// ? blocks, brick blocks, staircases, bushes, castle, flagpole finish.
class MarioGame: GameBase {

    // MARK: - Physics (tile units per second)

    private enum Phys {
        static let jumpV: CGFloat     = -15    // tiles/s upward
        static let holdG: CGFloat     =  25    // tiles/s² (hold = floaty)
        static let relG: CGFloat      =  75    // tiles/s² (release / falling)
        static let maxFall: CGFloat   =  12    // tiles/s
        static let scroll: CGFloat    =   4    // tiles/s auto-scroll
        static let goombaSpd: CGFloat =   2    // tiles/s leftward
        static let stepMax: CGFloat   =   1.3  // max auto-step (tiles)
        static let coyoteTime: CGFloat =  0.08 // seconds
        static let jumpBuffer: CGFloat =  0.12 // seconds
        static let flagSlide: CGFloat  =   6   // tiles/s flag slide down
    }

    // MARK: - World 1-1 Level Data

    private enum Lvl {
        static let cols     = 212
        static let rows     = 15
        static let groundRow = 13   // rows 13-14 are solid ground

        // Pits — columns with NO ground (widened for PiP; gap 3 ends at 154 so staircase at 155 is solid)
        static let gaps: [ClosedRange<Int>] = [69...72, 86...89, 152...154]

        // Pipes: (col, heightInTiles). Each pipe is 2 cols wide.
        static let pipes: [(col: Int, h: Int)] = [
            (28, 2), (38, 3), (46, 4), (57, 4), (163, 2), (179, 2)
        ]

        // ? blocks: (col, row) — verified from NES ROM / pixel-faithful references
        // Row 9 = low floating row; row 4 = high floating row
        static let qBlocks: [(col: Int, row: Int)] = [
            // Low row (row 9)
            (16, 9), (21, 9), (23, 9), (78, 9),
            (106, 9), (109, 9), (112, 9), (170, 9),
            // High row (row 4)
            (22, 4), (94, 4), (109, 4), (129, 4),
        ]

        // Brick blocks: (col, row) — verified layout
        // Row 9 = low; row 4 = high elevated section
        static let bricks: [(col: Int, row: Int)] = [
            // Low bricks (row 9)
            (20, 9), (22, 9), (24, 9),
            (77, 9), (79, 9),
            (94, 9),                        // 6-coin brick
            (100, 9), (101, 9),             // star brick
            (118, 9),
            (129, 9), (130, 9),
            (168, 9), (169, 9), (171, 9),
            // High bricks (row 4)
            (80, 4), (81, 4), (82, 4), (83, 4), (84, 4), (85, 4), (86, 4), (87, 4),
            (91, 4), (92, 4), (93, 4),
            (121, 4), (122, 4), (123, 4),
            (128, 4), (130, 4), (131, 4),
        ]

        // Staircases: (col, topRow) — solid from topRow down to groundRow-1
        static let stairs: [(col: Int, topRow: Int)] = [
            // Ascending staircase 1
            (134, 12), (135, 11), (136, 10), (137, 9),
            // Descending staircase 1
            (140,  9), (141, 10), (142, 11), (143, 12),
            // Ascending staircase 2
            (148, 12), (149, 11), (150, 10), (151, 9), (152, 9),
            // Descending staircase 2 (was missing; gap 3 ends at 154)
            (155,  9), (156, 10), (157, 11), (158, 12),
            // Final ascending pyramid to flagpole
            (181, 12), (182, 11), (183, 10), (184, 9), (185, 8),
            (186,  7), (187,  6), (188, 5)
        ]

        // Goomba spawn columns
        static let goombas: [Int] = [
            22, 40, 41, 51, 52, 80, 82, 97, 98,
            107, 114, 115, 124, 128, 129, 174, 175
        ]

        // W1-1 has no visible floating coins — all coins are inside blocks
        static let coins: [(col: Int, row: Int)] = []

        // Bush decoration columns (world 1-1 approximate positions)
        static let bushCols: [Int] = [11, 31, 60, 102, 136, 166]

        static let flagpoleCol = 198
        static let castleCol   = flagpoleCol + 5  // just past flagpole

        static func isGap(_ col: Int) -> Bool {
            gaps.contains { $0.contains(col) }
        }
    }

    // MARK: - Runtime State

    private var tileSize: CGFloat = 0
    private var cameraWX: CGFloat = 0       // world-X of left screen edge
    private var positionX: CGFloat = 0      // AX screen X (fixed)
    private var positionY: CGFloat = 0      // AX screen Y
    private var velocityY: CGFloat = 0
    private var onGround = true
    private var wasMouseDown = false
    private var jumpHeld = false
    private var coyoteLeft: CGFloat = 0
    private var jumpBufLeft: CGFloat = 0
    private var levelWon = false
    private var winTime: UInt64 = 0

    // Score / HUD
    private var coinCount = 0
    private var timeLeft: CGFloat = 400

    // Heightmap: column → topmost solid row (nil = pit)
    private var heightmap: [Int?] = []

    // Flag animation
    private var flagAXY: CGFloat = 0        // AX Y of flag top (slides down on win)
    private var flagInitY: CGFloat = 0      // starting AX Y (pole top)

    // MARK: - Entity Structs

    private struct PipeEnt {
        let worldX: CGFloat; let height: CGFloat
        var bodyLayer: CALayer?; var capLayer: CALayer?
    }
    private struct BlockEnt {
        let worldX: CGFloat; let worldY: CGFloat; let isQ: Bool
        var layer: CALayer?; var hit: Bool
    }
    private struct StairEnt {
        let worldX: CGFloat; let worldY: CGFloat
        var layer: CALayer?
    }
    private struct GoombaEnt {
        var worldX: CGFloat; let spawnX: CGFloat; let groundY: CGFloat
        var layer: CALayer?; var alive: Bool; var spawned: Bool
    }
    private struct CoinEnt {
        let worldX: CGFloat; let worldY: CGFloat
        var layer: CALayer?; var collected: Bool
    }
    private struct BushEnt {
        let worldX: CGFloat
        var layer: CALayer?
    }

    private var pipeEnts:   [PipeEnt]   = []
    private var blockEnts:  [BlockEnt]  = []
    private var stairEnts:  [StairEnt]  = []
    private var goombaEnts: [GoombaEnt] = []
    private var coinEnts:   [CoinEnt]   = []
    private var bushEnts:   [BushEnt]   = []
    private var groundLayers: [CALayer] = []
    private var clouds: [(layer: CALayer, worldX: CGFloat, worldY: CGFloat)] = []
    private var hills:  [(layer: CALayer, worldX: CGFloat)] = []
    private var flagpoleLayer:    CALayer?
    private var flagpoleBallLayer: CALayer?
    private var flagLayer:        CALayer?
    private var castleWorldX: CGFloat = 0
    private var castleLayer:  CALayer?

    // Overlay
    private var overlayWindow: NSWindow?
    private var overlayLayer:  CALayer?
    private var skyLayer:      CALayer?

    // HUD
    private var hudWindow:      NSWindow?
    private var hudScoreLabel:  NSTextField?
    private var hudCoinsLabel:  NSTextField?
    private var hudTimeLabel:   NSTextField?
    private var hudStatusLabel: NSTextField?   // "1-1" or "CLEAR!" or "DEAD"

    // MARK: - Lifecycle

    override func onStart(screen: CGRect, pip: PipWindowInfo) {
        tileSize   = screenH / CGFloat(Lvl.rows)
        cameraWX   = 0
        positionX  = screen.minX + screen.width * 0.18
        velocityY  = 0
        onGround   = true
        wasMouseDown = false
        jumpHeld   = false
        coyoteLeft = 0
        jumpBufLeft = 0
        levelWon   = false
        coinCount  = 0
        timeLeft   = 400
        flagAXY    = 0
        flagInitY  = 0

        let groundSurfY = CGFloat(Lvl.groundRow) * tileSize
        positionY = groundSurfY - cachedPipSize.height

        var initPos = CGPoint(x: positionX, y: positionY)
        if let val = AXValueCreate(.cgPoint, &initPos) {
            AXUIElementSetAttributeValue(pip.axWindow, kAXPositionAttribute as CFString, val)
        }

        buildHeightmap()
        buildEntities()

        if Thread.isMainThread { createOverlays(screen: screen) }
        else { DispatchQueue.main.sync { self.createOverlays(screen: screen) } }

        fillGround(screen: screen)
        spawnInitialBackdrop(screen: screen)

        print("[Mario] 1-1 started, tileSize=\(tileSize)")
    }

    override func onStop() {
        let ow = overlayWindow
        let hw = hudWindow
        if Thread.isMainThread {
            ow?.orderOut(nil)
            hw?.orderOut(nil)
        } else {
            DispatchQueue.main.async {
                ow?.orderOut(nil)
                hw?.orderOut(nil)
            }
        }
        overlayWindow = nil; overlayLayer = nil; skyLayer = nil
        hudWindow = nil; hudScoreLabel = nil; hudCoinsLabel = nil
        hudTimeLabel = nil; hudStatusLabel = nil
        pipeEnts = []; blockEnts = []; stairEnts = []
        goombaEnts = []; coinEnts = []; bushEnts = []
        groundLayers = []; clouds = []; hills = []
        flagpoleLayer = nil; flagpoleBallLayer = nil
        flagLayer = nil; castleLayer = nil
        print("[Mario] 1-1 stopped")
    }

    // MARK: - Heightmap

    private func buildHeightmap() {
        heightmap = Array(repeating: Lvl.groundRow, count: Lvl.cols + 20)

        for gap in Lvl.gaps {
            for col in gap { if col < heightmap.count { heightmap[col] = nil } }
        }
        for s in Lvl.stairs {
            if s.col < heightmap.count, let cur = heightmap[s.col] {
                heightmap[s.col] = min(cur, s.topRow)
            }
        }
        for p in Lvl.pipes {
            let top = Lvl.groundRow - p.h
            for dc in 0..<2 {
                let c = p.col + dc
                if c < heightmap.count, let cur = heightmap[c] {
                    heightmap[c] = min(cur, top)
                }
            }
        }
    }

    // MARK: - Entity Building

    private func buildEntities() {
        pipeEnts = Lvl.pipes.map { p in
            PipeEnt(worldX: CGFloat(p.col) * tileSize,
                    height: CGFloat(p.h)   * tileSize,
                    bodyLayer: nil, capLayer: nil)
        }

        var blocks: [BlockEnt] = []
        for q in Lvl.qBlocks {
            blocks.append(BlockEnt(worldX: CGFloat(q.col) * tileSize,
                                   worldY: CGFloat(q.row) * tileSize,
                                   isQ: true, layer: nil, hit: false))
        }
        for b in Lvl.bricks {
            blocks.append(BlockEnt(worldX: CGFloat(b.col) * tileSize,
                                   worldY: CGFloat(b.row) * tileSize,
                                   isQ: false, layer: nil, hit: false))
        }
        blockEnts = blocks.sorted { $0.worldX < $1.worldX }

        var stairs: [StairEnt] = []
        for s in Lvl.stairs {
            for row in s.topRow..<Lvl.groundRow {
                stairs.append(StairEnt(worldX: CGFloat(s.col) * tileSize,
                                       worldY: CGFloat(row)   * tileSize,
                                       layer: nil))
            }
        }
        stairEnts = stairs.sorted { $0.worldX < $1.worldX }

        let groundSurfY = CGFloat(Lvl.groundRow) * tileSize
        goombaEnts = Lvl.goombas.map { col in
            let wx = CGFloat(col) * tileSize
            return GoombaEnt(worldX: wx, spawnX: wx,
                             groundY: groundSurfY - tileSize,
                             layer: nil, alive: true, spawned: false)
        }

        coinEnts = Lvl.coins.map { c in
            CoinEnt(worldX: CGFloat(c.col) * tileSize,
                    worldY: CGFloat(c.row) * tileSize,
                    layer: nil, collected: false)
        }

        bushEnts = Lvl.bushCols.map { col in
            BushEnt(worldX: CGFloat(col) * tileSize, layer: nil)
        }

        castleWorldX = CGFloat(Lvl.castleCol) * tileSize
    }

    // MARK: - Overlays

    private func createOverlays(screen: CGRect) {
        let (ow, rootLayer) = createFullscreenOverlay(screen: screen)
        ow.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        overlayWindow = ow
        overlayLayer = rootLayer

        // NES SMB sky blue: #5C94FC
        let sky = CALayer()
        sky.frame = CGRect(x: 0, y: 0, width: screen.width, height: screenH)
        sky.backgroundColor = NSColor(red: 0.361, green: 0.580, blue: 0.988, alpha: 1.0).cgColor
        rootLayer.addSublayer(sky)
        skyLayer = sky

        createHUD(screen: screen)
    }

    // MARK: - HUD

    private func createHUD(screen: CGRect) {
        let hudH: CGFloat = 50
        let hw = NSWindow(
            contentRect: NSRect(x: screen.minX, y: screenH - hudH,
                                width: screen.width, height: hudH),
            styleMask: .borderless, backing: .buffered, defer: false)
        hw.isOpaque = false
        hw.backgroundColor = NSColor(white: 0.04, alpha: 0.92)
        hw.level = .floating
        hw.ignoresMouseEvents = true
        hw.hasShadow = false
        hw.collectionBehavior = [.canJoinAllSpaces, .stationary, .transient, .ignoresCycle]
        hw.orderFrontRegardless()
        hudWindow = hw
        guard let cv = hw.contentView else { return }

        let titleFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        let valueFont = NSFont.monospacedSystemFont(ofSize: 15, weight: .bold)
        let cream = NSColor(red: 1.0, green: 0.97, blue: 0.88, alpha: 1.0)
        let sw = screen.width

        func title(_ text: String, x: CGFloat, w: CGFloat) {
            let f = NSTextField(labelWithString: text)
            f.font = titleFont; f.textColor = cream; f.alignment = .center
            f.frame = NSRect(x: x, y: 30, width: w, height: 14)
            cv.addSubview(f)
        }
        func value(_ text: String, x: CGFloat, w: CGFloat) -> NSTextField {
            let f = NSTextField(labelWithString: text)
            f.font = valueFont; f.textColor = cream; f.alignment = .center
            f.frame = NSRect(x: x, y: 6, width: w, height: 22)
            cv.addSubview(f)
            return f
        }

        // MARIO section
        title("MARIO",  x: sw * 0.05, w: 100)
        hudScoreLabel = value("000000", x: sw * 0.05, w: 100)

        // Coins
        hudCoinsLabel = value("×00", x: sw * 0.27, w: 70)

        // WORLD section
        title("WORLD",  x: sw * 0.5 - 50, w: 100)
        hudStatusLabel = value("1-1", x: sw * 0.5 - 50, w: 100)

        // TIME section
        title("TIME",   x: sw * 0.78, w: 80)
        hudTimeLabel = value("400", x: sw * 0.78, w: 80)
    }

    // MARK: - Ground Tiles

    private func fillGround(screen: CGRect) {
        guard let root = overlayLayer else { return }
        let tileW = tileSize
        let tileH = tileSize / 2   // ground tile sprite is 16x8 (2:1 ratio)
        let tilesNeeded = Int(screen.width / tileW) + 3
        let tileRows = Int(ceil((CGFloat(Lvl.rows - Lvl.groundRow) * tileSize) / tileH))
        for col in 0..<tilesNeeded {
            for row in 0..<tileRows {
                let layer = CALayer()
                layer.contents = MarioSprites.groundTileImage
                layer.magnificationFilter = .nearest
                layer.minificationFilter  = .nearest
                layer.contentsGravity     = .resize
                layer.frame = CGRect(x: CGFloat(col) * tileW, y: CGFloat(row) * tileH,
                                     width: tileW, height: tileH)
                root.addSublayer(layer)
                groundLayers.append(layer)
            }
        }
    }

    // MARK: - Backdrop

    private func spawnInitialBackdrop(screen: CGRect) {
        guard let root = overlayLayer else { return }
        var cx: CGFloat = CGFloat.random(in: 50...200)
        while cx < screen.width + 300 {
            spawnCloud(worldX: cx, screen: screen, root: root)
            cx += CGFloat.random(in: 200...400)
        }
        var hx: CGFloat = CGFloat.random(in: 0...80)
        while hx < screen.width + 200 {
            spawnHill(worldX: hx, screen: screen, root: root)
            hx += CGFloat.random(in: 300...500)
        }
    }

    private func spawnCloud(worldX: CGFloat, screen: CGRect, root: CALayer) {
        let layer = layerPool.dequeue()
        layer.contents = MarioSprites.cloudImage
        layer.magnificationFilter = .nearest; layer.minificationFilter = .nearest
        layer.contentsGravity = .resize
        let s = CGFloat.random(in: 1.5...3.0)
        let y = CGFloat.random(in: (screen.minY + 30)...(screen.minY + screen.height * 0.35))
        let cw: CGFloat = 40 * s, ch: CGFloat = 20 * s
        layer.frame = CGRect(x: worldX - cameraWX, y: screenH - y - ch, width: cw, height: ch)
        layer.opacity = 0.9
        if let sky = skyLayer { root.insertSublayer(layer, above: sky) }
        else { root.addSublayer(layer) }
        clouds.append((layer: layer, worldX: worldX, worldY: y))
    }

    private func spawnHill(worldX: CGFloat, screen: CGRect, root: CALayer) {
        let layer = layerPool.dequeue()
        layer.contents = MarioSprites.hillImage
        layer.magnificationFilter = .nearest; layer.minificationFilter = .nearest
        layer.contentsGravity = .resize
        let s = CGFloat.random(in: 1.0...2.0)
        let w: CGFloat = 72 * s, h: CGFloat = 36 * s
        let groundNSH = CGFloat(Lvl.rows - Lvl.groundRow) * tileSize
        layer.frame = CGRect(x: worldX - cameraWX, y: groundNSH, width: w, height: h)
        layer.opacity = 0.7
        if let sky = skyLayer { root.insertSublayer(layer, above: sky) }
        else { root.addSublayer(layer) }
        hills.append((layer: layer, worldX: worldX))
    }

    // MARK: - Game Loop

    override func gameTick() {
        guard active, let _ = cachedAXWindow else { return }

        let screen = getScreenFrame()
        let size   = cachedPipSize
        let dt     = deltaTime()

        if checkGameOverTimeout() { return }

        // --- Win timeout ---
        if levelWon {
            // Animate flag sliding down
            let flagH   = tileSize * 1.0
            let flagEnd = CGFloat(Lvl.groundRow) * tileSize - flagH
            if flagAXY < flagEnd {
                flagAXY = min(flagAXY + Phys.flagSlide * tileSize * dt, flagEnd)
            }

            // Win ends after 3 s
            if machToSeconds(mach_absolute_time() - winTime) > 3.0 { stop() }

            withTransaction {
                updateEntityVisuals(screen: screen)
                updateBackdrop(screen: screen)
            }
            return
        }

        // --- Timer ---
        timeLeft -= dt
        if timeLeft < 0 { timeLeft = 0 }
        if timeLeft == 0 && state == .playing {
            triggerGameOver(message: "TIME UP  \(score)")
            hudStatusLabel?.stringValue = "TIME UP"
            SoundKit.shared.play(.death)
            return
        }

        // --- Input ---
        let mouseDown = isMouseDown
        if mouseDown && !wasMouseDown { jumpBufLeft = Phys.jumpBuffer }
        wasMouseDown = mouseDown

        if onGround { coyoteLeft  = Phys.coyoteTime }
        else        { coyoteLeft -= dt }

        if jumpBufLeft > 0 && (onGround || coyoteLeft > 0) {
            velocityY   = Phys.jumpV * tileSize
            onGround    = false
            coyoteLeft  = 0
            jumpHeld    = true
            jumpBufLeft = 0
            SoundKit.shared.play(.bounce)
        }
        jumpBufLeft -= dt
        if !mouseDown { jumpHeld = false }

        // --- Gravity ---
        let g: CGFloat = (velocityY < 0 && jumpHeld && mouseDown) ? Phys.holdG : Phys.relG
        velocityY += g * tileSize * dt
        velocityY  = min(velocityY, Phys.maxFall * tileSize)
        positionY += velocityY * dt

        // --- Camera ---
        cameraWX += Phys.scroll * tileSize * dt

        // --- Ground / heightmap collision ---
        let pipW = size.width
        let pipH = size.height

        // Leading-edge wall check
        let leadCol = Int((positionX + pipW + cameraWX) / tileSize)
        if leadCol >= 0 && leadCol < heightmap.count, let leadRow = heightmap[leadCol] {
            let leadSurfY = CGFloat(leadRow) * tileSize
            let diff      = (positionY + pipH) - leadSurfY
            if diff > Phys.stepMax * tileSize {
                triggerGameOver(message: "GAME OVER  \(score)")
                hudStatusLabel?.stringValue = "DEAD"
                SoundKit.shared.play(.death)
                return
            }
        }

        // Center-column ground
        let centerCol = Int((positionX + pipW / 2 + cameraWX) / tileSize)
        if centerCol >= 0 && centerCol < heightmap.count, let surfRow = heightmap[centerCol] {
            let surfY = CGFloat(surfRow) * tileSize
            if positionY + pipH >= surfY {
                positionY = surfY - pipH
                velocityY = 0
                onGround  = true
            } else {
                onGround  = false
            }
        } else {
            onGround = false
            if positionY > screenH + 200 {
                triggerGameOver(message: "GAME OVER  \(score)")
                hudStatusLabel?.stringValue = "DEAD"
                SoundKit.shared.play(.death)
                return
            }
        }

        let pipRect  = CGRect(x: positionX + 6, y: positionY + 6, width: pipW - 12, height: pipH - 12)
        let fullRect = CGRect(x: positionX,     y: positionY,     width: pipW,       height: pipH)

        // --- Block collision ---
        for i in blockEnts.indices where blockEnts[i].layer != nil && !blockEnts[i].hit {
            let bx    = blockEnts[i].worldX - cameraWX + screen.minX
            let by    = blockEnts[i].worldY
            let bRect = CGRect(x: bx, y: by, width: tileSize, height: tileSize)

            if fullRect.intersects(bRect) {
                if velocityY < 0 {
                    blockEnts[i].hit        = true
                    blockEnts[i].layer?.opacity = 0.4
                    score += blockEnts[i].isQ ? 200 : 50
                    SoundKit.shared.play(.score)
                    velocityY = 0
                } else if velocityY > 0 {
                    let prevBottom = (positionY + pipH) - velocityY * dt
                    if prevBottom <= by + 4 {
                        positionY = by - pipH
                        velocityY = 0
                        onGround  = true
                    }
                }
            }
        }

        // --- Goomba collision ---
        for i in goombaEnts.indices where goombaEnts[i].alive && goombaEnts[i].spawned {
            goombaEnts[i].worldX -= Phys.goombaSpd * tileSize * dt

            let gx    = goombaEnts[i].worldX - cameraWX + screen.minX
            let gy    = goombaEnts[i].groundY
            let gRect = CGRect(x: gx, y: gy, width: tileSize, height: tileSize)

            if pipRect.intersects(gRect) {
                let pipBtm   = positionY + pipH
                let goombaMid = gy + tileSize * 0.5
                if velocityY > 0 && pipBtm <= goombaMid + velocityY * dt {
                    goombaEnts[i].alive = false
                    goombaEnts[i].layer?.opacity   = 0.3
                    goombaEnts[i].layer?.transform = CATransform3DMakeScale(1.0, 0.3, 1.0)
                    velocityY = Phys.jumpV * tileSize * 0.5
                    score += 100
                    SoundKit.shared.play(.hit)
                } else {
                    triggerGameOver(message: "GAME OVER  \(score)")
                    hudStatusLabel?.stringValue = "DEAD"
                    SoundKit.shared.play(.death)
                    return
                }
            }
        }

        // --- Coin collection ---
        for i in coinEnts.indices where coinEnts[i].layer != nil && !coinEnts[i].collected {
            let cx    = coinEnts[i].worldX - cameraWX + screen.minX
            let cy    = coinEnts[i].worldY
            let cRect = CGRect(x: cx, y: cy, width: tileSize * 0.8, height: tileSize * 0.8)
            if fullRect.intersects(cRect) {
                coinEnts[i].collected  = true
                coinEnts[i].layer?.isHidden = true
                score     += 200
                coinCount += 1
                SoundKit.shared.play(.score)
            }
        }

        // --- Flagpole check ---
        let flagWorldX  = CGFloat(Lvl.flagpoleCol) * tileSize
        let flagScreenX = flagWorldX - cameraWX + screen.minX
        if flagScreenX <= positionX + pipW / 2 && !levelWon {
            levelWon = true
            winTime  = mach_absolute_time()
            score   += 1000 + Int(timeLeft) * 50   // points + time bonus
            hudStatusLabel?.stringValue = "CLEAR!"
            SoundKit.shared.play(.score)
            print("[Mario] 1-1 complete! score=\(score)")
            return
        }

        // --- Move PiP ---
        let newPos = CGPoint(x: positionX, y: positionY)
        if !movePip(to: newPos) { return }
        let bounds = CGRect(origin: newPos, size: size)

        // --- Spawn / cull ---
        spawnAndCull(screen: screen)

        // --- Update visuals ---
        withTransaction {
            updateGroundVisuals(screen: screen)
            updateEntityVisuals(screen: screen)
            updateBackdrop(screen: screen)
            syncBorder(around: bounds)
        }

        // --- Update HUD ---
        hudScoreLabel?.stringValue = String(format: "%06d", score)
        hudCoinsLabel?.stringValue = String(format: "×%02d", coinCount)
        hudTimeLabel?.stringValue  = String(format: "%03d", Int(timeLeft))
        if timeLeft < 100 {
            hudTimeLabel?.textColor = NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        }
    }

    // MARK: - Spawn / Cull

    private func spawnAndCull(screen: CGRect) {
        guard let root = overlayLayer else { return }
        let viewL = cameraWX - 100
        let viewR = cameraWX + screen.width + 200

        // --- Pipes ---
        for i in pipeEnts.indices {
            let wx = pipeEnts[i].worldX
            if pipeEnts[i].bodyLayer == nil && wx >= viewL && wx <= viewR {
                let body = layerPool.dequeue()
                body.contents = MarioSprites.pipeBodyImage
                body.magnificationFilter = .nearest; body.minificationFilter = .nearest
                body.contentsGravity = .resize
                root.addSublayer(body)
                pipeEnts[i].bodyLayer = body

                let cap = layerPool.dequeue()
                cap.contents = MarioSprites.pipeCapImage
                cap.magnificationFilter = .nearest; cap.minificationFilter = .nearest
                cap.contentsGravity = .resize
                root.addSublayer(cap)
                pipeEnts[i].capLayer = cap
            } else if pipeEnts[i].bodyLayer != nil && wx < viewL - 200 {
                layerPool.enqueue(pipeEnts[i].bodyLayer!)
                layerPool.enqueue(pipeEnts[i].capLayer!)
                pipeEnts[i].bodyLayer = nil; pipeEnts[i].capLayer = nil
            }
        }

        // --- Blocks ---
        for i in blockEnts.indices {
            let wx = blockEnts[i].worldX
            if blockEnts[i].layer == nil && wx >= viewL && wx <= viewR {
                let layer = layerPool.dequeue()
                // Use distinct brick sprite for elevated brick blocks
                layer.contents = blockEnts[i].isQ
                    ? MarioSprites.questionBlockImage
                    : MarioSprites.brickBlockImage
                layer.magnificationFilter = .nearest; layer.minificationFilter = .nearest
                layer.contentsGravity = .resize
                layer.opacity = blockEnts[i].hit ? 0.4 : 1.0
                root.addSublayer(layer)
                blockEnts[i].layer = layer
            } else if blockEnts[i].layer != nil && wx < viewL - 200 {
                layerPool.enqueue(blockEnts[i].layer!)
                blockEnts[i].layer = nil
            }
        }

        // --- Stair blocks ---
        for i in stairEnts.indices {
            let wx = stairEnts[i].worldX
            if stairEnts[i].layer == nil && wx >= viewL && wx <= viewR {
                let layer = layerPool.dequeue()
                layer.contents = MarioSprites.groundTileImage
                layer.magnificationFilter = .nearest; layer.minificationFilter = .nearest
                layer.contentsGravity = .resize
                root.addSublayer(layer)
                stairEnts[i].layer = layer
            } else if stairEnts[i].layer != nil && wx < viewL - 200 {
                layerPool.enqueue(stairEnts[i].layer!)
                stairEnts[i].layer = nil
            }
        }

        // --- Goombas ---
        for i in goombaEnts.indices where goombaEnts[i].alive {
            let wx = goombaEnts[i].spawnX
            if !goombaEnts[i].spawned && wx >= viewL && wx <= viewR {
                let layer = layerPool.dequeue()
                layer.contents = MarioSprites.goombaImage
                layer.magnificationFilter = .nearest; layer.minificationFilter = .nearest
                layer.contentsGravity = .resize
                layer.opacity = 1.0; layer.transform = CATransform3DIdentity
                root.addSublayer(layer)
                goombaEnts[i].layer   = layer
                goombaEnts[i].spawned = true
            } else if goombaEnts[i].spawned, let layer = goombaEnts[i].layer {
                if goombaEnts[i].worldX < viewL - 200 {
                    layerPool.enqueue(layer)
                    goombaEnts[i].layer  = nil
                    goombaEnts[i].alive  = false
                }
            }
        }

        // --- Coins ---
        for i in coinEnts.indices where !coinEnts[i].collected {
            let wx = coinEnts[i].worldX
            if coinEnts[i].layer == nil && wx >= viewL && wx <= viewR {
                let layer = layerPool.dequeue()
                layer.contents = MarioSprites.coinImage
                layer.magnificationFilter = .nearest; layer.minificationFilter = .nearest
                layer.contentsGravity = .resize; layer.isHidden = false
                root.addSublayer(layer)
                coinEnts[i].layer = layer
            } else if coinEnts[i].layer != nil && wx < viewL - 200 {
                layerPool.enqueue(coinEnts[i].layer!)
                coinEnts[i].layer = nil
            }
        }

        // --- Bushes ---
        for i in bushEnts.indices {
            let wx = bushEnts[i].worldX
            if bushEnts[i].layer == nil && wx >= viewL && wx <= viewR {
                let layer = layerPool.dequeue()
                layer.contents = MarioSprites.bushImage
                layer.magnificationFilter = .nearest; layer.minificationFilter = .nearest
                layer.contentsGravity = .resize
                layer.opacity = 1.0
                if let sky = skyLayer { root.insertSublayer(layer, above: sky) }
                else { root.addSublayer(layer) }
                bushEnts[i].layer = layer
            } else if bushEnts[i].layer != nil && wx < viewL - 200 {
                layerPool.enqueue(bushEnts[i].layer!)
                bushEnts[i].layer = nil
            }
        }

        // --- Castle ---
        let castWX = castleWorldX
        if castleLayer == nil && castWX >= viewL && castWX <= viewR {
            let layer = layerPool.dequeue()
            layer.contents = MarioSprites.castleImage
            layer.magnificationFilter = .nearest; layer.minificationFilter = .nearest
            layer.contentsGravity = .resize
            root.addSublayer(layer)
            castleLayer = layer
        } else if castleLayer != nil && castWX < viewL - 500 {
            layerPool.enqueue(castleLayer!)
            castleLayer = nil
        }

        // --- Flagpole + Flag ---
        let flagWX = CGFloat(Lvl.flagpoleCol) * tileSize
        if flagpoleLayer == nil && flagWX >= viewL && flagWX <= viewR {
            let pole = layerPool.dequeue()
            pole.backgroundColor = NSColor(red: 0.0, green: 0.55, blue: 0.0, alpha: 1.0).cgColor
            root.addSublayer(pole)
            flagpoleLayer = pole

            let ball = layerPool.dequeue()
            ball.backgroundColor = NSColor(red: 0.9, green: 0.8, blue: 0.0, alpha: 1.0).cgColor
            ball.cornerRadius = tileSize * 0.3
            root.addSublayer(ball)
            flagpoleBallLayer = ball

            // Flag starts at top of pole
            let poleH   = tileSize * 10
            flagInitY   = CGFloat(Lvl.groundRow) * tileSize - poleH
            flagAXY     = flagInitY

            let fl = layerPool.dequeue()
            fl.contents = MarioSprites.flagImage
            fl.magnificationFilter = .nearest; fl.minificationFilter = .nearest
            fl.contentsGravity = .resize
            root.addSublayer(fl)
            flagLayer = fl
        }

        // Spawn ahead: clouds and hills
        let spawnEdge = cameraWX + screen.width + 300
        if let lastCloud = clouds.last, lastCloud.worldX < spawnEdge {
            spawnCloud(worldX: lastCloud.worldX + CGFloat.random(in: 200...400),
                       screen: screen, root: root)
        }
        if let lastHill = hills.last, lastHill.worldX < spawnEdge {
            spawnHill(worldX: lastHill.worldX + CGFloat.random(in: 300...500),
                      screen: screen, root: root)
        }
    }

    // MARK: - Visual Updates

    private func updateGroundVisuals(screen: CGRect) {
        let tileW    = tileSize
        let tileH    = tileSize / 2
        let offsetX  = cameraWX.truncatingRemainder(dividingBy: tileW)
        let tileRows = Int(ceil((CGFloat(Lvl.rows - Lvl.groundRow) * tileSize) / tileH))
        let tileCols = groundLayers.count / max(tileRows, 1)

        for col in 0..<tileCols {
            let worldCol = Int((cameraWX + CGFloat(col) * tileW) / tileW)
            let isGapCol = Lvl.isGap(worldCol)
            for row in 0..<tileRows {
                let idx = col * tileRows + row
                guard idx < groundLayers.count else { continue }
                groundLayers[idx].frame.origin.x = CGFloat(col) * tileW - offsetX
                groundLayers[idx].isHidden = isGapCol
            }
        }
    }

    private func updateEntityVisuals(screen: CGRect) {
        let pipeCapH  = tileSize * 0.4
        let pipeCapW  = tileSize * 2.2
        let pipeBodyW = tileSize * 1.6

        // Pipes
        for p in pipeEnts {
            guard let body = p.bodyLayer, let cap = p.capLayer else { continue }
            let sx       = p.worldX - cameraWX
            let pipeTopAX = CGFloat(Lvl.groundRow) * tileSize - p.height
            let bodyH     = p.height - pipeCapH

            cap.frame = CGRect(x: sx - (pipeCapW - pipeBodyW) / 2,
                               y: axToNS(y: pipeTopAX, height: pipeCapH),
                               width: pipeCapW, height: pipeCapH)
            body.frame = CGRect(x: sx + (tileSize * 2 - pipeBodyW) / 2,
                                y: axToNS(y: pipeTopAX + pipeCapH, height: bodyH),
                                width: pipeBodyW, height: bodyH)
            let vis = sx > -pipeCapW * 2 && sx < screen.width + 50
            cap.isHidden = !vis; body.isHidden = !vis
        }

        // Blocks (? and brick)
        for b in blockEnts {
            guard let layer = b.layer else { continue }
            let sx = b.worldX - cameraWX
            layer.frame = CGRect(x: sx, y: axToNS(y: b.worldY, height: tileSize),
                                 width: tileSize, height: tileSize)
            layer.isHidden = sx < -tileSize || sx > screen.width + 50
        }

        // Stair blocks
        for s in stairEnts {
            guard let layer = s.layer else { continue }
            let sx = s.worldX - cameraWX
            layer.frame = CGRect(x: sx, y: axToNS(y: s.worldY, height: tileSize),
                                 width: tileSize, height: tileSize)
            layer.isHidden = sx < -tileSize || sx > screen.width + 50
        }

        // Goombas
        for g in goombaEnts where g.layer != nil {
            let sx = g.worldX - cameraWX
            g.layer!.frame = CGRect(x: sx, y: axToNS(y: g.groundY, height: tileSize),
                                    width: tileSize, height: tileSize)
            g.layer!.isHidden = sx < -tileSize || sx > screen.width + 50
        }

        // Coins
        for c in coinEnts where c.layer != nil && !c.collected {
            let sx = c.worldX - cameraWX
            let cs = tileSize * 0.8
            c.layer!.frame = CGRect(x: sx + tileSize * 0.1,
                                    y: axToNS(y: c.worldY, height: cs),
                                    width: cs, height: cs)
            c.layer!.isHidden = sx < -tileSize || sx > screen.width + 50
        }

        // Bushes (sit on ground surface, 1:1 camera scroll)
        let groundNSH = CGFloat(Lvl.rows - Lvl.groundRow) * tileSize
        for b in bushEnts where b.layer != nil {
            let sx  = b.worldX - cameraWX
            let bw  = tileSize * 2.5
            let bh  = tileSize * 1.0
            b.layer!.frame = CGRect(x: sx, y: groundNSH, width: bw, height: bh)
            b.layer!.isHidden = sx < -bw || sx > screen.width + 50
        }

        // Castle (sits on ground, 6×6 tiles)
        if let castle = castleLayer {
            let sx       = castleWorldX - cameraWX
            let castleH  = tileSize * 6
            let castleW  = tileSize * 6
            castle.frame = CGRect(x: sx,
                                  y: axToNS(y: CGFloat(Lvl.groundRow) * tileSize - castleH,
                                            height: castleH),
                                  width: castleW, height: castleH)
            castle.isHidden = sx < -castleW || sx > screen.width + 50
        }

        // Flagpole
        if let pole = flagpoleLayer {
            let fx    = CGFloat(Lvl.flagpoleCol) * tileSize - cameraWX
            let poleW = tileSize * 0.15
            let poleH = tileSize * 10
            let poleTopAX = CGFloat(Lvl.groundRow) * tileSize - poleH
            pole.frame = CGRect(x: fx + tileSize * 0.42,
                                y: axToNS(y: poleTopAX, height: poleH),
                                width: poleW, height: poleH)
        }
        if let ball = flagpoleBallLayer {
            let fx       = CGFloat(Lvl.flagpoleCol) * tileSize - cameraWX
            let ballSize = tileSize * 0.6
            let poleH    = tileSize * 10
            let ballAXY  = CGFloat(Lvl.groundRow) * tileSize - poleH - ballSize / 2
            ball.frame   = CGRect(x: fx + tileSize * 0.2,
                                  y: axToNS(y: ballAXY, height: ballSize),
                                  width: ballSize, height: ballSize)
        }

        // Flag (triangle pennant, slides down on win)
        if let fl = flagLayer {
            let fx     = CGFloat(Lvl.flagpoleCol) * tileSize - cameraWX
            let flagW  = tileSize * 1.5
            let flagH  = tileSize * 1.0
            fl.frame   = CGRect(x: fx + tileSize * 0.12,
                                y: axToNS(y: flagAXY, height: flagH),
                                width: flagW, height: flagH)
            fl.isHidden = fx < -flagW * 2 || fx > screen.width + 50
        }
    }

    private func updateBackdrop(screen: CGRect) {
        // Clouds: slow parallax (0.3x)
        for c in clouds {
            let px = c.worldX - cameraWX * 0.3
            let nsY = screenH - c.worldY - c.layer.frame.height
            c.layer.frame.origin.x = px
            c.layer.frame.origin.y = nsY
            c.layer.isHidden = px < -c.layer.frame.width || px > screen.width + 50
        }

        // Hills: medium parallax (0.6x)
        let groundNSH = CGFloat(Lvl.rows - Lvl.groundRow) * tileSize
        for h in hills {
            let px = h.worldX - cameraWX * 0.6
            h.layer.frame.origin.x = px
            h.layer.frame.origin.y = groundNSH
            h.layer.isHidden = px < -h.layer.frame.width || px > screen.width + 50
        }

        // Cull distant clouds and hills
        clouds.removeAll { c in
            let px = c.worldX - cameraWX * 0.3
            if px < -c.layer.frame.width - 100 { layerPool.enqueue(c.layer); return true }
            return false
        }
        hills.removeAll { h in
            let px = h.worldX - cameraWX * 0.6
            if px < -h.layer.frame.width - 100 { layerPool.enqueue(h.layer); return true }
            return false
        }
    }
}
