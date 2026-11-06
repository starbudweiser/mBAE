// Archives Bethesda : BSA (v103/104/105) et BA2 (GNRL, DX10) en lecture seule. Traduction fidèle de BethesdaArchive (Python).

import Foundation

public enum ArchiveError: Error, LocalizedError {
    case notRecognized
    case foldersTruncated
    case truncated
    case decompress
    case io(String)

    public var errorDescription: String? {
        switch self {
        case .notRecognized: L("Archive non reconnue (ni .bsa, ni .ba2 valide).")
        case .foldersTruncated: L("Archive corrompue : table des dossiers tronquée.")
        case .truncated: L("Archive corrompue : données tronquées.")
        case .decompress: L("Décompression impossible : données invalides.")
        case .io(let m): L("Impossible de lire l'archive : {err}", ["err": m])
        }
    }
}

public enum ArchiveKind: String { case bsa = "BSA", ba2 = "BA2" }

public struct Chunk: Equatable {
    public var offset: UInt64
    public var packed: Int
    public var full: Int
}

/// Texture DX10 : largeur, hauteur, niveaux de mip, format DXGI, carte cubique.
public struct Texture: Equatable {
    public var width: Int, height: Int, mips: Int, dxgi: Int, cube: Int
}

public struct ArchiveEntry {
    public var name: String
    public var size: Int          // taille brute affichée
    public var offset: UInt64
    public var compressed: Bool
    public var packedSize = 0     // BA2
    public var realSize = 0       // BA2
    public var chunks: [Chunk]?   // BA2 DX10
    public var texture: Texture?  // BA2 DX10
}

/// Lecteur séquentiel d'un fichier : lectures courtes autorisées (comme file.read), `exact` pour les structures.
final class Reader {
    let handle: FileHandle
    let length: UInt64
    init(_ url: URL) throws {
        do {
            handle = try FileHandle(forReadingFrom: url)
            length = try handle.seekToEnd()
            try handle.seek(toOffset: 0)
        } catch { throw ArchiveError.io(error.localizedDescription) }
    }
    deinit { try? handle.close() }

    func seek(_ offset: UInt64) throws { do { try handle.seek(toOffset: offset) } catch { throw ArchiveError.io(error.localizedDescription) } }
    func skip(_ n: Int) throws { try seek(handle.offsetInFile + UInt64(n)) }

    func read(_ n: Int) throws -> Data {
        guard n > 0 else { return Data() }
        // Jamais plus que ce qui reste dans le fichier (une taille aberrante ne doit pas allouer des gigaoctets)
        let here = (try? handle.offset()) ?? 0
        let n = Int(min(UInt64(n), length > here ? length - here : 0))
        guard n > 0 else { return Data() }
        do { return try handle.read(upToCount: n) ?? Data() } catch { throw ArchiveError.io(error.localizedDescription) }
    }

    func exact(_ n: Int, _ error: ArchiveError = .truncated) throws -> [UInt8] {
        let d = try read(n)
        guard d.count == n else { throw error }
        return [UInt8](d)
    }
}

extension Array where Element == UInt8 {
    func le(_ at: Int, _ width: Int) -> UInt64 {
        var v: UInt64 = 0
        for k in 0..<width { v |= UInt64(self[at + k]) << UInt64(8 * k) }
        return v
    }
}

/// Équivalent de str.strip() de Python sur un texte latin-1 (espaces, séparateurs 0x1c-0x1f, 0x85, 0xa0).
func pyStrip(_ s: String) -> String {
    let drop: (Unicode.Scalar) -> Bool = { $0.properties.isWhitespace || (0x1c...0x1f).contains($0.value) }
    var u = Substring(s).unicodeScalars
    while let f = u.first, drop(f) { u.removeFirst() }
    while let l = u.last, drop(l) { u.removeLast() }
    return String(u)
}

func latin1(_ d: Data) -> String { String(d.map { Character(Unicode.Scalar($0)) }) }

public final class BethesdaArchive: @unchecked Sendable {
    public let url: URL
    public private(set) var files: [ArchiveEntry] = []
    public private(set) var kind: ArchiveKind = .bsa
    public private(set) var version = 0
    public private(set) var embeddedNames = false

    public var typeLabel: String { kind.rawValue }

    public init(path: String) throws {
        url = URL(fileURLWithPath: path)
        let f = try Reader(url)
        let magic = try f.read(4)
        if magic == Data([0x42, 0x53, 0x41, 0x00]) {
            kind = .bsa
            try parseBSA(f)
        } else if magic == Data("BTDX".utf8) {
            kind = .ba2
            try parseBA2(f)
        } else {
            throw ArchiveError.notRecognized
        }
    }

    private func parseBSA(_ f: Reader) throws {
        let h = try f.exact(32)
        let version = Int(h.le(0, 4)); self.version = version
        let archiveFlags = h.le(8, 4)
        let folderCount = Int(h.le(12, 4))
        let totalFileNameLen = Int(h.le(24, 4))
        let hasDirNames = archiveFlags & 0x1 != 0
        let hasFileNames = archiveFlags & 0x2 != 0
        let defaultCompressed = archiveFlags & 0x4 != 0
        embeddedNames = version >= 104 && archiveFlags & 0x100 != 0

        // 1. Enregistrements de dossiers : 24 octets en v105, 16 avant
        let recSize = version >= 105 ? 24 : 16
        var counts: [(hash: UInt64, count: Int)] = []
        for _ in 0..<folderCount {
            let b = try f.exact(recSize, .foldersTruncated)
            counts.append((b.le(0, 8), Int(b.le(8, 4))))
        }

        // 2. Pour chaque dossier : nom puis liste de fichiers
        var folders: [(name: String, files: [(hash: UInt64, size: Int, offset: UInt64, compressed: Bool)])] = []
        outer: for rf in counts {
            var folderName = ""
            if hasDirNames {
                let b = try f.read(1)
                if b.isEmpty { break outer }
                let raw = try f.read(Int(b[b.startIndex]))
                let cut = raw.firstIndex(of: 0).map { raw[raw.startIndex..<$0] } ?? raw[...]
                folderName = latin1(Data(cut)).replacingOccurrences(of: "\\", with: "/")
            }
            var list: [(UInt64, Int, UInt64, Bool)] = []
            for _ in 0..<rf.count {
                let b = try f.read(16)
                if b.count < 16 { break }
                let a = [UInt8](b)
                let size = Int(a.le(8, 4))
                var comp = defaultCompressed
                if size & (1 << 30) != 0 { comp = !defaultCompressed }
                list.append((a.le(0, 8), size & 0x3FFF_FFFF, a.le(12, 4), comp))
            }
            folders.append((folderName, list))
        }

        // 3. Table globale des noms de fichiers
        var fileNames: [String] = []
        if hasFileNames && totalFileNameLen > 0 {
            let blob = try f.read(totalFileNameLen)
            fileNames = blob.split(separator: 0, omittingEmptySubsequences: false).map { pyStrip(latin1(Data($0))) }
        }

        // 4. Association noms / dossiers
        var idx = 0
        for fd in folders {
            let prefix = fd.name.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            for fi in fd.files {
                let name: String
                if idx < fileNames.count && !fileNames[idx].isEmpty {
                    name = fileNames[idx]
                } else {
                    name = "file_" + String(format: "%016llx", fi.hash) + ".dat"
                }
                idx += 1
                var full = prefix.isEmpty ? name : "\(prefix)/\(name)"
                if !prefix.isEmpty { while full.hasPrefix("/") { full.removeFirst() } }
                if !full.isEmpty && !full.hasSuffix("/") {
                    files.append(ArchiveEntry(name: full, size: fi.size, offset: fi.offset, compressed: fi.compressed))
                }
            }
        }
    }

    private func parseBA2(_ f: Reader) throws {
        let h = try f.exact(16)
        let version = Int(h.le(0, 4)); self.version = version
        let headerType = Data(h[4..<8])
        let numFiles = Int(h.le(8, 4))
        let nameTableOffset = h.le(12, 4) | (try f.exact(4).le(0, 4) << 32)
        // Starfield : v2 = 8 octets en plus, v3 = 12. Les v7 / v8 (Fallout 4 « nouvelle génération ») ont l'en-tête de la v1 :
        // la version Python sautait 8 octets pour elles aussi et lisait des tables de fichiers fausses (erreur d'extraction).
        if version == 2 { try f.skip(8) } else if version == 3 { try f.skip(12) }

        var metas: [ArchiveEntry] = []
        if headerType == Data("GNRL".utf8) {
            for _ in 0..<numFiles {
                let m = try f.exact(36)
                let packed = Int(m.le(24, 4)), real = Int(m.le(28, 4))
                metas.append(ArchiveEntry(name: "", size: real, offset: m.le(16, 8), compressed: packed > 0, packedSize: packed, realSize: real))
            }
        } else if headerType == Data("DX10".utf8) {
            for _ in 0..<numFiles {
                let m = try f.exact(24)
                let nChunks = Int(m[13])
                var chunks: [Chunk] = []
                for _ in 0..<nChunks {
                    let c = try f.exact(24)
                    chunks.append(Chunk(offset: c.le(0, 8), packed: Int(c.le(8, 4)), full: Int(c.le(12, 4))))
                }
                let real = chunks.reduce(0) { $0 + $1.full } + 148
                metas.append(ArchiveEntry(
                    name: "", size: real, offset: chunks.first?.offset ?? 0, compressed: chunks.contains { $0.packed != 0 },
                    packedSize: chunks.reduce(0) { $0 + $1.packed }, realSize: real, chunks: chunks,
                    texture: Texture(width: Int(m.le(18, 2)), height: Int(m.le(16, 2)), mips: Int(m[20]), dxgi: Int(m[21]), cube: Int(m[22]))))
            }
        }

        try f.seek(nameTableOffset)
        for var meta in metas {
            let l = try f.exact(2)
            let len = Int(l.le(0, 2))
            let raw = try f.read(len)
            var name = String(decoding: raw, as: UTF8.self).replacingOccurrences(of: "\\", with: "/")
            name = name.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            meta.name = name
            if !name.isEmpty { files.append(meta) }
        }
    }
}
