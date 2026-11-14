"""Install the two user's ORIGINAL Moulid PDFs in Riyadul Adkar.

No OCR, per-character extraction, artificial line spacing, or rasterizing
of the Arabic. Original decoration, tables, and diacritics remain intact.
The Flutter viewer applies a dark-mode color filter; both PDF assets stay
vector-native / original-resolution.
"""
from pathlib import Path
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
        "sharaful anam orgn [Autosaved]  111111 bn(2).pdf",
        "sharaful anam orgn [Autosaved]  111111 bn.pdf",
    ], "sharafal_anam_moulid", 30, 30),
]

def find_source(names):
    for name in names:
        path = DL / name
        if path.is_file():
            return path
    raise FileNotFoundError(
        "Save the uploaded original PDF into Downloads. Searched: "
        + ", ".join(names))

def remove_sharaf_number(page):
    """Cover only the tiny printed page-number box at top centre.

    A white fill preserves the original source page/frame beneath it except
    in this narrow, initially white area. Does not shift any Arabic lines.
    """
    r = page.rect
    white = pymupdf.Rect(
        r.x0+r.width*.465, r.y0+r.height*.023,
        r.x0+r.width*.535, r.y0+r.height*.059)
    page.draw_rect(white,fill=(1,1,1),color=None,overlay=True)

def remove_last_sharaf_artwork(page, original):
    """Remove only the *separate* final-page decorative image.

    Never guess a broad crop: keep all Arabic printed content. Only erase
    a source image whose box is in the lower half and not full-page scan.
    """
    r = original.rect
    removed = 0
    for item in original.get_images(full=True):
        xref=item[0]
        for box in original.get_image_rects(xref):
            box=pymupdf.Rect(box)
            if (box.y0>r.y0+r.height*.48
                    and box.width<r.width*.86
                    and box.height<r.height*.49
                    and box.height>r.height*.045):
                page.draw_rect(box,fill=(1,1,1),color=None,overlay=True)
                removed+=1
    return removed

def build(book):
    name,names,base,count,expected=book
    source_path=find_source(names)
    original=pymupdf.open(str(source_path))
    if len(original)!=expected:
        raise ValueError(f"{name}: expected {expected} source pages; got {len(original)}")
    output=pymupdf.open()
    # Preserve exact original page boxes. No arbitrary 21-inch upscaling:
    # converting a source page to huge dimensions adds no PDF clarity.
    for i in range(count):
        p=original[i]
        target=output.new_page(width=p.rect.width,height=p.rect.height)
        target.show_pdf_page(target.rect,original,i,keep_proportion=False)
        if base=="sharafal_anam_moulid":
            remove_sharaf_number(target)
            if i==count-1:
                deleted=remove_last_sharaf_artwork(target,p)
                print("Sharaf final-page image regions covered:",deleted)
    OUT.mkdir(parents=True,exist_ok=True)
    for mode in ("light","dark"):
        path=OUT/f"{base}_{mode}.pdf"
        pending=path.with_suffix(".pending.pdf")
        if pending.exists():pending.unlink()
        output.save(str(pending),garbage=4,deflate=True)
        test=pymupdf.open(str(pending))
        valid=len(test)==count
        test.close()
        if not valid:raise RuntimeError("Output page count check failed")
        if path.is_file():
            backup=OUT/f"{base}_{mode}.before_original.pdf"
            if not backup.is_file():backup.write_bytes(path.read_bytes())
        pending.replace(path)
        print(f"APP ASSET READY: {path.name} ({count} original pages)")
    output.close()
    original.close()

def main():
    for book in BOOKS:build(book)
    print("DONE. Flutter dark theme applies display color conversion, "
          "not a destructive rewrite of original Arabic pages.")

if __name__=="__main__":
    main()
