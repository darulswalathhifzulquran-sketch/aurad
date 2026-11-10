# Al Auradu: install precisely the two user-provided Mawlid PDF sources
# and two exact user-approved border pictures, without touching other folders.
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$dest = Join-Path $root "assets\mawlid_sources"
New-Item -ItemType Directory -Path $dest -Force | Out-Null
Add-Type -AssemblyName System.Windows.Forms
$owner = New-Object System.Windows.Forms.Form
$owner.TopMost = $true
$owner.ShowInTaskbar = $false
$owner.Size = New-Object System.Drawing.Size(1,1)
$owner.StartPosition = "CenterScreen"

function Choose-File([string]$title,[string]$filter,[string]$name) {
  $dlg = New-Object System.Windows.Forms.OpenFileDialog
  $dlg.Title = $title
  $dlg.Filter = $filter
  $dlg.InitialDirectory = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
  if ($dlg.ShowDialog($owner) -ne [System.Windows.Forms.DialogResult]::OK) {
    throw "Cancelled: $title"
  }
  Copy-Item -LiteralPath $dlg.FileName -Destination (Join-Path $dest $name) -Force
  Write-Host "Selected: $name" -ForegroundColor Green
}
try {
  Choose-File "1 of 4 - Choose Manqoos Moulid ORIGINAL PDF (17 pages)" "PDF files (*.pdf)|*.pdf" "manqoos_original.pdf"
  Choose-File "2 of 4 - Choose Sharafal Anam ORIGINAL PDF (30 pages)" "PDF files (*.pdf)|*.pdf" "sharafal_anam_original.pdf"
  Choose-File "3 of 4 - Choose approved LIGHT WHITE/GOLD border image" "PNG images (*.png)|*.png" "border_light.png"
  Choose-File "4 of 4 - Choose approved DARK BLACK/BLUE border image" "PNG images (*.png)|*.png" "border_dark.png"
} finally {
  $owner.Dispose()
}
py -m pip install --disable-pip-version-check pymupdf pillow numpy
if ($LASTEXITCODE -ne 0) { throw "Python dependency installation failed" }
py (Join-Path $root "tools\build_mawlid_themes.py")
if ($LASTEXITCODE -ne 0) { throw "PDF preparation failed - see error above" }
Write-Host "All four Mawlid PDFs created in assets/books" -ForegroundColor Green
Write-Host "Next: flutter pub get; flutter run -d chrome" -ForegroundColor Cyan
