"""Langue de l'interface : choix mémorisé dans les QSettings de l'appli (clé « language », « auto » = langue du Mac)
et menu « Langue » de la barre de menus (module commun lang_menu)."""
from PyQt6.QtCore import QCoreApplication, QLibraryInfo, QSettings, QTranslator

import i18n
import lang_menu

_qt_tr = None


def qt_lang(code: str) -> None:
    """Boutons standard de Qt (Oui/Non, Annuler, OK…) dans la langue de l'appli : traductions de Qt embarquées."""
    global _qt_tr
    app = QCoreApplication.instance()
    if app is None:
        return
    if _qt_tr is not None:
        app.removeTranslator(_qt_tr)
        _qt_tr = None
    if code != "en":
        tr = QTranslator(app)
        if tr.load(f"qtbase_{code}", QLibraryInfo.path(QLibraryInfo.LibraryPath.TranslationsPath)):
            app.installTranslator(tr)
            _qt_tr = tr


def init_lang(settings: QSettings) -> None:
    """Active la langue mémorisée (à appeler avant de construire l'interface)."""
    qt_lang(i18n.set_lang(lang_menu.resolve(settings.value("language", lang_menu.AUTO))))


def install_menu(window, settings: QSettings, on_change):
    """Menu « Langue » ; après un choix, la langue est activée puis on_change() est appelé."""
    def apply(code):
        qt_lang(i18n.set_lang(code))
        on_change()

    return lang_menu.install_qt(window, lambda: settings.value("language", lang_menu.AUTO),
                                lambda v: settings.setValue("language", v), apply)
