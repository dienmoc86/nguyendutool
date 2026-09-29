$baseTools = "tools"
if (-not (Test-Path $baseTools)) { New-Item -ItemType Directory -Path $baseTools | Out-Null }

# 1. Stirling-PDF
$stirlingDir = Join-Path $baseTools "Stirling-PDF"
if (-not (Test-Path $stirlingDir)) { New-Item -ItemType Directory -Path $stirlingDir | Out-Null }

$stirlingJarUrl = "https://github.com/Stirling-Tools/Stirling-PDF/releases/download/v3.0.1/Stirling-PDF.jar"
$stirlingJarFile = Join-Path $stirlingDir "Stirling-PDF.jar"
Write-Host "Downloading Stirling-PDF.jar using curl.exe..."
& curl.exe -L --fail --progress-bar -o $stirlingJarFile $stirlingJarUrl
Write-Host "Finished Stirling-PDF.jar download. Size: $((Get-Item $stirlingJarFile).Length / 1MB) MB"

# 2. Tesseract OCR Installer
$tessDir = Join-Path $baseTools "Tesseract"
if (-not (Test-Path $tessDir)) { New-Item -ItemType Directory -Path $tessDir | Out-Null }

$tessInstallerUrl = "https://github.com/UB-Mannheim/tesseract/releases/download/v5.4.0.20240606/tesseract-ocr-w64-setup-5.4.0.20240606.exe"
$tessInstallerFile = Join-Path $tessDir "tesseract-ocr-w64-setup-5.4.0.20240606.exe"
Write-Host "Downloading Tesseract OCR installer using curl.exe..."
& curl.exe -L --fail --progress-bar -o $tessInstallerFile $tessInstallerUrl
Write-Host "Finished Tesseract download. Size: $((Get-Item $tessInstallerFile).Length / 1MB) MB"

Write-Host "All source downloads complete."
