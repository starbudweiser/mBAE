// Socle pour SwiftUI — thème commun de mes applications.
//
// FICHIER GÉNÉRÉ par Socle/swift/build_socle_swift.py à partir de Socle/tokens.json.
// Ne pas le modifier à la main : modifier tokens.json ou Socle_template.swift, puis régénérer.
//
// Utilisation :
//     Socle.apply()                                   // thème sombre par défaut (comme les applis Qt)
//     Text("Titre").socle(.heading)                   // style typographique (× Socle.scale)
//     .foregroundStyle(Socle.C.textStrong)            // couleurs : Socle.C.*, mesures : Socle.M.*
//     Button("FUSIONNER") {}.buttonStyle(SocleButtonStyle(.primary))
//     Socle.brand("nEXUSWATCH", color: …); Text(branded: s)  // minuscule du nom dans la couleur du logo

import AppKit
import SwiftUI

enum Socle {
    static let version = 1

    /// Échelle typographique fixe des applis desktop (tailles des tokens × 1,1), comme Qt.
    /// Espacements, rayons et hauteurs ne changent pas.
    static let scale: CGFloat = 1.1

    enum Theme { case dark, light, system }

    /// Thème de l'appli : sombre par défaut.
    @MainActor static func apply(_ theme: Theme = .dark) {
        switch theme {
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .system: NSApp.appearance = nil
        }
    }

    // MARK: Couleurs (suivent le thème de la fenêtre)

    enum C {
        /// Fond de la fenêtre, derrière les panneaux.
        static let bg = dynamic(dark: (0.1176, 0.1176, 0.1176, 1), light: (0.9490, 0.9490, 0.9490, 1))
        /// Zones en creux : journaux, listes de fichiers, champs de saisie, scène d'accueil.
        static let bgSunken = dynamic(dark: (0.0941, 0.0941, 0.0941, 1), light: (0.9216, 0.9216, 0.9216, 1))
        /// Contenu encastré dans un panneau : zone de dépôt, cadre d'aperçu, encart de texte long.
        static let bgInset = dynamic(dark: (0.1020, 0.1020, 0.1020, 1), light: (0.9686, 0.9686, 0.9686, 1))
        /// Panneaux de travail, cartes de groupe, corps des dialogues.
        static let surface = dynamic(dark: (0.1333, 0.1333, 0.1333, 1), light: (1.0000, 1.0000, 1.0000, 1))
        /// Chrome qui encadre le travail : barre d'en-tête, barre latérale.
        static let surfaceRaised = dynamic(dark: (0.1490, 0.1490, 0.1490, 1), light: (0.9804, 0.9804, 0.9804, 1))
        /// Survol d'une ligne de liste ou d'option.
        static let surfaceHover = dynamic(dark: (0.1725, 0.1725, 0.1725, 1), light: (0.9412, 0.9412, 0.9412, 1))
        /// Ligne sélectionnée ; le contrôle (radio, case) porte l'accent, pas la ligne.
        static let surfaceSelected = dynamic(dark: (0.1882, 0.1882, 0.1882, 1), light: (0.9098, 0.9098, 0.9098, 1))
        /// Aplat des boutons secondaires, sans contour.
        static let control = dynamic(dark: (0.2000, 0.2000, 0.2000, 1), light: (0.9020, 0.9020, 0.9020, 1))
        /// Survol d'un bouton secondaire.
        static let controlHover = dynamic(dark: (0.2510, 0.2510, 0.2510, 1), light: (0.8510, 0.8510, 0.8510, 1))
        /// Bouton secondaire enfoncé.
        static let controlPressed = dynamic(dark: (0.1647, 0.1647, 0.1647, 1), light: (0.8000, 0.8000, 0.8000, 1))
        /// Bouton tertiaire plein et poignée de barre de défilement au survol.
        static let controlStrong = dynamic(dark: (0.2667, 0.2667, 0.2667, 1), light: (0.8314, 0.8314, 0.8314, 1))
        /// Filet de 1px autour des panneaux, de l'en-tête et des dialogues ; soulignement d'onglets.
        static let border = dynamic(dark: (0.2000, 0.2000, 0.2000, 1), light: (0.8314, 0.8314, 0.8314, 1))
        /// Tirets de la zone de dépôt au repos. Jamais en contour de bouton.
        static let borderStrong = dynamic(dark: (0.2667, 0.2667, 0.2667, 1), light: (0.7412, 0.7412, 0.7412, 1))
        /// Séparateurs à l'intérieur d'une carte.
        static let borderSubtle = dynamic(dark: (0.1804, 0.1804, 0.1804, 1), light: (0.8980, 0.8980, 0.8980, 1))
        /// Contour des radios, cases à cocher et champs non sélectionnés. 3,2:1 sur surface (sombre), 3,5:1 sur surface (clair).
        static let borderControl = dynamic(dark: (0.4392, 0.4392, 0.4392, 1), light: (0.5412, 0.5412, 0.5412, 1))
        /// Titres, libellés de boutons secondaires, option sélectionnée, sur tout fond bg-* et surface-*.
        static let textStrong = dynamic(dark: (1.0000, 1.0000, 1.0000, 1), light: (0.0667, 0.0667, 0.0667, 1))
        /// Texte courant sur tout fond bg-* et surface-*.
        static let text = dynamic(dark: (0.8667, 0.8667, 0.8667, 1), light: (0.1333, 0.1333, 0.1333, 1))
        /// Texte secondaire : sous-titres, libellés de stats, en-têtes de tableau. ≥ 6,2:1 sur tous les fonds.
        static let textMuted = dynamic(dark: (0.6667, 0.6667, 0.6667, 1), light: (0.3333, 0.3333, 0.3333, 1))
        /// Méta-informations, surtitres, compteurs, indications. ≥ 4,7:1 sur tous les fonds.
        static let textSubtle = dynamic(dark: (0.5608, 0.5608, 0.5608, 1), light: (0.4000, 0.4000, 0.4000, 1))
        /// Texte d'un contrôle désactivé uniquement (exempté du contraste).
        static let textDisabled = dynamic(dark: (0.4000, 0.4000, 0.4000, 1), light: (0.6392, 0.6392, 0.6392, 1))
        /// L'accent en tant que marque : radio et case cochées, soulignement d'onglet actif, zone de dépôt survolée. 5,8:1 sur surface (sombre), 4,1:1 (clair) — jamais pour du texte.
        static let accent = dynamic(dark: (0.0549, 0.6471, 0.9137, 1), light: (0.0078, 0.5176, 0.7804, 1))
        /// Point de radio et coche dessinés sur accent.
        static let onAccent = dynamic(dark: (0.0314, 0.1843, 0.2863, 1), light: (1.0000, 1.0000, 1.0000, 1))
        /// Fond des boutons principaux (Continuer, Valider). Libellé on-accent-fill à 5,9:1.
        static let accentFill = dynamic(dark: (0.0118, 0.4118, 0.6314, 1), light: (0.0118, 0.4118, 0.6314, 1))
        /// Survol d'un bouton principal.
        static let accentFillHover = dynamic(dark: (0.0275, 0.3490, 0.5216, 1), light: (0.0275, 0.3490, 0.5216, 1))
        /// Bouton principal enfoncé.
        static let accentFillPressed = dynamic(dark: (0.0471, 0.2902, 0.4314, 1), light: (0.0471, 0.2902, 0.4314, 1))
        /// Libellé sur accent-fill et ses états.
        static let onAccentFill = dynamic(dark: (1.0000, 1.0000, 1.0000, 1), light: (1.0000, 1.0000, 1.0000, 1))
        /// L'accent en texte : chemins, liens, valeurs mises en avant. ≥ 5,4:1 sur tous les fonds.
        static let accentText = dynamic(dark: (0.2196, 0.7412, 0.9725, 1), light: (0.0118, 0.4118, 0.6314, 1))
        /// L'appel principal d'un écran — un seul par écran (Ouvrir, Importer, Créer). Libellé on-action.
        static let action = dynamic(dark: (0.9843, 0.7490, 0.1412, 1), light: (0.9843, 0.7490, 0.1412, 1))
        /// Survol du bouton d'action.
        static let actionHover = dynamic(dark: (0.9608, 0.6196, 0.0431, 1), light: (0.9608, 0.6196, 0.0431, 1))
        /// Bouton d'action enfoncé.
        static let actionPressed = dynamic(dark: (0.8510, 0.4667, 0.0235, 1), light: (0.8510, 0.4667, 0.0235, 1))
        /// Libellé sur action et ses états. 10,4:1 sur action.
        static let onAction = dynamic(dark: (0.1020, 0.1020, 0.1020, 1), light: (0.1020, 0.1020, 0.1020, 1))
        /// Texte et chiffres de réussite, sur surface et bg-sunken. Toujours accompagné d'un mot ou d'un préfixe.
        static let success = dynamic(dark: (0.2902, 0.8706, 0.5020, 1), light: (0.0824, 0.5020, 0.2392, 1))
        /// Fond opaque d'un badge ou d'un encart de réussite.
        static let successBg = dynamic(dark: (0.0784, 0.2235, 0.1216, 1), light: (0.8627, 0.9882, 0.9059, 1))
        /// Contour d'un encart de réussite.
        static let successBorder = dynamic(dark: (0.1333, 0.7725, 0.3686, 1), light: (0.0863, 0.6392, 0.2902, 1))
        /// Texte dans un encart de réussite, sur success-bg.
        static let successSoft = dynamic(dark: (0.5255, 0.9373, 0.6745, 1), light: (0.0784, 0.3255, 0.1765, 1))
        /// Texte d'avertissement, sur surface et bg-sunken.
        static let warning = dynamic(dark: (0.9843, 0.7490, 0.1412, 1), light: (0.7059, 0.3255, 0.0353, 1))
        /// Fond opaque d'un badge ou d'un encart d'avertissement.
        static let warningBg = dynamic(dark: (0.2471, 0.1647, 0.0471, 1), light: (0.9961, 0.9529, 0.7804, 1))
        /// Contour d'un encart d'avertissement.
        static let warningBorder = dynamic(dark: (0.9608, 0.6196, 0.0431, 1), light: (0.8510, 0.4667, 0.0235, 1))
        /// Texte dans un encart d'avertissement, sur warning-bg.
        static let warningSoft = dynamic(dark: (0.9922, 0.9020, 0.5412, 1), light: (0.4706, 0.2078, 0.0588, 1))
        /// Texte d'erreur et éléments manquants, sur surface et bg-sunken.
        static let danger = dynamic(dark: (0.9725, 0.4431, 0.4431, 1), light: (0.7255, 0.1098, 0.1098, 1))
        /// Fond opaque d'un badge ou d'un encart d'erreur.
        static let dangerBg = dynamic(dark: (0.2902, 0.1098, 0.1098, 1), light: (0.9961, 0.8863, 0.8863, 1))
        /// Contour d'un encart ou d'un dialogue d'erreur.
        static let dangerBorder = dynamic(dark: (0.9373, 0.2667, 0.2667, 1), light: (0.8627, 0.1490, 0.1490, 1))
        /// Texte dans un encart d'erreur, sur danger-bg.
        static let dangerSoft = dynamic(dark: (0.9961, 0.7922, 0.7922, 1), light: (0.4980, 0.1137, 0.1137, 1))
        /// Aplat rouge atténué d'un bouton ou d'une pastille d'état « refusé » sélectionné ; texte text-strong dessus. Moins vif que danger-border.
        static let dangerFill = dynamic(dark: (0.5725, 0.2078, 0.2078, 1), light: (0.9216, 0.5647, 0.5647, 1))
        /// Contour d'un encart d'information.
        static let infoBorder = dynamic(dark: (0.2196, 0.7412, 0.9725, 1), light: (0.0078, 0.5176, 0.7804, 1))
        /// Texte dans un encart d'information (fond neutre surface-raised, sans aplat de couleur).
        static let infoSoft = dynamic(dark: (0.7294, 0.9020, 0.9922, 1), light: (0.0471, 0.2902, 0.4314, 1))
        /// Fond plein d'une bulle d'aide ou d'explication (bleu).
        static let bubbleHelp = dynamic(dark: (0.0549, 0.6471, 0.9137, 1), light: (0.0549, 0.6471, 0.9137, 1))
        /// Fond plein d'une bulle de conseil ou d'astuce (vert).
        static let bubbleTip = dynamic(dark: (0.1333, 0.7725, 0.3686, 1), light: (0.1333, 0.7725, 0.3686, 1))
        /// Fond plein d'une bulle d'attention (jaune).
        static let bubbleWarning = dynamic(dark: (0.9843, 0.7490, 0.1412, 1), light: (0.9843, 0.7490, 0.1412, 1))
        /// Fond plein d'une bulle d'action irréversible (rouge).
        static let bubbleDanger = dynamic(dark: (0.9373, 0.2667, 0.2667, 1), light: (0.9373, 0.2667, 0.2667, 1))
        /// Fond plein d'une bulle de l'intelligence artificielle (ambre).
        static let bubbleAi = dynamic(dark: (0.9608, 0.6196, 0.0431, 1), light: (0.9608, 0.6196, 0.0431, 1))
        /// Texte et titre d'une bulle, sur son fond plein coloré, dans les deux thèmes.
        static let onBubble = dynamic(dark: (0.1020, 0.1020, 0.1020, 1), light: (0.1020, 0.1020, 0.1020, 1))
        /// Carré sombre qui porte l'icône blanche d'une bulle.
        static let bubbleIcon = dynamic(dark: (0.1490, 0.1490, 0.1490, 1), light: (0.1490, 0.1490, 0.1490, 1))
        /// Contour de focus clavier, 2px décalé de 2px. ≥ 3:1 sur toutes les surfaces.
        static let focusRing = dynamic(dark: (0.2196, 0.7412, 0.9725, 1), light: (0.0118, 0.4118, 0.6314, 1))
        /// Voile derrière un dialogue ; avec le filet border, c'est ce qui le détache (aucune ombre).
        static let scrim = dynamic(dark: (0.0000, 0.0000, 0.0000, 0.75), light: (0.0667, 0.0667, 0.0667, 0.45))
    }

    // MARK: Mesures (px)

    enum M {
        static let space1: CGFloat = 4
        static let space1_5: CGFloat = 6
        static let space2: CGFloat = 8
        static let space2_5: CGFloat = 10
        static let space3: CGFloat = 12
        static let space4: CGFloat = 16
        static let space5: CGFloat = 20
        static let space6: CGFloat = 24
        static let space8: CGFloat = 32
        static let radius: CGFloat = 4
        static let radiusField: CGFloat = 0
        static let radiusMd: CGFloat = 6
        static let radiusLg: CGFloat = 8
        static let radiusXl: CGFloat = 12
        static let radiusFull: CGFloat = 9999
        static let sizeBar: CGFloat = 40
        static let sizeControl: CGFloat = 32
        static let sizeControlLg: CGFloat = 36
        static let sizeCta: CGFloat = 56
        static let sizeChoice: CGFloat = 16
        static let sizeScrollbar: CGFloat = 8
        static let sizeSidebarMin: CGFloat = 200
        static let sizeSplashWidth: CGFloat = 500
        static let sizeSplashHeight: CGFloat = 190
        static let sizeSplashTitle: CGFloat = 40
        static let opacityDisabled: CGFloat = 0.4
    }

    // MARK: Typographie

    struct TextStyle {
        let size: CGFloat
        let weight: Font.Weight
        let tracking: CGFloat   // em
        let mono: Bool

        var pointSize: CGFloat { max(8, (size * Socle.scale).rounded()) }
        var font: Font {
            .system(size: pointSize, weight: weight, design: mono ? .monospaced : .default)
        }
        var nsFont: NSFont {
            let w: NSFont.Weight = switch weight {
            case .bold: .bold
            case .semibold: .semibold
            case .medium: .medium
            default: .regular
            }
            return mono ? .monospacedSystemFont(ofSize: pointSize, weight: w) : .systemFont(ofSize: pointSize, weight: w)
        }
    }

    enum T {
        static let display = TextStyle(size: 20, weight: .bold, tracking: 0.025, mono: false)
        static let heading = TextStyle(size: 16, weight: .bold, tracking: 0.025, mono: false)
        static let title = TextStyle(size: 14, weight: .bold, tracking: 0.025, mono: false)
        static let stat = TextStyle(size: 20, weight: .bold, tracking: 0, mono: false)
        static let reading = TextStyle(size: 15, weight: .regular, tracking: 0, mono: false)
        static let bodyLg = TextStyle(size: 14, weight: .regular, tracking: 0, mono: false)
        static let body = TextStyle(size: 12, weight: .regular, tracking: 0, mono: false)
        static let bodyRelaxed = TextStyle(size: 12, weight: .regular, tracking: 0, mono: false)
        static let label = TextStyle(size: 12, weight: .medium, tracking: 0, mono: false)
        static let labelStrong = TextStyle(size: 12, weight: .bold, tracking: 0, mono: false)
        static let eyebrow = TextStyle(size: 12, weight: .bold, tracking: 0.05, mono: false)
        static let meta = TextStyle(size: 11, weight: .regular, tracking: 0, mono: false)
        static let caption = TextStyle(size: 10, weight: .regular, tracking: 0, mono: false)
        static let buttonLg = TextStyle(size: 14, weight: .bold, tracking: 0, mono: false)
        static let buttonFlow = TextStyle(size: 12, weight: .bold, tracking: 0.025, mono: false)
        static let button = TextStyle(size: 12, weight: .medium, tracking: 0, mono: false)
        static let mono = TextStyle(size: 12, weight: .regular, tracking: 0, mono: true)
        static let monoSm = TextStyle(size: 11, weight: .regular, tracking: 0, mono: true)
    }

    static func dynamic(dark: (CGFloat, CGFloat, CGFloat, CGFloat), light: (CGFloat, CGFloat, CGFloat, CGFloat)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let c = appearance.bestMatch(from: [.darkAqua, .aqua]) == .aqua ? light : dark
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: c.3)
        })
    }
}

extension View {
    /// Applique un style typographique Socle (police système, taille × échelle, interlettrage).
    func socle(_ style: Socle.TextStyle) -> some View {
        font(style.font).tracking(style.tracking * style.pointSize)
    }
}

/// Nom de l'appli : sa lettre minuscule, à toute place (le « m » de mORTEX, le « e » de CAREERDeSK…), prend la couleur
/// de son logo partout où le nom est écrit. Poser `Socle.brand("nEXUSWATCH", color: …)` au démarrage, puis
/// écrire `Text(branded: texte)` pour tout texte qui peut contenir le nom (titres, textes, dialogues).
/// Titres de fenêtre, menus et notifications système n'acceptent pas de couleur.
extension Socle {
    nonisolated(unsafe) private(set) static var brandNames: [String] = []
    nonisolated(unsafe) private(set) static var brandColor: Color = .accentColor

    static func brand(_ names: String..., color: Color) {
        brandNames = names
        brandColor = color
    }

    /// Texte avec la lettre minuscule de chaque occurrence du nom de l'appli colorée.
    static func branded(_ text: String) -> AttributedString {
        branded(AttributedString(text))
    }

    /// Même chose sur un texte déjà mis en forme (Markdown…), sans toucher à ses autres attributs.
    static func branded(_ attributed: AttributedString) -> AttributedString {
        var out = attributed
        let text = String(attributed.characters)
        for name in brandNames {
            let marks = name.enumerated().filter { $0.element.isLowercase }.map(\.offset)
            guard !marks.isEmpty else { continue }
            var from = text.startIndex
            while let r = text.range(of: name, range: from..<text.endIndex) {
                from = r.upperBound
                let before = r.lowerBound == text.startIndex ? nil : text[text.index(before: r.lowerBound)]
                let after = r.upperBound == text.endIndex ? nil : text[r.upperBound]
                // Pas dans un mot, un chemin, un identifiant ni une adresse
                if let b = before, b.isLetter || b.isNumber || "./@-_".contains(b) { continue }
                if let a = after, a.isLetter || a.isNumber || "-_".contains(a) { continue }
                let lo = text.distance(from: text.startIndex, to: r.lowerBound)
                for mark in marks {
                    let start = out.index(out.startIndex, offsetByCharacters: lo + mark)
                    out[start..<out.index(afterCharacter: start)].foregroundColor = brandColor
                }
            }
        }
        return out
    }
}

extension Text {
    /// Texte où la lettre minuscule du nom de l'appli prend la couleur de son logo (voir `Socle.brand`).
    init(branded text: String) {
        self.init(Socle.branded(text))
    }
}

extension View {
    /// Zone de saisie Socle (TextField, SecureField, TextEditor) : angles droits, fond creux, filet 1 px,
    /// marge intérieure `space-3` ; un champ d'une ligne fait au moins `size-control-lg` de haut.
    func socleField(multiline: Bool = false) -> some View {
        modifier(SocleField(multiline: multiline))
    }
}

struct SocleField: ViewModifier {
    let multiline: Bool
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .scrollContentBackground(.hidden)
            .focused($focused)
            .socleEditing(focused)
            .padding(.horizontal, Socle.M.space3)
            .padding(.vertical, multiline ? Socle.M.space3 : Socle.M.space2)
            .frame(minHeight: multiline ? nil : Socle.M.sizeControlLg)
            .background(Socle.C.bgSunken)
            .overlay(Rectangle().stroke(focused ? Socle.C.focusRing : .clear, lineWidth: 1))
            .foregroundStyle(Socle.C.textStrong)
    }
}

/// Grille de modules Socle : blocs indépendants en colonnes de même largeur (au moins `minimum`), autant que la
/// largeur en permet, espacées de `space-4`. Agencement en maçonnerie : chaque bloc se place sous la colonne la plus
/// courte, à sa hauteur naturelle, sans trou sous un bloc plus court que son voisin. Le module où l'on saisit, sinon
/// celui que la souris survole, reste net ; les autres s'estompent. Chaque bloc de la grille porte `.socleModule()`.
struct SocleModuleGrid<Content: View>: View {
    var minimum: CGFloat = 550  // 500 px × échelle de texte 1,1
    @ViewBuilder var content: Content
    @State private var spotlight = SocleSpotlight()

    var body: some View {
        SocleMasonry(minimum: minimum, spacing: Socle.M.space4) { content }
            .environment(spotlight)
    }
}

/// Maçonnerie : colonnes de largeur égale ; chaque élément va sous la colonne la plus courte.
struct SocleMasonry: Layout {
    var minimum: CGFloat
    var spacing: CGFloat

    private func arrange(_ width: CGFloat, _ subviews: Subviews) -> (points: [CGPoint], column: CGFloat, height: CGFloat) {
        let width = width.isFinite && width > 0 ? width : minimum
        let n = max(1, Int((width + spacing) / (minimum + spacing)))
        let column = (width - CGFloat(n - 1) * spacing) / CGFloat(n)
        var heights = Array(repeating: CGFloat(0), count: n)
        var points: [CGPoint] = []
        for view in subviews {
            let h = view.sizeThatFits(ProposedViewSize(width: column, height: nil)).height
            let c = heights.indices.min { heights[$0] < heights[$1] } ?? 0
            points.append(CGPoint(x: CGFloat(c) * (column + spacing), y: heights[c]))
            heights[c] += h + spacing
        }
        return (points, column, max(0, (heights.max() ?? 0) - spacing))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? minimum
        return CGSize(width: width, height: arrange(width, subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrange(bounds.width, subviews)
        for (view, p) in zip(subviews, layout.points) {
            view.place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: ProposedViewSize(width: layout.column, height: nil))
        }
    }
}

/// Module actif d'une grille : celui où l'on saisit, sinon celui survolé.
@MainActor @Observable
final class SocleSpotlight {
    static let dimmed = 0.45
    var hovered: UUID?
    var editing: UUID?
    var active: UUID? { editing ?? hovered }
}

private struct SocleModuleKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
    var socleModule: UUID? {
        get { self[SocleModuleKey.self] }
        set { self[SocleModuleKey.self] = newValue }
    }
}

extension View {
    /// Bloc d'une `SocleModuleGrid` : suivi du survol, estompé quand un autre bloc est actif. Sans grille : sans effet.
    func socleModule() -> some View { modifier(SocleModule()) }

    /// Signale à la grille qu'un champ prend ou perd le focus (déjà fait par `.socleField()`).
    func socleEditing(_ focused: Bool) -> some View { modifier(SocleEditing(focused: focused)) }
}

private struct SocleModule: ViewModifier {
    @Environment(SocleSpotlight.self) private var spotlight: SocleSpotlight?
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .environment(\.socleModule, id)
            .opacity(spotlight?.active.map { $0 == id ? 1 : SocleSpotlight.dimmed } ?? 1)
            .animation(.easeInOut(duration: 0.15), value: spotlight?.active)
            .onHover { inside in
                guard let spotlight else { return }
                if inside { spotlight.hovered = id } else if spotlight.hovered == id { spotlight.hovered = nil }
            }
    }
}

private struct SocleEditing: ViewModifier {
    @Environment(SocleSpotlight.self) private var spotlight: SocleSpotlight?
    @Environment(\.socleModule) private var module
    let focused: Bool

    func body(content: Content) -> some View {
        content.onChange(of: focused) { _, now in
            guard let spotlight, let module else { return }
            if now { spotlight.editing = module } else if spotlight.editing == module { spotlight.editing = nil }
        }
    }
}

extension View {
    /// Valeur saisie (nombre, montant, durée) : en `accent-text`, à poser avant `.socleField()`.
    func socleValue() -> some View { foregroundStyle(Socle.C.accentText) }
}

/// Choix à niveaux Socle : l'option choisie prend la couleur de son niveau (fort, intermédiaire, neutre).
struct SocleSegmented<Value: Hashable>: View {
    enum Tone { case strong, soft, neutral }
    let options: [Value]
    let selection: Value
    let label: (Value) -> String
    var tone: (Value) -> Tone = { _ in .strong }
    let onSelect: (Value) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let on = option == selection
                Button { onSelect(option) } label: {
                    Text(label(option)).socle(Socle.T.label)
                        .padding(.horizontal, Socle.M.space2_5).frame(minHeight: 26)
                        .foregroundStyle(on ? foreground(tone(option)) : Socle.C.textMuted)
                        .background(on ? background(tone(option)) : Color.clear, in: RoundedRectangle(cornerRadius: Socle.M.radius))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Socle.C.bgSunken, in: RoundedRectangle(cornerRadius: Socle.M.radius))
        .fixedSize()
    }

    private func background(_ t: Tone) -> Color {
        switch t {
        case .strong: Socle.C.accentFill
        case .soft: Socle.C.control
        case .neutral: Socle.C.control
        }
    }

    private func foreground(_ t: Tone) -> Color {
        switch t {
        case .strong: Socle.C.onAccentFill
        case .soft: Socle.C.accentText
        case .neutral: Socle.C.text
        }
    }
}

/// Étiquette de valeur Socle (commune, mot-clé) : fond `control`, texte `accent-text`, croix pour retirer.
struct SocleChip: View {
    let text: String
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
            if let onRemove {
                Button(action: onRemove) { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)) }.buttonStyle(.plain)
            }
        }
        .foregroundStyle(Socle.C.accentText)
        .padding(.horizontal, Socle.M.space2).padding(.vertical, 3)
        .background(Socle.C.control, in: Capsule())
    }
}

/// Boutons plats Socle : aplat de couleur, aucun contour, aucun relief ; focus clavier 2 px.
struct SocleButtonStyle: ButtonStyle {
    enum Variant { case primary, action, secondary, tertiary }
    let variant: Variant
    var height: CGFloat = Socle.M.sizeControlLg

    init(_ variant: Variant, height: CGFloat = Socle.M.sizeControlLg) {
        self.variant = variant
        self.height = height
    }

    func makeBody(configuration: Configuration) -> some View {
        Styled(configuration: configuration, variant: variant, height: height)
    }

    private struct Styled: View {
        let configuration: Configuration
        let variant: Variant
        let height: CGFloat
        @Environment(\.isEnabled) private var enabled
        @State private var hover = false

        var body: some View {
            configuration.label
                .socle(variant == .action ? Socle.T.buttonLg : (variant == .primary ? Socle.T.buttonFlow : Socle.T.button))
                .foregroundStyle(foreground)
                .padding(.horizontal, Socle.M.space4)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(background, in: RoundedRectangle(cornerRadius: Socle.M.radius))
                .contentShape(Rectangle())
                .opacity(enabled ? 1 : Socle.M.opacityDisabled)
                .onHover { hover = $0 }
                .animation(.easeOut(duration: 0.15), value: hover)
        }

        private var foreground: Color {
            switch variant {
            case .primary: Socle.C.onAccentFill
            case .action: Socle.C.onAction
            case .secondary, .tertiary: Socle.C.textStrong
            }
        }

        private var background: Color {
            let pressed = configuration.isPressed && enabled
            let hovered = hover && enabled
            switch variant {
            case .primary: return pressed ? Socle.C.accentFillPressed : hovered ? Socle.C.accentFillHover : Socle.C.accentFill
            case .action: return pressed ? Socle.C.actionPressed : hovered ? Socle.C.actionHover : Socle.C.action
            case .secondary: return pressed ? Socle.C.controlPressed : hovered ? Socle.C.controlHover : Socle.C.control
            case .tertiary: return pressed ? Socle.C.controlPressed : hovered ? Socle.C.controlStrong : .clear
            }
        }
    }
}

extension NSWindow {
    /// Centre exactement la fenêtre sur l'écran du pointeur, dans sa zone utile (`center()` de macOS la place au-dessus du centre).
    @MainActor func socleCenter() {
        let pointeur = NSEvent.mouseLocation
        let ecran = NSScreen.screens.first { NSMouseInRect(pointeur, $0.frame, false) } ?? screen ?? NSScreen.main
        guard let zone = ecran?.visibleFrame else { return }
        setFrameOrigin(NSPoint(x: zone.midX - frame.width / 2, y: zone.midY - frame.height / 2))
    }
}

extension View {
    /// Filigrane de la colonne de gauche : motif de l'icône de l'appli, d'une seule teinte, derrière le contenu.
    /// À poser avant le `.background` de la colonne. Il déborde du bas et de la droite, et ne capte aucun clic.
    func socleWatermark<Mark: View>(@ViewBuilder _ mark: () -> Mark) -> some View {
        let mark = mark()
        return background {
            GeometryReader { zone in
                let side = zone.size.width * 1.3
                mark
                    .frame(width: side, height: side)
                    .foregroundStyle(Socle.C.textStrong)
                    .opacity(0.05)
                    .position(x: zone.size.width * 0.62, y: zone.size.height - side * 0.38)
            }
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
