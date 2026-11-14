"""Install original Manqoos and Sharaf Moulids while preserving source resolution.

Run from project root: python tool/repair_moulid_v2.py
Only the specified Sharaf print decorations are covered, never retyped.
Footer is taken from the user's own light border art, if available.
"""
from pathlib import Path
from io import BytesIO
import pymupdf

ROOT = Path(__file__).resolve().parents[1]
DL = Path.home() / "Downloads"
OUT = ROOT / "assets" / "books"
BOOKS = [
    ("Manqoos", [
        "Manqoos moulid-3-19 (1)(3).pdf",
        "Manqoos moulid-3-19.pdf",
        "Manqoos moulid.pdf",
    ], "mankoos_moulid", 13, 17),
    ("Sharaf al-Anam", [
        "sharaful anam orgn [Autosaved]  111111 bn(2).pdf",
        "sharaful anam orgn [Autosaved]  111111 bn.pdf",
    ], "sharafal_anam_moulid", 30, 30),
]

def find_source(names):
    for name in names:
        path = DL / name
        if path.is_file():
            return path
    raise FileNotFoundError(
        "Original PDF missing from Downloads: " + ", ".join(names))

def cover_white(page, coords):
    r = page.rect
    box = pymupdf.Rect(
        r.x0 + r.width * coords[0], r.y0 + r.height * coords[1],
        r.x0 + r.width * coords[2], r.y0 + r.height * coords[3])
    page.draw_rect(box, color=None, fill=(1, 1, 1), overlay=True)

def remove_sharaf_number(page):
    # Cover the entire number capsule, including the grey-black outline.
    # Only the top-centre paper area; do not touch Arabic body text.
    cover_white(page, (.455, .004, .545, .071))

def remove_last_sharaf_artwork(page):
    # Screenshot-confirmed: isolated calligraphy below the final du'a.
    # Keep the top text and all four decorative frame corners intact.
    cover_white(page, (.165, .565, .84, .885))

def footer_art():
    """Get the academy badge from the user's exact previously approved border."""
    try:
        from PIL import Image
    except ImportError:
        return None
    user_badge = DL / "moulid_footer.png"
    if user_badge.is_file():
        image = Image.open(user_badge).convert("RGB")
    else:
        border = DL / "moulid_light.png"
        if not border.is_file():
            print("FOOTER NOTE: save moulid_footer.png in Downloads to replace old attribution")
            return None
        original = Image.open(border).convert("RGB")
        w, h = original.size
        image = original.crop((
            int(w * .26), int(h * .912),
            int(w * .74), int(h * .995)))
    data = BytesIO()
    image.save(data, format="PNG")
    return data.getvalue()

def replace_footer(page, image):
    if not image:
        return
    # Paint over the old 'Majlis Salat al-Saadah' capsule, then place
    # academy branding. This does not affect the main page text.
    cover_white(page, (.245, .934, .755, .999))
    r = page.rect
    dest = pymupdf.Rect(r.width*.258, r.height*.924,
                        r.width*.742, r.height*.996)
    page.insert_image(dest, stream=image, overlay=True,
                      keep_proportion=False)

def build(book, badge):
    name, names, base, count, expected = book
    source_path = find_source(names)
    original = pymupdf.open(str(source_path))
    if len(original) != expected:
        raise ValueError(
            f"{name}: expected {expected} original pages, found {len(original)}")
    output = pymupdf.open()
    for i in range(count):
        source_page = original[i]
        page = output.new_page(width=source_page.rect.width,
                               height=source_page.rect.height)
        # Retain every original PDF vector glyph/diacritic and table line.
        page.show_pdf_page(page.rect, original, i, keep_proportion=False)
        if base == "sharafal_anam_moulid":
            remove_sharaf_number(page)
            if i == count-1:
                remove_last_sharaf_artwork(page)
        replace_footer(page, badge)

    OUT.mkdir(parents=True, exist_ok=True)
    for mode in ("light", "dark"):
        path = OUT / f"{base}_{mode}.pdf"
        pending = path.with_suffix(".pending.pdf")
        if pending.exists():
            pending.unlink()
        output.save(str(pending), garbage=4, deflate=True)
        test = pymupdf.open(str(pending))
        valid = len(test) == count
        test.close()
        if not valid:
            raise RuntimeError("Invalid output page count")
        if path.is_file():
            backup = OUT / f"{base}_{mode}.before_original.pdf"
            if not backup.is_file():
                backup.write_bytes(path.read_bytes())
        pending.replace(path)
        print(f"APP ASSET READY: {path.name} ({count} original pages)")
    output.close()
    original.close()

def main():
    badge = footer_art()
    for book in BOOKS:
        build(book, badge)
    print("DONE. Original PDF text preserved; dark color handled by Flutter.")

if __name__ == "__main__":
    main()
