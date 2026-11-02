"""Traductions : {texte français: (anglais, italien, espagnol)}.

Les placeholders {x} doivent rester identiques dans toutes les langues (vérifié par
tests/test_i18n.py).
"""

TR = {
    # ------------------------------------------------------------ fenêtre
    "Extracteur d'archives Bethesda": (
        "Bethesda archive extractor", "Estrattore di archivi Bethesda", "Extractor de archivos de Bethesda"),
    "Ouvrir une archive (.bsa / .ba2)": (
        "Open an archive (.bsa / .ba2)", "Apri un archivio (.bsa / .ba2)", "Abrir un archivo (.bsa / .ba2)"),
    "Glisse-dépose une archive n'importe où ici.": (
        "Drag and drop an archive anywhere here.",
        "Trascina un archivio in qualsiasi punto qui.",
        "Arrastra un archivo a cualquier parte de aquí."),
    "Chemin du fichier": ("File path", "Percorso del file", "Ruta del archivo"),
    "Taille brute": ("Raw size", "Dimensione grezza", "Tamaño bruto"),
    "Type d'archive": ("Archive type", "Tipo di archivio", "Tipo de archivo"),
    "(Comp)": ("(Comp)", "(Comp)", "(Comp)"),
    "(Brut)": ("(Raw)", "(Grezzo)", "(Bruto)"),
    "EXTRAIRE TOUT": ("EXTRACT ALL", "ESTRAI TUTTO", "EXTRAER TODO"),
    "{name} — {type} ({n} fichiers)": ("{name} — {type} ({n} files)", "{name} — {type} ({n} file)", "{name} — {type} ({n} archivos)"),
    "Langue : {name}": ("Language: {name}", "Lingua: {name}", "Idioma: {name}"),
    "Automatique ({lang})": ("Automatic ({lang})", "Automatica ({lang})", "Automático ({lang})"),
    # ------------------------------------------------------------ dialogues
    "Sélectionner une archive Bethesda": ("Select a Bethesda archive", "Seleziona un archivio Bethesda", "Seleccionar un archivo de Bethesda"),
    "Archives Bethesda": ("Bethesda archives", "Archivi Bethesda", "Archivos de Bethesda"),
    "Tous les fichiers": ("All files", "Tutti i file", "Todos los archivos"),
    "Choisir le dossier de destination": ("Choose the destination folder", "Scegli la cartella di destinazione", "Elegir la carpeta de destino"),
    # ------------------------------------------------------------ statut
    "En attente": ("Waiting", "In attesa", "En espera"),
    "Prêt pour l'extraction.": ("Ready to extract.", "Pronto per l'estrazione.", "Listo para extraer."),
    "Erreur : {err}": ("Error: {err}", "Errore: {err}", "Error: {err}"),
    "Extraction terminée : {n} fichiers extraits.": (
        "Extraction complete: {n} files extracted.", "Estrazione completata: {n} file estratti.", "Extracción terminada: {n} archivos extraídos."),
    "Archive vide.": ("Empty archive.", "Archivio vuoto.", "Archivo vacío."),
    "Archive non reconnue (ni .bsa, ni .ba2 valide).": (
        "Unrecognized archive (neither a valid .bsa nor .ba2).",
        "Archivio non riconosciuto (né .bsa né .ba2 valido).",
        "Archivo no reconocido (ni .bsa ni .ba2 válido)."),
    "Archive corrompue : table des dossiers tronquée.": (
        "Corrupted archive: folder table truncated.",
        "Archivio danneggiato: tabella delle cartelle troncata.",
        "Archivo dañado: tabla de carpetas truncada."),
}
