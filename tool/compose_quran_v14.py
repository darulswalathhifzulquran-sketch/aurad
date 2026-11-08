"""Quran blue-frame candidate, carefully isolated layers (V14).

Use this on the Windows project folder:
  python tool/compose_quran_v14.py
  python tool/compose_quran_v14.py --all

Input: quran.pdf (blue border), quran_vector_candidate.pdf (AI vector Quran).
Produces a NEW PDF only. NEVER changes installed quran.pdf.
Uses true PDF vector glyph paths, not giant JPEG/PNG for the Quran writing.

Critical invariants:
- Absolutely no old Quran text: original PDF is NEVER placed as PDF page.
- Old border is a TRANSPARENT PNG created only from pixels outside central ink.
- New Quran is ONE clipped vector page, with greens recolored white.
- No extra white heading boxes or duplicate page numbers.
- Preserves source Quran's original ayah symbols and line ordering.
"""
import argparse
import io
from pathlib import Path

import pymupdf
from PIL import Image, ImageDraw

from compose_quran_clean_vector import page_svg_as_pdf

ROOT = Path(__file__).resolve().parents[1]
OLD = ROOT / "quran.pdf"
VECTOR = ROOT / "quran_vector_candidate.pdf"
PREVIEW = ROOT / "quran_v14_preview.pdf"
FULL = ROOT / "quran_v14_candidate_604.pdf"
SAMPLES = (1, 2, 3, 208, 252, 604)

# The original BLUE border extends from ~0.12..0.88 of the PDF sheet.
# Only the four outside ornamental bands are used from the original page.
# This is intentionally more conservative than extracting the original
# page / masking a rectangular body from an existing combined PDF.
OLD_BODY_HOLE = (.165, .157, .835, .874)
TARGET_BODY = (.178, .173, .822, .847)

def nrect(page, coords):
    return pymupdf.Rect(
        page.rect.x0 + coords[0] * page.rect.width,
        page.rect.y0 + coords[1] * page.rect.height,
        page.rect.x0 + coords[2] * page.rect.width,
        page.rect.y0 + coords[3] * page.rect.height
    )


def border_only(original, zoom=3):
    """Transparent PNG from original border with ALL old body ink excluded.

    It is impossible to get double Quran text from this layer: the original
    page is not copied, and central area is fully transparent.
    Keep the original ornamental frame, including pale blue/gray rails,
    not just saturated blue pixels (which V4/V7 incorrectly discarded).
    """
    pix = original.get_pixmap(
        matrix=pymupdf.Matrix(zoom, zoom),
        colorspace=pymupdf.csRGB, alpha=False)
    rgb = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
    rgba = rgb.convert("RGBA")
    alpha = Image.new("L", rgb.size, 255)
    draw = ImageDraw.Draw(alpha)
    a, b, c, d = OLD_BODY_HOLE
    draw.rectangle(
        (int(a * pix.width)-2, int(b * pix.height)-2,
         int(c * pix.width)+2, int(d * pix.height)+2), fill=0)
    # Mask extra old pixels in the heading and foot of the page only:
    # avoid preserving the BLURRY historical labels. The blue outline
    # and other artwork remain, and the new Illustrator page owns its text.
    for a,b,c,d in (
        (.204,.102,.424,.143),
        (.574,.102,.794,.143),
        (.454,.879,.546,.916),
    ):
        draw.rectangle(
            (int(a * pix.width),int(b * pix.height),
             int(c * pix.width),int(d * pix.height)), fill=0)
    rgba.putalpha(alpha)
    stream = io.BytesIO()
    rgba.save(stream, format="PNG")
    return stream.getvalue()


def vector_content_crop(page, n):
    """Find the real dark-ink bounds from the Illustrator vector page.

    This temporary low-resolution pixel scan ONLY measures the bounding box.
    It does not rasterize the output lettering or OCR / reshape Arabic.
    """
    # Keep the full special Fatiha/Baqara graphic in its source geometry.
    # Regular pages have source title/folio outside the Quran reading block.
    bounds = (.12, .16, .88, .91) if n <= 2 else (.12, .155, .88, .89)
    area = nrect(page, bounds)
    pix = page.get_pixmap(
        matrix=pymupdf.Matrix(2, 2),
        clip=area, colorspace=pymupdf.csRGB, alpha=False)
    w,h = pix.width,pix.height
    data=pix.samples
    found_x=[]
    found_y=[]
    for y in range(0,h,2):
        row=y*w*3
        for x in range(0,w,2):
            k=row+x*3
            if max(data[k],data[k+1],data[k+2]) < 175:
                found_x.append(x)
                found_y.append(y)
    if len(found_x) < 100:
        raise RuntimeError(f"Page {n}: vector ink not found; stopping")
    px=max(4,int(w*.018))
    py=max(4,int(h*.016))
    return pymupdf.Rect(
        max(page.rect.x0,area.x0+(min(found_x)-px)/2),
        max(page.rect.y0,area.y0+(min(found_y)-py)/2),
        min(page.rect.x1,area.x0+(max(found_x)+px+1)/2),
        min(page.rect.y1,area.y0+(max(found_y)+py+1)/2),
    )


def make(page_numbers, target):
    if not OLD.is_file() or not VECTOR.is_file():
        raise SystemExit("Missing project quran.pdf or quran_vector_candidate.pdf")
    created = pymupdf.open()
    try:
        with pymupdf.open(OLD) as original, pymupdf.open(VECTOR) as source:
            if len(original)!=604 or len(source)!=604:
                raise RuntimeError("Both sources need exactly 604 pages.")
            for number in page_numbers:
                original_page=original[number-1]
                clean, changed=page_svg_as_pdf(source[number-1])
                try:
                    if changed<1:
                        raise RuntimeError(f"Page {number}: green fills not converted")
                    page=created.new_page(
                        width=original_page.rect.width,
                        height=original_page.rect.height)
                    clip=vector_content_crop(clean[0],number)
                    dest=nrect(page,TARGET_BODY)
                    # Only one native vector Arabic Quran source.
                    page.show_pdf_page(dest,clean,0,clip=clip,
                                       keep_proportion=True,overlay=True)
                    # The approved original frame has NO Quran glyphs in it.
                    page.insert_image(
                        page.rect,stream=border_only(original_page),
                        keep_proportion=False,overlay=True)
                    print(f"PAGE {number}: source ink {clip}, frame inside {dest}, "
                          f"greens={changed}, old Quran ink=NONE",flush=True)
                finally:
                    clean.close()
        created.save(target,garbage=3,deflate=True)
    finally:
        created.close()
    print("SUCCESS:",target)
    print("Original quran.pdf not changed.")
    print("NOTE: Check header metadata, verse circles, alignment and first/last")
    print("words against original before using in production; do NOT auto-install.")

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--all",action="store_true")
    args=parser.parse_args()
    make(range(1,605) if args.all else SAMPLES,
         FULL if args.all else PREVIEW)
