// Décodeur LZ4 en Swift pur : bloc brut et trame standard (magic 0x184D2204). Les sommes de contrôle ne sont pas vérifiées.

import Foundation

public enum LZ4 {
    /// Bloc LZ4 brut → octets. `maxSize` : taille maximale de sortie (taille décompressée annoncée).
    /// Renvoie ce qui a été décodé, ou `nil` si le bloc est invalide ou dépasse `maxSize`.
    public static func decodeBlock(_ src: Data, maxSize: Int) -> Data? {
        var out = [UInt8]()
        let bytes = [UInt8](src)
        return decodeBlock(bytes, into: &out, limit: maxSize, start: 0, end: bytes.count) ? Data(out) : nil
    }

    /// Décode s[start..<end] et l'ajoute à `out`, sans dépasser `limit` octets pour ce bloc. Les correspondances peuvent viser
    /// les données déjà présentes dans `out` (blocs dépendants d'une trame).
    static func decodeBlock(_ s: [UInt8], into out: inout [UInt8], limit: Int, start: Int, end: Int) -> Bool {
        let base = out.count
        guard limit >= 0, limit < Int.max / 2 else { return false }
        out.append(contentsOf: repeatElement(0, count: limit))  // zone de travail, réduite à la taille décodée ensuite
        var written = 0
        let ok: Bool = s.withUnsafeBufferPointer { src in
            out.withUnsafeMutableBufferPointer { dst in
                var i = start
                var o = base          // position d'écriture dans dst
                let cap = base + limit
                while i < end {
                    let token = Int(src[i]); i += 1
                    var lit = token >> 4
                    if lit == 15 {
                        while true {
                            if i >= end { return false }
                            let b = Int(src[i]); i += 1
                            lit += b
                            if b != 255 { break }
                        }
                    }
                    if lit > end - i || lit > cap - o { return false }
                    if lit > 0 { memcpy(dst.baseAddress! + o, src.baseAddress! + i, lit) }
                    i += lit; o += lit
                    if i >= end { break }  // dernier jeu de littéraux : pas de correspondance
                    if i + 2 > end { return false }
                    let offset = Int(src[i]) | Int(src[i + 1]) << 8
                    i += 2
                    if offset == 0 || offset > o { return false }
                    var len = token & 15
                    if len == 15 {
                        while true {
                            if i >= end { return false }
                            let b = Int(src[i]); i += 1
                            len += b
                            if b != 255 { break }
                        }
                    }
                    len += 4
                    if len > cap - o { return false }
                    let d = dst.baseAddress!
                    if offset >= len {
                        memcpy(d + o, d + o - offset, len)
                    } else {
                        for k in 0..<len { d[o + k] = d[o + k - offset] }
                    }
                    o += len
                }
                written = o - base
                return true
            }
        }
        out.removeLast(limit - written)
        return ok
    }

    /// Trame LZ4 (une ou plusieurs trames à la suite, trames « saut » ignorées) → octets. `nil` si invalide.
    public static func decodeFrame(_ src: Data) -> Data? {
        let s = [UInt8](src)
        var out = [UInt8]()
        var p = 0
        func u32(_ at: Int) -> UInt32? {
            guard at + 4 <= s.count else { return nil }
            return UInt32(s[at]) | UInt32(s[at + 1]) << 8 | UInt32(s[at + 2]) << 16 | UInt32(s[at + 3]) << 24
        }
        var frames = 0
        while p < s.count {
            guard let magic = u32(p) else { return nil }
            p += 4
            if magic & 0xFFFF_FFF0 == 0x184D_2A50 {  // trame saut
                guard let size = u32(p) else { return nil }
                p += 4 + Int(size)
                guard p <= s.count else { return nil }
                continue
            }
            guard magic == 0x184D_2204, p + 2 <= s.count else { return nil }
            let flg = s[p], bd = s[p + 1]
            p += 2
            guard flg >> 6 == 1, bd & 0x8F == 0 else { return nil }
            let blockChecksum = flg & 0x10 != 0
            let contentSize = flg & 0x08 != 0
            let contentChecksum = flg & 0x04 != 0
            let dictID = flg & 0x01 != 0
            let maxBlock: Int
            switch (bd >> 4) & 7 {
            case 4: maxBlock = 64 << 10
            case 5: maxBlock = 256 << 10
            case 6: maxBlock = 1 << 20
            case 7: maxBlock = 4 << 20
            default: return nil
            }
            if contentSize { p += 8 }
            if dictID { p += 4 }
            p += 1  // octet de contrôle de l'en-tête
            guard p <= s.count else { return nil }
            while true {
                guard let raw = u32(p) else { return nil }
                p += 4
                if raw == 0 { break }  // fin de trame
                let stored = raw & 0x8000_0000 != 0
                let size = Int(raw & 0x7FFF_FFFF)
                guard size <= maxBlock, p + size <= s.count else { return nil }
                if stored {
                    out.append(contentsOf: s[p..<(p + size)])
                } else {
                    // blocs indépendants ou liés : dans les deux cas le décodage s'appuie sur la sortie déjà produite
                    guard decodeBlock(s, into: &out, limit: maxBlock, start: p, end: p + size) else { return nil }
                }
                p += size
                if blockChecksum { p += 4 }
            }
            if contentChecksum { p += 4 }
            guard p <= s.count else { return nil }
            frames += 1
        }
        return frames > 0 ? Data(out) : nil
    }
}
