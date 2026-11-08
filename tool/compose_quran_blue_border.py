"""Preview the original blue Mushaf frame with sharp Illustrator Quran lettering.

This makes a SEPARATE preview PDF, never overwrites quran.pdf.
Run: python tool/compose_quran_blue_border.py
Optional: python tool/compose_quran_blue_border.py --all

The approved original printed frame and page header remain from quran.pdf.
The vector Arabic body is clipped from quran_vector_candidate.pdf.
"""
import argparse
import re
from pathlib import Path

import pymupdf

ROOT = Path(__file__).resolve().parents[1]
OLD = ROOT / "quran.pdf"
VECTOR = ROOT / "quran_vector_candidate.pdf"
OUTPUT = ROOT / "quran_blue_border_preview.pdf"
FINAL = ROOT / "quran_blue_border_vector_candidate.pdf"
COUNT = 604

# Body rectangles as fractions of the original PDF page dimensions:
# The old paper contains a blue border outside this area, untouched.
OLD_BODY = (0.166, 0.135, 0.835, 0.881)
DEFAULT_AI_CROP = (0.23, 0.135, 0.77, 0.86)


def rect_relative(page, proportions):
    a, b, c, d = proportions
    return pymupdf.Rect(
        page.rect.x0 + page.rect.width * a,
        page.rect.y0 + page.rect.height * b,
        page.rect.x0 + page.rect.width * c,
        page.rect.y0 + page.rect.height * d,
    )


def color_is_green(rgb):
    if rgb is None or len(rgb) < 3:
        return False
    r, g, b = rgb[:3]
    # The source pages have a pale green fill. This range excludes black text
    # and deep ornamental strokes.
    return (0.48 < r < 0.98 and 0.62 < g < 1.0
            and 0.44 < b < 0.98 and g > r * 1.035 and g > b * 1.015)


def green_rect(page):
    candidates = []
    for d in page.get_drawings():
        if color_is_green(d.get("fill")):
            r = d["rect"]
            area = r.width * r.height
            if r.width > page.rect.width * .2 and r.height > page.rect.height * .2:
                candidates.append((area, r))
    if candidates:
        return max(candidates, key=lambda x: x[0])[1]
    return rect_relative(page, DEFAULT_AI_CROP)


def replace_green_graphics(doc):
    """Try to convert green background fills to white without rasterizing glyphs.

    Only convert PDF fill-color instructions using a matching pale-green
    colour. Do not modify text drawing or paths.
    """
    changed = 0
    # RGB direct fill: three values followed by 'rg'. Convert ONLY pale greens.
    rx = re.compile(rb"(?<![0-9.])([0-9]*\.?[0-9]+)\s+"
                    rb"([0-9]*\.?[0-9]+)\s+([0-9]*\.?[0-9]+)\s+rg\b")
    def patch(m):
        nonlocal changed
        try:
            rgb = tuple(float(m.group(i)) for i in (1, 2, 3))
        except ValueError:
            return m.group()
        if color_is_green(rgb):
            changed += 1
            return b"1 1 1 rg"
        return m.group()

    for xref in range(1, doc.xref_length()):
        try:
            stream = doc.xref_stream(xref)
            if not stream:
                continue
            updated = rx.sub(patch, stream)
            if updated != stream:
                doc.update_stream(xref, updated)
        except (RuntimeError, ValueError):
            continue
    return changed


def compose(pages, source, reference, dest):
    out = pymupdf.open()
    try:
        for number in pages:
            old = reference[number - 1]
            sharp = source[number - 1]
            if old.rect.is_empty or sharp.rect.is_empty:
                raise ValueError(f"Invalid page {number}")
            out.insert_pdf(reference, from_page=number - 1, to_page=number - 1)
            result = out[-1]
            target = rect_relative(result, OLD_BODY)
            crop = green_rect(sharp)
            # Enlarge crop slightly to retain diacritics close to both sides.
            crop = crop + (-sharp.rect.width * .012, -sharp.rect.height * .008,
                           sharp.rect.width * .012, sharp.rect.height * .008)
            crop = crop & sharp.rect
            # Opaque white conceals ONLY the old black letters within the frame.
            # The old blue frame, side ornaments and headers are left intact.
            result.draw_rect(target, color=None, fill=(1, 1, 1), overlay=True)
            result.show_pdf_page(target, source, number - 1,
                                 clip=crop, keep_proportion=False, overlay=True)
            if number in (208, 252) or len(pages) <= 4:
                print(f"Page {number}: old={old.rect}, AI crop={crop}, target={target}")
            if len(pages) > 4 and number % 50 == 0:
                print(f"Combined {number}/{COUNT}", flush=True)
        out.save(dest, garbage=3, deflate=True)
    finally:
        out.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true", help="Create entire 604-page candidate")
    args = ap.parse_args()
    if not OLD.exists() or not VECTOR.exists():
        raise SystemExit("Need quran.pdf and quran_vector_candidate.pdf in project root")
    # Copy vector source to a working document IN MEMORY; never change candidate.
    with pymupdf.open(VECTOR) as art, pymupdf.open(OLD) as old:
        if len(art) != COUNT or len(old) != COUNT:
            raise SystemExit(f"Wrong page counts: new={len(art)}, old={len(old)}")
        count = replace_green_graphics(art)
        print("Green RGB fill instructions changed to white:", count)
        page_indices = range(1, COUNT + 1) if args.all else [3, 208, 252, 604]
        output = FINAL if args.all else OUTPUT
        compose(page_indices, art, old, output)
    print("SUCCESS:", output)
    print("Original quran.pdf and vector candidate were not modified.")
    if not args.all:
        print("Inspect all 4 preview pages. If alignment and colors match,")
        print("run again with --all to build 604-page PDF.")

if __name__ == "__main__":
    main()
