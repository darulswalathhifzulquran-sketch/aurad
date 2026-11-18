# Reuse the already successfully built Flutter Web output.
# Retry transient Cloudflare Pages asset-upload failures without rebuilding.
$ErrorActionPreference = "Stop"
Set-Location (Resolve-Path (Join-Path $PSScriptRoot ".."))
$required = @(
    "build/web/index.html",
    "build/web/assets/assets/quran_pages/page_0001.jpg",
    "build/web/assets/assets/quran_pages/page_0604.jpg",
    "build/web/assets/assets/web_books/majlisunnoor-1_page_0001.jpg"
)
foreach ($asset in $required) {
    if (-not (Test-Path $asset)) {
        throw "Cloudflare upload stopped: missing $asset. First run publish_cloudflare.ps1."
    }
}
$project = "riyadul-adkar"
$attempts = 3
for ($i = 1; $i -le $attempts; $i++) {
    Write-Host ""
    Write-Host "CLOUDFLARE UPLOAD ATTEMPT $i / $attempts (NO FLUTTER REBUILD)" -ForegroundColor Cyan
    npx.cmd --yes wrangler@4 pages deploy "build/web" --project-name $project --branch main --commit-dirty=true
    if ($LASTEXITCODE -eq 0) {
        Write-Host "CLOUDFLARE DEPLOYED SUCCESSFULLY." -ForegroundColor Green
        Write-Host "The CLI above reports the actual pages.dev URL."
        exit 0
    }
    if ($i -lt $attempts) {
        Write-Host "Upload failed. Waiting briefly before retry (Cloudflare may have a temporary upload issue)." -ForegroundColor Yellow
        Start-Sleep -Seconds (8 * $i)
    }
}
throw "Cloudflare Pages upload failed after $attempts attempts. Copy the last Wrangler error, including any HTTP status code. Do NOT rebuild Flutter."
