"""Install the user's exact academy plaque in Flutter assets.

Usage: python tool/install_academy_footer.py
Save the approved footer image in Downloads as academy_footer.png
(or academy_footer_exact.png). It MUST be the academy badge, not a chart.
No Arabic letters are retyped, inferred, or regenerated here.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
DOWNLOADS=Path.home()/"Downloads"
DEST=ROOT/"assets"/"images"/"academy_footer_exact.png"

def install():
    choices=[
       DOWNLOADS/"academy_footer_exact.png",
       DOWNLOADS/"academy_footer.png",
       DOWNLOADS/"download(1).png",
    ]
    source=next((p for p in choices if p.is_file()),None)
    if source is None:
        raise SystemExit(
            "MISSING IMAGE: Save your exact white academy badge to "
            "Downloads/academy_footer.png. No changes to PDF or text were made.")
    img=Image.open(source).convert("RGBA")
    w,h=img.size
    # Explicitly reject wide spreadsheet/chart images that were mistakenly
    # inserted by the old script as Downloads/download.png.
    if w>1200 and h<110:
        raise SystemExit("Not an academy badge: selected file looks like a chart.")
    # If screenshot has a black exterior, crop to the actual white capsule.
    rgb=img.convert("RGB")
    pixels=rgb.load()
    white=[]
    stride=max(1,min(w,h)//450)
    for y in range(0,h,stride):
        for x in range(0,w,stride):
            rr,gg,bb=pixels[x,y]
            if min(rr,gg,bb)>225:
                white.append((x,y))
    if not white:
        raise SystemExit("Image has no white academy plaque: keep the original.")
    left=min(p[0] for p in white)
    top=min(p[1] for p in white)
    right=max(p[0] for p in white)+stride
    bottom=max(p[1] for p in white)+stride
    # A proper academy plaque is a wide, short badge.
    if right-left < 1.8*(bottom-top):
        raise SystemExit("Image is not a horizontal academy plaque.")
    xpad=max(1,int(.007*(right-left)))
    ypad=max(1,int(.015*(bottom-top)))
    left=max(0,left-xpad);top=max(0,top-ypad)
    right=min(w,right+xpad);bottom=min(h,bottom+ypad)
    img=img.crop((left,top,right,bottom))
    # Rounded crop removes exterior black but keeps every original letter.
    width,height=img.size
    mask=Image.new("L",(width,height),0)
    d=ImageDraw.Draw(mask)
    d.rounded_rectangle((0,0,width-1,height-1),
        radius=max(2,min(height//3,width//16)),fill=255)
    img.putalpha(mask)
    DEST.parent.mkdir(parents=True,exist_ok=True)
    img.save(DEST,optimize=True)
    print("SUCCESS: exact academy footer image copied to",DEST)
    print("Source:",source)
    print("Original Arabic lettering is unmodified.")

if __name__=="__main__":
    install()
