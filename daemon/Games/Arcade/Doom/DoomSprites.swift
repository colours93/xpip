import Cocoa

/// Pixel art sprites for the Doom game — wall textures, enemies, items, weapons.
/// All textures are 16x16 pixels, rendered at scale 1 (used as texture sources for raycasting).
enum DoomSprites {

    // MARK: - Wall Textures (16x16, unscaled — sampled per-column by raycaster)

    /// Grey stone bricks
    static let wallStone: CGImage? = {
        let O: UInt32 = 0xFF555555 // mortar
        let pixels: [[UInt32]] = [
            [0xFF888888, 0xFF888888, 0xFF888888, 0xFF7A7A7A, O,         0xFF999999, 0xFF999999, 0xFF8A8A8A, 0xFF8A8A8A, 0xFF999999, 0xFF7A7A7A, O,         0xFF888888, 0xFF888888, 0xFF888888, 0xFF7A7A7A],
            [0xFF7A7A7A, 0xFF888888, 0xFF999999, 0xFF888888, O,         0xFF8A8A8A, 0xFF999999, 0xFF999999, 0xFF8A8A8A, 0xFF888888, 0xFF888888, O,         0xFF7A7A7A, 0xFF888888, 0xFF999999, 0xFF888888],
            [0xFF888888, 0xFF999999, 0xFF8A8A8A, 0xFF7A7A7A, O,         0xFF999999, 0xFF8A8A8A, 0xFF888888, 0xFF999999, 0xFF999999, 0xFF8A8A8A, O,         0xFF888888, 0xFF999999, 0xFF8A8A8A, 0xFF7A7A7A],
            [0xFF7A7A7A, 0xFF888888, 0xFF888888, 0xFF888888, O,         0xFF888888, 0xFF888888, 0xFF7A7A7A, 0xFF888888, 0xFF8A8A8A, 0xFF888888, O,         0xFF7A7A7A, 0xFF888888, 0xFF888888, 0xFF888888],
            [O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O        ],
            [0xFF996644, 0xFF885533, 0xFF996644, 0xFFAA7755, 0xFF996644, 0xFF885533, O,         0xFF996644, 0xFFAA7755, 0xFF996644, 0xFF885533, 0xFF996644, 0xFFAA7755, 0xFF996644, 0xFF885533, 0xFF996644],
            [0xFF885533, 0xFF996644, 0xFFAA7755, 0xFF996644, 0xFF885533, 0xFF996644, O,         0xFF885533, 0xFF996644, 0xFFAA7755, 0xFF996644, 0xFF885533, 0xFF996644, 0xFFAA7755, 0xFF996644, 0xFF885533],
            [0xFF996644, 0xFFAA7755, 0xFF996644, 0xFF885533, 0xFF996644, 0xFFAA7755, O,         0xFF996644, 0xFF885533, 0xFF996644, 0xFFAA7755, 0xFF996644, 0xFF885533, 0xFF996644, 0xFFAA7755, 0xFF996644],
            [0xFFAA7755, 0xFF996644, 0xFF885533, 0xFF996644, 0xFFAA7755, 0xFF996644, O,         0xFFAA7755, 0xFF996644, 0xFF885533, 0xFF996644, 0xFFAA7755, 0xFF996644, 0xFF885533, 0xFF996644, 0xFFAA7755],
            [O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O        ],
            [0xFF888888, 0xFF999999, 0xFF8A8A8A, O,         0xFF888888, 0xFF888888, 0xFF999999, 0xFF8A8A8A, 0xFF888888, 0xFF7A7A7A, O,         0xFF888888, 0xFF999999, 0xFF8A8A8A, 0xFF888888, 0xFF7A7A7A],
            [0xFF999999, 0xFF8A8A8A, 0xFF888888, O,         0xFF7A7A7A, 0xFF999999, 0xFF8A8A8A, 0xFF888888, 0xFF999999, 0xFF888888, O,         0xFF999999, 0xFF8A8A8A, 0xFF888888, 0xFF999999, 0xFF888888],
            [0xFF8A8A8A, 0xFF888888, 0xFF7A7A7A, O,         0xFF888888, 0xFF888888, 0xFF888888, 0xFF7A7A7A, 0xFF8A8A8A, 0xFF999999, O,         0xFF8A8A8A, 0xFF888888, 0xFF7A7A7A, 0xFF8A8A8A, 0xFF999999],
            [0xFF888888, 0xFF7A7A7A, 0xFF888888, O,         0xFF999999, 0xFF7A7A7A, 0xFF888888, 0xFF888888, 0xFF888888, 0xFF8A8A8A, O,         0xFF888888, 0xFF7A7A7A, 0xFF888888, 0xFF888888, 0xFF8A8A8A],
            [O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O        ],
            [0xFF996644, 0xFFAA7755, 0xFF996644, 0xFF885533, 0xFF996644, 0xFFAA7755, 0xFF996644, 0xFF885533, O,         0xFF996644, 0xFFAA7755, 0xFF996644, 0xFF885533, 0xFF996644, 0xFFAA7755, 0xFF996644],
        ]
        return GameBase.renderPixelArt(pixels, scale: 1)
    }()

    /// Blood-red bricks
    static let wallRed: CGImage? = {
        let O: UInt32 = 0xFF331111
        let pixels: [[UInt32]] = [
            [0xFF882222, 0xFF993333, 0xFF882222, 0xFF773333, O,         0xFF993333, 0xFF882222, 0xFF993333, 0xFF882222, 0xFF773333, 0xFF882222, O,         0xFF882222, 0xFF993333, 0xFF882222, 0xFF773333],
            [0xFF773333, 0xFF882222, 0xFF993333, 0xFF882222, O,         0xFF882222, 0xFF993333, 0xFF882222, 0xFF773333, 0xFF882222, 0xFF993333, O,         0xFF773333, 0xFF882222, 0xFF993333, 0xFF882222],
            [0xFF882222, 0xFF993333, 0xFF882222, 0xFF993333, O,         0xFF773333, 0xFF882222, 0xFF993333, 0xFF882222, 0xFF993333, 0xFF882222, O,         0xFF882222, 0xFF993333, 0xFF882222, 0xFF993333],
            [0xFF993333, 0xFF882222, 0xFF773333, 0xFF882222, O,         0xFF993333, 0xFF773333, 0xFF882222, 0xFF993333, 0xFF882222, 0xFF773333, O,         0xFF993333, 0xFF882222, 0xFF773333, 0xFF882222],
            [O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O        ],
            [0xFF993333, 0xFF882222, 0xFF773333, O,         0xFF882222, 0xFF993333, 0xFF882222, 0xFF773333, 0xFF882222, O,         0xFF993333, 0xFF882222, 0xFF773333, 0xFF882222, 0xFF993333, 0xFF882222],
            [0xFF882222, 0xFF993333, 0xFF882222, O,         0xFF993333, 0xFF882222, 0xFF993333, 0xFF882222, 0xFF993333, O,         0xFF882222, 0xFF993333, 0xFF882222, 0xFF993333, 0xFF882222, 0xFF993333],
            [0xFF773333, 0xFF882222, 0xFF993333, O,         0xFF882222, 0xFF773333, 0xFF882222, 0xFF993333, 0xFF882222, O,         0xFF773333, 0xFF882222, 0xFF993333, 0xFF882222, 0xFF773333, 0xFF882222],
            [0xFF882222, 0xFF773333, 0xFF882222, O,         0xFF773333, 0xFF882222, 0xFF773333, 0xFF882222, 0xFF773333, O,         0xFF882222, 0xFF773333, 0xFF882222, 0xFF773333, 0xFF882222, 0xFF773333],
            [O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O        ],
            [0xFF882222, 0xFF993333, 0xFF882222, 0xFF773333, O,         0xFF882222, 0xFF993333, 0xFF882222, 0xFF773333, 0xFF882222, 0xFF993333, O,         0xFF882222, 0xFF993333, 0xFF882222, 0xFF773333],
            [0xFF993333, 0xFF882222, 0xFF993333, 0xFF882222, O,         0xFF993333, 0xFF882222, 0xFF993333, 0xFF882222, 0xFF993333, 0xFF882222, O,         0xFF993333, 0xFF882222, 0xFF993333, 0xFF882222],
            [0xFF882222, 0xFF773333, 0xFF882222, 0xFF993333, O,         0xFF882222, 0xFF773333, 0xFF882222, 0xFF993333, 0xFF882222, 0xFF773333, O,         0xFF882222, 0xFF773333, 0xFF882222, 0xFF993333],
            [0xFF773333, 0xFF882222, 0xFF773333, 0xFF882222, O,         0xFF773333, 0xFF882222, 0xFF773333, 0xFF882222, 0xFF773333, 0xFF882222, O,         0xFF773333, 0xFF882222, 0xFF773333, 0xFF882222],
            [O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O        ],
            [0xFF993333, 0xFF882222, 0xFF993333, 0xFF773333, 0xFF882222, O,         0xFF993333, 0xFF882222, 0xFF993333, 0xFF773333, 0xFF882222, O,         0xFF993333, 0xFF882222, 0xFF993333, 0xFF773333],
        ]
        return GameBase.renderPixelArt(pixels, scale: 1)
    }()

    /// Dark tech panel
    static let wallTech: CGImage? = {
        let pixels: [[UInt32]] = [
            [0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466],
            [0xFF444466, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF444466, 0xFF444466, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF444466],
            [0xFF444466, 0xFF333355, 0xFF225588, 0xFF2266AA, 0xFF2266AA, 0xFF225588, 0xFF333355, 0xFF444466, 0xFF444466, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF444466],
            [0xFF444466, 0xFF333355, 0xFF2266AA, 0xFF3388CC, 0xFF3388CC, 0xFF2266AA, 0xFF333355, 0xFF444466, 0xFF444466, 0xFF333355, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF333355, 0xFF444466],
            [0xFF444466, 0xFF333355, 0xFF2266AA, 0xFF3388CC, 0xFF3388CC, 0xFF2266AA, 0xFF333355, 0xFF444466, 0xFF444466, 0xFF333355, 0xFF444466, 0xFF00AA44, 0xFF00AA44, 0xFF444466, 0xFF333355, 0xFF444466],
            [0xFF444466, 0xFF333355, 0xFF225588, 0xFF2266AA, 0xFF2266AA, 0xFF225588, 0xFF333355, 0xFF444466, 0xFF444466, 0xFF333355, 0xFF444466, 0xFF00AA44, 0xFF00AA44, 0xFF444466, 0xFF333355, 0xFF444466],
            [0xFF444466, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF444466, 0xFF444466, 0xFF333355, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF333355, 0xFF444466],
            [0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF444466],
            [0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466],
            [0xFF444466, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF444466],
            [0xFF444466, 0xFF333355, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF333355, 0xFF444466],
            [0xFF444466, 0xFF333355, 0xFF444466, 0xFFDD4444, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFFDD4444, 0xFF444466, 0xFF333355, 0xFF444466],
            [0xFF444466, 0xFF333355, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF333355, 0xFF444466],
            [0xFF444466, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF333355, 0xFF444466],
            [0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466, 0xFF444466],
            [0xFF555577, 0xFF555577, 0xFF555577, 0xFF555577, 0xFF555577, 0xFF555577, 0xFF555577, 0xFF555577, 0xFF555577, 0xFF555577, 0xFF555577, 0xFF555577, 0xFF555577, 0xFF555577, 0xFF555577, 0xFF555577],
        ]
        return GameBase.renderPixelArt(pixels, scale: 1)
    }()

    /// Wall texture lookup: tile value → texture image
    static let wallTextures: [CGImage] = [wallStone, wallRed, wallTech].compactMap { $0 }

    // MARK: - Extract texture pixel data for raycasting

    /// Pre-extracted RGBA pixel data for each wall texture (16x16).
    /// Layout: [texIndex][pixelIndex * 4 + channel]
    static let wallTextureData: [[UInt8]] = {
        var result: [[UInt8]] = []
        for tex in wallTextures {
            let w = tex.width, h = tex.height
            let bytesPerRow = w * 4
            var pixelData = [UInt8](repeating: 0, count: h * bytesPerRow)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let ctx = CGContext(data: &pixelData, width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                result.append([UInt8](repeating: 128, count: h * bytesPerRow))
                continue
            }
            ctx.draw(tex, in: CGRect(x: 0, y: 0, width: w, height: h))
            result.append(pixelData)
        }
        return result
    }()

    // MARK: - Enemy Sprites (16x16, scale 2 → 32x32 for billboard rendering)

    /// Imp-like demon — front facing
    static let demon: CGImage? = {
        let O: UInt32 = 0
        let pixels: [[UInt32]] = [
            [O,         O,         O,         O,         O,         0xFFAA2222, 0xFF881111, O,         O,         0xFF881111, 0xFFAA2222, O,         O,         O,         O,         O        ],
            [O,         O,         O,         O,         0xFFAA2222, 0xFFCC3333, 0xFFAA2222, 0xFF881111, 0xFF881111, 0xFFAA2222, 0xFFCC3333, 0xFFAA2222, O,         O,         O,         O        ],
            [O,         O,         O,         0xFF881111, 0xFFCC3333, 0xFFCC3333, 0xFFAA2222, 0xFFAA2222, 0xFFAA2222, 0xFFAA2222, 0xFFCC3333, 0xFFCC3333, 0xFF881111, O,         O,         O        ],
            [O,         O,         0xFF881111, 0xFFAA2222, 0xFFCC3333, 0xFFFFFF00, 0xFFFF0000, 0xFFAA2222, 0xFFAA2222, 0xFFFF0000, 0xFFFFFF00, 0xFFCC3333, 0xFFAA2222, 0xFF881111, O,         O        ],
            [O,         O,         0xFF881111, 0xFFAA2222, 0xFFCC3333, 0xFFAA2222, 0xFFAA2222, 0xFF881111, 0xFF881111, 0xFFAA2222, 0xFFAA2222, 0xFFCC3333, 0xFFAA2222, 0xFF881111, O,         O        ],
            [O,         O,         O,         0xFF881111, 0xFFAA2222, 0xFFAA2222, 0xFF881111, 0xFF661111, 0xFF661111, 0xFF881111, 0xFFAA2222, 0xFFAA2222, 0xFF881111, O,         O,         O        ],
            [O,         O,         O,         O,         0xFF881111, 0xFFAA2222, 0xFF881111, 0xFFCC3333, 0xFFCC3333, 0xFF881111, 0xFFAA2222, 0xFF881111, O,         O,         O,         O        ],
            [O,         O,         0xFF661111, 0xFF881111, 0xFFAA2222, 0xFFCC3333, 0xFFCC3333, 0xFFAA2222, 0xFFAA2222, 0xFFCC3333, 0xFFCC3333, 0xFFAA2222, 0xFF881111, 0xFF661111, O,         O        ],
            [O,         0xFF661111, 0xFF881111, 0xFFAA2222, 0xFFCC3333, 0xFFAA2222, 0xFFAA2222, 0xFF881111, 0xFF881111, 0xFFAA2222, 0xFFAA2222, 0xFFCC3333, 0xFFAA2222, 0xFF881111, 0xFF661111, O        ],
            [O,         0xFF881111, 0xFFAA2222, 0xFFCC3333, 0xFFAA2222, 0xFF881111, 0xFF881111, 0xFFAA2222, 0xFFAA2222, 0xFF881111, 0xFF881111, 0xFFAA2222, 0xFFCC3333, 0xFFAA2222, 0xFF881111, O        ],
            [O,         O,         0xFF881111, 0xFFAA2222, 0xFF881111, O,         0xFF881111, 0xFFAA2222, 0xFFAA2222, 0xFF881111, O,         0xFF881111, 0xFFAA2222, 0xFF881111, O,         O        ],
            [O,         O,         O,         0xFF881111, 0xFF881111, O,         0xFF881111, 0xFFAA2222, 0xFFAA2222, 0xFF881111, O,         0xFF881111, 0xFF881111, O,         O,         O        ],
            [O,         O,         O,         0xFF881111, 0xFFAA2222, O,         O,         0xFF881111, 0xFF881111, O,         O,         0xFFAA2222, 0xFF881111, O,         O,         O        ],
            [O,         O,         0xFF881111, 0xFFAA2222, 0xFF881111, O,         O,         O,         O,         O,         O,         0xFF881111, 0xFFAA2222, 0xFF881111, O,         O        ],
            [O,         O,         0xFF661111, 0xFF881111, O,         O,         O,         O,         O,         O,         O,         O,         0xFF881111, 0xFF661111, O,         O        ],
            [O,         O,         0xFF661111, 0xFF661111, O,         O,         O,         O,         O,         O,         O,         O,         0xFF661111, 0xFF661111, O,         O        ],
        ]
        return GameBase.renderPixelArt(pixels, scale: 2)
    }()

    /// Dead demon (flat on ground)
    static let demonDead: CGImage? = {
        let O: UInt32 = 0
        let pixels: [[UInt32]] = [
            [O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O        ],
            [O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O        ],
            [O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O        ],
            [O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O        ],
            [O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O        ],
            [O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O        ],
            [O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O        ],
            [O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O        ],
            [O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O        ],
            [O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         O        ],
            [O,         0xFF440000, 0xFF550000, O,         O,         O,         O,         O,         O,         O,         O,         O,         O,         0xFF550000, 0xFF440000, O        ],
            [0xFF440000, 0xFF661111, 0xFF881111, 0xFF661111, 0xFF550000, 0xFF440000, 0xFF440000, 0xFF550000, 0xFF550000, 0xFF440000, 0xFF440000, 0xFF550000, 0xFF661111, 0xFF881111, 0xFF661111, 0xFF440000],
            [0xFF550000, 0xFF881111, 0xFFAA2222, 0xFF881111, 0xFF661111, 0xFF881111, 0xFF661111, 0xFF661111, 0xFF661111, 0xFF661111, 0xFF881111, 0xFF661111, 0xFF881111, 0xFFAA2222, 0xFF881111, 0xFF550000],
            [0xFF661111, 0xFFAA2222, 0xFF881111, 0xFFAA2222, 0xFF881111, 0xFFAA2222, 0xFF881111, 0xFF881111, 0xFF881111, 0xFF881111, 0xFFAA2222, 0xFF881111, 0xFFAA2222, 0xFF881111, 0xFFAA2222, 0xFF661111],
            [0xFF440000, 0xFF661111, 0xFF881111, 0xFF661111, 0xFFAA2222, 0xFF881111, 0xFFAA2222, 0xFFAA2222, 0xFFAA2222, 0xFFAA2222, 0xFF881111, 0xFFAA2222, 0xFF661111, 0xFF881111, 0xFF661111, 0xFF440000],
            [O,         0xFF440000, 0xFF550000, 0xFF440000, 0xFF661111, 0xFF661111, 0xFF881111, 0xFF881111, 0xFF881111, 0xFF881111, 0xFF661111, 0xFF661111, 0xFF440000, 0xFF550000, 0xFF440000, O        ],
        ]
        return GameBase.renderPixelArt(pixels, scale: 2)
    }()

    // MARK: - Item Sprites

    /// Health pickup (red cross on white)
    static let healthPack: CGImage? = {
        let O: UInt32 = 0
        let W: UInt32 = 0xFFEEEEEE
        let R: UInt32 = 0xFFDD2222
        let pixels: [[UInt32]] = [
            [O, O, O, O, O, W, W, W, W, W, W, O, O, O, O, O],
            [O, O, O, W, W, W, W, W, W, W, W, W, W, O, O, O],
            [O, O, W, W, W, W, W, W, W, W, W, W, W, W, O, O],
            [O, W, W, W, W, W, R, R, R, R, W, W, W, W, W, O],
            [O, W, W, W, W, W, R, R, R, R, W, W, W, W, W, O],
            [W, W, W, W, R, R, R, R, R, R, R, R, W, W, W, W],
            [W, W, W, W, R, R, R, R, R, R, R, R, W, W, W, W],
            [W, W, W, W, R, R, R, R, R, R, R, R, W, W, W, W],
            [W, W, W, W, R, R, R, R, R, R, R, R, W, W, W, W],
            [W, W, W, W, R, R, R, R, R, R, R, R, W, W, W, W],
            [W, W, W, W, R, R, R, R, R, R, R, R, W, W, W, W],
            [O, W, W, W, W, W, R, R, R, R, W, W, W, W, W, O],
            [O, W, W, W, W, W, R, R, R, R, W, W, W, W, W, O],
            [O, O, W, W, W, W, W, W, W, W, W, W, W, W, O, O],
            [O, O, O, W, W, W, W, W, W, W, W, W, W, O, O, O],
            [O, O, O, O, O, W, W, W, W, W, W, O, O, O, O, O],
        ]
        return GameBase.renderPixelArt(pixels, scale: 2)
    }()

    /// Ammo pickup (yellow shells)
    static let ammoPack: CGImage? = {
        let O: UInt32 = 0
        let Y: UInt32 = 0xFFDDAA22
        let D: UInt32 = 0xFFAA7711
        let B: UInt32 = 0xFF886600
        let pixels: [[UInt32]] = [
            [O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O],
            [O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O],
            [O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O],
            [O, O, O, Y, Y, O, O, Y, Y, O, O, Y, Y, O, O, O],
            [O, O, O, Y, Y, O, O, Y, Y, O, O, Y, Y, O, O, O],
            [O, O, O, Y, Y, O, O, Y, Y, O, O, Y, Y, O, O, O],
            [O, O, O, Y, Y, O, O, Y, Y, O, O, Y, Y, O, O, O],
            [O, O, O, D, D, O, O, D, D, O, O, D, D, O, O, O],
            [O, O, O, D, D, O, O, D, D, O, O, D, D, O, O, O],
            [O, O, O, D, D, O, O, D, D, O, O, D, D, O, O, O],
            [O, O, O, B, B, O, O, B, B, O, O, B, B, O, O, O],
            [O, O, O, B, B, O, O, B, B, O, O, B, B, O, O, O],
            [O, O, O, B, B, O, O, B, B, O, O, B, B, O, O, O],
            [O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O],
            [O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O],
            [O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O],
        ]
        return GameBase.renderPixelArt(pixels, scale: 2)
    }()

    /// Pre-extracted enemy pixel data for billboard column sampling (16x16 at scale 2 = 32x32 actual)
    static let demonData: [UInt8] = {
        guard let img = demon else { return [] }
        let w = img.width, h = img.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &data, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return data
    }()

    static let demonDeadData: [UInt8] = {
        guard let img = demonDead else { return [] }
        let w = img.width, h = img.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &data, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return data
    }()

    static let healthData: [UInt8] = {
        guard let img = healthPack else { return [] }
        let w = img.width, h = img.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &data, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return data
    }()

    static let ammoData: [UInt8] = {
        guard let img = ammoPack else { return [] }
        let w = img.width, h = img.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &data, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return data
    }()
}
