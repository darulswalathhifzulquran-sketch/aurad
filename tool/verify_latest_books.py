"""Verify latest installed AURAD PDFs and footer before opening Flutter.

Usage: python tool/verify_latest_books.py
This script is read-only; it never edits existing files.
"""
from pathlib import Path
import json
import sys
import hashlib

try:
    import pymupdf
except ImportError:
    print("Missing PyMuPDF; install: python -m pip install pymupdf")
    sys.exit(2)

root=Path(__file__).resolve().parents[1]
downloads=Path.home()/"Downloads"
entries=[
    ("Majlisunnoor original PDF",
     root/"assets/books/majlisunnoor.pdf",17,
     downloads/"majlisunnoor(1).pdf"),
    ("Hizbun Nasr original PDF",
     root/"assets/books/hizbun_nasr.pdf",3,
     downloads/"hizbu nnasr(1).pdf"),
]

def digest(path):
    h=hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda:stream.read(1024*1024),b""):
            h.update(block)
    return h.hexdigest()

manifest=json.loads((root/"assets/data/library.json").read_text(encoding="utf-8"))
items={item["id"]:item for item in manifest["items"]}
errors=[]
for label,filename,expected,original in entries:
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
    if not original.is_file():
        errors.append(f"ORIGINAL NOT AVAILABLE for byte-level check: {original}")
    elif digest(original)!=digest(filename):
        errors.append(
            f"NOT ORIGINAL: {filename.name} differs from {original.name}. "
            "Re-run install_latest_books.py to restore the unmodified PDF "
            "including its printed page numbers and embedded footer.")
    else:
        print(
            f"EXACT BYTE MATCH: {filename.name} == {original.name} "
            f"(SHA256 {digest(filename)[:16]}...)")
for ident,asset in [
    ("majlisunnoor-1","assets/books/majlisunnoor.pdf"),
    ("dua-4","assets/books/hizbun_nasr.pdf"),
]:
    item=items.get(ident)
    if item is None or item.get("pdfAsset") != asset:
        errors.append(f"WRONG LIBRARY MAPPING: {ident} -> {asset}")
    else:
        print(f"OK: library item {ident} -> {asset}")
# The two user-uploaded PDFs carry their OWN original footer and
# printed page numbers. A separate app footer is not required for them.
if errors:
    print("\n".join(errors))
    print("\nDOWNLOADS FILES (reference only):")
    for part in ("majlisunnoor","hizbu","academy_footer"):
        for x in downloads.glob(f"*{part}*"):
            print(x.name, x.stat().st_size)
    print("Fix missing assets and RESTART Flutter, not hot reload.")
    sys.exit(1)
print("SUCCESS: Both installed PDFs are byte-for-byte identical to the two user uploads.")
print("After installing changed assets: flutter clean; flutter pub get; flutter run -d chrome")
