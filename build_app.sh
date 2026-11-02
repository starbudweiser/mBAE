#!/bin/bash
# Construit mBAE.app à la racine du projet puis supprime les fichiers temporaires.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

APP_NAME="mBAE"
ENTRY="src/mBAE_MACOS.py"
ICON="$ROOT/assets/icon.icns"
VENV=".build_venv"
TMP_DIR=".build_tmp"

[ -f "$ENTRY" ] || { echo "Erreur : $ENTRY introuvable." >&2; exit 1; }
[ -f "$ICON" ]  || { echo "Erreur : $ICON introuvable." >&2; exit 1; }
command -v python3 >/dev/null || { echo "Erreur : python3 requis." >&2; exit 1; }

cleanup() {
    # "$APP_NAME" (sans .app) : dossier intermédiaire de PyInstaller, à ne pas laisser à la racine
    # Le Finder peut recréer des .DS_Store pendant la suppression : quelques essais, sans faire échouer le build
    for _ in 1 2 3; do
        rm -rf "$VENV" "$TMP_DIR" "$APP_NAME.spec" "$APP_NAME" build __pycache__ src/__pycache__ 2>/dev/null && break
        sleep 1
    done
    find "$ROOT" -name ".DS_Store" -not -path "*/node_modules/*" -delete 2>/dev/null || true
}
trap cleanup EXIT

rm -rf "$APP_NAME.app" "$APP_NAME"
python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet --upgrade pip
# Lanceur PyInstaller recompilé depuis les sources (et non celui, précompilé, de la roue PyPI) :
# le lanceur générique est partagé par d'innombrables programmes, dont des malwares, et fait
# mettre les applis en quarantaine par les antivirus heuristiques (scan Nexus Mods).
PYINSTALLER_COMPILE_BOOTLOADER=1 "$VENV/bin/pip" install --quiet --no-binary pyinstaller pyinstaller
"$VENV/bin/pip" install --quiet PyQt6 lz4

"$VENV/bin/pyinstaller" \
    --noconfirm --clean --windowed \
    --name "$APP_NAME" \
    --icon "$ICON" \
    --distpath "$TMP_DIR/dist" \
    --workpath "$TMP_DIR" \
    --specpath "$TMP_DIR" \
    "$ENTRY"

mv "$TMP_DIR/dist/$APP_NAME.app" "$ROOT/$APP_NAME.app"
# Signature stable avec _tools/sign_app.sh (certificat local) ; sans lui (compilation depuis
# le dépôt GitHub seul), signature ad hoc pour que l'appli se lance quand même.
SIGN_APP="$(cd "$ROOT/.." && pwd)/_tools/sign_app.sh"
if [ -x "$SIGN_APP" ]; then
    "$SIGN_APP" "$ROOT/$APP_NAME.app" 1.3.1
else
    echo "_tools/sign_app.sh absent : signature ad hoc."
    codesign --force --deep --sign - "$ROOT/$APP_NAME.app"
fi
echo "OK : $ROOT/$APP_NAME.app"
