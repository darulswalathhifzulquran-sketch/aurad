"""Quran release candidate: a single vector Quran text layer with original blue frame.

No old Quran text is ever inserted. The OLD PDF is rasterized ONLY into
transparent frame art, its entire center removed. Source vector Arabic is
copied once as true vector. No colored dark-mode PDF is used automatically.

Default: 6 page preview. --all: 604 page candidate (not installed).
"""
import argparse
import io
import re
from pathlib import Path

import pymupdf as fitz
from PIL import Image, ImageDraw

from compose_quran_clean_vector import page_svg_as_pdf

ROOT = Path(__file__).resolve().parents[1]
OLD = ROOT / "quran.pdf"
NEW = ROOT / "quran_vector_candidate.pdf"
PREVIEW = ROOT / "quran_release_preview.pdf"
FULL = ROOT / "quran_release_candidate.pdf"
PAGE_NUMBERS = (1, 2, 3, 208, 252, 604)
FONT = ROOT / "assets" / "fonts" / "Amiri-Regular.ttf"

# Measured as proportion of the original paper size.
# The entire old Quran text rectangle (including top and bottom row) is
# REMOVED, not covered by another opaque rectangular patch.
OLD_HOLE = (0.144, 0.152, 0.857, 0.871)
NEW_BODY = (0.168, 0.160, 0.832, 0.856)
HEADER_LEFT = (0.20, 0.09, 0.425, 0.148)
HEADER_RIGHT = (0.575, 0.09, 0.80, 0.148)
NUMBER = (0.447, 0.878, 0.552, 0.921)

SURAH = ("الفاتحة|البقرة|آل عمران|النساء|المائدة|الأنعام|الأعراف|الأنفال|التوبة|يونس|هود|يوسف|الرعد|إبراهيم|"
"الحجر|النحل|الإسراء|الكهف|مريم|طه|الأنبياء|الحج|المؤمنون|النور|الفرقان|الشعراء|النمل|القصص|العنكبوت|الروم|"
"لقمان|السجدة|الأحزاب|سبأ|فاطر|يس|الصافات|ص|الزمر|غافر|فصلت|الشورى|الزخرف|الدخان|الجاثية|الأحقاف|محمد|"
"الفتح|الحجرات|ق|الذاريات|الطور|النجم|القمر|الرحمن|الواقعة|الحديد|المجادلة|الحشر|الممتحنة|الصف|الجمعة|"
"المنافقون|التغابن|الطلاق|التحريم|الملك|القلم|الحاقة|المعارج|نوح|الجن|المزمل|المدثر|القيامة|الإنسان|المرسلات|"
"النبأ|النازعات|عبس|التكوير|الانفطار|المطففين|الانشقاق|البروج|الطارق|الأعلى|الغاشية|الفجر|البلد|الشمس|الليل|"
"الضحى|الشرح|التين|العلق|القدر|البينة|الزلزلة|العاديات|القارعة|التكاثر|العصر|الهمزة|الفيل|قريش|الماعون|"
"الكوثر|الكافرون|النصر|المسد|الإخلاص|الفلق|الناس").split("|")
DIGITS = str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩")

def rel(page, coords):
    x0,y0,x1,y1=coords
    return fitz.Rect(page.rect.x0+x0*page.rect.width,
                     page.rect.y0+y0*page.rect.height,
                     page.rect.x0+x1*page.rect.width,
                     page.rect.y0+y1*page.rect.height)

def starts(name, expected):
    code=(ROOT / "lib/mushaf.dart").read_text(encoding="utf-8")
    m=re.search(r"const List<int> "+name+r"\s*=\s*\[([^\]]+)\]",code,re.S)
    if m is None:
        raise ValueError("Missing page starts "+name)
    values=[int(x) for x in re.findall(r"\d+",m.group(1))]
    if len(values)!=expected:
        raise ValueError("Wrong number of starts "+name)
    return values

def section(number, mapping):
    return max((i+1 for i,p in enumerate(mapping) if p<=number),default=1)

def frame_png(page, scale=3):
    pix=page.get_pixmap(matrix=fitz.Matrix(scale,scale),
                        colorspace=fitz.csRGB,alpha=False)
    old=Image.frombytes("RGB",(pix.width,pix.height),pix.samples)
    rgba=old.convert("RGBA")
    a=Image.new("L",old.size,255)
    draw=ImageDraw.Draw(a)
    def erase(bounds, margin=0):
        xa,ya,xb,yb=bounds
        draw.rectangle((int(xa*pix.width)-margin,
                        int(ya*pix.height)-margin,
                        int(xb*pix.width)+margin,
                        int(yb*pix.height)+margin),fill=0)
    erase(OLD_HOLE,2)
    # Remove ONLY dark lettering in the header/page-number capsule interiors,
    # while leaving the decorative blue exterior and pale blue fill intact.
    pixels=old.load()
    m=a.load()
    for box in (HEADER_LEFT,HEADER_RIGHT,NUMBER):
        x0,y0,x1,y1=box
        # narrow area within capsule to keep rounded blue edges
        xmin,xmax=int((x0+.012)*pix.width),int((x1-.012)*pix.width)
        ymin,ymax=int((y0+.008)*pix.height),int((y1-.008)*pix.height)
        for y in range(ymin,ymax):
            for x in range(xmin,xmax):
                r,g,b=pixels[x,y]
                if max(r,g,b)<145 and max(r,g,b)-min(r,g,b)<48:
                    m[x,y]=0
    rgba.putalpha(a)
    data=io.BytesIO()
    rgba.save(data,format="PNG")
    return data.getvalue()

def source_body(page, n):
    # Use actual Arabic black glyph extents within source reading area,
    # not a random center crop. Prevents truncated words/diacritics.
    pix=page.get_pixmap(matrix=fitz.Matrix(2,2),
                        colorspace=fitz.csRGB,alpha=False)
    w,h=pix.width,pix.height
    pixels=pix.samples
    if n<=2:
        bounds=(.16,.20,.85,.83)
    else:
        bounds=(.12,.17,.88,.86)
    xa,ya,xb,yb=(int(bounds[0]*w),int(bounds[1]*h),
                 int(bounds[2]*w),int(bounds[3]*h))
    xs=[];ys=[]
    for y in range(ya,yb,2):
        for x in range(xa,xb,2):
            k=(y*w+x)*3
            if max(pixels[k],pixels[k+1],pixels[k+2])<130:
                xs.append(x);ys.append(y)
    if not xs:
        raise ValueError(f"Cannot detect Arabic body on page {n}")
    # Larger safety margin for diacritics and verse-number ornaments.
    px=int(.020*w)
    py=int(.012*h)
    return fitz.Rect(max(0,(min(xs)-px)/2),
                     max(0,(min(ys)-py)/2),
                     min(page.rect.width,(max(xs)+px)/2),
                     min(page.rect.height,(max(ys)+py)/2))

def label(page, box, text):
    if not FONT.is_file():
        print("WARNING: Amiri title font missing, skipped: ",text)
        return
    css=("@font-face{font-family:amiri;src:url('Amiri-Regular.ttf')}"
         "div{font-family:amiri;font-size:11pt;text-align:center;"
         "color:#17486a;margin:0;line-height:1.0}")
    remaining,_=page.insert_htmlbox(
        rel(page,box),f"<div dir='rtl'>{text}</div>",
        css=css,archive=fitz.Archive(str(FONT.parent)),
        scale_low=.40,overlay=True)
    if remaining<0:
        raise ValueError(f"Cannot fit title: {text}")

def build(page_numbers,output):
    if not OLD.is_file() or not NEW.is_file():
        raise SystemExit("Missing quran.pdf or quran_vector_candidate.pdf in project")
    surah_starts=starts("kSurahPage",114)
    juz_starts=starts("kJuzPage",30)
    if len(SURAH)!=114:
        raise ValueError("Incorrect Surah name mapping")
    result=fitz.open()
    try:
        with fitz.open(OLD) as old,fitz.open(NEW) as source:
            if len(old)!=604 or len(source)!=604:
                raise ValueError("Both PDF files must have 604 pages")
            for n in page_numbers:
                fresh,green=page_svg_as_pdf(source[n-1])
                try:
                    if green==0:
                        raise ValueError(f"Unremoved source green background: page {n}")
                    p=result.new_page(width=old[n-1].rect.width,
                                      height=old[n-1].rect.height)
                    clip=source_body(fresh[0],n)
                    # This document never includes the old Arabic body.
                    p.show_pdf_page(rel(p,NEW_BODY),fresh,0,clip=clip,
                                    keep_proportion=(n<=2),overlay=True)
                    p.insert_image(p.rect,stream=frame_png(old[n-1]),
                                   keep_proportion=False,overlay=True)
                    label(p,HEADER_LEFT,"سورة "+SURAH[section(n,surah_starts)-1])
                    label(p,HEADER_RIGHT,"الجزء "+str(section(n,juz_starts)).translate(DIGITS))
                    label(p,NUMBER,str(n).translate(DIGITS))
                    print(f"Page {n}: single vector text; blue frame; green removed={green}",flush=True)
                finally:
                    fresh.close()
        result.save(output,garbage=3,deflate=True)
    finally:
        result.close()
    print("CREATED:",output)
    print("Original Quran PDF NOT changed. Compare 3, 208, 252 before release.")

if __name__=="__main__":
    ap=argparse.ArgumentParser()
    ap.add_argument("--all",action="store_true")
    flags=ap.parse_args()
    build(range(1,605) if flags.all else PAGE_NUMBERS,
          FULL if flags.all else PREVIEW)
