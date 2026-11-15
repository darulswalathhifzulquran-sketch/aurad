"""Install the user's latest APPROVED Quran source (PDF or ZIP) unchanged.

Save the file last uploaded in this chat ("quran pdf(7)") to Windows Downloads.
Then run: python tool/install_final_quran.py

The supplied file was an archive. Search its PDF members for exactly 604 pages
and install ONLY a unique verified 604-page source. Never rebuild decorations,
remove text, alter page order or overwrite the existing Quran on failure.
"""
from pathlib import Path
from shutil import copyfile
from tempfile import TemporaryDirectory
from zipfile import ZipFile, is_zipfile
from hashlib import sha256
import pymupdf

ROOT = Path(__file__).resolve().parents[1]
DOWNLOADS = Path.home() / "Downloads"
DEST = ROOT / "quran.pdf"
CANDIDATES = [
    "quran pdf(7)", "quran pdf(7).zip", "quran pdf(7).pdf",
    "quran pdf (7)", "quran pdf (7).zip", "quran pdf (7).pdf",
    "final_quran.pdf", "quran_final_approved.pdf",
]

def digest(path):
    h = sha256()
    with open(path, "rb") as file:
        for block in iter(lambda: file.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

def check_pdf(path):
    try:
        doc = pymupdf.open(str(path), filetype="pdf")
        pages = len(doc)
        doc.close()
        return pages
    except Exception:
        return None

def find_source(working):
    incoming = next((DOWNLOADS / name for name in CANDIDATES
                     if (DOWNLOADS / name).is_file()), None)
    if incoming is None:
        raise RuntimeError(
            "Final upload missing from Downloads. Save 'quran pdf(7)' from "
            "the ChatGPT attachment to Downloads first. No change made.")
    if not is_zipfile(incoming):
        if check_pdf(incoming) != 604:
            raise RuntimeError(
                f"{incoming.name} is not an exactly 604-page PDF. "
                "No change made.")
        return incoming
    candidates = []
    with ZipFile(incoming) as archive:
        for member_index, member in enumerate(archive.infolist()):
            if member.is_dir() or not member.filename.lower().endswith(".pdf"):
                continue
            # Avoid traversal and unbounded extraction of untrusted ZIP files.
            if member.file_size > 400 * 1024 * 1024 or member.file_size < 1024:
                continue
            path = working / f"candidate_{member_index}.pdf"
            with archive.open(member) as src, open(path, "wb") as dst:
                while True:
                    data = src.read(1024 * 1024)
                    if not data:
                        break
                    dst.write(data)
            pages = check_pdf(path)
            print(f"Archive PDF: {member.filename} ({pages} pages)")
            if pages == 604:
                candidates.append((member.filename, path))
    if len(candidates) != 1:
        raise RuntimeError(
            f"Expected exactly ONE 604-page Quran PDF in ZIP, found "
            f"{len(candidates)}. No changes made. Select the intended "
            "604-page file manually if the ZIP has multiple.")
    print("Chosen from ZIP:", candidates[0][0])
    return candidates[0][1]

def main():
    with TemporaryDirectory(prefix="aurad_quran_") as tmp:
        source = find_source(Path(tmp))
        if DEST.exists() and digest(source) == digest(DEST):
            print("ALREADY INSTALLED: final Quran matches quran.pdf exactly.")
            return
        backup = ROOT / "quran.before_final_user_pdf_backup.pdf"
        if DEST.is_file() and not backup.exists():
            copyfile(DEST, backup)
            print("BACKUP:", backup)
        temp = ROOT / "quran.final_import.tmp"
        copyfile(source, temp)
        if digest(temp) != digest(source) or check_pdf(temp) != 604:
            temp.unlink(missing_ok=True)
            raise RuntimeError("Verification failed; existing Quran unchanged.")
        temp.replace(DEST)
        print("SUCCESS: exact 604-page Quran installed in", DEST)
        print("FILE SHA256:", digest(DEST))
        print("No Quran page or decoration was edited.")

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        raise SystemExit(f"STOPPED SAFELY: {exc}")
