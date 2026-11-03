"""Langue de l'interface des applis Skyrim Tools (Python) : détection d'après le Mac et menu « Langue ».

FICHIER COMMUN : la source est _tools/shared/lang_menu.py, recopiée dans chaque appli par _tools/sync_shared.sh.
Ne pas le modifier dans une appli. Tests : _tools/shared/test_lang_menu.py.

- Choix mémorisé : « auto » (défaut) ou un code fr/en/es/it. « auto » suit la première langue préférée du Mac prise
  en charge, sinon l'anglais.
- Menu « Langue » de la barre de menus : « Automatique (système) », puis Français, English, Español, Italiano, coche
  sur le choix courant. Le menu lui-même suit la langue active.
- PyQt6 : install_qt(window, get_choice, set_choice, on_change).
- pywebview : web_menu(...) fournit le Menu à ajouter à webview.start(menu=…) ; les coches et les libellés sont
  ensuite tenus à jour par AppKit (PyObjC, fourni avec pywebview).
- Essai dans une autre langue sans toucher au Mac : lancer l'appli avec les arguments `-AppleLanguages "(en)"`.
"""
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

AUTO = "auto"
LANGS = {"fr": "Français", "en": "English", "es": "Español", "it": "Italiano"}  # noms dans leur propre langue
TEXTS = {
    "fr": {"menu": "Langue", "auto": "Automatique (système)"},
    "en": {"menu": "Language", "auto": "Automatic (system)"},
    "es": {"menu": "Idioma", "auto": "Automático (sistema)"},
    "it": {"menu": "Lingua", "auto": "Automatica (sistema)"},
}


def pick(preferred) -> str:
    """Première langue prise en charge parmi les langues préférées (« fr-FR », « en_US »…), sinon l'anglais."""
    for code in preferred or ():
        code = str(code or "")[:2].lower()
        if code in LANGS:
            return code
    return "en"


def preferred_languages() -> list[str]:
    """Langues préférées du Mac, arguments -AppleLanguages compris (Foundation, puis Qt, puis `defaults`)."""
    try:
        from Foundation import NSLocale
        return [str(x) for x in NSLocale.preferredLanguages()]
    except Exception:
        pass
    try:
        from PyQt6.QtCore import QLocale
        return list(QLocale.system().uiLanguages())
    except Exception:
        pass
    try:
        out = subprocess.run(["defaults", "read", "-g", "AppleLanguages"], capture_output=True, text=True, timeout=2).stdout
        return re.findall(r'"?([a-z]{2}[-_A-Za-z]*)', out)
    except (OSError, subprocess.SubprocessError):
        return []


def system_lang() -> str:
    return pick(preferred_languages())


def normalize_choice(choice) -> str:
    choice = str(choice or "").strip()
    return choice if choice in LANGS else AUTO


def resolve(choice) -> str:
    """Langue à afficher pour un choix mémorisé."""
    choice = normalize_choice(choice)
    return system_lang() if choice == AUTO else choice


def texts(lang) -> dict:
    return TEXTS.get(lang, TEXTS["en"])


def entries(lang) -> list[tuple[str, str]]:
    """(valeur, libellé) des entrées du menu ; None = séparateur."""
    return [(AUTO, texts(lang)["auto"]), None, *LANGS.items()]


class FileStore:
    """Choix mémorisé dans ~/Library/Application Support/<appli>/language.json (applis sans QSettings)."""

    def __init__(self, app_name: str, base: Path | None = None):
        self.path = (base or Path.home() / "Library" / "Application Support" / app_name) / "language.json"

    def get(self) -> str:
        try:
            return normalize_choice(json.loads(self.path.read_text(encoding="utf-8")).get("language"))
        except (OSError, ValueError, AttributeError):
            return AUTO

    def set(self, choice: str) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps({"language": normalize_choice(choice)}), encoding="utf-8")


# --------------------------------------------------------------------------- PyQt6

def install_qt(window, get_choice, set_choice, on_change, before_title: str | None = None):
    """Ajoute le menu « Langue » à la barre de menus de `window` (QMainWindow, QWidget ou QMenuBar).
    get_choice() -> « auto » ou code ; set_choice(choix) le mémorise ; on_change(code) applique la langue.
    before_title : titre d'un menu existant devant lequel le placer (sinon à la fin). Renvoie le QMenu."""
    from PyQt6.QtGui import QAction, QActionGroup
    from PyQt6.QtWidgets import QMenu, QMenuBar

    if isinstance(window, QMenuBar):
        bar = window
    elif hasattr(window, "menuBar"):
        bar = window.menuBar()
    else:  # QWidget : barre de menus globale de macOS, partagée avec updater.start_qt (attribut menu_bar)
        bar = getattr(window, "menu_bar", None) or QMenuBar()
        window.menu_bar = bar
    menu = QMenu(bar)
    group = QActionGroup(menu)
    acts = {}
    for entry in entries("en"):
        if entry is None:
            menu.addSeparator()
            continue
        act = QAction(menu)
        act.setCheckable(True)
        act.setData(entry[0])
        act.setMenuRole(QAction.MenuRole.NoRole)  # macOS ne doit pas le déplacer dans le menu de l'appli
        group.addAction(act)
        menu.addAction(act)
        acts[entry[0]] = act

    def refresh():
        lang = resolve(get_choice())
        menu.setTitle(texts(lang)["menu"])
        acts[AUTO].setText(texts(lang)["auto"])
        for code, name in LANGS.items():
            acts[code].setText(name)
        acts[normalize_choice(get_choice())].setChecked(True)

    def chosen(act):
        set_choice(act.data())
        on_change(resolve(act.data()))
        refresh()

    group.triggered.connect(chosen)
    target = next((a for a in bar.actions() if before_title and a.text() == before_title), None)
    if target is not None:
        bar.insertMenu(target, menu)
    else:
        bar.addMenu(menu)
    menu.refresh = refresh
    refresh()
    return menu


# --------------------------------------------------------------------------- pywebview

def web_menu(get_choice, set_choice, on_change, lang: str | None = None):
    """Menu « Langue » pour webview.start(menu=[…]). on_change(code) est appelé hors du fil principal (pywebview) ;
    il transmet la langue à l'interface (window.evaluate_js). Coches et libellés : mis à jour par AppKit."""
    from webview.menu import Menu, MenuAction, MenuSeparator

    lang = lang or resolve(get_choice())
    title = texts(lang)["menu"]
    state = {"title": title}

    def choose(value):
        def run():
            set_choice(value)
            new = resolve(value)
            on_change(new)
            state["title"] = _cocoa_refresh(state["title"], new, normalize_choice(value))
        return run

    items = [MenuSeparator() if e is None else MenuAction(e[1], choose(e[0])) for e in entries(lang)]
    menu = Menu(title, items)
    menu._lang_state = state
    return menu


def cocoa_mark(get_choice, title: str | None = None) -> None:
    """Coche le choix courant (à appeler une fois la fenêtre affichée)."""
    choice = normalize_choice(get_choice())
    lang = resolve(choice)
    _cocoa_refresh(title or texts(lang)["menu"], lang, choice)


def _cocoa_refresh(old_title: str, lang: str, choice: str) -> str:
    """Retitre le menu « Langue » et coche `choice`, sur le fil principal. Renvoie le nouveau titre."""
    new_title = texts(lang)["menu"]
    try:
        from AppKit import NSApp
        from PyObjCTools import AppHelper
    except Exception:
        return old_title

    def apply():
        main = NSApp.mainMenu() if NSApp else None
        if main is None:
            return
        idx = main.indexOfItemWithTitle_(old_title)
        if idx < 0:
            return
        top = main.itemAtIndex_(idx)
        sub = top.submenu()
        top.setTitle_(new_title)
        if sub is not None:
            sub.setTitle_(new_title)
            values = [e and e[0] for e in entries(lang)]
            labels = [e and e[1] for e in entries(lang)]
            for i in range(min(sub.numberOfItems(), len(values))):
                item = sub.itemAtIndex_(i)
                if values[i] is None:
                    continue
                item.setTitle_(labels[i])
                item.setState_(1 if values[i] == choice else 0)

    AppHelper.callAfter(apply)
    return new_title
