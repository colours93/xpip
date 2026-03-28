import Cocoa
import ApplicationServices
import QuartzCore

// MARK: - DoomGame: In-process DDA raycaster with real Doom WAD map data
//
// Parses VERTEXES, LINEDEFS, THINGS from ~/.xpip/wads/*.wad, builds a tile map,
// renders a Wolfenstein-style DDA raycaster into a 320×200 RGBA framebuffer,
// and displays it as CALayer.contents in the PiP overlay — same as every other game.
//
// Controls: arrow keys (move/turn), Ctrl (shoot), Shift (run)
// Requires: bash scripts/get-freedoom.sh

class DoomGame: GameBase {

    // MARK: - Config
    private let FBW  = 320
    private let FBH  = 200
    private let TILE = 64          // Doom world units per tile
    private let FOV  = Double.pi / 3.0   // 60°
    private let MOVE = 3.5         // tiles/sec
    private let TURN = 2.2         // rad/sec

    // MARK: - Overlay
    private var overlayWindow: NSWindow?
    private var viewportLayer: CALayer?

    // MARK: - Framebuffer (320×200 RGBA)
    private var fb = [UInt8](repeating: 0, count: 320 * 200 * 4)

    // MARK: - Map
    private var mapGrid: [[Bool]] = []   // [row=y][col=x], true = wall
    private var mapW = 0
    private var mapH = 0
    private var mapOffX = 0
    private var mapOffY = 0

    // MARK: - Player
    private var px = 0.0   // tile-space position
    private var py = 0.0
    private var pa = 0.0   // angle in radians (0=+x/east, π/2=+y/north)

    // MARK: - Textures: arrays of 16×16 RGBA (1024 bytes each)
    private var wallTextures: [[UInt8]] = []

    // MARK: - Enemies
    private struct Enemy { var tx: Double; var ty: Double; var hp = 2; var dead = false }
    private var enemies: [Enemy] = []

    // MARK: - Input state
    private var prevCtrl = false
    private var shootCD  = 0.0
    private var muzzleT  = 0.0

    // MARK: - Lifecycle
    private var mapLoaded = false
    private var statusOverlay: NSWindow?
    private var statusLabel:   NSTextField?

    // MARK: - GameBase Overrides

    override func onStart(screen: CGRect, pip: PipWindowInfo) {
        timerIntervalMs = 16   // ~60 fps

        setupOverlay(pip: pip)

        if let wadPath = findWAD() {
            showStatus("Loading Doom map…")
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.loadMap(wadPath: wadPath)
            }
        } else {
            showStatus("❌ No WAD found\nRun: bash scripts/get-freedoom.sh")
        }
    }

    override func onStop() {
        overlayWindow?.orderOut(nil); overlayWindow = nil; viewportLayer = nil
        statusOverlay?.orderOut(nil); statusOverlay = nil; statusLabel = nil
    }

    override func gameTick() {
        guard mapLoaded else { return }

        // Keep our window snapped exactly on top of the PiP every frame
        if let f = getPipFrame() {
            let nsY = screenH - f.origin.y - f.height
            let target = NSRect(x: f.origin.x, y: nsY, width: f.width, height: f.height)
            if overlayWindow?.frame != target {
                overlayWindow?.setFrame(target, display: false, animate: false)
                if let cv = overlayWindow?.contentView {
                    viewportLayer?.frame = cv.bounds
                }
            }
        }

        let dt = deltaTime()
        handleInput(dt: dt)
        renderFrame()
        guard let provider = CGDataProvider(data: Data(fb) as CFData),
              let img = CGImage(width: FBW, height: FBH,
                                bitsPerComponent: 8, bitsPerPixel: 32,
                                bytesPerRow: FBW * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                                provider: provider, decode: nil,
                                shouldInterpolate: false, intent: .defaultIntent)
        else { return }
        withTransaction { self.viewportLayer?.contents = img }
    }

    // MARK: - Overlay Setup

    private func setupOverlay(pip: PipWindowInfo) {
        let ax  = pip.bounds
        let nsY = screenH - ax.origin.y - ax.height

        // Small window that sits exactly ON TOP of the PiP — Doom renders inside it
        let ow = createFloatingWindow(frame: NSRect(x: ax.origin.x, y: nsY,
                                                    width: ax.width, height: ax.height))
        ow.level    = NSWindow.Level(rawValue: 104)  // above PiP (layer 103)
        ow.hasShadow = false
        ow.contentView?.wantsLayer = true
        ow.contentView?.layer?.masksToBounds = true
        ow.orderFrontRegardless()
        overlayWindow = ow

        let vl = CALayer()
        vl.frame               = ow.contentView!.bounds
        vl.magnificationFilter = .nearest
        vl.minificationFilter  = .nearest
        ow.contentView?.layer?.addSublayer(vl)
        viewportLayer = vl
        print("[DoomGame] Overlay window over PiP at (\(ax.origin.x),\(nsY)) \(ax.width)×\(ax.height)")
    }

    // MARK: - WAD Discovery

    private func findWAD() -> String? {
        let dir = NSString("~/.xpip/wads").expandingTildeInPath as String
        for name in ["freedoom1.wad", "freedoom2.wad", "doom1.wad", "doom.wad", "doom2.wad"] {
            let p = (dir as NSString).appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        if let items = try? FileManager.default.contentsOfDirectory(atPath: dir),
           let f = items.first(where: { $0.lowercased().hasSuffix(".wad") }) {
            return (dir as NSString).appendingPathComponent(f)
        }
        return nil
    }

    // MARK: - Map Loading (background thread, dispatches to main on finish)

    private func loadMap(wadPath: String) {
        guard let wad = WADReader(url: URL(fileURLWithPath: wadPath)) else {
            DispatchQueue.main.async { self.showStatus("❌ Invalid WAD file") }
            return
        }

        // Load wall textures (16×16 RGBA arrays from flats)
        var textures = DoomWADTextures.loadWallTextures(from: wad) ?? []
        if textures.isEmpty {
            textures = [solidTex(r:180,g:80,b:40), solidTex(r:140,g:60,b:30),
                        solidTex(r:90,g:90,b:120),  solidTex(r:60,g:55,b:80)]
        }

        // Read map lumps — WADReader returns the first occurrence, which is E1M1 / MAP01
        guard let thingData = wad.lump(named: "THINGS"),
              let vertData  = wad.lump(named: "VERTEXES"),
              let lineData  = wad.lump(named: "LINEDEFS") else {
            DispatchQueue.main.async { self.showStatus("❌ WAD missing map lumps") }
            return
        }

        // --- Parse THINGS (10 bytes each: x,y,angle,type,flags) ---
        var playerX = 0, playerY = 0, playerAng = 0, foundPlayer = false
        var monsterPos: [(Int, Int)] = []
        for i in stride(from: 0, to: thingData.count - 9, by: 10) {
            let tx   = Int(thingData.i16(i + 0))
            let ty   = Int(thingData.i16(i + 2))
            let ang  = Int(thingData.u16(i + 4))
            let type = Int(thingData.u16(i + 6))
            if type == 1, !foundPlayer { playerX = tx; playerY = ty; playerAng = ang; foundPlayer = true }
            if type >= 3001 && type <= 3006 { monsterPos.append((tx, ty)) }
        }
        guard foundPlayer else {
            DispatchQueue.main.async { self.showStatus("❌ No player start in WAD") }
            return
        }

        // --- Parse VERTEXES (4 bytes each: x,y Int16 LE) ---
        var vxArr = [Int](), vyArr = [Int]()
        for i in stride(from: 0, to: vertData.count - 3, by: 4) {
            vxArr.append(Int(vertData.i16(i + 0)))
            vyArr.append(Int(vertData.i16(i + 2)))
        }
        guard !vxArr.isEmpty else {
            DispatchQueue.main.async { self.showStatus("❌ No vertices in WAD") }
            return
        }

        // --- Parse LINEDEFS (14 bytes each: v1,v2,flags,special,tag,sn0,sn1 as UInt16/Int16 LE) ---
        struct LD { let v1, v2: Int; let sn1: Int }
        var lds = [LD]()
        for i in stride(from: 0, to: lineData.count - 13, by: 14) {
            lds.append(LD(
                v1:  Int(lineData.u16(i + 0)),
                v2:  Int(lineData.u16(i + 2)),
                sn1: Int(lineData.i16(i + 12))   // -1 = one-sided (solid wall)
            ))
        }

        // --- Build tile grid ---
        let minX = vxArr.min()!; let maxX = vxArr.max()!
        let minY = vyArr.min()!; let maxY = vyArr.max()!
        let offX = minX; let offY = minY
        let gW   = (maxX - minX) / TILE + 2
        let gH   = (maxY - minY) / TILE + 2

        // Start all tiles as floor (false = passable)
        var grid = [[Bool]](repeating: [Bool](repeating: false, count: gW), count: gH)

        // Rasterize one-sided linedefs as wall tiles using Bresenham
        for ld in lds where ld.sn1 == -1 {
            guard ld.v1 < vxArr.count && ld.v2 < vxArr.count else { continue }
            var tx0 = (vxArr[ld.v1] - offX) / TILE;  var ty0 = (vyArr[ld.v1] - offY) / TILE
            let tx1 = (vxArr[ld.v2] - offX) / TILE;  let ty1 = (vyArr[ld.v2] - offY) / TILE
            let ddx = abs(tx1 - tx0); let ddy = abs(ty1 - ty0)
            let sx  = tx0 < tx1 ? 1 : -1; let sy = ty0 < ty1 ? 1 : -1
            var err = ddx - ddy
            while true {
                if tx0 >= 0 && tx0 < gW && ty0 >= 0 && ty0 < gH { grid[ty0][tx0] = true }
                if tx0 == tx1 && ty0 == ty1 { break }
                let e2 = 2 * err
                if e2 > -ddy { err -= ddy; tx0 += sx }
                if e2 <  ddx { err += ddx; ty0 += sy }
            }
        }

        // BFS flood-fill from player tile — mark all reachable floor as visited
        let pTX = max(0, min(gW-1, (playerX - offX) / TILE))
        let pTY = max(0, min(gH-1, (playerY - offY) / TILE))
        var visited = [[Bool]](repeating: [Bool](repeating: false, count: gW), count: gH)
        if !grid[pTY][pTX] {
            var q = [(pTX, pTY)]; var head = 0
            visited[pTY][pTX] = true
            while head < q.count {
                let (cx, cy) = q[head]; head += 1
                for (nx, ny) in [(cx-1,cy),(cx+1,cy),(cx,cy-1),(cx,cy+1)] {
                    guard nx >= 0 && nx < gW && ny >= 0 && ny < gH else { continue }
                    guard !grid[ny][nx] && !visited[ny][nx] else { continue }
                    visited[ny][nx] = true; q.append((nx, ny))
                }
            }
        }

        // Unvisited floor tiles → mark as wall (void/inaccessible areas)
        for y in 0..<gH { for x in 0..<gW {
            if !grid[y][x] && !visited[y][x] { grid[y][x] = true }
        }}

        // Place enemies at reachable tile centers
        var ens: [Enemy] = monsterPos.compactMap { (mx, my) in
            let ex = (mx - offX) / TILE; let ey = (my - offY) / TILE
            guard ex >= 0 && ex < gW, ey >= 0 && ey < gH, !grid[ey][ex] else { return nil }
            return Enemy(tx: Double(ex)+0.5, ty: Double(ey)+0.5)
        }
        if ens.count > 24 { ens = Array(ens.prefix(24)) }

        let ppx = Double(playerX - offX) / Double(TILE)
        let ppy = Double(playerY - offY) / Double(TILE)
        let ppa = Double(playerAng) * .pi / 180.0

        let wallCount = grid.flatMap { $0 }.filter { $0 }.count
        print("[DoomGame] ✅ Map: \(gW)×\(gH) tiles (\(wallCount) walls), player=(\(pTX),\(pTY)), \(ens.count) enemies, \(textures.count) textures")

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.wallTextures = textures
            self.mapGrid  = grid
            self.mapW     = gW;   self.mapH     = gH
            self.mapOffX  = offX; self.mapOffY  = offY
            self.px = ppx; self.py = ppy; self.pa = ppa
            self.enemies  = ens
            self.mapLoaded = true
            self.clearStatus()
        }
    }

    // MARK: - Input

    private func key(_ code: Int) -> Bool {
        CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(code))
    }

    private func handleInput(dt: Double) {
        let up    = key(126); let dn    = key(125)
        let left  = key(123); let right = key(124)
        let ctrl  = key(59)  || key(62)
        let shift = key(56)

        let spd = (shift ? MOVE * 1.7 : MOVE) * dt
        let trn = TURN * dt

        if left  { pa -= trn }
        if right { pa += trn }

        var nx = px, ny = py
        if up { nx += cos(pa)*spd; ny += sin(pa)*spd }
        if dn { nx -= cos(pa)*spd; ny -= sin(pa)*spd }

        let m = 0.25
        if !isWall(nx+m, py) && !isWall(nx-m, py) { px = nx }
        if !isWall(px, ny+m) && !isWall(px, ny-m) { py = ny }

        if ctrl && !prevCtrl { shoot() }
        prevCtrl = ctrl
        if shootCD > 0 { shootCD -= dt }
        if muzzleT > 0 { muzzleT -= dt }
    }

    private func isWall(_ tx: Double, _ ty: Double) -> Bool {
        let ix = Int(tx), iy = Int(ty)
        guard ix >= 0 && ix < mapW && iy >= 0 && iy < mapH else { return true }
        return mapGrid[iy][ix]
    }

    private func shoot() {
        guard shootCD <= 0 else { return }
        shootCD = 0.25; muzzleT = 0.12
        SoundKit.shared.play(.hit)
        for i in enemies.indices where !enemies[i].dead {
            let dx = enemies[i].tx - px, dy = enemies[i].ty - py
            let dist = (dx*dx + dy*dy).squareRoot()
            guard dist < 10 else { continue }
            var diff = atan2(dy, dx) - pa
            while diff >  .pi { diff -= 2 * .pi }
            while diff < -.pi { diff += 2 * .pi }
            if abs(diff) < FOV / 3.5 {
                enemies[i].hp -= 1
                if enemies[i].hp <= 0 { enemies[i].dead = true; score += 100 }
            }
        }
    }

    // MARK: - Render

    private func renderFrame() {
        let w = FBW, h = FBH, half = h / 2

        // Fill ceiling (dark slate) and floor (dark brown)
        for y in 0..<h {
            let (r,g,b): (UInt8,UInt8,UInt8) = y < half ? (42,42,62) : (55,38,18)
            var i = y * w * 4
            for _ in 0..<w { fb[i]=r; fb[i+1]=g; fb[i+2]=b; fb[i+3]=255; i+=4 }
        }

        // Wall raycast — DDA
        var zBuf = [Double](repeating: 1000, count: w)
        let fovH = FOV / 2
        for col in 0..<w {
            let angle = pa - fovH + FOV * Double(col) / Double(w)
            let (rawD, texX, tidx) = castRay(angle: angle)
            let corrD = rawD * cos(angle - pa)   // fisheye correction
            zBuf[col] = corrD
            let wallH = min(Int(Double(h) / max(corrD, 0.01)), h)
            let top   = (h - wallH) / 2
            let shade = max(0.08, 1.0 - corrD / 14.0)
            let tex   = wallTextures[tidx % wallTextures.count]
            let bot   = min(top + wallH, h)
            for y in max(top,0)..<bot {
                let ty = (y - top) * 16 / max(wallH, 1)
                let to = (min(ty,15) * 16 + texX) * 4
                let i  = (y * w + col) * 4
                fb[i]   = UInt8(Double(tex[to])   * shade)
                fb[i+1] = UInt8(Double(tex[to+1]) * shade)
                fb[i+2] = UInt8(Double(tex[to+2]) * shade)
                fb[i+3] = 255
            }
        }

        // Sprites (back-to-front)
        let alive = enemies.filter { !$0.dead }
            .sorted { ($0.tx-px)*($0.tx-px)+($0.ty-py)*($0.ty-py) >
                      ($1.tx-px)*($1.tx-px)+($1.ty-py)*($1.ty-py) }
        for e in alive { drawSprite(tx: e.tx, ty: e.ty, zBuf: zBuf) }

        if muzzleT > 0 { drawMuzzleFlash() }
        drawCrosshair()
    }

    private func castRay(angle: Double) -> (dist: Double, texX: Int, texIdx: Int) {
        let ca = cos(angle), sa = sin(angle)
        let ddx = abs(1.0 / (ca == 0 ? 1e-30 : ca))
        let ddy = abs(1.0 / (sa == 0 ? 1e-30 : sa))
        var mx = Int(px), my = Int(py)
        let sx = ca >= 0 ? 1 : -1;  let sy = sa >= 0 ? 1 : -1
        var sdx = ca >= 0 ? (Double(mx+1)-px)*ddx : (px-Double(mx))*ddx
        var sdy = sa >= 0 ? (Double(my+1)-py)*ddy : (py-Double(my))*ddy
        var side = 0

        for _ in 0..<60 {
            if sdx < sdy { sdx += ddx; mx += sx; side = 0 }
            else          { sdy += ddy; my += sy; side = 1 }
            guard mx >= 0 && mx < mapW && my >= 0 && my < mapH else { return (60, 0, 0) }
            if mapGrid[my][mx] { break }
        }

        let dist = max(side == 0 ? sdx - ddx : sdy - ddy, 0.01)
        var wx   = side == 0 ? py + dist*sa : px + dist*ca
        wx -= floor(wx)
        var texX = Int(wx * 16)
        if side == 0 && ca < 0 { texX = 15 - texX }
        if side == 1 && sa > 0 { texX = 15 - texX }
        texX = max(0, min(15, texX))
        var tidx = ((mx &+ my) & 0x7FFF) % max(wallTextures.count, 1)
        if side == 1 { tidx = (tidx + 1) % max(wallTextures.count, 1) }   // slightly darker NS walls
        return (dist, texX, tidx)
    }

    private func drawSprite(tx: Double, ty: Double, zBuf: [Double]) {
        let w = FBW, h = FBH
        let dx = tx - px, dy = ty - py
        let dist = (dx*dx + dy*dy).squareRoot()
        guard dist > 0.5 && dist < 16 else { return }
        var diff = atan2(dy, dx) - pa
        while diff >  .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        guard abs(diff) < FOV * 0.75 else { return }
        let sh = min(Int(Double(h) / dist), h), sw = sh
        let sx0 = Int(Double(w) * (0.5 + diff/FOV)) - sw/2
        let sy0 = (h - sh) / 2
        let shade = max(0.15, 1.0 - dist/12.0)
        for sx in 0..<sw {
            let col = sx0 + sx
            guard col >= 0 && col < w && zBuf[col] > dist else { continue }
            for sy in 0..<sh {
                let row = sy0 + sy
                guard row >= 0 && row < h else { continue }
                let i = (row * w + col) * 4
                fb[i]   = UInt8(min(255.0, 200.0 * shade))
                fb[i+1] = UInt8(min(255.0, 70.0  * shade))
                fb[i+2] = UInt8(min(255.0, 50.0  * shade))
                fb[i+3] = 255
            }
        }
    }

    private func drawMuzzleFlash() {
        let cx = FBW/2, cy = FBH - 34, r = 15
        for y in max(0,cy-r)..<min(FBH,cy+r) {
            for x in max(0,cx-r)..<min(FBW,cx+r) {
                if (x-cx)*(x-cx) + (y-cy)*(y-cy) < r*r {
                    let i = (y*FBW+x)*4
                    fb[i]   = UInt8(min(255, Int(fb[i])   + 140))
                    fb[i+1] = UInt8(min(255, Int(fb[i+1]) + 110))
                    fb[i+2] = UInt8(min(255, Int(fb[i+2]) + 20))
                }
            }
        }
    }

    private func drawCrosshair() {
        let cx = FBW/2, cy = FBH/2
        for d in -4...4 {
            let x1 = cx+d; if x1 >= 0 && x1 < FBW { let i=(cy*FBW+x1)*4; fb[i]=210;fb[i+1]=210;fb[i+2]=210;fb[i+3]=255 }
            let y1 = cy+d; if y1 >= 0 && y1 < FBH { let i=(y1*FBW+cx)*4; fb[i]=210;fb[i+1]=210;fb[i+2]=210;fb[i+3]=255 }
        }
    }

    // MARK: - Texture helpers

    private func solidTex(r: UInt8, g: UInt8, b: UInt8) -> [UInt8] {
        var t = [UInt8](repeating: 255, count: 16*16*4)
        for i in 0..<(16*16) {
            let dark = (i/16 + i%16) % 3 == 0    // slight checkerboard shading
            let o = i*4
            t[o]   = dark ? UInt8(max(0, Int(r)-30)) : r
            t[o+1] = dark ? UInt8(max(0, Int(g)-30)) : g
            t[o+2] = dark ? UInt8(max(0, Int(b)-30)) : b
        }
        return t
    }

    // MARK: - Status overlay

    private func showStatus(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.statusOverlay == nil { self.makeStatusOverlay() }
            self.statusLabel?.stringValue = text
            self.statusOverlay?.orderFrontRegardless()
        }
    }

    private func clearStatus() {
        DispatchQueue.main.async { [weak self] in self?.statusOverlay?.orderOut(nil) }
    }

    private func makeStatusOverlay() {
        let wf  = overlayWindow?.frame ?? CGRect(x: 100, y: 400, width: 320, height: 150)
        let ow  = createFloatingWindow(frame: NSRect(x: wf.midX-140, y: wf.midY-40, width: 280, height: 80))
        ow.backgroundColor = NSColor(white: 0.07, alpha: 0.92)
        ow.isOpaque = false; ow.level = .floating
        ow.level = NSWindow.Level(rawValue: 105)
        ow.contentView?.wantsLayer = true
        ow.contentView?.layer?.cornerRadius = 10
        ow.orderFrontRegardless()
        let lbl = NSTextField(frame: NSRect(x:12, y:0, width:256, height:80))
        lbl.isEditable = false; lbl.isBordered = false; lbl.drawsBackground = false
        lbl.alignment = .center; lbl.maximumNumberOfLines = 3; lbl.textColor = .white
        lbl.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        ow.contentView?.addSubview(lbl)
        statusOverlay = ow; statusLabel = lbl
    }
}

// MARK: - Data: little-endian reads

private extension Data {
    func i16(_ off: Int) -> Int16 {
        Int16(bitPattern: UInt16(self[off]) | (UInt16(self[off+1]) << 8))
    }
    func u16(_ off: Int) -> UInt16 {
        UInt16(self[off]) | (UInt16(self[off+1]) << 8)
    }
}
