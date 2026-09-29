$ErrorActionPreference = 'Stop'

$releaseDir = "release\1.5.1"
if (-not (Test-Path $releaseDir)) {
    New-Item -ItemType Directory -Path $releaseDir | Out-Null
}

$staging = "build\portable_staging"
if (Test-Path $staging) {
    Remove-Item -Recurse -Force $staging
}
New-Item -ItemType Directory -Path $staging | Out-Null

Write-Host "Copying Release build artifacts to staging..."
Copy-Item -Recurse "build\windows\x64\runner\Release\*" $staging
Copy-Item "VERSION.json" $staging
if (Test-Path "licenses") {
    Copy-Item -Recurse "licenses" $staging
}

$zipTarget = "$releaseDir\NguyenDuTool_Portable_1.5.1.zip"
if (Test-Path $zipTarget) {
    Remove-Item -Force $zipTarget
}

Write-Host "Creating Portable ZIP: $zipTarget..."
Compress-Archive -Path "$staging\*" -DestinationPath $zipTarget -CompressionLevel Optimal
Remove-Item -Recurse -Force $staging

Write-Host "Portable ZIP created successfully."
$zipItem = Get-Item $zipTarget
Write-Host "Portable ZIP Size: $($zipItem.Length) bytes"

Write-Host "`nComputing SHA-256 for release artifacts..."
$setupExe = "$releaseDir\NguyenDuTool_Setup_1.5.1.exe"
$setupHash = (Get-FileHash -Algorithm SHA256 $setupExe).Hash
$portableHash = (Get-FileHash -Algorithm SHA256 $zipTarget).Hash

$setupHash | Set-Content "$setupExe.sha256"
$portableHash | Set-Content "$zipTarget.sha256"

$checksums = @"
$setupHash  NguyenDuTool_Setup_1.5.1.exe
$portableHash  NguyenDuTool_Portable_1.5.1.zip
"@

$checksums | Set-Content "$releaseDir\SHA256SUMS.txt"
Write-Host "SHA256SUMS.txt generated in $releaseDir."
Write-Host "Setup EXE: $setupHash"
Write-Host "Portable ZIP: $portableHash"
