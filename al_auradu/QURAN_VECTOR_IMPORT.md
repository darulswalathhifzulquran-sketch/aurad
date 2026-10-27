# Al Auradu Quran: Surah-wise + Juz-wise — 1441 Hafs vector source

## What we have, what we do NOT have
- The owner uploaded a **466,430,736-byte ZIP** labelled `quran pdf`.
- It is a ZIP containing **604 .ai Adobe Illustrator source pages**, not a PDF.
- The owner separately supplied a blue Islamic decorative border PNG.
- The existing `al_auradu/quran.pdf` in Git LFS is **624 pages of scans**:
  its page mapping is incompatible and its text pixelates when zoomed.
  **Never use that old file in this new 604-page reader.**
- The original ZIP and border PNG are attached in the ChatGPT conversation,
  but **are not automatically copied into GitHub Codespaces**. The built
  `quran_vector_604.pdf` must be imported before the Quran reading screen
  can display pages. The reader safely shows a missing-content message until
  this asset exists.

## What's ready
- Existing 114 Surah names and 30 Juz names remain unchanged.
- Both Quran tabs open `QuranVectorReader` with their proper start-page
  indices from the existing `mushaf.dart` table, using ONE 604-page PDF.
- The user can pinch zoom, vertically scroll, turn to the next/previous
  page with the side arrows, or type a page number using the search icon.
- The page number slider was intentionally not added.
- The Home Page, Swalathu Sa'adha, Mawlid, Mala, Baith, Counter and other
  approved designs are untouched.
- The original Arabic verse glyph artwork is never OCR'd, rewritten,
  spelled, corrected or reconstructed by an image generator.

## Import in Codespaces (no manual Dart editing)
1. Keep the branch `feature/quran-1441-vector-surah-juz` in Codespaces.
2. Use your previously downloaded and extracted King Fahd Complex **original
   1441 Hafs ZIP**, or let the helper download the official archive:
   `https://dm.qurancomplex.gov.sa/Download/1441-AI-hafs.zip`.
   It is roughly 466 MB. If this server is unavailable, upload your own
   ZIP into the Codespace and pass its path.
3. Ask Copilot Agent to run:
   `bash al_auradu/tool/install_vector_quran.sh "/path/to/original.zip"`
   or `bash al_auradu/tool/install_vector_quran.sh` to use the official URL.
   The script checks EXACTLY 604 numbered AI files.
4. It converts compatible AI vector artwork to PDF while preserving
   curves/letter outlines, and merges pages 001 through 604 **in order**.
   If the AI file is not PDF-compatible, install Inkscape; the script will
   convert via Inkscape's vector PDF export.
5. **BEFORE RELEASE:** visually inspect outputs at pages 1, 2, 128, 582, 604;
   check 114 Surah and 30 Juz boundaries, Arabic letter forms, harakat,
   ayah medallions, and the publisher/edition. Do not assume 604 count alone
   proves the page-index mapping.
6. After approved, have Copilot run `git lfs install`, `git add`,
   `git commit`, and `git push` on the feature branch. Git LFS tracking
   for the output PDF is configured. Never use ordinary Git for large PDFs.
7. `flutter pub get`, `flutter analyze`, `flutter test`, and
   `flutter build web --release`, then restart the **Fast Release Preview**
   on private Codespaces port 3000 and inspect on a mobile-sized screen.

## Border and Dark Mode — source-safety gate
The user's exact blue border PNG is NOT yet a verified Flutter repository
asset. Do not approximate it with generated artwork, or flatten/retype Quran
text to make room for it. Use a separate **non-destructive decoration layer**
only AFTER verifying it does not obscure any original letters or marks.
Likewise, making the PDF background black and text white requires validated
vector recoloring; changing only Flutter's outer background does not erase
white pixels inside an opaque PDF. Do not risk corrupted Quran glyphs.
The old white/page background may remain until this can be verified.

## App size/speed
The vector PDF can be hundreds of megabytes. Do not load it during Home
startup. PDFium viewer is opened only when a Quran item is selected.
For Play Store release, plan lazy download/offline caching or per-page assets
after reviewing size and download performance. A large bundled PDF can make
the installed app unnecessarily heavy.

## Review gate
This is a separate Pull Request. **Do not merge to the working App or main**
until the owner visually approves the vector Quran, precise navigation,
border treatment, and live PDF opening time.
