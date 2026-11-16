"""Verify latest installed AURAD PDFs and footer before opening Flutter.

Usage: python tool/verify_latest_books.py
This script is read-only; it never edits existing files.
"""
from pathlib import Path
import json
import sys

try:
    import pymupdf
except ImportError:
    print("Missing PyMuPDF; install: python -m pip install pymupdf")
    sys.exit(2)

root=Path(__file__).resolve().parents[1]
downloads=Path.home()/"Downloads"
entries=[
    ("Majlisunnoor original PDF",
     root/"assets/books/majlisunnoor.pdf",17),
    ("Hizbun Nasr original PDF",
     root/"assets/books/hizbun_nasr.pdf",3),
]
manifest=json.loads((root/"assets/data/library.json").read_text(encoding="utf-8"))
items={item["id"]:item for item in manifest["items"]}
errors=[]
for label,filename,expected in entries:
    if not filename.is_file():
        errors.append(f"MISSING {label}: {filename}")
        continue
    try:
        with pymupdf.open(filename) as doc:
            actual=len(doc)
    except Exception as exc:
        errors.append(f"UNREADABLE {filename}: {exc}")
        continue
    if actual!=expected:
        errors.append(f"WRONG PAGE COUNT {filename.name}: {actual} (expected {expected})")
    else:
        print(f"OK: {label}: {filename.name}, {actual} original PDF pages, "
              f"{filename.stat().st_size:,} bytes")
for ident,asset in [
    ("majlisunnoor-1","assets/books/majlisunnoor.pdf"),
    ("dua-4","assets/books/hizbun_nasr.pdf"),
]:
    item=items.get(ident)
    if item is None or item.get("pdfAsset") != asset:
        errors.append(f"WRONG LIBRARY MAPPING: {ident} -> {asset}")
    else:
        print(f"OK: library item {ident} -> {asset}")
footer=root/"assets/images/academy_footer_exact.png"
if not footer.is_file():
    errors.append("MISSING academy footer picture: "+str(footer))
else:
    print(f"OK: academy footer image: {footer.stat().st_size:,} bytes")
if errors:
    print("\n".join(errors))
    print("\nDOWNLOADS FILES (reference only):")
    for part in ("majlisunnoor","hizbu","academy_footer"):
        for x in downloads.glob(f"*{part}*"):
            print(x.name, x.stat().st_size)
    print("Fix missing assets and RESTART Flutter, not hot reload.")
    sys.exit(1)
print("SUCCESS: PDF, mapping and footer files are present.")
print("After installing changed assets: flutter clean; flutter pub get; flutter run -d chrome")
