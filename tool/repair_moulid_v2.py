"""Rebuild original Moulid PDF app assets with precise, non-destructive edits.

The original Arabic stays PDF-native (not OCR or a pixelated image).
Input files are searched in the user's Windows Downloads directory.
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
        "sharaful anam orgn [Autosaved]  111111 bn(3).pdf",
        "sharaful anam orgn [Autosaved]  111111 bn(2).pdf",
        "sharaful anam orgn [Autosaved]  111111 bn.pdf",
    ], "sharafal_anam_moulid", 30, 30),
]

def find_source(names):
    for name in names:
        p = DL / name
        if p.is_file():
            return p
    raise FileNotFoundError("Save original PDF in Downloads: " + " / ".join(names))

def rect_for(page, coords):
    r = page.rect
    return pymupdf.Rect(r.x0+r.width*coords[0],r.y0+r.height*coords[1],
                        r.x0+r.width*coords[2],r.y0+r.height*coords[3])

def cover_white(page,coords):
    page.draw_rect(rect_for(page,coords), color=None, fill=(1,1,1),overlay=True)

def get_footer_image():
    from PIL import Image, ImageDraw
    # Prefer the exact artwork the user supplied, saved as download.png.
    asset = next((p for p in (DL/"moulid_footer.png",DL/"download.png",
                   DL/"academy_footer.png") if p.is_file()),None)
    if asset:
        im = Image.open(asset).convert("RGBA")
        # User's design is a white rounded badge on an external black field.
        # Remove ONLY exterior black, retaining black lettering inside badge.
        pixels = im.load()
        w,h=im.size
        white_bbox=im.convert("RGB").point(
            lambda v: 255 if v>175 else 0).getbbox()
        if white_bbox:
            l,t,r,b=white_bbox
            l=max(0,l-3);t=max(0,t-3);r=min(w,r+3);b=min(h,b+3)
            im=im.crop((l,t,r,b))
            # Black outside the plaque becomes transparent; enclosed black
            # Arabic letters remain opaque because their background is white.
            rgb=im.convert("RGB")
            from PIL import ImageDraw
            # Per-row segmented white plaque spans (excluding text holes).
            mask=Image.new("L",im.size,0)
            d=ImageDraw.Draw(mask)
            rw,rh=im.size
            for y in range(rh):
                spans=[]
                inside=False
                start=0
                for x in range(rw):
                    c=rgb.getpixel((x,y))
                    bright=min(c)>175
                    if bright and not inside:
                        start=x;inside=True
                    elif not bright and inside:
                        if x-start>=max(2,rw//200):spans.append((start,x))
                        inside=False
                if inside and rw-start>=max(2,rw//200):
                    spans.append((start,rw))
                if spans:
                    # Outer white capsule silhouette must be broad, not one
                    # isolated Arabic stroke.
                    left=spans[0][0];right=spans[-1][1]
                    if right-left>rw*.6:
                        d.line((left,y,right,y),fill=255,width=1)
            im.putalpha(mask)
            visible=mask.getbbox()
            if visible:
                im=im.crop(visible)
        print("FOOTER ART: using exact saved user picture",asset.name)
    else:
        border=DL/"moulid_light.png"
        if not border.is_file():
            print("FOOTER ART MISSING: save the 4th screenshot as Downloads/download.png")
            return None
        old=Image.open(border).convert("RGB")
        w,h=old.size
        im=old.crop((int(w*.28),int(h*.918),int(w*.72),int(h*.994))).convert("RGBA")
        print("FOOTER ART: using previously approved moulid_light.png plaque")
    buf=BytesIO()
    im.save(buf,format="PNG")
    return buf.getvalue()

def put_footer(page,badge):
    if not badge:
        return
    # Old source plaque is around the bottom centre. Never cover the body
    # or the ornate four corners; unlike the former broad .934-.999 mask.
    cover_white(page,(.305,.957,.695,.991))
    dest=rect_for(page,(.300,.952,.700,.992))
    page.insert_image(dest,stream=badge,overlay=True,keep_proportion=False)

def remove_last_sharaf_calligraphy(page):
    # Last-page illustration is isolated well below the Arabic du'a text.
    cover_white(page,(.17,.575,.83,.884))


def renumber_manqoos_page(page, number):
    """Replace printed source numbering 3-15 with clean 1-13, keeping
    all Arabic verses and the decorative border untouched."""
    from PIL import Image, ImageDraw, ImageFont
    page_w, page_h = page.rect.width, page.rect.height
    # Printed numeral lies at the top-centre above the Arabic body.
    number_area = (.455, .004, .545, .053)
    cover_white(page, number_area)
    label = str(number).translate(str.maketrans(
        "0123456789", "٠١٢٣٤٥٦٧٨٩"))
    image = Image.new("RGBA", (240, 120), (255, 255, 255, 0))
    draw = ImageDraw.Draw(image)
    try:
        font = ImageFont.truetype("arial.ttf", 68)
    except OSError:
        font = ImageFont.load_default()
        label = str(number)
    draw.text((120, 60), label, font=font, anchor="mm",
              fill=(12, 33, 51, 255))
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    page.insert_image(pymupdf.Rect(page_w*.471, page_h*.013,
                    page_w*.529, page_h*.052),
                    stream=buffer.getvalue(), overlay=True,
                    keep_proportion=False)

def remove_manqoos_green(page,source):
    # Green artwork is a colored standalone ornament, not Arabic body text.
    # Determine its actual location from source pixels, not guessed margins.
    try:
        from PIL import Image
        pix=source.get_pixmap(matrix=pymupdf.Matrix(1.0,1.0),
                              colorspace=pymupdf.csRGB,alpha=False)
        im=Image.frombytes("RGB",(pix.width,pix.height),pix.samples)
        xs=[];ys=[]
        for y in range(0,im.height,2):
            for x in range(0,im.width,2):
                r,g,b=im.getpixel((x,y))
                if g>r*1.45 and g>b*1.28 and g>58:
                    xs.append(x);ys.append(y)
        if len(xs)>70:
            box=(max(0,(min(xs)-4)/im.width),
                 max(0,(min(ys)-4)/im.height),
                 min(1,(max(xs)+4)/im.width),
                 min(1,(max(ys)+4)/im.height))
            cover_white(page,box)
            print("  Removed green Manqoos art:",[round(z,3) for z in box])
    except Exception as exc:
        print("  Green ornament inspection skipped:",exc)

def build(book,badge):
    title,names,base,count,expected=book
    path=find_source(names)
    src=pymupdf.open(str(path))
    if len(src)!=expected:
        raise ValueError(f"{title}: expected {expected}, got {len(src)} pages in {path.name}")
    result=pymupdf.open()
    for i in range(count):
        original=src[i]
        page=result.new_page(width=original.rect.width,height=original.rect.height)
        page.show_pdf_page(page.rect,src,i,keep_proportion=False)
        if base=="mankoos_moulid":
            renumber_manqoos_page(page, i+1)
            if i==count-1:
                remove_manqoos_green(page,original)
        if base=="sharafal_anam_moulid" and i==count-1:
            remove_last_sharaf_calligraphy(page)
        # Preserve every Sharaf al-Anam printed page-number capsule.
        put_footer(page,badge)

    OUT.mkdir(parents=True,exist_ok=True)
    for mode in ("light","dark"):
        output=OUT/f"{base}_{mode}.pdf"
        temp=output.with_suffix(".pending.pdf")
        if temp.exists():temp.unlink()
        result.save(str(temp),garbage=4,deflate=True)
        check=pymupdf.open(str(temp))
        if len(check)!=count:raise ValueError("Page count verification failed")
        check.close()
        if output.exists():
            backup=OUT/f"{base}_{mode}.backup_before_update.pdf"
            if not backup.exists():backup.write_bytes(output.read_bytes())
        temp.replace(output)
        print(f"APP ASSET READY: {output.name} ({count} pages)")
    result.close()
    src.close()

def main():
    badge=get_footer_image()
    for book in BOOKS:
        build(book,badge)
    print("DONE. Printed page numbers retained. Native PDF Arabic retained.")

if __name__=="__main__":
    main()
