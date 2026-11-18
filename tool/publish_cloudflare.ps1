# Publish the exact same Flutter Web app to Cloudflare Pages without the
# Netlify platform's injected badge. Source PDFs in assets/books are unchanged.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File ".\\tool\\publish_cloudflare.ps1"
$ErrorActionPreference = "Stop"
Set-Location (Resolve-Path (Join-Path $PSScriptRoot ".."))
Write-Host "Preparing Riyadul Adkar for Cloudflare Pages..."

# Browser uses the 604 Quran JPEGs and original-book JPEGs for quick rendering.
# Never publish a stale build lacking those generated pages.
if (-not (Test-Path "assets/quran_pages/page_0604.jpg")) {
    python ".\\tool\\install_quran_web_pages.py"
    if ($LASTEXITCODE -ne 0) { throw "Quran web page generation failed." }
}
if (-not (Test-Path "assets/web_books/majlisunnoor-1_page_0001.jpg")) {
    python ".\\tool\\install_web_book_pages.py"
    if ($LASTEXITCODE -ne 0) { throw "Book web page generation failed." }
}
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "Flutter dependencies failed." }
flutter build web --release --no-wasm-dry-run
if ($LASTEXITCODE -ne 0) { throw "Flutter Web build failed." }

$web = Join-Path (Get-Location) "build/web"
if (-not (Test-Path (Join-Path $web "index.html"))) { throw "Missing index.html" }
foreach ($asset in @(
    "assets/assets/quran_pages/page_0001.jpg",
    "assets/assets/quran_pages/page_0604.jpg",
    "assets/assets/web_books/majlisunnoor-1_page_0001.jpg",
    "assets/assets/web_books/dua-4_page_0001.jpg"
)) {
    if (-not (Test-Path (Join-Path $web $asset))) {
        throw "Missing web book asset: $asset"
    }
}

# Free Cloudflare Pages has a strict 25 MiB limit per uploaded asset.
# The Web PDF readers use original-page JPEGs; oversized source PDFs are
# unnecessary in the published web directory, though remain untouched in
# project assets/books and quran.pdf for native/mobile builds.
$limit = 25MB
$large = @(Get-ChildItem $web -Recurse -File | Where-Object { $_.Length -gt $limit })
foreach ($file in $large) {
    if ($file.Extension -ieq ".pdf") {
        Write-Host "Exclude oversized ORIGINAL PDF from web upload only:" $file.Name
        Remove-Item -LiteralPath $file.FullName -Force
    } else {
        throw "Cloudflare 25 MiB file limit: $($file.FullName) ($($file.Length) bytes). No upload attempted."
    }
}

$count = @(Get-ChildItem $web -Recurse -File).Count
if ($count -gt 20000) { throw "Cloudflare free Pages file count limit exceeded: $count" }
Write-Host "READY: $count files. Original source PDFs remain unchanged in the project."
Write-Host "Cloudflare may open a browser to sign in. Approve login, then choose"
Write-Host "a Cloudflare Pages project name such as riyadul-adkar and branch main."
Write-Host "The deployment command will print the REAL public pages.dev URL."
npx.cmd --yes wrangler@4 pages deploy "build/web"
if ($LASTEXITCODE -ne 0) { throw "Cloudflare Pages deploy failed." }
Write-Host "Cloudflare Pages deployment finished. Netlify is left untouched."
