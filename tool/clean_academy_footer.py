"""Trim the extra outer background from the ALREADY INSTALLED academy badge.

Does not redraw or change a single Arabic letter. It only crops the
solid-color margin outside the supplied image. Re-run safely after any
new academy_footer_exact.png installation.
    python tool/clean_academy_footer.py
"""
from pathlib import Path
from PIL import Image, ImageChops, ImageStat

ASSET = Path(__file__).resolve().parents[1] / "assets/images/academy_footer_exact.png"


def clean():
    if not ASSET.exists():
        raise SystemExit("Missing academy footer image: run install_academy_footer.py")
    image = Image.open(ASSET).convert("RGBA")
    rgb = image.convert("RGB")
    w, h = rgb.size
    # Sample the four corners (outer screenshot/background, not the text).
    corners = [rgb.getpixel(xy) for xy in
               [(0, 0), (w-1, 0), (0, h-1), (w-1, h-1)]]
    bg = tuple(sorted(c[i] for c in corners)[2] for i in range(3))
    # Find the non-background horizontal plaque outline and lettering.
    bgimg = Image.new("RGB", rgb.size, bg)
    difference = ImageChops.difference(rgb, bgimg).convert("L")
    binary = difference.point(lambda z: 255 if z >= 48 else 0)
    bounds = binary.getbbox()
    if not bounds:
        raise SystemExit("Cannot detect academy plaque; original left unchanged")
    l,t,r,b = bounds
    if (r-l) < w * .3 or (b-t) < 6:
        raise SystemExit("Detected crop is too small; original left unchanged")
    # Two-pixel pad retains the black outline and Arabic decorative mark.
    padx = min(4, max(1, w//200))
    pady = min(3, max(1, h//60))
    bounds=(max(0,l-padx),max(0,t-pady),min(w,r+padx),min(h,b+pady))
    output=image.crop(bounds)
    if output.width/output.height < 2:
        raise SystemExit("Crop is not a horizontal badge; original left unchanged")
    output.save(ASSET, optimize=True)
    print("SUCCESS: removed academy badge exterior only:", w,h,
          "->",output.size,"original text pixels preserved")


if __name__ == "__main__":
    clean()
