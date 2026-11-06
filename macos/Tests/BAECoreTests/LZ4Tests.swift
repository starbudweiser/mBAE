// Décodeur LZ4 : vecteurs produits par le module Python lz4 (blocs bruts et trames, compressibles et non).

import Foundation
import XCTest
import CZlib
@testable import BAECore

final class LZ4Tests: XCTestCase {
    let comp = rep("Gamebryo File Format ", 200)
    var rnd: Data { lcg(3000) }
    var mixed: Data { var m = Data(); for _ in 0..<3 { m += rep("abc", 50) + rnd.prefix(500) + rep("xyz", 400) + rnd[500..<1500] }; return m }
    var big: Data { rep("0123456789abcdef", 8000) + lcg(5000) + rep("0123456789abcdef", 3000) }

    func testBlocs() {
        XCTAssertEqual(LZ4.decodeBlock(hex(LZ4Vectors.block_comp), maxSize: comp.count), comp)
        XCTAssertEqual(LZ4.decodeBlock(hex(LZ4Vectors.block_rnd), maxSize: rnd.count), rnd)
        XCTAssertEqual(LZ4.decodeBlock(hex(LZ4Vectors.block_mixed), maxSize: mixed.count), mixed)
        XCTAssertEqual(LZ4.decodeBlock(hex(LZ4Vectors.block_tiny), maxSize: 1), Data("a".utf8))
        XCTAssertEqual(LZ4.decodeBlock(hex(LZ4Vectors.block_big), maxSize: big.count), big)
    }

    func testBlocPlusGrandQueLaTailleAnnoncee() {
        XCTAssertNil(LZ4.decodeBlock(hex(LZ4Vectors.block_comp), maxSize: comp.count - 1))
    }

    func testTrames() {
        XCTAssertEqual(LZ4.decodeFrame(hex(LZ4Vectors.frame_comp)), comp)
        XCTAssertEqual(LZ4.decodeFrame(hex(LZ4Vectors.frame_rnd)), rnd)
        XCTAssertEqual(LZ4.decodeFrame(hex(LZ4Vectors.frame_mixed)), mixed)
        XCTAssertEqual(LZ4.decodeFrame(hex(LZ4Vectors.frame_tiny)), Data("a".utf8))
        XCTAssertEqual(LZ4.decodeFrame(hex(LZ4Vectors.frame_big)), big)
        XCTAssertEqual(LZ4.decodeFrame(hex(LZ4Vectors.frame_empty)), Data())
    }

    func testTramesBlocsLiesEtIndependants() {
        XCTAssertEqual(LZ4.decodeFrame(hex(LZ4Vectors.frame_linked)), big)
        XCTAssertEqual(LZ4.decodeFrame(hex(LZ4Vectors.frame_indep)), big)  // avec sommes de blocs et de contenu
    }

    func testDeuxTramesALaSuite() {
        XCTAssertEqual(LZ4.decodeFrame(hex(LZ4Vectors.frame_two)), comp + rnd)
    }

    func testInvalides() {
        XCTAssertNil(LZ4.decodeFrame(Data()))
        XCTAssertNil(LZ4.decodeFrame(Data([1, 2, 3, 4, 5, 6])))
        let f = hex(LZ4Vectors.frame_comp)
        XCTAssertNil(LZ4.decodeFrame(f.prefix(f.count - 6)))  // tronquée
        XCTAssertNil(LZ4.decodeBlock(Data([0xF0]), maxSize: 100))
        XCTAssertNil(LZ4.decodeBlock(Data([0x10, 0x41, 0x00, 0x00]), maxSize: 100))  // décalage nul
    }
}

final class InflateTests: XCTestCase {
    func testZlib() {
        let d = rep("Gamebryo File Format ", 500) + lcg(2000)
        XCTAssertEqual(Inflate.zlib(zdeflate(d)), d)
        XCTAssertEqual(Inflate.zlib(zdeflate(Data())), Data())
    }
    func testDonneesApresLaFinIgnorees() {
        let d = rep("abc", 100)
        XCTAssertEqual(Inflate.zlib(zdeflate(d) + Data([1, 2, 3])), d)
    }
    func testInvalide() {
        XCTAssertNil(Inflate.zlib(Data()))
        XCTAssertNil(Inflate.zlib(Data([0x41, 0x42, 0x43, 0x44])))
        let z = zdeflate(rep("abc", 1000))
        XCTAssertNil(Inflate.zlib(z.prefix(z.count - 5)))  // tronqué
    }
}
