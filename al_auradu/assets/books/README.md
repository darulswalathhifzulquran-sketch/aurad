# Original devotional book PDFs

Place the approved original PDF in this directory **without converting it
into PNG/JPG**:

- `swalathus_saadha.pdf` — the user's approved one-page Swalathus Sa'adha
  book. It opens from `Swalath → Swalathus Sa'adha`.

The app intentionally displays **Content not added yet** if this binary file
has not been uploaded. Existing folder names and all Quran Surah/Juz labels
must remain untouched.

How to add in Codespaces:

1. Open the `feature/swalathu-saadha-vector-pdf` branch.
2. Drag the PDF into `al_auradu/assets/books/`.
3. Rename it **exactly** `swalathus_saadha.pdf`.
4. Commit and push on the feature branch.
5. Verify using `flutter analyze`, `flutter test` and `flutter build web`.
6. Open the app, tap Swalathus Sa'adha, and test pinch zoom at 400%.

Do not OCR or rasterize the supplied content. Retain original embedded fonts
and the page decoration exactly as received.
