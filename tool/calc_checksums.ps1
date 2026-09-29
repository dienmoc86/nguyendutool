$files = @(
    'release\1.5.0\NguyenDuTool_Setup_1.5.0.exe',
    'release\1.5.0\NguyenDuTool_Portable_1.5.0.zip',
    'build\windows\x64\runner\Release\NguyenDuTool.exe',
    'bin\ffmpeg.exe',
    'bin\ffprobe.exe',
    'build\windows\x64\runner\Release\flutter_windows.dll'
)

$output = @()
foreach ($f in $files) {
    if (Test-Path $f) {
        $hash = (Get-FileHash -Algorithm SHA256 $f).Hash
        $line = "$hash  $f"
        Write-Host $line
        $output += $line
    } else {
        Write-Warning "File not found: $f"
    }
}

$output | Set-Content 'release\1.5.0\SHA256SUMS.txt'
$output | Set-Content 'SHA256SUMS.txt'

$setupHash = (Get-FileHash -Algorithm SHA256 'release\1.5.0\NguyenDuTool_Setup_1.5.0.exe').Hash
$setupHash | Set-Content 'release\1.5.0\NguyenDuTool_Setup_1.5.0.exe.sha256'

$portableHash = (Get-FileHash -Algorithm SHA256 'release\1.5.0\NguyenDuTool_Portable_1.5.0.zip').Hash
$portableHash | Set-Content 'release\1.5.0\NguyenDuTool_Portable_1.5.0.zip.sha256'

Write-Host "Wrote checksums to release\1.5.0\ and root."
