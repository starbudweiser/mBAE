// Extraction : octets d'un fichier de l'archive (ExtractWorker.run en Python) et écriture vers un dossier de sortie.

import Foundation

/// En-tête DDS avec extension DX10 (148 octets), valable pour tous les formats DXGI d'un BA2.
public func ddsHeader(width: Int, height: Int, mips: Int, dxgi: Int, cube: Int) -> Data {
    var d = Data()
    func u32(_ v: Int) { var x = UInt32(truncatingIfNeeded: v).littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
    let isCube = cube != 0
    let flags = 0x1007 | (mips > 1 ? 0x20000 : 0)
    let caps = 0x1000 | (mips > 1 ? 0x400008 : 0) | (isCube ? 0x8 : 0)
    d.append(contentsOf: Array("DDS ".utf8))
    u32(124); u32(flags); u32(height); u32(width); u32(0); u32(0); u32(mips)
    for _ in 0..<11 { u32(0) }
    u32(32); u32(0x4); d.append(contentsOf: Array("DX10".utf8)); for _ in 0..<5 { u32(0) }
    u32(caps); u32(isCube ? 0xFE00 : 0); u32(0); u32(0); u32(0)
    u32(dxgi); u32(3); u32(isCube ? 4 : 0); u32(1); u32(0)
    return d
}

/// Bloc BA2 : zlib (Fallout 4, Skyrim) ou LZ4 brut (Starfield).
func unpack(_ raw: Data, realSize: Int) throws -> Data {
    if let d = Inflate.zlib(raw) { return d }
    if let d = LZ4.decodeBlock(raw, maxSize: realSize) { return d }
    throw ArchiveError.decompress
}

public struct ExtractResult {
    public var total = 0      // fichiers de l'archive
    public var skipped = 0    // noms refusés (chemin non sûr)
    public var extracted: Int { total - skipped }
}

extension BethesdaArchive {
    /// Octets d'un fichier. `nil` si ses données sont tronquées au point de ne pas pouvoir être lues (le Python passe alors au suivant).
    func bytes(of item: ArchiveEntry, from f: Reader) throws -> Data? {
        try f.seek(item.offset)
        if kind == .bsa {
            var remaining = item.size
            if embeddedNames {  // nom du fichier répété devant ses données
                let b = try f.read(1)
                guard let n = b.first else { throw ArchiveError.truncated }
                try f.skip(Int(n))
                remaining -= Int(n) + 1
            }
            if item.compressed {
                let head = try f.read(4)
                if head.count < 4 { return nil }
                let raw = try f.read(max(0, remaining - 4))
                guard let d = version >= 105 ? LZ4.decodeFrame(raw) : Inflate.zlib(raw) else { throw ArchiveError.decompress }
                return d
            }
            return try f.read(max(0, remaining))
        }
        if let chunks = item.chunks, let t = item.texture {
            var data = ddsHeader(width: t.width, height: t.height, mips: t.mips, dxgi: t.dxgi, cube: t.cube)
            for c in chunks {
                try f.seek(c.offset)
                data.append(c.packed != 0 ? try unpack(try f.read(c.packed), realSize: c.full) : try f.read(c.full))
            }
            return data
        }
        if item.compressed { return try unpack(try f.read(item.packedSize), realSize: item.realSize) }
        return try f.read(item.realSize)
    }

    /// Nom relatif sûr pour une extraction, ou `nil` : chemin absolu, composant « .. » ou caractère nul.
    /// (La version Python écrivait ces chemins tels quels, y compris hors du dossier de sortie : ils sont refusés ici.)
    public static func safeRelativePath(_ name: String) -> String? {
        if name.isEmpty || name.hasPrefix("/") || name.contains("\0") { return nil }
        let parts = name.split(separator: "/", omittingEmptySubsequences: false)
        if parts.contains("..") { return nil }
        return name
    }

    /// Extrait tous les fichiers vers `outDir`. `progress` reçoit le pourcentage (0-100) ; `isCancelled` arrête proprement.
    @discardableResult
    public func extractAll(to outDir: String, progress: (Int) -> Void = { _ in }, isCancelled: () -> Bool = { false }) throws -> ExtractResult {
        var result = ExtractResult()
        result.total = files.count
        guard !files.isEmpty else { return result }
        let fm = FileManager.default
        let root = URL(fileURLWithPath: outDir).standardizedFileURL
        let f = try Reader(url)
        for (idx, item) in files.enumerated() {
            if isCancelled() { break }
            guard let rel = Self.safeRelativePath(item.name) else {
                result.skipped += 1
                progress(Int(Double(idx + 1) / Double(files.count) * 100))
                continue
            }
            let dest = root.appendingPathComponent(rel)
            guard dest.standardizedFileURL.path.hasPrefix(root.path.hasSuffix("/") ? root.path : root.path + "/") else {
                result.skipped += 1
                continue
            }
            do { try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true) }
            catch { throw ArchiveError.io(error.localizedDescription) }
            guard let data = try bytes(of: item, from: f) else { continue }
            var isDir: ObjCBool = false
            if !(fm.fileExists(atPath: dest.path, isDirectory: &isDir) && isDir.boolValue) {
                do { try data.write(to: dest) } catch { throw ArchiveError.io(error.localizedDescription) }
            }
            progress(Int(Double(idx + 1) / Double(files.count) * 100))
        }
        return result
    }
}

/// Taille en kilo-octets d'après 1024, avec la décimale et l'unité de la langue : « 1,3 Ko » (fr), « 1.3 KB » (en).
public func fmtKB(_ bytes: Int) -> String {
    String(format: "%.1f", Double(bytes) / 1024).replacingOccurrences(of: ".", with: I18n.decimal[I18n.lang]!) + " " + I18n.units[I18n.lang]![0]
}
