"""V7: one and only one VECTOR Quran text layer, old BLUE border overlay.

NO old PDF page as background. NO manual heading/page-number boxes.
Illustrator native Surah, Juz and page numerals stay within same vector layer.
The old PDF is sampled exclusively for blue/cyan border pixels.

Preview: python tool/compose_quran_v7.py
Full:    python tool/compose_quran_v7.py --all
Never replaces the working quran.pdf.
"""
import argparse
import io
from pathlib import Path

import pymupdf as fitz
from PIL import Image, ImageFilter

from compose_quran_clean_vector import page_svg_as_pdf

BASE = Path(__file__).resolve().parents[1]
ORIGINAL = BASE / "quran.pdf"
VECTOR = BASE / "quran_vector_candidate.pdf"
PREVIEW = BASE / "quran_v7_single_layer_preview.pdf"
FULL = BASE / "quran_v7_single_layer_604.pdf"
SAMPLES = (1, 2, 3, 208, 252, 604)

# The source Illustrator pages are already correctly composed: keep their
# whole page, including native Quran text, ayah numbers, Surah/Juz and folio.
# No crop/reflow of verses whatsoever.


def blue_ornament(old, scale=3):
    """Alpha mask of only the approved original blue ornamental artwork.

    This NEVER includes original black verses, page numbers or captions.
    A small dilation restores thin ornament antialiasing at top and bottom.
    """
    pix = old.get_pixmap(matrix=fitz.Matrix(scale, scale),
                         colorspace=fitz.csRGB, alpha=False)
    rgb = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
    w, h = rgb.size
    src = rgb.load()
    color = Image.new("RGBA", rgb.size, (0, 0, 0, 0))
    target = color.load()

    # Capture the FULL 4-sided blue frame, including both horizontal rails
    # and Fatiha/Baqara ornamental corners. Do not copy any central content.
    # Limits are intentionally broader than V4's side-only extraction.
    for y in range(h):
        fy = (y + .5) / h
        for x in range(w):
            fx = (x + .5) / w
            # Use the exterior margin of the inner Quran frame only;
            # protects from blue ayah markers inside the reading area.
            near_frame = (
                fx < .183 or fx > .817
                or fy < .174 or fy > .859
            )
            if not near_frame:
                continue
            r, g, b = src[x, y]
            saturation = max(r, g, b) - min(r, g, b)
            # Blue/cyan border, not black Arabic or gray frame.
            cyan_blue = (
                saturation >= 35
                and b >= 75
                and (b > r * 1.16)
                and (g > r * 1.08 or b > g * 1.14)
            )
            if cyan_blue:
                target[x, y] = (r, g, b, 255)
    mem = io.BytesIO()
    color.save(mem, format="PNG")
    return mem.getvalue()


def build(page_numbers, path):
    if not ORIGINAL.exists() or not VECTOR.exists():
        raise SystemExit("Need quran.pdf and quran_vector_candidate.pdf in project directory")
    out = fitz.open()
    try:
        with fitz.open(ORIGINAL) as old, fitz.open(VECTOR) as vector:
            if len(old) != 604 or len(vector) != 604:
                raise SystemExit("Both Quran PDFs must contain exactly 604 pages.")
            for n in page_numbers:
                original = old[n - 1]
                sharp = vector[n - 1]
                clean, green_count = page_svg_as_pdf(sharp)
                try:
                    if green_count == 0:
                        raise ValueError(f"Page {n}: green background not removed")
                    target = out.new_page(width=original.rect.width,
                                          height=original.rect.height)
                    # Exactly ONE new source PDF page. Absolutely NO original
                    # text, no source clipping and NO boxes drawn over text.
                    target.show_pdf_page(target.rect, clean, 0,
                                         keep_proportion=True, overlay=True)
                    # Only old blue decorative pixels. No old glyphs.
                    ornament = blue_ornament(original)
                    target.insert_image(target.rect, stream=ornament,
                                        keep_proportion=False, overlay=True)
                    print(f"Page {n}: single sharp vector page; "
                          f"green replaced={green_count}; blue ornaments only; "
                          "no title/page boxes", flush=True)
                finally:
                    clean.close()
        out.save(path, garbage=3, deflate=True)
    finally:
        out.close()
    print("SUCCESS:", path)
    print("Unchanged: quran.pdf and dark Quran PDF.")
    print("CHECK: original line starts/ends and border alignment BEFORE --all.")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true")
    args = ap.parse_args()
    build(range(1, 605) if args.all else SAMPLES,
          FULL if args.all else PREVIEW)
