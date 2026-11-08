"""Safely install the USER SELECTED unchanged Quran PDF in the Flutter app.

Run: python tool/install_user_quran.py
Choose the exact Quran PDF downloaded from ChatGPT (not any old quran.pdf).
Keeps a backup, checks 604 pages, and never uses any merged V1-V14 PDF.
Both Flutter light and dark modes use this SAME source PDF.
"""
from pathlib import Path
import shutil
import sys
import tempfile
import zipfile
import re

import pymupdf

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "quran.pdf"

def choose():
    if len(sys.argv) > 1:
        return Path(sys.argv[1]).expanduser()
    try:
        import tkinter as tk
        from tkinter import filedialog
        root = tk.Tk()
        root.withdraw()
        root.attributes("-topmost", True)
        value = filedialog.askopenfilename(
            title="SELECT YOUR NEW ORIGINAL QURAN (PDF or AI ZIP), not old or preview",
            initialdir=str(Path.home() / "Downloads"),
            filetypes=[
                ("Quran PDF or Illustrator ZIP", "*.pdf *.zip"),
                ("All files", "*.*"),
            ])
        root.destroy()
    except Exception as exc:
        raise SystemExit("Could not open file picker; pass full file path: "+str(exc))
    return Path(value) if value else None

def numeric_name(name):
    return [int(x) if x.isdigit() else x.casefold()
            for x in re.split(r"(\d+)", name)]

def install():
    selected = choose()
    if selected is None:
        print("Cancelled. Existing quran.pdf unchanged.")
        return
    if not selected.is_file():
        raise SystemExit("Selected file not found: " + str(selected))
    if selected.resolve() == TARGET.resolve():
        raise SystemExit("Selected existing app quran.pdf; choose the NEW downloaded file.")
    with tempfile.TemporaryDirectory(prefix="aurad_quran_") as folder:
        output = Path(folder) / "verified_quran.pdf"
        with selected.open("rb") as stream:
            magic = stream.read(5)
        if magic == b"%PDF-":
            print("Selected PDF:", selected)
            shutil.copyfile(selected, output)
        elif zipfile.is_zipfile(selected):
            print("Selected Illustrator ZIP:", selected)
            with zipfile.ZipFile(selected) as zipped:
                items = sorted(
                    (i for i in zipped.infolist()
                     if not i.is_dir() and i.filename.lower().endswith(".ai")),
                    key=lambda i: numeric_name(i.filename))
                if len(items) != 604:
                    raise SystemExit(
                        f"ZIP must contain exactly 604 Illustrator pages; got {len(items)}."
                    )
                doc = pymupdf.open()
                try:
                    for number, member in enumerate(items, 1):
                        with pymupdf.open(
                            stream=zipped.read(member), filetype="pdf"
                        ) as source:
                            if len(source) != 1:
                                raise ValueError(f"Bad page {number}")
                            doc.insert_pdf(source)
                        if number % 100 == 0:
                            print(f"Imported {number}/604 source pages", flush=True)
                    doc.save(output, garbage=3, deflate=True)
                finally:
                    doc.close()
        else:
            raise SystemExit("Selected file is not PDF or a 604-page Illustrator ZIP.")
        with pymupdf.open(output) as doc:
            if len(doc) != 604:
                raise SystemExit(f"Expected 604 pages; found {len(doc)}. No changes made.")
            for index in (0, 2, 207, 251, 603):
                if doc[index].rect.is_empty:
                    raise SystemExit(f"Invalid page: {index+1}")
            print("Verified exactly 604 pages, valid PDF.")
        if TARGET.exists():
            backup = ROOT / "quran_before_new_source_backup.pdf"
            if not backup.exists():
                shutil.copy2(TARGET, backup)
                print("Backup saved:", backup)
        # Atomic replace on Windows: temp placed in SAME directory.
        temp = ROOT / "quran_pending_install.pdf"
        shutil.copyfile(output, temp)
        temp.replace(TARGET)
        print("SUCCESS: Installed exact source page design as", TARGET)
        print("Light/dark display handled by Flutter: source PDF is NOT recolored.")
        print("NEXT: flutter clean ; flutter pub get ; flutter run -d chrome")

if __name__ == "__main__":
    install()
