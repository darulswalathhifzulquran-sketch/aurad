"""Install the user's newest two-page Salam Baith PDF EXACTLY as uploaded.

Save the ChatGPT attachment as 'salam baith .pdf.pdf' in Windows Downloads.
No re-rendering, white patch, page-number removal, footer replacement, or
retyping/repainting of the Arabic. The source PDF is copied byte-for-byte.
"""
from pathlib import Path
import hashlib
import shutil
import sys

try:
    import pymupdf
except ImportError:
    sys.exit("Install pymupdf first: python -m pip install pymupdf")

ROOT = Path(__file__).resolve().parents[1]
DOWNLOADS = Path.home() / "Downloads"
OUT = ROOT / "assets" / "books" / "salam_baith.pdf"

# The latest user attachment has two suffixes: '.pdf.pdf'.
# Do not silently use the older edited 'salam baith .pdf' file.
SOURCE = DOWNLOADS / "salam baith .pdf.pdf"

def digest(path):
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for data in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(data)
    return hasher.hexdigest()

def main():
    if not SOURCE.is_file():
        sys.exit(
            "LATEST SALAM BAITH PDF MISSING. Download the uploaded "
            "'salam baith .pdf.pdf' into Windows Downloads. "
            "No app PDF was changed."
        )
    with pymupdf.open(SOURCE) as doc:
        if not doc.is_pdf or len(doc) != 2:
            sys.exit("Source is not the original two-page Salam Baith PDF. No changes made.")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    if OUT.exists() and digest(OUT) == digest(SOURCE):
        print("EXACT ALREADY INSTALLED:", OUT)
        print("SHA256:", digest(OUT))
        return
    if OUT.exists():
        backup = OUT.with_name("salam_baith.before_exact_install.pdf")
        if not backup.exists():
            shutil.copy2(OUT, backup)
    tmp = OUT.with_name("salam_baith.installing")
    shutil.copyfile(SOURCE, tmp)
    if digest(tmp) != digest(SOURCE):
        tmp.unlink(missing_ok=True)
        sys.exit("Copy checksum mismatch; existing Salam Baith was NOT replaced.")
    tmp.replace(OUT)
    print("SUCCESS: Salam Baith, 2 pages, exact original PDF copied.")
    print("All original page numbers, Arabic text, borders, title and footer preserved.")
    print("SHA256:", digest(OUT))

if __name__ == "__main__":
    main()
