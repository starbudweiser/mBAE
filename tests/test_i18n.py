"""Vérifie que chaque texte passé à L()/N_() possède une traduction complète."""
import ast
import re
import sys
import unittest
from unittest import mock
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "src"
sys.path.insert(0, str(ROOT))

import i18n  # noqa: E402

FIELD_RE = re.compile(r"\{([A-Za-z_][A-Za-z0-9_]*)[^}]*\}")


def collect_keys() -> set:
    keys = set()
    for path in ROOT.glob("*.py"):
        if path.name.startswith(("test_", ".")) or path.name in ("i18n_strings.py", "socle_qt.py"):
            continue
        tree = ast.parse(path.read_text(encoding="utf-8"))
        for node in ast.walk(tree):
            if (isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id in ("L", "N_")
                    and node.args and isinstance(node.args[0], ast.Constant) and isinstance(node.args[0].value, str)):
                keys.add(node.args[0].value)
    return keys


class TestI18n(unittest.TestCase):
    def test_all_keys_translated(self):
        from i18n_strings import TR
        missing = sorted(k for k in collect_keys() if k not in TR)
        self.assertEqual(missing, [], f"{len(missing)} clé(s) sans traduction")
        for k, tr in TR.items():
            self.assertEqual(len(tr), 3, k)
            for lang, t in zip(("en", "it", "es"), tr):
                self.assertTrue(t.strip(), f"{lang} vide : {k}")
                self.assertEqual(set(FIELD_RE.findall(k)), set(FIELD_RE.findall(t)), f"{lang} : {k}")

    def test_no_stale_keys(self):
        from i18n_strings import TR
        stale = sorted(set(TR) - collect_keys())
        self.assertEqual(stale, [], "clés orphelines dans TR")

    def test_switch(self):
        import i18n_strings
        sample = {"Fichier : {name}": ("File: {name}", "File: {name}", "Archivo: {name}"),
                  "Automatique ({lang})": ("Automatic ({lang})", "Automatica ({lang})", "Automático ({lang})")}
        with mock.patch.dict(i18n_strings.TR, sample):
            try:
                i18n.set_lang("en")
                self.assertEqual(i18n.L("Fichier : {name}", name="x"), "File: x")
                i18n.set_lang("it")
                self.assertEqual(i18n.L("Automatique ({lang})", lang="x"), "Automatica (x)")
            finally:
                i18n.set_lang("fr")
            self.assertEqual(i18n.L("Fichier : {name}", name="x"), "Fichier : x")

    def test_system_lang(self):
        self.assertEqual(i18n.system_lang(["it-IT", "en-US"]), "it")
        self.assertEqual(i18n.system_lang(["de-DE", "es-ES"]), "es")
        self.assertEqual(i18n.system_lang(["de-DE"]), "en")


if __name__ == "__main__":
    unittest.main()
