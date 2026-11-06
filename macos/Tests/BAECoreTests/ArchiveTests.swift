// Port de tests/test_archives.py (BSA v105 LZ4, noms incorporés, BA2 GNRL, DX10) + BSA zlib v104, bit d'inversion, chemins non sûrs.

import Foundation
import XCTest
import CZlib
@testable import BAECore

final class ArchiveTests: TempCase {
    let payload = rep("Gamebryo File Format", 50)

    func lz4Frame(_ d: Data) -> Data { hex(LZ4Vectors.frame_comp) }  // trame Python de « Gamebryo File Format » × 4200 (voir testFrameLikePython)

    /// Trame LZ4 d'un contenu : bloc stocké (non compressé), valide pour tout décodeur de trame.
    func storedFrame(_ d: Data) -> Data {
        var w = Le()
        w.u32(0x184D2204); w.u8(0x60); w.u8(0x40); w.u8(0)  // FLG v1 indépendants, BD 64 Ko, HC ignoré
        w.u32(d.count | 0x8000_0000); w.raw(d); w.u32(0)
        return w.d
    }

    func testBsaV105Lz4() throws {
        var body = Le(); body.u32(payload.count); body.raw(storedFrame(payload))
        XCTAssertEqual(try extract(bsa(flags: 0x7, body: body.d), "bsa")["a/b.nif"], payload)
    }

    func testBsaV105NomsIncorpores() throws {
        var body = Le(); body.u8(7); body.str("a\\b.nif"); body.u32(payload.count); body.raw(storedFrame(payload))
        XCTAssertEqual(try extract(bsa(flags: 0x107, body: body.d), "bsa")["a/b.nif"], payload)
    }

    func testBsaNonCompresse() throws {
        XCTAssertEqual(try extract(bsa(flags: 0x3, body: payload), "bsa")["a/b.nif"], payload)
    }

    func testBsaV104Zlib() throws {
        var body = Le(); body.u32(payload.count); body.raw(zdeflate(payload))
        let r = try extract(bsa(version: 104, flags: 0x7, body: body.d), "bsa")
        XCTAssertEqual(r["a/b.nif"], payload)
    }

    func testBsaV103Zlib() throws {
        var body = Le(); body.u32(payload.count); body.raw(zdeflate(payload))
        XCTAssertEqual(try extract(bsa(version: 103, flags: 0x7, body: body.d), "bsa")["a/b.nif"], payload)
    }

    /// Bit 30 de la taille : inverse la compression globale du fichier.
    func testBitInversion() throws {
        // archive compressée par défaut, mais ce fichier est stocké brut
        let a = bsa(flags: 0x7, sizeField: payload.count | (1 << 30), body: payload)
        XCTAssertEqual(try extract(a, "bsa")["a/b.nif"], payload)
        // archive brute par défaut, mais ce fichier est compressé
        var body = Le(); body.u32(payload.count); body.raw(storedFrame(payload))
        let b = bsa(flags: 0x3, sizeField: body.d.count | (1 << 30), body: body.d)
        XCTAssertEqual(try extract(b, "bsa")["a/b.nif"], payload)
    }

    func testListe() throws {
        let path = dir.appendingPathComponent("x.bsa")
        try bsa(flags: 0x3, body: payload).write(to: path)
        let a = try BethesdaArchive(path: path.path)
        XCTAssertEqual(a.typeLabel, "BSA")
        XCTAssertEqual(a.version, 105)
        XCTAssertEqual(a.files.map(\.name), ["a/b.nif"])
        XCTAssertEqual(a.files[0].size, payload.count)
        XCTAssertFalse(a.files[0].compressed)
    }

    func ba2Gnrl(compress: Bool = true) -> Data {
        let packed = compress ? zdeflate(payload) : Data()
        let names = 24 + 36 + (compress ? packed.count : payload.count)
        var w = Le()
        w.str("BTDX"); w.u32(1); w.str("GNRL"); w.u32(1); w.u64(names)
        w.u32(1); w.u32(2); w.u32(3); w.u32(0); w.u64(60); w.u32(packed.count); w.u32(payload.count); w.u32(0xBAADF00D)
        w.raw(compress ? packed : payload); w.u16(5); w.str("a/b.c")
        return w.d
    }

    func testBa2GnrlZlib() throws { XCTAssertEqual(try extract(ba2Gnrl(), "ba2")["a/b.c"], payload) }
    func testBa2GnrlBrut() throws { XCTAssertEqual(try extract(ba2Gnrl(compress: false), "ba2")["a/b.c"], payload) }

    func testBa2GnrlLz4BrutStarfield() throws {
        let packed = hex(LZ4Vectors.block_comp)
        let real = rep("Gamebryo File Format ", 200)
        var w = Le()
        w.str("BTDX"); w.u32(2); w.str("GNRL"); w.u32(1); w.u64(24 + 8 + 36 + packed.count)
        w.u64(0)  // octets supplémentaires de l'en-tête v2
        w.u32(1); w.u32(2); w.u32(3); w.u32(0); w.u64(24 + 8 + 36); w.u32(packed.count); w.u32(real.count); w.u32(0xBAADF00D)
        w.raw(packed); w.u16(5); w.str("a\\b.c")
        XCTAssertEqual(try extract(w.d, "ba2")["a/b.c"], real)
    }

    func testBa2Dx10() throws {
        let pixels = Data(repeating: 0x11, count: 64)
        let packed = zdeflate(pixels)
        let names = 24 + 48 + packed.count
        var w = Le()
        w.str("BTDX"); w.u32(1); w.str("DX10"); w.u32(1); w.u64(names)
        w.u32(1); w.u32(2); w.u32(3); w.u8(0); w.u8(1); w.u16(24); w.u16(8); w.u16(8); w.u8(1); w.u8(71); w.u8(0); w.u8(8)
        w.u64(72); w.u32(packed.count); w.u32(pixels.count); w.u16(0); w.u16(0); w.u32(0xBAADF00D)
        w.raw(packed); w.u16(5); w.str("a/b.d")
        let out = try extract(w.d, "ba2")["a/b.d"]!
        XCTAssertEqual(out.prefix(4), Data("DDS ".utf8))
        XCTAssertEqual(out.count, 148 + 64)
        XCTAssertEqual(out.subdata(in: 128..<132), Data([71, 0, 0, 0]))
        XCTAssertEqual(out.subdata(in: 148..<out.count), pixels)
        // champs de l'en-tête
        XCTAssertEqual(out.subdata(in: 12..<20), Data([8, 0, 0, 0, 8, 0, 0, 0]))   // hauteur, largeur
        XCTAssertEqual(out.subdata(in: 4..<8), Data([124, 0, 0, 0]))
        XCTAssertEqual(out.subdata(in: 84..<88), Data("DX10".utf8))
    }

    func testDdsHeaderMipsEtCube() {
        let h = ddsHeader(width: 4, height: 2, mips: 3, dxgi: 98, cube: 1)
        XCTAssertEqual(h.count, 148)
        func u32(_ at: Int) -> Int { Int(h[at]) | Int(h[at + 1]) << 8 | Int(h[at + 2]) << 16 | Int(h[at + 3]) << 24 }
        XCTAssertEqual(u32(8), 0x1007 | 0x20000)
        XCTAssertEqual(u32(28), 3)
        XCTAssertEqual(u32(108), 0x1000 | 0x400008 | 0x8)
        XCTAssertEqual(u32(112), 0xFE00)
        XCTAssertEqual(u32(128), 98)
        XCTAssertEqual(u32(136), 4)
    }

    func testNonReconnue() throws {
        let path = dir.appendingPathComponent("x.bsa")
        try Data("PK\u{3}\u{4}....".utf8).write(to: path)
        XCTAssertThrowsError(try BethesdaArchive(path: path.path)) { e in
            XCTAssertEqual(e.localizedDescription, "Archive non reconnue (ni .bsa, ni .ba2 valide).")
        }
    }

    func testTableDesDossiersTronquee() throws {
        var d = bsa(flags: 0x7, body: Data()); d = d.prefix(50)
        let path = dir.appendingPathComponent("x.bsa")
        try d.write(to: path)
        XCTAssertThrowsError(try BethesdaArchive(path: path.path)) { e in
            XCTAssertEqual(e.localizedDescription, "Archive corrompue : table des dossiers tronquée.")
        }
    }

    func testBsaSansNomsDeFichiers() throws {
        // drapeau 0x2 absent : nom de repli file_<hash>.dat
        let r = try extract(bsa(flags: 0x1, body: payload), "bsa")
        XCTAssertEqual(r["a/file_0000000000000002.dat"], payload)
    }

    func testCheminsNonSurs() {
        XCTAssertNil(BethesdaArchive.safeRelativePath("../x"))
        XCTAssertNil(BethesdaArchive.safeRelativePath("a/../../x"))
        XCTAssertNil(BethesdaArchive.safeRelativePath("/etc/x"))
        XCTAssertNil(BethesdaArchive.safeRelativePath(""))
        XCTAssertEqual(BethesdaArchive.safeRelativePath("a/b..c/d.nif"), "a/b..c/d.nif")
    }

    func testExtractionIgnoreCheminHorsDossier() throws {
        let path = dir.appendingPathComponent("x.bsa")
        try bsa(flags: 0x3, body: payload, file: "b.nif", folder: "a/../..").write(to: path)
        let a = try BethesdaArchive(path: path.path)
        let out = dir.appendingPathComponent("sortie")
        try fm.createDirectory(at: out, withIntermediateDirectories: true)
        let r = try a.extractAll(to: out.path)
        XCTAssertEqual(r.skipped, 1)
        XCTAssertEqual(r.extracted, 0)
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent("b.nif").path))
    }

    func testProgressionEtArret() throws {
        let path = dir.appendingPathComponent("x.bsa")
        try bsa(flags: 0x3, body: payload).write(to: path)
        let a = try BethesdaArchive(path: path.path)
        var seen: [Int] = []
        try a.extractAll(to: dir.appendingPathComponent("o").path, progress: { seen.append($0) })
        XCTAssertEqual(seen, [100])
        let cancelled = dir.appendingPathComponent("o2")
        try a.extractAll(to: cancelled.path, isCancelled: { true })
        XCTAssertFalse(fm.fileExists(atPath: cancelled.appendingPathComponent("a/b.nif").path))
    }
}
