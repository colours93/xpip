import Cocoa

/// Parses a Super Mario Bros. 1 NES ROM (iNES format) to extract
/// authentic pixel-art sprites and W1-1 level layout data.
///
/// Place the ROM at: ~/.xpip/roms/smb1.nes
///
/// iNES layout for SMB1 (US, PRG×2 + CHR×1):
///   0x0000–0x000F  16-byte header
///   0x0010–0x400F  PRG ROM bank 0  (CPU $8000–$BFFF)
///   0x4010–0x800F  PRG ROM bank 1  (CPU $C000–$FFFF)
///   0x8010–0x900F  CHR ROM         (PPU $0000–$1FFF, 512 tiles)
///
/// CHR sub-banks:
///   $0000–$0FFF  Background tiles  (CHR index 0–255)
///   $1000–$1FFF  Sprite tiles      (CHR index 256–511)
///
/// Each 8×8 tile = 16 bytes (2bpp):
///   Bytes 0–7   Bit-plane 0 (LSB of 2-bit palette index)
///   Bytes 8–15  Bit-plane 1 (MSB of 2-bit palette index)
///   pixel = ((p0_row >> (7-x)) & 1) | (((p1_row >> (7-x)) & 1) << 1)
///   pixel 0 = transparent/background colour
///
/// W1-1 data offsets (file-relative):
///   0x269E  L_GroundArea6  area object list
///   0x1F11  E_GroundArea6  enemy object list
final class SMBRomParser {

    // MARK: - Singleton

    static let shared = SMBRomParser()

    // MARK: - iNES / CHR constants

    private static let headerSize    = 16
    private static let prgBankBytes  = 0x4000   // 16 KB
    private static let chrBankBytes  = 0x2000   // 8 KB  = 512 tiles
    private static let tileBytes     = 16       // bytes per 8×8 CHR tile
    private static let tilesInCHR    = 512      // tiles in one 8 KB CHR bank

    // MARK: - SMB1 file offsets

    static let w11AreaObjectsOffset  = 0x269E   // L_GroundArea6
    static let w11EnemyObjectsOffset = 0x1F11   // E_GroundArea6

    // MARK: - SMB1 CHR tile indices
    // Background bank  (PPU $0000, CHR 0–255)

    private enum BG {
        static let brickTL   = 0x45   // Brick block top-left  8×8
        static let brickBL   = 0x47   // Brick block bot-left  8×8
        static let qBlock0   = 0x53   // ? block frame 0 (used for entire 16×16)
        static let qBlock1   = 0x54   // ? block frame 1
        static let blockHit  = 0x57   // Used / hit block
        static let pipeCapL  = 0x60   // Pipe top-cap left  half
        static let pipeCapR  = 0x61   // Pipe top-cap right half
        static let pipeBodyL = 0x62   // Pipe body left  half
        static let pipeBodyR = 0x63   // Pipe body right half
        static let coin      = 0x6A   // Coin tile
        static let groundTop = 0x24   // Ground-top tile (approx)
    }

    // Sprite bank  (PPU $1000, CHR 256–511)
    private enum SPR {
        // Goomba walk frame 1 (metasprite: 4 tiles, left-to-right, top-to-bottom)
        static let goombaTL  = 0x70   // sprite-bank index → CHR = 256 + 0x70 = 368
        static let goombaTR  = 0x71
        static let goombaBL  = 0x72
        static let goombaBR  = 0x73
    }

    // MARK: - NES 64-colour system palette (ARGB)
    // Calibrated so: $17=#C84C0C (ground) $1A≈#00AB00 (pipe) $22=#5C94FC (sky) $27=#FC9838 (? block)

    static let nesColors: [UInt32] = [
        /*$00*/0xFF757575, /*$01*/0xFF271B8F, /*$02*/0xFF0000AB, /*$03*/0xFF47009F,
        /*$04*/0xFF8F0077, /*$05*/0xFFAB0013, /*$06*/0xFFA70000, /*$07*/0xFF7F0B00,
        /*$08*/0xFF432F00, /*$09*/0xFF004700, /*$0A*/0xFF005100, /*$0B*/0xFF003F17,
        /*$0C*/0xFF1B3F5F, /*$0D*/0xFF000000, /*$0E*/0xFF000000, /*$0F*/0xFF000000,
        /*$10*/0xFFBCBCBC, /*$11*/0xFF0073EF, /*$12*/0xFF233BEF, /*$13*/0xFF8300F3,
        /*$14*/0xFFBF00BF, /*$15*/0xFFE7005B, /*$16*/0xFFDB2B00, /*$17*/0xFFC84C0C,
        /*$18*/0xFF8B7300, /*$19*/0xFF009700, /*$1A*/0xFF00AB00, /*$1B*/0xFF00933B,
        /*$1C*/0xFF00838B, /*$1D*/0xFF000000, /*$1E*/0xFF000000, /*$1F*/0xFF000000,
        /*$20*/0xFFFFFFFF, /*$21*/0xFF3FBFFF, /*$22*/0xFF5C94FC, /*$23*/0xFF9F78FF,
        /*$24*/0xFFFF73FF, /*$25*/0xFFFF73C7, /*$26*/0xFFFF7763, /*$27*/0xFFFC9838,
        /*$28*/0xFFD7CF00, /*$29*/0xFF79E700, /*$2A*/0xFF43F32B, /*$2B*/0xFF1BDF91,
        /*$2C*/0xFF17DBD7, /*$2D*/0xFF3C3C3C, /*$2E*/0xFF000000, /*$2F*/0xFF000000,
        /*$30*/0xFFFFFFFF, /*$31*/0xFFA7EBFF, /*$32*/0xFFB7B7FF, /*$33*/0xFFD7ABFF,
        /*$34*/0xFFFFABFF, /*$35*/0xFFFFABD7, /*$36*/0xFFFFB7B3, /*$37*/0xFFFFD79B,
        /*$38*/0xFFE7E78B, /*$39*/0xFFABF38B, /*$3A*/0xFF8BEFAB, /*$3B*/0xFF8BF7D7,
        /*$3C*/0xFF00B7F7, /*$3D*/0xFFAFAFAF, /*$3E*/0xFF000000, /*$3F*/0xFF000000,
    ]

    // MARK: - SMB1 overworld palettes (NES colour indices; -1 = transparent)

    static let palGround:  [Int] = [-1, 0x17, 0x27, 0x0F]   // brick / ground
    static let palPipe:    [Int] = [-1, 0x1A, 0x29, 0x0F]   // green pipe
    static let palQBlock:  [Int] = [-1, 0x27, 0x17, 0x0F]   // ? block orange
    static let palGoomba:  [Int] = [-1, 0x28, 0x16, 0x01]   // goomba brown
    static let palCoin:    [Int] = [-1, 0x27, 0x28, 0x20]   // coin yellow

    // MARK: - State

    /// True when a valid SMB1 ROM was loaded and CHR tiles decoded
    let isLoaded: Bool

    // Pre-rendered ROM sprites (nil if ROM not present or tile missing)
    let groundTileROM:    CGImage?
    let brickBlockROM:    CGImage?
    let questionBlockROM: CGImage?
    let pipeCapROM:       CGImage?
    let pipeBodyROM:      CGImage?
    let goombaROM:        CGImage?
    let coinROM:          CGImage?

    // Parsed W1-1 layout (valid only when isLoaded && levelParsed)
    private(set) var levelParsed  = false
    private(set) var w11Pipes:   [(col: Int, h: Int)]       = []
    private(set) var w11QBlocks: [(col: Int, row: Int)]     = []
    private(set) var w11Bricks:  [(col: Int, row: Int)]     = []
    private(set) var w11Stairs:  [(col: Int, topRow: Int)]  = []
    private(set) var w11Goombas: [Int]                      = []
    private(set) var w11Gaps:    [ClosedRange<Int>]         = []

    // MARK: - Init

    private init() {
        let romPath = NSHomeDirectory() + "/.xpip/roms/smb1.nes"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: romPath)) else {
            isLoaded = false
            groundTileROM = nil; brickBlockROM = nil; questionBlockROM = nil
            pipeCapROM = nil; pipeBodyROM = nil; goombaROM = nil; coinROM = nil
            print("[SMBRomParser] ROM not found — place smb1.nes at ~/.xpip/roms/smb1.nes")
            return
        }

        // Validate iNES magic: "NES\x1A"
        guard data.count >= 16,
              data[0] == 0x4E, data[1] == 0x45,
              data[2] == 0x53, data[3] == 0x1A else {
            isLoaded = false
            groundTileROM = nil; brickBlockROM = nil; questionBlockROM = nil
            pipeCapROM = nil; pipeBodyROM = nil; goombaROM = nil; coinROM = nil
            print("[SMBRomParser] Invalid iNES header — not a valid NES ROM file")
            return
        }

        let prgBanks = Int(data[4])
        let chrBanks = Int(data[5])
        let chrOff   = SMBRomParser.headerSize + prgBanks * SMBRomParser.prgBankBytes

        guard chrBanks >= 1, data.count >= chrOff + SMBRomParser.chrBankBytes else {
            isLoaded = false
            groundTileROM = nil; brickBlockROM = nil; questionBlockROM = nil
            pipeCapROM = nil; pipeBodyROM = nil; goombaROM = nil; coinROM = nil
            print("[SMBRomParser] CHR ROM not found (PRG×\(prgBanks), CHR×\(chrBanks), size=\(data.count))")
            return
        }

        print("[SMBRomParser] Loaded \(data.count) bytes: PRG×\(prgBanks), CHR×\(chrBanks), chrOffset=0x\(String(chrOff, radix:16))")

        // Decode all 512 CHR tiles
        let tiles = SMBRomParser.decodeCHR(data: data, offset: chrOff)

        // Render pre-baked sprites
        // Ground tile: two background tiles side-by-side (16×8)
        groundTileROM = SMBRomParser.composite(
            tiles: tiles,
            indices: [BG.groundTop, BG.groundTop],
            cols: 2, rows: 1,
            pal: SMBRomParser.palGround, scale: 3)

        // Brick block: 2×2 using brick tiles (16×16)
        brickBlockROM = SMBRomParser.composite(
            tiles: tiles,
            indices: [BG.brickTL, BG.brickTL, BG.brickBL, BG.brickBL],
            cols: 2, rows: 2,
            pal: SMBRomParser.palGround, scale: 3)

        // ? block: 2×2 using ? block tile frame 0 (16×16)
        questionBlockROM = SMBRomParser.composite(
            tiles: tiles,
            indices: [BG.qBlock0, BG.qBlock1, BG.qBlock0, BG.qBlock1],
            cols: 2, rows: 2,
            pal: SMBRomParser.palQBlock, scale: 3)

        // Pipe cap: 2 tiles wide × 1 tall (16×8)
        pipeCapROM = SMBRomParser.composite(
            tiles: tiles,
            indices: [BG.pipeCapL, BG.pipeCapR],
            cols: 2, rows: 1,
            pal: SMBRomParser.palPipe, scale: 3)

        // Pipe body: 2 tiles wide × 1 tall (16×8)
        pipeBodyROM = SMBRomParser.composite(
            tiles: tiles,
            indices: [BG.pipeBodyL, BG.pipeBodyR],
            cols: 2, rows: 1,
            pal: SMBRomParser.palPipe, scale: 3)

        // Goomba: 2×2 sprite metasprite (sprite bank, CHR = 256 + sprIndex)
        goombaROM = SMBRomParser.composite(
            tiles: tiles,
            indices: [256 + SPR.goombaTL, 256 + SPR.goombaTR,
                      256 + SPR.goombaBL, 256 + SPR.goombaBR],
            cols: 2, rows: 2,
            pal: SMBRomParser.palGoomba, scale: 3)

        // Coin: single 8×8 tile
        coinROM = SMBRomParser.composite(
            tiles: tiles,
            indices: [BG.coin],
            cols: 1, rows: 1,
            pal: SMBRomParser.palCoin, scale: 3)

        isLoaded = true

        // Parse W1-1 level data (best-effort; logged for tuning)
        if SMBRomParser.w11AreaObjectsOffset + 2 < data.count {
            parseAreaObjects(data: data)
        }
        if SMBRomParser.w11EnemyObjectsOffset + 2 < data.count {
            parseEnemyObjects(data: data)
        }

        // Sanity-check the parsed layout against known W1-1 characteristics
        levelParsed = (w11Pipes.count >= 3 && w11QBlocks.count >= 6 && w11Gaps.count >= 2)
        print("[SMBRomParser] Sprites OK. Level: \(w11Pipes.count) pipes, " +
              "\(w11QBlocks.count) ?blocks, \(w11Bricks.count) bricks, " +
              "\(w11Goombas.count) goombas, \(w11Gaps.count) gaps — parsed=\(levelParsed)")
    }

    // MARK: - CHR Decoding

    /// Decode all CHR tiles from the ROM into raw 64-byte pixel arrays (values 0–3).
    /// Returns an array of 512 entries (even if ROM has fewer tiles; extras are blank).
    private static func decodeCHR(data: Data, offset: Int) -> [[UInt8]] {
        var tiles = [[UInt8]](repeating: [UInt8](repeating: 0, count: 64),
                              count: tilesInCHR)
        let count = min(tilesInCHR, (data.count - offset) / tileBytes)
        for t in 0..<count {
            let base = offset + t * tileBytes
            var px = [UInt8](repeating: 0, count: 64)
            for y in 0..<8 {
                let p0 = data[base + y]
                let p1 = data[base + 8 + y]
                for x in 0..<8 {
                    let bit = 7 - x
                    px[y * 8 + x] = ((p0 >> bit) & 1) | (((p1 >> bit) & 1) << 1)
                }
            }
            tiles[t] = px
        }
        return tiles
    }

    // MARK: - Sprite Rendering

    /// Assemble a composite image from multiple CHR tiles arranged in a cols×rows grid.
    /// `indices` must have exactly cols×rows entries (row-major order).
    /// Pixel value 0 → transparent; 1–3 → NES colour via `pal`.
    private static func composite(tiles: [[UInt8]], indices: [Int],
                                   cols: Int, rows: Int,
                                   pal: [Int], scale: Int) -> CGImage? {
        guard indices.count == cols * rows else { return nil }
        let pixW = cols * 8
        let pixH = rows * 8
        var grid = [[UInt32]](repeating: [UInt32](repeating: 0, count: pixW), count: pixH)
        for r in 0..<rows {
            for c in 0..<cols {
                let ci = indices[r * cols + c]
                guard ci >= 0, ci < tiles.count else { continue }
                let px = tiles[ci]
                for py in 0..<8 {
                    for px_ in 0..<8 {
                        grid[r * 8 + py][c * 8 + px_] = nesArgb(px[py * 8 + px_], pal: pal)
                    }
                }
            }
        }
        return GameBase.renderPixelArt(grid, scale: scale)
    }

    /// Render a single CHR tile with a given palette (useful for one-off sprites).
    func tileImage(chrIndex: Int, pal: [Int], scale: Int = 3) -> CGImage? {
        guard isLoaded, chrIndex >= 0, chrIndex < SMBRomParser.tilesInCHR else { return nil }
        let tiles = _rawTiles
        guard !tiles.isEmpty else { return nil }
        let px = tiles[chrIndex]
        let rows: [[UInt32]] = (0..<8).map { y in
            (0..<8).map { x in SMBRomParser.nesArgb(px[y * 8 + x], pal: pal) }
        }
        return GameBase.renderPixelArt(rows, scale: scale)
    }

    // Lazily-decoded raw tile storage (only populated when tileImage is called)
    private var _rawTiles: [[UInt8]] = []

    private static func nesArgb(_ pixel: UInt8, pal: [Int]) -> UInt32 {
        if pixel == 0 { return 0 }          // transparent
        let idx = Int(pixel)
        guard idx < pal.count else { return 0 }
        let nesIdx = pal[idx]
        guard nesIdx >= 0, nesIdx < nesColors.count else { return 0 }
        return nesColors[nesIdx]
    }

    // MARK: - Area Object Parser (W1-1, best-effort)
    //
    // Area object format (2 bytes per object):
    //   Byte 1: [Y:4][X:4]
    //     Y = tile row (0–13 = floating objects; 0xE/0xF = special)
    //     X = column within current 16-column page (0–15)
    //   Byte 2: object type
    //     High nibble + low nibble encode type and size
    //   End: 0xFD
    //
    // Page advance: when X4 ≤ prevX4 (and prevX4 ≥ 0), advance to next page.
    //
    // Known byte2 encodings (best-effort; tune from log output):
    //   Y=0xE: page-skip marker — just advance page, carry X4 as new prevX4
    //   Y=0xD, b2_hi=0x5: Pipe  — height = b2_lo + 2
    //   Y=0xD, b2_hi=0x6: Gap   — width  = b2_lo + 1
    //   Y=0xD, b2_hi=0x7: Ascending staircase  — steps = b2_lo + 1
    //   Y=0xD, b2_hi=0x8: Descending staircase — steps = b2_lo + 1
    //   Y=0..12, b2_hi=0x0: Single ? block
    //   Y=0..12, b2_hi=0x1: Row of bricks       — count = b2_lo + 1
    //   Y=0..12, b2_hi=0x2: Row of ? blocks      — count = b2_lo + 1
    //   Y=0..12, b2_hi=0x3: Row of solid blocks  — count = b2_lo + 1
    //
    // All decoded objects and raw bytes are printed for verification.

    private func parseAreaObjects(data: Data) {
        var pipes:   [(col: Int, h: Int)]       = []
        var qBlocks: [(col: Int, row: Int)]     = []
        var bricks:  [(col: Int, row: Int)]     = []
        var stairs:  [(col: Int, topRow: Int)]  = []
        var gaps:    [ClosedRange<Int>]         = []

        var i      = SMBRomParser.w11AreaObjectsOffset
        var page   = 0
        var prevX4 = -1   // -1 = no previous object

        print("[SMBRomParser] --- W1-1 area objects (raw dump) ---")
        var objIdx = 0
        while i + 1 < data.count {
            let b1 = Int(data[i])
            let b2 = Int(data[i + 1])
            i += 2

            if b1 == 0xFD {
                print("[SMBRomParser] obj \(objIdx): END 0xFD")
                break
            }

            let y4  = (b1 >> 4) & 0xF
            let x4  =  b1       & 0xF
            let bHi = (b2 >> 4) & 0xF
            let bLo =  b2       & 0xF

            // Page advance
            if y4 == 0xE {
                // Explicit page-skip marker
                page += 1
                prevX4 = -1
                print("[SMBRomParser] obj \(objIdx): PAGE-SKIP → page \(page)")
                objIdx += 1
                continue
            }

            if prevX4 >= 0, x4 <= prevX4 { page += 1 }
            let col = page * 16 + x4
            prevX4 = x4

            print("[SMBRomParser] obj \(objIdx): b1=0x\(hex(b1)) b2=0x\(hex(b2))  col=\(col) row=\(y4)  hi=\(bHi) lo=\(bLo)")
            objIdx += 1

            if y4 <= 12 {
                // Floating objects
                let row = y4
                switch bHi {
                case 0x0:
                    qBlocks.append((col: col, row: row))
                case 0x1:
                    for dc in 0...bLo { bricks.append((col: col + dc, row: row)) }
                case 0x2:
                    for dc in 0...bLo { qBlocks.append((col: col + dc, row: row)) }
                case 0x3:
                    for dc in 0...bLo { bricks.append((col: col + dc, row: row)) }
                default:
                    break
                }

            } else if y4 == 0xD {
                // Ground-level objects (row 13)
                switch bHi {
                case 0x5:   // Pipe
                    let h = bLo + 2
                    pipes.append((col: col, h: h))
                case 0x6:   // Pit / gap
                    let w = bLo + 1
                    gaps.append(col...(col + w - 1))
                case 0x7:   // Ascending staircase
                    let steps = bLo + 1
                    for s in 0..<steps {
                        stairs.append((col: col + s, topRow: 13 - s))
                    }
                case 0x8:   // Descending staircase
                    let steps = bLo + 1
                    for s in 0..<steps {
                        stairs.append((col: col + s, topRow: 13 - (steps - 1 - s)))
                    }
                default:
                    break
                }
            }
            // y4 == 0xF = area attribute header (ignore)
        }
        print("[SMBRomParser] --- end area objects (\(objIdx) entries) ---")

        w11Pipes   = pipes
        w11QBlocks = qBlocks
        w11Bricks  = bricks
        w11Stairs  = stairs
        w11Gaps    = gaps
    }

    // MARK: - Enemy Object Parser (W1-1)
    //
    // Enemy object format (2 bytes):
    //   Byte 1: [X:4][Y:4]   — page/column same page-advance logic as area objects
    //   Byte 2: [page_flag:1][hard_flag:1][type:6]
    //   End:    0xFF
    //
    // Known enemy types:
    //   0x00  Goomba
    //   0x01  Koopa Troopa
    //   0x07  Piranha Plant

    private func parseEnemyObjects(data: Data) {
        var goombas: [Int] = []

        var i      = SMBRomParser.w11EnemyObjectsOffset
        var page   = 0
        var prevX4 = -1

        print("[SMBRomParser] --- W1-1 enemy objects (raw dump) ---")
        var objIdx = 0
        while i + 1 < data.count {
            let b1 = Int(data[i])
            let b2 = Int(data[i + 1])
            i += 2

            if b1 == 0xFF {
                print("[SMBRomParser] enemy \(objIdx): END 0xFF")
                break
            }

            let x4   = (b1 >> 4) & 0xF
            // y nibble is b1 & 0xF but enemies typically spawn at ground level
            let eType = b2 & 0x3F

            if prevX4 >= 0, x4 <= prevX4 { page += 1 }
            let col = page * 16 + x4
            prevX4 = x4

            print("[SMBRomParser] enemy \(objIdx): b1=0x\(hex(b1)) b2=0x\(hex(b2))  col=\(col) type=0x\(hex(eType))")
            objIdx += 1

            if eType == 0x00 { goombas.append(col) }
        }
        print("[SMBRomParser] --- end enemies (\(objIdx) entries) ---")

        w11Goombas = goombas
    }

    // MARK: - Helpers

    private func hex(_ n: Int) -> String { String(format: "%02X", n) }
    private static func hex(_ n: Int) -> String { String(format: "%02X", n) }
}
