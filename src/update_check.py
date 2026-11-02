"""Avertit qu'une nouvelle version existe (dernière release GitHub), sans rien télécharger ni installer.

Fichier commun aux applis Skyrim Tools : la source est _tools/shared/update_check.py, recopiée dans chaque
appli par _tools/sync_shared.sh. Ne pas le modifier dans une appli.

- Au plus une requête par jour (api.github.com), seulement dans l'appli compilée (version lue dans Info.plist).
- « Ignorer cette version » n'affiche plus rien jusqu'à la version suivante.
- Le bouton ouvre la page GitHub Releases de l'outil (releases/latest), où se trouve le téléchargement notarisé.
"""
from __future__ import annotations

import json
import os
import plistlib
import re
import sys
import threading
import time
import urllib.request
import webbrowser
from pathlib import Path

OWNER = "starbudweiser"
DAY = 24 * 3600

TEXTS = {
    "fr": {"title": "Nouvelle version", "body": "{app} {new} est disponible (vous avez la {cur}).",
           "open": "Ouvrir la page de téléchargement", "later": "Plus tard", "skip": "Ignorer cette version"},
    "en": {"title": "New version", "body": "{app} {new} is available (you have {cur}).",
           "open": "Open the download page", "later": "Later", "skip": "Skip this version"},
    "es": {"title": "Nueva versión", "body": "{app} {new} está disponible (tienes la {cur}).",
           "open": "Abrir la página de descarga", "later": "Más tarde", "skip": "Omitir esta versión"},
    "it": {"title": "Nuova versione", "body": "{app} {new} è disponibile (hai la {cur}).",
           "open": "Apri la pagina di download", "later": "Più tardi", "skip": "Ignora questa versione"},
}


def release_page(repo: str) -> str:
    return f"https://github.com/{OWNER}/{repo}/releases/latest"


def texts(lang: str) -> dict:
    return TEXTS.get((lang or "")[:2].lower(), TEXTS["en"])


def parse_version(v: str) -> tuple:
    nums = re.findall(r"\d+", str(v or "").split("-")[0])
    return tuple(int(n) for n in nums[:3]) + (0,) * (3 - len(nums[:3])) if nums else ()


def is_newer(latest: str, current: str) -> bool:
    a, b = parse_version(latest), parse_version(current)
    return bool(a and b and a > b)


def bundle_info() -> dict:
    """Info.plist de l'appli compilée ({} en développement)."""
    exe = Path(sys.executable).resolve()
    plist = exe.parent.parent / "Info.plist"
    if exe.parent.name != "MacOS" or not plist.is_file():
        return {}
    try:
        with plist.open("rb") as f:
            return plistlib.load(f)
    except (OSError, plistlib.InvalidFileException):
        return {}


class State:
    """Dernière vérification et version ignorée, dans ~/Library/Caches/<bundle id>/update_check.json."""

    def __init__(self, bundle_id: str, base: Path | None = None):
        root = base or Path.home() / "Library" / "Caches"
        self.path = root / (bundle_id or "skyrim-tools") / "update_check.json"

    def load(self) -> dict:
        try:
            return json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return {}

    def save(self, data: dict) -> None:
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            self.path.write_text(json.dumps(data), encoding="utf-8")
        except OSError:
            pass


def fetch_latest(repo: str, timeout: float = 6.0) -> str:
    req = urllib.request.Request(f"https://api.github.com/repos/{OWNER}/{repo}/releases/latest",
                                 headers={"Accept": "application/vnd.github+json", "User-Agent": f"{repo}-update-check"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return str(json.load(r).get("tag_name") or "")


def check(repo: str, current: str, state: State, now: float | None = None, fetch=fetch_latest) -> str | None:
    """Version plus récente à proposer, ou None (déjà vérifié aujourd'hui, à jour, ignorée, hors ligne)."""
    now = time.time() if now is None else now
    data = state.load()
    latest = data.get("latest", "")
    if "checked" not in data or now - float(data["checked"]) >= DAY:
        try:
            latest = fetch(repo)
        except (OSError, ValueError):
            return None  # hors ligne ou GitHub indisponible : on réessaiera au prochain lancement
        data.update(checked=now, latest=latest)
        state.save(data)
    if latest and is_newer(latest, current) and data.get("skipped") != latest:
        return latest.lstrip("vV")
    return None


def skip(state: State, version: str) -> None:
    data = state.load()
    data["skipped"] = "v" + version.lstrip("vV")
    state.save(data)


def _system_lang() -> str:
    try:
        import subprocess
        out = subprocess.run(["defaults", "read", "-g", "AppleLanguages"], capture_output=True, text=True, timeout=2).stdout
        m = re.search(r'"?([a-z]{2})', out)
        return m.group(1) if m else "en"
    except (OSError, subprocess.SubprocessError):
        return "en"


def _prepare(repo: str, lang):
    info = bundle_info()
    current = info.get("CFBundleShortVersionString", "")
    if not current or os.environ.get("SKYRIM_TOOLS_NO_UPDATE_CHECK"):
        return None
    state = State(info.get("CFBundleIdentifier", repo))
    name = info.get("CFBundleName", repo)
    return current, state, name, (lambda: (lang() if callable(lang) else lang) or _system_lang())


def start_qt(parent, repo: str, page: str | None = None, lang=None) -> None:
    """PyQt6 : vérification en arrière-plan, puis fenêtre de choix dans le fil de l'interface."""
    prep = _prepare(repo, lang)
    if not prep:
        return
    current, state, name, get_lang = prep
    # import dynamique : PyInstaller n'embarque pas PyQt6 dans les applis pywebview qui n'appellent pas start_qt
    import importlib
    QObject, pyqtSignal = (getattr(importlib.import_module("PyQt6.QtCore"), n) for n in ("QObject", "pyqtSignal"))
    QMessageBox = importlib.import_module("PyQt6.QtWidgets").QMessageBox

    class _Relay(QObject):
        found = pyqtSignal(str)

    relay = _Relay(parent)

    def ask(new: str) -> None:
        t = texts(get_lang())
        box = QMessageBox(parent)
        box.setIcon(QMessageBox.Icon.Information)
        box.setWindowTitle(t["title"])
        box.setText(t["body"].format(app=name, new=new, cur=current))
        open_b = box.addButton(t["open"], QMessageBox.ButtonRole.AcceptRole)
        skip_b = box.addButton(t["skip"], QMessageBox.ButtonRole.DestructiveRole)
        box.addButton(t["later"], QMessageBox.ButtonRole.RejectRole)
        box.exec()
        if box.clickedButton() is open_b:
            webbrowser.open(page or release_page(repo))
        elif box.clickedButton() is skip_b:
            skip(state, new)

    relay.found.connect(ask)
    parent._update_relay = relay  # garde l'objet en vie

    def run() -> None:
        new = check(repo, current, state)
        if new:
            relay.found.emit(new)

    threading.Thread(target=run, daemon=True).start()


def start_webview(window, repo: str, page: str | None = None, lang=None) -> None:
    """pywebview : vérification en arrière-plan, puis boîte de confirmation de la fenêtre."""
    prep = _prepare(repo, lang)
    if not prep:
        return
    current, state, name, get_lang = prep

    def run() -> None:
        new = check(repo, current, state)
        if not new:
            return
        t = texts(get_lang())
        msg = t["body"].format(app=name, new=new, cur=current) + f"\n\n{t['open']} ?"
        if window.create_confirmation_dialog(t["title"], msg):  # « Annuler » = plus tard
            webbrowser.open(page or release_page(repo))

    threading.Thread(target=run, daemon=True).start()
