"""Build fast-loading, pixel-faithful Web book pages from existing original PDFs.

Does NOT modify, replace, recolor or retype any original PDF. Each of
the nine PDF-backed books gets independently loadable page images.
Run: python tool/install_web_book_pages.py
"""
import json
from pathlib import Path
import sys

try:
    import pymupdf
    from PIL import Image
except ImportError:
    sys.exit("Run: python -m pip install pymupdf pillow")

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "web_books"
MANIFEST = ROOT / "assets" / "data" / "web_books_manifest.json"
CATALOG = ROOT / "assets" / "data" / "library.json"
HEIGHT = 1550

def main():
    books = json.loads(CATALOG.read_text(encoding="utf-8"))["items"]
    manifest = {}
    missing = []
    for book in books:
        asset = book.get("pdfAsset", "")
        if not asset:
            continue
        path = ROOT / asset
        if not path.is_file():
            missing.append(str(path.relative_to(ROOT)))
            continue
        item_id = book["id"]
        target = OUTPUT / item_id
        target.mkdir(parents=True, exist_ok=True)
        with pymupdf.open(path) as pdf:
            count = len(pdf)
            if count == 0:
                missing.append(asset + " (empty PDF)")
                continue
            for i, page in enumerate(pdf):
                dst = target / f"page_{i+1:04d}.jpg"
                if dst.exists() and dst.stat().st_size > 6000 and dst.stat().st_mtime >= path.stat().st_mtime:
                    continue
                factor = HEIGHT / page.rect.height
                pix = page.get_pixmap(matrix=pymupdf.Matrix(factor, factor),
                                      colorspace=pymupdf.csRGB, alpha=False)
                image = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
                tmp = dst.with_suffix(".partial.jpg")
                image.save(tmp, format="JPEG", quality=88, subsampling=0,
                           progressive=True)
                tmp.replace(dst)
            manifest[item_id] = count
            print(f"READY: {item_id} ({count} A4 pages)", flush=True)
    if missing:
        sys.exit("STOPPED: These originals are missing; no web manifest changed:\n" +
                 "\n".join(" - " + p for p in missing))
    if not manifest:
        sys.exit("No PDF-backed books found.")
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2),
                        encoding="utf-8")
    print("SUCCESS: All PDF-backed book pages ready for instant lazy Web loading.")
    print("Original source PDFs are unchanged.")

if __name__ == "__main__":
    main()
