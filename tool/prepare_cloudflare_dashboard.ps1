# Prepare a Cloudflare Pages dashboard drag-and-drop deployment.
# Does not run Flutter, recompile, modify source PDFs, or contact Cloudflare.
# Deploy an existing Direct Upload project using its Create deployment button.
$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $root
$web = Join-Path $root "build/web"
if (-not (Test-Path (Join-Path $web "index.html"))) {
    throw "No Flutter build found. Run publish_cloudflare.ps1 once first."
}
foreach ($path in @(
    "assets/assets/quran_pages/page_0001.jpg",
    "assets/assets/quran_pages/page_0604.jpg",
    "assets/assets/web_books/majlisunnoor-1_page_0001.jpg",
    "assets/assets/web_books/dua-4_page_0001.jpg"
)) {
    if (-not (Test-Path (Join-Path $web $path))) {
        throw "Deployment missing required page: $path"
    }
}
# Stage a Cloudflare-only copy. The Netlify build contains some PDFs larger
# than Cloudflare's 25 MiB limit; keep ALL original PDFs and the Netlify
# build untouched. Generated JPG pages continue to provide the web reader.
$stage = Join-Path $root "build/cloudflare_upload"
if (Test-Path $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null
Copy-Item -Path (Join-Path $web '*') -Destination $stage -Recurse -Force
$oversized = @(Get-ChildItem -LiteralPath $stage -File -Recurse |
    Where-Object { $_.Length -gt 25MB })
foreach ($file in $oversized) {
    if ($file.Extension -ine ".pdf") {
        throw "Cannot exclude non-PDF asset above 25 MiB: $($file.FullName)"
    }
    Write-Host "Exclude oversized source PDF from Cloudflare ZIP only: $($file.Name)"
    Remove-Item -LiteralPath $file.FullName -Force
}
$files = @(Get-ChildItem -LiteralPath $stage -File -Recurse)
if ($files.Count -gt 1000) {
    throw "Dashboard direct upload allows at most 1000 files; current: $($files.Count)"
}
Write-Host "VERIFIED: $($files.Count) files for Cloudflare dashboard upload." -ForegroundColor Green
Write-Host "Original source PDFs and Netlify build/web remain unchanged."
$zip = Join-Path $root "riyadul-adkar-cloudflare.zip"
if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force }
Write-Host "Preparing ZIP from existing production build; NO Flutter rebuild."
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Fastest
if (-not (Test-Path $zip)) { throw "ZIP creation failed." }
Write-Host "READY: $zip" -ForegroundColor Green
Write-Host "In Cloudflare Dashboard: Workers & Pages > riyadul-adkar > Create deployment > Production."
Write-Host "Upload the ZIP file. Do not upload build/web (it contains oversized PDFs). Choose Save and deploy."
