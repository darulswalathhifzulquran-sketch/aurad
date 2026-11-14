"""Install the EXACT academy footer artwork without retyping Arabic.

Windows usage:
    python tool/install_academy_footer.py

Drag one rectangle around the badge in the preview and click "Use Selection".
Works for page screenshots, black backgrounds, pre-cropped logos, and large images.
It does NOT guess the crop or substitute unrelated images.
"""
from pathlib import Path
from PIL import Image, ImageTk, ImageOps
import tkinter as tk
from tkinter import filedialog, messagebox

ROOT = Path(__file__).resolve().parents[1]
DOWNLOADS = Path.home() / "Downloads"
DEST = ROOT / "assets" / "images" / "academy_footer_exact.png"


def install():
    root = tk.Tk()
    root.withdraw()
    preferred = DOWNLOADS / "academy_footer.png"
    alt = DOWNLOADS / "academy_footer_exact.png"
    source = preferred if preferred.is_file() else (alt if alt.is_file() else None)
    if not source:
        messagebox.showinfo("Select footer picture",
            "Select the image containing جامعة الإمام النووي.")
        chosen = filedialog.askopenfilename(
            title="Select academy footer reference image",
            initialdir=str(DOWNLOADS),
            filetypes=[("Images", "*.png *.jpg *.jpeg *.webp"), ("All files", "*.*")])
        if not chosen:
            print("Cancelled: no image selected.")
            root.destroy()
            return
        source = Path(chosen)

    original = ImageOps.exif_transpose(Image.open(source)).convert("RGBA")
    width, height = original.size
    max_w, max_h = 1000, 750
    scale = min(max_w / width, max_h / height, 1.0)
    view_size = (max(1, round(width * scale)), max(1, round(height * scale)))
    preview = original.resize(view_size, Image.Resampling.LANCZOS)

    win = tk.Toplevel(root)
    win.title("Academy footer - drag around ONLY the academy plaque")
    win.resizable(False, False)
    tk.Label(win, text="Drag to select ONLY the white rectangular academy box. "
                       "Keep its black border and all Arabic lettering intact.",
             font=("Segoe UI", 10)).pack(padx=10, pady=(10, 6))
    canvas = tk.Canvas(win, width=view_size[0], height=view_size[1],
                       highlightthickness=1, highlightbackground="#888")
    canvas.pack(padx=10)
    tk_photo = ImageTk.PhotoImage(preview)
    canvas.create_image(0, 0, image=tk_photo, anchor="nw")
    canvas.image = tk_photo

    state = {"origin": None, "rect": None, "box": None, "saved": False}

    def start(e):
        state["origin"] = (e.x, e.y)
        if state["rect"]:
            canvas.delete(state["rect"])
        state["rect"] = None
        state["box"] = None

    def move(e):
        if state["origin"] is None:
            return
        x0,y0 = state["origin"]
        x1=max(0,min(view_size[0],e.x))
        y1=max(0,min(view_size[1],e.y))
        if state["rect"]:
            canvas.coords(state["rect"],x0,y0,x1,y1)
        else:
            state["rect"]=canvas.create_rectangle(x0,y0,x1,y1,
                                    outline="#00d4ff",width=3)

    def end(e):
        if state["origin"] is None:
            return
        x0,y0=state["origin"]
        x1=max(0,min(view_size[0],e.x))
        y1=max(0,min(view_size[1],e.y))
        l,t,r,b=sorted((x0,x1))[0], sorted((y0,y1))[0], sorted((x0,x1))[1], sorted((y0,y1))[1]
        state["box"]=(l,t,r,b)
        state["origin"]=None

    canvas.bind("<ButtonPress-1>",start)
    canvas.bind("<B1-Motion>",move)
    canvas.bind("<ButtonRelease-1>",end)

    def use_selection():
        box = state["box"]
        if not box:
            messagebox.showwarning("Select footer","Drag around the academy box first.",parent=win)
            return
        l,t,r,b=box
        if r-l < 30 or b-t < 8:
            messagebox.showwarning("Selection too small","Select the entire badge.",parent=win)
            return
        if (r-l)/(b-t) < 1.7:
            messagebox.showwarning("Not horizontal",
                "Select just the wide horizontal footer box, not the whole page.",parent=win)
            return
        exact=(max(0,int(l/scale)),max(0,int(t/scale)),
               min(width,int(r/scale)),min(height,int(b/scale)))
        result=original.crop(exact)
        DEST.parent.mkdir(parents=True,exist_ok=True)
        result.save(DEST,optimize=True)
        state["saved"]=True
        print("SUCCESS: Exact original footer saved:",DEST,flush=True)
        print("SOURCE:",source,"CROP:",exact,flush=True)
        win.destroy()

    footer=tk.Frame(win)
    footer.pack(fill="x",padx=10,pady=12)
    tk.Button(footer,text="Use Selection",command=use_selection,
              font=("Segoe UI",11,"bold"),bg="#d0f4db",
              width=20).pack(side="left",padx=8)
    tk.Button(footer,text="Cancel",command=win.destroy,
              width=12).pack(side="left")
    win.protocol("WM_DELETE_WINDOW",win.destroy)
    print("Source:",source,"dimensions:",width,"x",height,flush=True)
    print("A crop window will open. Drag around the academy footer badge.",flush=True)
    root.wait_window(win)
    root.destroy()
    if not state["saved"]:
        raise SystemExit("No change made: academy footer crop was cancelled.")


if __name__ == "__main__":
    install()
