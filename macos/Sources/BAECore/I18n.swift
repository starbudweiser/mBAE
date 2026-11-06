// Internationalisation : français (source), anglais, italien, espagnol.
//
// Le texte français sert de clé : L("Texte {x}", ["x": 1]) renvoie la traduction de la langue
// active, ou le français si elle manque. La table vient de i18n/strings.json (Strings.swift généré),
// partagée avec la preview web. La langue est celle du Mac, fixée au lancement.

import Foundation

public enum I18n {
    public static let langs = ["fr": "Français", "en": "English", "it": "Italiano", "es": "Español"]
    static let index = ["en": 0, "it": 1, "es": 2]

    // Séparateurs des nombres et unités de taille (décimales, comme le Finder)
    static let thousands = ["fr": "\u{00a0}", "en": ",", "it": ".", "es": "."]
    static let decimal = ["fr": ",", "en": ".", "it": ",", "es": ","]
    static let units = [
        "fr": ["Ko", "Mo", "Go", "To"],
        "en": ["KB", "MB", "GB", "TB"],
        "it": ["KB", "MB", "GB", "TB"],
        "es": ["KB", "MB", "GB", "TB"],
    ]

    nonisolated(unsafe) public private(set) static var lang = "fr"

    /// Première langue prise en charge parmi les langues préférées du système
    /// (codes « fr-FR », « en_US »…), sinon `fallback`.
    public static func systemLang(_ preferred: [String] = Locale.preferredLanguages, fallback: String = "en") -> String {
        for code in preferred {
            let c = String(code.prefix(2)).lowercased()
            if langs[c] != nil { return c }
        }
        return fallback
    }

    @discardableResult
    public static func setLang(_ code: String) -> String {
        lang = langs[code] != nil ? code : "fr"
        return lang
    }

    public static var keys: Set<String> { Set(translations.keys) }
    public static func translation(_ key: String) -> [String]? { translations[key] }
}

/// Marque un texte à traduire sans le traduire (traduit plus tard par L).
@inline(__always) public func N_(_ text: String) -> String { text }

/// Traduit `text` (clé française) et remplace les paramètres {nom}.
public func L(_ text: String, _ kw: [String: Any] = [:]) -> String {
    var out = text
    if I18n.lang != "fr", let i = I18n.index[I18n.lang], let tr = translations[text], !tr[i].isEmpty {
        out = tr[i]
    }
    guard !kw.isEmpty else { return out }
    // Un seul passage : un paramètre qui contient « {x} » (nom de fichier) n'est pas remplacé à son tour
    var result = ""
    var rest = out[...]
    while let open = rest.firstIndex(of: "{") {
        result += rest[..<open]
        if let close = rest[open...].firstIndex(of: "}"), let v = kw[String(rest[rest.index(after: open)..<close])] {
            result += "\(v)"
            rest = rest[rest.index(after: close)...]
        } else {
            result.append("{")
            rest = rest[rest.index(after: open)...]
        }
    }
    return result + rest
}

/// Singulier ou pluriel selon `n` (en français, 0 et 1 sont au singulier).
/// `{n}` reçoit le nombre formaté selon la langue.
public func P(_ n: Int, _ one: String, _ many: String, _ kw: [String: Any] = [:]) -> String {
    let singular = I18n.lang == "fr" ? n <= 1 : n == 1
    var kw = kw
    kw["n"] = fmtInt(n)
    return L(singular ? one : many, kw)
}

/// 12345 → « 12 345 » (fr), « 12,345 » (en), « 12.345 » (it, es).
public func fmtInt(_ n: Int) -> String {
    let digits = String(abs(n))
    var out = ""
    for (i, ch) in digits.enumerated() {
        if i > 0 && (digits.count - i) % 3 == 0 { out += I18n.thousands[I18n.lang]! }
        out.append(ch)
    }
    return n < 0 ? "-" + out : out
}

/// Taille lisible en unités décimales : « 12,4 Go », « 12.4 GB »…
public func fmtSize(_ bytes: Int64) -> String {
    if bytes < 1000 { return P(Int(bytes), "{n} octet", "{n} octets") }
    var n = Double(bytes)
    let units = I18n.units[I18n.lang]!
    for unit in units {
        n /= 1000
        if n < 1000 || unit == units.last! {
            return String(format: "%.1f", n).replacingOccurrences(of: ".", with: I18n.decimal[I18n.lang]!) + " " + unit
        }
    }
    return ""
}
