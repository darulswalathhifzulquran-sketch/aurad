"""V9: approved blue frame + ONE true-vector Quran body, never double text.

Requires existing quran.pdf (approved frame), quran_vector_candidate.pdf
(the user's 604 Illustrator PDF pages), pymupdf, pillow.
Does NOT modify working PDFs. Preview: python tool/compose_quran_v9.py

Technical:
* clean recolored vector page is the ONLY Arabic source.
* old PDF is not inserted, even as a page background.
* border is sampled only in outer ornamental bands, and inner text cut out.
* source Arabic is fitted using its actual dark ink bounding rectangle,
  never arbitrary fixed source crop that cuts off lines.
* page 1/2 keep source's original circular composition.
* source's native vector Surah/Juz/verse/page writing is NOT duplicated by
  additional new labels or white boxes.
"""
import io
import argparse
from pathlib import Path

import pymupdf as fitz
from PIL import Image, ImageDraw

from compose_quran_clean_vector import page_svg_as_pdf
from compose_quran_v5 import SURAH, page_starts, current, arabic_numbers

ROOT = Path(__file__).resolve().parents[1]
OLD_PDF = ROOT / "quran.pdf"
VECTOR_PDF = ROOT / "quran_vector_candidate.pdf"
PREVIEW = ROOT / "quran_v9_preview.pdf"
FULL = ROOT / "quran_v9_604.pdf"
SAMPLES = (1, 2, 3, 208, 252, 604)
FONT = ROOT / "assets/fonts/Amiri-Regular.ttf"

# These four coordinates match the inner open space of the BLUE frame.
# They are calibrated to the original frame, not the source Quran crop.
BODY_TARGET = (.176, .158, .824, .858)
HEADER_TARGET = (.18, .105, .82, .14)
BOTTOM_TARGET = (.43, .875, .57, .915)

def rect(page, bounds):
    return fitz.Rect(
        page.rect.x0 + bounds[0] * page.rect.width,
        page.rect.y0 + bounds[1] * page.rect.height,
        page.rect.x0 + bounds[2] * page.rect.width,
        page.rect.y0 + bounds[3] * page.rect.height,
    )

def perimeter_png(page, zoom=3):
    """Use the old border's actual pixels, but ZERO pixels of its Quran text.

    We keep its full ornamental perimeter including top/bottom bars and
    capsules. Black writing is stripped everywhere, so it cannot ghost.
    Retain pale/cyan/blue outline colors only, never plain white background.
    """
    pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom),
                          colorspace=fitz.csRGB, alpha=False)
    orig = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
    out = Image.new("RGBA", orig.size, (0, 0, 0, 0))
    src, dst = orig.load(), out.load()
    w, h = orig.size
    for y in range(h):
        fy = y / h
        for x in range(w):
            fx = x / w
            # Keep only the outside FRAME, no original Quran body.
            if .169 < fx < .831 and .148 < fy < .868:
                continue
            r, g, b = src[x, y]
            # Saturated blue frame paint, including all its horizontal rails.
            if b > 75 and ((b > r*1.16 and g > r*1.05)
                           or (g > r*1.24 and b > r*1.2)):
                dst[x, y] = (r, g, b, 255)
    stream = io.BytesIO()
    out.save(stream, format="PNG")
    return stream.getvalue()

def ink_bbox(page, number):
    """Locate actual ink in the vector source, using a temporary render only
    to measure bounds. Final PDF Arabic paths remain un-rasterized.
    """
    p = page.get_pixmap(matrix=fitz.Matrix(2,2),
                        colorspace=fitz.csRGB, alpha=False)
    rgb = Image.frombytes("RGB", (p.width, p.height), p.samples)
    # Only central Quran BODY. Exclude source surah/juz/top and foot labels.
    if number <= 2:
        area = (.16, .16, .84, .83)
    else:
        area = (.10, .17, .90, .87)
    xa,ya,xb,yb = (int(area[0]*p.width),int(area[1]*p.height),
                   int(area[2]*p.width),int(area[3]*p.height))
    px = rgb.load()
    xs, ys = [], []
    # Subsampling suffices for ink extent: no OCR involved.
    for y in range(ya, yb, 2):
        for x in range(xa, xb, 2):
            r,g,b = px[x,y]
            if max(r,g,b) < 150:
                xs.append(x)
                ys.append(y)
    if len(xs) < 50:
        raise ValueError(f"Page {number}: Quran body ink not found")
    # Use the extreme bounds with a little padding for diacritics.
    minx,maxx,miny,maxy=min(xs),max(xs),min(ys),max(ys)
    pad_x = int(.012*p.width)
    pad_y = int(.008*p.height)
    return fitz.Rect(
        max(0,(minx-pad_x)/2),
        max(0,(miny-pad_y)/2),
        min(page.rect.width,(maxx+pad_x)/2),
        min(page.rect.height,(maxy+pad_y)/2),
    )

def add_vector_label(page, bounds, value):
    """Native vector Arabic label, inside existing border capsule: NO box."""
    if not FONT.is_file():
        raise ValueError("Amiri font missing: " + str(FONT))
    css = (
        "@font-face{font-family:Amiri;src:url('Amiri-Regular.ttf')}"
        "div{font-family:Amiri;font-size:12pt;line-height:1.0;"
        "color:#174E76;text-align:center;margin:0;}"
    )
    remaining, _ = page.insert_htmlbox(
        rect(page,bounds),"<div dir='rtl'>"+value+"</div>",
        css=css,archive=fitz.Archive(str(FONT.parent)),
        scale_low=.35,overlay=True)
    if remaining < 0:
        raise ValueError("Unable to fit title: "+value)

def compose(pages, dest):
    if not OLD_PDF.is_file() or not VECTOR_PDF.is_file():
        raise SystemExit("Missing original quran.pdf or quran_vector_candidate.pdf")
    surah_starts, juz_starts = page_starts()
    out = fitz.open()
    try:
        with fitz.open(OLD_PDF) as original, fitz.open(VECTOR_PDF) as vector:
            if len(original)!=604 or len(vector)!=604:
                raise ValueError("Both source PDFs must have exactly 604 pages.")
            for n in pages:
                old = original[n-1]
                source = vector[n-1]
                clean, converted = page_svg_as_pdf(source)
                try:
                    if converted < 1:
                        raise ValueError(f"Page {n}: green backgrounds not recolored")
                    new = out.new_page(width=old.rect.width,
                                       height=old.rect.height)
                    if n <= 2:
                        # Special opening pages: retain the vector circular text
                        # and native decorations; fit to the blue frame.
                        crop = ink_bbox(clean[0], n)
                    else:
                        crop = ink_bbox(clean[0], n)
                    target = rect(new, BODY_TARGET)
                    new.show_pdf_page(target, clean, 0, clip=crop,
                                       keep_proportion=(n<=2))
                    # Clean outer frame only. NO original Quran page is added.
                    new.insert_image(new.rect, stream=perimeter_png(old),
                                     overlay=True, keep_proportion=False)
                    # Clear SVG/vector labels at the ORIGINAL label positions:
                    # NOT drawing white rectangles or duplicating old captions.
                    add_vector_label(new,(.20,.091,.42,.143),
                        "سورة "+SURAH[current(surah_starts,n)-1])
                    add_vector_label(new,(.58,.091,.80,.143),
                        "الجزء "+arabic_numbers(current(juz_starts,n)))
                    add_vector_label(new,(.447,.872,.555,.914),
                        arabic_numbers(n))
                    print(f"Page {n}: green removed={converted}, "
                          f"ink crop={crop}, target={target}; "
                          "one vector Arabic layer / no extra boxes",flush=True)
                finally:
                    clean.close()
        out.save(dest, garbage=3, deflate=True)
    finally:
        out.close()
    print("SUCCESS:",dest)
    print("NO original blurry Quran glyphs and NO extra page-number boxes.")
    print("This is a preview; original quran.pdf unchanged.")
    print("High-clarity Surah/Juz/page number inserted without white boxes.")
    print("Hizb numbering is omitted until exact page metadata is verified.")

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--all",action="store_true")
    opt=parser.parse_args()
    compose(range(1,605) if opt.all else SAMPLES,
            FULL if opt.all else PREVIEW)
