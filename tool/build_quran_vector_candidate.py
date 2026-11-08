"""Build a separate, zoomable 604-page vector PDF from Illustrator Quran pages.
Keeps the current quran.pdf and dark mode untouched.

Run: python tool/build_quran_vector_candidate.py "C:\\Users\\HP\\Downloads\\quran-new.zip"
"""
import re
import sys
import zipfile
from pathlib import Path
import pymupdf

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "quran_vector_candidate.pdf"

def sort_parts(value):
    return [int(x) if x.isdigit() else x.casefold()
            for x in re.split(r"(\d+)", value)]

def main():
    if len(sys.argv) != 2:
        sys.exit("Usage: python tool/build_quran_vector_candidate.py path/to/quran-new.zip")
    source = Path(sys.argv[1])
    if not source.is_file() or not zipfile.is_zipfile(source):
        sys.exit("Source must be an existing ZIP archive")
    with zipfile.ZipFile(source) as archive:
        items = sorted(
            [x for x in archive.infolist()
             if not x.is_dir() and x.filename.lower().endswith(".ai")],
            key=lambda x: sort_parts(x.filename)
        )
        if len(items) != 604:
            sys.exit(f"Expected 604 AI pages. Found: {len(items)}")
        assembled = pymupdf.open()
        try:
            for i, item in enumerate(items, 1):
                data = archive.read(item)
                with pymupdf.open(stream=data, filetype="pdf") as page_pdf:
                    if len(page_pdf) != 1:
                        raise ValueError(f"AI file {i} has {len(page_pdf)} pages")
                    if len(page_pdf[0].get_drawings()) < 2 and not page_pdf[0].get_xobjects():
                        raise ValueError(f"AI page {i} has no vector artwork")
                    assembled.insert_pdf(page_pdf)
                if i % 50 == 0:
                    print(f"Assembled {i}/604 pages", flush=True)
            temp = ROOT / "quran_vector_candidate.tmp.pdf"
            try:
                assembled.save(temp, garbage=3, deflate=True)
            finally:
                assembled.close()
            with pymupdf.open(temp) as check:
                if len(check) != 604:
                    raise ValueError(f"Output has {len(check)} pages")
                for index in (0, 207, 251, 603):
                    page = check[index]
                    if not page.get_drawings() and not page.get_xobjects():
                        raise ValueError(f"Page {index+1} is missing vector artwork")
            temp.replace(OUTPUT)
        finally:
            if not assembled.is_closed:
                assembled.close()
    print("SUCCESS: Separate 604-page vector candidate saved at", OUTPUT)
    print("Current working quran.pdf was NOT changed.")
    print("Compare the design and ayah positions with original PDF before replacing.")
if __name__ == "__main__":
    main()
