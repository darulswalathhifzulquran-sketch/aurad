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

flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }
flutter build web --release
if ($LASTEXITCODE -ne 0) { throw "Flutter Web build failed" }
if (-not (Test-Path "build/web/index.html")) { throw "Web build output missing" }

Write-Host "Deploying verified web app to the linked Netlify site..." -ForegroundColor Cyan
npx --yes netlify-cli deploy --prod --no-build --dir "build/web"
if ($LASTEXITCODE -ne 0) { throw "Netlify publish failed" }
Write-Host "Published. Copy the Production URL printed above to share the app." -ForegroundColor Green
