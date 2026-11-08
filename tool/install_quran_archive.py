#!/usr/bin/env python3
"""Safely install a sharper 604-page Quran PDF from a downloaded ZIP/PDF.

Usage: python tool/install_quran_archive.py [source.zip]
Never alters verse text, page order, or artwork. Requires: pip install pymupdf.
"""
import re
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

try:
    import pymupdf as fitz
except ImportError:
    sys.exit("Missing PyMuPDF. Run: python -m pip install pymupdf")

PROJECT = Path(__file__).resolve().parents[1]
TARGET = PROJECT / "quran.pdf"
COUNT = 604
IMAGES = {".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff"}


def natural_key(name):
    return [int(x) if x.isdigit() else x.casefold()
            for x in re.split(r"(\d+)", str(name))]


def choose_source():
    if len(sys.argv) > 1:
        p = Path(sys.argv[1]).expanduser()
        if not p.is_file():
            sys.exit(f"File not found: {p}")
        return p
    roots = [Path.home() / "Downloads", PROJECT]
    options = []
    for folder in roots:
        if not folder.is_dir():
            continue
        for p in folder.iterdir():
            if not p.is_file() or "quran" not in p.name.casefold():
                continue
            if p.resolve() == TARGET.resolve():
                continue
            if p.stat().st_size < 100_000:
                continue
            try:
                with p.open("rb") as stream:
                    is_pdf = stream.read(5) == b"%PDF-"
                if zipfile.is_zipfile(p) or is_pdf:
                    options.append(p)
            except OSError:
                pass
    if not options:
        sys.exit("No Quran ZIP/PDF found in Downloads. Pass full path as argument.")
    options.sort(key=lambda p: (zipfile.is_zipfile(p), p.stat().st_size,
                                p.stat().st_mtime), reverse=True)
    print("Detected source:", options[0])
    return options[0]


def quality(path):
    with fitz.open(path) as doc:
        if len(doc) != COUNT:
            raise ValueError(f"Expected 604 pages, found {len(doc)}")
        values = []
        for n in (3, 99, 251, 499):
            page = doc[n]
            images = page.get_images(full=True)
            pixels = max((im[2] * im[3] for im in images), default=0)
            vector = len(page.get_text().strip()) > 15 or len(page.get_drawings()) > 30
            values.append((pixels, vector))
        avg_pixels = sum(p for p, _ in values) / len(values)
        vector = sum(1 for _, v in values if v) >= 3
        return (vector, avg_pixels)


def extract_zip(source, destination):
    with zipfile.ZipFile(source) as z:
        files = [i for i in z.infolist()
                 if not i.is_dir() and not Path(i.filename).name.startswith(".")
                 and "__MACOSX" not in i.filename]
        pdfs = [i for i in files if Path(i.filename).suffix.lower() == ".pdf"]
        imgs = [i for i in files if Path(i.filename).suffix.lower() in IMAGES]
        print(f"ZIP contents: {len(pdfs)} PDFs, {len(imgs)} image files, "
              f"{sum(Path(i.filename).suffix.lower() == '.ai' for i in files)} Illustrator pages")
        if pdfs:
            checked = []
            for info in sorted(pdfs, key=lambda x: x.file_size, reverse=True):
                if info.file_size > 1_500_000_000:
                    continue
                candidate = destination.parent / "_quran_candidate.pdf"
                with z.open(info) as inp, candidate.open("wb") as out:
                    shutil.copyfileobj(inp, out)
                try:
                    q = quality(candidate)
                    checked.append((q, info.filename))
                    if not destination.exists() or q > quality(destination):
                        shutil.copy2(candidate, destination)
                except Exception as exc:
                    print(f"Skipping {info.filename}: {exc}")
            if destination.exists():
                print("Validated PDF candidates:", checked)
                return
        # Illustrator can save AI files with embedded PDF-compatible data.
        # Attempt direct vector conversion first: no rasterization, no OCR.
        ai_pages = [i for i in files
                    if Path(i.filename).suffix.lower() == ".ai"]
        if len(ai_pages) == COUNT:
            print("Found 604 Adobe Illustrator pages. Checking PDF compatibility...")
            ai_pages.sort(key=lambda i: natural_key(i.filename))
            out = fitz.open()
            try:
                for i, info in enumerate(ai_pages, 1):
                    with z.open(info) as stream:
                        data = stream.read()
                    try:
                        one = fitz.open(stream=data, filetype="pdf")
                    except Exception as exc:
                        raise ValueError(
                            f"Illustrator page {i} ({info.filename}) cannot be "
                            "read as PDF-compatible vector data. Open the AI "
                            "files in Adobe Illustrator and export as PDF with "
                            "vector quality; no replacement was made."
                        ) from exc
                    try:
                        if one.needs_pass:
                            raise ValueError(f"Password-protected Illustrator page {i}")
                        if len(one) != 1:
                            raise ValueError(
                                f"Illustrator page {i} contains {len(one)} PDF pages, not 1"
                            )
                        out.insert_pdf(one)
                    finally:
                        one.close()
                    if i % 50 == 0:
                        print(f"Combined {i}/604 vector pages", flush=True)
                out.save(destination, garbage=3, deflate=True)
            finally:
                out.close()
            return
        if len(pdfs) == COUNT:
            print("Combining 604 individual PDF pages")
            out = fitz.open()
            try:
                for i, info in enumerate(sorted(pdfs, key=lambda x: natural_key(x.filename)), 1):
                    data = z.read(info)
                    one = fitz.open(stream=data, filetype="pdf")
                    try:
                        if len(one) != 1:
                            raise ValueError(f"Expected one page in {info.filename}")
                        out.insert_pdf(one)
                    finally:
                        one.close()
                    if i % 100 == 0:
                        print(f"Combined {i}/604 pages")
                out.save(destination, garbage=3, deflate=True)
            finally:
                out.close()
            return
        if len(imgs) != COUNT:
            raise ValueError(
                f"No 604-page PDF or exactly 604 images. Found {len(imgs)} images. "
                "Source not installed; original Quran remains unchanged."
            )
        imgs.sort(key=lambda i: natural_key(i.filename))
        out = fitz.open()
        try:
            for i, info in enumerate(imgs, 1):
                data = z.read(info)
                img = fitz.open(stream=data, filetype=Path(info.filename).suffix[1:])
                try:
                    pdf_data = img.convert_to_pdf()
                    temp = fitz.open("pdf", pdf_data)
                    try:
                        out.insert_pdf(temp)
                    finally:
                        temp.close()
                finally:
                    img.close()
                if i % 100 == 0:
                    print(f"Converted {i}/604 pages")
            out.save(destination, garbage=3, deflate=True)
        finally:
            out.close()


def main():
    source = choose_source()
    print("Source size (MB):", round(source.stat().st_size / 1_048_576))
    with tempfile.TemporaryDirectory(prefix="quran_verified_") as folder:
        candidate = Path(folder) / "verified.pdf"
        if zipfile.is_zipfile(source):
            extract_zip(source, candidate)
        elif source.suffix.lower() == ".pdf":
            shutil.copy2(source, candidate)
        else:
            sys.exit("Source is neither ZIP nor PDF.")
        newq = quality(candidate)
        print("New source quality (vector, average image pixels):", newq)
        if TARGET.exists() and TARGET.stat().st_size > 100000:
            try:
                oldq = quality(TARGET)
                print("Existing Quran quality:", oldq)
                if newq <= oldq:
                    sys.exit("New source is not measurably sharper. Original PDF kept.")
            except Exception as e:
                print("Existing PDF inspection:", e)
            backup = PROJECT / "quran_original_backup.pdf"
            if not backup.exists():
                shutil.copy2(TARGET, backup)
                print("Backed up original to:", backup)
        shutil.copy2(candidate, TARGET)
    print("SUCCESS: Installed verified 604-page Quran at:", TARGET)
    print("Note: Existing dark-mode PDF is unchanged.")


if __name__ == "__main__":
    main()
