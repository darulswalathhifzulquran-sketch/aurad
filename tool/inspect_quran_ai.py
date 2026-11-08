"""Inspect 604 Illustrator Quran pages without changing the working app PDF.

Usage: python tool/inspect_quran_ai.py "C:\\Users\\HP\\Downloads\\quran-new.zip"
Writes page previews for manual inspection, plus PDF rendering diagnostics.
"""
import sys
import re
import zipfile
from pathlib import Path
import pymupdf

SAMPLES = (1, 208, 252, 604)
OUT = Path(__file__).resolve().parents[1] / "quran_ai_preview"

def natural(name):
    return [int(part) if part.isdigit() else part.casefold()
            for part in re.split(r"(\d+)", name)]

def analyze(pdf, index):
    page = pdf[0]
    print(f"PAGE {index}: dimensions={page.rect}, text_chars={len(page.get_text())}, "
          f"images={len(page.get_images(full=True))}, drawings={len(page.get_drawings())}, "
          f"contents={len(page.get_contents())}, xobjects={len(page.get_xobjects())}", flush=True)
    p = page.get_pixmap(matrix=pymupdf.Matrix(2, 2), colorspace=pymupdf.csRGB, alpha=False)
    pixels = p.samples
    # Count pixels visibly different from white. This detects blank PDF wrappers.
    step = 4 * 3
    colored = sum(
        1 for k in range(0, len(pixels) - 2, step)
        if min(pixels[k], pixels[k + 1], pixels[k + 2]) < 210
    )
    sample_count = max(1, len(pixels) // step)
    pct = 100 * colored / sample_count
    out = OUT / f"page_{index:03}.png"
    p.save(str(out))
    print(f"  Preview: {out}; nonwhite_sample={pct:.2f}%", flush=True)
    if pct < 0.12:
        print("  WARNING: This page appears nearly blank. Do NOT install.", flush=True)
    return pct

def main():
    if len(sys.argv) < 2:
        sys.exit("Provide path to Quran ZIP file.")
    source = Path(sys.argv[1])
    if not source.is_file():
        sys.exit(f"File missing: {source}")
    OUT.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(source) as archive:
        pages = sorted(
            (x for x in archive.infolist()
             if not x.is_dir() and x.filename.lower().endswith(".ai")),
            key=lambda x: natural(x.filename)
        )
        if len(pages) != 604:
            sys.exit(f"Expected 604 AI pages; found {len(pages)}.")
        scores = []
        for i in SAMPLES:
            item = pages[i - 1]
            data = archive.read(item)
            print(f"AI {i}: {item.filename}; starts={data[:40]!r}", flush=True)
            with pymupdf.open(stream=data, filetype="pdf") as doc:
                scores.append(analyze(doc, i))
        if any(x < 0.12 for x in scores):
            print("RESULT: At least one page may be blank. Original Quran PDF untouched.")
        else:
            print("RESULT: Pages render with visible ink. Inspect the 4 PNG previews "
                  "for matching verse content and layout BEFORE changing quran.pdf.")
        print("Preview folder:", OUT)

if __name__ == "__main__":
    main()
