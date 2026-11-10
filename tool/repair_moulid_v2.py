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
    rect = source_page.rect
    # Capture ALL Arabic, keeping outside-of-page margin only; avoid removing
    # any of the long Sharaf lines.
    margins = (.06,.055,.06,.07) if kind=="mankoos" else (.028,.032,.028,.045)
    left, top, right, bottom = margins
    clip = pymupdf.Rect(rect.x0+rect.width*left,rect.y0+rect.height*top,
                        rect.x1-rect.width*right,rect.y1-rect.height*bottom)
    pix = source_page.get_pixmap(matrix=pymupdf.Matrix(3.0,3.0),
                                clip=clip,colorspace=pymupdf.csRGB,alpha=False)
    rgb = Image.frombytes("RGB",(pix.width,pix.height),pix.samples)
    data = np.asarray(rgb).astype(np.int16)
    black = np.min(data,axis=2)
    alpha = np.uint8(np.clip((246-black)*5,0,255))

    # Remove the original decorative title/Bismillah on first page.
    if idx == 0:
        # Covers former image heading only, not the following prose.
        fraction = .19 if kind == "mankoos" else .145
        alpha[:int(alpha.shape[0]*fraction),:] = 0

    # Green artwork on Manqoos page 13:
    # detect the green pixels, and erase its whole bounding shape,
    # including pale anti-aliased edges. Never touch other pages.
    if kind=="mankoos" and idx==12:
        green = ((data[:,:,1] > data[:,:,0]+12) &
                 (data[:,:,1] > data[:,:,2]+8) &
                 (data[:,:,1] > 35))
        ys,xs = np.where(green)
        if len(xs)>150:
            pad = 24
            x0=max(0,int(xs.min())-pad); x1=min(alpha.shape[1],int(xs.max())+pad)
            y0=max(0,int(ys.min())-pad); y1=min(alpha.shape[0],int(ys.max())+pad)
            # Remove entire decoration region if only artwork occupies it.
            alpha[y0:y1,x0:x1]=0
            print(f"Manqoos final green decoration cleared: {x0},{y0}-{x1},{y1}")

    # Remove only the last-page decorative picture in Sharaf. Source image
    # block coordinates, rather than manually erasing Arabic lines.
    if kind=="sharaf" and idx==29:
        for block in source_page.get_text("dict").get("blocks",[]):
            if block.get("type")!=1: continue
            box=pymupdf.Rect(block["bbox"])
            if box.y0 < rect.y0+rect.height*.45: continue
            x0=int((box.x0-clip.x0)/clip.width*alpha.shape[1])
            x1=int((box.x1-clip.x0)/clip.width*alpha.shape[1])
            y0=int((box.y0-clip.y0)/clip.height*alpha.shape[0])
            y1=int((box.y1-clip.y0)/clip.height*alpha.shape[0])
            alpha[max(0,y0):min(alpha.shape[0],y1),
                  max(0,x0):min(alpha.shape[1],x1)] = 0

    out=Image.new("RGBA",rgb.size,(255,255,255,0)) if dark else rgb.convert("RGBA")
    out.putalpha(Image.fromarray(alpha))
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
        top=.258 if idx==0 else .130
        target=pymupdf.Rect(width*.155,height*top,width*.845,height*.865)
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
