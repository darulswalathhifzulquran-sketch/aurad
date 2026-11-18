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
$files = @(Get-ChildItem -LiteralPath $web -File -Recurse)
if ($files.Count -gt 1000) {
    throw "Dashboard direct upload allows at most 1000 files; current: $($files.Count)"
}
$oversized = @($files | Where-Object { $_.Length -gt 25MB })
if ($oversized.Count -gt 0) {
    throw "Dashboard direct upload has a 25 MiB per-file limit. Oversized: $($oversized[0].FullName)"
}
Write-Host "VERIFIED: $($files.Count) web files fit Cloudflare Dashboard direct-upload limits." -ForegroundColor Green
Write-Host "Original PDFs in the project are unchanged."
$zip = Join-Path $root "riyadul-adkar-cloudflare.zip"
if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force }
Write-Host "Preparing ZIP from the existing Flutter build; no rebuild."
Compress-Archive -Path (Join-Path $web '*') -DestinationPath $zip -CompressionLevel Fastest
if (-not (Test-Path $zip)) { throw "ZIP creation failed." }
Write-Host "READY: $zip" -ForegroundColor Green
Write-Host "In Cloudflare Dashboard: Workers & Pages > riyadul-adkar > Create deployment > Production."
Write-Host "Use the ZIP or drag the build/web folder. Choose Save and deploy."
