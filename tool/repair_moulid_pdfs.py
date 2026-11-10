"""Regenerate the two Mawlid PDF variants with the owner's exact borders.

Uses the ORIGINAL PDFs in Downloads, never previously generated derivatives.
Run from Flutter project root: python tool/repair_moulid_pdfs.py
"""
from io import BytesIO
from pathlib import Path
import pymupdf
from PIL import Image, ImageOps, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DL = Path.home() / "Downloads"
OUT = ROOT / "assets" / "books"

BOOKS = [
    ("Manqoos", DL / "Manqoos moulid-3-19.pdf", "mankoos_moulid", 13, 17),
    ("Sharaf al-Anam", DL / "sharaful anam orgn [Autosaved]  111111 bn.pdf",
     "sharafal_anam_moulid", 30, 30),
]
BORDERS = {
    "light": DL / "moulid_light.png",
    "dark": DL / "moulid_dark.png",
}

def image_png(im):
    memory = BytesIO()
    im.save(memory, "PNG")
    return memory.getvalue()

def text_art(source_page, kind, page_number, mode):
    """Keep original printed Arabic; turn white paper into transparency."""
    rect = source_page.rect
    # Earlier 8.5% side crop cut off the long Sharaf lines.
    # Use book-specific source bounds *inside* the old printed frame.
    if kind == "Manqoos":
        fractions = (.116, .059, .884, .927)
    else:
        fractions = (.051, .051, .949, .945)
    x0, y0, x1, y1 = fractions
    clip = pymupdf.Rect(
        rect.x0 + rect.width * x0, rect.y0 + rect.height * y0,
        rect.x0 + rect.width * x1, rect.y0 + rect.height * y1,
    )
    px = source_page.get_pixmap(matrix=pymupdf.Matrix(3.6, 3.6),
                                clip=clip, colorspace=pymupdf.csRGB,
                                alpha=False)
    rgb = Image.frombytes("RGB", (px.width, px.height), px.samples)
    alpha = ImageOps.grayscale(rgb).point(
        lambda v: min(255, max(0, (247 - v) * 5))
    )

    # Remove Manqoos's green decorative Muhammad image, without removing
    # neighbouring black Arabic paragraph text on page 13.
    if kind == "Manqoos" and page_number == 13:
        r, g, b = rgb.split()
        from PIL import ImageChops
        # Green lettering is strongly green-dominant.
        green = g.point(lambda v: 255 if v > 65 else 0)
        red_low = r.point(lambda v: 255 if v < 160 else 0)
        blue_low = b.point(lambda v: 255 if v < 160 else 0)
        green = ImageChops.multiply(green, ImageChops.multiply(red_low, blue_low))
        alpha.paste(0, mask=green)

    # Sharaf first-page Bismillah: reserve its space for requested title.
    if kind != "Manqoos" and page_number == 1:
        title_cut = int(rgb.height * .175)
        ImageDraw.Draw(alpha).rectangle((0, 0, rgb.width, title_cut), fill=0)

    # Hide image artwork at end of last Sharaf page, but keep all text.
    if kind != "Manqoos" and page_number == 30:
        for block in source_page.get_text("dict").get("blocks", []):
            if block.get("type") != 1:
                continue
            r = pymupdf.Rect(block["bbox"])
            if (r.y0 < rect.y0 + rect.height * .45 or
                    r.width < rect.width * .19 or
                    r.width > rect.width * .95):
                continue
            coords = [
                int((r.x0 - clip.x0) / clip.width * rgb.width),
                int((r.y0 - clip.y0) / clip.height * rgb.height),
                int((r.x1 - clip.x0) / clip.width * rgb.width),
                int((r.y1 - clip.y0) / clip.height * rgb.height),
            ]
            ImageDraw.Draw(alpha).rectangle(coords, fill=0)
            print("  Removed last-page image artwork:", tuple(round(v) for v in r))

    if mode == "dark":
        out = Image.new("RGBA", rgb.size, (255, 255, 255, 0))
    else:
        out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return image_png(out)

def title_png(mode):
    font_path = ROOT / "assets" / "fonts" / "Amiri-Regular.ttf"
    if not font_path.is_file():
        raise FileNotFoundError(f"Arabic calligraphy font not found: {font_path}")
    W, H = 1400, 240
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pen = ImageDraw.Draw(overlay)
    font = ImageFont.truetype(str(font_path), 115)
    pen.text((W // 2, H // 2), "شرف الأنام",
             anchor="mm", font=font, direction="rtl",
             fill=(225, 183, 94, 255) if mode == "dark"
             else (100, 48, 24, 255),
             stroke_width=0)
    return image_png(overlay)

def build(book, source_file, basename, keep_pages, source_pages, mode):
    source = pymupdf.open(str(source_file))
    if len(source) != source_pages:
        raise ValueError(f"{book}: expected {source_pages} source pages, "
                         f"found {len(source)}")
    border = BORDERS[mode]
    with Image.open(border) as im:
        width, height = im.size
    result = pymupdf.open()
    for i in range(keep_pages):
        page = result.new_page(width=width, height=height)
        page.insert_image(page.rect, filename=str(border), keep_proportion=False)
        # The artwork is fully inside the owner's new frame.
        area = pymupdf.Rect(width * .077, height * .104,
                            width * .923, height * .899)
        png = text_art(source[i], book, i + 1, mode)
        page.insert_image(area, stream=png, keep_proportion=False)
        if book != "Manqoos" and i == 0:
            title_rect = pymupdf.Rect(width * .17, height * .125,
                                      width * .83, height * .236)
            page.insert_image(title_rect, stream=title_png(mode),
                              keep_proportion=True)
    path = OUT / f"{basename}_{mode}.pdf"
    if path.exists():
        backup = path.with_suffix(".previous.pdf")
        if backup.exists():
            backup.unlink()
        path.replace(backup)
    result.save(str(path), garbage=4, deflate=True)
    print(f"CREATED {path.name}: {len(result)} pages")
    result.close()
    source.close()

def main():
    required = [*BORDERS.values(), *[book[1] for book in BOOKS]]
    for f in required:
        if not f.is_file():
            raise FileNotFoundError(f)
    OUT.mkdir(parents=True, exist_ok=True)
    for book in BOOKS:
        for mode in ("light", "dark"):
            build(*book, mode)
    print("DONE: 4 new PDFs. Check pages visually before accepting them.")

if __name__ == "__main__":
    main()
