"""Install the user's latest APPROVED Quran source (PDF or ZIP) unchanged.

Save the file last uploaded in this chat ("quran pdf") to Windows Downloads.
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
import re
import pymupdf

ROOT = Path(__file__).resolve().parents[1]
DOWNLOADS = Path.home() / "Downloads"
DEST = ROOT / "quran.pdf"
CANDIDATES = [
    "quran pdf", "quran-new.zip", "quran pdf.zip",
    "quran pdf(8)", "quran pdf(8).zip", "quran pdf(8).pdf",
    "quran pdf (8)", "quran pdf (8).zip", "quran pdf (8).pdf",
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
            "Final upload missing from Downloads. Save 'quran pdf' (or quran-new.zip) from "
            "the ChatGPT attachment to Downloads first. No change made.")
    if not is_zipfile(incoming):
        if check_pdf(incoming) != 604:
            raise RuntimeError(
                f"{incoming.name} is not an exactly 604-page PDF. "
                "No change made.")
        return incoming
    candidates = []
    with ZipFile(incoming) as archive:
        print('ZIP FILE:', incoming.name)
        print('Archive entries:', len(archive.infolist()))
        print('PDF members:', sum(x.filename.lower().endswith('.pdf') for x in archive.infolist()))
        print('Image members:', sum(x.filename.lower().endswith(('.jpg','.jpeg','.png','.webp')) for x in archive.infolist()))
        for member_index, member in enumerate(archive.infolist()):
            if member.is_dir() or not member.filename.lower().endswith(".pdf"):
                continue
            # Avoid traversal and unbounded extraction of untrusted ZIP files.
            if member.file_size > 2 * 1024 * 1024 * 1024 or member.file_size < 1024:
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
    if len(candidates) == 1:
        print("Chosen from ZIP:", candidates[0][0])
        return candidates[0][1]
    if len(candidates) > 1:
        raise RuntimeError(
            "Multiple 604-page PDFs found in ZIP; cannot choose safely. "
            "No changes made.")
    # Some shared Quran downloads are ZIPs containing one high-quality
    # image per page rather than one PDF. Assemble in exact numeric order.
    with ZipFile(incoming) as archive:
        image_members = [member for member in archive.infolist()
                         if not member.is_dir() and
                         member.filename.lower().endswith((".jpg", ".jpeg", ".png"))]
        if len(image_members) != 604:
            sample = [x.filename for x in archive.infolist()[:12]]
            raise RuntimeError(
                f"No 604-page PDF found and ZIP has {len(image_members)} "
                f"image pages (requires 604). Sample entries: {sample}. "
                "Current app Quran was NOT changed.")
        def numeric_key(member):
            stem = Path(member.filename).stem
            nums = re.findall(r"\d+", stem)
            return int(nums[-1]) if nums else None
        keys = [numeric_key(member) for member in image_members]
        if any(k is None for k in keys) or len(set(keys)) != 604:
            raise RuntimeError(
                "The 604 image filenames do not contain unique page numbers. "
                "Cannot safely determine Quran page order; existing Quran unchanged.")
        image_members.sort(key=numeric_key)
        ordered_keys = [numeric_key(x) for x in image_members]
        if ordered_keys not in [list(range(1, 605)), list(range(604))]:
            raise RuntimeError(
                f"Image filenames do not form uninterrupted page numbers "
                f"1-604 (or 0-603). First={ordered_keys[:5]}, "
                f"last={ordered_keys[-5:]}. Current Quran unchanged.")
        target = working / "approved_quran_from_images.pdf"
        document = pymupdf.open()
        for index, member in enumerate(image_members):
            with archive.open(member) as image_file:
                image_bytes = image_file.read()
            # The original image is inserted at its native pixel dimensions;
            # no OCR, border replacement, downsampling or text rewriting.
            try:
                pix = pymupdf.Pixmap(image_bytes)
                width, height = pix.width, pix.height
            except Exception as exc:
                document.close()
                raise RuntimeError(
                    f"Failed reading image page {index+1}: {exc}")
            if width < 300 or height < 500:
                document.close()
                raise RuntimeError(
                    f"Unusually small Quran page image {member.filename}: "
                    f"{width}x{height}; stopped without changing app.")
            page = document.new_page(width=width * .75, height=height * .75)
            page.insert_image(page.rect, stream=image_bytes, keep_proportion=True)
            if (index + 1) % 100 == 0:
                print(f"Imported {index + 1}/604 full-resolution pages")
        document.save(str(target), garbage=3, deflate=True)
        document.close()
        print("Constructed 604-page PDF from the ORIGINAL archive images.")
        return target

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
