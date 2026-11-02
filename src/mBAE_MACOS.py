import os
import struct
import sys
import zlib
import socle_qt
import updater
from i18n import get_lang
from i18n import L, N_
from lang_button import LangButton, init_lang
from PyQt6.QtCore import QSettings, Qt, QThread, pyqtSignal
from PyQt6.QtWidgets import (
    QAbstractItemView,
    QApplication,
    QFileDialog,
    QHBoxLayout,
    QHeaderView,
    QLabel,
    QMainWindow,
    QProgressBar,
    QPushButton,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

import lz4.block
import lz4.frame


# ==============================================================================
# MOTEUR BSA / BA2
# ==============================================================================


def unpack(raw, real_size):
    """Bloc BA2 : zlib (Fallout 4, Skyrim) ou LZ4 (Starfield)."""
    try:
        return zlib.decompress(raw)
    except zlib.error:
        return lz4.block.decompress(raw, uncompressed_size=real_size)


def dds_header(width, height, mips, dxgi, cube):
    """En-tête DDS avec extension DX10 (148 octets), valable pour tous les formats DXGI d'un BA2."""
    flags = 0x1007 | (0x20000 if mips > 1 else 0)
    caps = 0x1000 | (0x400008 if mips > 1 else 0) | (0x8 if cube else 0)
    return (
        struct.pack("<4s7I11I", b"DDS ", 124, flags, height, width, 0, 0, mips, *([0] * 11))
        + struct.pack("<II4s5I", 32, 0x4, b"DX10", 0, 0, 0, 0, 0)
        + struct.pack("<5I", caps, 0xFE00 if cube else 0, 0, 0, 0)
        + struct.pack("<5I", dxgi, 3, 4 if cube else 0, 1, 0)
    )


class BethesdaArchive:

    def __init__(self, filepath):
        self.filepath = filepath
        self.files = []
        self.archive_type = None
        self.version = 0
        self.embedded_names = False
        self._parse()

    def _parse(self):
        with open(self.filepath, "rb") as f:
            magic = f.read(4)
            if magic == b"BSA\x00":
                self.archive_type = "BSA"
                self._parse_bsa(f)
            elif magic == b"BTDX":
                self.archive_type = "BA2"
                self._parse_ba2(f)
            else:
                raise ValueError(L("Archive non reconnue (ni .bsa, ni .ba2 valide)."))

    def _parse_bsa(self, f):
        version = self.version = struct.unpack("<I", f.read(4))[0]
        data_offset = struct.unpack("<I", f.read(4))[0]
        archive_flags = struct.unpack("<I", f.read(4))[0]
        folder_count, file_count = struct.unpack("<II", f.read(8))
        total_folder_name_len, total_file_name_len = struct.unpack("<II", f.read(8))
        file_flags = struct.unpack("<I", f.read(4))[0]

        has_dir_names = bool(archive_flags & 0x1)
        has_file_names = bool(archive_flags & 0x2)
        default_compressed = bool(archive_flags & 0x4)
        self.embedded_names = version >= 104 and bool(archive_flags & 0x100)

        # 1. Lecture des en-têtes de dossiers (Folder Records)
        # v105 (Skyrim SE 64-bit) utilise 24 octets par record, les versions <=104 utilisent 16 octets
        rec_size = 24 if version >= 105 else 16
        raw_folders = []
        for _ in range(folder_count):
            buf = f.read(rec_size)
            if len(buf) < rec_size:
                raise ValueError(L("Archive corrompue : table des dossiers tronquée."))
            if version >= 105:
                f_hash, f_count, f_off_high, f_off_low = struct.unpack("<QIIQ", buf)
                raw_folders.append({"hash": f_hash, "count": f_count})
            else:
                f_hash, f_count, f_offset = struct.unpack("<QII", buf)
                raw_folders.append({"hash": f_hash, "count": f_count})

        # 2. Lecture séquentielle contiguë : pour chaque dossier, Nom + Liste de fichiers
        folder_data = []
        for rf in raw_folders:
            folder_name = ""
            if has_dir_names:
                b_len = f.read(1)
                if not b_len:
                    break
                name_len = struct.unpack("<B", b_len)[0]
                # Le nom contient 'name_len' octets incluant le null terminal
                raw_n = f.read(name_len).split(b"\x00")[0]
                folder_name = raw_n.decode("latin-1", errors="ignore").replace("\\", "/")

            files_in_folder = []
            for _ in range(rf["count"]):
                f_buf = f.read(16)
                if len(f_buf) < 16:
                    break
                fh, size, f_offset = struct.unpack("<QII", f_buf)

                is_comp = default_compressed
                if size & (1 << 30):
                    is_comp = not default_compressed
                real_size = size & 0x3FFFFFFF

                files_in_folder.append(
                    {
                        "hash": fh,
                        "size": real_size,
                        "offset": f_offset,
                        "compressed": is_comp,
                    }
                )
            folder_data.append({"name": folder_name, "files": files_in_folder})

        # 3. Lecture séquentielle contiguë de la table globale des noms de fichiers
        file_names = []
        if has_file_names and total_file_name_len > 0:
            raw_blob = f.read(total_file_name_len)
            file_names = [
                n.decode("latin-1", errors="ignore").strip()
                for n in raw_blob.split(b"\x00")
            ]

        # 4. Association noms / dossiers
        fn_idx = 0
        for fd in folder_data:
            d_prefix = fd["name"].strip("/")
            for fi in fd["files"]:
                if fn_idx < len(file_names) and file_names[fn_idx]:
                    file_name = file_names[fn_idx]
                else:
                    file_name = f"file_{fi['hash']:016x}.dat"
                fn_idx += 1

                full_path = f"{d_prefix}/{file_name}".lstrip("/") if d_prefix else file_name

                if full_path and not full_path.endswith("/"):
                    self.files.append(
                        {
                            "name": full_path,
                            "size": fi["size"],
                            "offset": fi["offset"],
                            "compressed": fi["compressed"],
                        }
                    )

    def _parse_ba2(self, f):
        version = self.version = struct.unpack("<I", f.read(4))[0]
        header_type = f.read(4)
        num_files = struct.unpack("<I", f.read(4))[0]
        name_table_offset = struct.unpack("<Q", f.read(8))[0]
        if version >= 2:  # Starfield : en-tête plus long
            f.seek(12 if version == 3 else 8, 1)

        files_meta = []
        if header_type == b"GNRL":
            for _ in range(num_files):
                meta = struct.unpack("<IIIIQIII", f.read(36))
                files_meta.append(
                    {
                        "offset": meta[4],
                        "packed_size": meta[5],
                        "real_size": meta[6],
                        "compressed": meta[5] > 0,
                    }
                )
        elif header_type == b"DX10":
            for _ in range(num_files):
                meta = struct.unpack("<IIIBBHHHBBBB", f.read(24))
                chunks = [struct.unpack("<QIIHHI", f.read(24))[:3] for _ in range(meta[4])]
                files_meta.append(
                    {
                        "offset": chunks[0][0] if chunks else 0,
                        "packed_size": sum(c[1] for c in chunks),
                        "real_size": sum(c[2] for c in chunks) + 148,
                        "compressed": any(c[1] for c in chunks),
                        "chunks": chunks,
                        "texture": (meta[7], meta[6], meta[8], meta[9], meta[10]),
                    }
                )

        f.seek(name_table_offset)
        for meta in files_meta:
            name_len = struct.unpack("<H", f.read(2))[0]
            name = (
                f.read(name_len)
                .decode("utf-8", errors="replace")
                .replace("\\", "/")
                .strip("/")
            )
            meta["name"] = name
            meta["size"] = meta["real_size"]
            if meta["name"] and not meta["name"].endswith("/"):
                self.files.append(meta)


# ==============================================================================
# WORKER EXTRACTION
# ==============================================================================


class ExtractWorker(QThread):
    progress = pyqtSignal(int)
    finished = pyqtSignal(int)  # nombre de fichiers extraits
    error = pyqtSignal(str)

    def __init__(self, archive, out_dir):
        super().__init__()
        self.archive = archive
        self.out_dir = out_dir

    def run(self):
        total = len(self.archive.files)
        if total == 0:
            self.finished.emit(0)
            return

        try:
            with open(self.archive.filepath, "rb") as f:
                for idx, item in enumerate(self.archive.files):
                    dest = os.path.join(self.out_dir, item["name"])
                    parent_dir = os.path.dirname(dest)
                    os.makedirs(parent_dir, exist_ok=True)

                    f.seek(item["offset"])

                    if self.archive.archive_type == "BSA":
                        remaining = item["size"]
                        if self.archive.embedded_names:  # nom du fichier répété devant ses données
                            name_len = f.read(1)[0]
                            f.seek(name_len, 1)
                            remaining -= name_len + 1
                        if item["compressed"]:
                            buf_len = f.read(4)
                            if len(buf_len) < 4:
                                continue
                            raw = f.read(remaining - 4)
                            data = lz4.frame.decompress(raw) if self.archive.version >= 105 else zlib.decompress(raw)
                        else:
                            data = f.read(remaining)

                    elif "chunks" in item:
                        parts = [dds_header(*item["texture"])]
                        for offset, packed, full in item["chunks"]:
                            f.seek(offset)
                            parts.append(unpack(f.read(packed), full) if packed else f.read(full))
                        data = b"".join(parts)

                    elif self.archive.archive_type == "BA2":
                        if item["compressed"]:
                            data = unpack(f.read(item["packed_size"]), item["real_size"])
                        else:
                            data = f.read(item["real_size"])

                    if not os.path.isdir(dest):
                        with open(dest, "wb") as out:
                            out.write(data)

                    self.progress.emit(int(((idx + 1) / total) * 100))

            self.finished.emit(total)
        except Exception as e:
            self.error.emit(str(e))


# ==============================================================================
# STYLE GRAPHIQUE
# ==============================================================================

APP_STYLE = """
QMainWindow, QWidget {
    background-color: #1e1e1e;
    color: #dddddd;
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, sans-serif;
    font-size: 13px;
}
QPushButton#primaryOpenBtn {
    background-color: #f59e0b;
    color: #181818;
    font-weight: 700;
    font-size: 12px;
    border: none;
    border-radius: 3px;
    padding: 8px 16px;
}
QPushButton#primaryOpenBtn:hover {
    background-color: #fbbf24;
}
QPushButton#actionCyanBtn {
    background-color: #0ea5e9;
    color: #ffffff;
    font-weight: 700;
    font-size: 12px;
    text-transform: uppercase;
    border: none;
    border-radius: 3px;
    padding: 8px 20px;
}
QPushButton#actionCyanBtn:hover {
    background-color: #0ea5e9;
}
QPushButton#actionCyanBtn:disabled {
    background-color: #303030;
    color: #666666;
}
QTableWidget {
    background-color: #181818;
    border: 1px solid #262626;
    border-radius: 2px;
    gridline-color: transparent;
    color: #dddddd;
}
QTableWidget::item {
    padding-left: 6px;
}
QTableWidget::item:selected {
    background-color: #0ea5e9;
    color: #ffffff;
}
QHeaderView::section {
    background-color: #1a1a1a;
    color: #8f8f8f;
    padding: 6px;
    border: none;
    border-bottom: 1px solid #262626;
    font-weight: 700;
    font-size: 11px;
}
QProgressBar {
    background-color: #181818;
    border: 1px solid #262626;
    border-radius: 2px;
    text-align: center;
    color: #ffffff;
    height: 14px;
    font-size: 10px;
}
QProgressBar::chunk {
    background-color: #0ea5e9;
}
"""


# ==============================================================================
# FENÊTRE PRINCIPALE
# ==============================================================================


class MainWindow(QMainWindow):

    def __init__(self, settings: QSettings):
        super().__init__()
        self.status = (N_("En attente"), {})  # (clé française, paramètres), retraduit au changement de langue
        self.resize(880, 580)
        self.setStyleSheet(APP_STYLE)

        self.setAcceptDrops(True)
        self.current_archive = None

        container = QWidget()
        layout = QVBoxLayout(container)
        layout.setContentsMargins(16, 16, 16, 16)
        layout.setSpacing(12)

        top_bar = QHBoxLayout()
        top_bar.setSpacing(10)

        self.btn_open = QPushButton()
        self.btn_open.setObjectName("primaryOpenBtn")
        self.btn_open.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_open.clicked.connect(self.choose_file)
        top_bar.addWidget(self.btn_open)

        self.lbl_info = QLabel()
        self.lbl_info.setStyleSheet("color: #8f8f8f;")
        top_bar.addWidget(self.lbl_info)
        top_bar.addStretch()
        self.btn_lang = LangButton(settings, self.apply_texts)
        top_bar.addWidget(self.btn_lang)

        layout.addLayout(top_bar)

        self.table = QTableWidget(0, 3)
        self.table.horizontalHeader().setSectionResizeMode(
            0, QHeaderView.ResizeMode.Stretch
        )
        self.table.setColumnWidth(1, 100)
        self.table.setColumnWidth(2, 110)
        self.table.verticalHeader().setVisible(False)
        self.table.setSelectionBehavior(
            QAbstractItemView.SelectionBehavior.SelectRows
        )
        self.table.setShowGrid(False)
        layout.addWidget(self.table)

        self.progress_bar = QProgressBar()
        self.progress_bar.setValue(0)
        layout.addWidget(self.progress_bar)

        bottom_bar = QHBoxLayout()
        self.status_lbl = QLabel()
        self.status_lbl.setStyleSheet("color: #707070;")
        bottom_bar.addWidget(self.status_lbl)

        bottom_bar.addStretch()

        self.btn_extract = QPushButton()
        self.btn_extract.setObjectName("actionCyanBtn")
        self.btn_extract.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_extract.setEnabled(False)
        self.btn_extract.clicked.connect(self.extract_all)
        bottom_bar.addWidget(self.btn_extract)

        layout.addLayout(bottom_bar)
        self.setCentralWidget(container)
        self.apply_texts()

    def apply_texts(self):
        """(Re)traduit l'interface dans la langue active."""
        self.setWindowTitle("mBAE – " + L("Extracteur d'archives Bethesda"))
        self.btn_open.setText("📦 " + L("Ouvrir une archive (.bsa / .ba2)"))
        self.btn_extract.setText(L("EXTRAIRE TOUT"))
        self.table.setHorizontalHeaderLabels([L("Chemin du fichier"), L("Taille brute"), L("Type d'archive")])
        if self.current_archive:
            self.lbl_info.setText(L("{name} — {type} ({n} fichiers)", name=os.path.basename(self.current_archive.filepath),
                                    type=self.current_archive.archive_type, n=len(self.current_archive.files)))
            for row in range(self.table.rowCount()):
                item = self.table.item(row, 2)
                item.setText(self._type_label(item.data(Qt.ItemDataRole.UserRole)))
        else:
            self.lbl_info.setText(L("Glisse-dépose une archive n'importe où ici."))
        self.set_status(*self.status)

    def set_status(self, key, kw=None):
        self.status = (key, kw or {})
        self.status_lbl.setText(L(key, **self.status[1]))

    def _type_label(self, compressed):
        return f"{self.current_archive.archive_type} " + (L("(Comp)") if compressed else L("(Brut)"))

    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()

    def dragMoveEvent(self, event):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()

    def dropEvent(self, event):
        for url in event.mimeData().urls():
            path = url.toLocalFile()
            if path.lower().endswith((".bsa", ".ba2")):
                self.load_archive(path)
                event.acceptProposedAction()
                return

    def choose_file(self):
        file_path, _ = QFileDialog.getOpenFileName(
            self,
            L("Sélectionner une archive Bethesda"),
            "",
            L("Archives Bethesda") + " (*.bsa *.ba2);;" + L("Tous les fichiers") + " (*.*)",
        )
        if file_path:
            self.load_archive(file_path)

    def load_archive(self, path):
        try:
            self.current_archive = BethesdaArchive(path)
            total = len(self.current_archive.files)

            self.lbl_info.setText(L("{name} — {type} ({n} fichiers)", name=os.path.basename(path),
                                    type=self.current_archive.archive_type, n=total))

            self.table.setRowCount(0)
            self.table.setSortingEnabled(False)
            for f in self.current_archive.files[:2500]:
                row = self.table.rowCount()
                self.table.insertRow(row)
                self.table.setItem(row, 0, QTableWidgetItem(f["name"]))
                self.table.setItem(
                    row, 1, QTableWidgetItem(f"{f['size'] / 1024:.1f} KB")
                )
                kind = QTableWidgetItem(self._type_label(f["compressed"]))
                kind.setData(Qt.ItemDataRole.UserRole, f["compressed"])
                self.table.setItem(row, 2, kind)
            self.table.setSortingEnabled(True)

            self.set_status(N_("Prêt pour l'extraction."))
            self.btn_extract.setEnabled(True)
            self.progress_bar.setValue(0)
        except Exception as e:
            self.set_status(N_("Erreur : {err}"), {"err": str(e)})

    def extract_all(self):
        if not self.current_archive:
            return

        dest = QFileDialog.getExistingDirectory(
            self, L("Choisir le dossier de destination")
        )
        if not dest:
            return

        self.btn_extract.setEnabled(False)
        self.btn_open.setEnabled(False)

        self.worker = ExtractWorker(self.current_archive, dest)
        self.worker.progress.connect(self.progress_bar.setValue)
        self.worker.finished.connect(self.on_finished)
        self.worker.error.connect(self.on_error)
        self.worker.start()

    def on_finished(self, total):
        if total:
            self.set_status(N_("Extraction terminée : {n} fichiers extraits."), {"n": total})
        else:
            self.set_status(N_("Archive vide."))
        self.btn_extract.setEnabled(True)
        self.btn_open.setEnabled(True)

    def on_error(self, err):
        self.set_status(N_("Erreur : {err}"), {"err": err})
        self.btn_extract.setEnabled(True)
        self.btn_open.setEnabled(True)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    socle_qt.apply(app, full=False)  # design system Socle
    socle_qt.brand(app, "mBAE", "#21a3d9")  # « m » dans le bleu du logo
    settings = QSettings("mBAE", "mBAE")
    init_lang(settings)
    win = MainWindow(settings)
    win.show()
    updater.start_qt(win, "mBAE", lang=get_lang)  # nouvelle version ? (au plus une fois par jour)
    sys.exit(app.exec())
