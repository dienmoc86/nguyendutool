$ErrorActionPreference = 'Stop'

$versionData = Get-Content "VERSION.json" -Raw | ConvertFrom-Json
$appVersion = $versionData.version
$releaseDir = "release\$appVersion"
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
if (Test-Path "bin") {
    $targetBin = Join-Path $staging "bin"
    if (-not (Test-Path $targetBin)) {
        New-Item -ItemType Directory -Path $targetBin | Out-Null
    }
    Copy-Item -Recurse -Force "bin\*" $targetBin
}
if (Test-Path "licenses") {
    $targetLic = Join-Path $staging "licenses"
    if (-not (Test-Path $targetLic)) {
        New-Item -ItemType Directory -Path $targetLic | Out-Null
    }
    Copy-Item -Recurse -Force "licenses\*" $targetLic
}

$zipTarget = "$releaseDir\NguyenDuTool_Portable_$appVersion.zip"
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
$setupExe = "$releaseDir\NguyenDuTool_Setup_$appVersion.exe"
if (-not (Test-Path $setupExe)) {
    Write-Warning "Setup EXE not found at $setupExe"
    $setupHash = "NOT_FOUND"
} else {
    $setupHash = (Get-FileHash -Algorithm SHA256 $setupExe).Hash
    $setupHash | Set-Content "$setupExe.sha256"
    Write-Host "Setup EXE: $setupHash"
}

$portableHash = (Get-FileHash -Algorithm SHA256 $zipTarget).Hash
$portableHash | Set-Content "$zipTarget.sha256"
Write-Host "Portable ZIP: $portableHash"

$checksums = @"
$setupHash  NguyenDuTool_Setup_$appVersion.exe
$portableHash  NguyenDuTool_Portable_$appVersion.zip
"@

$checksums | Set-Content "$releaseDir\SHA256SUMS.txt"
Write-Host "SHA256SUMS.txt generated in $releaseDir."

# Update RELEASE_MANIFEST.json with newly calculated hashes
$manifestPath = "RELEASE_MANIFEST.json"
if (Test-Path $manifestPath) {
    $manifestJson = Get-Content $manifestPath -Raw | ConvertFrom-Json
    $manifestJson.sha256 = $setupHash
    $manifestJson.installerSha256 = $setupHash
    $manifestJson.portableSha256 = $portableHash
    $manifestJson | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding utf8
    $manifestJson | ConvertTo-Json -Depth 10 | Set-Content "$releaseDir\RELEASE_MANIFEST.json" -Encoding utf8
    Write-Host "RELEASE_MANIFEST.json updated with new SHA256 hashes."
}

# Copy to user's designated packaging directory: "đóng gói tool"
Write-Host "`nCopying artifacts to 'đóng gói tool'..."
python "tool\copy_to_package_dir.py"
Write-Host "Files successfully copied to 'đóng gói tool'."
