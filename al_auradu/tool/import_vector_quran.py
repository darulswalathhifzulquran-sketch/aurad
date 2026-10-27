#!/usr/bin/env python3
"""Assemble the owner's 604 ORIGINAL Hafs AI vector pages into a PDF.

No Qur'anic text is typed, inferred, OCR'd, corrected, recolored or replaced.
Each original AI page must convert to a single PDF page with vectors intact.

Input:  the owner-supplied official 1441-AI-hafs.zip (604 numbered .ai files).
Output: assets/books/quran_vector_604.pdf   (needs Git LFS before commit)

This script intentionally does NOT use the OLD 624-page scanned quran.pdf.
It intentionally does NOT retype any Quran content or use generated images.
If a conversion is incompatible, it STOPS rather than silently rasterizing.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

try:
    import fitz  # PyMuPDF
except ImportError:
    sys.exit("Install converter dependency: python3 -m pip install PyMuPDF")

APP_ROOT = Path(__file__).resolve().parents[1]
OUTPUT = APP_ROOT / "assets" / "books" / "quran_vector_604.pdf"
MANIFEST = APP_ROOT / "assets" / "data" / "quran_vector_604_manifest.json"
EXACT_COUNT = 604
NUMBER = re.compile(r"^(\d{3})_+Hafs\d+_DM\.ai$", re.IGNORECASE)


def identify_pages(z: zipfile.ZipFile) -> dict[int, zipfile.ZipInfo]:
    pages: dict[int, zipfile.ZipInfo] = {}
    for info in z.infolist():
        if info.is_dir():
            continue
        name = Path(info.filename.replace("\\", "/")).name
        match = NUMBER.fullmatch(name)
        if not match:
            continue
        number = int(match.group(1))
        if number in pages:
            raise ValueError(f"Duplicate Quran page number: {number}")
        pages[number] = info

    expected = set(range(1, EXACT_COUNT + 1))
    if set(pages) != expected:
        missing = sorted(expected - set(pages))
        extra = sorted(set(pages) - expected)
        raise ValueError(
            f"Expected exactly numbered pages 001–604; "
            f"missing={missing[:20]}, unexpected={extra[:20]}"
        )
    return pages


def open_vector_page(data: bytes, number: int, temp: Path) -> "fitz.Document":
    # Most PDF-compatible Illustrator AI documents start with %PDF and can be
    # imported directly. No rasterization and no font re-typing take place.
    if data.lstrip().startswith(b"%PDF-"):
        doc = fitz.open(stream=data, filetype="pdf")
    else:
        # Some genuine Illustrator AI files use legacy PostScript syntax.
        # Inkscape handles those cases as vectors when supported.
        inkscape = shutil.which("inkscape")
        if inkscape is None:
            raise RuntimeError(
                f"Page {number:03d} is not PDF-compatible AI. "
                "Install Inkscape to import it; do NOT export as PNG/JPG."
            )
        ai = temp / f"{number:03d}.ai"
        pdf = temp / f"{number:03d}.pdf"
        ai.write_bytes(data)
        proc = subprocess.run(
            [inkscape, str(ai), "--export-type=pdf",
             f"--export-filename={pdf}"],
            capture_output=True,
            text=True,
            timeout=120,
        )
        if proc.returncode or not pdf.is_file() or pdf.stat().st_size == 0:
            raise RuntimeError(
                f"Inkscape vector PDF conversion failed on "
                f"{number:03d}: {proc.stderr[:1000]}"
            )
        doc = fitz.open(pdf)

    if doc.page_count != 1:
        doc.close()
        raise ValueError(f"AI file {number:03d} did not produce exactly 1 PDF page")
    if doc[0].rect.is_empty:
        doc.close()
        raise ValueError(f"AI file {number:03d} has an empty page rectangle")
    return doc


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "archive",
        type=Path,
        help="the original King Fahd Complex 1441-AI-hafs ZIP",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=OUTPUT,
        help="where the assembled vector PDF is written",
    )
    args = parser.parse_args()
    archive = args.archive.expanduser().resolve()
    if not archive.is_file():
        sys.exit(f"Missing original owner-supplied ZIP: {archive}")
    if not zipfile.is_zipfile(archive):
        sys.exit("Source is not a ZIP archive. Do not proceed.")
    out_path = args.output.expanduser().resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if out_path.exists():
        sys.exit(
            f"Output already exists: {out_path}. Preserve it and "
            "use a new output location to prevent accidental overwrite."
        )

    sha = hashlib.sha256()
    with archive.open("rb") as incoming:
        for chunk in iter(lambda: incoming.read(1024 * 1024), b""):
            sha.update(chunk)

    with zipfile.ZipFile(archive) as z:
        pages = identify_pages(z)
        dest = fitz.open()
        temp_pdf = out_path.with_suffix(".assembling.pdf")
        try:
            with tempfile.TemporaryDirectory(prefix="aurad-vector-ai-") as t:
                for n in range(1, EXACT_COUNT + 1):
                    raw = z.read(pages[n])
                    original = open_vector_page(raw, n, Path(t))
                    try:
                        # Preserves page's original vector art, lettering,
                        # verse medallions and diacritics EXACTLY as supplied.
                        dest.insert_pdf(original, from_page=0, to_page=0,
                                        links=False, annots=False)
                    finally:
                        original.close()
                    if n % 25 == 0 or n in (1, 2, EXACT_COUNT):
                        print(f"Imported unmodified original page {n}/604",
                              flush=True)

            if dest.page_count != EXACT_COUNT:
                raise ValueError("Merged Quran PDF failed 604-page count")
            dest.save(temp_pdf, garbage=3, deflate=True)
        except Exception:
            if temp_pdf.exists():
                temp_pdf.unlink()
            raise
        finally:
            dest.close()

    # Re-open assembled file to verify PDF count/headers/physical size.
    with fitz.open(temp_pdf) as proof:
        if proof.page_count != EXACT_COUNT:
            temp_pdf.unlink(missing_ok=True)
            sys.exit("Assembled Quran file has wrong PDF page count.")

    temp_pdf.replace(out_path)
    record = {
        "source_archive": archive.name,
        "source_sha256": sha.hexdigest(),
        "source_page_count": EXACT_COUNT,
        "output_pdf": out_path.name,
        "output_bytes": out_path.stat().st_size,
        "source": "King Fahd Complex Hafs 1441 official AI pages",
        "processing": "Vector-preserving PDF page merge, no Quran text edits",
        "review_status": "UNVERIFIED: owner must visually proofread page mappings",
    }
    # Save report next to destination, not in Flutter assets until reviewed.
    report = out_path.with_name(out_path.stem + ".import_report.json")
    report.write_text(json.dumps(record, indent=2, ensure_ascii=False),
                      encoding="utf-8")
    print(f"SUCCESS: {out_path} ({record['output_bytes']} bytes)")
    print(f"Source SHA256: {sha.hexdigest()}")
    print("IMPORTANT: human-verify pages 1, 2, 128, 582, 604 and 114 Surah")
    print("starts + 30 Juz starts before approving this Quran release.")


if __name__ == "__main__":
    main()
