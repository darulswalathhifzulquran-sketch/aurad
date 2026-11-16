"""Install EXACT uploaded academy calligraphy as the single shared badge.

Download the 3rd image shared with Majlisunnoor / Hizbun Nasr to
Windows Downloads, named academy_footer_new.png.
Run: python tool/install_shared_footer.py

It keeps the original printed Arabic glyphs, crops outer margins, removes
only background connected to the corners and never types substitute Arabic.
"""
from pathlib import Path
from PIL import Image, ImageDraw
from collections import deque

ROOT=Path(__file__).resolve().parents[1]
DOWNLOADS=Path.home()/"Downloads"
DEST=ROOT/"assets/images/academy_footer_exact.png"
NAMES=("academy_footer_new.png","image(20261116-073959).png")

def exterior_background(image):
    """Return the original RGBA badge with outer black made transparent."""
    rgba=image.convert("RGBA")
    width,height=rgba.size
    if width<120 or height<25:
        raise ValueError("Reference image is too small for HD footer.")
    pix=rgba.load()
    corners=[pix[x,y][:3] for x,y in
             ((0,0),(width-1,0),(0,height-1),(width-1,height-1))]
    is_dark=sum(max(c)<95 for c in corners)>=3
    if not is_dark:
        # Source may be pre-cropped light plaque; preserve it as supplied.
        return rgba
    queue=deque([(0,0),(width-1,0),(0,height-1),(width-1,height-1)])
    seen=bytearray(width*height)
    while queue:
        x,y=queue.popleft()
        if not (0<=x<width and 0<=y<height):
            continue
        idx=y*width+x
        if seen[idx]:
            continue
        seen[idx]=1
        red,green,blue,alpha=pix[x,y]
        # Only the black connected exterior is transparent. Black letters
        # inside the WHITE plaque are never connected to these corners.
        if max(red,green,blue)>125:
            continue
        pix[x,y]=(red,green,blue,0)
        if x>0:queue.append((x-1,y))
        if x+1<width:queue.append((x+1,y))
        if y>0:queue.append((x,y-1))
        if y+1<height:queue.append((x,y+1))
    bbox=rgba.getbbox()
    if not bbox:
        raise ValueError("No footer plaque detected; source was not installed.")
    pad=2
    left,top,right,bottom=bbox
    return rgba.crop((max(0,left-pad),max(0,top-pad),
                      min(width,right+pad),min(height,bottom+pad)))

def main():
    source=next((DOWNLOADS/name for name in NAMES
                 if (DOWNLOADS/name).is_file()),None)
    if source is None:
        raise SystemExit(
            "FOOTER IMAGE NOT FOUND. Save the exact new academy image from "
            "this chat into Downloads as academy_footer_new.png. "
            "Existing academy footer was not changed.")
    image=exterior_background(Image.open(source))
    ratio=image.width/image.height
    if not 2.0 <=ratio<=15:
        raise SystemExit(
            f"Unexpected footer proportions {ratio:.2f}; check your image. "
            "No change was made.")
    DEST.parent.mkdir(parents=True,exist_ok=True)
    if DEST.exists():
        backup=DEST.with_name("academy_footer_before_new_reference.png")
        if not backup.exists():
            import shutil
            shutil.copy2(DEST,backup)
    image.save(DEST,optimize=True)
    print("SUCCESS: new original academy footer picture installed:",DEST)
    print("SIZE:", image.width,"x",image.height,
          "original Arabic letters preserved; outside transparent")
    print("The Flutter reader uses this badge for every NON-QURAN folder.")

if __name__=="__main__":
    main()
