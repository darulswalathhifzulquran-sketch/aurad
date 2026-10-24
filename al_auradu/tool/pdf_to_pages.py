#!/usr/bin/env python3
"""Turn a PDF into page pictures for the app.

Setup (once):   pip install pymupdf
Quran:          python tool/pdf_to_pages.py big-quran.pdf --out assets/quran
Majlisunnoor:   python tool/pdf_to_pages.py majlisunnoor.pdf --out assets/majlis --width 900 --expect 0

Options
  --first N    PDF page number where book page 1 is (skip cover pages). Default: asks you if the count is wrong
  --last N     last PDF page to use. Default: the end
  --width PX   picture width in pixels. Default 1000
  --quality Q  JPG quality 1-100. Default 78
  --expect N   warn when the page count is not N (604 for the Quran, 0 = no check)

Creates 001.jpg, 002.jpg ... and info.json (page count + shape) in --out.
"""
import argparse
import json
import os
import sys

try:
    import fitz  # PyMuPDF
except ImportError:
    print("PyMuPDF is missing. Run:  pip install pymupdf")
    sys.exit(1)

ap = argparse.ArgumentParser()
ap.add_argument("pdf")
ap.add_argument("--out", required=True)
ap.add_argument("--first", type=int, default=0)
ap.add_argument("--last", type=int, default=0)
ap.add_argument("--width", type=int, default=1000)
ap.add_argument("--quality", type=int, default=78)
ap.add_argument("--expect", type=int, default=604)
a = ap.parse_args()

doc = fitz.open(a.pdf)
total = doc.page_count
first = a.first
if first <= 0:
    if a.expect and total != a.expect and sys.stdin.isatty():
        print(f"This PDF has {total} pages, but the book should have {a.expect}.")
        print("Open the PDF and find the PDF page number of the FIRST book page")
        print("(for the Quran: the page with Surah Al-Fatiha).")
        try:
            first = int(input("PDF page number of book page 1: ").strip())
        except ValueError:
            first = 1
    else:
        first = 1
first = max(1, first)
last = a.last if a.last > 0 else total
if a.expect and not a.last and total - first + 1 > a.expect:
    last = first + a.expect - 1
last = min(last, total)
count = last - first + 1
print(f"PDF has {total} pages; using {first}..{last} = {count} pages")
if a.expect and count != a.expect:
    print(f"WARNING: expected {a.expect} pages but got {count}. "
          f"Use --first / --last so that book page 1 is the first picture.")

os.makedirs(a.out, exist_ok=True)
aspect = None
size = 0
for n, pno in enumerate(range(first - 1, last), start=1):
    page = doc[pno]
    zoom = a.width / page.rect.width
    pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=False)
    path = os.path.join(a.out, f"{n:03d}.jpg")
    try:
        pix.save(path, jpg_quality=a.quality)
    except TypeError:
        pix.save(path)
    size += os.path.getsize(path)
    if aspect is None:
        aspect = pix.width / pix.height
    if n % 25 == 0 or n == count:
        print(f"  {n}/{count}")

with open(os.path.join(a.out, "info.json"), "w", encoding="utf-8") as f:
    json.dump({"count": count, "aspect": round(aspect, 4)}, f)
print(f"Done. {count} pictures, {size / 1024 / 1024:.1f} MB in {a.out}")
