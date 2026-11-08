"""V6: second-preview blue Mushaf frame + sharp, SINGLE-LAYER Quran body.

Never uses old blurry Quran text. Does not change the installed quran.pdf.
Creates 6-page preview by default. Requires pymupdf + Pillow only.

    python tool/compose_quran_v6.py
    python tool/compose_quran_v6.py --all
"""
import argparse
import io
import re
from pathlib import Path

import pymupdf as fitz
from PIL import Image, ImageDraw

from compose_quran_clean_vector import page_svg_as_pdf

BASE = Path(__file__).resolve().parents[1]
ORIGINAL = BASE / "quran.pdf"
VECTOR = BASE / "quran_vector_candidate.pdf"
PREVIEW = BASE / "quran_v6_preview.pdf"
FINAL = BASE / "quran_v6_604.pdf"
FONT = BASE / "assets/fonts/Amiri-Regular.ttf"

SURAH = ("الفاتحة|البقرة|آل عمران|النساء|المائدة|الأنعام|الأعراف|الأنفال|التوبة|يونس|هود|يوسف|الرعد|إبراهيم|"
"الحجر|النحل|الإسراء|الكهف|مريم|طه|الأنبياء|الحج|المؤمنون|النور|الفرقان|الشعراء|النمل|القصص|العنكبوت|الروم|"
"لقمان|السجدة|الأحزاب|سبأ|فاطر|يس|الصافات|ص|الزمر|غافر|فصلت|الشورى|الزخرف|الدخان|الجاثية|الأحقاف|محمد|"
"الفتح|الحجرات|ق|الذاريات|الطور|النجم|القمر|الرحمن|الواقعة|الحديد|المجادلة|الحشر|الممتحنة|الصف|الجمعة|"
"المنافقون|التغابن|الطلاق|التحريم|الملك|القلم|الحاقة|المعارج|نوح|الجن|المزمل|المدثر|القيامة|الإنسان|المرسلات|"
"النبأ|النازعات|عبس|التكوير|الانفطار|المطففين|الانشقاق|البروج|الطارق|الأعلى|الغاشية|الفجر|البلد|الشمس|الليل|"
"الضحى|الشرح|التين|العلق|القدر|البينة|الزلزلة|العاديات|القارعة|التكاثر|العصر|الهمزة|الفيل|قريش|الماعون|"
"الكوثر|الكافرون|النصر|المسد|الإخلاص|الفلق|الناس").split("|")
DIGITS = str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩")

# Positions are fractional coordinates measured from the ORIGINAL page.
# Preserve all blue ornamentation around the outer edge. The source is
# clipped inside the border without importing any of the old pixel Quran.
FRAME_OPENING = (.175, .165, .825, .852)
BODY_DEST = (.187, .171, .814, .844)
TOP_SURAH = (.196, .088, .432, .146)
TOP_JUZ = (.57, .088, .806, .146)
BOTTOM_NUMBER = (.437, .865, .562, .922)

def rect(page, values):
    a,b,c,d = values
    return fitz.Rect(page.rect.x0 + page.rect.width*a,
                     page.rect.y0 + page.rect.height*b,
                     page.rect.x0 + page.rect.width*c,
                     page.rect.y0 + page.rect.height*d)

def starts(name, required):
    code = (BASE / "lib/mushaf.dart").read_text(encoding="utf-8")
    m = re.search(r"const List<int> " + name + r"\s*=\s*\[([^\]]+)\]", code)
    if not m:
        raise ValueError("Could not read " + name)
    numbers = [int(n) for n in re.findall(r"\d+",m.group(1))]
    if len(numbers) != required:
        raise ValueError("Incorrect number of page starts for " + name)
    return numbers

def at(page, boundaries):
    return max((i+1 for i,p in enumerate(boundaries) if p <= page),default=1)

def remove_old_ink_but_keep_frame(page, zoom=3):
    """A transparent *perimeter-only* PNG retaining the actual blue border.

    It is NOT an old PDF background. Every original Quran glyph is removed
    by transparency before overlay. Old surah/juz/page lettering removed too.
    """
    pix = page.get_pixmap(matrix=fitz.Matrix(zoom,zoom),
                          colorspace=fitz.csRGB,alpha=False)
    rgb = Image.frombytes("RGB",(pix.width,pix.height),pix.samples)
    rgba = rgb.convert("RGBA")
    alpha = Image.new("L",(pix.width,pix.height),255)
    mask = ImageDraw.Draw(alpha)
    def erase(frac, extra=0):
        a,b,c,d=frac
        mask.rectangle((int(a*pix.width)-extra,int(b*pix.height)-extra,
                        int(c*pix.width)+extra,int(d*pix.height)+extra),fill=0)
    erase(FRAME_OPENING,2)
    erase(TOP_SURAH,1)
    erase(TOP_JUZ,1)
    erase(BOTTOM_NUMBER,1)
    rgba.putalpha(alpha)
    b=io.BytesIO()
    rgba.save(b,format="PNG")
    return b.getvalue()

def source_crop(page, number):
    """Crop away Illustrator paper margins, page title, and green shapes.

    For ordinary pages retain every Quran body row and every decorative
    ayah numeral. For Fatiha / Baqara opening, preserve circular layout.
    """
    if number in (1,2):
        return rect(page,(.215,.155,.785,.865))
    # AI Arabic reading text covers the central panel; tighter than the
    # full imported AI sheet, wider than the hand-trimmed V2 box.
    return rect(page,(.178,.163,.822,.867))

def vector_title(page, bounds, text, size=12):
    if not FONT.is_file():
        raise RuntimeError("Amiri font missing: " + str(FONT))
    css=("@font-face{font-family:Amiri;src:url('Amiri-Regular.ttf')}"
         "div{font-family:Amiri;text-align:center;direction:rtl;"
         "color:#174d74;font-size:14pt;line-height:1.1;margin:0}")
    area=rect(page,bounds)
    # First cover old raster caption with a white rect. The frame's blue
    # decoration outside the capsule is not touched by this label.
    page.draw_rect(area,fill=(1,1,1),color=None,overlay=True)
    available,_=page.insert_htmlbox(
        area, f"<div dir='rtl'>{text}</div>", css=css,
        archive=fitz.Archive(str(FONT.parent)),
        scale_low=.35,overlay=True)
    if available < 0:
        raise RuntimeError("Arabic title did not fit: "+text)

def build(indices,path):
    sstarts=starts("kSurahPage",114)
    jstarts=starts("kJuzPage",30)
    if len(SURAH)!=114:
        raise RuntimeError("Surah mapping invalid")
    out=fitz.open()
    try:
        with fitz.open(ORIGINAL) as old,fitz.open(VECTOR) as ai:
            if len(old)!=604 or len(ai)!=604:
                raise RuntimeError("Expected both Mushaf PDFs to contain 604 pages")
            for n in indices:
                o=old[n-1]
                src=ai[n-1]
                clean,greens=page_svg_as_pdf(src)
                try:
                    if not greens:
                        raise RuntimeError(f"Page {n}: green source colors not removed")
                    page=out.new_page(width=o.rect.width,height=o.rect.height)
                    # Only ONE vector Quran text layer. The 2026 green PDF
                    # source is recolored white before use.
                    page.show_pdf_page(rect(page,BODY_DEST),clean,0,
                        clip=source_crop(src,n),keep_proportion=False,overlay=True)
                    # The blue and silver border from the old edition is
                    # inserted with the ORIGINAL TEXT AREA fully transparent.
                    page.insert_image(page.rect,
                        stream=remove_old_ink_but_keep_frame(o),
                        overlay=True,keep_proportion=False)
                    vector_title(page,TOP_SURAH,"سورة "+SURAH[at(n,sstarts)-1])
                    vector_title(page,TOP_JUZ,"الجزء "+str(at(n,jstarts)).translate(DIGITS))
                    vector_title(page,BOTTOM_NUMBER,str(n).translate(DIGITS))
                    print(f"Page {n}: vector Quran; old text 0; blue border; "
                          f"green removed {greens}",flush=True)
                finally:
                    clean.close()
        out.save(path,garbage=3,deflate=True)
    finally:
        out.close()
    print("DONE:",path)
    print("Working quran.pdf was not changed. Inspect Quran line breaks and border.")

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--all",action="store_true")
    args=p.parse_args()
    if not ORIGINAL.exists() or not VECTOR.exists():
        raise SystemExit("Need quran.pdf and quran_vector_candidate.pdf")
    indices=range(1,605) if args.all else (1,2,3,208,252,604)
    build(indices,FINAL if args.all else PREVIEW)
