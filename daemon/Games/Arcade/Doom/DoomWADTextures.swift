import Foundation
import Cocoa

/// Load wall texture data from a Doom WAD (PLAYPAL + flats) for use in the raycaster.
/// Flats are 64×64 palette-indexed; we decode and downscale to 16×16 RGBA.
enum DoomWADTextures {

    /// Load up to `maxTextures` wall textures from WAD (flats between F_START and F_END).
    /// Returns array of 16×16 RGBA pixel data (1024 bytes each), or nil on failure.
    static func loadWallTextures(from wad: WADReader, maxTextures: Int = 16) -> [[UInt8]]? {
        guard let palData = wad.lump(named: "PLAYPAL"), palData.count >= 768 else { return nil }
        let palette: [(r: UInt8, g: UInt8, b: UInt8)] = (0..<256).map { i in
            let o = i * 3
            return (palData[o], palData[o + 1], palData[o + 2])
        }
        var flatNames = wad.lumpNames(between: "F_START", and: "F_END")
        if flatNames.isEmpty { flatNames = wad.lumpNames(between: "FF_START", and: "FF_END") }
        if flatNames.isEmpty {
            // Fallback: any lump of size 4096 (64×64 flat)
            flatNames = wad.lumpNames(withSize: 4096)
        }
        guard !flatNames.isEmpty else { return nil }
        return decodeFlats(wad: wad, names: flatNames, palette: palette, max: maxTextures)
    }

    private static func decodeFlats(wad: WADReader, names: [String], palette: [(r: UInt8, g: UInt8, b: UInt8)], max: Int) -> [[UInt8]]? {
        var result: [[UInt8]] = []
        for name in names.prefix(max) {
            guard let lump = wad.lump(named: name), lump.count >= 4096 else { continue }
            // 64×64 flat -> 16×16 RGBA (sample every 4th pixel)
            var out = [UInt8](repeating: 0, count: 16 * 16 * 4)
            for y in 0..<16 {
                for x in 0..<16 {
                    let sx = x * 4
                    let sy = y * 4
                    let idx = sy * 64 + sx
                    let palIdx = Int(lump[idx])
                    let c = palette[min(palIdx, 255)]
                    let o = (y * 16 + x) * 4
                    out[o] = c.r
                    out[o + 1] = c.g
                    out[o + 2] = c.b
                    out[o + 3] = 255
                }
            }
            result.append(out)
        }
        return result.isEmpty ? nil : result
    }
}
