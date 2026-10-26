"""Turn existing blue calligraphic title image into scalable vector outlines.

This ONLY traces the existing image's silhouette — no letters are retyped,
OCR'd, or invented. It preserves every embedded Arabic body-text glyph,
diacritic and the page frame. When source PPTX/vector art becomes available
it can replace this auto-traced version for maximum typographic fidelity.
"""
from pathlib import Path
import re
import io
import sys

import fitz
import numpy as np
import cv2
from PIL import Image
import cairosvg

PDF = Path(__file__).resolve().parents[1] / "assets/books/swalathus_saadha.pdf"
if not PDF.exists():
    sys.exit("Missing original Swalathu Sa'adha PDF")

doc = fitz.open(PDF)
if len(doc) != 1:
    sys.exit("Unexpected page count; refusing to edit")
page = doc[0]
if abs(page.rect.width - 1512) > 1 or abs(page.rect.height - 2138.4) > 1:
    sys.exit("Unexpected PDF size; refusing to edit")

image = next((i for i in page.get_images(full=True) if i[7] == "Image7"), None)
if image is None:
    print("Raster title image already replaced; no work needed.")
    sys.exit(0)
xref, smask = image[0], image[1]
image_bboxes = page.get_image_rects(xref)
if len(image_bboxes) != 1:
    sys.exit("Unexpected repeated heading image")
title_rect = image_bboxes[0]
title_mask_image = doc.extract_image(smask)
if (title_mask_image["width"], title_mask_image["height"]) != (500, 500):
    sys.exit("Unexpected heading mask image size")

mask = np.array(Image.open(io.BytesIO(title_mask_image["image"])).convert("L"))
upscaled = cv2.resize(mask, None, fx=4, fy=4,
                      interpolation=cv2.INTER_CUBIC)
smooth = cv2.GaussianBlur(upscaled, (5, 5), 0.7)
_, binary = cv2.threshold(smooth, 90, 255, cv2.THRESH_BINARY)
contours, _ = cv2.findContours(binary, cv2.RETR_TREE,
                                cv2.CHAIN_APPROX_SIMPLE)
paths = []
for contour in contours:
    if cv2.contourArea(contour) < 1.5:
        continue
    approx = cv2.approxPolyDP(contour, epsilon=1.0, closed=True)
    points = approx.reshape(-1, 2)
    if len(points) < 3:
        continue
    paths.append("M " + " L ".join(
        f"{int(x)},{int(y)}" for x, y in points) + " Z")
if len(paths) < 30:
    sys.exit("Unexpected low contour count, refusing title change")

# The source title's visible blue, sampled from its own original image.
svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="500" '
       'height="500" viewBox="0 0 2000 2000">'
       '<path d="' + " ".join(paths) + '" fill="#315EA1" '
       'fill-rule="evenodd"/></svg>')
vector_title_pdf = fitz.open(stream=cairosvg.svg2pdf(
    bytestring=svg.encode("utf-8")), filetype="pdf")

before_text = page.get_text()
found = 0
for content_id in page.get_contents():
    content = doc.xref_stream(content_id)
    new_content, replacements = re.subn(
        rb'/Image7\s+Do\b', b'', content
    )
    if replacements:
        doc.update_stream(content_id, new_content)
        found += replacements
if found != 1:
    sys.exit(f"Unexpected PDF heading instance count: {found}")

# Overlay the traced original lettering at the precise original image matrix.
# No border, Arabic body text or page decorations are flattened into images.
page.show_pdf_page(title_rect, vector_title_pdf, 0, overlay=True)
output = PDF.with_suffix(".vectorized.pdf")
doc.save(output, garbage=3, deflate=True)
doc.close()
with fitz.open(output) as rendered:
    if rendered[0].get_text() != before_text:
        output.unlink(missing_ok=True)
        sys.exit("Arabic body text changed; cancelled")
    if len(rendered[0].get_images()) >= 43:
        output.unlink(missing_ok=True)
        sys.exit("Raster title was not removed; cancelled")

output.replace(PDF)
print(f"Vector traced original title with {len(paths)} shapes; "
      "embedded Arabic text and page contents preserved.")
