"""Install the two ORIGINAL PDFs supplied on 2026-11-16.

Download majlisunnoor(1).pdf, hizbu nnasr(1).pdf from this conversation
to Windows Downloads (or copy them to the project root).
Run: python tool/install_latest_books.py

Preserves every byte of the original Arabic and page design.
Only the reader's shared academy-footer overlay changes visually.
"""
from pathlib import Path
import hashlib
import shutil
import pymupdf

ROOT=Path(__file__).resolve().parents[1]
DOWNLOADS=Path.home()/"Downloads"
DEST=ROOT/"assets"/"books"

BOOKS=(
    (("majlisunnoor(1).pdf",),"majlisunnoor.pdf",17),
    (("hizbu nnasr(1).pdf",),"hizbun_nasr.pdf",3),
)

def filehash(p):
    h=hashlib.sha256()
    with p.open("rb") as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b""):
            h.update(chunk)
    return h.hexdigest()

def locate(names):
    for folder in (DOWNLOADS,ROOT):
        for name in names:
            found=folder/name
            if found.is_file():
                return found
    return None

def main():
    jobs=[]
    for names, output_name, expected_pages in BOOKS:
        src=locate(names)
        if src is None:
            raise SystemExit(
                "MISSING SOURCE: "+names[0]+"; download the original "
                "PDF supplied in this conversation into Downloads. "
                "Existing app files were NOT changed.")
        try:
            with pymupdf.open(src) as book:
                pages=len(book)
                valid=book.is_pdf and pages==expected_pages
        except Exception as exc:
            raise SystemExit(f"Invalid PDF {src}: {exc}. No changes made.")
        if not valid:
            raise SystemExit(
                f"{src.name}: got {pages} pages; expected {expected_pages}. "
                "No files were changed.")
        jobs.append((src,DEST/output_name,pages))
    DEST.mkdir(parents=True,exist_ok=True)
    for src,dst,pages in jobs:
        if dst.exists() and filehash(dst)==filehash(src):
            print("ALREADY INSTALLED:",dst.name,pages,"pages")
            continue
        if dst.exists():
            backup=dst.with_name(dst.stem+".before_new_upload.pdf")
            if not backup.exists():
                shutil.copy2(dst,backup)
        temp=dst.with_name(dst.name+".tmp")
        shutil.copyfile(src,temp)
        if filehash(temp)!=filehash(src):
            temp.unlink(missing_ok=True)
            raise RuntimeError("File hash verification failed: "+src.name)
        temp.replace(dst)
        print("SUCCESS:",dst.name,pages,"original PDF pages, unmodified.")
    print("READY: Both latest books are connected in assets/data/library.json")

if __name__=="__main__":
    main()
