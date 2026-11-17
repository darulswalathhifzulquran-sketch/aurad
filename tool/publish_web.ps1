# Publish the verified local Flutter Web app to its already-linked Netlify site.
# Run ONLY after: tool/install_latest_books.py and tool/install_shared_footer.py.
$ErrorActionPreference = "Stop"
Set-Location (Resolve-Path (Join-Path $PSScriptRoot ".."))

$required = @(
    "assets/books/majlisunnoor.pdf",
    "assets/books/hizbun_nasr.pdf",
    "assets/images/academy_footer_exact.png",
    "quran.pdf"
)
foreach ($file in $required) {
    if (-not (Test-Path $file)) {
        throw "Missing required app asset: $file. Publish stopped."
    }
}

# Don't publish an unlinked project to an unexpected domain.
if (-not (Test-Path ".netlify/state.json")) {
    Write-Host "Netlify site not linked yet." -ForegroundColor Yellow
    Write-Host "Run: npx netlify-cli login"
    Write-Host "Then: npx netlify-cli link"
    throw "Publish stopped until the intended site is linked."
}

# Verify the new PDFs' page counts before publishing.
@'
import pymupdf
files = [("assets/books/majlisunnoor.pdf", 17),
         ("assets/books/hizbun_nasr.pdf", 3)]
for path, expected in files:
    with pymupdf.open(path) as d:
        if len(d) != expected:
            raise SystemExit(f"{path}: expected {expected} pages, got {len(d)}")
        print(f"VERIFIED: {path}, {len(d)} pages")
'@ | python -
if ($LASTEXITCODE -ne 0) { throw "PDF verification failed" }

# Build page-by-page reader assets once from the user's EXACT original PDFs.
# Subsequent runs reuse the existing images, so only changed pages are built.
python ".\\tool\\install_web_book_pages.py"
if ($LASTEXITCODE -ne 0) { throw "Book web-page preparation failed" }
python ".\\tool\\install_quran_web_pages.py"
if ($LASTEXITCODE -ne 0) { throw "Quran web-page preparation failed" }
if (-not (Test-Path "assets/quran_pages/page_0604.jpg")) {
    throw "Quran web images missing; publish stopped"
}

flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }
flutter build web --release --no-wasm-dry-run
if ($LASTEXITCODE -ne 0) { throw "Flutter Web build failed" }
if (-not (Test-Path "build/web/index.html")) { throw "Web build output missing" }
# Ensure source PDFs actually exist inside the public Flutter Web build.
$webPdfAssets = @(
    "build/web/assets/assets/books/majlisunnoor.pdf",
    "build/web/assets/assets/books/hizbun_nasr.pdf",
    "build/web/assets/assets/books/salam_baith.pdf",
    "build/web/assets/assets/quran_pages/page_0001.jpg",
    "build/web/assets/assets/quran_pages/page_0604.jpg",
    "build/web/assets/assets/web_books/majlisunnoor-1_page_0001.jpg",
    "build/web/assets/assets/web_books/dua-4_page_0001.jpg",
    "build/web/assets/assets/web_books/baith-3_page_0001.jpg",
    "build/web/assets/assets/data/web_books_manifest.json"
)
foreach ($pdf in $webPdfAssets) {
    if (-not (Test-Path $pdf)) {
        throw "Book PDF missing in web build: $pdf. Publish stopped."
    }
    Write-Host "WEB PDF INCLUDED: $pdf"
}

Write-Host "Deploying verified web app to the linked Netlify site..." -ForegroundColor Cyan
npx.cmd --yes netlify-cli deploy --prod --no-build --dir "build/web"
if ($LASTEXITCODE -ne 0) { throw "Netlify publish failed" }
Write-Host "Published. Copy the Production URL printed above to share the app." -ForegroundColor Green
