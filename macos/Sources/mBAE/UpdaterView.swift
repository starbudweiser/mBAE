// Fenêtre de mise à jour (design Socle) : « vous avez X, Y est disponible », notes cumulées dans la langue de l'appli,
// « Installer et relancer » / « Plus tard » / « Ignorer cette version », progression. Voir Updater.swift (même dossier).
// Dépend de Socle.swift de l'appli (Socle.C, Socle.M, Socle.T, SocleButtonStyle, Text(branded:)).
import AppKit
import SwiftUI

@MainActor
final class UpdateWindowController: NSObject, NSWindowDelegate {
    private let engine: UpdateEngine
    private var window: NSWindow?

    init(engine: UpdateEngine) { self.engine = engine }

    func show(plan: UpdatePlan) {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 580), styleMask: [.titled, .closable],
                             backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            w.delegate = self
            window = w
        }
        guard let window else { return }
        window.title = Updater.text("title", lang: engine.currentLang)
        window.contentView = NSHostingView(rootView: UpdateView(engine: engine, plan: plan, close: { [weak self] in self?.window?.close() }))
        window.socleCenter()
        NSApp.activate()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }
}

/// Mini rendu Markdown des notes : titres « ## X.Y.Z », puces « - », gras et code en ligne.
struct UpdateNotes: View {
    let markdown: String

    private enum Line: Hashable { case heading(String), bullet(String), paragraph(String) }

    private var lines: [Line] {
        markdown.split(separator: "\n", omittingEmptySubsequences: true).map { raw in
            let s = String(raw)
            if s.hasPrefix("## ") { return .heading(String(s.dropFirst(3))) }
            if s.hasPrefix("- ") { return .bullet(String(s.dropFirst(2))) }
            return .paragraph(s)
        }
    }

    private func inline(_ s: String) -> Text {
        let opts = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return Text(Socle.branded((try? AttributedString(markdown: s, options: opts)) ?? AttributedString(s)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Socle.M.space1_5) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                switch line {
                case .heading(let t):
                    Text(t).socle(Socle.T.title).foregroundStyle(Socle.C.textStrong).padding(.top, Socle.M.space2)
                case .bullet(let t):
                    HStack(alignment: .firstTextBaseline, spacing: Socle.M.space2) {
                        Text("•").socle(Socle.T.body).foregroundStyle(Socle.C.textMuted)
                        inline(t).socle(Socle.T.body).foregroundStyle(Socle.C.text).fixedSize(horizontal: false, vertical: true)
                    }
                case .paragraph(let t):
                    inline(t).socle(Socle.T.body).foregroundStyle(Socle.C.text).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct UpdateView: View {
    @ObservedObject var engine: UpdateEngine
    let plan: UpdatePlan
    let close: () -> Void

    private var lang: String { engine.currentLang }
    private func t(_ key: String, _ args: CVarArg...) -> String {
        args.isEmpty ? Updater.text(key, lang: lang) : Updater.text(key, lang: lang, args[0], args.count > 1 ? args[1] : "", args.count > 2 ? args[2] : "")
    }

    private var notes: String {
        let md = Updater.buildNotes(plan.releases, lang: lang)
        return md.isEmpty ? t("no_notes") : md
    }

    private var working: Bool {
        switch engine.state {
        case .downloading, .verifying, .installing: true
        default: false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Socle.M.space3) {
            Text(t("title")).socle(Socle.T.heading).foregroundStyle(Socle.C.textStrong)
            Text(branded: t("body", engine.appName, plan.target.version, plan.current))
                .socle(Socle.T.bodyLg).foregroundStyle(Socle.C.text)
            Text(t("notes", plan.current).uppercased()).socle(Socle.T.eyebrow).foregroundStyle(Socle.C.textMuted)
            ScrollView {
                UpdateNotes(markdown: notes).padding(Socle.M.space3)
            }
            .background(Socle.C.bgSunken)
            .overlay(Rectangle().stroke(Socle.C.border, lineWidth: 1))
            statusArea
            HStack(spacing: Socle.M.space2) {
                Button(t("skip")) { engine.skip(plan); close() }
                    .buttonStyle(SocleButtonStyle(.tertiary)).frame(width: 170).disabled(working)
                Spacer()
                if case .failed = engine.state {
                    Button(t("open_page")) { engine.openPage(); close() }.buttonStyle(SocleButtonStyle(.secondary)).frame(width: 200)
                }
                Button(failed ? t("close") : t("later")) { close() }
                    .buttonStyle(SocleButtonStyle(.secondary)).frame(width: 110).disabled(working)
                if !failed {
                    Button(t("install")) { engine.install(plan) }
                        .buttonStyle(SocleButtonStyle(.primary)).frame(width: 190).disabled(working)
                }
            }
        }
        .padding(Socle.M.space6)
        .frame(width: 540, height: 580)
        .background(Socle.C.surface)
    }

    private var failed: Bool {
        if case .failed = engine.state { return true }
        return false
    }

    @ViewBuilder private var statusArea: some View {
        switch engine.state {
        case .downloading(let p):
            VStack(alignment: .leading, spacing: Socle.M.space1_5) {
                ProgressView(value: p).tint(Socle.C.accent)
                Text(t("downloading")).socle(Socle.T.meta).foregroundStyle(Socle.C.textMuted)
            }
        case .verifying:
            VStack(alignment: .leading, spacing: Socle.M.space1_5) {
                ProgressView().progressViewStyle(.linear).tint(Socle.C.accent)
                Text(t("verifying")).socle(Socle.T.meta).foregroundStyle(Socle.C.textMuted)
            }
        case .installing:
            VStack(alignment: .leading, spacing: Socle.M.space1_5) {
                ProgressView().progressViewStyle(.linear).tint(Socle.C.accent)
                Text(t("installing")).socle(Socle.T.meta).foregroundStyle(Socle.C.textMuted)
            }
        case .failed(let key):
            Text(t(key)).socle(Socle.T.body).foregroundStyle(Socle.C.danger).fixedSize(horizontal: false, vertical: true)
        default:
            EmptyView()
        }
    }
}
