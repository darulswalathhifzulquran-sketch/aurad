"""Read-only quality audit of the existing Git LFS Mushaf PDF.

Reports the exact page count, visible text elements, font info, image coverage,
and embedded-image sizes on representative pages. Never changes Quran text.
This is a structural check, NOT a religious content certification.
"""
from pathlib import Path
import json
import sys

import fitz

SOURCE = Path(__file__).resolve().parents[1] / "quran.pdf"
if not SOURCE.exists():
    sys.exit("FAIL: quran.pdf is missing; use git lfs pull in Codespaces.")

size = SOURCE.stat().st_size
if size < 1_000_000 or SOURCE.open("rb").read(5) != b"%PDF-":
    sys.exit("FAIL: quran.pdf is a Git LFS pointer or is not a real PDF.")

doc = fitz.open(SOURCE)
print("MUSHAF_PDF_AUDIT: file_size_bytes=", size)
print("MUSHAF_PDF_AUDIT: pages=", len(doc))
if len(doc) != 604:
    sys.exit(
        "FAIL: Surah/Juz offsets were written for Madinah 604 pages, "
        f"but this Quran PDF contains {len(doc)} PDF pages."
    )

samples = [0, 1, 127, 581, 603]
records = []
for p in samples:
    page = doc[p]
    rect = page.rect
    fonts = sorted({tuple(f[3:5]) for f in page.get_fonts(full=True)})
    chars = len(page.get_text())
    image_coverage = 0.0
    image_count = 0
    for image in page.get_images(full=True):
        xs = page.get_image_rects(image[0])
        for ir in xs:
            image_count += 1
            intersection = (ir & rect)
            image_coverage += max(0, intersection.get_area()) / max(1, rect.get_area())
    image_coverage = min(1.0, image_coverage)
    record = {
        "pdf_page": p + 1,
        "width_pt": round(rect.width, 2),
        "height_pt": round(rect.height, 2),
        "extracted_text_characters": chars,
        "embedded_font_count": len(fonts),
        "image_placements": image_count,
        "image_page_coverage_estimate": round(image_coverage, 4),
        "vector_text_likely": chars > 60 and image_coverage < 0.6,
    }
    records.append(record)
    print("MUSHAF_PDF_PAGE_AUDIT:", json.dumps(record, ensure_ascii=False))

likely_scanned = sum(x["vector_text_likely"] is False for x in records)
if likely_scanned:
    print(
        "QUALITY_WARNING: The sampled PDF pages do not all contain clearly "
        "detectable vector text. Scanned pages can blur at large zoom. "
        "This test CANNOT prove unlimited zoom clarity."
    )
else:
    print(
        "QUALITY_INDICATOR: Sampled pages appear to include selectable "
        "vector text, but a full visual Quran/harakat audit is still required."
    )
print(
    "RELEASE_GATE: Visual human review of the exact Surah/Juz boundaries "
    "(PDF pages 1, 2, 128, 582, 604) is still required. "
    "A 604-page count alone does not establish the Mushaf edition."
)
doc.close()
