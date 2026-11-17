"""Prepare fast, lazy-loaded Quran pages for the Netlify Flutter Web reader.

Source is the ORIGINAL 604-page quran.pdf. No text retyping or reflow.
Each printed page is converted directly to an optimized image. The original
PDF remains untouched; Flutter only downloads whichever pages are visible.
Run: python tool/install_quran_web_pages.py
"""
from pathlib import Path
import sys

try:
    import pymupdf
    from PIL import Image
except ImportError:
    sys.exit("Run: python -m pip install pymupdf pillow")

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "quran.pdf"
OUTPUT = ROOT / "assets" / "quran_pages"
COUNT = 604
HEIGHT = 1750

def main():
    if not SOURCE.exists():
        sys.exit("Missing source quran.pdf; no pages generated.")
    with pymupdf.open(SOURCE) as doc:
        if len(doc) != COUNT:
            sys.exit(f"EXPECTED EXACTLY 604 Quran PDF pages; found {len(doc)}. No change.")
        OUTPUT.mkdir(parents=True, exist_ok=True)
        completed = 0
        for n in range(COUNT):
            dst = OUTPUT / f"page_{n+1:04d}.jpg"
            if dst.is_file() and dst.stat().st_size > 7000:
                continue
            page = doc[n]
            ratio = HEIGHT / page.rect.height
            pix = page.get_pixmap(matrix=pymupdf.Matrix(ratio, ratio),
                                 colorspace=pymupdf.csRGB, alpha=False)
            image = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
            tmp = dst.with_suffix(".installing.jpg")
            image.save(tmp, format="JPEG", quality=87, subsampling=0,
                       progressive=True)
            tmp.replace(dst)
            completed += 1
            if (n + 1) % 50 == 0:
                print(f"Quran pages checked: {n + 1}/{COUNT}", flush=True)
    absent = [n for n in range(1, COUNT+1)
              if not (OUTPUT / f"page_{n:04d}.jpg").exists()]
    if absent:
        sys.exit(f"Page conversion incomplete: {absent[:10]}")
    print("SUCCESS: 604 Quran pages ready for fast on-demand loading.")
    print("The original quran.pdf is unchanged.")

if __name__ == "__main__":
    main()
