"""Mise à jour automatique des applis Skyrim Tools (Python). Remplace update_check.py.

FICHIER COMMUN : la source est _tools/shared/updater.py, recopiée dans chaque appli par _tools/sync_shared.sh.
Ne pas le modifier dans une appli. Tests : _tools/shared/test_updater.py.

Fonctionnement
- Une requête par jour au plus (GET /repos/starbudweiser/<dépôt>/releases), plus la vérification manuelle du menu.
- Les releases publiées (ni brouillon ni préversion) plus récentes que la version installée sont listées ; leurs notes
  (balises <!-- notes:xx --> écrites par _tools/release_notes.py) sont affichées dans la langue de l'appli, de la plus
  récente à la plus ancienne, avant toute installation.
- « Installer et relancer » : téléchargement (api.github.com et *.githubusercontent.com seulement), SHA-256 du .sha256,
  décompression, contrôle de l'identifiant, de la version annoncée, de la signature (codesign --strict --deep), du
  Team ID Developer ID et de l'exigence de signature de l'appli en cours, du ticket de notarisation (stapler).
  Puis un script à part attend la fin de l'appli, garde l'ancienne copie, remplace par ditto, la remet en cas d'échec
  et relance.
- Dossier non inscriptible : droits demandés par la fenêtre système (osascript) ; refus = page de téléchargement.
- Désactivation pour les essais : variable SKYRIM_TOOLS_NO_UPDATE_CHECK (vérification automatique seulement).
- Édition de test : la clé SkyrimUpdateAcceptBundleID de l'Info.plist (réglage de build, donc signé avec l'appli)
  autorise cet identifiant de test à recevoir le paquet officiel. Une appli signée localement (sans Team ID) reçoit
  aussi le paquet officiel : seuls le Team ID du paquet, sa notarisation et son identifiant comptent alors.

Interfaces : start_qt(fenêtre, dépôt, lang) pour PyQt6, start_webview(fenêtre, dépôt, lang) pour pywebview.
Chacune renvoie un contrôleur dont .check_manual() est à brancher sur le menu « Rechercher les mises à jour… ».
"""
from __future__ import annotations

import hashlib
import html
import importlib
import json
import os
import plistlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
import webbrowser
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import urlparse

OWNER = "starbudweiser"
TEAM_ID = "35KLMK53PN"
API_HOST = "api.github.com"
DOWNLOAD_SUFFIX = ".githubusercontent.com"
ACCEPT_KEY = "SkyrimUpdateAcceptBundleID"
DAY = 24 * 3600
LANGS = ("fr", "en", "es", "it")

TEXTS = {
    "fr": {
        "menu": "Rechercher les mises à jour…", "title": "Nouvelle version",
        "body": "{app} {new} est disponible (vous avez la {cur}).", "notes": "Nouveautés depuis la {cur}",
        "no_notes": "Aucune note de version pour cette mise à jour.",
        "install": "Installer et relancer", "later": "Plus tard", "skip": "Ignorer cette version",
        "downloading": "Téléchargement…", "verifying": "Vérification du paquet…", "installing": "Installation, l'appli va se relancer…",
        "uptodate_title": "À jour", "uptodate": "{app} {cur} est la dernière version.",
        "err_net": "Impossible de joindre GitHub. Réessayez plus tard.",
        "err_verify": "Le paquet téléchargé n'a pas passé les contrôles de sécurité. Rien n'a été installé.",
        "err_install": "L'installation a échoué. L'ancienne version est conservée.",
        "err_denied": "Droits refusés. Vous pouvez télécharger la mise à jour à la main.",
        "open_page": "Ouvrir la page de téléchargement", "close": "Fermer",
    },
    "en": {
        "menu": "Check for Updates…", "title": "New version",
        "body": "{app} {new} is available (you have {cur}).", "notes": "What's new since {cur}",
        "no_notes": "No release notes for this update.",
        "install": "Install and relaunch", "later": "Later", "skip": "Skip this version",
        "downloading": "Downloading…", "verifying": "Verifying the package…", "installing": "Installing, the app will relaunch…",
        "uptodate_title": "Up to date", "uptodate": "{app} {cur} is the latest version.",
        "err_net": "Could not reach GitHub. Try again later.",
        "err_verify": "The downloaded package failed the security checks. Nothing was installed.",
        "err_install": "The installation failed. The previous version is kept.",
        "err_denied": "Permission denied. You can download the update by hand.",
        "open_page": "Open the download page", "close": "Close",
    },
    "es": {
        "menu": "Buscar actualizaciones…", "title": "Nueva versión",
        "body": "{app} {new} está disponible (tienes la {cur}).", "notes": "Novedades desde la {cur}",
        "no_notes": "No hay notas de versión para esta actualización.",
        "install": "Instalar y reiniciar", "later": "Más tarde", "skip": "Omitir esta versión",
        "downloading": "Descargando…", "verifying": "Verificando el paquete…", "installing": "Instalando, la app se reiniciará…",
        "uptodate_title": "Al día", "uptodate": "{app} {cur} es la última versión.",
        "err_net": "No se puede contactar con GitHub. Inténtalo más tarde.",
        "err_verify": "El paquete descargado no superó los controles de seguridad. No se instaló nada.",
        "err_install": "La instalación falló. Se conserva la versión anterior.",
        "err_denied": "Permiso denegado. Puedes descargar la actualización a mano.",
        "open_page": "Abrir la página de descarga", "close": "Cerrar",
    },
    "it": {
        "menu": "Verifica aggiornamenti…", "title": "Nuova versione",
        "body": "{app} {new} è disponibile (hai la {cur}).", "notes": "Novità dalla {cur}",
        "no_notes": "Nessuna nota di versione per questo aggiornamento.",
        "install": "Installa e riavvia", "later": "Più tardi", "skip": "Ignora questa versione",
        "downloading": "Download in corso…", "verifying": "Verifica del pacchetto…", "installing": "Installazione, l'app si riavvierà…",
        "uptodate_title": "Aggiornata", "uptodate": "{app} {cur} è l'ultima versione.",
        "err_net": "Impossibile raggiungere GitHub. Riprova più tardi.",
        "err_verify": "Il pacchetto scaricato non ha superato i controlli di sicurezza. Non è stato installato nulla.",
        "err_install": "L'installazione non è riuscita. La versione precedente è conservata.",
        "err_denied": "Permesso negato. Puoi scaricare l'aggiornamento a mano.",
        "open_page": "Apri la pagina di download", "close": "Chiudi",
    },
}


def normalize_lang(lang: str | None) -> str:
    code = (lang or "")[:2].lower()
    return code if code in LANGS else "en"


def texts(lang: str | None) -> dict:
    return TEXTS[normalize_lang(lang)]


def system_lang() -> str:
    try:
        out = subprocess.run(["defaults", "read", "-g", "AppleLanguages"], capture_output=True, text=True, timeout=2).stdout
        m = re.search(r'"?([a-z]{2})', out)
        return normalize_lang(m.group(1)) if m else "en"
    except (OSError, subprocess.SubprocessError):
        return "en"


# --------------------------------------------------------------------------- versions et releases

def parse_version(text: str) -> tuple:
    """x, x.y ou x.y.z (préfixe v et suffixe -beta ignorés) → (x, y, z) ; () si illisible."""
    raw = str(text or "").strip()
    if raw[:1] in "vV":
        raw = raw[1:]
    parts = raw.split("-")[0].split(".")
    if not 1 <= len(parts) <= 3 or not all(p.isdigit() for p in parts):
        return ()
    return tuple(int(p) for p in parts) + (0,) * (3 - len(parts))


def is_newer(latest: str, current: str) -> bool:
    a, b = parse_version(latest), parse_version(current)
    return bool(a and b and a > b)


@dataclass(frozen=True)
class Release:
    tag: str
    version: str
    body: str
    zip_name: str
    zip_url: str
    sha_url: str
    html_url: str = ""


def parse_releases(data: bytes | str) -> list[Release]:
    """Réponse de GET /releases → releases publiées (ni brouillon ni préversion) qui portent un zip et son .sha256."""
    try:
        raw = json.loads(data)
    except ValueError:
        return []
    out = []
    for j in raw if isinstance(raw, list) else []:
        if not isinstance(j, dict) or j.get("draft") or j.get("prerelease"):
            continue
        v = parse_version(str(j.get("tag_name") or ""))
        if not v:
            continue
        assets = {}
        for a in j.get("assets") or []:
            url = str(a.get("url") or "")
            p = urlparse(url)
            if p.scheme == "https" and p.hostname == API_HOST:
                assets[str(a.get("name") or "")] = url
        zips = sorted(n for n in assets if n.endswith(".zip") and n + ".sha256" in assets)
        if not zips:
            continue
        zip_name = next((n for n in zips if "arm64" in n), zips[0])
        out.append(Release(str(j["tag_name"]), ".".join(map(str, v)), str(j.get("body") or ""), zip_name,
                           assets[zip_name], assets[zip_name + ".sha256"], str(j.get("html_url") or "")))
    return out


def newer_releases(releases: list[Release], current: str) -> list[Release]:
    """Releases plus récentes que la version installée, de la plus récente à la plus ancienne."""
    return sorted((r for r in releases if is_newer(r.version, current)), key=lambda r: parse_version(r.version), reverse=True)


_MARK = re.compile(r"<!--\s*notes:(\w+)\s*-->")


def extract_notes(body: str, lang: str) -> str:
    """Notes d'une release dans la langue demandée (anglais à défaut) ; corps entier nettoyé si aucune balise."""
    text = body or ""
    marks = list(_MARK.finditer(text))
    sections = {}
    for i, m in enumerate(marks):
        end = marks[i + 1].start() if i + 1 < len(marks) else len(text)
        sections[m.group(1).lower()] = text[m.end():end]
    if sections:
        chosen = sections.get(normalize_lang(lang)) or sections.get("en") or ""
    else:
        chosen = text.split("\n---", 1)[0]
        chosen = "\n".join(l for l in chosen.splitlines() if not l.lstrip("*_ ").lower().startswith("full changelog"))
    chosen = re.sub(r"\A\s*#{1,6}[^\n]*\n", "", chosen)  # titre de langue (« ## Français »)
    return chosen.strip()


def build_notes(releases: list[Release], lang: str) -> str:
    """Markdown : une section « ## X.Y.Z » par release, de la plus récente à la plus ancienne ; releases sans note omises."""
    blocks = []
    for r in releases:
        n = extract_notes(r.body, lang)
        if n:
            blocks.append(f"## {r.version}\n\n{n}")
    return "\n\n".join(blocks)


def branded(text: str, name: str, color: str | None) -> str:
    """Texte HTML échappé ; la première lettre minuscule du nom de l'appli prend la couleur de son logo."""
    out = html.escape(text)
    m = re.search(r"[a-z]", name)
    if color and m and name in text:
        i = m.start()
        out = out.replace(html.escape(name), f'<span style="color:{html.escape(color)}">{html.escape(name[i])}</span>'.join([html.escape(name[:i]), html.escape(name[i + 1:])]), 1)
    return out


def md_to_html(md: str) -> str:
    """Mini rendu Markdown (titres, puces, gras, code) pour la fenêtre pywebview."""
    out, in_list = [], False
    for line in md.splitlines():
        s = html.escape(line.rstrip())
        s = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", s)
        s = re.sub(r"`(.+?)`", r"<code>\1</code>", s)
        if s.startswith("- "):
            if not in_list:
                out.append("<ul>"); in_list = True
            out.append(f"<li>{s[2:]}</li>")
            continue
        if in_list:
            out.append("</ul>"); in_list = False
        if s.startswith("## "):
            out.append(f"<h3>{s[3:]}</h3>")
        elif s.strip():
            out.append(f"<p>{s}</p>")
    if in_list:
        out.append("</ul>")
    return "\n".join(out)


# --------------------------------------------------------------------------- script d'installation

def install_script(pid: int, new_app: str, destination: str, relaunch: bool, quiet: bool = False, chown: str | None = None) -> str:
    """Script lancé à part : attend la fin de l'appli, garde l'ancienne copie, remplace par ditto (la remet en cas
    d'échec), relance si demandé. `quiet` : relance sans passer au premier plan ; `chown` « uid:gid » : copie faite
    avec des droits administrateur."""
    q = shlex.quote
    old = destination + ".old"
    opts = "-g " if quiet else ""
    own = f"/usr/sbin/chown -R {q(chown)} {q(destination)} 2>/dev/null\n" if chown else ""
    reopen = f"/usr/bin/open {opts}{q(destination)}\n" if relaunch else ""
    return (
        "#!/bin/sh\n"
        f"while kill -0 {int(pid)} 2>/dev/null; do sleep 0.2; done\n"
        f"rm -rf {q(old)}\n"
        f"mv {q(destination)} {q(old)} || exit 1\n"
        f"if /usr/bin/ditto {q(new_app)} {q(destination)}; then\n"
        f"    rm -rf {q(old)} {q(new_app)}\n"
        "else\n"
        f"    rm -rf {q(destination)}; mv {q(old)} {q(destination)}\n"
        "fi\n"
        f"/usr/bin/xattr -cr {q(destination)} 2>/dev/null\n"
        f"{own}"
        f"{reopen}"
    )


# --------------------------------------------------------------------------- appli en cours

def app_path() -> Path | None:
    """<Appli>.app en cours d'exécution, ou None en développement."""
    exe = Path(sys.executable).resolve()
    if exe.parent.name == "MacOS" and exe.parents[1].name == "Contents" and exe.parents[2].suffix == ".app":
        return exe.parents[2]
    return None


def bundle_info(app: Path | None) -> dict:
    if app is None:
        return {}
    try:
        with (app / "Contents" / "Info.plist").open("rb") as f:
            return plistlib.load(f)
    except (OSError, plistlib.InvalidFileException):
        return {}


def _run(*args: str) -> tuple[int, str]:
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=300)
    except (OSError, subprocess.SubprocessError):
        return -1, ""
    return r.returncode, r.stdout + r.stderr


def requirement(app: Path | str) -> str | None:
    """Exigence de signature désignée de l'appli (identifiant + certificat)."""
    code, out = _run("/usr/bin/codesign", "-d", "-r-", str(app))
    return next((l for l in out.splitlines() if l.startswith("designated =>")), None) if code == 0 else None


def team_id(app: Path | str) -> str | None:
    code, out = _run("/usr/bin/codesign", "-dv", str(app))
    m = re.search(r"^TeamIdentifier=(\S+)", out, re.M) if code == 0 else None
    return m.group(1) if m else None


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def sha_matches(archive: Path, sha_text: str) -> bool:
    m = re.match(r"\s*([0-9a-fA-F]{64})\b", sha_text or "")
    return bool(m) and m.group(1).lower() == sha256_of(archive)


def accepted_ids(info: dict) -> set[str]:
    """Identifiants de paquet acceptés pour la mise à jour : celui de l'appli, plus celui de la clé de build de test."""
    ids = {str(info.get("CFBundleIdentifier") or "")}
    extra = info.get(ACCEPT_KEY)
    if extra:
        ids.add(str(extra))
    ids.discard("")
    return ids


def prepare(archive: Path, sha_text: str, version: str, current_app: Path, check_notarization: bool = True) -> Path | None:
    """Contrôle l'archive téléchargée, la décompresse et la contrôle : renvoie le .app prêt à installer, ou None."""
    if not sha_matches(archive, sha_text):
        return None
    folder = Path(tempfile.mkdtemp(prefix="skyrim-update-"))
    try:
        if _run("/usr/bin/ditto", "-x", "-k", str(archive), str(folder))[0] != 0:
            raise ValueError
        apps = [p for p in folder.iterdir() if p.suffix == ".app" and p.is_dir()]
        if len(apps) != 1:
            raise ValueError
        new = apps[0]
        cur = bundle_info(current_app)
        info = bundle_info(new)
        if info.get("CFBundleIdentifier") not in accepted_ids(cur):
            raise ValueError
        if not parse_version(str(info.get("CFBundleShortVersionString") or "")) == parse_version(version):
            raise ValueError
        if _run("/usr/bin/codesign", "--verify", "--strict", "--deep", str(new))[0] != 0:
            raise ValueError
        if team_id(new) != TEAM_ID:
            raise ValueError
        if not cur.get(ACCEPT_KEY) and team_id(current_app) == TEAM_ID:
            # appli officielle (Developer ID) : même exigence de signature que l'appli en cours. Une copie signée
            # localement ou l'édition de test n'a pas cette exigence : seul le Team ID du paquet reçu compte alors.
            want = requirement(current_app)
            if not want or requirement(new) != want:
                raise ValueError
        if check_notarization and _run("/usr/bin/xcrun", "stapler", "validate", str(new))[0] != 0:
            raise ValueError
        return new
    except (ValueError, OSError):
        shutil.rmtree(folder, ignore_errors=True)
        return None


# --------------------------------------------------------------------------- réseau

def github_token() -> str | None:
    """Jeton `gh` de l'utilisateur, seulement si le dépôt n'est pas lisible sans (dépôt privé)."""
    for gh in ("/opt/homebrew/bin/gh", "/usr/local/bin/gh"):
        if Path(gh).is_file():
            code, out = _run(gh, "auth", "token")
            if code == 0 and out.strip():
                return out.strip()
    return None


def host_allowed(host: str | None) -> bool:
    return bool(host) and (host == API_HOST or host.endswith(DOWNLOAD_SUFFIX))


class _Redirects(urllib.request.HTTPRedirectHandler):
    """Refuse toute redirection hors de GitHub et n'envoie pas le jeton au stockage de fichiers."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        p = urlparse(newurl)
        if p.scheme != "https" or not host_allowed(p.hostname):
            raise urllib.error.URLError(f"redirection refusée : {p.hostname}")
        new = super().redirect_request(req, fp, code, msg, headers, newurl)
        if new is not None and p.hostname != API_HOST:
            new.headers.pop("Authorization", None)
            new.unredirected_hdrs.pop("Authorization", None)
        return new


def _open(url: str, accept: str, token: str | None, timeout: float = 20.0):
    p = urlparse(url)
    if p.scheme != "https" or not host_allowed(p.hostname):
        raise urllib.error.URLError(f"hôte refusé : {p.hostname}")
    req = urllib.request.Request(url, headers={"Accept": accept, "User-Agent": "skyrim-tools-updater"})
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    return urllib.request.build_opener(_Redirects).open(req, timeout=timeout)


def fetch_releases(repo: str) -> tuple[list[Release], str | None]:
    """(releases, jeton). Sans jeton d'abord ; `gh` en repli sur 404 (dépôt privé). OSError si GitHub est injoignable."""
    url = f"https://{API_HOST}/repos/{OWNER}/{repo}/releases?per_page=30"
    token = None
    for attempt in (0, 1):
        try:
            with _open(url, "application/vnd.github+json", token) as r:
                return parse_releases(r.read()), token
        except urllib.error.HTTPError as e:
            if e.code == 404 and attempt == 0:
                token = github_token()
                if token:
                    continue
                return [], None
            raise OSError(f"HTTP {e.code}") from e
    return [], token


def download(url: str, dest: Path, token: str | None, progress=None) -> None:
    with _open(url, "application/octet-stream", token, timeout=60) as r, dest.open("wb") as f:
        total = int(r.headers.get("Content-Length") or 0)
        done = 0
        while chunk := r.read(1 << 18):
            f.write(chunk)
            done += len(chunk)
            if progress and total:
                progress(min(100, done * 100 // total))


def download_text(url: str, token: str | None) -> str:
    with _open(url, "application/octet-stream", token) as r:
        return r.read(4096).decode("utf-8", "replace")


# --------------------------------------------------------------------------- état local

class State:
    """Dernière vérification et version ignorée, dans ~/Library/Caches/<identifiant>/updater.json."""

    def __init__(self, bundle_id: str, base: Path | None = None):
        self.path = (base or Path.home() / "Library" / "Caches") / (bundle_id or "skyrim-tools") / "updater.json"

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

    def due(self, now: float) -> bool:
        return now - float(self.load().get("checked", 0) or 0) >= DAY

    def mark_checked(self, now: float) -> None:
        d = self.load(); d["checked"] = now; self.save(d)

    def skipped(self) -> str:
        return str(self.load().get("skipped", ""))

    def skip(self, version: str) -> None:
        d = self.load(); d["skipped"] = version; self.save(d)


# --------------------------------------------------------------------------- moteur (sans interface)

@dataclass
class Plan:
    app_name: str
    current: str
    target: Release
    releases: list = field(default_factory=list)  # toutes les releases plus récentes, la plus récente d'abord

    def notes(self, lang: str) -> str:
        return build_notes(self.releases, lang)


class Engine:
    """Vérification et installation ; aucune interface. `fetch`, `now` et `app` sont injectables pour les tests."""

    def __init__(self, repo: str, lang=None, app: Path | None = None, state: State | None = None,
                 fetch=fetch_releases, now=time.time):
        self.repo = repo
        self._lang = lang
        self.app = app if app is not None else app_path()
        self.info = bundle_info(self.app)
        self.current = str(self.info.get("CFBundleShortVersionString") or "")
        self.name = str(self.info.get("CFBundleName") or repo)
        self.state = state or State(str(self.info.get("CFBundleIdentifier") or repo))
        self._fetch, self._now = fetch, now
        self.token: str | None = None
        self.busy = False

    @property
    def lang(self) -> str:
        value = self._lang() if callable(self._lang) else self._lang
        return normalize_lang(value) if value else system_lang()

    @property
    def page(self) -> str:
        return f"https://github.com/{OWNER}/{self.repo}/releases/latest"

    def check(self, manual: bool = False) -> tuple[str, Plan | None]:
        """('update', Plan) | ('uptodate', None) | ('skip', None) | ('error', None)."""
        if not self.current:
            return "skip", None  # développement : pas d'appli compilée
        if not manual:
            if os.environ.get("SKYRIM_TOOLS_NO_UPDATE_CHECK") or not self.state.due(self._now()):
                return "skip", None
        try:
            releases, self.token = self._fetch(self.repo)
        except (OSError, ValueError):
            return "error", None
        self.state.mark_checked(self._now())
        newer = newer_releases(releases, self.current)
        if not newer:
            return "uptodate", None
        if not manual and self.state.skipped() == newer[0].version:
            return "skip", None
        return "update", Plan(self.name, self.current, newer[0], newer)

    def install(self, plan: Plan, progress=None, relaunch: bool = True) -> str:
        """'ok' (le script d'installation attend la fin de l'appli) | 'net' | 'verify' | 'install' | 'denied'."""
        if self.app is None or not self.app.parent.is_dir():
            return "install"
        work = Path(tempfile.mkdtemp(prefix="skyrim-dl-"))
        try:
            archive = work / plan.target.zip_name
            try:
                download(plan.target.zip_url, archive, self.token, progress)
                sha_text = download_text(plan.target.sha_url, self.token)
            except (OSError, ValueError):
                return "net"
            new = prepare(archive, sha_text, plan.target.version, self.app)
            if new is None:
                return "verify"
            return self._launch_installer(new, relaunch)
        finally:
            shutil.rmtree(work, ignore_errors=True)

    def _launch_installer(self, new: Path, relaunch: bool) -> str:
        writable = os.access(self.app.parent, os.W_OK) and os.access(self.app, os.W_OK)
        quiet = bool(os.environ.get("SKYRIM_TOOLS_UPDATE_QUIET"))
        chown = None if writable else f"{os.getuid()}:{os.getgid()}"
        script = Path(tempfile.mkdtemp(prefix="skyrim-install-")) / "install.sh"
        script.write_text(install_script(os.getpid(), str(new), str(self.app), relaunch, quiet, chown), encoding="utf-8")
        try:
            if writable:
                subprocess.Popen(["/bin/sh", str(script)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            else:
                cmd = f"/bin/sh {shlex.quote(str(script))} >/dev/null 2>&1 &"
                r = subprocess.run(["/usr/bin/osascript", "-e",
                                    f'do shell script "{cmd.replace(chr(92), chr(92) * 2).replace(chr(34), chr(92) + chr(34))}" with administrator privileges'],
                                   capture_output=True, text=True, timeout=300)
                if r.returncode != 0:
                    return "denied"
        except (OSError, subprocess.SubprocessError):
            return "install"
        return "ok"


# --------------------------------------------------------------------------- interface PyQt6

def _qt():
    """Classes Qt, importées à la demande : PyInstaller n'embarque pas PyQt6 dans les applis pywebview."""
    core, widgets = importlib.import_module("PyQt6.QtCore"), importlib.import_module("PyQt6.QtWidgets")
    gui = importlib.import_module("PyQt6.QtGui")
    try:
        socle = importlib.import_module("socle_qt")
    except ImportError:
        socle = None
    return core, widgets, gui, socle


def start_qt(window, repo: str, lang=None, page: str | None = None, menu: bool = True):
    """PyQt6 : vérification en arrière-plan, puis fenêtre Socle quand l'appli est au premier plan. Renvoie le contrôleur.
    `menu` : ajoute « Rechercher les mises à jour… » au menu de l'appli (barre de menus de la fenêtre, ou barre macOS)."""
    engine = Engine(repo, lang)
    core, widgets, gui, socle = _qt()

    class Controller(core.QObject):
        found = core.pyqtSignal(object, bool)   # Plan | None, manuel
        status = core.pyqtSignal(str, str)      # code de résultat, message
        progress = core.pyqtSignal(int)
        done = core.pyqtSignal(str)
        noticed = core.pyqtSignal(str)

        def __init__(self):
            super().__init__(window)
            self.found.connect(self._show)
            self._pending = None

        def check_manual(self):
            self._start(True)

        def check_auto(self):
            self._start(False)

        def _start(self, manual: bool):
            if engine.busy:
                return
            engine.busy = True

            def run():
                try:
                    code, plan = engine.check(manual)
                finally:
                    engine.busy = False
                if code == "update" or (manual and code in ("uptodate", "error")):
                    self.found.emit((code, plan), manual)
            threading.Thread(target=run, daemon=True).start()

        def _show(self, result, manual):
            code, plan = result
            app = widgets.QApplication.instance()
            if not manual and app.applicationState() != core.Qt.ApplicationState.ApplicationActive:
                # mode silencieux : pas de fenêtre devant le travail en cours ; on attend que l'appli passe au premier plan
                self._pending = result
                app.applicationStateChanged.connect(self._on_state)
                return
            self._dialog(code, plan)

        def _on_state(self, state):
            if state == core.Qt.ApplicationState.ApplicationActive and self._pending:
                app = widgets.QApplication.instance()
                app.applicationStateChanged.disconnect(self._on_state)
                result, self._pending = self._pending, None
                self._dialog(*result)

        def _dialog(self, code, plan):
            t = texts(engine.lang)
            if code != "update":
                box = widgets.QMessageBox(window)
                box.setWindowTitle(t["uptodate_title"] if code == "uptodate" else t["title"])
                box.setText(t["uptodate"].format(app=engine.name, cur=engine.current) if code == "uptodate" else t["err_net"])
                box.exec()
                return
            _UpdateDialog(self, plan, t).exec()

    class _UpdateDialog(widgets.QDialog):
        def __init__(self, ctl, plan, t):
            super().__init__(window)
            self.ctl, self.plan, self.t = ctl, plan, t
            self.setWindowTitle(t["title"])
            self.setModal(True)
            self.resize(540, 520)
            lay = widgets.QVBoxLayout(self)
            lay.setContentsMargins(24, 22, 24, 20)
            lay.setSpacing(12)
            title = widgets.QLabel(t["title"])
            body = widgets.QLabel(t["body"].format(app=plan.app_name, new=plan.target.version, cur=plan.current))
            body.setWordWrap(True)
            heading = widgets.QLabel(t["notes"].format(cur=plan.current))
            self.view = widgets.QTextBrowser()
            self.view.setOpenExternalLinks(False)
            self.view.setMarkdown(plan.notes(engine.lang) or t["no_notes"])
            self.status = widgets.QLabel("")
            self.status.setWordWrap(True)
            self.bar = widgets.QProgressBar()
            self.bar.setRange(0, 100)
            self.bar.hide()
            row = widgets.QHBoxLayout()
            self.b_skip = widgets.QPushButton(t["skip"])
            self.b_later = widgets.QPushButton(t["later"])
            self.b_install = widgets.QPushButton(t["install"])
            self.b_page = widgets.QPushButton(t["open_page"])
            self.b_page.hide()
            row.addWidget(self.b_skip)
            row.addStretch(1)
            row.addWidget(self.b_page)
            row.addWidget(self.b_later)
            row.addWidget(self.b_install)
            for w in (title, body, heading, self.view, self.bar, self.status):
                lay.addWidget(w)
            lay.addLayout(row)
            if socle:
                socle.role(title, "title")
                socle.role(heading, "eyebrow")
                socle.role(self.status, "muted")
                socle.variant(self.b_install, "primary")
                socle.variant(self.b_later, "secondary")
                socle.variant(self.b_skip, "tertiary")
                socle.variant(self.b_page, "secondary")
            self.b_later.clicked.connect(self.reject)
            self.b_skip.clicked.connect(self._skip)
            self.b_install.clicked.connect(self._install)
            self.b_page.clicked.connect(lambda: (webbrowser.open(page or engine.page), self.reject()))
            ctl.progress.connect(self.bar.setValue)
            ctl.done.connect(self._finished)

        def _skip(self):
            engine.state.skip(self.plan.target.version)
            self.reject()

        def _install(self):
            for b in (self.b_skip, self.b_later, self.b_install):
                b.setEnabled(False)
            self.bar.show()
            self.status.setText(self.t["downloading"])

            def run():
                code = engine.install(self.plan, progress=self.ctl.progress.emit)
                self.ctl.done.emit(code)
            threading.Thread(target=run, daemon=True).start()

        def _finished(self, code):
            if code == "ok":
                self.status.setText(self.t["installing"])
                self.bar.setRange(0, 0)
                widgets.QApplication.instance().quit()  # le script attend la fin du processus, remplace puis relance
                return
            self.bar.hide()
            self.status.setText(self.t[{"net": "err_net", "verify": "err_verify", "denied": "err_denied"}.get(code, "err_install")])
            self.b_later.setText(self.t["close"])
            self.b_later.setEnabled(True)
            self.b_page.show()

    ctl = Controller()
    window._updater = ctl  # garde l'objet en vie
    if menu:
        bar = getattr(window, "menu_bar", None) or (window.menuBar() if hasattr(window, "menuBar") else None)
        if bar is None:
            bar = widgets.QMenuBar()
            window._update_menubar = bar
        action = gui.QAction(texts(engine.lang)["menu"], bar)
        action.setMenuRole(gui.QAction.MenuRole.ApplicationSpecificRole)  # macOS la range dans le menu de l'appli
        action.triggered.connect(ctl.check_manual)
        bar.addMenu(engine.name).addAction(action)
    if not os.environ.get("SKYRIM_TOOLS_NO_UPDATE_CHECK"):
        ctl.check_auto()
    return ctl


# --------------------------------------------------------------------------- interface pywebview

_WEB_CSS = ("#sk-upd{position:fixed;inset:0;z-index:99999;display:flex;align-items:center;justify-content:center;"
            "background:rgba(0,0,0,.55);font:13px -apple-system,system-ui,sans-serif}"
            "#sk-upd .box{background:#222;color:#ddd;border:1px solid #444;border-radius:10px;width:min(520px,92vw);"
            "max-height:86vh;display:flex;flex-direction:column;padding:22px 24px;gap:10px;box-shadow:0 12px 40px rgba(0,0,0,.5)}"
            "#sk-upd h2{margin:0;color:#fff;font-size:17px}#sk-upd .eyebrow{color:#aaa;font-size:11px;text-transform:uppercase;letter-spacing:.06em}"
            "#sk-upd .notes{overflow:auto;background:#1a1a1a;border:1px solid #333;border-radius:6px;padding:4px 14px;min-height:120px}"
            "#sk-upd h3{margin:12px 0 4px;color:#fff;font-size:14px;font-weight:600}#sk-upd ul{margin:4px 0 8px;padding-left:18px;list-style:disc}#sk-upd li{margin:3px 0}#sk-upd p{margin:6px 0}#sk-upd code{background:#333;padding:0 4px;border-radius:3px}"
            "#sk-upd .row{display:flex;gap:8px;align-items:center}#sk-upd .sp{flex:1}"
            "#sk-upd button{background:#333;color:#ddd;border:1px solid #707070;border-radius:6px;padding:6px 12px;font:inherit;cursor:pointer}"
            "#sk-upd button.primary{background:#0369a1;border-color:#0369a1;color:#fff}#sk-upd button.tert{background:none;border-color:transparent;color:#aaa}"
            "#sk-upd button:disabled{opacity:.5;cursor:default}#sk-upd .bar{height:6px;background:#333;border-radius:3px;overflow:hidden;display:none}"
            "#sk-upd .bar i{display:block;height:100%;width:0;background:#0ea5e9}#sk-upd .st{color:#aaa;min-height:1.2em}")


def start_webview(window, repo: str, lang=None, page: str | None = None, brand: str | None = None):
    """pywebview : même fenêtre en HTML, dans la fenêtre de l'appli (window.evaluate_js + window.expose). Renvoie le contrôleur.
    `brand` : couleur du logo, pour la lettre minuscule du nom de l'appli (règle Socle)."""
    engine = Engine(repo, lang)

    class Controller:
        plan: Plan | None = None

        def check_manual(self):
            self._start(True)

        def check_auto(self):
            self._start(False)

        def _start(self, manual):
            if engine.busy:
                return
            engine.busy = True

            def run():
                try:
                    code, plan = engine.check(manual)
                finally:
                    engine.busy = False
                if code == "update":
                    self.plan = plan
                    self._render(plan)
                elif manual and code in ("uptodate", "error"):
                    t = texts(engine.lang)
                    self._js(f"alert({json.dumps(t['uptodate'].format(app=engine.name, cur=engine.current) if code == 'uptodate' else t['err_net'])})")
            threading.Thread(target=run, daemon=True).start()

        def _js(self, code):
            try:
                window.evaluate_js(code)
            except Exception:
                pass

        def _render(self, plan):
            t = texts(engine.lang)
            data = {
                "title": t["title"], "body": branded(t["body"].format(app=plan.app_name, new=plan.target.version, cur=plan.current), plan.app_name, brand),
                "heading": t["notes"].format(cur=plan.current), "notes": md_to_html(plan.notes(engine.lang)) or f"<p>{html.escape(t['no_notes'])}</p>",
                "install": t["install"], "later": t["later"], "skip": t["skip"], "page": t["open_page"],
            }
            self._js("(" + _WEB_JS + ")(" + json.dumps(data) + "," + json.dumps(_WEB_CSS) + ")")

        # appelés depuis la page (window.expose)
        def sk_update_install(self):
            def run():
                code = engine.install(self.plan, progress=lambda p: self._js(f"window.skUpdProgress({p})"))
                t = texts(engine.lang)
                if code == "ok":
                    self._js(f"window.skUpdStatus({json.dumps(t['installing'])},false)")
                    time.sleep(0.5)
                    window.destroy()
                else:
                    key = {"net": "err_net", "verify": "err_verify", "denied": "err_denied"}.get(code, "err_install")
                    self._js(f"window.skUpdStatus({json.dumps(t[key])},true)")
            threading.Thread(target=run, daemon=True).start()

        def sk_update_skip(self):
            if self.plan:
                engine.state.skip(self.plan.target.version)

        def sk_update_page(self):
            webbrowser.open(page or engine.page)

    ctl = Controller()
    window._updater = ctl
    try:
        window.expose(ctl.sk_update_install, ctl.sk_update_skip, ctl.sk_update_page)
    except Exception:
        pass
    if not os.environ.get("SKYRIM_TOOLS_NO_UPDATE_CHECK"):
        threading.Timer(3.0, ctl.check_auto).start()  # laisse la page se charger
    return ctl


_WEB_JS = r"""function(d, css){
  var old=document.getElementById('sk-upd'); if(old) old.remove();
  var s=document.createElement('style'); s.id='sk-upd-css'; s.textContent=css; document.head.appendChild(s);
  var o=document.createElement('div'); o.id='sk-upd';
  o.innerHTML='<div class="box"><h2></h2><div class="body"></div><div class="eyebrow"></div><div class="notes"></div>'+
   '<div class="bar"><i></i></div><div class="st"></div><div class="row"><button class="tert" id="sk-skip"></button><span class="sp"></span>'+
   '<button id="sk-page" style="display:none"></button><button id="sk-later"></button><button class="primary" id="sk-install"></button></div></div>';
  document.body.appendChild(o);
  var q=function(x){return o.querySelector(x)};
  q('h2').textContent=d.title; q('.body').innerHTML=d.body; q('.eyebrow').textContent=d.heading; q('.notes').innerHTML=d.notes;
  q('#sk-skip').textContent=d.skip; q('#sk-later').textContent=d.later; q('#sk-install').textContent=d.install; q('#sk-page').textContent=d.page;
  var close=function(){o.remove(); var c=document.getElementById('sk-upd-css'); if(c) c.remove();};
  q('#sk-later').onclick=close;
  q('#sk-skip').onclick=function(){pywebview.api.sk_update_skip(); close();};
  q('#sk-page').onclick=function(){pywebview.api.sk_update_page(); close();};
  q('#sk-install').onclick=function(){['#sk-skip','#sk-later','#sk-install'].forEach(function(i){q(i).disabled=true});
    q('.bar').style.display='block'; pywebview.api.sk_update_install();};
  window.skUpdProgress=function(p){q('.bar i').style.width=p+'%'};
  window.skUpdStatus=function(m,err){q('.st').textContent=m; if(err){q('.bar').style.display='none'; q('#sk-later').disabled=false; q('#sk-page').style.display='';}};
}"""
