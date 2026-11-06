// Interface : ouvrir une archive (bouton ou glisser-déposer), tableau des fichiers, progression, extraction.

import AppKit
import BAECore
import SwiftUI
import UniformTypeIdentifiers

let WINDOW_SIZE = CGSize(width: 880, height: 580)

struct ContentView: View {
    @Bindable var model: AppModel
    @State private var order = [KeyPathComparator(\Row.id)]

    var body: some View {
        let _ = model.tick
        VStack(spacing: Socle.M.space3) {
            top
            table
            ProgressView(value: Double(model.progress), total: 100)
                .progressViewStyle(.linear).tint(Socle.C.accent)
            bottom
        }
        .padding(Socle.M.space3)
        .frame(minWidth: 640, minHeight: 420)
        .background(Socle.C.bg)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            Task {
                for p in providers {
                    if let item = try? await p.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
                       let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil), model.isArchivePath(url.path) {
                        model.load(url.path)
                        return
                    }
                }
            }
            return true
        }
    }

    private var top: some View {
        HStack(spacing: Socle.M.space2) {
            Button("📦 " + L("Ouvrir une archive (.bsa / .ba2)")) { chooseFile() }
                .buttonStyle(SocleButtonStyle(.primary)).fixedSize().disabled(model.busy)
            Text(model.infoText)
                .socle(Socle.T.body).foregroundStyle(Socle.C.textMuted)
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }

    private var table: some View {
        Table(sortedRows, sortOrder: $order) {
            TableColumn(L("Chemin du fichier"), value: \.name) { Text($0.name).socle(Socle.T.body).lineLimit(1) }
            TableColumn(L("Taille brute"), value: \.size) { Text($0.sizeText).socle(Socle.T.body) }.width(100)
            TableColumn(L("Type d'archive"), value: \.typeKey) { Text(model.typeLabel($0.compressed)).socle(Socle.T.body) }.width(110)
        }
        .scrollContentBackground(.hidden)
        .background(Socle.C.surface, in: RoundedRectangle(cornerRadius: Socle.M.radiusMd))
        .overlay(RoundedRectangle(cornerRadius: Socle.M.radiusMd).stroke(Socle.C.border, lineWidth: 1))
    }

    private var sortedRows: [Row] { model.rows.sorted(using: order) }

    private var bottom: some View {
        HStack(spacing: Socle.M.space2) {
            Text(model.status)
                .socle(Socle.T.body).foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Button(L("EXTRAIRE TOUT")) { chooseDestination() }
                .buttonStyle(SocleButtonStyle(.primary)).fixedSize()
                .disabled(model.archive == nil || model.busy)
        }
    }

    private var color: Color {
        switch model.tone {
        case .none: Socle.C.textMuted
        case .success: Socle.C.success
        case .danger: Socle.C.danger
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.title = L("Sélectionner une archive Bethesda")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = L("Archives Bethesda") + " (*.bsa *.ba2)"
        panel.allowedContentTypes = ["bsa", "ba2"].compactMap { UTType(filenameExtension: $0) }
        panel.allowsOtherFileTypes = true
        if panel.runModal() == .OK, let url = panel.url { model.load(url.path) }
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.title = L("Choisir le dossier de destination")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { model.extract(to: url.path) }
    }
}

extension Row {
    var typeKey: String { compressed ? "1" : "0" }
}
