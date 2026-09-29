<#
.SYNOPSIS
    Master build and packaging script for NguyenDu Tool.
.DESCRIPTION
    Compiles Flutter release, builds Inno Setup installer, creates portable ZIP,
    computes SHA-256 hashes, and outputs everything to 'D:\CODE\Nguyen Du tool\đóng gói tool'.
#>

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  NguyenDu Tool - Master Build & Packaging" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Build Windows Release
Write-Host "`n[1/3] Building Flutter Windows Release..." -ForegroundColor Green
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter build failed."
    exit 1
}

# 2. Inno Setup Compiler
Write-Host "`n[2/3] Compiling Inno Setup Installer..." -ForegroundColor Green
$isccPath = "C:\Users\dienmoc\AppData\Local\Programs\InnoSetup\ISCC.exe"
if (-not (Test-Path $isccPath)) {
    $isccPath = (Get-Command ISCC.exe -ErrorAction SilentlyContinue)?.Source
}
if (-not $isccPath -or -not (Test-Path $isccPath)) {
    Write-Error "Inno Setup compiler (ISCC.exe) not found."
    exit 1
}

& $isccPath "installer\setup.iss"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Inno Setup compilation failed."
    exit 1
}

# 3. Package Portable & Copy to 'đóng gói tool'
Write-Host "`n[3/3] Packaging Portable ZIP & Generating Hashes..." -ForegroundColor Green
& powershell -ExecutionPolicy Bypass -File "tool\package_portable.ps1"

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "  Packaging complete! Artifacts are available in:" -ForegroundColor Green
Write-Host "  $(Resolve-Path 'đóng gói tool')" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Cyan
