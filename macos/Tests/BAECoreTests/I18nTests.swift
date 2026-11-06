// Port de tests/test_i18n.py : chaque texte passé à L() / N_() possède une traduction complète, mêmes {x} dans toutes les langues.

import Foundation
import XCTest
@testable import BAECore

final class I18nTests: XCTestCase {
    override func tearDown() { I18n.setLang("fr") }

    static let field = try! NSRegularExpression(pattern: #"\{([A-Za-z_][A-Za-z0-9_]*)[^}]*\}"#)

    static func fields(_ s: String) -> Set<String> {
        Set(field.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { String(s[Range($0.range(at: 1), in: s)!]) })
    }

    /// Clés passées à L / N_ / P dans les sources de l'appli et du cœur.
    static func collectKeys() throws -> Set<String> {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources")
        let call = try NSRegularExpression(pattern: #"(?<![A-Za-z_.])(?:L|N_)\(\s*"((?:[^"\\]|\\.)*)""#)
        var keys = Set<String>()
        for case let url as URL in FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)! where url.pathExtension == "swift" {
            if ["Strings.swift", "I18n.swift"].contains(url.lastPathComponent) { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            for m in call.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                var k = String(text[Range(m.range(at: 1), in: text)!])
                k = k.replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\\"", with: "\"").replacingOccurrences(of: "\\\\", with: "\\")
                keys.insert(k)
            }
        }
        return keys
    }

    func testToutesLesClesTraduites() throws {
        let keys = try Self.collectKeys()
        XCTAssertGreaterThan(keys.count, 20)
        let missing = keys.filter { translations[$0] == nil }.sorted()
        XCTAssertEqual(missing, [], "\(missing.count) clé(s) sans traduction")
        for (k, tr) in translations {
            XCTAssertEqual(tr.count, 3, k)
            for (lang, t) in zip(["en", "it", "es"], tr) {
                XCTAssertFalse(t.trimmingCharacters(in: .whitespaces).isEmpty, "\(lang) vide : \(k)")
                XCTAssertEqual(Self.fields(k), Self.fields(t), "\(lang) : \(k)")
            }
        }
    }

    func testPasDeClesOrphelines() throws {
        let keys = try Self.collectKeys()
        XCTAssertEqual(translations.keys.filter { !keys.contains($0) }.sorted(), [])
    }

    func testChangementDeLangue() {
        I18n.setLang("en")
        XCTAssertEqual(L("Archive vide."), "Empty archive.")
        XCTAssertEqual(L("Erreur : {err}", ["err": "x"]), "Error: x")
        I18n.setLang("it")
        XCTAssertEqual(L("Archive vide."), "Archivio vuoto.")
        I18n.setLang("es")
        XCTAssertEqual(L("Archive vide."), "Archivo vacío.")
        I18n.setLang("fr")
        XCTAssertEqual(L("Erreur : {err}", ["err": "x"]), "Erreur : x")
        XCTAssertEqual(L("Texte inconnu {x}", ["x": 1]), "Texte inconnu 1")
    }

    func testParametreContenantUneAccolade() {
        XCTAssertEqual(L("Erreur : {err}", ["err": "{n}"]), "Erreur : {n}")
    }

    func testLangueSysteme() {
        XCTAssertEqual(I18n.systemLang(["it-IT", "en-US"]), "it")
        XCTAssertEqual(I18n.systemLang(["de-DE", "es-ES"]), "es")
        XCTAssertEqual(I18n.systemLang(["de-DE"]), "en")
    }

    func testChoixDeLangue() {
        XCTAssertEqual(Config.resolve("auto", preferred: ["it-IT"]), "it")
        XCTAssertEqual(Config.resolve("fr", preferred: ["it-IT"]), "fr")
        XCTAssertEqual(Config.resolve(nil, preferred: ["de-DE"]), "en")
        XCTAssertEqual(Config.normalize("xx"), "auto")
    }
}

final class TaillesEtUpdaterTests: XCTestCase {
    override func tearDown() { I18n.setLang("fr") }

    func testTailleEnKo() {
        I18n.setLang("fr"); XCTAssertEqual(fmtKB(1331), "1,3 Ko")
        I18n.setLang("en"); XCTAssertEqual(fmtKB(1331), "1.3 KB")
        I18n.setLang("es"); XCTAssertEqual(fmtKB(0), "0,0 KB")
    }

    /// Tables de textes de la fenêtre de mise à jour (Updater.swift, cible exécutable : lue dans la source) :
    /// mêmes clés, aucun texte vide et mêmes %@ / %d dans les 4 langues.
    func testTablesDeLUpdater() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/mBAE/Updater.swift")
        let src = try String(contentsOf: url, encoding: .utf8)
        let start = try XCTUnwrap(src.range(of: "static let texts"))
        let end = try XCTUnwrap(src.range(of: "static func text(", range: start.upperBound..<src.endIndex))
        let block = String(src[start.upperBound..<end.lowerBound])
        let langRe = try NSRegularExpression(pattern: #"^\s{8}"(fr|en|es|it)": \["#, options: .anchorsMatchLines)
        let pairRe = try NSRegularExpression(pattern: #""([a-z_0-9]+)": "((?:[^"\\]|\\.)*)""#)
        let heads = langRe.matches(in: block, range: NSRange(block.startIndex..., in: block))
        XCTAssertEqual(heads.count, 4)
        var tables: [String: [String: String]] = [:]
        for (i, h) in heads.enumerated() {
            let lang = String(block[Range(h.range(at: 1), in: block)!])
            let from = Range(h.range, in: block)!.upperBound
            let to = i + 1 < heads.count ? Range(heads[i + 1].range, in: block)!.lowerBound : block.endIndex
            let part = String(block[from..<to])
            var t: [String: String] = [:]
            for m in pairRe.matches(in: part, range: NSRange(part.startIndex..., in: part)) {
                t[String(part[Range(m.range(at: 1), in: part)!])] = String(part[Range(m.range(at: 2), in: part)!])
            }
            tables[lang] = t
        }
        let ref = try XCTUnwrap(tables["fr"])
        XCTAssertGreaterThan(ref.count, 10)
        let spec = try NSRegularExpression(pattern: #"%[@dlfs]+"#)
        func specs(_ s: String) -> [String] { spec.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { String(s[Range($0.range, in: s)!]) } }
        for (lang, t) in tables {
            XCTAssertEqual(Set(t.keys), Set(ref.keys), "clés de \(lang)")
            for (k, v) in t {
                XCTAssertFalse(v.trimmingCharacters(in: .whitespaces).isEmpty, "\(lang).\(k) vide")
                XCTAssertEqual(specs(v), specs(ref[k] ?? ""), "\(lang).\(k) : paramètres différents")
            }
        }
    }
}
