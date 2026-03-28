import Cocoa

// MARK: - Ghost Mode

enum GhostMode {
    case inHouse    // Bobbing in house, not yet released
    case exiting    // Navigating from house up through the gate
    case scatter    // Patrolling assigned corner
    case chase      // Hunting Pac-Man with personality-specific targeting
    case frightened // Scared — random movement, edible
    case eaten      // Eyes only — racing back to ghost house
}

// MARK: - Ghost State

struct GhostState {
    var col: CGFloat
    var row: CGFloat
    var dir: Int            // 0=right 1=down 2=left 3=up
    var layer: CALayer
    var colorIndex: Int     // 0=Blinky 1=Pinky 2=Inky 3=Clyde
    var mode: GhostMode
    var released: Bool      // cleared to leave house
    var personalDots: Int   // personal dot-counter for house release
    // Track last cell where direction was chosen — prevents re-deciding every tick
    var lastDecisionCol: Int = -1
    var lastDecisionRow: Int = -1
}

// MARK: - GhostDirector

/// Owns all four ghost AIs. Implements the full classic Pac-Man ghost behaviour:
/// scatter/chase mode schedule, individual chase targets (Blinky direct, Pinky 4-ahead,
/// Inky pincer, Clyde shy), frightened random walk, eaten return-to-house, personal
/// dot-counter + force-release, no-up intersections, and Elroy speed boost for Blinky.
class GhostDirector {

    // MARK: - Public

    var ghosts: [GhostState] = []
    var frightened = false
    var frightenTimer: CGFloat = 0
    var frightenDuration: CGFloat = 7.0  // Set by PacManGame per level

    // MARK: - Grid Config

    private let gridCols: Int
    private let gridRows: Int
    private let tunnelRow: Int
    private let houseExitCol: CGFloat = 13
    private let houseExitRow: CGFloat = 9
    private let dirDelta: [(dc: Int, dr: Int)] = [(1,0),(0,1),(-1,0),(0,-1)]

    // Scatter corner targets — Blinky, Pinky, Inky, Clyde
    private let scatterTargets: [(col: CGFloat, row: CGFloat)] = [
        (27, 0), (0, 0), (27, 30), (0, 30)
    ]

    // Four intersections where ghosts may NOT choose "up" (classic arcade rule)
    // Prevents ghosts from short-circuiting certain corridors
    private let noUpTiles: Set<String> = ["6_8", "21_8", "6_26", "21_26"]

    // MARK: - Mode Schedule
    // Phase durations vary by level — we pick the right one in setup()
    private let scheduleL1: [(scatter: Bool, duration: CGFloat)] = [
        (true, 7), (false, 20), (true, 7), (false, 20),
        (true, 5), (false, 20), (true, 5), (false, CGFloat.greatestFiniteMagnitude),
    ]
    private let scheduleL2: [(scatter: Bool, duration: CGFloat)] = [
        (true, 7), (false, 20), (true, 7), (false, 20),
        (true, 5), (false, CGFloat.greatestFiniteMagnitude),
    ]
    private let scheduleL5: [(scatter: Bool, duration: CGFloat)] = [
        (true, 5), (false, 20), (true, 5), (false, 20),
        (true, 5), (false, CGFloat.greatestFiniteMagnitude),
    ]
    private var modeSchedule: [(scatter: Bool, duration: CGFloat)] = []
    private var modeIndex = 0
    private var modeTimer: CGFloat = 0
    private var globalScatter = true   // current global mode

    // MARK: - Release System
    // Personal dot limits per ghost (level 1 values; Blinky & Pinky = 0 → instant)
    private let personalDotLimits = [0, 0, 30, 60]
    // Which ghost is currently the "active" dot counter (Pinky→Inky→Clyde in order)
    private var activeDotGhost = 1

    // Force-release timer: if Pac-Man stops eating for 4 s, release the next ghost anyway
    private var lastDotEatenTime: CGFloat = 0
    private var forceReleaseInterval: CGFloat = 4.0
    private var forceReleaseActive = false

    // MARK: - Elroy Mode (Blinky speed boost when dots run low)
    private var elroy1Threshold = 20   // Dots remaining at which Elroy 1 activates
    private var elroy2Threshold = 10   // Dots remaining at which Elroy 2 activates

    // MARK: - Speeds
    var normalSpeed: CGFloat = 2.8
    var frightenedSpeed: CGFloat = 1.8
    var eatenSpeed:      CGFloat { normalSpeed * 2.2 }
    var elroy1Speed:     CGFloat { normalSpeed * 1.22 }
    var elroy2Speed:     CGFloat { normalSpeed * 1.50 }

    // MARK: - Internal Time
    private var gameTime: CGFloat = 0

    // MARK: - Init

    init(gridCols: Int, gridRows: Int, tunnelRow: Int) {
        self.gridCols  = gridCols
        self.gridRows  = gridRows
        self.tunnelRow = tunnelRow
    }

    // MARK: - Setup / Reset

    func setup(ghosts: [GhostState], totalDots: Int, level: Int) {
        self.ghosts    = ghosts
        frightened     = false
        frightenTimer  = 0
        gameTime       = 0
        modeIndex      = 0
        modeTimer      = 0
        globalScatter  = true
        activeDotGhost = 1
        lastDotEatenTime = 0
        forceReleaseActive = false

        // Pick mode schedule
        if level >= 5 { modeSchedule = scheduleL5 }
        else if level >= 2 { modeSchedule = scheduleL2 }
        else { modeSchedule = scheduleL1 }

        // Elroy thresholds scale with level
        let e1 = [20, 30, 40, 40, 40, 50, 50, 50, 60, 60]
        let e2 = [10, 15, 20, 20, 20, 25, 25, 25, 30, 30]
        let li = min(level - 1, e1.count - 1)
        elroy1Threshold = e1[li]
        elroy2Threshold = e2[li]

        // Release Blinky and Pinky immediately (personal limit 0)
        for i in 0..<self.ghosts.count where personalDotLimits[i] == 0 {
            self.ghosts[i].released = true
            if self.ghosts[i].mode == .inHouse { self.ghosts[i].mode = .exiting }
        }
    }

    // MARK: - Dot Eaten Notification

    /// Call every time Pac-Man eats a dot. Drives the personal dot counter release system.
    func dotEaten(gameTime: CGFloat) {
        lastDotEatenTime = gameTime
        forceReleaseActive = false

        // Personal counter: only tick for the current "active" ghost in the queue
        guard activeDotGhost < ghosts.count else { return }
        let i = activeDotGhost
        guard ghosts[i].mode == .inHouse, !ghosts[i].released else {
            advanceActiveDotGhost()
            return
        }
        ghosts[i].personalDots += 1
        if ghosts[i].personalDots >= personalDotLimits[i] {
            ghosts[i].released = true
            advanceActiveDotGhost()
        }
    }

    private func advanceActiveDotGhost() {
        activeDotGhost += 1
        while activeDotGhost < ghosts.count && ghosts[activeDotGhost].released {
            activeDotGhost += 1
        }
    }

    // MARK: - Power Pellet

    /// Call when Pac-Man eats a power pellet.
    func activateFrightened() {
        frightened    = true
        frightenTimer = frightenDuration

        for i in 0..<ghosts.count {
            switch ghosts[i].mode {
            case .scatter, .chase:
                ghosts[i].mode = .frightened
                ghosts[i].dir  = (ghosts[i].dir + 2) % 4  // immediate reverse
            default: break  // house/exiting/eaten unaffected
            }
        }
    }

    // MARK: - Eat a Scared Ghost

    /// Returns true if the ghost at index i was edible and is now eaten.
    @discardableResult
    func eatGhost(index i: Int) -> Bool {
        guard ghosts[i].mode == .frightened else { return false }
        ghosts[i].mode = .eaten
        return true
    }

    // MARK: - Main Update

    func update(dt: CGFloat, maze: [[Int]],
                playerCol: CGFloat, playerRow: CGFloat, playerDir: Int,
                dotsRemaining: Int, gameTime: CGFloat) {
        self.gameTime = gameTime

        // ── Frightened countdown ──────────────────────────────────────────────
        if frightened {
            frightenTimer -= dt
            if frightenTimer <= 0 {
                frightened = false
                for i in 0..<ghosts.count {
                    if ghosts[i].mode == .frightened {
                        ghosts[i].mode = globalScatter ? .scatter : .chase
                    }
                }
            }
        }

        // ── Global scatter/chase schedule ─────────────────────────────────────
        // Mode timer pauses while frightened (classic arcade behaviour)
        if !frightened { updateGlobalMode(dt: dt) }

        // ── Time-based ghost release (fallback) ────────────────────────────────
        updateTimeRelease(gameTime: gameTime)

        // ── Force-release if Pac-Man hasn't eaten in 4 s ─────────────────────
        if gameTime - lastDotEatenTime >= forceReleaseInterval {
            if !forceReleaseActive {
                forceReleaseActive = true
                releaseNextHouseGhost()
            }
        } else {
            forceReleaseActive = false
        }

        // ── Move each ghost ───────────────────────────────────────────────────
        for i in 0..<ghosts.count {
            moveGhost(index: i, dt: dt, maze: maze,
                      playerCol: playerCol, playerRow: playerRow, playerDir: playerDir,
                      dotsRemaining: dotsRemaining)
        }
    }

    // MARK: - Collision Query (call from PacManGame)

    /// Returns whether ghost[i] is collidable (not inHouse / exiting / eaten).
    func isCollidable(index i: Int) -> Bool {
        switch ghosts[i].mode {
        case .inHouse, .exiting, .eaten: return false
        default: return true
        }
    }

    // MARK: - Private: Release Helpers

    private func updateTimeRelease(gameTime: CGFloat) {
        // Secondary release: time gates that back-stop the dot counter
        let timeLimits: [CGFloat] = [0, 5, 10, 15]
        for i in 0..<ghosts.count {
            if !ghosts[i].released && gameTime >= timeLimits[i] {
                ghosts[i].released = true
                advanceActiveDotGhost()
            }
        }
        // Transition inHouse → exiting for anything that just got released
        for i in 0..<ghosts.count {
            if ghosts[i].mode == .inHouse && ghosts[i].released {
                ghosts[i].mode = .exiting
            }
        }
    }

    private func releaseNextHouseGhost() {
        for i in 0..<ghosts.count {
            if ghosts[i].mode == .inHouse && !ghosts[i].released {
                ghosts[i].released = true
                advanceActiveDotGhost()
                return
            }
        }
    }

    // MARK: - Private: Mode Schedule

    private func updateGlobalMode(dt: CGFloat) {
        guard modeIndex < modeSchedule.count else { return }
        let phase = modeSchedule[modeIndex]
        modeTimer += dt
        if !phase.duration.isInfinite && modeTimer >= phase.duration {
            modeTimer = 0
            modeIndex += 1
            if modeIndex < modeSchedule.count {
                let newScatter = modeSchedule[modeIndex].scatter
                // Reverse all active (scatter/chase) ghosts
                for i in 0..<ghosts.count {
                    switch ghosts[i].mode {
                    case .scatter, .chase:
                        ghosts[i].mode = newScatter ? .scatter : .chase
                        ghosts[i].dir  = (ghosts[i].dir + 2) % 4
                    default: break
                    }
                }
                globalScatter = newScatter
            }
        } else {
            globalScatter = phase.scatter
        }
    }

    // MARK: - Private: Movement Dispatch

    private func moveGhost(index i: Int, dt: CGFloat, maze: [[Int]],
                           playerCol: CGFloat, playerRow: CGFloat, playerDir: Int,
                           dotsRemaining: Int) {
        switch ghosts[i].mode {
        case .inHouse:   bobInHouse(index: i)
        case .exiting:   exitHouse(index: i, dt: dt)
        case .eaten:     returnToHouse(index: i, dt: dt)
        default:
            moveOnMaze(index: i, dt: dt, maze: maze,
                       playerCol: playerCol, playerRow: playerRow,
                       playerDir: playerDir, dotsRemaining: dotsRemaining)
        }
    }

    // MARK: - Private: In-House Bob

    private func bobInHouse(index i: Int) {
        let baseCols: [CGFloat] = [13, 13, 11, 15]
        let baseRows: [CGFloat] = [9,  13, 13, 13]
        ghosts[i].col = baseCols[i]
        ghosts[i].row = baseRows[i] + sin(gameTime * 2.2 + CGFloat(i) * 1.6) * 0.28
        // Transition check (time-based release sets .released then mode stays .inHouse
        // until updateTimeRelease flips it to .exiting — both run in the same tick)
        if ghosts[i].released { ghosts[i].mode = .exiting }
    }

    // MARK: - Private: Exit House

    private func exitHouse(index i: Int, dt: CGFloat) {
        let dist = distance(ghosts[i].col, ghosts[i].row, houseExitCol, houseExitRow)
        if dist < 0.5 {
            ghosts[i].col  = houseExitCol
            ghosts[i].row  = houseExitRow
            ghosts[i].dir  = 2   // head left onto the main maze
            ghosts[i].mode = globalScatter ? .scatter : .chase
            ghosts[i].lastDecisionCol = -1   // force direction pick on first maze cell
            ghosts[i].lastDecisionRow = -1
            return
        }
        // Navigate: centre horizontally on col 13, then drive up
        let colErr = ghosts[i].col - houseExitCol
        if abs(colErr) > 0.3 {
            ghosts[i].col -= colErr.sign * normalSpeed * dt
        } else {
            ghosts[i].col  = houseExitCol
            ghosts[i].row -= normalSpeed * dt
        }
    }

    // MARK: - Private: Return to House (Eaten)

    private func returnToHouse(index i: Int, dt: CGFloat) {
        // Target: centre of ghost house (col 13, row 13)
        let tC: CGFloat = 13, tR: CGFloat = 13
        let dist = distance(ghosts[i].col, ghosts[i].row, tC, tR)
        if dist < 0.5 {
            ghosts[i].col  = tC; ghosts[i].row = tR
            ghosts[i].mode = .inHouse
            ghosts[i].released = true   // will immediately begin exiting again
            ghosts[i].lastDecisionCol = -1
            ghosts[i].lastDecisionRow = -1
            return
        }
        // Straight-line rush through walls (eyes can pass through anything)
        let speed = eatenSpeed * dt
        let dx = tC - ghosts[i].col, dy = tR - ghosts[i].row
        let mag = hypot(dx, dy)
        if mag > 0 {
            ghosts[i].col += (dx / mag) * speed
            ghosts[i].row += (dy / mag) * speed
        }
    }

    // MARK: - Private: Maze Movement (Scatter / Chase / Frightened)

    private func moveOnMaze(index i: Int, dt: CGFloat, maze: [[Int]],
                             playerCol: CGFloat, playerRow: CGFloat,
                             playerDir: Int, dotsRemaining: Int) {
        let gC = Int(round(ghosts[i].col))
        let gR = Int(round(ghosts[i].row))

        // At a new cell centre — choose next direction (only once per cell)
        let isNewCell = gC != ghosts[i].lastDecisionCol || gR != ghosts[i].lastDecisionRow
        if isNewCell &&
           abs(ghosts[i].col - CGFloat(gC)) < 0.25 &&
           abs(ghosts[i].row - CGFloat(gR)) < 0.25 {

            ghosts[i].col = CGFloat(gC)
            ghosts[i].row = CGFloat(gR)
            ghosts[i].lastDecisionCol = gC
            ghosts[i].lastDecisionRow = gR

            let reverse = (ghosts[i].dir + 2) % 4
            let noUp    = noUpTiles.contains("\(gC)_\(gR)")
            var options: [Int] = []

            for dir in 0..<4 {
                if dir == reverse { continue }            // cannot reverse
                if dir == 3 && noUp { continue }          // no-up tile rule
                let nc = gC + dirDelta[dir].dc
                let nr = gR + dirDelta[dir].dr
                guard isWalkable(nc, nr, maze: maze) else { continue }
                // Prevent re-entering ghost house from outside
                if nc >= 0, nc < gridCols, nr >= 0, nr < gridRows {
                    let v = maze[nr][nc]
                    if v == 4 || v == 5 { continue }
                }
                options.append(dir)
            }

            // Fallback: allow reverse if genuinely stuck (dead end)
            if options.isEmpty {
                let nc = gC + dirDelta[reverse].dc
                let nr = gR + dirDelta[reverse].dr
                if isWalkable(nc, nr, maze: maze) { options.append(reverse) }
            }

            if !options.isEmpty {
                if ghosts[i].mode == .frightened {
                    // Frightened: random valid direction (still no reversing)
                    ghosts[i].dir = options.randomElement()!
                } else {
                    // Chase / Scatter: choose direction closest to target tile
                    let target = computeTarget(index: i, playerCol: playerCol,
                                               playerRow: playerRow, playerDir: playerDir)
                    var bestDir = options[0], bestDist: CGFloat = .greatestFiniteMagnitude
                    for dir in options {
                        let nc = gC + dirDelta[dir].dc
                        let nr = gR + dirDelta[dir].dr
                        let d  = distance(CGFloat(nc), CGFloat(nr), target.x, target.y)
                        if d < bestDist { bestDist = d; bestDir = dir }
                    }
                    ghosts[i].dir = bestDir
                }
            }
        }

        // Compute speed — Elroy applies only to Blinky in scatter/chase
        let spd: CGFloat
        if ghosts[i].mode == .frightened {
            spd = frightenedSpeed * dt
        } else if i == 0 {
            if dotsRemaining <= elroy2Threshold      { spd = elroy2Speed * dt }
            else if dotsRemaining <= elroy1Threshold { spd = elroy1Speed * dt }
            else                                     { spd = normalSpeed * dt }
        } else {
            spd = normalSpeed * dt
        }

        let d    = dirDelta[ghosts[i].dir]
        let newC = ghosts[i].col + CGFloat(d.dc) * spd
        let newR = ghosts[i].row + CGFloat(d.dr) * spd

        // Tunnel wrap
        if gR == tunnelRow {
            if newC < -1 { ghosts[i].col = CGFloat(gridCols); return }
            if newC > CGFloat(gridCols) { ghosts[i].col = -1; return }
        }

        // Validate target cell — no walking back into ghost house
        let ckC = Int(round(newC)), ckR = Int(round(newR))
        if isWalkable(ckC, ckR, maze: maze) {
            if ckC >= 0, ckC < gridCols, ckR >= 0, ckR < gridRows, maze[ckR][ckC] == 4 {
                ghosts[i].col = CGFloat(gC); ghosts[i].row = CGFloat(gR)
                return
            }
            ghosts[i].col = newC; ghosts[i].row = newR
        } else {
            ghosts[i].col = CGFloat(gC); ghosts[i].row = CGFloat(gR)
        }
    }

    // MARK: - Private: Target Computation

    private func computeTarget(index i: Int,
                                playerCol: CGFloat, playerRow: CGFloat,
                                playerDir: Int) -> CGPoint {
        if ghosts[i].mode == .scatter {
            return CGPoint(x: scatterTargets[i].col, y: scatterTargets[i].row)
        }
        switch i {
        case 0:  // Blinky — direct pursuit
            return CGPoint(x: playerCol, y: playerRow)

        case 1:  // Pinky — 4 tiles ahead (+ classic up-bug: also 4 left when facing up)
            let d = dirDelta[playerDir]
            var tC = playerCol + CGFloat(d.dc) * 4
            let tR = playerRow + CGFloat(d.dr) * 4
            if playerDir == 3 { tC -= 4 }   // faithful up-overflow bug
            return CGPoint(x: tC, y: tR)

        case 2:  // Inky — vector from Blinky through "2 ahead", doubled
            let d  = dirDelta[playerDir]
            let aC = playerCol + CGFloat(d.dc) * 2
            let aR = playerRow + CGFloat(d.dr) * 2
            return CGPoint(x: 2 * aC - ghosts[0].col, y: 2 * aR - ghosts[0].row)

        case 3:  // Clyde — chases when far (> 8 tiles), retreats when close
            let dist = distance(ghosts[3].col, ghosts[3].row, playerCol, playerRow)
            if dist > 8 { return CGPoint(x: playerCol, y: playerRow) }
            return CGPoint(x: scatterTargets[3].col, y: scatterTargets[3].row)

        default:
            return CGPoint(x: playerCol, y: playerRow)
        }
    }

    // MARK: - Private: Helpers

    private func isWalkable(_ col: Int, _ row: Int, maze: [[Int]]) -> Bool {
        guard col >= 0, col < gridCols, row >= 0, row < gridRows else {
            return row == tunnelRow && (col < 0 || col >= gridCols)
        }
        return maze[row][col] != 0
    }

    @inline(__always)
    private func distance(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> CGFloat {
        hypot(x1 - x2, y1 - y2)
    }
}

// MARK: - CGFloat sign helper
private extension CGFloat {
    var sign: CGFloat { self >= 0 ? 1 : -1 }
}
