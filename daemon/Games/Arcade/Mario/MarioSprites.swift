import Cocoa

enum MarioSprites {
    // === Ground tile palette ===
    private static let B: UInt32 = 0xC84C0C  // brick orange
    private static let D: UInt32 = 0xA43000  // dark brick
    private static let M: UInt32 = 0xE09040  // mortar/light
    private static let G: UInt32 = 0x68A820  // ground green
    private static let K: UInt32 = 0x386810  // dark green
    private static let O: UInt32 = 0         // transparent

    // === Brick block border ===
    private static let bK: UInt32 = 0x181818  // elevated brick border

    // === Pipe palette ===
    private static let PG: UInt32 = 0x00A800  // pipe green
    private static let PL: UInt32 = 0x00E800  // pipe light green
    private static let PD: UInt32 = 0x005800  // pipe dark green
    private static let PK: UInt32 = 0x003800  // pipe darkest

    // === Coin palette ===
    private static let CY: UInt32 = 0xFCBE28  // coin yellow
    private static let CO: UInt32 = 0xE89C10  // coin orange
    private static let CW: UInt32 = 0xFCE878  // coin white highlight

    // === Goomba palette ===
    private static let GB: UInt32 = 0x8C5010  // goomba brown
    private static let GD: UInt32 = 0x6C3810  // goomba dark
    private static let GT: UInt32 = 0xD8A068  // goomba tan
    private static let GW: UInt32 = 0xF8F8F8  // goomba white (eyes)
    private static let GK: UInt32 = 0x181818  // goomba black (pupils)

    // === Question block palette ===
    private static let QY: UInt32 = 0xE89C10  // question yellow
    private static let QO: UInt32 = 0xC87010  // question orange
    private static let QW: UInt32 = 0xFCE878  // question highlight
    private static let QD: UInt32 = 0x885010  // question dark

    // === Cloud palette ===
    private static let CL: UInt32 = 0xF8F8F8  // cloud white
    private static let CS: UInt32 = 0xA8D8F8  // cloud shadow

    // === Bush palette ===
    private static let bG: UInt32 = 0x009800  // bush green
    private static let bS: UInt32 = 0x005400  // bush shadow

    // === Castle palette ===
    private static let zS: UInt32 = 0x888888  // castle stone
    private static let zH: UInt32 = 0xB8B8B8  // castle highlight
    private static let zD: UInt32 = 0x585858  // castle shadow
    private static let zK: UInt32 = 0x101010  // castle dark (openings)

    // === Flag palette ===
    private static let fG: UInt32 = 0x00A800  // flag green

    // Ground tile 16x8 — classic brick
    static let groundTile: [[UInt32]] = [
        [B,B,B,B,B,B,B,M,B,B,B,B,B,B,B,M],
        [B,B,B,B,B,B,B,M,B,B,B,B,B,B,B,M],
        [B,B,B,B,B,B,B,M,B,B,B,B,B,B,B,M],
        [M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M],
        [B,B,B,M,B,B,B,B,B,B,B,M,B,B,B,B],
        [B,B,B,M,B,B,B,B,B,B,B,M,B,B,B,B],
        [B,B,B,M,B,B,B,B,B,B,B,M,B,B,B,B],
        [M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M],
    ]

    // Brick block 16x16 — elevated brick with dark border
    static let brickBlock: [[UInt32]] = [
        [bK,bK,bK,bK,bK,bK,bK,bK,bK,bK,bK,bK,bK,bK,bK,bK],
        [bK, B, B, B, B, B, B, M, B, B, B, B, B, B, B,bK],
        [bK, B, B, B, B, B, B, M, B, B, B, B, B, B, B,bK],
        [bK, B, B, B, B, B, B, M, B, B, B, B, B, B, B,bK],
        [bK, M, M, M, M, M, M, M, M, M, M, M, M, M, M,bK],
        [bK, B, B, M, B, B, B, B, B, B, B, M, B, B, B,bK],
        [bK, B, B, M, B, B, B, B, B, B, B, M, B, B, B,bK],
        [bK, B, B, M, B, B, B, B, B, B, B, M, B, B, B,bK],
        [bK, M, M, M, M, M, M, M, M, M, M, M, M, M, M,bK],
        [bK, B, B, B, B, B, M, B, B, B, B, B, B, B, B,bK],
        [bK, B, B, B, B, B, M, B, B, B, B, B, B, B, B,bK],
        [bK, B, B, B, B, B, M, B, B, B, B, B, B, B, B,bK],
        [bK, M, M, M, M, M, M, M, M, M, M, M, M, M, M,bK],
        [bK, B, B, B, M, B, B, B, B, B, M, B, B, B, B,bK],
        [bK, B, B, B, M, B, B, B, B, B, M, B, B, B, B,bK],
        [bK,bK,bK,bK,bK,bK,bK,bK,bK,bK,bK,bK,bK,bK,bK,bK],
    ]

    // Pipe body 12x8 (tiled vertically)
    static let pipeBody: [[UInt32]] = [
        [PK,PD,PG,PG,PG,PL,PL,PG,PG,PG,PD,PK],
        [PK,PD,PG,PG,PG,PL,PL,PG,PG,PG,PD,PK],
        [PK,PD,PG,PG,PG,PL,PL,PG,PG,PG,PD,PK],
        [PK,PD,PG,PG,PG,PL,PL,PG,PG,PG,PD,PK],
        [PK,PD,PG,PG,PG,PL,PL,PG,PG,PG,PD,PK],
        [PK,PD,PG,PG,PG,PL,PL,PG,PG,PG,PD,PK],
        [PK,PD,PG,PG,PG,PL,PL,PG,PG,PG,PD,PK],
        [PK,PD,PG,PG,PG,PL,PL,PG,PG,PG,PD,PK],
    ]

    // Pipe cap 16x6 (wider lip)
    static let pipeCap: [[UInt32]] = [
        [PK,PK,PK,PK,PK,PK,PK,PK,PK,PK,PK,PK,PK,PK,PK,PK],
        [PK,PD,PG,PG,PL,PL,PL,PL,PL,PL,PL,PG,PG,PG,PD,PK],
        [PK,PD,PG,PG,PL,PL,PL,PL,PL,PL,PL,PG,PG,PG,PD,PK],
        [PK,PD,PG,PG,PL,PL,PL,PL,PL,PL,PL,PG,PG,PG,PD,PK],
        [PK,PD,PG,PG,PG,PG,PG,PG,PG,PG,PG,PG,PG,PG,PD,PK],
        [PK,PK,PK,PK,PK,PK,PK,PK,PK,PK,PK,PK,PK,PK,PK,PK],
    ]

    // Coin 8x10
    static let coin: [[UInt32]] = [
        [O, O, CY,CY,CY,CY, O, O],
        [O, CY,CW,CY,CY,CY,CY, O],
        [CY,CW,CO,CY,CY,CO,CY,CY],
        [CY,CW,CO,CY,CY,CO,CY,CY],
        [CY,CY,CO,CY,CY,CO,CY,CY],
        [CY,CY,CO,CY,CY,CO,CY,CY],
        [CY,CY,CO,CY,CY,CO,CY,CY],
        [CY,CY,CY,CO,CO,CY,CY,CY],
        [O, CY,CY,CY,CY,CY,CY, O],
        [O, O, CY,CY,CY,CY, O, O],
    ]

    // Goomba 14x14
    static let goomba: [[UInt32]] = [
        [O, O, O, O, O,GB,GB,GB,GB, O, O, O, O, O],
        [O, O, O, O,GB,GB,GB,GB,GB,GB, O, O, O, O],
        [O, O, O,GB,GB,GB,GB,GB,GB,GB,GB, O, O, O],
        [O, O,GB,GB,GB,GB,GB,GB,GB,GB,GB,GB, O, O],
        [O, O,GW,GW,GK,GB,GB,GB,GK,GW,GW, O, O, O],
        [O,GB,GW,GW,GK,GB,GB,GB,GK,GW,GW,GB, O, O],
        [O,GB,GB,GB,GB,GT,GT,GT,GB,GB,GB,GB,GB, O],
        [GB,GB,GB,GB,GT,GT,GT,GT,GT,GB,GB,GB,GB, O],
        [GB,GB,GB,GT,GT,GT,GT,GT,GT,GT,GB,GB,GB,GB],
        [O, O, O,GT,GT,GT,GT,GT,GT,GT, O, O, O, O],
        [O, O,GD,GD,GT,GT,GT,GT,GD,GD, O, O, O, O],
        [O,GD,GD,GD,GD,GT,GT,GD,GD,GD,GD, O, O, O],
        [GD,GD,GD,GD,GD, O, O,GD,GD,GD,GD,GD, O, O],
        [GD,GD,GD, O, O, O, O, O, O,GD,GD,GD, O, O],
    ]

    // Question block 16x16 (fixed from 15 rows to 16 rows)
    static let questionBlock: [[UInt32]] = [
        [QD,QD,QD,QD,QD,QD,QD,QD,QD,QD,QD,QD,QD,QD,QD,QD],
        [QD,QY,QY,QY,QY,QY,QY,QY,QY,QY,QY,QY,QY,QY,QO,QD],
        [QD,QY,QY,QY,QY,QW,QW,QW,QW,QY,QY,QY,QY,QY,QO,QD],
        [QD,QY,QY,QY,QW,QW,QY,QY,QW,QW,QY,QY,QY,QY,QO,QD],
        [QD,QY,QY,QY,QW,QW,QY,QY,QW,QW,QY,QY,QY,QY,QO,QD],
        [QD,QY,QY,QY,QY,QY,QY,QY,QW,QW,QY,QY,QY,QY,QO,QD],
        [QD,QY,QY,QY,QY,QY,QY,QW,QW,QY,QY,QY,QY,QY,QO,QD],
        [QD,QY,QY,QY,QY,QY,QW,QW,QY,QY,QY,QY,QY,QY,QO,QD],
        [QD,QY,QY,QY,QY,QY,QW,QW,QY,QY,QY,QY,QY,QY,QO,QD],
        [QD,QY,QY,QY,QY,QY,QY,QY,QY,QY,QY,QY,QY,QY,QO,QD],
        [QD,QY,QY,QY,QY,QY,QY,QY,QY,QY,QY,QY,QY,QY,QO,QD],
        [QD,QY,QY,QY,QY,QY,QW,QW,QY,QY,QY,QY,QY,QY,QO,QD],
        [QD,QY,QY,QY,QY,QY,QW,QW,QY,QY,QY,QY,QY,QY,QO,QD],
        [QD,QY,QY,QY,QY,QY,QY,QY,QY,QY,QY,QY,QY,QY,QO,QD],
        [QD,QO,QO,QO,QO,QO,QO,QO,QO,QO,QO,QO,QO,QO,QO,QD],
        [QD,QD,QD,QD,QD,QD,QD,QD,QD,QD,QD,QD,QD,QD,QD,QD],
    ]

    // Cloud 20x10
    static let cloud: [[UInt32]] = [
        [O, O, O, O, O, O,CL,CL,CL,CL,CL,CL,CL,CL, O, O, O, O, O, O],
        [O, O, O, O,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL, O, O, O, O],
        [O, O,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL, O, O],
        [O,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL, O],
        [CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL],
        [CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL],
        [CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL],
        [O,CS,CS,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CS,CS, O],
        [O, O,CS,CS,CS,CL,CL,CL,CL,CL,CL,CL,CL,CL,CL,CS,CS,CS, O, O],
        [O, O, O, O,CS,CS,CS,CS,CS,CS,CS,CS,CS,CS,CS,CS, O, O, O, O],
    ]

    // Hill 24x12
    static let hill: [[UInt32]] = [
        [O, O, O, O, O, O, O, O, O, O, G, G, G, G, O, O, O, O, O, O, O, O, O, O],
        [O, O, O, O, O, O, O, O, G, G, G, G, G, G, G, G, O, O, O, O, O, O, O, O],
        [O, O, O, O, O, O, G, G, G, G, G, G, G, G, G, G, G, G, O, O, O, O, O, O],
        [O, O, O, O, O, G, G, G, G, G, G, G, G, G, G, G, G, G, G, O, O, O, O, O],
        [O, O, O, O, G, G, G, G, G, K, G, G, G, G, K, G, G, G, G, G, O, O, O, O],
        [O, O, O, G, G, G, G, G, K, K, G, G, G, G, K, K, G, G, G, G, G, O, O, O],
        [O, O, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, O, O],
        [O, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, O],
        [G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G],
        [G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G],
        [G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G],
        [G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G, G],
    ]

    // Bush 20x10 — same silhouette as cloud but green (SMB bush = recolored cloud)
    static let bush: [[UInt32]] = [
        [O,  O,  O,  O,  O,  O, bG, bG, bG, bG, bG, bG, bG, bG,  O,  O,  O,  O,  O,  O],
        [O,  O,  O,  O, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG,  O,  O,  O,  O],
        [O,  O, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG,  O,  O],
        [O,  bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG,  O],
        [bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG],
        [bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG],
        [bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG],
        [O,  bS, bS, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bS, bS,  O],
        [O,  O,  bS, bS, bS, bG, bG, bG, bG, bG, bG, bG, bG, bG, bG, bS, bS, bS,  O,  O],
        [O,  O,  O,  O,  bS, bS, bS, bS, bS, bS, bS, bS, bS, bS, bS, bS,  O,  O,  O,  O],
    ]

    // Castle 24x20 — end-level castle
    // Battlements: 2-pillar, 2-gap, 2-pillar, 2-gap, 8-wall, 2-gap, 2-pillar, 2-gap, 2-pillar
    // = 2+2+2+2+8+2+2+2+2 = 24 wide
    static let castle: [[UInt32]] = [
        // Row 0-2: battlements
        [zS,zS, O, O,zS,zS, O, O,zS,zS,zS,zS,zS,zS,zS,zS, O, O,zS,zS, O, O,zS,zS],
        [zH,zS, O, O,zH,zS, O, O,zH,zS,zS,zS,zS,zS,zS,zH, O, O,zH,zS, O, O,zH,zS],
        [zD,zD, O, O,zD,zD, O, O,zD,zD,zD,zD,zD,zD,zD,zD, O, O,zD,zD, O, O,zD,zD],
        // Row 3: base of battlements
        [zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS],
        // Row 4: highlight stripe
        [zH,zH,zH,zH,zH,zH,zH,zH,zH,zH,zH,zH,zH,zH,zH,zH,zH,zH,zH,zH,zH,zH,zH,zH],
        // Row 5: body
        [zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS],
        // Rows 6-8: windows (3-wide each at cols 3-5 and 17-19)
        // 3+3+11+3+4 = 24
        [zS,zS,zS,zK,zK,zK,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zK,zK,zK,zS,zS,zS,zS],
        [zS,zS,zS,zK,zK,zK,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zK,zK,zK,zS,zS,zS,zS],
        [zS,zS,zS,zK,zK,zK,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zK,zK,zK,zS,zS,zS,zS],
        // Rows 9-11: body
        [zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS],
        [zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS],
        [zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS],
        // Row 12: arch keystone 2-wide (cols 11-12); 11+2+11=24
        [zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zK,zK,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS],
        // Row 13: arch 4-wide (cols 10-13); 10+4+10=24
        [zS,zS,zS,zS,zS,zS,zS,zS,zS,zS,zK,zK,zK,zK,zS,zS,zS,zS,zS,zS,zS,zS,zS,zS],
        // Row 14: arch 6-wide (cols 9-14); 9+6+9=24
        [zS,zS,zS,zS,zS,zS,zS,zS,zS,zK,zK,zK,zK,zK,zK,zS,zS,zS,zS,zS,zS,zS,zS,zS],
        // Row 15: arch 8-wide (cols 8-15); 8+8+8=24
        [zS,zS,zS,zS,zS,zS,zS,zS,zK,zK,zK,zK,zK,zK,zK,zK,zS,zS,zS,zS,zS,zS,zS,zS],
        // Rows 16-19: door body 8-wide (cols 8-15)
        [zS,zS,zS,zS,zS,zS,zS,zS,zK,zK,zK,zK,zK,zK,zK,zK,zS,zS,zS,zS,zS,zS,zS,zS],
        [zS,zS,zS,zS,zS,zS,zS,zS,zK,zK,zK,zK,zK,zK,zK,zK,zS,zS,zS,zS,zS,zS,zS,zS],
        [zS,zS,zS,zS,zS,zS,zS,zS,zK,zK,zK,zK,zK,zK,zK,zK,zS,zS,zS,zS,zS,zS,zS,zS],
        [zS,zS,zS,zS,zS,zS,zS,zS,zK,zK,zK,zK,zK,zK,zK,zK,zS,zS,zS,zS,zS,zS,zS,zS],
    ]

    // Flag 8x8 — triangle pennant pointing right, attached to left side of pole
    static let flag: [[UInt32]] = [
        [fG, fG, fG, fG, fG, fG, fG,  O],
        [fG, fG, fG, fG, fG, fG,  O,  O],
        [fG, fG, fG, fG, fG,  O,  O,  O],
        [fG, fG, fG, fG,  O,  O,  O,  O],
        [fG, fG, fG,  O,  O,  O,  O,  O],
        [fG, fG,  O,  O,  O,  O,  O,  O],
        [fG,  O,  O,  O,  O,  O,  O,  O],
        [ O,  O,  O,  O,  O,  O,  O,  O],
    ]

    // Pre-rendered images
    static let groundTileImage: CGImage?   = GameBase.renderPixelArt(groundTile,   scale: 3)
    static let brickBlockImage: CGImage?   = GameBase.renderPixelArt(brickBlock,   scale: 3)
    static let pipeBodyImage: CGImage?     = GameBase.renderPixelArt(pipeBody,     scale: 3)
    static let pipeCapImage: CGImage?      = GameBase.renderPixelArt(pipeCap,      scale: 3)
    static let coinImage: CGImage?         = GameBase.renderPixelArt(coin,         scale: 3)
    static let goombaImage: CGImage?       = GameBase.renderPixelArt(goomba,       scale: 3)
    static let questionBlockImage: CGImage? = GameBase.renderPixelArt(questionBlock, scale: 3)
    static let cloudImage: CGImage?        = GameBase.renderPixelArt(cloud,        scale: 2)
    static let hillImage: CGImage?         = GameBase.renderPixelArt(hill,         scale: 3)
    static let bushImage: CGImage?         = GameBase.renderPixelArt(bush,         scale: 2)
    static let castleImage: CGImage?       = GameBase.renderPixelArt(castle,       scale: 3)
    static let flagImage: CGImage?         = GameBase.renderPixelArt(flag,         scale: 3)
}
