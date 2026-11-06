// Mise à jour automatique des applis Skyrim Tools et personnelles (Swift). Remplace UpdateCheck.swift.
//
// FICHIER COMMUN : la source est _tools/shared/Updater.swift (avec UpdaterView.swift), recopiée dans chaque appli par
// _tools/sync_shared.sh. Ne pas le modifier dans une appli. Tests : _tools/shared/swift-tests (swift test).
// Mêmes règles que _tools/shared/updater.py :
// - une requête par jour au plus (GET /repos/starbudweiser/<dépôt>/releases), plus « Rechercher les mises à jour… » ;
// - les releases publiées plus récentes que la version installée sont listées, leurs notes (balises
//   <!-- notes:xx --> de release_notes.py) s'affichent dans la langue de l'appli avant toute installation ;
// - « Installer et relancer » : téléchargement (api.github.com et *.githubusercontent.com seulement), SHA-256 du .sha256,
//   ditto, identifiant, version annoncée, codesign --strict --deep, Team ID 35KLMK53PN, même exigence de signature que
//   l'appli en cours, ticket de notarisation (stapler) ; script à part : attend la fin de l'appli, garde l'ancienne copie,
//   remplace par ditto, la remet en cas d'échec, relance ;
// - dossier non inscriptible : droits demandés par la fenêtre système (osascript) ;
// - SKYRIM_TOOLS_NO_UPDATE_CHECK désactive la vérification automatique (essais) ;
// - clé Info.plist SkyrimUpdateAcceptBundleID : l'édition de test reçoit le paquet officiel.
//
// Utilisation : UpdateEngine.shared.configure(repo: "nEXUSWATCH", lang: { L.lang })  puis  UpdateEngine.shared.start() ;
// menu « Rechercher les mises à jour… » : UpdateEngine.shared.installAppMenuItem() ou UpdateEngine.shared.checkNow().
import AppKit
import CryptoKit
import Foundation

// MARK: - Versions et releases

/// Version `x.y.z` (préfixe `v` et suffixe `-beta` ignorés).
struct AppVersion: Comparable, Equatable, CustomStringConvertible {
    let parts: [Int]

    init?(_ text: String) {
        var core = text.trimmingCharacters(in: .whitespaces)
        if core.hasPrefix("v") || core.hasPrefix("V") { core.removeFirst() }
        core = core.split(separator: "-").first.map(String.init) ?? core
        let numbers = core.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !numbers.isEmpty, numbers.count <= 3, numbers.allSatisfy({ $0 != nil }) else { return nil }
        parts = numbers.compactMap { $0 } + Array(repeating: 0, count: 3 - numbers.count)
    }

    static func < (a: AppVersion, b: AppVersion) -> Bool { a.parts.lexicographicallyPrecedes(b.parts) }
    var description: String { parts.map(String.init).joined(separator: ".") }
}

struct UpdateRelease: Equatable {
    var tag: String
    var version: String
    var body: String
    var zipName: String
    var zipURL: URL
    var shaURL: URL
}

/// Mise à jour proposée : la plus récente, et toutes les releases plus récentes que la version installée (la plus récente d'abord).
struct UpdatePlan: Equatable {
    var current: String
    var target: UpdateRelease
    var releases: [UpdateRelease]
}

enum Updater {
    static let owner = "starbudweiser"
    static let teamID = "35KLMK53PN"
    static let apiHost = "api.github.com"
    static let acceptKey = "SkyrimUpdateAcceptBundleID"
    static let langs = ["fr", "en", "es", "it"]

    static func hostAllowed(_ host: String?) -> Bool {
        guard let host else { return false }
        return host == apiHost || host.hasSuffix(".githubusercontent.com")
    }

    /// Réponse de GET /releases : releases publiées (ni brouillon ni préversion) portant un zip et son .sha256.
    static func parseReleases(_ data: Data) -> [UpdateRelease] {
        guard let list = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return [] }
        var out: [UpdateRelease] = []
        for j in list {
            guard (j["draft"] as? Bool) != true, (j["prerelease"] as? Bool) != true,
                  let tag = j["tag_name"] as? String, let version = AppVersion(tag),
                  let assets = j["assets"] as? [[String: Any]] else { continue }
            var urls: [String: URL] = [:]
            for a in assets {
                guard let name = a["name"] as? String, let text = a["url"] as? String, let url = URL(string: text),
                      url.scheme == "https", url.host == apiHost else { continue }
                urls[name] = url
            }
            let zips = urls.keys.filter { $0.hasSuffix(".zip") && urls[$0 + ".sha256"] != nil }.sorted()
            guard let zip = zips.first(where: { $0.contains("arm64") }) ?? zips.first,
                  let zipURL = urls[zip], let shaURL = urls[zip + ".sha256"] else { continue }
            out.append(UpdateRelease(tag: tag, version: version.description, body: j["body"] as? String ?? "",
                                     zipName: zip, zipURL: zipURL, shaURL: shaURL))
        }
        return out
    }

    /// Releases plus récentes que la version installée, de la plus récente à la plus ancienne.
    static func newer(_ releases: [UpdateRelease], than current: String) -> [UpdateRelease] {
        guard let cur = AppVersion(current) else { return [] }
        return releases.filter { AppVersion($0.version)! > cur }.sorted { AppVersion($0.version)! > AppVersion($1.version)! }
    }

    static func normalizeLang(_ lang: String?) -> String {
        let code = String((lang ?? "").prefix(2)).lowercased()
        return langs.contains(code) ? code : "en"
    }

    /// Notes d'une release dans la langue demandée (anglais à défaut) ; corps entier nettoyé si aucune balise.
    static func extractNotes(_ body: String, lang: String) -> String {
        let pattern = try! NSRegularExpression(pattern: #"<!--\s*notes:(\w+)\s*-->"#)
        let ns = body as NSString
        let marks = pattern.matches(in: body, range: NSRange(location: 0, length: ns.length))
        var sections: [String: String] = [:]
        for (i, m) in marks.enumerated() {
            let start = m.range.location + m.range.length
            let end = i + 1 < marks.count ? marks[i + 1].range.location : ns.length
            sections[ns.substring(with: m.range(at: 1)).lowercased()] = ns.substring(with: NSRange(location: start, length: end - start))
        }
        var chosen: String
        if sections.isEmpty {
            chosen = body.components(separatedBy: "\n---").first ?? ""
            chosen = chosen.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: CharacterSet(charactersIn: "*_ ")).lowercased().hasPrefix("full changelog") }
                .joined(separator: "\n")
        } else {
            chosen = sections[normalizeLang(lang)].flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                ?? sections["en"] ?? ""
        }
        // titre de langue (« ## Français ») en tête
        if let r = chosen.range(of: #"\A\s*#{1,6}[^\n]*\n"#, options: .regularExpression) { chosen.removeSubrange(r) }
        return chosen.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Markdown : une section « ## X.Y.Z » par release, de la plus récente à la plus ancienne ; releases sans note omises.
    static func buildNotes(_ releases: [UpdateRelease], lang: String) -> String {
        releases.compactMap { r -> String? in
            let n = extractNotes(r.body, lang: lang)
            return n.isEmpty ? nil : "## \(r.version)\n\n\(n)"
        }.joined(separator: "\n\n")
    }

    // MARK: Script d'installation

    private static func quoted(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    /// Script lancé à part : attend la fin de l'appli, garde l'ancienne copie, remplace par ditto (la remet en cas d'échec), relance.
    /// `quiet` : relance sans passer au premier plan ; `chown` « uid:gid » : copie faite avec des droits administrateur.
    static func installScript(pid: Int32, newApp: String, destination: String, relaunch: Bool, quiet: Bool = false, chown: String? = nil) -> String {
        let old = destination + ".old"
        let own = chown.map { "/usr/sbin/chown -R \(quoted($0)) \(quoted(destination)) 2>/dev/null\n" } ?? ""
        let reopen = relaunch ? "/usr/bin/open \(quiet ? "-g " : "")\(quoted(destination))\n" : ""
        return """
        #!/bin/sh
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        rm -rf \(quoted(old))
        mv \(quoted(destination)) \(quoted(old)) || exit 1
        if /usr/bin/ditto \(quoted(newApp)) \(quoted(destination)); then
            rm -rf \(quoted(old)) \(quoted(newApp))
        else
            rm -rf \(quoted(destination)); mv \(quoted(old)) \(quoted(destination))
        fi
        /usr/bin/xattr -cr \(quoted(destination)) 2>/dev/null
        \(own)\(reopen)
        """
    }

    // MARK: Contrôles

    static func sha256(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func shaMatches(_ url: URL, text: String) -> Bool {
        guard let m = text.range(of: #"^\s*[0-9a-fA-F]{64}"#, options: .regularExpression) else { return false }
        return text[m].trimmingCharacters(in: .whitespaces).lowercased() == sha256(of: url)
    }

    /// Identifiants de paquet acceptés : celui de l'appli, plus celui de la clé de build de l'édition de test.
    static func acceptedIDs(_ info: [String: Any]) -> Set<String> {
        var ids = Set([info["CFBundleIdentifier"] as? String ?? ""])
        if let extra = info[acceptKey] as? String { ids.insert(extra) }
        ids.remove("")
        return ids
    }

    nonisolated static func run(_ path: String, _ args: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return (-1, "") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    static func requirement(of app: String) -> String? {
        let r = run("/usr/bin/codesign", ["-d", "-r-", app])
        return r.status == 0 ? r.output.split(separator: "\n").first { $0.hasPrefix("designated =>") }.map(String.init) : nil
    }

    static func teamID(of app: String) -> String? {
        let r = run("/usr/bin/codesign", ["-dv", app])
        guard r.status == 0 else { return nil }
        return r.output.split(separator: "\n").first { $0.hasPrefix("TeamIdentifier=") }.map { String($0.dropFirst("TeamIdentifier=".count)) }
    }

    /// Contrôle l'archive, la décompresse et la contrôle : renvoie le .app prêt à installer, ou nil.
    static func prepare(zip: URL, shaText: String, version: String, currentApp: URL, checkNotarization: Bool = true) -> URL? {
        guard shaMatches(zip, text: shaText) else { return nil }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("skyrim-update-\(UUID().uuidString)")
        func fail() -> URL? { try? FileManager.default.removeItem(at: dir); return nil }
        do { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) } catch { return nil }
        guard run("/usr/bin/ditto", ["-x", "-k", zip.path, dir.path]).status == 0,
              let apps = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter({ $0.pathExtension == "app" }),
              apps.count == 1, let app = apps.first else { return fail() }
        let cur = NSDictionary(contentsOf: currentApp.appendingPathComponent("Contents/Info.plist")) as? [String: Any] ?? [:]
        guard let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")) as? [String: Any],
              let id = info["CFBundleIdentifier"] as? String, acceptedIDs(cur).contains(id),
              let v = info["CFBundleShortVersionString"] as? String, let got = AppVersion(v), got == AppVersion(version),
              run("/usr/bin/codesign", ["--verify", "--strict", "--deep", app.path]).status == 0,
              teamID(of: app.path) == teamID else { return fail() }
        // appli officielle (Developer ID) : même exigence de signature que l'appli en cours ; une copie signée localement
        // ou l'édition de test n'a pas cette exigence : seul le Team ID du paquet reçu compte alors.
        if cur[acceptKey] == nil, teamID(of: currentApp.path) == teamID {
            guard let want = requirement(of: currentApp.path), requirement(of: app.path) == want else { return fail() }
        }
        if checkNotarization, run("/usr/bin/xcrun", ["stapler", "validate", app.path]).status != 0 { return fail() }
        return app
    }

    // MARK: Textes (mêmes clés dans les 4 langues)

    static let texts: [String: [String: String]] = [
        "fr": [
            "menu": "Rechercher les mises à jour…", "title": "Nouvelle version",
            "body": "%@ %@ est disponible (vous avez la %@).", "notes": "Nouveautés depuis la %@",
            "no_notes": "Aucune note de version pour cette mise à jour.",
            "install": "Installer et relancer", "later": "Plus tard", "skip": "Ignorer cette version",
            "downloading": "Téléchargement…", "verifying": "Vérification du paquet…", "installing": "Installation, l'appli va se relancer…",
            "uptodate_title": "À jour", "uptodate": "%@ %@ est la dernière version.",
            "err_net": "Impossible de joindre GitHub. Réessayez plus tard.",
            "err_verify": "Le paquet téléchargé n'a pas passé les contrôles de sécurité. Rien n'a été installé.",
            "err_install": "L'installation a échoué. L'ancienne version est conservée.",
            "err_busy": "Une opération est en cours. Réessayez après.",
            "err_denied": "Droits refusés. Vous pouvez télécharger la mise à jour à la main.",
            "open_page": "Ouvrir la page de téléchargement", "close": "Fermer",
        ],
        "en": [
            "menu": "Check for Updates…", "title": "New version",
            "body": "%@ %@ is available (you have %@).", "notes": "What's new since %@",
            "no_notes": "No release notes for this update.",
            "install": "Install and relaunch", "later": "Later", "skip": "Skip this version",
            "downloading": "Downloading…", "verifying": "Verifying the package…", "installing": "Installing, the app will relaunch…",
            "uptodate_title": "Up to date", "uptodate": "%@ %@ is the latest version.",
            "err_net": "Could not reach GitHub. Try again later.",
            "err_verify": "The downloaded package failed the security checks. Nothing was installed.",
            "err_install": "The installation failed. The previous version is kept.",
            "err_busy": "An operation is running. Try again afterwards.",
            "err_denied": "Permission denied. You can download the update by hand.",
            "open_page": "Open the download page", "close": "Close",
        ],
        "es": [
            "menu": "Buscar actualizaciones…", "title": "Nueva versión",
            "body": "%@ %@ está disponible (tienes la %@).", "notes": "Novedades desde la %@",
            "no_notes": "No hay notas de versión para esta actualización.",
            "install": "Instalar y reiniciar", "later": "Más tarde", "skip": "Omitir esta versión",
            "downloading": "Descargando…", "verifying": "Verificando el paquete…", "installing": "Instalando, la app se reiniciará…",
            "uptodate_title": "Al día", "uptodate": "%@ %@ es la última versión.",
            "err_net": "No se puede contactar con GitHub. Inténtalo más tarde.",
            "err_verify": "El paquete descargado no superó los controles de seguridad. No se instaló nada.",
            "err_install": "La instalación falló. Se conserva la versión anterior.",
            "err_busy": "Hay una operación en curso. Inténtalo después.",
            "err_denied": "Permiso denegado. Puedes descargar la actualización a mano.",
            "open_page": "Abrir la página de descarga", "close": "Cerrar",
        ],
        "it": [
            "menu": "Verifica aggiornamenti…", "title": "Nuova versione",
            "body": "%@ %@ è disponibile (hai la %@).", "notes": "Novità dalla %@",
            "no_notes": "Nessuna nota di versione per questo aggiornamento.",
            "install": "Installa e riavvia", "later": "Più tardi", "skip": "Ignora questa versione",
            "downloading": "Download in corso…", "verifying": "Verifica del pacchetto…", "installing": "Installazione, l'app si riavvierà…",
            "uptodate_title": "Aggiornata", "uptodate": "%@ %@ è l'ultima versione.",
            "err_net": "Impossibile raggiungere GitHub. Riprova più tardi.",
            "err_verify": "Il pacchetto scaricato non ha superato i controlli di sicurezza. Non è stato installato nulla.",
            "err_install": "L'installazione non è riuscita. La versione precedente è conservata.",
            "err_busy": "Un'operazione è in corso. Riprova dopo.",
            "err_denied": "Permesso negato. Puoi scaricare l'aggiornamento a mano.",
            "open_page": "Apri la pagina di download", "close": "Chiudi",
        ],
    ]

    static func text(_ key: String, lang: String, _ args: CVarArg...) -> String {
        let table = texts[normalizeLang(lang)] ?? texts["en"]!
        let format = table[key] ?? texts["en"]![key] ?? key
        return args.isEmpty ? format : String(format: format, arguments: args)
    }
}

// MARK: - Moteur (état observable, réseau, installation)

@MainActor
final class UpdateEngine: ObservableObject {
    enum State: Equatable {
        case idle, checking, upToDate
        case available(UpdatePlan)
        case downloading(Double)
        case verifying
        case installing
        case failed(String)   // clé de texte (err_*)
    }

    static let shared = UpdateEngine()

    @Published private(set) var state = State.idle
    /// Mise à jour en cours de proposition ou d'installation (pour les écrans de réglages de l'appli).
    @Published private(set) var plan: UpdatePlan?
    private(set) var repo = ""
    private(set) var lang: () -> String = { Locale.preferredLanguages.first ?? "en" }
    private(set) var brandName: String?
    /// Vérification automatique active (réglage de l'appli, s'il y en a un).
    var autoCheck: () -> Bool = { true }
    /// Appli occupée (nettoyage en cours…) : l'installation attend.
    var canInstall: () -> Bool = { true }

    let info = Bundle.main.infoDictionary ?? [:]
    var currentVersion: String { info["CFBundleShortVersionString"] as? String ?? "" }
    var appName: String { info["CFBundleName"] as? String ?? repo }
    var currentLang: String { Updater.normalizeLang(lang()) }
    var page: URL { URL(string: "https://github.com/\(Updater.owner)/\(repo)/releases/latest")! }

    private var timer: Timer?
    private var token: String??
    private var useToken = false
    private var pendingAuto: UpdatePlan?
    private var activeObserver: NSObjectProtocol?
    private var menuObserver: NSObjectProtocol?
    private var window: UpdateWindowController?
    private let defaults = UserDefaults.standard
    private static let day: TimeInterval = 24 * 3600

    var isBusy: Bool {
        switch state {
        case .checking, .downloading, .verifying, .installing: true
        default: false
        }
    }

    func configure(repo: String, lang: @escaping () -> String, brandName: String? = nil) {
        self.repo = repo
        self.lang = lang
        self.brandName = brandName
    }

    /// Au lancement puis toutes les heures : une vraie requête au plus une fois par jour. N'ouvre aucune fenêtre
    /// tant que l'appli n'est pas au premier plan (mode silencieux).
    func start() {
        guard Bundle.main.bundleURL.pathExtension == "app", !currentVersion.isEmpty,
              ProcessInfo.processInfo.environment["SKYRIM_TOOLS_NO_UPDATE_CHECK"] == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        }
        timer?.tolerance = 60
        checkIfDue()
    }

    private func checkIfDue() {
        guard autoCheck() else { return }
        let last = defaults.double(forKey: "updater.checked")
        if last == 0 || Date().timeIntervalSince1970 - last >= Self.day { check(manual: false) }
    }

    /// Menu « Rechercher les mises à jour… » : ignore le délai d'un jour et la version ignorée, répond toujours.
    func checkNow() { check(manual: true) }

    func check(manual: Bool = false) {
        guard !isBusy, !currentVersion.isEmpty else { return }
        if case .available(let plan) = state, manual { present(plan); return }
        state = .checking
        Task {
            guard let releases = await fetchReleases() else {
                state = manual ? .failed("err_net") : .idle
                if manual { presentMessage(Updater.text("title", lang: currentLang), Updater.text("err_net", lang: currentLang)) }
                return
            }
            defaults.set(Date().timeIntervalSince1970, forKey: "updater.checked")
            let newer = Updater.newer(releases, than: currentVersion)
            guard let target = newer.first else {
                state = .upToDate
                if manual { presentMessage(Updater.text("uptodate_title", lang: currentLang), Updater.text("uptodate", lang: currentLang, appName, currentVersion)) }
                return
            }
            let plan = UpdatePlan(current: currentVersion, target: target, releases: newer)
            self.plan = plan
            state = .available(plan)
            if manual { present(plan) } else if defaults.string(forKey: "updater.skipped") != target.version { presentWhenActive(plan) }
        }
    }

    // MARK: Fenêtres

    private func presentWhenActive(_ plan: UpdatePlan) {
        if NSApp.isActive { present(plan); return }
        pendingAuto = plan
        guard activeObserver == nil else { return }
        activeObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let plan = self.pendingAuto else { return }
                self.pendingAuto = nil
                if let o = self.activeObserver { NotificationCenter.default.removeObserver(o); self.activeObserver = nil }
                self.present(plan)
            }
        }
    }

    func present(_ plan: UpdatePlan) {
        if window == nil { window = UpdateWindowController(engine: self) }
        window?.show(plan: plan)
    }

    private func presentMessage(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }

    /// Texte d'un état d'échec (clé err_*), dans la langue de l'appli.
    func message(for key: String) -> String { Updater.text(key, lang: currentLang) }

    func skip(_ plan: UpdatePlan) {
        defaults.set(plan.target.version, forKey: "updater.skipped")
    }

    func openPage() { NSWorkspace.shared.open(page) }

    /// Ajoute « Rechercher les mises à jour… » au menu de l'appli (sous « À propos »), si l'appli a une barre de menus.
    /// SwiftUI reconstruit parfois la barre après le lancement : l'ajout est refait au besoin (au démarrage, puis à chaque activation).
    func installAppMenuItem() {
        insertMenuItem()
        for i in 1...30 { DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 2) { MainActor.assumeIsolated { self.insertMenuItem() } } }
        guard menuObserver == nil else { return }
        menuObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.insertMenuItem() }
        }
    }

    func insertMenuItem() {
        guard let menu = NSApp.mainMenu?.items.first?.submenu,
              !menu.items.contains(where: { $0.representedObject as? String == "updater" }) else { return }
        let item = NSMenuItem(title: Updater.text("menu", lang: currentLang), action: #selector(UpdateMenuTarget.fire), keyEquivalent: "")
        item.target = UpdateMenuTarget.shared
        item.representedObject = "updater"
        let at = menu.items.firstIndex { $0.isSeparatorItem } ?? 1
        menu.insertItem(item, at: min(at, menu.items.count))
    }

    // MARK: Réseau

    /// Jeton GitHub de l'utilisateur (via `gh`), seulement si le dépôt n'est pas lisible sans (dépôt privé).
    private func githubToken() async -> String? {
        if let token { return token }
        let value: String? = await Task.detached {
            for path in ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"] where FileManager.default.isExecutableFile(atPath: path) {
                let r = Updater.run(path, ["auth", "token"])
                let text = r.output.trimmingCharacters(in: .whitespacesAndNewlines)
                if r.status == 0, !text.isEmpty { return text }
            }
            return nil
        }.value
        token = .some(value)
        return value
    }

    private func request(_ url: URL, accept: String, timeout: TimeInterval = 20) async -> URLRequest? {
        guard url.scheme == "https", Updater.hostAllowed(url.host) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.setValue(accept, forHTTPHeaderField: "Accept")
        req.setValue("skyrim-tools-updater", forHTTPHeaderField: "User-Agent")
        if useToken, let t = await githubToken() { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        return req
    }

    /// Refuse toute redirection hors de GitHub et n'envoie pas le jeton au stockage de fichiers.
    private final class Redirects: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            guard request.url?.scheme == "https", Updater.hostAllowed(request.url?.host) else { completionHandler(nil); return }
            var next = request
            if request.url?.host != Updater.apiHost { next.setValue(nil, forHTTPHeaderField: "Authorization") }
            completionHandler(next)
        }
    }

    /// nil si GitHub est injoignable. 404 : aucune release, ou dépôt privé (alors `gh` donne un jeton).
    private func fetchReleases() async -> [UpdateRelease]? {
        guard let url = URL(string: "https://\(Updater.apiHost)/repos/\(Updater.owner)/\(repo)/releases?per_page=30") else { return nil }
        useToken = false
        let session = URLSession(configuration: .ephemeral, delegate: Redirects(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        for attempt in 0...1 {
            guard let req = await request(url, accept: "application/vnd.github+json"),
                  let (data, response) = try? await session.data(for: req),
                  let status = (response as? HTTPURLResponse)?.statusCode else { return nil }
            if status == 404, attempt == 0, await githubToken() != nil { useToken = true; continue }
            if status == 404 { return [] }
            return status == 200 ? Updater.parseReleases(data) : nil
        }
        return nil
    }

    /// Téléchargement avec progression ; mêmes règles de redirection que `Redirects`.
    private final class Downloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
        let progress: @Sendable (Double) -> Void
        var continuation: CheckedContinuation<URL?, Never>?
        private var finished = false
        init(progress: @escaping @Sendable (Double) -> Void) { self.progress = progress }

        private func finish(_ url: URL?) {
            guard !finished else { return }
            finished = true
            continuation?.resume(returning: url)
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            guard request.url?.scheme == "https", Updater.hostAllowed(request.url?.host) else { completionHandler(nil); return }
            var next = request
            if request.url?.host != Updater.apiHost { next.setValue(nil, forHTTPHeaderField: "Authorization") }
            completionHandler(next)
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            if totalBytesExpectedToWrite > 0 { progress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) }
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            guard (downloadTask.response as? HTTPURLResponse)?.statusCode == 200 else { finish(nil); return }
            let kept = FileManager.default.temporaryDirectory.appendingPathComponent("skyrim-dl-\(UUID().uuidString).zip")
            do { try FileManager.default.moveItem(at: location, to: kept); finish(kept) } catch { finish(nil) }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if error != nil { finish(nil) }
        }
    }

    private func download(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async -> URL? {
        guard let req = await request(url, accept: "application/octet-stream", timeout: 60) else { return nil }
        let delegate = Downloader(progress: progress)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        return await withCheckedContinuation { (c: CheckedContinuation<URL?, Never>) in
            delegate.continuation = c
            session.downloadTask(with: req).resume()
        }
    }

    private func downloadText(_ url: URL) async -> String? {
        guard let req = await request(url, accept: "application/octet-stream") else { return nil }
        let session = URLSession(configuration: .ephemeral, delegate: Redirects(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, response) = try? await session.data(for: req), (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return String(decoding: data.prefix(4096), as: UTF8.self)
    }

    // MARK: Installation

    func install(_ plan: UpdatePlan) {
        guard !isBusy else { return }
        guard canInstall() else { state = .failed("err_busy"); return }
        state = .downloading(0)
        Task {
            guard let zip = await download(plan.target.zipURL, progress: { p in
                Task { @MainActor in UpdateEngine.shared.setProgress(p) }
            }), let sha = await downloadText(plan.target.shaURL) else { state = .failed("err_net"); return }
            state = .verifying
            let current = Bundle.main.bundleURL
            let staged = await Task.detached { Updater.prepare(zip: zip, shaText: sha, version: plan.target.version, currentApp: current) }.value
            try? FileManager.default.removeItem(at: zip)
            guard let staged else { state = .failed("err_verify"); return }
            switch launchInstaller(staged) {
            case .ok:
                state = .installing
                try? await Task.sleep(nanoseconds: 400_000_000)
                NSApp.terminate(nil)
            case .denied: state = .failed("err_denied")
            case .failed: state = .failed("err_install")
            }
        }
    }

    fileprivate func setProgress(_ p: Double) {
        if case .downloading = state { state = .downloading(p) }
    }

    private enum Launch { case ok, denied, failed }

    private func launchInstaller(_ newApp: URL) -> Launch {
        let destination = Bundle.main.bundleURL
        let fm = FileManager.default
        let writable = fm.isWritableFile(atPath: destination.deletingLastPathComponent().path) && fm.isWritableFile(atPath: destination.path)
        let quiet = ProcessInfo.processInfo.environment["SKYRIM_TOOLS_UPDATE_QUIET"] != nil
        let chown = writable ? nil : "\(getuid()):\(getgid())"
        let script = fm.temporaryDirectory.appendingPathComponent("skyrim-install-\(UUID().uuidString).sh")
        let text = Updater.installScript(pid: ProcessInfo.processInfo.processIdentifier, newApp: newApp.path, destination: destination.path,
                                         relaunch: true, quiet: quiet, chown: chown)
        do { try text.write(to: script, atomically: true, encoding: .utf8) } catch { return .failed }
        let process = Process()
        if writable {
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = [script.path]
        } else {
            // dossier protégé : droits demandés par la fenêtre système ; le script tourne en arrière-plan jusqu'à la fin de l'appli
            let command = "/bin/sh '\(script.path)' >/dev/null 2>&1 &"
            let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", "do shell script \"\(escaped)\" with administrator privileges"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do { try process.run() } catch { return .failed }
            process.waitUntilExit()
            return process.terminationStatus == 0 ? .ok : .denied
        }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return .failed }
        return .ok
    }
}

/// Cible de l'élément de menu (NSMenuItem a besoin d'un objet Objective-C).
final class UpdateMenuTarget: NSObject {
    static let shared = UpdateMenuTarget()
    @MainActor @objc func fire() { UpdateEngine.shared.checkNow() }
}
