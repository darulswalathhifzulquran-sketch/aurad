"""Install SIX EXACT original PDFs supplied in the latest user message.

Keep every original byte: never add/remove page numbers, footer, borders,
calligraphy, Arabic lettering or change the PDF page boxes.
Download all six attached PDFs to Windows Downloads with their original names.
Run: python tool/install_six_original_pdfs.py
This validates EVERY input before replacing ANY app asset, saves backups,
copies source bytes exactly, and verifies SHA256 for each installed asset.
"""
from pathlib import Path
from shutil import copy2, copyfile
from hashlib import sha256
import json
import sys

try:
    import pymupdf
except ImportError:
    sys.exit("Missing pymupdf. Run: python -m pip install pymupdf")

ROOT = Path(__file__).resolve().parents[1]
DOWNLOADS = Path.home() / "Downloads"
ASSETS = ROOT / "assets" / "books"

# Exact latest uploaded names, never silently fall back to previous revisions.
BOOKS = (
    ("hizbu nnasr(2).pdf", "hizbun_nasr.pdf", 3, "dua-4"),
    ("majlisunnoor(2).pdf", "majlisunnoor.pdf", 17, "majlisunnoor-1"),
    ("Manqoos moulid-3-19 (1).pdf.pdf", "mankoos_moulid_light.pdf", 13, "mankoos-mawlid"),
    ("swalathu nnariyah.pdf", "swalathu_nariyath.pdf", 1, "swalath-4"),
    ("swalathu sa\x60adha [Autosaved](3).pdf", "swalathu_saadha_corrected.pdf", 1, "swalath-saadha"),
    ("swalathu thaj. pdf(1).pdf", "swalathu_taj.pdf", 2, "swalath-3"),
)

def digest(path):
    h = sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def find_source(source_name, item_id):
    requested = DOWNLOADS / source_name
    if requested.is_file():
        return requested
    if item_id != "swalath-saadha":
        return requested
    # Different browser/Windows downloads may normalize the apostrophe
    # or backtick. Never select an unrelated PDF or an old version.
    # The source attached by the user in this conversation is exactly
    # 344092 bytes (one PDF page). Only consider matching-size alternate
    # filenames, never arbitrarily use a previously downloaded revision.
    expected_size = 344092
    matches = []
    nearby = []
    for candidate in DOWNLOADS.glob("*.pdf"):
        name = candidate.name.casefold()
        if name.startswith("swalathu sa") and "autosaved" in name:
            nearby.append(candidate)
            if candidate.stat().st_size == expected_size:
                matches.append(candidate)
    if len(matches) == 1:
        print("FOUND SA'ADHA: matching the uploaded PDF's exact byte length:")
        print(" ", matches[0].name, "(", expected_size, "bytes)")
        return matches[0]
    if len(matches) > 1:
        hashes = {digest(candidate) for candidate in matches}
        if len(hashes) == 1:
            print("FOUND SA'ADHA: multiple identical files; using", matches[0].name)
            return matches[0]
        print("AMBIGUOUS: multiple differently encoded Sa'adha PDFs have")
        print("the expected size. Save the uploaded (3) PDF under its exact name.")
    print("SA'ADHA DOWNLOAD NOT FOUND with the supplied file's size (344092 bytes).")
    print("Available related PDFs:")
    for candidate in nearby:
        print(" ", candidate.name, candidate.stat().st_size, "bytes")

    return requested


def main():
    catalog = json.loads((ROOT / "assets/data/library.json").read_text(encoding="utf-8"))
    by_id = {entry["id"]: entry for entry in catalog["items"]}
    prepared = []
    errors = []
    for source_name, target_name, expected_pages, item_id in BOOKS:
        src = find_source(source_name, item_id)
        dest = ASSETS / target_name
        if not src.is_file():
            errors.append(f"MISSING DOWNLOAD: {source_name}")
            continue
        try:
            with pymupdf.open(src) as pdf:
                count = len(pdf)
                if count != expected_pages:
                    errors.append(f"WRONG SOURCE: {source_name} has {count} pages, expected {expected_pages}")
                    continue
        except Exception as exc:
            errors.append(f"PDF INVALID: {source_name}: {exc}")
            continue
        if by_id.get(item_id, {}).get("pdfAsset") != f"assets/books/{target_name}":
            errors.append(f"WRONG APP MAPPING for {item_id}: expected {target_name}")
            continue
        prepared.append((src, dest, expected_pages))
    if errors:
        sys.exit(
            "NO PDFS CHANGED. Fix these before running again:\n" +
            "\n".join("  - " + item for item in errors)
        )
    ASSETS.mkdir(parents=True, exist_ok=True)
    for src, dest, count in prepared:
        if dest.exists() and digest(src) == digest(dest):
            print(f"EXACT ALREADY INSTALLED: {dest.name}, {count} pages")
            continue
        if dest.exists():
            backup = ASSETS / (dest.name + ".before_six_originals_backup")
            if not backup.exists():
                copy2(dest, backup)
        temporary = ASSETS / (dest.name + ".installing")
        copyfile(src, temporary)
        if digest(temporary) != digest(src):
            temporary.unlink(missing_ok=True)
            sys.exit(f"Copy verification failed for {src.name}.")
        temporary.replace(dest)
        print(f"INSTALLED UNMODIFIED: {dest.name}, {count} pages")
    print("\nFINAL EXACT-BYTE VERIFICATION:")
    for src, dest, count in prepared:
        if digest(src) != digest(dest):
            sys.exit("FAILED: " + dest.name)
        print(f"  MATCH: {src.name} -> {dest.name} | SHA256 {digest(dest)}")
    print("SUCCESS: ALL SIX BOOKS MATCH THE USER'S ORIGINAL PDFs BYTE-FOR-BYTE.")
    print("Every original printed page number and embedded academy footer is preserved.")
    print("Restart Flutter after copying assets: flutter clean; flutter pub get; flutter run -d chrome")

if __name__ == "__main__":
    main()
