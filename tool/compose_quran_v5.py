"""Create a new blue-frame Mushaf PDF without the old blurry text.

Uses Illustrator VECTOR Quran pages for every Arabic line. The old PDF is
used ONLY as a framed picture with its central text erased. This script never
modifies the working quran.pdf, and never layers old text behind new text.

Preview: python tool/compose_quran_v5.py
Full:    python tool/compose_quran_v5.py --all
"""
import argparse
import io
import re
from pathlib import Path
from PIL import Image, ImageDraw
import pymupdf

ROOT = Path(__file__).resolve().parents[1]
OLD = ROOT / "quran.pdf"
NEW = ROOT / "quran_vector_candidate.pdf"
PREVIEW = ROOT / "quran_v5_preview.pdf"
FINAL = ROOT / "quran_v5_604.pdf"
PAGES = (1, 2, 3, 208, 252, 604)
AMIRI = ROOT / "assets" / "fonts" / "Amiri-Regular.ttf"

# Coordinates relative to ORIGINAL PDF page dimensions.
# Outer frame: original ornamental artwork including both side columns,
# top/bottom bars, side marker, and top capsule OUTLINES.
# The center is not pasted at all (so ZERO old Quran glyphs can survive).
FRAME_HOLE = (0.158, 0.158, 0.844, 0.862)
READING_AREA = (0.176, 0.174, 0.826, 0.829)
HEADER_LEFT = (0.200, 0.094, 0.422, 0.140)
HEADER_RIGHT = (0.578, 0.094, 0.800, 0.140)
FOOT_NUMBER = (0.434, 0.875, 0.566, 0.924)

def rel(p, vals):
    return pymupdf.Rect(p.rect.x0 + vals[0] * p.rect.width,
                        p.rect.y0 + vals[1] * p.rect.height,
                        p.rect.x0 + vals[2] * p.rect.width,
                        p.rect.y0 + vals[3] * p.rect.height)

def page_starts():
    txt = (ROOT / "lib" / "mushaf.dart").read_text(encoding="utf8")
    found = []
    for name, needed in (("kSurahPage",114),("kJuzPage",30)):
        m = re.search(r"const List<int> " + name + r"\s*=\s*\[([^\]]+)\]",txt)
        if not m:
            raise ValueError("Missing Quran metadata: " + name)
        pages = [int(x) for x in re.findall(r"\d+", m.group(1))]
        if len(pages) != needed:
            raise ValueError("Invalid Quran metadata count: " + name)
        found.append(pages)
    return found

SURAH = ("الفاتحة|البقرة|آل عمران|النساء|المائدة|الأنعام|الأعراف|الأنفال|التوبة|يونس|هود|يوسف|الرعد|إبراهيم|"
"الحجر|النحل|الإسراء|الكهف|مريم|طه|الأنبياء|الحج|المؤمنون|النور|الفرقان|الشعراء|النمل|القصص|العنكبوت|الروم|"
"لقمان|السجدة|الأحزاب|سبأ|فاطر|يس|الصافات|ص|الزمر|غافر|فصلت|الشورى|الزخرف|الدخان|الجاثية|الأحقاف|محمد|"
"الفتح|الحجرات|ق|الذاريات|الطور|النجم|القمر|الرحمن|الواقعة|الحديد|المجادلة|الحشر|الممتحنة|الصف|الجمعة|"
"المنافقون|التغابن|الطلاق|التحريم|الملك|القلم|الحاقة|المعارج|نوح|الجن|المزمل|المدثر|القيامة|الإنسان|المرسلات|"
"النبأ|النازعات|عبس|التكوير|الانفطار|المطففين|الانشقاق|البروج|الطارق|الأعلى|الغاشية|الفجر|البلد|الشمس|الليل|"
"الضحى|الشرح|التين|العلق|القدر|البينة|الزلزلة|العاديات|القارعة|التكاثر|العصر|الهمزة|الفيل|قريش|الماعون|"
"الكوثر|الكافرون|النصر|المسد|الإخلاص|الفلق|الناس").split("|")

def current(starts, page):
    return max((i + 1 for i, value in enumerate(starts) if value <= page), default=1)

def arabic_numbers(n):
    return str(n).translate(str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩"))

def render_title(page, bounds, txt, fontsize=12.5):
    if not AMIRI.is_file():
        raise ValueError("Required Amiri font not installed in assets/fonts.")
    # HTML shaping supports Arabic ligatures and correct RTL ordering.
    html = "<div dir='rtl'>" + txt + "</div>"
    css = (
        "@font-face{font-family:amiri;src:url('Amiri-Regular.ttf')}"
        "div{font-family:amiri;font-size:14pt;font-weight:normal;"
        "line-height:1.05;text-align:center;color:#174e76;margin:0}"
    )
    archive = pymupdf.Archive(str(AMIRI.parent))
    remaining, scale = page.insert_htmlbox(rel(page, bounds), html,
                                          css=css, archive=archive,
                                          scale_low=0.35, overlay=True)
    if remaining < 0:
        raise RuntimeError("Could not fit Arabic heading: " + txt)

def old_frame_png(page, scale=3):
    pix = page.get_pixmap(matrix=pymupdf.Matrix(scale, scale),
                          colorspace=pymupdf.csRGB, alpha=False)
    original = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
    rgba = original.convert("RGBA")
    mask = Image.new("L", original.size, 255)
    draw = ImageDraw.Draw(mask)
    def clear(b, padding=0):
        draw.rectangle((round(b[0]*pix.width) - padding,
                        round(b[1]*pix.height) - padding,
                        round(b[2]*pix.width) + padding,
                        round(b[3]*pix.height) + padding), fill=0)
    # The original center is fully transparent, not a rectangular overlay.
    clear(FRAME_HOLE, padding=1)
    # Remove low-resolution old captions and page number; retain their
    # ornate capsule boundaries where possible.
    clear(HEADER_LEFT)
    clear(HEADER_RIGHT)
    clear(FOOT_NUMBER)
    rgba.putalpha(mask)
    result = io.BytesIO()
    rgba.save(result, format="PNG")
    return result.getvalue()

def get_clean_page(page):
    # This is the existing V3 SVG color transformer which already proved it
    # finds #c0e2ca and replaces green; no Cairo or rasterization of glyphs.
    from compose_quran_clean_vector import page_svg_as_pdf
    return page_svg_as_pdf(page)

def source_body_crop(page):
    """Select source Quran body but exclude its old green header/page label.
    The exact Arabic glyph paths stay in vector PDF; no text extraction/reflow.
    First two pages preserve their original central composition.
    """
    # Illustrator pages have a similar layout; center source art within frame.
    if page.number in (0,1):
        return rel(page, (0.165, 0.175, 0.835, 0.840))
    return rel(page, (0.163, 0.159, 0.837, 0.877))

def build(pages, output):
    surah_pages, juz_pages = page_starts()
    assert len(SURAH) == 114
    combined = pymupdf.open()
    try:
        with pymupdf.open(OLD) as old, pymupdf.open(NEW) as source:
            if len(old) != 604 or len(source) != 604:
                raise ValueError("Old and vector Quran must each have 604 pages")
            for i in pages:
                original = old[i-1]
                vector = source[i-1]
                cleaned, greens = get_clean_page(vector)
                try:
                    if greens == 0:
                        raise RuntimeError(f"Page {i}: green background not removed")
                    target = combined.new_page(width=original.rect.width,
                                               height=original.rect.height)
                    # White background and ONLY new vector Arabic text.
                    target.show_pdf_page(rel(target, READING_AREA), cleaned, 0,
                                         clip=source_body_crop(vector),
                                         keep_proportion=False, overlay=True)
                    # The OLD frame is a transparent image with all its
                    # Quran text removed. Its blue ornament stays complete.
                    target.insert_image(target.rect, stream=old_frame_png(original),
                                        overlay=True, keep_proportion=False)
                    title = SURAH[current(surah_pages, i) - 1]
                    juz = current(juz_pages, i)
                    render_title(target, HEADER_LEFT, "سورة " + title)
                    render_title(target, HEADER_RIGHT,
                                 "الجزء " + arabic_numbers(juz))
                    render_title(target, FOOT_NUMBER, arabic_numbers(i))
                    print(f"Page {i}: vector Quran + full blue frame, green {greens}, "
                          f"surah={title}, juz={juz}", flush=True)
                finally:
                    cleaned.close()
        combined.save(output, garbage=3, deflate=True)
    finally:
        combined.close()
    print("PREVIEW SUCCESS:" if len(pages) < 604 else "FULL PDF SUCCESS:", output)
    print("Old quran.pdf untouched; no old blurry Arabic behind vector text.")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--all", action="store_true")
    args = parser.parse_args()
    if not OLD.exists() or not NEW.exists():
        raise SystemExit("Expected quran.pdf and quran_vector_candidate.pdf")
    build(range(1,605) if args.all else PAGES,
          FINAL if args.all else PREVIEW)

if __name__ == "__main__":
    main()
