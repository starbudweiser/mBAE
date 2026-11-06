#!/usr/bin/env python3
"""Génère Sources/BAECore/Strings.swift à partir de ../i18n/strings.json (lancé par build_app.sh).

La table de traductions est la même pour l'appli et la preview web : {texte_fr: [en, it, es]}.
"""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
SRC = HERE.parent / "i18n" / "strings.json"
OUT = HERE / "Sources" / "BAECore" / "Strings.swift"


def lit(s: str) -> str:
    return json.dumps(s, ensure_ascii=False).replace("\\/", "/")


table = json.loads(SRC.read_text(encoding="utf-8"))
lines = [f"    {lit(k)}: [{', '.join(lit(t) for t in v)}]," for k, v in table.items()]
OUT.write_text(
    "// FICHIER GÉNÉRÉ par macos/gen_strings.py à partir de i18n/strings.json : ne pas modifier à la main.\n\n"
    "let translations: [String: [String]] = [\n" + "\n".join(lines) + "\n]\n",
    encoding="utf-8",
)
print(f"{len(table)} traductions → {OUT.relative_to(HERE)}")
