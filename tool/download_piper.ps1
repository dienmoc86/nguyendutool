$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$piperDir = "bin\piper"
if (-not (Test-Path $piperDir)) {
    New-Item -ItemType Directory -Path $piperDir | Out-Null
}

$modelsDir = Join-Path $piperDir "models"
if (-not (Test-Path $modelsDir)) {
    New-Item -ItemType Directory -Path $modelsDir | Out-Null
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Piper TTS (Offline Neural) Downloader   " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Download Piper Windows x64 release
$piperExe = Join-Path $piperDir "piper.exe"
if (-not (Test-Path $piperExe)) {
    $zipUrl = "https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_windows_amd64.zip"
    $tempZip = Join-Path $piperDir "piper_temp.zip"
    Write-Host "`n[1/2] Downloading Piper Windows x64..." -ForegroundColor Green
    & curl.exe -L --fail --progress-bar -o $tempZip $zipUrl
    if (Test-Path $tempZip) {
        Write-Host "Extracting Piper binary..." -ForegroundColor Green
        Expand-Archive -Path $tempZip -DestinationPath $piperDir -Force
        Remove-Item -Force $tempZip
        # If extracted into a nested 'piper' directory, move files up
        $nestedPiper = Join-Path $piperDir "piper"
        if (Test-Path $nestedPiper) {
            Get-ChildItem -Path $nestedPiper | Move-Item -Destination $piperDir -Force
            Remove-Item -Recurse -Force $nestedPiper
        }
    }
} else {
    Write-Host "[1/2] Piper executable already present at $piperExe." -ForegroundColor Yellow
}

# 2. Download Vietnamese ONNX model (vi_VN-25hours-single)
$onnxFile = Join-Path $modelsDir "vi_VN-25hours-single.onnx"
$jsonFile = Join-Path $modelsDir "vi_VN-25hours-single.onnx.json"

if (-not (Test-Path $onnxFile)) {
    Write-Host "`n[2/2] Downloading Vietnamese Neural ONNX voice model..." -ForegroundColor Green
    $onnxUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/vi/vi_VN/25hours_single/low/vi_VN-25hours_single-low.onnx"
    $jsonUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/vi/vi_VN/25hours_single/low/vi_VN-25hours_single-low.onnx.json"

    & curl.exe -L --fail --progress-bar -o $onnxFile $onnxUrl
    & curl.exe -L --fail --progress-bar -o $jsonFile $jsonUrl
    Write-Host "Vietnamese voice model installed successfully." -ForegroundColor Green
} else {
    Write-Host "[2/2] Vietnamese voice model already present." -ForegroundColor Yellow
}

Write-Host "`nDone! Piper TTS is ready for 100% offline synthesis." -ForegroundColor Cyan
