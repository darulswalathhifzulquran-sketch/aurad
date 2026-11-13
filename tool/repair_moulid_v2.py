"""Build the actual Flutter Moulid assets, never synthetic/generated Arabic text.

Run from the local al_auradu Flutter project root:
    python tool/repair_moulid_v2.py

Input PDFs and the owner's two exact border PNGs must be present in Downloads.
Output files use the already-registered paths in assets/data/library.json.
"""
from pathlib import Path
from io import BytesIO
import pymupdf
from PIL import Image, ImageDraw, ImageFont, ImageFilter
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
BODY_LEFT = 0.116
BODY_RIGHT = 0.884
BODY_BOTTOM = 0.903

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
    if not path.exists():
        matches = sorted(DL.glob("*" + png_name.replace(".png", "") + "*.png"))
        if matches:
            path = matches[-1]
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

    # Antialiased source ink: no hard binary black/white threshold.
    # Colored source ornaments are excluded; all dark neutral Arabic strokes
    # including hairline diacritics remain. Supersampling smooths PDF zoom.
    lo=cropped.min(axis=2); hi=cropped.max(axis=2)
    chroma=hi-lo
    neutral=np.clip((62-chroma)*.08,0,1)
    darkness=np.clip((252-lo)*2.2,0,255)
    ink=np.uint8(np.clip(darkness*neutral,0,255))

    # Sharaf al-Anam: remove the separate final-page picture, never an
    # entire scanned page and never any neighboring Arabic text.
    if kind == "sharaf" and idx == 29:
        for block in source_page.get_text("dict").get("blocks", []):
            if block.get("type") != 1:
                continue
            box = pymupdf.Rect(block["bbox"])
            if box.y0 < rect.height * .48 or box.width > rect.width * .97:
                continue
            xa=max(0,int(box.x0/rect.width*w)-x0)
            xb=min(x1-x0,int(box.x1/rect.width*w)-x0)
            ya=max(0,int(box.y0/rect.height*h)-y0)
            yb=min(y1-y0,int(box.y1/rect.height*h)-y0)
            if xb>xa and yb>ya:
                ink[ya:yb,xa:xb]=0
                print("  Removed separate Sharaf final-page design image")

    ys,xs=np.where(ink>28)
    if xs.size<10:
        raise RuntimeError(f"No original Arabic text on {kind} page {idx+1}")
    # Trim excessive white space *within* the source crop.
    pad_x=max(7,int((x1-x0)*.018))
    pad_y=max(5,int((y1-y0)*.012))
    lx=max(0,int(xs.min())-pad_x); rx=min(ink.shape[1],int(xs.max())+pad_x+1)
    ty=max(0,int(ys.min())-pad_y); by=min(ink.shape[0],int(ys.max())+pad_y+1)
    ink=ink[ty:by,lx:rx]

    # Add breathing space between printed lines, instead of stretching
    # letter shapes. Rows that form a continuous ink run stay untouched.
    active=np.count_nonzero(ink>30,axis=1)>max(3,int(ink.shape[1]*.006))
    gaps=[]
    start=None
    for row,on in enumerate(active):
        if not on and start is None: start=row
        if on and start is not None:
            if row-start>=5: gaps.append((start,row))
            start=None
    if len(gaps)>=7:
        spacer=max(1,min(24,int(ink.shape[1]*.027)))
        pieces=[]
        last=0
        for a,b in gaps:
            pieces.append(ink[last:a,:])
            pieces.append(np.zeros((spacer,ink.shape[1]),dtype=np.uint8))
            last=b
        pieces.append(ink[last:,:])
        ink=np.concatenate(pieces,axis=0)

    # Smooth upsampling is a presentation improvement, not extra source
    # information. Zoom detail ultimately depends on the original PDF.
    alpha=Image.fromarray(ink).resize(
        (ink.shape[1]*2,ink.shape[0]*2),Image.Resampling.LANCZOS)
    image=Image.new("RGBA",alpha.size,
                    (255,255,255,0) if dark else (0,0,0,0))
    image.putalpha(alpha)
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
                         PAGE_H*(.245 if index==0 else .090),
                         PAGE_W*BODY_RIGHT,PAGE_H*BODY_BOTTOM)
        page.insert_image(box,
                          stream=source_text_image(source[index],kind,index,
                                                   mode=="dark"),
                          keep_proportion=True)
        if index==0:
            title_box=pymupdf.Rect(PAGE_W*.20,PAGE_H*.10,
                                  PAGE_W*.80,PAGE_H*.220)
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
