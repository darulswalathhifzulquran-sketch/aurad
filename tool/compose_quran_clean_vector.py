"""Make a CLEAN Quran preview: original BLUE ornaments, crisp VECTOR Arabic.

Never composites old blurred Arabic behind new Arabic.
Never replaces quran.pdf. Preview 4 pages unless --all is requested.

Requirements: python -m pip install pymupdf pillow cairosvg
Usage:
    python tool/compose_quran_clean_vector.py
    python tool/compose_quran_clean_vector.py --all
"""
import argparse
import io
import re
from pathlib import Path

import pymupdf
from PIL import Image
import cairosvg

ROOT = Path(__file__).resolve().parents[1]
OLD = ROOT / "quran.pdf"
VECTOR = ROOT / "quran_vector_candidate.pdf"
PREVIEW = ROOT / "quran_clean_vector_preview.pdf"
FULL = ROOT / "quran_clean_vector_604.pdf"
N = 604

# The approved border stays in its original position. The artwork
# is placed within its inner frame, NOT over the original Quran text.
TARGET = (.160, .152, .840, .872)
BLUE = (0.025, 0.43, 0.74)

SURAH_NAMES = (
    "الفاتحة البقرة آل عمران النساء المائدة الأنعام الأعراف الأنفال التوبة يونس هود يوسف الرعد إبراهيم "
    "الحجر النحل الإسراء الكهف مريم طه الأنبياء الحج المؤمنون النور الفرقان الشعراء النمل القصص العنكبوت الروم "
    "لقمان السجدة الأحزاب سبأ فاطر يس الصافات ص الزمر غافر فصلت الشورى الزخرف الدخان الجاثية الأحقاف محمد "
    "الفتح الحجرات ق الذاريات الطور النجم القمر الرحمن الواقعة الحديد المجادلة الحشر الممتحنة الصف الجمعة "
    "المنافقون التغابن الطلاق التحريم الملك القلم الحاقة المعارج نوح الجن المزمل المدثر القيامة الإنسان المرسلات "
    "النبأ النازعات عبس التكوير الانفطار المطففين الانشقاق البروج الطارق الأعلى الغاشية الفجر البلد الشمس الليل "
    "الضحى الشرح التين العلق القدر البينة الزلزلة العاديات القارعة التكاثر العصر الهمزة الفيل قريش الماعون "
    "الكوثر الكافرون النصر المسد الإخلاص الفلق الناس"
).replace("آل عمران", "آل_عمران").split()

def find_starts(const_name, expected):
    source = (ROOT / "lib" / "mushaf.dart").read_text(encoding="utf-8")
    match = re.search(r"const List<int> " + const_name + r"\s*=\s*\[([^\]]+)\]", source)
    if not match:
        raise ValueError("Cannot find Quran page map: " + const_name)
    starts = [int(x) for x in re.findall(r"\d+", match.group(1))]
    if len(starts) != expected:
        raise ValueError("Invalid page-map length for " + const_name)
    return starts

def which_page(starts, number):
    return max((i + 1 for i, p in enumerate(starts) if p <= number), default=1)

def rrect(page, box):
    a, b, c, d = box
    return pymupdf.Rect(
        page.rect.x0 + page.rect.width * a,
        page.rect.y0 + page.rect.height * b,
        page.rect.x0 + page.rect.width * c,
        page.rect.y0 + page.rect.height * d,
    )

def looks_green(r, g, b):
    return g > r * 1.028 and g > b * 1.009 and (
        0.40 < r < 0.99 and 0.47 < g <= 1 and 0.36 < b < 0.99
    )

# PyMuPDF exports Illustrator's vector glyph outlines as SVG path data,
# with palette as RGB/hex values. Replacing green fills HERE preserves
# the glyph paths as vectors (does not create a pixel image).
HEX = re.compile(r"#[0-9A-Fa-f]{6}\b")
RGB = re.compile(
    r"rgb\(\s*([\d.]+%?)\s*,\s*([\d.]+%?)\s*,\s*([\d.]+%?)\s*\)",
    re.IGNORECASE,
)

def rgb_component(t):
    if t.endswith("%"):
        return float(t[:-1]) / 100
    n = float(t)
    return n / 255 if n > 1 else n

def whiten_green(svg):
    replaced = [0]
    def hx(m):
        token = m.group()
        r, g, b = [int(token[j:j+2], 16)/255 for j in (1, 3, 5)]
        if looks_green(r, g, b):
            replaced[0] += 1
            return "#ffffff"
        return token

    def rg(m):
        r, g, b = (rgb_component(m.group(i)) for i in (1, 2, 3))
        if looks_green(r, g, b):
            replaced[0] += 1
            return "rgb(255,255,255)"
        return m.group()

    return RGB.sub(rg, HEX.sub(hx, svg)), replaced[0]

def green_panel(page):
    candidates = []
    for item in page.get_drawings():
        fill = item.get("fill")
        if fill is None or len(fill) < 3:
            continue
        if looks_green(*fill[:3]):
            rect = item["rect"]
            if rect.width >= page.rect.width * .28 and rect.height >= page.rect.height * .3:
                candidates.append((rect.width * rect.height, rect))
    if candidates:
        box = max(candidates, key=lambda pair: pair[0])[1]
        # Keep Quran ornaments and diacritics at the edges of the green panel.
        box = pymupdf.Rect(box.x0 - page.rect.width*.018,
                           box.y0 - page.rect.height*.024,
                           box.x1 + page.rect.width*.018,
                           box.y1 + page.rect.height*.024)
        return box & page.rect
    return rrect(page, (.20, .10, .80, .91))

def blue_border_png(page, resolution=2):
    """Extract only old blue/turquoise ornamental pixels, never old black text."""
    pix = page.get_pixmap(matrix=pymupdf.Matrix(resolution, resolution),
                          colorspace=pymupdf.csRGB, alpha=False)
    rgb = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
    rgba = Image.new("RGBA", rgb.size, (0, 0, 0, 0))
    src = rgb.load()
    dst = rgba.load()
    w, h = rgb.size
    for y in range(h):
        yn = y / h
        for x in range(w):
            xn = x / w
            # Restrict extraction to the perimeter: NO old Quran verses.
            if .155 < xn < .845 and .145 < yn < .88:
                continue
            r, g, b = src[x, y]
            blue = (b > 80 and b > r * 1.18 and b >= g * .82)
            turquoise = (g > 90 and b > 85 and g > r * 1.20 and b > r * 1.15)
            if blue or turquoise:
                dst[x, y] = (r, g, b, 255)
    stream = io.BytesIO()
    rgba.save(stream, format="PNG")
    return stream.getvalue()

def page_svg_as_pdf(page):
    svg = page.get_svg_image(text_as_path=True)
    svg, converted = whiten_green(svg)
    if converted == 0:
        raise ValueError(
            "No green vector fills were detected. STOPPING to prevent "
            "another green-box preview; inspect the AI source palette."
        )
    content = cairosvg.svg2pdf(bytestring=svg.encode("utf-8"))
    return pymupdf.open(stream=content, filetype="pdf"), converted

def title(page, surah, juz):
    # Arabic text rendered using HarfBuzz-capable PDF HTML layout.
    fontpath = ROOT / "assets" / "fonts" / "Amiri-Regular.ttf"
    archive = pymupdf.Archive(str(fontpath.parent)) if fontpath.exists() else None
    css = (
        "@font-face {font-family:'QuranTitle';src:url('Amiri-Regular.ttf');}"
        "body{font-family:'QuranTitle',serif;margin:0;padding:0;"
        "font-size:13pt;line-height:1.3;color:#174e76;text-align:center;}"
    )
    left = rrect(page, (.17, .091, .41, .145))
    right = rrect(page, (.59, .091, .83, .145))
    # Skip when 604-index page map is not Madinah-equivalent, but keep
    # genuine page-map metadata. Title text never overwrites body art.
    for bounds, value in ((left, f"الجزء {juz}"), (right, f"سورة {surah}")):
        html = f"<div dir='rtl'>{value}</div>"
        page.insert_htmlbox(bounds, html, css=css, archive=archive,
                            scale_low=0.5, overlay=True)

def generate(indices, dest):
    surah_starts = find_starts("kSurahPage", 114)
    juz_starts = find_starts("kJuzPage", 30)
    if len(SURAH_NAMES) != 114:
        raise ValueError(f"Expected 114 surah names; found {len(SURAH_NAMES)}")
    output = pymupdf.open()
    with pymupdf.open(OLD) as old_pdf, pymupdf.open(VECTOR) as vector_pdf:
        if len(old_pdf) != N or len(vector_pdf) != N:
            raise ValueError("Both Quran PDFs must have precisely 604 pages.")
        try:
            for num in indices:
                previous = old_pdf[num - 1]
                original = vector_pdf[num - 1]
                cleaned, changes = page_svg_as_pdf(original)
                try:
                    current = output.new_page(width=previous.rect.width,
                                              height=previous.rect.height)
                    target = rrect(current, TARGET)
                    clip = green_panel(original)
                    # The original old page is NEVER added as the background.
                    # So double text is impossible.
                    current.draw_rect(target, fill=(1, 1, 1),
                                      color=None, overlay=True)
                    current.show_pdf_page(target, cleaned, 0,
                                          clip=clip, keep_proportion=False)
                    # Draw authentic blue decorations extracted from original;
                    # its black glyphs were intentionally discarded.
                    current.insert_image(current.rect,
                        stream=blue_border_png(previous), overlay=True)
                    # Grey inner line from the original design, now true vector.
                    current.draw_rect(
                        rrect(current, (.153, .147, .847, .883)),
                        color=(.46, .53, .58), width=.42, overlay=True)
                    current.draw_rect(
                        rrect(current, (.158, .151, .842, .877)),
                        color=(.70, .75, .79), width=.26, overlay=True)
                    title(current,
                          SURAH_NAMES[which_page(surah_starts, num)-1].replace("_", " "),
                          which_page(juz_starts, num))
                    print(f"Page {num}: removed {changes} green palette values; "
                          f"vector crop={clip}; border=blue-only", flush=True)
                finally:
                    cleaned.close()
            output.save(dest, garbage=3, deflate=True)
        finally:
            output.close()
    print("SUCCESS:", dest)
    print("No old Quran text layer, no green background, original PDF untouched.")
    if len(indices) < 604:
        print("PREVIEW ONLY. Check pages 1, 3, 208, 252, 604 before full build.")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--all", action="store_true")
    args = parser.parse_args()
    if not OLD.exists() or not VECTOR.exists():
        raise SystemExit("Missing quran.pdf or quran_vector_candidate.pdf")
    pages = range(1, 605) if args.all else (1, 3, 208, 252, 604)
    generate(pages, FULL if args.all else PREVIEW)

if __name__ == "__main__":
    main()
