# Changelog — mBAE

Notes de version / release notes (EN + FR). Translations in IT and ES: see the Nexus Mods page.

## 2.0.0

**English**

- Version number aligned across the Skyrim Mac Toolkit: every app of the kit is now a native Swift app, at version 2.0.0.

**Français**

- Numéro de version commun à tout le Skyrim Mac Toolkit : toutes les applis du kit sont désormais des applis Swift natives, en version 2.0.0.

## 1.3.1

**English**

- The window title is now translated: “mBAE – Bethesda archive extractor”.
- Rewritten as a native Swift app (no more Python/PyInstaller): same archives (BSA 103/104/105, BA2 GNRL/DX10, zlib and LZ4), same files extracted byte for byte. No more generic PyInstaller launcher, which antivirus scanners tend to flag.
- Safer extraction: files whose internal path is absolute or contains “..” are skipped (and counted in the final message) instead of being written outside the destination folder.
- Language menu in the menu bar, “About mBAE” window, and automatic update check (daily, signature verified).

**Français**

- Le titre de la fenêtre est maintenant traduit : « mBAE – Extracteur d'archives Bethesda ».
- Réécrite en appli Swift native (plus de Python ni de PyInstaller) : mêmes archives (BSA 103/104/105, BA2 GNRL/DX10, zlib et LZ4), mêmes fichiers extraits octet pour octet. Plus de lanceur PyInstaller générique, souvent signalé par les antivirus.
- Extraction plus sûre : les fichiers dont le chemin interne est absolu ou contient « .. » sont ignorés (et comptés dans le message final) au lieu d'être écrits hors du dossier de destination.
- Menu « Langue » dans la barre de menus, fenêtre « À propos de mBAE » et recherche automatique des mises à jour (quotidienne, signature vérifiée).

## 1.3.0

**English**

- BAE is renamed mBAE, like the other Skyrim Mac Toolkit apps. Because of the new name, macOS treats it as a new app: remove the old BAE.app from Applications.
- Signed with a Developer ID and notarized by Apple: macOS now opens the app without a security warning.
- The app's launcher is now compiled from source when the app is built, instead of using PyInstaller's generic prebuilt launcher, which antivirus scanners tend to flag. No change in features.
- The first letter of the app's name now uses the colour of its logo everywhere it appears.
- Version number aligned across the Skyrim Mac Toolkit.

**Français**

- BAE s'appelle désormais mBAE, comme les autres applis du Skyrim Mac Toolkit. Avec ce nouveau nom, macOS la considère comme une nouvelle appli : supprimez l'ancienne BAE.app du dossier Applications.
- Signée avec un certificat Developer ID et notarisée par Apple : macOS ouvre désormais l'appli sans avertissement de sécurité.
- Le lanceur de l'appli est maintenant compilé depuis les sources à la construction de l'appli, au lieu du lanceur générique précompilé de PyInstaller, souvent signalé par les antivirus. Aucun changement de fonctionnalités.
- La première lettre du nom de l'appli prend la couleur de son logo partout où il est écrit.
- Numéro de version commun à tout le Skyrim Mac Toolkit.

<!-- gen_changelogs : entrées ci-dessous conservées -->

## 1.0.1

**English**

- New-version notice: the app checks the latest GitHub release once a day and offers to open the Nexus page, remind you later or skip that version. Nothing is downloaded or installed.

**Français**

- Avertissement de nouvelle version : l'appli consulte la dernière release GitHub une fois par jour et propose d'ouvrir la page Nexus, de rappeler plus tard ou d'ignorer cette version. Rien n'est téléchargé ni installé.


## 1.0.0

First public release. / Première version publique.
