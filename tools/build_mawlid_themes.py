"""
Prepare the two approved-themed Mawlid PDFs without retyping Arabic.

Windows setup:
  py -m pip install pymupdf pillow numpy
  py tools/build_mawlid_themes.py

Put your two original PDF files and the two exact approved border PNGs
in assets/mawlid_sources/ with the names shown below. Existing files stay
untouched. The output is four separate themed PDFs in assets/books/.

This raster-composites the original glyphs (including harakat), rather
than re-typing/reshaping Arabic. Always proofread the output visually.
"""
from pathlib import Path
from io import BytesIO
import sys

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "mawlid_sources"
DST = ROOT / "assets" / "books"

FILES = [
    ("manqoos_original.pdf", "mankoos_moulid", 17),
    ("sharafal_anam_original.pdf", "sharafal_anam_moulid", 30),
]

def run():
    try:
        import fitz
        import numpy as np
        from PIL import Image
    except ImportError:
        sys.exit("Install dependencies first: py -m pip install pymupdf pillow numpy")

    required = [SRC / "border_light.png", SRC / "border_dark.png"]
    required.extend(SRC / file for file, _, _ in FILES)
    missing = [str(p) for p in required if not p.is_file()]
    if missing:
        sys.exit("Missing input files:\n" + "\n".join(missing))

    # Keep the supplied border images completely unchanged apart from 2x
    # enlargement for high-resolution PDF export.
    borders = {}
    for mode in ("light", "dark"):
        with Image.open(SRC / f"border_{mode}.png") as im:
            borders[mode] = im.convert("RGB").resize(
                (im.width * 2, im.height * 2), Image.Resampling.LANCZOS
            )
    if borders["light"].size != borders["dark"].size:
        sys.exit("Light and dark borders must have matching dimensions.")

    W, H = borders["light"].size
    DST.mkdir(parents=True, exist_ok=True)
    # The approved border is unobstructed: body content stays inside its frame.
    box = (round(W * .105), round(H * .105),
           round(W * .895), round(H * .902))
    bw, bh = box[2] - box[0], box[3] - box[1]

    for filename, stem, expected in FILES:
        source = fitz.open(SRC / filename)
        if source.page_count != expected:
            sys.exit(f"{filename}: expected {expected} pages, found {source.page_count}")
        outputs = {m: fitz.open() for m in ("light", "dark")}
        try:
            for page_number, page in enumerate(source, 1):
                # Read the *actual PDF drawing*, never extracted/retyped text.
                # Source scans include their own old gold/maroon border.
                # Only black typography and center-area colored headings
                # survive this mask; the old marginal frame is discarded.
                target_w = bw
                scale = target_w / page.rect.width
                pix = page.get_pixmap(matrix=fitz.Matrix(scale, scale),
                                      colorspace=fitz.csRGB, alpha=False)
                original = Image.frombytes("RGB", (pix.width, pix.height),
                                           pix.samples)
                rgb = np.asarray(original, dtype=np.uint8)
                ch = rgb.astype(np.int16)
                lum = np.mean(ch, axis=2)
                spread = np.max(ch, axis=2) - np.min(ch, axis=2)
                neutral = spread < 42
                # Exclude page-number strip and colored corner ornament.
                yy, xx = np.ogrid[:pix.height, :pix.width]
                inside = ((xx > pix.width * .055) &
                          (xx < pix.width * .945) &
                          (yy > pix.height * .055) &
                          (yy < pix.height * .94))
                center = ((xx > pix.width * .16) &
                          (xx < pix.width * .84) &
                          (yy > pix.height * .10) &
                          (yy < pix.height * .88))
                alpha = np.zeros(lum.shape, dtype=np.uint8)
                keep_black = neutral & inside
                alpha[keep_black] = np.clip(
                    (218 - lum[keep_black]) * 2.8, 0, 255
                ).astype(np.uint8)
                keep_color = (~neutral) & center & (lum < 205)
                alpha[keep_color] = np.clip(
                    (230 - lum[keep_color]) * 2.8, 0, 255
                ).astype(np.uint8)
                text = Image.fromarray(np.dstack((rgb, alpha)), "RGBA")

                # Preserve all line spacing and relative glyph positions.
                ratio = min(bw / text.width, bh / text.height)
                size = (max(1, round(text.width * ratio)),
                        max(1, round(text.height * ratio)))
                text = text.resize(size, Image.Resampling.LANCZOS)
                left = box[0] + (bw - size[0]) // 2
                top = box[1] + (bh - size[1]) // 2

                for mode in ("light", "dark"):
                    canvas = borders[mode].convert("RGBA")
                    ink = text
                    if mode == "dark":
                        # Same exact letter shapes and diacritics, now white.
                        arr = np.asarray(text).copy()
                        is_color = (arr[:, :, :3].max(axis=2).astype(int)
                                    - arr[:, :, :3].min(axis=2).astype(int)) > 42
                        arr[:, :, :3] = [255, 255, 255]
                        arr[is_color, :3] = [225, 180, 89]
                        ink = Image.fromarray(arr, "RGBA")
                    canvas.alpha_composite(ink, (left, top))
                    b = BytesIO()
                    canvas.convert("RGB").save(b, "PNG", optimize=True)
                    pdf_page = outputs[mode].new_page(width=W, height=H)
                    pdf_page.insert_image(pdf_page.rect, stream=b.getvalue())
                print(f"{stem}: {page_number}/{expected}")
            for mode, document in outputs.items():
                dest = DST / f"{stem}_{mode}.pdf"
                document.save(dest, garbage=4, deflate=True)
                print("CREATED:", dest)
        finally:
            source.close()
            for doc in outputs.values():
                doc.close()

if __name__ == "__main__":
    run()
