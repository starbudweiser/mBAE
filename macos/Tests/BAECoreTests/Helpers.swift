import Foundation
import XCTest
import CZlib
@testable import BAECore

func hex(_ s: String) -> Data {
    var d = Data(); var i = s.startIndex
    while i < s.endIndex { let j = s.index(i, offsetBy: 2); d.append(UInt8(s[i..<j], radix: 16)!); i = j }
    return d
}

/// Mêmes données que le générateur Python des vecteurs.
func lcg(_ n: Int) -> Data {
    var x: UInt64 = 12345; var o = Data()
    for _ in 0..<n { x = (x &* 1103515245 &+ 12345) & 0x7fffffff; o.append(UInt8((x >> 16) & 0xff)) }
    return o
}
func rep(_ s: String, _ n: Int) -> Data { Data(String(repeating: s, count: n).utf8) }

struct Le {
    var d = Data()
    mutating func u8(_ v: Int) { d.append(UInt8(v)) }
    mutating func u16(_ v: Int) { d.append(contentsOf: [UInt8(v & 255), UInt8((v >> 8) & 255)]) }
    mutating func u32(_ v: Int) { for k in 0..<4 { d.append(UInt8((v >> (8 * k)) & 255)) } }
    mutating func u64(_ v: Int) { for k in 0..<8 { d.append(UInt8((v >> (8 * k)) & 255)) } }
    mutating func raw(_ b: Data) { d.append(b) }
    mutating func str(_ s: String) { d.append(contentsOf: Array(s.utf8)) }
}

/// zlib.compress via la libz (pour fabriquer des archives de test).
func zdeflate(_ data: Data) -> Data {
    var len = compressBound(uLong(data.count))
    var out = [UInt8](repeating: 0, count: Int(len))
    let r = data.withUnsafeBytes { compress(&out, &len, $0.bindMemory(to: UInt8.self).baseAddress, uLong(data.count)) }
    precondition(r == Z_OK)
    return Data(out[0..<Int(len)])
}

/// Dossier « a », fichier « b.nif » dont les données sont `body` (BSA v105 ou autre version `ver`).
func bsa(version ver: Int = 105, flags: Int, sizeField: Int? = nil, body: Data, file: String = "b.nif", folder: String = "a") -> Data {
    var w = Le()
    let rec = ver >= 105 ? 24 : 16
    let head = 36 + rec + (folder.utf8.count + 2) + 16 + (file.utf8.count + 1)
    w.str("BSA\0"); w.u32(ver); w.u32(36); w.u32(flags); w.u32(1); w.u32(1); w.u32(folder.utf8.count + 2); w.u32(file.utf8.count + 1); w.u32(0)
    w.u64(1); w.u32(1)
    if ver >= 105 { w.u32(0); w.u64(0) } else { w.u32(0) }
    w.u8(folder.utf8.count + 1); w.str(folder); w.u8(0)
    w.u64(2); w.u32(sizeField ?? body.count); w.u32(head)
    w.str(file); w.u8(0)
    w.raw(body)
    return w.d
}

class TempCase: XCTestCase {
    var dir: URL!
    let fm = FileManager.default
    override func setUpWithError() throws {
        I18n.setLang("fr")
        dir = fm.temporaryDirectory.appendingPathComponent("mbae-tests-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? fm.removeItem(at: dir) }

    /// Écrit l'archive, l'extrait et renvoie {chemin relatif: octets}.
    func extract(_ data: Data, _ ext: String) throws -> [String: Data] {
        let path = dir.appendingPathComponent("x." + ext)
        try data.write(to: path)
        let archive = try BethesdaArchive(path: path.path)
        let out = dir.appendingPathComponent("out")
        try archive.extractAll(to: out.path)
        var result: [String: Data] = [:]
        if let en = fm.enumerator(at: out, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let u as URL in en where (try? u.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                result[String(u.standardizedFileURL.path.dropFirst(out.standardizedFileURL.path.count + 1))] = try Data(contentsOf: u)
            }
        }
        return result
    }
}
