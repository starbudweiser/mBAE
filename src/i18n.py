"""Internationalisation : français (source), anglais, italien, espagnol.

Même principe que les autres applis (sKYCRASH, fOLDERFUSE) : le texte français sert de clé.
L("Texte {x}", x=1) renvoie la traduction de la langue active, ou le français si elle
manque. Les traductions vivent dans i18n_strings.TR sous la forme {texte_fr: (en, it, es)}.
Module sans dépendance Qt.
"""
from __future__ import annotations

LANGS = {"fr": "Français", "en": "English", "it": "Italiano", "es": "Español"}
_INDEX = {"en": 0, "it": 1, "es": 2}
_lang = "fr"


def system_lang(preferred: list[str], default: str = "en") -> str:
    """Première langue prise en charge parmi les langues préférées du système
    (codes « fr-FR », « en_US »…), sinon `default`."""
    for code in preferred:
        code = (code or "")[:2].lower()
        if code in LANGS:
            return code
    return default


def set_lang(code: str) -> str:
    global _lang
    _lang = code if code in LANGS else "fr"
    return _lang


def get_lang() -> str:
    return _lang


def N_(text: str) -> str:
    """Marque un texte à traduire sans le traduire (déclarations au niveau module)."""
    return text


def L(text: str, **kw) -> str:
    """Traduit `text` (clé française) et applique str.format(**kw) si des paramètres sont fournis."""
    out = text
    if _lang != "fr":
        try:
            from i18n_strings import TR
            tr = TR.get(text)
            if tr:
                out = tr[_INDEX[_lang]] or text
        except ImportError:
            pass
    if not kw:
        return out
    try:
        return out.format(**kw)
    except (KeyError, IndexError, ValueError):
        return text.format(**kw)
