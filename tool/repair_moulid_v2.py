"""Mawlid edition V2: original Arabic pages, approved unmodified borders.

Needs: pip install pymupdf pillow numpy arabic-reshaper python-bidi
Optional owner calligraphy images in Downloads:
  manqoos_calligraphy.png
  sharaf_calligraphy.png
Run from project root: python tool/repair_moulid_v2.py
"""
from pathlib import Path
from io import BytesIO
import pymupdf
from PIL import Image, ImageOps, ImageDraw, ImageFont
import numpy as np
import arabic_reshaper
from bidi.algorithm import get_display

ROOT = Path(__file__).resolve().parents[1]
DL = Path.home() / "Downloads"
OUT = ROOT / "assets" / "books"
BOOKS = [
    ("mankoos", DL / "Manqoos moulid-3-19.pdf",
     "mankoos_moulid", 17, 13, "منقوص مولد", "manqoos_calligraphy.png"),
    ("sharaf", DL / "sharaful anam orgn [Autosaved]  111111 bn.pdf",
     "sharafal_anam_moulid", 30, 30, "شرف الأنام", "sharaf_calligraphy.png"),
]

def png(im):
    buf = BytesIO()
    im.save(buf, format="PNG")
    return buf.getvalue()

def heading(text, filename, dark):
    """Prefer owner's exact artwork; fallback to shaped Amiri Arabic."""
    path = DL / filename
    if path.exists():
        img = Image.open(path).convert("RGBA")
        arr = np.asarray(img.convert("RGB")).astype(np.int16)
        # All supplied examples use flat white or black backgrounds.
        edges = np.concatenate([arr[0,:,:], arr[-1,:,:],arr[:,0,:],arr[:,-1,:]])
        bg = np.median(edges, axis=0)
        dist = np.max(np.abs(arr-bg), axis=2)
        mask = Image.fromarray(np.uint8(np.clip((dist - 12)*8,0,255)))
        img.putalpha(mask)
    else:
        img = Image.new("RGBA", (1400, 240), (0,0,0,0))
        font = ImageFont.truetype(str(ROOT/"assets/fonts/Amiri-Regular.ttf"), 128)
        value = get_display(arabic_reshaper.reshape(text))
        ImageDraw.Draw(img).text((700,120),value,anchor="mm",font=font,
                                 fill=(255,255,255,255))
    # Recolor only the calligraphy strokes BLUE, not the border.
    alpha = img.getchannel("A")
    blue = Image.new("RGBA", img.size, (75,153,238,0) if dark
                     else (27,86,173,0))
    blue.putalpha(alpha)
    # Crop only transparent external whitespace.
    bb = blue.getbbox()
    return png(blue.crop(bb) if bb else blue)

def page_art(source_page, kind, idx, dark):
    """Extract only printed dark Arabic; no former border/artwork/background.

    The previous pipeline placed an entire old page inside the new frame,
    producing double borders, tiny script and visible cropped ornaments.
    This edition trims to the actual remaining ink bounding box.
    """
    rect = source_page.rect
    px = source_page.get_pixmap(
        matrix=pymupdf.Matrix(3.5, 3.5),
        colorspace=pymupdf.csRGB, alpha=False,
    )
    rgb = Image.frombytes("RGB", (px.width, px.height), px.samples)
    data = np.asarray(rgb, dtype=np.int16)
    H, W = data.shape[:2]

    # Keep only black/grey ink, suppress gold/green decorative illustrations.
    hi = data.max(axis=2)
    lo = data.min(axis=2)
    neutral = (hi-lo <= 26)
    darkness = np.clip((220-lo)*4,0,255)
    ink = (neutral & (lo < 205)).astype(np.uint8)*darkness.astype(np.uint8)

    # Remove source page's outer strips, including original decorative frame.
    # Never erase inside the central reading column.
    side = .15 if kind=="mankoos" else .105
    ink[:int(.035*H),:] = 0
    ink[int(.960*H):,:] = 0
    ink[:, :int(side*W)] = 0
    ink[:, int((1-side)*W):] = 0

    # First page: remove source decorative heading; insert the owner's blue
    # calligraphy in a separate frame region.
    if idx == 0:
        ink[:int((.22 if kind=="mankoos" else .18)*H),:] = 0

    # Remove Manqoos final green design *including* its faded black shadow.
    # Restrict to detected green artwork's region, not the full page.
    if kind=="mankoos" and idx==12:
        green=((data[:,:,1]>data[:,:,0]+12)&
               (data[:,:,1]>data[:,:,2]+9)&
               (data[:,:,1]>40))
        yy,xx=np.where(green)
        if len(xx)>100:
            pad=max(20,int(W*.018))
            l=max(0,int(xx.min())-pad); r=min(W,int(xx.max())+pad)
            t=max(0,int(yy.min())-pad); d=min(H,int(yy.max())+pad)
            ink[t:d,l:r]=0
            print("  Removed Manqoos green calligraphy and shadow")

    # Sharaf's last page has embedded decorative image artwork.
    if kind=="sharaf" and idx==29:
        for block in source_page.get_text("dict").get("blocks",[]):
            if block.get("type")!=1: continue
            box=pymupdf.Rect(block["bbox"])
            if box.y0<rect.y0+rect.height*.45: continue
            x0=max(0,int(box.x0/rect.width*W)-5)
            x1=min(W,int(box.x1/rect.width*W)+5)
            y0=max(0,int(box.y0/rect.height*H)-5)
            y1=min(H,int(box.y1/rect.height*H)+5)
            ink[y0:y1,x0:x1]=0

    # Crop to ink extents. This prevents huge blank margins or tiny script.
    where=np.where(ink>70)
    if where[0].size<30:
        raise ValueError(f"No Arabic ink detected in {kind} page {idx+1}")
    pad_x=int(W*.016); pad_y=int(H*.010)
    x0=max(0,int(where[1].min())-pad_x)
    x1=min(W,int(where[1].max())+pad_x+1)
    y0=max(0,int(where[0].min())-pad_y)
    y1=min(H,int(where[0].max())+pad_y+1)
    ink=ink[y0:y1,x0:x1]
    if dark:
        out=Image.new("RGBA", (x1-x0,y1-y0), (255,255,255,0))
    else:
        out=Image.new("RGBA", (x1-x0,y1-y0), (0,0,0,0))
    out.putalpha(Image.fromarray(ink))
    return png(out)

def build(kind, source_file, base, expected, count, title, title_image, mode):
    source=pymupdf.open(str(source_file))
    if len(source)!=expected:
        raise RuntimeError(f"{kind}: expected {expected} original pages; got {len(source)}")
    border=DL / f"moulid_{mode}.png"
    width,height=Image.open(border).size
    doc=pymupdf.open()
    for idx in range(count):
        page=doc.new_page(width=width,height=height)
        page.insert_image(page.rect,filename=str(border),keep_proportion=False)
        # INSET safe area: content must not cross inner blue/gold lines.
        # Use an equal scale factor (no stretched or clipped Arabic).
        # Leave title space above first page; other pages use more of height.
        top=.275 if idx==0 else .145
        target=pymupdf.Rect(width*.132,height*top,width*.868,height*.857)
        art=page_art(source[idx],kind,idx,mode=="dark")
        page.insert_image(target,stream=art,keep_proportion=True)
        if idx==0:
            head=pymupdf.Rect(width*.23,height*.145,width*.77,height*.235)
            page.insert_image(head,stream=heading(title,title_image,mode=="dark"),
                              keep_proportion=True)
    out=OUT/f"{base}_{mode}.pdf"
    old=out.with_suffix(".v1-backup.pdf")
    if out.exists() and not old.exists():
        out.rename(old)
    doc.save(str(out),garbage=4,deflate=True)
    print(f"CREATED: {out.name} ({len(doc)} pages)")
    doc.close();source.close()

def main():
    for mode in ("light","dark"):
        if not (DL/f"moulid_{mode}.png").is_file():
            raise FileNotFoundError(f"Missing border: moulid_{mode}.png")
    for book in BOOKS:
        if not book[1].is_file(): raise FileNotFoundError(book[1])
    OUT.mkdir(parents=True,exist_ok=True)
    for book in BOOKS:
        for mode in ("light","dark"): build(*book,mode)
    print("DONE: 4 PDF files rebuilt. Inspect first, middle and last pages.")

if __name__=="__main__":
    main()
