# Quran reader verification (do not publish without review)

The original `al_auradu/quran.pdf` is tracked in Git LFS (approximately
164,637,564 bytes). This branch references it as a Flutter PDF asset **without
making another copy**.

The old `assets/quran/*.webp` screenshots are NOT used by the new Quran
reader, to avoid scaling the fixed-size raster pages.

## How to check in GitHub Codespaces

1. Make sure you are on `feature/quran-pdf-reader-604`.
2. Run `git lfs pull`; `quran.pdf` must be a genuine `%PDF-` file rather
   than a 134-byte Git LFS pointer. Never commit the binary as ordinary Git.
3. Use PDF inspection tools (`pdfinfo quran.pdf`, `pdffonts quran.pdf` or
   a PDF viewer) to verify the document has **604 pages** and to determine
   whether Quran glyphs are vector text rather than scanned page photos.
4. Check the 604-page MADINAH edition visually. Having 604 pages alone is
   NOT proof that the Surah and Juz start-page mapping matches.
5. Verify at least Al-Fatiha p1, Al-Baqarah p2, Al-An'am p128,
   and Juz 30 p582 as well as the final Surah at p604.
6. Flutter commands: `flutter pub get`, `flutter analyze --no-fatal-infos`,
   `flutter test`, `flutter build web`.
7. Preview Home -> Quran -> Surah / Juz on mobile and desktop, scroll
   vertically, zoom to 400%, check Arabic harakat and page boundaries.
8. If the existing 157 MB PDF is an image-only scan, its printed-page pixels
   CANNOT become infinitely sharp by switching Flutter PDF renderers.
   Obtain a verified vector Mushaf from a trusted source instead.

## Reader behavior

- Original 114 Surah and 30 Juz lists stay visible.
- An entry opens the same PDF at its standard Madinah-604 starting page.
- A PDF with a page count other than 604 triggers a warning and DOES NOT
  automatically jump to the requested Surah/Juz page.
- Continuous vertical scroll, pinch zoom, page-left/right controls, and
  page-number navigation are provided by Flutter + PDFium (pdfrx).
- Other library folders and their text are not modified.
- Embedded PDF bytes are loaded directly without OCR, image conversion,
  font substitution, replacing/retyping Quran, or adding external page art.

## Publishing considerations

At ~157 MB the Quran PDF itself dominates the app size and web downloads.
Before Play Store release consider official-source rights and efficient
content distribution (e.g. verified offline download with cache). Do not
compress away the readable glyph detail.
