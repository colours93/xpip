import Foundation

/// Minimal Doom WAD reader: header + directory, lump access by name.
/// IWAD/PWAD format: 12-byte header, then directory at offset (16 bytes per entry).
struct WADReader {
    private let data: Data
    private let directory: [(name: String, offset: Int, size: Int)]

    init?(url: URL) {
        guard let d = try? Data(contentsOf: url), d.count >= 12 else { return nil }
        let sig = String(data: d.prefix(4), encoding: .ascii) ?? ""
        guard sig == "IWAD" || sig == "PWAD" else { return nil }
        let numLumps = d.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Int32.self).littleEndian }
        let dirOffset = Int(d.withUnsafeBytes { $0.load(fromByteOffset: 8, as: Int32.self).littleEndian })
        guard dirOffset >= 0, dirOffset + Int(numLumps) * 16 <= d.count else { return nil }
        var dir: [(String, Int, Int)] = []
        for i in 0..<Int(numLumps) {
            let e = dirOffset + i * 16
            let offset = Int(d.withUnsafeBytes { $0.load(fromByteOffset: e, as: Int32.self).littleEndian })
            let size = Int(d.withUnsafeBytes { $0.load(fromByteOffset: e + 4, as: Int32.self).littleEndian })
            let nameData = d.subdata(in: e + 8..<e + 16)
            let name = String(bytes: nameData.filter { $0 != 0 }, encoding: .ascii) ?? ""
            dir.append((name, offset, size))
        }
        self.data = d
        self.directory = dir
    }

    /// Lump data by exact name (e.g. "PLAYPAL", "FLOOR0_1").
    func lump(named name: String) -> Data? {
        guard let e = directory.first(where: { $0.name == name }),
              e.offset >= 0, e.offset + e.size <= data.count else { return nil }
        return data.subdata(in: e.offset..<(e.offset + e.size))
    }

    /// Names of lumps between startMark and endMark (e.g. F_START .. F_END for flats).
    func lumpNames(between startMark: String, and endMark: String) -> [String] {
        var inRange = false
        var names: [String] = []
        for e in directory {
            if e.name == startMark { inRange = true; continue }
            if e.name == endMark { break }
            if inRange, e.size > 0 { names.append(e.name) }
        }
        return names
    }

    /// All lump names (for debugging).
    func allLumpNames() -> [String] { directory.map(\.name) }

    /// Names of lumps with exactly this size (e.g. 4096 for Doom flats).
    func lumpNames(withSize size: Int) -> [String] {
        directory.filter { $0.size == size && $0.offset >= 0 && $0.offset + size <= data.count }.map(\.name)
    }
}
