// Point d'entrée : fenêtre AppKit unique (880 × 580, redimensionnable) qui héberge l'interface SwiftUI.

import AppKit
import BAECore
import SwiftUI

func windowTitle() -> String { L("mBAE – Extracteur d'archives Bethesda") }

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    let model = AppModel()
    var config = Config.load()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Socle.apply()
        // « m » dans le bleu du logo
        Socle.brand("mBAE", color: Color(red: 0x21 / 255, green: 0xa3 / 255, blue: 0xd9 / 255))
        buildMenu()

        let host = NSHostingView(rootView: ContentView(model: model))
        window = NSWindow(contentRect: NSRect(origin: .zero, size: WINDOW_SIZE),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = windowTitle()
        window.contentView = host
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.backgroundColor = NSColor(Socle.C.bg)
        window.contentMinSize = NSSize(width: 640, height: 420)
        window.setContentSize(WINDOW_SIZE)
        window.socleCenter()
        // Essais en arrière-plan : MBAE_QUIET=1 lance l'appli sans prendre le focus
        let env = ProcessInfo.processInfo.environment
        if env["MBAE_QUIET"] != nil {
            window.orderBack(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
        }
        UpdateEngine.shared.configure(repo: "mBAE", lang: { I18n.lang })
        UpdateEngine.shared.canInstall = { [weak self] in !(self?.model.busy ?? false) }
        UpdateEngine.shared.start()  // nouvelle version ? (au plus une fois par jour)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { UpdateEngine.shared.installAppMenuItem() }

        // Essais : MBAE_ARCHIVE=<archive> l'ouvre (lecture seule) ; MBAE_EXTRACT=<dossier> l'extrait ensuite sans dialogue.
        if let a = env["MBAE_ARCHIVE"] {
            model.load(a)
            if let out = env["MBAE_EXTRACT"] { model.extract(to: out) }
        }
        // Vérification visuelle (développement) : MBAE_SNAPSHOT=<fichier.png> enregistre la fenêtre après MBAE_DELAY s (2 par défaut) et quitte.
        if let out = env["MBAE_SNAPSHOT"] {
            let delay = Double(env["MBAE_DELAY"] ?? "") ?? 2
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
                let view = window.contentView!
                if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
                }
                NSApp.terminate(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Fermer la fenêtre pendant une extraction : arrêt propre, puis fermeture.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if model.stopAndWait() { DispatchQueue.main.async { NSApp.terminate(nil) } }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model.stopAndWait()
        return .terminateNow
    }

    // MARK: Langue

    @objc func chooseLanguage(_ sender: NSMenuItem) {
        let choice = Config.normalize(sender.representedObject as? String)
        config["language"] = choice
        Config.save(config)
        I18n.setLang(Config.resolve(choice))
        window.title = windowTitle()
        model.retranslate()
        buildMenu()
        UpdateEngine.shared.insertMenuItem()
    }

    @objc func showAbout(_ sender: Any?) { About.show() }

    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        // Pas de couleur dans les menus : le nom de l'appli y est en texte normal
        let about = appMenu.addItem(withTitle: L("À propos de mBAE"), action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Masquer mBAE"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = appMenu.addItem(withTitle: L("Masquer les autres"),
                                     action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: L("Tout afficher"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Quitter mBAE"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: L("Édition"))
        editMenu.addItem(withTitle: L("Copier"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L("Tout sélectionner"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        // Menu « Langue » : Automatique + 4 langues, coche sur le choix courant
        let langItem = NSMenuItem()
        let langMenu = NSMenu(title: L("Langue"))
        let current = Config.choice(config)
        func add(_ title: String, _ code: String) {
            let item = langMenu.addItem(withTitle: title, action: #selector(chooseLanguage), keyEquivalent: "")
            item.target = self
            item.representedObject = code
            item.state = code == current ? .on : .off
        }
        add(L("Automatique (système)"), Config.auto)
        langMenu.addItem(.separator())
        for (code, label) in Config.menuLangs { add(label, code) }
        langItem.submenu = langMenu
        main.addItem(langItem)

        let winItem = NSMenuItem()
        let winMenu = NSMenu(title: L("Fenêtre"))
        winMenu.addItem(withTitle: L("Réduire"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        winItem.submenu = winMenu
        main.addItem(winItem)
        NSApp.mainMenu = main
        NSApp.windowsMenu = winMenu
    }
}

I18n.setLang(Config.resolve(Config.choice(Config.load())))

// Mode ligne de commande (essais, sans fenêtre), l'archive n'est jamais modifiée :
//   mBAE --list <archive>              → « taille<TAB>C|R<TAB>nom » par fichier
//   mBAE --extract <archive> <dossier> → extrait tout vers <dossier>, écrit « OK<TAB>total<TAB>ignorés »
let cliArgs = CommandLine.arguments
if cliArgs.count >= 3, cliArgs[1] == "--list" || cliArgs[1] == "--extract" {
    do {
        let a = try BethesdaArchive(path: cliArgs[2])
        if cliArgs[1] == "--list" {
            print("\(a.typeLabel)\t\(a.version)\t\(a.files.count)")
            for f in a.files { print("\(f.size)\t\(f.compressed ? "C" : "R")\t\(f.name)") }
        } else {
            guard cliArgs.count == 4 else { FileHandle.standardError.write(Data("usage: --extract <archive> <dossier>\n".utf8)); exit(2) }
            let r = try a.extractAll(to: cliArgs[3])
            print("OK\t\(r.total)\t\(r.skipped)")
        }
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("ERREUR\t\(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
