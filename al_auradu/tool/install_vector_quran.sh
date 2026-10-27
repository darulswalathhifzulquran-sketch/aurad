#!/usr/bin/env bash
# Convert the original 604 King Fahd Complex Hafs .ai pages into one PDF.
# Usage: bash al_auradu/tool/install_vector_quran.sh "/path/to/owner-download.zip"
# Or run without an argument to download from the author's official URL.
set -Eeuo pipefail
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$(cd "$APP_DIR/.." && pwd)"
OUT="$APP_DIR/assets/books/quran_vector_604.pdf"

if [[ -e "$OUT" ]]; then
  echo "Quran PDF already exists; refusing to overwrite or corrupt it: $OUT"
  exit 1
fi

SOURCE="${1:-}"
if [[ -z "$SOURCE" ]]; then
  if [[ -s "$REPO_DIR/quran pdf" ]]; then
    SOURCE="$REPO_DIR/quran pdf"
  elif [[ -s "$APP_DIR/1441-AI-hafs.zip" ]]; then
    SOURCE="$APP_DIR/1441-AI-hafs.zip"
  else
    SOURCE="$REPO_DIR/1441-AI-hafs.zip"
    echo "Downloading the ORIGINAL official King Fahd Complex 604-page Hafs AI..."
    if ! curl --fail --location --retry 2 --connect-timeout 20 --max-time 900 \
        "https://dm.qurancomplex.gov.sa/Download/1441-AI-hafs.zip" \
        --output "$SOURCE"; then
      rm -f "$SOURCE"
      echo "Official ZIP download failed. Upload your existing 466 MB original"
      echo "archive to your Codespace, then run this script with its full path."
      exit 2
    fi
  fi
fi

if [[ ! -f "$SOURCE" ]]; then
  echo "Missing input ZIP: $SOURCE"
  exit 1
fi

python3 -m pip install --disable-pip-version-check --quiet PyMuPDF==1.26.5
python3 "$APP_DIR/tool/import_vector_quran.py" "$SOURCE"
python3 - "$OUT" <<'PY'
import fitz, sys
path = sys.argv[1]
with fitz.open(path) as doc:
    assert len(doc) == 604, "Quran PDF MUST contain exactly 604 pages"
    for i in [0, 1, 127, 581, 603]:
        assert doc[i].rect.width > 0 and doc[i].rect.height > 0
print("604-vector-page Quran PDF assembled; visual proofreading is mandatory.")
PY

echo "Source conversion done. Please review Surah/Juz boundaries and the"
echo "Arabic harakat visually BEFORE committing/publishing this content."
echo "Git LFS tracking is already set up for:"
echo "  al_auradu/assets/books/quran_vector_604.pdf"
echo "After approval: git lfs install; git add -f '$OUT'; commit/push feature branch."
