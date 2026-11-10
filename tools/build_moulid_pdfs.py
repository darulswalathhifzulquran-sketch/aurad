"""
Build the four user-approved Mawlid PDF assets, without changing any app UI.
Run on Windows after placing the two source PDFs and the EXACT two border images
in Downloads. Requirements: python -m pip install pymupdf pillow
python tools/build_moulid_pdfs.py --manqoos "..." --sharaf "..." --light-border "..." --dark-border "..."
"""
import argparse
from pathlib import Path
import io
import fitz
from PIL import Image, ImageChops, ImageOps

OUT = Path(__file__).resolve().parents[1] / "assets" / "books"
PAGE_W, PAGE_H = 2172, 2896
# The source PDFs have decorative frames at their extreme edges. Crop
# only the old page frame, keeping the original lettering as a single image.
SOURCE_CROP = (0.112, 0.067, 0.888, 0.927)
TARGET_RECT = (0.119, 0.091, 0.881, 0.908)

def contain(src, width, height):
    ratio = min(width / src.width, height / src.height)
    return src.resize((max(1, round(src.width * ratio)), max(1, round(src.height * ratio))), Image.Resampling.LANCZOS)

def make_book(original_pdf, border_png, out_pdf, dark=False):
    frame = Image.open(border_png).convert("RGB").resize((PAGE_W, PAGE_H), Image.Resampling.LANCZOS)
    src = fitz.open(str(original_pdf))
    result = fitz.open()
    count = 0
    for p in src:
        pix = p.get_pixmap(matrix=fitz.Matrix(3, 3), alpha=False, colorspace=fitz.csRGB)
        original = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
        w, h = original.size
        a,b,c,d = SOURCE_CROP
        content = original.crop((round(w*a), round(h*b), round(w*c), round(h*d)))
        x1,y1,x2,y2 = (round(v * dimension) for v,dimension in zip(TARGET_RECT, (PAGE_W,PAGE_H,PAGE_W,PAGE_H)))
        room_w,room_h = x2-x1,y2-y1
        content = contain(content, room_w, room_h)
        x = x1+(room_w-content.width)//2
        y = y1+(room_h-content.height)//2
        page = frame.copy()
        if dark:
            gray = ImageOps.grayscale(content)
            # Black original ink -> white ink, white original paper -> transparency;
            # preserve anti-aliased diacritics and all original glyph shapes.
            alpha = ImageOps.invert(gray).point(lambda v: min(255, round(v*1.25)))
            ink = Image.new("RGB", content.size, (255,255,255))
            page.paste(ink,(x,y),alpha)
        else:
            # Only the content rectangle is pasted, no reconstruction of Arabic.
            page.paste(content,(x,y))
        stream=io.BytesIO()
        page.save(stream,format="PNG",optimize=True)
        result_page=result.new_page(width=595.28,height=841.89)
        result_page.insert_image(result_page.rect,stream=stream.getvalue())
        count+=1
        print(f"{out_pdf.name}: {count}/{len(src)}",flush=True)
    OUT.mkdir(parents=True,exist_ok=True)
    result.save(str(out_pdf),garbage=4,deflate=True)
    result.close()
    src.close()
    print(f"CREATED: {out_pdf} ({count} pages)")

def main():
    ap=argparse.ArgumentParser()
    for key in ("manqoos","sharaf","light-border","dark-border"):
        ap.add_argument("--"+key,required=True,type=Path)
    a=ap.parse_args()
    for path in (a.manqoos,a.sharaf,a.light_border,a.dark_border):
        if not path.is_file():
            ap.error(f"File not found: {path}")
    for key, source in (("mankoos_moulid",a.manqoos),("sharafal_anam_moulid",a.sharaf)):
        make_book(source,a.light_border,OUT/f"{key}_light.pdf",False)
        make_book(source,a.dark_border,OUT/f"{key}_dark.pdf",True)
    print("DONE: four PDFs are ready; run flutter pub get then flutter run")

if __name__=="__main__":
    main()
