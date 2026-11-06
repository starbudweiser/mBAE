// Réglages : ~/Library/Application Support/mBAE/config.json, clé « language » (« auto » ou fr/en/es/it).
// La version Python n'avait aucun réglage de langue enregistré : on repart sur « Automatique ».

import Foundation

public enum Config {
    public static let auto = "auto"
    /// Entrées du menu Langue, dans leur propre langue.
    public static let menuLangs: [(code: String, label: String)] = [("fr", "Français"), ("en", "English"), ("es", "Español"), ("it", "Italiano")]

    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/mBAE/config.json")
    }

    public static func normalize(_ choice: String?) -> String {
        let c = (choice ?? "").trimmingCharacters(in: .whitespaces)
        return I18n.langs[c] != nil ? c : auto
    }

    /// Langue à afficher pour un choix mémorisé.
    public static func resolve(_ choice: String?, preferred: [String] = Locale.preferredLanguages) -> String {
        let c = normalize(choice)
        return c == auto ? I18n.systemLang(preferred) : c
    }

    public static func load(_ url: URL = defaultURL) -> [String: Any] {
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }

    public static func save(_ config: [String: Any], to url: URL = defaultURL) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            try data.write(to: url, options: .atomic)
        } catch {
            FileHandle.standardError.write(Data("Config save failed: \(error)\n".utf8))
        }
    }

    public static func choice(_ config: [String: Any]) -> String { normalize(config["language"] as? String) }
}
