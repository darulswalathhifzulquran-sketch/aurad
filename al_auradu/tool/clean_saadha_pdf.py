"""Remove exactly three stray gray marks from the blank PDF margin.

Arabic prayer text, embedded fonts, imagery and design remain original.
Re-running this script after a successful cleanup is a no-op.
"""
from pathlib import Path
import sys
import fitz

PDF = Path(__file__).resolve().parents[1] / 'assets/books/swalathus_saadha.pdf'
DOTS_AT_HALF_SCALE = [(62, 351, 6, 6), (65, 590, 6, 6), (60, 709, 7, 6)]
CENTERS = [(64, 353), (67, 592), (63, 711)]

if not PDF.is_file():
    sys.exit(f'Missing source PDF: {PDF}')

doc = fitz.open(PDF)
if len(doc) != 1:
    sys.exit('Stop: unexpected number of pages; original must be one page.')
page = doc[0]
if abs(page.rect.width - 1512) > 1 or abs(page.rect.height - 2138.4) > 1:
    sys.exit(f'Stop: unexpected page dimensions: {page.rect}')
original_text = page.get_text('text')
if not original_text or 'Sakkal Majalla' not in ' '.join(str(x) for x in page.get_fonts()):
    sys.exit('Stop: Arabic source font or text not found.')

preview = page.get_pixmap(matrix=fitz.Matrix(0.5, 0.5), alpha=False)
if all(min(preview.pixel(x, y)[:3]) > 230 for x, y in CENTERS):
    print('Stray dots already cleaned. No PDF changes required.')
    sys.exit(0)

for x, y, w, h in DOTS_AT_HALF_SCALE:
    rect = fitz.Rect(2*x - 3, 2*y - 3, 2*(x+w) + 3, 2*(y+h) + 3)
    page.draw_rect(rect, color=None, fill=(1, 1, 1), overlay=True)

result = PDF.with_suffix('.cleaned.pdf')
doc.save(result, garbage=3, deflate=True)
doc.close()
with fitz.open(result) as cleaned:
    if cleaned[0].get_text('text') != original_text:
        result.unlink(missing_ok=True)
        sys.exit('Stop: embedded Arabic source text changed.')
    verify = cleaned[0].get_pixmap(matrix=fitz.Matrix(0.5, 0.5), alpha=False)
    if not all(min(verify.pixel(x, y)[:3]) > 230 for x, y in CENTERS):
        result.unlink(missing_ok=True)
        sys.exit('Stop: unwanted dots were not removed.')

result.replace(PDF)
print('Only the three blank-margin dots were hidden; Arabic text unchanged.')
