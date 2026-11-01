"""Socle pour Qt (PyQt6) — thème commun de mes applications.

FICHIER GÉNÉRÉ par Socle/qt/build_socle_qt.py à partir de Socle/tokens.json.
Ne pas le modifier à la main : modifier tokens.json ou socle_qt_template.py, puis régénérer.

Utilisation :
    import socle_qt
    app = QApplication(sys.argv)
    socle_qt.apply(app)                          # thème sombre par défaut
    socle_qt.variant(bouton, "primary")          # primary | action | secondary | tertiary
    socle_qt.role(label, "title")                # title | heading | display | eyebrow | meta | mono | path | muted | subtle
    socle_qt.status(label, "success")            # success | warning | danger | none (+ repolish auto)
    socle_qt.brand(app, "sKYCRASH", "#ff7a00")   # minuscule du nom de l'appli dans la couleur de son logo
    socle_qt.traduire_qt(app, "fr")              # menus et boutons fournis par Qt dans la langue de l'appli
    # Les fenêtres se centrent seules à leur première ouverture (apply) ; socle_qt.centrer(fenetre) pour le faire à la main.
"""
import html
import os
import re
import tempfile

from PyQt6.QtGui import QColor, QCursor, QFont, QFontDatabase, QGuiApplication, QPalette
from PyQt6.QtCore import QEvent, QLibraryInfo, QObject, Qt, QTimer, QTranslator
from PyQt6.QtWidgets import (QApplication, QCheckBox, QHBoxLayout, QLabel, QPushButton, QRadioButton, QSizePolicy,
                             QWidget)

TOKENS = {'version': 1,
 'colors': {'dark': {'bg': '#1e1e1e',
                     'bg-sunken': '#181818',
                     'bg-inset': '#1a1a1a',
                     'surface': '#222222',
                     'surface-raised': '#262626',
                     'surface-hover': '#2c2c2c',
                     'surface-selected': '#303030',
                     'control': '#333333',
                     'control-hover': '#404040',
                     'control-pressed': '#2a2a2a',
                     'control-strong': '#444444',
                     'border': '#333333',
                     'border-strong': '#444444',
                     'border-subtle': '#2e2e2e',
                     'border-control': '#707070',
                     'text-strong': '#ffffff',
                     'text': '#dddddd',
                     'text-muted': '#aaaaaa',
                     'text-subtle': '#8f8f8f',
                     'text-disabled': '#666666',
                     'accent': '#0ea5e9',
                     'on-accent': '#082f49',
                     'accent-fill': '#0369a1',
                     'accent-fill-hover': '#075985',
                     'accent-fill-pressed': '#0c4a6e',
                     'on-accent-fill': '#ffffff',
                     'accent-text': '#38bdf8',
                     'action': '#fbbf24',
                     'action-hover': '#f59e0b',
                     'action-pressed': '#d97706',
                     'on-action': '#1a1a1a',
                     'success': '#4ade80',
                     'success-bg': '#14391f',
                     'success-border': '#22c55e',
                     'success-soft': '#86efac',
                     'warning': '#fbbf24',
                     'warning-bg': '#3f2a0c',
                     'warning-border': '#f59e0b',
                     'warning-soft': '#fde68a',
                     'danger': '#f87171',
                     'danger-bg': '#4a1c1c',
                     'danger-border': '#ef4444',
                     'danger-soft': '#fecaca',
                     'info-border': '#38bdf8',
                     'info-soft': '#bae6fd',
                     'bubble-help': '#0ea5e9',
                     'bubble-tip': '#22c55e',
                     'bubble-warning': '#fbbf24',
                     'bubble-danger': '#ef4444',
                     'bubble-ai': '#f59e0b',
                     'on-bubble': '#1a1a1a',
                     'bubble-icon': '#262626',
                     'focus-ring': '#38bdf8',
                     'scrim': 'rgba(0, 0, 0, 0.75)'},
            'light': {'bg': '#f2f2f2',
                      'bg-sunken': '#ebebeb',
                      'bg-inset': '#f7f7f7',
                      'surface': '#ffffff',
                      'surface-raised': '#fafafa',
                      'surface-hover': '#f0f0f0',
                      'surface-selected': '#e8e8e8',
                      'control': '#e6e6e6',
                      'control-hover': '#d9d9d9',
                      'control-pressed': '#cccccc',
                      'control-strong': '#d4d4d4',
                      'border': '#d4d4d4',
                      'border-strong': '#bdbdbd',
                      'border-subtle': '#e5e5e5',
                      'border-control': '#8a8a8a',
                      'text-strong': '#111111',
                      'text': '#222222',
                      'text-muted': '#555555',
                      'text-subtle': '#666666',
                      'text-disabled': '#a3a3a3',
                      'accent': '#0284c7',
                      'on-accent': '#ffffff',
                      'accent-fill': '#0369a1',
                      'accent-fill-hover': '#075985',
                      'accent-fill-pressed': '#0c4a6e',
                      'on-accent-fill': '#ffffff',
                      'accent-text': '#0369a1',
                      'action': '#fbbf24',
                      'action-hover': '#f59e0b',
                      'action-pressed': '#d97706',
                      'on-action': '#1a1a1a',
                      'success': '#15803d',
                      'success-bg': '#dcfce7',
                      'success-border': '#16a34a',
                      'success-soft': '#14532d',
                      'warning': '#b45309',
                      'warning-bg': '#fef3c7',
                      'warning-border': '#d97706',
                      'warning-soft': '#78350f',
                      'danger': '#b91c1c',
                      'danger-bg': '#fee2e2',
                      'danger-border': '#dc2626',
                      'danger-soft': '#7f1d1d',
                      'info-border': '#0284c7',
                      'info-soft': '#0c4a6e',
                      'bubble-help': '#0ea5e9',
                      'bubble-tip': '#22c55e',
                      'bubble-warning': '#fbbf24',
                      'bubble-danger': '#ef4444',
                      'bubble-ai': '#f59e0b',
                      'on-bubble': '#1a1a1a',
                      'bubble-icon': '#262626',
                      'focus-ring': '#0369a1',
                      'scrim': 'rgba(17, 17, 17, 0.45)'}},
 'metrics': {'space-1': 4,
             'space-1.5': 6,
             'space-2': 8,
             'space-2.5': 10,
             'space-3': 12,
             'space-4': 16,
             'space-5': 20,
             'space-6': 24,
             'space-8': 32,
             'radius': 4,
             'radius-field': 0,
             'radius-md': 6,
             'radius-lg': 8,
             'radius-xl': 12,
             'radius-full': 9999,
             'size-bar': 40,
             'size-control': 32,
             'size-control-lg': 36,
             'size-cta': 56,
             'size-choice': 16,
             'size-scrollbar': 8,
             'size-sidebar-min': 200,
             'size-splash-width': 500,
             'size-splash-height': 190,
             'size-splash-title': 40,
             'opacity-disabled': 0.4},
 'type': {'display': {'family': 'sans', 'size': 20, 'weight': 700},
          'heading': {'family': 'sans', 'size': 16, 'weight': 700},
          'title': {'family': 'sans', 'size': 14, 'weight': 700},
          'stat': {'family': 'sans', 'size': 20, 'weight': 700},
          'reading': {'family': 'sans', 'size': 15, 'weight': 400},
          'body-lg': {'family': 'sans', 'size': 14, 'weight': 400},
          'body': {'family': 'sans', 'size': 12, 'weight': 400},
          'body-relaxed': {'family': 'sans', 'size': 12, 'weight': 400},
          'label': {'family': 'sans', 'size': 12, 'weight': 500},
          'label-strong': {'family': 'sans', 'size': 12, 'weight': 700},
          'eyebrow': {'family': 'sans', 'size': 12, 'weight': 700},
          'meta': {'family': 'sans', 'size': 11, 'weight': 400},
          'caption': {'family': 'sans', 'size': 10, 'weight': 400},
          'button-lg': {'family': 'sans', 'size': 14, 'weight': 700},
          'button-flow': {'family': 'sans', 'size': 12, 'weight': 700},
          'button': {'family': 'sans', 'size': 12, 'weight': 500},
          'mono': {'family': 'mono', 'size': 12, 'weight': 400},
          'mono-sm': {'family': 'mono', 'size': 11, 'weight': 400}}}

_theme = "dark"
_full = True
# Échelle fixe des applis Qt : les tailles typographiques des tokens × 1,1 (body 12 → 13 px…), réglée
# après essais sur l'écran de l'utilisateur. Pas de zoom à la volée : espacements, rayons et hauteurs ne
# changent pas, l'agencement reste celui qui a été vérifié.
SCALE = 1.1
for _spec in TOKENS["type"].values():
    _spec["size"] = max(8, round(_spec["size"] * SCALE))


def scale() -> float:
    """Échelle typographique des applis (fixe) : pour mettre à l'échelle une taille propre à l'appli."""
    return SCALE


def c(name: str, theme: str | None = None) -> str:
    """Valeur d'un token de couleur pour le thème courant (ou celui demandé)."""
    return TOKENS["colors"][theme or _theme][name]


def m(name: str) -> int | float:
    """Valeur d'un token d'espacement, de rayon, de taille ou d'opacité (px)."""
    return TOKENS["metrics"][name]


def font(style: str = "body") -> QFont:
    """QFont correspondant à un style typographique Socle (body, title, mono…)."""
    spec = TOKENS["type"][style]
    if spec["family"] == "mono":
        f = QFontDatabase.systemFont(QFontDatabase.SystemFont.FixedFont)
    else:
        f = QFontDatabase.systemFont(QFontDatabase.SystemFont.GeneralFont)
    f.setPixelSize(spec["size"])
    f.setWeight(QFont.Weight(spec["weight"]))
    if style in ("display", "heading", "title", "button-flow"):
        f.setLetterSpacing(QFont.SpacingType.PercentageSpacing, 102.5)
    elif style == "eyebrow":
        f.setLetterSpacing(QFont.SpacingType.PercentageSpacing, 105)
    return f


def _repolish(w: QWidget) -> None:
    w.style().unpolish(w)
    w.style().polish(w)
    w.update()


def variant(button: QWidget, name: str) -> QWidget:
    """Variante de bouton : primary, action, secondary (défaut), tertiary."""
    button.setProperty("variant", name)
    _repolish(button)  # avant setFont : le polish de la feuille QSS réinitialise la police
    if name in ("primary", "flow"):
        button.setFont(font("button-flow"))
    elif name == "action":
        button.setFont(font("button-lg"))
    return button


def role(widget: QWidget, name: str) -> QWidget:
    """Rôle typographique d'un libellé : title, heading, display, eyebrow, meta, mono, path, muted, subtle."""
    widget.setProperty("role", name)
    _repolish(widget)  # avant setFont : le polish de la feuille QSS réinitialise la police
    styles = {"path": "mono", "muted": "body", "subtle": "meta"}
    style = styles.get(name, name)
    if style in TOKENS["type"]:
        widget.setFont(font(style))
    return widget


def status(widget: QWidget, name: str = "none") -> QWidget:
    """Couleur de statut (success, warning, danger, info) ; toujours accompagnée d'un mot."""
    widget.setProperty("status", name)
    _repolish(widget)
    return widget


class WrapChoice(QWidget):
    """Case à cocher (ou radio) dont le libellé passe à la ligne au lieu de déborder à droite.

    S'emploie comme un QCheckBox : isChecked(), setChecked(), toggled, setText(), text().
    Radios : chaque WrapChoice a son propre parent, les regrouper dans un QButtonGroup (via .box).
    """

    def __init__(self, text: str = "", radio: bool = False, parent: QWidget | None = None):
        super().__init__(parent)
        self.box = QRadioButton() if radio else QCheckBox()
        self.box.setAccessibleName(text)
        self.label = QLabel(text)
        self.label.setWordWrap(True)
        self.label.setAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignTop)
        self.label.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred)
        self.label.setCursor(Qt.CursorShape.PointingHandCursor)
        self.label.setStyleSheet("background: transparent;")
        lay = QHBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(int(m("space-2.5")))
        lay.addWidget(self.box, 0, Qt.AlignmentFlag.AlignTop)
        lay.addWidget(self.label, 1)
        self.toggled = self.box.toggled
        self.setFocusProxy(self.box)

    def mousePressEvent(self, event):  # un clic sur le libellé coche la case
        if self.isEnabled() and event.button() == Qt.MouseButton.LeftButton:
            self.box.click()

    def isChecked(self) -> bool:
        return self.box.isChecked()

    def setChecked(self, value: bool) -> None:
        self.box.setChecked(value)

    def text(self) -> str:
        return self.label.text()

    def setText(self, text: str) -> None:
        self.label.setText(text)
        self.box.setAccessibleName(text)


class _FitHeight(QObject):
    def eventFilter(self, obj, event):
        if event.type() in (QEvent.Type.Show, QEvent.Type.Resize, QEvent.Type.LayoutRequest):
            lay = obj.layout()
            if lay is not None and lay.hasHeightForWidth():
                h = lay.totalHeightForWidth(obj.width())
                if h != obj.minimumHeight():
                    obj.setMinimumHeight(h)
        return False


def fit_height(window: QWidget) -> QWidget:
    """Hauteur minimale d'une fenêtre ou d'un dialogue recalculée selon sa largeur.

    Qt n'agrandit pas une fenêtre quand des libellés passent à la ligne (WrapChoice,
    QLabel.setWordWrap) : sans cela, les lignes se chevauchent ou sont rognées.
    """
    window._socle_fit = _FitHeight(window)
    window.installEventFilter(window._socle_fit)
    return window


def centrer(window: QWidget) -> QWidget:
    """Centre la fenêtre sur l'écran du pointeur, dans sa zone utile (hors barre des menus et Dock)."""
    ecran = QGuiApplication.screenAt(QCursor.pos()) or QGuiApplication.primaryScreen()
    zone = ecran.availableGeometry()
    cadre = window.frameGeometry()
    window.move(max(zone.left(), zone.center().x() - cadre.width() // 2),
                max(zone.top(), zone.center().y() - cadre.height() // 2))
    return window


class _Centrage(QObject):
    def eventFilter(self, obj, event):
        if (event.type() == QEvent.Type.Show and isinstance(obj, QWidget) and obj.isWindow()
                and obj.windowType() == Qt.WindowType.Window and not obj.property("socle_centre")):
            obj.setProperty("socle_centre", True)
            if not obj.testAttribute(Qt.WidgetAttribute.WA_Moved):  # une fenêtre placée par l'appli (splash) reste où elle est
                centrer(obj)
                recentrage = QTimer(obj)  # la barre de titre ne compte dans le cadre qu'une fois la fenêtre affichée
                recentrage.setSingleShot(True)
                recentrage.timeout.connect(lambda: centrer(obj))
                recentrage.start(0)
        return False


def traduire_qt(app: QApplication, langue: str) -> None:
    """Traduit ce que Qt écrit lui-même (menu de l'appli sur macOS, boutons standard) : à appeler avant de créer les menus."""
    traduction = QTranslator(app)
    if traduction.load(f"qtbase_{langue}", QLibraryInfo.path(QLibraryInfo.LibraryPath.TranslationsPath)):
        app.installTranslator(traduction)


# Nom de l'appli : sa lettre minuscule, à toute place (le « m » de mORTEX, le « s » de sKYCRASH, le « e » de
# CAREERDeSK…) prend la couleur de son logo partout où le nom est écrit dans un QLabel (titres, textes,
# dialogues, QMessageBox). Titres de fenêtre, menus et boutons natifs n'affichent pas de texte riche.
_brand: dict = {}
_QLABEL_SET_TEXT = QLabel.setText


def _brand_sub(fragment: str) -> str:
    for rx in _brand["res"]:
        fragment = rx.sub(lambda mt: "".join(_brand["span"].format(c) if c.islower() else c for c in mt.group()), fragment)
    return fragment


def brand_html(text: str) -> str:
    """Texte (brut ou riche) avec la lettre minuscule du nom de l'appli colorée, pour un widget en texte riche."""
    if not _brand or not any(rx.search(text) for rx in _brand["res"]):
        return text
    if re.search(r"<[A-Za-z!/]", text):
        return "".join(part if part.startswith("<") else _brand_sub(part) for part in re.split(r"(<[^>]*>)", text))
    return _brand_sub(html.escape(text, quote=False)).replace("\n", "<br>")


def _brand_label(label: QLabel, text: str) -> str:
    out = brand_html(text)
    if out != text:
        label.setTextFormat(Qt.TextFormat.RichText)
    return out


class _BrandFilter(QObject):
    def eventFilter(self, obj, event):
        if event.type() == QEvent.Type.Show and isinstance(obj, QLabel):
            text = obj.text()
            out = _brand_label(obj, text)
            if out != text:
                _QLABEL_SET_TEXT(obj, out)
        return False


def brand(app: QApplication, names, color: str) -> None:
    """Colore la lettre minuscule du nom de l'appli dans tous ses QLabel.

    names : nom de l'appli (« sKYCRASH ») ou liste de graphies (« fOMODSIM », « fOMOD_SIM ») ;
    color : couleur du logo. Couvre les textes posés par setText() et ceux des dialogues Qt
    (relus à l'affichage). Pour un autre widget à texte riche, passer par brand_html().
    """
    rxs = []
    for name in [names] if isinstance(names, str) else names:
        if any(c.islower() for c in name):  # pas dans un mot, un chemin, un identifiant de paquet ni une adresse
            rxs.append(re.compile(rf"(?<![\w.@/-]){re.escape(name)}(?![\w-])"))
    if not rxs:
        return
    _brand.update(res=rxs, span=f'<span style="color:{color}">{{}}</span>')

    def set_text(label, text):
        _QLABEL_SET_TEXT(label, _brand_label(label, text) if isinstance(text, str) else text)

    QLabel.setText = set_text
    app._socle_brand = _BrandFilter(app)
    app.installEventFilter(app._socle_brand)


def _icons_dir(theme: str) -> str:
    """Écrit les petites icônes SVG (coche, flèche) utilisées par la feuille QSS."""
    path = os.path.join(tempfile.gettempdir(), f"socle_qt_v{TOKENS['version']}_{theme}")
    os.makedirs(path, exist_ok=True)
    svgs = {
        "check.svg": f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><path d="M3.5 8.5l3 3 6-7" fill="none" stroke="{c("on-accent", theme)}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
        "chevron.svg": f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><path d="M4 6l4 4 4-4" fill="none" stroke="{c("text-muted", theme)}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    }
    for name, svg in svgs.items():
        with open(os.path.join(path, name), "w", encoding="utf-8") as fh:
            fh.write(svg)
    return path.replace("\\", "/")


def _type_rules() -> str:
    """Tailles et graisses en QSS : Qt réinitialise la graisse d'un setFont() au polish."""
    t = TOKENS["type"]

    mono = QFontDatabase.systemFont(QFontDatabase.SystemFont.FixedFont).family()

    def rule(selector: str, style: str) -> str:
        family = f' font-family: "{mono}";' if t[style]["family"] == "mono" else ""
        return f"{selector} {{ font-size: {t[style]['size']}px; font-weight: {t[style]['weight']};{family} }}"

    rules = [rule(f'QLabel[role="{name}"]', name) for name in ("display", "heading", "title", "eyebrow", "meta", "mono")]
    rules += [
        rule('QLabel[role="path"]', "mono"),
        rule('QLabel[role="subtle"]', "meta"),
        rule('QPushButton[variant="primary"], QPushButton[variant="flow"]', "button-flow"),
        rule('QPushButton[variant="action"]', "button-lg"),
        rule("QPushButton, QToolButton", "button"),
    ]
    # Les règles génériques d'abord, les variantes ensuite (même spécificité : la dernière l'emporte).
    return "\n".join([rules[-1]] + rules[:-1])


_BASE_SELECTORS = ("QToolTip", "QScrollBar", "QScrollArea", "QMenu", "QDialog", "QMessageBox",
                   "QComboBox", "QCheckBox", "QRadioButton", "QTabWidget", "QTabBar")


def _minimal(sheet: str) -> str:
    """Ne garde que les règles sûres pour une appli qui a déjà sa propre feuille de style :
    infobulles, barres de défilement, menus, dialogues, et règles ciblées par propriété
    (role, variant, status, panel) qui ne s'appliquent qu'aux widgets marqués."""
    import re
    sheet = re.sub(r"/\*.*?\*/", "", sheet, flags=re.S)
    kept = []
    for rule in sheet.split("}"):
        if "{" not in rule:
            continue
        selector = rule.split("{", 1)[0].strip()
        if "[" in selector or selector.startswith(_BASE_SELECTORS):
            kept.append(rule.strip() + " }")
    return "\n".join(kept) + "\n"


def qss(theme: str = "dark", full: bool = True) -> str:
    """Feuille de style globale Socle pour le thème donné (full=False : version minimale)."""
    sheet = _qss(theme)
    return sheet if full else _minimal(sheet)


def _qss(theme: str) -> str:
    k = TOKENS["colors"][theme]
    r, rmd, rlg = m("radius"), m("radius-md"), m("radius-lg")
    icons = _icons_dir(theme)
    return f"""
QWidget {{ background-color: {k['bg']}; color: {k['text']}; font-size: {TOKENS['type']['body']['size']}px; selection-background-color: {k['accent-fill']}; selection-color: {k['on-accent-fill']}; }}
QLabel {{ background: transparent; }}
QToolTip {{ background-color: {k['bubble-help']}; color: {k['on-bubble']}; border: 0; border-radius: 6px; padding: 8px 10px; }}

/* Panneaux */
QFrame[panel="true"] {{ background-color: {k['surface']}; border: 1px solid {k['border']}; border-radius: {rmd}px; }}
QFrame[panel="raised"], QFrame#HeaderBar {{ background-color: {k['surface-raised']}; border: 1px solid {k['border']}; border-radius: {rmd}px; }}
QFrame[panel="sunken"] {{ background-color: {k['bg-sunken']}; border: 1px solid {k['border']}; border-radius: {r}px; }}
QFrame[panel] QLabel, QFrame#HeaderBar QLabel {{ background: transparent; }}

/* Typographie */
QLabel[role="display"], QLabel[role="heading"], QLabel[role="title"] {{ color: {k['text-strong']}; }}
QLabel[role="eyebrow"], QLabel[role="subtle"], QLabel[role="meta"] {{ color: {k['text-subtle']}; }}
QLabel[role="muted"] {{ color: {k['text-muted']}; }}
QLabel[role="mono"] {{ color: {k['text-muted']}; }}
QLabel[role="path"] {{ color: {k['accent-text']}; }}
QLabel[status="success"] {{ color: {k['success']}; }}
QLabel[status="warning"] {{ color: {k['warning']}; }}
QLabel[status="danger"] {{ color: {k['danger']}; }}
QLabel[status="info"] {{ color: {k['accent-text']}; }}

/* Boutons — secondaire par défaut */
QPushButton, QToolButton {{
    background-color: {k['control']}; color: {k['text-strong']};
    border: 1px solid {k['control']}; border-radius: {r}px;
    min-height: {m('size-control') - 2}px; padding: 0 {m('space-3')}px;
}}
QPushButton:hover, QToolButton:hover {{ background-color: {k['control-hover']}; border-color: {k['control-hover']}; }}
QPushButton:pressed, QToolButton:pressed {{ background-color: {k['control-pressed']}; border-color: {k['control-pressed']}; }}
QPushButton:focus, QToolButton:focus {{ border-color: {k['focus-ring']}; }}
QPushButton:disabled, QToolButton:disabled {{ color: {k['text-disabled']}; background-color: {k['control']}; border-color: {k['control']}; }}
QPushButton[variant="tertiary"] {{ background-color: {k['control-strong']}; border-color: {k['control-strong']}; }}
QPushButton[variant="primary"], QPushButton[variant="flow"] {{ min-height: {m('size-control-lg') - 2}px; padding: 0 {m('space-4')}px; }}
QPushButton[variant="primary"] {{ background-color: {k['accent-fill']}; color: {k['on-accent-fill']}; border-color: {k['accent-fill']}; }}
QPushButton[variant="primary"]:hover {{ background-color: {k['accent-fill-hover']}; border-color: {k['accent-fill-hover']}; }}
QPushButton[variant="primary"]:pressed {{ background-color: {k['accent-fill-pressed']}; }}
QPushButton[variant="primary"]:focus {{ border-color: {k['focus-ring']}; }}
QPushButton[variant="primary"]:disabled {{ background-color: {k['control']}; color: {k['text-disabled']}; border-color: {k['control']}; }}
QPushButton[variant="action"] {{ min-height: {m('size-cta') - 2}px; padding: 0 {m('space-4')}px; background-color: {k['action']}; color: {k['on-action']}; border-color: {k['action']}; }}
QPushButton[variant="action"]:hover {{ background-color: {k['action-hover']}; border-color: {k['action-hover']}; }}
QPushButton[variant="action"]:pressed {{ background-color: {k['action-pressed']}; }}
QPushButton[variant="action"]:focus {{ border-color: {k['focus-ring']}; }}
QPushButton[variant="action"]:disabled {{ background-color: {k['control']}; color: {k['text-disabled']}; border-color: {k['control']}; }}
QPushButton[variant="picker"] {{ background-color: {k['bg-inset']}; border: 1px dashed {k['border-strong']}; border-radius: {rlg}px; text-align: left; padding: {m('space-3')}px; }}
QPushButton[variant="picker"]:hover {{ border-color: {k['accent']}; background-color: {k['surface-hover']}; }}
QPushButton[variant="picker"][filled="true"] {{ border-style: solid; border-color: {k['control']}; }}
QPushButton[variant="picker"][filled="true"]:hover {{ border-color: {k['accent']}; }}
QPushButton[variant="picker"]:disabled {{ color: {k['text-disabled']}; border-color: {k['control']}; }}
QPushButton[variant="picker"] QLabel {{ background: transparent; }}

/* Champs */
QLineEdit, QPlainTextEdit, QTextEdit, QSpinBox, QComboBox {{
    background-color: {k['bg-sunken']}; color: {k['text-strong']};
    border: 1px solid transparent; border-radius: {m('radius-field')}px; padding: 0 {m('space-3')}px;
}}
QLineEdit, QSpinBox, QComboBox {{ min-height: {m('size-control-lg') - 2}px; }}
QPlainTextEdit, QTextEdit {{ padding: {m('space-3')}px; }}
QLineEdit:focus, QPlainTextEdit:focus, QTextEdit:focus, QSpinBox:focus, QComboBox:focus {{ border-color: {k['focus-ring']}; }}
QLineEdit:disabled, QComboBox:disabled {{ color: {k['text-disabled']}; }}
QComboBox {{ padding-right: {m('space-6') + m('space-1')}px; }}
QComboBox::drop-down, QComboBox::drop-down:editable {{ subcontrol-origin: padding; subcontrol-position: center right; width: {m('space-6')}px; border: none; background: transparent; }}
QComboBox::down-arrow, QComboBox::down-arrow:on {{ image: url({icons}/chevron.svg); width: 12px; height: 12px; }}
QComboBox QAbstractItemView {{ background-color: {k['surface']}; color: {k['text']}; border: 1px solid {k['border']}; outline: none; padding: {m('space-1')}px; selection-background-color: {k['surface-selected']}; selection-color: {k['text-strong']}; }}
QComboBox QAbstractItemView::item {{ min-height: {m('size-control') - 8}px; padding: 0 {m('space-2')}px; border-radius: {r}px; }}

/* Choix */
QCheckBox, QRadioButton {{ background: transparent; spacing: {m('space-2.5')}px; color: {k['text']}; }}
QCheckBox::indicator, QRadioButton::indicator {{ width: {m('size-choice') - 3}px; height: {m('size-choice') - 3}px; border: 1.5px solid {k['border-control']}; background-color: {k['surface']}; }}
QCheckBox::indicator {{ border-radius: {r}px; }}
QRadioButton::indicator {{ border-radius: {m('size-choice') // 2}px; }}
QCheckBox::indicator:checked {{ background-color: {k['accent']}; border-color: {k['accent']}; image: url({icons}/check.svg); }}
QRadioButton::indicator:checked {{ border-color: {k['accent']}; background-color: qradialgradient(cx:0.5, cy:0.5, radius:0.5, fx:0.5, fy:0.5, stop:0 {k['on-accent']}, stop:0.38 {k['on-accent']}, stop:0.42 {k['accent']}, stop:1 {k['accent']}); }}

/* Progression */
QProgressBar {{
    background-color: {k['bg-sunken']}; color: {k['text']};
    border: 1px solid {k['border']}; border-radius: {r}px; text-align: center;
    min-height: {m('size-control') - 2}px;
}}
QProgressBar::chunk {{ background-color: {k['accent-fill']}; border-radius: {r - 1}px; }}
QProgressBar[status="success"] {{ color: {k['success-soft']}; border-color: {k['success-border']}; }}
QProgressBar[status="success"]::chunk {{ background-color: {k['success-bg']}; }}
QProgressBar[status="danger"] {{ color: {k['danger-soft']}; border-color: {k['danger-border']}; background-color: {k['danger-bg']}; }}
QProgressBar[status="danger"]::chunk {{ background-color: {k['danger-bg']}; }}

/* Listes, arbres, tableaux */
QListView, QTreeView, QTableView {{ background-color: {k['bg-sunken']}; border: 1px solid {k['border']}; border-radius: {r}px; outline: none; }}
QListView::item {{ padding: {m('space-1')}px {m('space-2')}px; border-radius: {r}px; }}
QTreeView::item {{ padding: {m('space-1')}px {m('space-1')}px; }}
QListView::item:hover, QTreeView::item:hover {{ background-color: {k['surface-hover']}; }}
QListView::item:selected, QTreeView::item:selected, QTableView::item:selected {{ background-color: {k['surface-selected']}; color: {k['text-strong']}; }}
QHeaderView::section {{ background-color: {k['surface-raised']}; color: {k['text-muted']}; border: none; border-bottom: 1px solid {k['border']}; padding: {m('space-1')}px {m('space-2')}px; }}

/* Onglets */
QTabWidget::pane {{ border: none; border-top: 1px solid {k['border']}; }}
QTabBar::tab {{ background: transparent; color: {k['text-subtle']}; border: none; border-bottom: 2px solid transparent; padding: 0 {m('space-3')}px {m('space-2')}px; }}
QTabBar::tab:hover {{ color: {k['text']}; }}
QTabBar::tab:selected {{ color: {k['text-strong']}; border-bottom-color: {k['accent']}; }}

/* Défilement et séparateurs */
QScrollArea {{ background: transparent; border: none; }}
QScrollBar:vertical {{ background: transparent; width: {m('size-scrollbar')}px; margin: 0; }}
QScrollBar:horizontal {{ background: transparent; height: {m('size-scrollbar')}px; margin: 0; }}
QScrollBar::handle {{ background-color: {k['control']}; border-radius: {m('size-scrollbar') // 2}px; min-height: 24px; min-width: 24px; }}
QScrollBar::handle:hover {{ background-color: {k['control-strong']}; }}
QScrollBar::add-line, QScrollBar::sub-line, QScrollBar::add-page, QScrollBar::sub-page {{ width: 0; height: 0; background: none; }}
QSplitter::handle {{ background-color: transparent; }}
QSplitter::handle:horizontal {{ width: 8px; }}
QSplitter::handle:vertical {{ height: 8px; }}
QSplitter::handle:hover {{ background-color: {k['accent']}; }}

/* Menus et dialogues */
QMenu {{ background-color: {k['surface']}; border: 1px solid {k['border']}; border-radius: {rmd}px; padding: 4px; }}
QMenu::item {{ padding: 4px 16px; border-radius: {r}px; }}
QMenu::item:selected {{ background-color: {k['surface-hover']}; color: {k['text-strong']}; }}
QMenu::separator {{ height: 1px; background: {k['border']}; margin: 4px 8px; }}
QDialog, QMessageBox {{ background-color: {k['surface']}; }}
QMessageBox QLabel {{ color: {k['text']}; }}

/* Typographie (tailles et graisses) */
""" + _type_rules() + "\n"


def palette(theme: str = "dark") -> QPalette:
    """Palette Qt alignée sur Socle (pour les éléments que la feuille QSS n'atteint pas)."""
    k = TOKENS["colors"][theme]
    p = QPalette()
    roles = {
        QPalette.ColorRole.Window: k["bg"],
        QPalette.ColorRole.WindowText: k["text"],
        QPalette.ColorRole.Base: k["bg-sunken"],
        QPalette.ColorRole.AlternateBase: k["surface"],
        QPalette.ColorRole.Text: k["text"],
        QPalette.ColorRole.Button: k["control"],
        QPalette.ColorRole.ButtonText: k["text-strong"],
        QPalette.ColorRole.Highlight: k["accent-fill"],
        QPalette.ColorRole.HighlightedText: k["on-accent-fill"],
        QPalette.ColorRole.ToolTipBase: k["bubble-help"],
        QPalette.ColorRole.ToolTipText: k["on-bubble"],
        QPalette.ColorRole.PlaceholderText: k["text-subtle"],
        QPalette.ColorRole.Link: k["accent-text"],
    }
    for r, value in roles.items():
        p.setColor(r, QColor(value))
    for r in (QPalette.ColorRole.WindowText, QPalette.ColorRole.Text, QPalette.ColorRole.ButtonText):
        p.setColor(QPalette.ColorGroup.Disabled, r, QColor(k["text-disabled"]))
    return p


def apply(app: QApplication, theme: str = "dark", full: bool = True) -> None:
    """Applique Socle à toute l'application : police système 12px, palette et feuille QSS.

    full=False pour une appli qui garde sa propre feuille de style (couleurs déjà Socle) :
    seules les règles de base (défilement, infobulles, menus, dialogues) sont ajoutées.
    """
    global _theme, _full
    _theme, _full = theme, full
    app.setFont(font("body"))
    app.setPalette(palette(theme))
    app.setStyleSheet(qss(theme, full))
    if not hasattr(app, "_socle_centrage"):
        app._socle_centrage = _Centrage(app)
        app.installEventFilter(app._socle_centrage)

