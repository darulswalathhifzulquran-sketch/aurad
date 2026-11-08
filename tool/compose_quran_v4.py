"""Quran V4: clean VECTOR source + BLUE frame only (no double text).

Original quran.pdf is never changed. V4 preview is five pages.
Requires only pymupdf and pillow (no Cairo).
    python tool/compose_quran_v4.py
    python tool/compose_quran_v4.py --all
"""
import argparse
import io
from pathlib import Path
from PIL import Image
import pymupdf

from compose_quran_clean_vector import page_svg_as_pdf

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = ROOT / "quran.pdf"
VECTOR = ROOT / "quran_vector_candidate.pdf"
PREVIEW = ROOT / "quran_v4_blue_clean_preview.pdf"
FULL = ROOT / "quran_v4_blue_clean_604.pdf"
SAMPLES = [1, 3, 208, 252, 604]


def ornament_overlay(old_page, zoom=3):
    """Keep only the original blue ornament pixels at the outer frame.

    Crucial: do not copy original black Arabic, header text, page numbers,
    inner pale-blue paper, or gray artifacts. All writing stays from the
    single VECTOR Quran layer.
    """
    pix = old_page.get_pixmap(matrix=pymupdf.Matrix(zoom, zoom),
                             colorspace=pymupdf.csRGB, alpha=False)
    rgb = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
    # The two named surah/juz header capsules contain old raster Arabic.
    # Exclude their interiors to avoid artifacts even when the old ink is blue.
    def header_capsule(x, y):
        return (0.075 < y < 0.165 and
                ((0.18 < x < 0.455) or (0.545 < x < 0.82)))

    # Never retain any old ink in the central Quran reading area.
    def outer_frame(x, y):
        return (x < .175 or x > .825 or y < .155 or y > .865)

    # Extract high saturation blue/cyan, NOT all dark text.
    px = rgb.load()
    result = Image.new("RGBA", rgb.size, (0, 0, 0, 0))
    dst = result.load()
    w, h = rgb.size
    for yi in range(h):
        y = (yi + .5) / h
        for xi in range(w):
            x = (xi + .5) / w
            if not outer_frame(x, y) or header_capsule(x, y):
                continue
            r, g, b = px[xi, yi]
            if b < 75 or r > 190:
                continue
            # Accent is blue/turquoise with a low red channel.
            if b >= 1.18 * r and g >= 1.12 * r and (g > 75 or b > 120):
                dst[xi, yi] = (r, g, b, 255)
    stream = io.BytesIO()
    result.save(stream, format="PNG")
    return stream.getvalue()


def make(indices, output):
    if not ORIGINAL.exists() or not VECTOR.exists():
        raise SystemExit("Missing quran.pdf or quran_vector_candidate.pdf")
    result = pymupdf.open()
    try:
        with pymupdf.open(ORIGINAL) as old, pymupdf.open(VECTOR) as vector:
            if len(old) != 604 or len(vector) != 604:
                raise SystemExit("Each source PDF must have 604 pages.")
            for num in indices:
                old_page = old[num - 1]
                vector_page = vector[num - 1]
                clean, greens = page_svg_as_pdf(vector_page)
                try:
                    if greens < 1:
                        raise ValueError(f"Page {num}: green fills were NOT removed.")
                    page = result.new_page(width=old_page.rect.width,
                                           height=old_page.rect.height)
                    # Entire cleaned Illustrator page = one unique Quran layer.
                    # No clipping into rectangular boxes, no old PDF as backing.
                    page.show_pdf_page(page.rect, clean, 0,
                                       keep_proportion=True, overlay=True)
                    # Original BLUE outer border. Drawn on top of the clean
                    # source, but NO old Quran text ever remains in the image.
                    border_png = ornament_overlay(old_page)
                    page.insert_image(page.rect, stream=border_png,
                                      overlay=True, keep_proportion=False)
                    print(f"COMPOSED page {num}: green fills removed={greens}; "
                          "one Quran vector text layer, blue-only frame", flush=True)
                finally:
                    clean.close()
        result.save(output, garbage=3, deflate=True)
    finally:
        result.close()
    print("SUCCESS:", output)
    print("Original working Quran and dark-mode PDFs unchanged.")
    print("Confirm Arabic first/last words and verse numbering before installation.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--all", action="store_true")
    args = parser.parse_args()
    make(range(1, 605) if args.all else SAMPLES,
         FULL if args.all else PREVIEW)


if __name__ == "__main__":
    main()
