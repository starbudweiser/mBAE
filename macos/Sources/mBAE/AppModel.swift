// État de l'appli : archive ouverte, lignes du tableau, état, extraction en arrière-plan avec progression.

import AppKit
import BAECore
import Observation
import SwiftUI

enum StatusTone { case none, success, danger }

struct Row: Identifiable {
    let id: Int
    let name: String
    let size: Int
    let compressed: Bool
    var sizeText: String { fmtKB(size) }
}

final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return flag }
    func set() { lock.lock(); flag = true; lock.unlock() }
}

@MainActor @Observable
final class AppModel {
    var archive: BethesdaArchive?
    var rows: [Row] = []
    var statusKey = N_("En attente")
    var statusParams: [String: Any] = [:]
    var tone: StatusTone = .none
    var progress = 0
    var busy = false
    var tick = 0  // change à chaque retraduction

    private var cancel = CancelFlag()
    private let done = DispatchSemaphore(value: 0)
    private var running = false
    private var closing = false

    var status: String { L(statusKey, statusParams) }

    func setStatus(_ key: String, _ params: [String: Any] = [:], tone: StatusTone = .none) {
        statusKey = key; statusParams = params; self.tone = tone
    }

    var infoText: String {
        guard let a = archive else { return L("Glisse-dépose une archive n'importe où ici.") }
        return L("{name} — {type} ({n} fichiers)", ["name": a.url.lastPathComponent, "type": a.typeLabel, "n": a.files.count])
    }

    func typeLabel(_ compressed: Bool) -> String {
        "\(archive?.typeLabel ?? "") " + (compressed ? L("(Comp)") : L("(Brut)"))
    }

    // MARK: Ouverture

    func isArchivePath(_ p: String) -> Bool { let l = p.lowercased(); return l.hasSuffix(".bsa") || l.hasSuffix(".ba2") }

    func load(_ path: String) {
        guard !busy else { return }
        do {
            let a = try BethesdaArchive(path: path)
            archive = a
            rows = a.files.prefix(2500).enumerated().map { Row(id: $0.offset, name: $0.element.name, size: $0.element.size, compressed: $0.element.compressed) }
            setStatus(N_("Prêt pour l'extraction."))
            progress = 0
        } catch {
            setStatus(N_("Erreur : {err}"), ["err": error.localizedDescription], tone: .danger)
        }
    }

    // MARK: Extraction

    func extract(to dest: String) {
        guard let a = archive, !busy else { return }
        busy = true
        progress = 0
        tone = .none
        let flag = CancelFlag()
        cancel = flag
        running = true
        let sem = done
        Thread.detachNewThread { [weak self] in
            let outcome: Result<ExtractResult, Error>
            do {
                outcome = .success(try a.extractAll(to: dest, progress: { p in
                    DispatchQueue.main.async { MainActor.assumeIsolated { self?.progress = p } }
                }, isCancelled: { flag.isSet }))
            } catch { outcome = .failure(error) }
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.finished(outcome) } }
            sem.signal()
        }
    }

    private func finished(_ outcome: Result<ExtractResult, Error>) {
        running = false
        if closing { return }
        busy = false
        switch outcome {
        case .success(let r):
            if r.total == 0 { setStatus(N_("Archive vide.")) }
            else if r.skipped > 0 { setStatus(N_("Extraction terminée : {n} fichiers extraits ({skipped} ignorés : chemin non sûr)."), ["n": r.extracted, "skipped": r.skipped], tone: .success) }
            else { setStatus(N_("Extraction terminée : {n} fichiers extraits."), ["n": r.total], tone: .success) }
        case .failure(let e):
            setStatus(N_("Erreur : {err}"), ["err": e.localizedDescription], tone: .danger)
        }
    }

    /// Fermeture : arrêt propre de l'extraction en cours, puis attente.
    @discardableResult
    func stopAndWait() -> Bool {
        guard running else { return false }
        closing = true
        cancel.set()
        done.wait()
        running = false
        return true
    }

    func retranslate() { tick += 1 }
}
