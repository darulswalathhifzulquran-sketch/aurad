"""Install the user's original two-page Salam Baith in the Flutter Baith folder.

Place "salam baith .pdf" (or "salam baith.pdf") in Windows Downloads.
Optional reference assets in Downloads:
  salam_calligraphy.png  - supplied title artwork
  academy_footer.png     - supplied Jamia Imam Navavi badge
Run: python tool/install_salam_baith.py

Preserves all original Arabic PDF pages as vectors.
"""
from pathlib import Path
from io import BytesIO
import pymupdf
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DOWNLOADS = Path.home() / "Downloads"
OUT = ROOT / "assets" / "books" / "salam_baith.pdf"

def find_source():
    names = ("salam baith .pdf", "salam baith.pdf", "Salam Baith.pdf",
             "salam baith (1).pdf")
    for name in names:
        p = DOWNLOADS / name
        if p.is_file():
            return p
    raise FileNotFoundError(
        "Save the provided 2-page PDF as Downloads/salam baith .pdf")

def to_png_bytes(img):
    b=BytesIO()
    img.save(b, format="PNG")
    return b.getvalue()

def badge_image():
    # The user-supplied white badge on black screenshot is cropped to its
    # rounded white plaque; preserves Arabic lettering in original pixels.
    files = ["academy_footer.png", "moulid_footer.png"]
    for name in files:
        path=DOWNLOADS/name
        if not path.exists():
            continue
        image=Image.open(path).convert("RGBA")
        gray=image.convert("L")
        mask=gray.point(lambda v:255 if v>160 else 0)
        box=mask.getbbox()
        if not box:
            continue
        image=image.crop(box)
        w,h=image.size
        # Do not make black Arabic letters transparent; these are on white.
        alpha=Image.new("L",(w,h),0)
        ImageDraw.Draw(alpha).rounded_rectangle(
            (0,0,w-1,h-1),radius=min(h//5,w//15),fill=255)
        image.putalpha(alpha)
        return to_png_bytes(image)
    print("FOOTER NOTE: Save the supplied badge as Downloads/academy_footer.png")
    return None

def title_image():
    """Preserve the supplied PINK Salam Baith calligraphy, not blue text."""
    choices = [
        DOWNLOADS / "salam_calligraphy.png",
        DOWNLOADS / "salam_baith_calligraphy.png",
    ]
    source = next((p for p in choices if p.is_file()), None)
    if source is None:
        print("TITLE MISSING: Save the provided pink calligraphy as "
              "Downloads/salam_calligraphy.png")
        return None
    original = Image.open(source).convert("RGBA")
    w, h = original.size
    if w < 10 or h < 10:
        raise ValueError("Salam calligraphy picture is too small")
    rgb = original.convert("RGB")
    corners = [rgb.getpixel((0, 0)), rgb.getpixel((w-1, 0)),
               rgb.getpixel((0, h-1)), rgb.getpixel((w-1, h-1))]
    dark_bg = sum(max(p) < 65 for p in corners) >= 3
    out = Image.new("RGBA", (w, h), (0,0,0,0))
    inp = original.load()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            red, green, blue, existing_alpha = inp[x, y]
            if dark_bg:
                # Pink and magenta strokes, but not black background.
                active = red > 85 and red > green * 1.35 and blue > 45
            else:
                # Keep the original ink in a white-background image.
                active = min(red,green,blue) < 190
            if active:
                dst[x,y] = (red,green,blue,existing_alpha)
    bbox = out.getbbox()
    if not bbox:
        print("TITLE MISSING: no pink lettering detected in", source)
        return None
    art = out.crop(bbox)
    print("SALAM TITLE: exact user-supplied calligraphy:", source.name)
    return to_png_bytes(art)


def build():
    source=find_source()
    original=pymupdf.open(str(source))
    if len(original)!=2:
        raise ValueError("Expected exactly two pages in Salam Baith PDF")
    title=title_image()
    if not (ROOT/"assets/images/academy_footer_exact.png").is_file():
        raise FileNotFoundError(
            "Run python tool/install_academy_footer.py before rebuilding PDFs")
    footer=None  # Flutter renders one exact image, not two
    edited=pymupdf.open()
    for i in range(2):
        p=original[i]
        page=edited.new_page(width=p.rect.width,height=p.rect.height)
        page.show_pdf_page(page.rect,original,i,keep_proportion=False)
        w,h=page.rect.width,page.rect.height
        if i==0 and title:
            # Only replace the original green heading, NOT the Bismillah or text.
            page.draw_rect(pymupdf.Rect(.20*w,.075*h,.80*w,.223*h),
                           fill=(1,1,1),color=None,overlay=True)
            page.insert_image(pymupdf.Rect(.24*w,.085*h,.76*w,.212*h),
                stream=title,keep_proportion=True,overlay=True)
        # Mask the old printed plaque, including its outline; the single
        # common Flutter footer appears on top at the bottom of the page.
        page.draw_rect(pymupdf.Rect(.355*w,.952*h,.645*w,.994*h),
                       fill=(1,1,1),color=None,overlay=True)
    OUT.parent.mkdir(parents=True,exist_ok=True)
    if OUT.exists():
        backup=OUT.with_name("salam_baith.before_update.pdf")
        if not backup.exists():backup.write_bytes(OUT.read_bytes())
    edited.save(str(OUT),garbage=4,deflate=True)
    edited.close();original.close()
    check=pymupdf.open(str(OUT))
    assert len(check)==2
    check.close()
    print("SUCCESS: Salam Baith installed ->",OUT,"(2 original pages)")

if __name__=="__main__":
    build()
