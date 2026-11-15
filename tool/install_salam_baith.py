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
    """Install the user's latest GREEN 'سلام بيت' image, not an old title.

    No Arabic letters are retyped. Preserve the uploaded calligraphy's
    exact green pixels, remove only its white background.
    """
    choices = [
        DOWNLOADS / "salam_baith_green_calligraphy.png",
        DOWNLOADS / "dec37185-c755-4674-802d-13ca7848256b(2).png",
    ]
    source = next((p for p in choices if p.is_file()), None)
    if source is None:
        raise FileNotFoundError(
            "GREEN TITLE MISSING. Save the latest green Salam Baith "
            "calligraphy to Downloads/salam_baith_green_calligraphy.png. "
            "Old pink/blue title will NOT be substituted.")
    original = Image.open(source).convert("RGBA")
    if original.width < 80 or original.height < 30:
        raise ValueError("Calligraphy PNG too small")
    w, h = original.size
    output = Image.new("RGBA", (w, h), (0,0,0,0))
    src=original.load()
    dest=output.load()
    count=0
    for y in range(h):
        for x in range(w):
            red, green, blue, a=src[x,y]
            # Actual green letter ink: leave hue untouched, use green
            # predominance for alpha so white background stays invisible.
            dominance = green - max(red,blue)
            alpha = max(0,min(255,int(dominance*4.0)))
            alpha = alpha*a//255
            if alpha>0:
                dest[x,y]=(red,green,blue,alpha)
                count+=1
    box=output.getbbox()
    if count < 150 or not box:
        raise ValueError(
            "GREEN TITLE NOT DETECTED. The selected picture is not "
            "the user's green سلام بيت calligraphy.")
    artwork=output.crop(box)
    print("GREEN SALAM TITLE:", source.name, artwork.width, "x", artwork.height)
    return to_png_bytes(artwork)


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
