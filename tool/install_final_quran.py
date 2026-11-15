"""Install the user's FINAL approved Qur'an PDF without modifying a page.

Put the last supplied Qur'an PDF in Downloads as "quran pdf(7)"
(or quran pdf(7).pdf) and run:
    python tool/install_final_quran.py

The script verifies 604 pages and copies the EXACT original file bytes to
Flutter's already configured quran.pdf asset. It does not rebuild borders,
re-render pages, modify Surah/Juz/ayah details or touch any other app section.
"""
from pathlib import Path
from shutil import copyfile
import hashlib
import fitz

ROOT = Path(__file__).resolve().parents[1]
DOWNLOADS = Path.home() / "Downloads"
DEST = ROOT / "quran.pdf"
CANDIDATES = [
    "quran pdf(7)", "quran pdf(7).pdf",
    "quran pdf (7)", "quran pdf (7).pdf",
    "final_quran.pdf", "quran_final_approved.pdf",
]

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def main():
    source = next((DOWNLOADS / name for name in CANDIDATES
                   if (DOWNLOADS / name).is_file()), None)
    if source is None:
        raise SystemExit(
            "Final Quran source not found. Save the last approved upload as "
            "Downloads\\quran pdf(7) (or quran pdf(7).pdf). "
            "The current app Quran was NOT changed.")
    try:
        document = fitz.open(str(source), filetype="pdf")
        pages = len(document)
        document.close()
    except Exception as exc:
        raise SystemExit(f"Cannot open the final PDF: {exc}. App unchanged.")
    if pages != 604:
        raise SystemExit(
            f"Final PDF contains {pages} pages, not 604. "
            "Stopped without changing app. Please use the 604-page source.")
    if DEST.exists() and sha256(DEST) == sha256(source):
        print("ALREADY INSTALLED: quran.pdf matches final source bit-for-bit.")
        return
    backup = ROOT / "quran.before_final_user_pdf_backup.pdf"
    if DEST.exists() and not backup.exists():
        copyfile(DEST, backup)
        print("BACKUP:", backup)
    tmp = ROOT / "quran.final_user_pdf.tmp"
    copyfile(source, tmp)
    if sha256(tmp) != sha256(source):
        tmp.unlink(missing_ok=True)
        raise SystemExit("Copy verification failed; app unchanged.")
    tmp.replace(DEST)
    print("SUCCESS: Final approved Quran PDF installed without editing its pages.")
    print("FROM:", source)
    print("TO:", DEST)
    print("PAGES:", pages)
    print("SHA256:", sha256(DEST))

if __name__ == "__main__":
    main()
