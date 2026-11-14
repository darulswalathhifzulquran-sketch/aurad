"""Crop the exact user-supplied academy footer, preserving original letters.

Save the image as Downloads/academy_footer.png and run:
    python tool/install_academy_footer.py

Works with a pre-cropped plaque, a black-background reference image,
or a white book-page screenshot with the plaque at the bottom.
No lettering is re-typed or regenerated. The output is also inspectable at
assets/images/academy_footer_exact.png.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps
import sys

ROOT = Path(__file__).resolve().parents[1]
DOWNLOADS = Path.home() / "Downloads"
DEST = ROOT / "assets" / "images" / "academy_footer_exact.png"


def _bbox_for_plaque(image):
    """Return a likely badge crop without mistaking a white page for a badge."""
    rgb = image.convert("RGB")
    w, h = rgb.size
    if w < 30 or h < 15:
        raise ValueError("Image is too small. Save the original academy footer image.")

    # Already-cropped horizontal white badge: keep the entire lettering intact.
    if w / h >= 2.3:
        return (0, 0, w, h), "horizontal badge"

    # A badge on a black background: take the white capsule, NOT dark outside.
    sample = [rgb.getpixel((x, y)) for x, y in
              [(0, 0), (w-1, 0), (0, h-1), (w-1, h-1)]]
    dark_corners = sum(max(c) < 65 for c in sample)
    if dark_corners >= 3:
        px = rgb.load()
        step = max(1, min(w, h)//800)
        spots = [(x, y) for y in range(0, h, step)
                 for x in range(0, w, step)
                 if min(px[x, y]) > 205]
        if spots:
            l = min(x for x,y in spots); t = min(y for x,y in spots)
            r = max(x for x,y in spots)+step; bot = max(y for x,y in spots)+step
            if (r-l) / max(1, bot-t) > 1.8:
                padx = max(2, int((r-l)*.012))
                pady = max(2, int((bot-t)*.035))
                return (max(0,l-padx), max(0,t-pady),
                        min(w,r+padx), min(h,bot+pady)), "white badge on black"

    # Full-page white screenshot: locate the long horizontal black outline
    # near the bottom of the page rather than measuring ALL white pixels.
    small = rgb.copy()
    small.thumbnail((900, 1200))
    sw, sh = small.size
    px = small.load()
    candidates = []
    for y in range(int(sh * .55), sh):
        # Only inspect the central area where the academy badge sits.
        left = int(sw*.16); right = int(sw*.84)
        dark = sum(1 for x in range(left, right)
                   if max(px[x, y]) < 110)
        if dark >= (right-left)*.35:
            candidates.append(y)
    if candidates:
        # Choose a run of strongly horizontal dark line pixels near the
        # bottom, then include the whole badge around that band.
        y0 = candidates[-1]
        strip = max(16, int(sw*.09))
        top = max(0, y0-strip)
        bottom = min(sh, y0+strip)
        # Find dark pixels in the selected strip and use their full x-span.
        points = [(x,y) for y in range(top,bottom)
                  for x in range(int(sw*.12),int(sw*.88))
                  if max(px[x,y]) < 125]
        if points:
            x1=min(x for x,y in points); x2=max(x for x,y in points)
            cy=(top+bottom)//2
            target_h=max(16,int((x2-x1)/5.4))
            ty=max(0,cy-target_h//2)
            by=min(sh,ty+target_h)
            if by-ty >= 10:
                scale_x=w/sw;scale_y=h/sh
                pad=max(2,int(sw*.008))
                box=(max(0,int((x1-pad)*scale_x)),
                     max(0,int(ty*scale_y)),
                     min(w,int((x2+pad)*scale_x)),
                     min(h,int(by*scale_y)))
                return box, "footer cropped from book screenshot"

    # Safe last resort: do not silently substitute an unrelated image.
    raise ValueError(
        "Could not identify the academy badge in this picture. "
        "Please crop only the horizontal academy box and save as "
        "Downloads/academy_footer.png."
    )


def install():
    choices = [DOWNLOADS/"academy_footer.png",
               DOWNLOADS/"academy_footer_exact.png"]
    source = next((p for p in choices if p.is_file()), None)
    if source is None:
        raise SystemExit("Missing Downloads/academy_footer.png")

    img = Image.open(source).convert("RGBA")
    try:
        box, method = _bbox_for_plaque(img)
    except ValueError as exc:
        raise SystemExit(str(exc))
    cropped = img.crop(box)
    w,h = cropped.size
    print(f"Detected: {method}; source={img.width}x{img.height}, crop={w}x{h}")
    # Preserve the original image pixels/Arabic lettering. The black
    # exterior (if present) is excluded by the crop; do not mask the ink.
    DEST.parent.mkdir(parents=True, exist_ok=True)
    cropped.save(DEST, optimize=True)
    print("SUCCESS: Footer image ->", DEST)
    print("Please inspect the saved image before running the PDF rebuild.")


if __name__ == "__main__":
    install()
