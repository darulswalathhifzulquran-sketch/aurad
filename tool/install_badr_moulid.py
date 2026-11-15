"""Install the user's original BADR MOULID FINAL 1.pdf.

Preserve all 25 original designed pages, Arabic and orange/gold borders.
Only the small ORIGINAL printed footer caption in the bottom centre is
masked so the same shared Flutter academy footer as other Mawlids is
rendered ONCE by reader.dart.  Does not crop or reflow book content.

Place BADR MOULID FINAL 1.pdf in Windows Downloads first.
"""
from pathlib import Path
from shutil import copy2
from tempfile import NamedTemporaryFile
import pymupdf

ROOT = Path(__file__).resolve().parents[1]
DOWNLOADS = Path.home() / "Downloads"
TARGET = ROOT / "assets/books/badr_moulid.pdf"
SOURCE_NAMES = (
    "BADR MOULID FINAL 1.pdf",
    "BADR MOULID FINAL 1 (1).pdf",
    "BADR MOULID FINAL 1",
)

def main():
    source=next((DOWNLOADS/n for n in SOURCE_NAMES if (DOWNLOADS/n).is_file()),None)
    if source is None:
        raise SystemExit(
            "SOURCE MISSING: Download the supplied BADR MOULID FINAL 1.pdf "
            "into Windows Downloads. Existing app books are unchanged.")
    src=pymupdf.open(str(source))
    count=len(src)
    if count!=25:
        src.close()
        raise SystemExit(
            f"Expected the original 25-page Badr Moulid, got {count} pages. "
            "No changes were made.")
    out=pymupdf.open()
    for i in range(count):
        rect=src[i].rect
        pg=out.new_page(width=rect.width,height=rect.height)
        pg.show_pdf_page(pg.rect,src,i,keep_proportion=False)
        # SOURCE PDF: original orange corners and page number remain intact.
        # Cover ONLY the old bottom-centre small مجلس صلاة السعادة
        # caption. The app's existing shared academy footer takes its place.
        # Bottom frame ornaments are outside this central zone.
        w,h=rect.width,rect.height
        pg.draw_rect(pymupdf.Rect(w*.34,h*.958,w*.66,h*.998),
                     color=None,fill=(1,1,1),overlay=True)
    TARGET.parent.mkdir(parents=True,exist_ok=True)
    backup=TARGET.with_name("badr_moulid.before_update.pdf")
    if TARGET.exists() and not backup.exists():
        copy2(TARGET,backup)
    temp=TARGET.with_name("badr_moulid.tmp.pdf")
    out.save(str(temp),garbage=4,deflate=True)
    out.close();src.close()
    verify=pymupdf.open(str(temp))
    assert len(verify)==25
    verify.close()
    temp.replace(TARGET)
    print("SUCCESS: Badr Mawlid installed, 25 original Arabic pages")
    print("APP ASSET:",TARGET)
    print("Flutter will render the shared Mawlid academy footer once.")

if __name__=="__main__":
    main()
