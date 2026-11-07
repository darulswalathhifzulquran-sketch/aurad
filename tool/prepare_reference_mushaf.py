"""
Prepare the user's ORIGINAL 604-page Mushaf for Flutter, without retyping verses.

Usage (Windows PowerShell, project root):
    py -m pip install pymupdf pillow numpy
    py tool/prepare_reference_mushaf.py "$env:USERPROFILE\Downloads\quran(1).pdf"

Keeps source page artwork, Surah/Juz tabs, side ornaments, page numbers, and
circular ayah markers exactly as supplied. Light uses a byte-for-byte copy.
Dark keeps cyan-blue ornaments while reversing the neutral page tones.
"""
import argparse
import io
import os
from pathlib import Path
import shutil
import sys

try:
    import fitz
    import numpy as np
    from PIL import Image
except ImportError:
    sys.exit("Install dependencies first: py -m pip install pymupdf pillow numpy")


def locate_source():
    downloads = Path.home() / "Downloads"
    for p in (downloads / "quran(1).pdf", downloads / "quran (1).pdf",
              downloads / "quran-original.pdf"):
        if p.is_file():
            return p
    sys.exit("Original PDF not found. Download quran(1).pdf to your Downloads folder.")


def darken(image_bytes):
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    arr = np.asarray(img, dtype=np.uint8)
    blue_delta = arr[:, :, 2].astype(np.int16) - arr[:, :, 0].astype(np.int16)
    spread = arr.max(axis=2).astype(np.int16) - arr.min(axis=2).astype(np.int16)
    preserve_blue = (blue_delta > 35) & (arr[:, :, 0] < 185) & (spread > 35)
    # Reverse monochrome tones, boosting text contrast but preserving antialiasing.
    reversed_tones = np.clip((255 - arr).astype(np.float32) * 1.22 - 25,
                             0, 255).astype(np.uint8)
    combined = np.where(preserve_blue[:, :, None], arr, reversed_tones)
    output = io.BytesIO()
    Image.fromarray(combined, "RGB").save(
        output, format="JPEG", quality=85, optimize=True, subsampling=0)
    return output.getvalue()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", nargs="?", type=Path, default=None)
    args = parser.parse_args()
    source = (args.source or locate_source()).expanduser().resolve()
    if not source.is_file():
        sys.exit(f"PDF not found: {source}")
    root = Path(__file__).resolve().parent.parent
    light = root / "quran.pdf"
    dark = root / "assets" / "books" / "quran_dark.pdf"
    if source == light.resolve() or source == dark.resolve():
        sys.exit("Use the ORIGINAL quran(1).pdf in Downloads, not an app output PDF.")
    src = fitz.open(source)
    if len(src) != 604:
        sys.exit(f"Expected 604 pages, got {len(src)}. No files were replaced.")
    if any(len(p.get_images(full=True)) < 1 for p in src):
        sys.exit("One or more source pages lack their scanned artwork.")
    print("Verified 604 original Mushaf pages.")
    dark.parent.mkdir(parents=True, exist_ok=True)
    dark_tmp = dark.with_suffix(".building.pdf")
    if dark_tmp.exists():
        dark_tmp.unlink()
    result = fitz.open()
    try:
        for i, page in enumerate(src):
            raw = src.extract_image(page.get_images(full=True)[0][0])["image"]
            target = result.new_page(width=page.rect.width, height=page.rect.height)
            # Render the FULL original page, including marginal Hizb markers.
            # Source currently embeds one full-page image per page.
            target.insert_image(target.rect, stream=darken(raw), keep_proportion=False)
            if (i + 1) % 50 == 0 or i == 603:
                print(f"Dark Mushaf: {i + 1}/604 pages")
        result.save(dark_tmp, garbage=4, deflate=True)
    finally:
        result.close()
        src.close()
    dark_tmp.replace(dark)
    shutil.copyfile(source, light)
    print(f"Light Mushaf: {light}")
    print(f"Dark Mushaf: {dark}")
    print("Ready. Run: flutter run -d chrome")


if __name__ == "__main__":
    main()
