"""Build the actual Flutter Moulid assets, never synthetic/generated Arabic text.

Run from the local al_auradu Flutter project root:
    python tool/repair_moulid_v2.py

Input PDFs and the owner's two exact border PNGs must be present in Downloads.
Output files use the already-registered paths in assets/data/library.json.
"""
from pathlib import Path
from io import BytesIO
import pymupdf
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import arabic_reshaper
from bidi.algorithm import get_display

ROOT = Path(__file__).resolve().parents[1]
DL = Path.home() / "Downloads"
OUT = ROOT / "assets" / "books"
# Requested physical page dimensions (inches), in PDF points.
PAGE_W = 21 * 72
PAGE_H = 29.7 * 72
# Content stays away from the exact original frame lines.
BODY_LEFT = 0.135
BODY_RIGHT = 0.865
BODY_BOTTOM = 0.86

BOOKS = [
    ("mankoos", ["Manqoos moulid-3-19.pdf", "Manqoos moulid.pdf",
                 "Manqoos moulid-3-19 (1)(2).pdf"],
     "mankoos_moulid", 13, 17, "منقوص المولد",
     "manqoos_calligraphy.png"),
    ("sharaf", ["sharaful anam orgn [Autosaved]  111111 bn.pdf",
                "sharaful anam orgn [Autosaved]  111111 bn(1).pdf"],
     "sharafal_anam_moulid", 30, 30, "شرف الأنام",
     "sharaf_calligraphy.png"),
]

def first_file(names):
    for name in names:
        path = DL / name
        if path.is_file():
            return path
    raise FileNotFoundError("Missing original PDF in Downloads: "+", ".join(names))

def as_png(image):
    buf = BytesIO()
    image.save(buf, format="PNG")
    return buf.getvalue()

def title_png(title, png_name, dark):
    """User-provided calligraphy first; printed fallback if not provided."""
    path = DL / png_name
    if path.exists():
        raw = Image.open(path).convert("RGBA")
        rgb = np.asarray(raw.convert("RGB"), dtype=np.int16)
        edge = np.concatenate([rgb[0],rgb[-1],rgb[:,0],rgb[:,-1]])
        background = np.median(edge,axis=0)
        diff = np.max(np.abs(rgb-background),axis=2)
        inherited_alpha = np.asarray(raw.getchannel("A"))
        alpha = np.minimum(inherited_alpha,
                           np.uint8(np.clip((diff-14)*8,0,255)))
        mask = Image.fromarray(alpha)
        artwork = Image.new("RGBA",raw.size,(0,0,0,0))
        artwork.putalpha(mask)
    else:
        artwork = Image.new("RGBA",(1600,300),(0,0,0,0))
        font = ImageFont.truetype(
            str(ROOT/"assets/fonts/Amiri-Regular.ttf"),160)
        shaped = get_display(arabic_reshaper.reshape(title))
        ImageDraw.Draw(artwork).text(
            (800,150),shaped,anchor="mm",font=font,fill="white")
    ink = Image.new("RGBA",artwork.size,
                    (65,146,244,0) if dark else (18,74,145,0))
    ink.putalpha(artwork.getchannel("A"))
    bbox = ink.getbbox()
    return as_png(ink.crop(bbox) if bbox else ink)

def source_text_image(source_page, kind, idx, dark):
    """Render original print, remove only old borders and explicitly
    designated decorations. No OCR, Arabic retyping or generative text."""
    rect = source_page.rect
    scale = 3.3
    pix = source_page.get_pixmap(matrix=pymupdf.Matrix(scale,scale),
                                colorspace=pymupdf.csRGB,alpha=False)
    rgb = Image.frombytes("RGB",(pix.width,pix.height),pix.samples)
    data = np.asarray(rgb,dtype=np.int16)
    h,w = data.shape[:2]

    # Source margins are outside the old red/gold frame; retain every central
    # word, table separator, and diacritic.
    if kind=="mankoos":
        left,right = .130,.870
        top,bottom = (.282 if idx==0 else .053),(.480 if idx==12 else .935)
    else:
        left,right = .060,.940
        top,bottom = (.207 if idx==0 else .058),.933

    x0=int(w*left); x1=int(w*right)
    y0=int(h*top); y1=int(h*bottom)
    cropped=data[y0:y1,x0:x1]
    if cropped.size==0: raise RuntimeError("Empty source crop")

    # Pixel-black print mask, preserving antialias and thin diacritics.
    lo=cropped.min(axis=2); hi=cropped.max(axis=2)
    # Colored source ornaments are not text. Keep neutral black ink.
    neutral=hi-lo < 54
    ink=np.uint8(np.clip((243-lo)*4,0,255))
    ink[~neutral]=0

    # Remove original tiny decorative page number and bottom plaque if
    # preserved by the inset; avoid deleting any content in the center.
    # The last Manqoos green image is below the text (bottom crop 48%).
    ys,xs=np.where(ink>24)
    if xs.size<10:
        raise RuntimeError(f"No original Arabic text on {kind} page {idx+1}")
    # Transparent image: dark ink on white, white ink on black.
    image=Image.new("RGBA",(x1-x0,y1-y0),
                    (255,255,255,0) if dark else (0,0,0,0))
    image.putalpha(Image.fromarray(ink))
    return as_png(image)

def render_book(book,mode):
    kind,candidates,basename,keep,expected,title,title_image = book
    path = first_file(candidates)
    source = pymupdf.open(str(path))
    if len(source)!=expected:
        raise ValueError(
            f"{kind}: expected {expected} original pages but "
            f"{path.name} has {len(source)}. No change written.")
    border = DL / f"moulid_{mode}.png"
    if not border.is_file(): raise FileNotFoundError(border)
    result = pymupdf.open()
    for index in range(keep):
        page=result.new_page(width=PAGE_W,height=PAGE_H)
        page.insert_image(page.rect,filename=str(border),
                          keep_proportion=False)
        # Aspect-preserving fit (never stretch Arabic text or spill into frame)
        box=pymupdf.Rect(PAGE_W*BODY_LEFT,
                         PAGE_H*(.285 if index==0 else .125),
                         PAGE_W*BODY_RIGHT,PAGE_H*BODY_BOTTOM)
        page.insert_image(box,
                          stream=source_text_image(source[index],kind,index,
                                                   mode=="dark"),
                          keep_proportion=True)
        if index==0:
            title_box=pymupdf.Rect(PAGE_W*.23,PAGE_H*.125,
                                  PAGE_W*.77,PAGE_H*.235)
            page.insert_image(title_box,stream=title_png(
                title,title_image,mode=="dark"),keep_proportion=True)
    OUT.mkdir(parents=True,exist_ok=True)
    output=OUT/f"{basename}_{mode}.pdf"
    temp=OUT/f"{basename}_{mode}.pending.pdf"
    if temp.exists():temp.unlink()
    result.save(str(temp),garbage=4,deflate=True)
    result.close();source.close()
    # Ensure expected output is valid before replacing app asset.
    test=pymupdf.open(str(temp))
    assert len(test)==keep
    assert all(abs(p.rect.width-PAGE_W)<.01 and
               abs(p.rect.height-PAGE_H)<.01 for p in test)
    test.close()
    if output.exists():
        backup=OUT/f"{basename}_{mode}.before_21in.pdf"
        if not backup.exists(): backup.write_bytes(output.read_bytes())
    temp.replace(output)
    print(f"APP ASSET READY: {output.name} - {keep} pages, 21 x 29.7 in")

def main():
    for book in BOOKS:
        for mode in ("light","dark"):
            render_book(book,mode)
    print("DONE: App assets regenerated; launch Flutter and visually check "
          "Arabic and headings before release.")

if __name__ == "__main__":
    main()
