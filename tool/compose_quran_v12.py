"""Quran V12 preview — no green fill, no old-text overlay, no cut-off lines.

Only pages 3, 208, 252 are previewed. The original quran.pdf and
quran_vector_candidate.pdf remain untouched.

Run: python tool/compose_quran_v12.py
"""
import io
from pathlib import Path

import pymupdf as fitz
from compose_quran_clean_vector import page_svg_as_pdf

ROOT = Path(__file__).resolve().parents[1]
OLD = ROOT / "quran.pdf"
VECTOR = ROOT / "quran_vector_candidate.pdf"
OUT = ROOT / "quran_v12_preview.pdf"
PAGES = (3, 208, 252)

# All coordinates normalized to full page. The middle of the old source is
# NEVER included, so there is no second copy of blurry Arabic.
# Region dimensions are the SAME on destination and source for strips.
TOP = (0.00, 0.00, 1.00, 0.146)
BOTTOM = (0.00, 0.872, 1.00, 1.00)
LEFT = (0.00, 0.146, 0.171, 0.872)
RIGHT = (0.829, 0.146, 1.00, 0.872)

# Inset the vector Quran inside the actual blue frame. A tiny gap prevents
# Arabic diacritics and verse circles from hitting its gray inner line.
DEST = (0.179, 0.168, 0.821, 0.851)

# Illustrator reading text, without its own green rectangular border, top
# titles or page number. The green palette is first recolored to white.
SRC = (0.162, 0.163, 0.838, 0.862)


def normalize(page, parts):
    return fitz.Rect(
        page.rect.x0 + page.rect.width * parts[0],
        page.rect.y0 + page.rect.height * parts[1],
        page.rect.x0 + page.rect.width * parts[2],
        page.rect.y0 + page.rect.height * parts[3],
    )


def strip(target, old_doc, n, region):
    old_page = old_doc[n - 1]
    target.show_pdf_page(
        normalize(target, region),
        old_doc, n - 1,
        clip=normalize(old_page, region),
        keep_proportion=False,
        overlay=True,
    )


def generate():
    if not OLD.is_file() or not VECTOR.is_file():
        raise SystemExit("Missing quran.pdf or quran_vector_candidate.pdf")
    out = fitz.open()
    try:
        with fitz.open(OLD) as old, fitz.open(VECTOR) as source:
            if len(old) != 604 or len(source) != 604:
                raise ValueError("Expected 604 pages in both Quran files.")
            for n in PAGES:
                old_page = old[n - 1]
                clean, replaced = page_svg_as_pdf(source[n - 1])
                try:
                    if replaced == 0:
                        raise ValueError("Green background not removed for page %s" % n)
                    page = out.new_page(
                        width=old_page.rect.width,
                        height=old_page.rect.height,
                    )
                    # 1. The ONLY text layer comes from the clean vector AI.
                    page.show_pdf_page(
                        normalize(page, DEST), clean, 0,
                        clip=normalize(clean[0], SRC),
                        keep_proportion=False,
                        overlay=False,
                    )
                    # 2. The original blue BORDER, surah/juz, and foot number
                    # are retained in their exact old positions — no added
                    # white boxes, labels, or duplicate old Quran interior.
                    for region in (TOP, BOTTOM, LEFT, RIGHT):
                        strip(page, old, n, region)
                    print("Page %s: source green fills whitened=%s; "
                          "one vector text layer; border strips only" % (n, replaced),
                          flush=True)
                finally:
                    clean.close()
        out.save(OUT, garbage=3, deflate=True)
    finally:
        out.close()
    print("PREVIEW:", OUT)
    print("The working quran.pdf has NOT been replaced.")


if __name__ == "__main__":
    generate()
