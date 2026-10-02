$releaseDir = (Resolve-Path "build\windows\x64\runner\Release").Path
$exePath = Join-Path $releaseDir "NguyenDuTool.exe"

Write-Host "Launching NguyenDu Tool from: $exePath"
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exePath
$psi.WorkingDirectory = $releaseDir
$psi.UseShellExecute = $true

$proc = [System.Diagnostics.Process]::Start($psi)
Start-Sleep -Seconds 3

if ($proc.HasExited) {
    Write-Warning "Process exited with code: $($proc.ExitCode)"
    
    $logsDir = Join-Path $env:USERPROFILE 'Documents\NguyenDu Tool\logs'
    if (Test-Path $logsDir) {
        Write-Host "Recent logs from $($logsDir):"
        Get-ChildItem $logsDir | Sort-Object LastWriteTime -Descending | Select-Object -First 2 | ForEach-Object {
            Write-Host "=== FILE: $($_.FullName) ==="
            Get-Content $_.FullName -Tail 40
        }
    }
} else {
    Write-Host "Process is RUNNING! PID: $($proc.Id), Window: $($proc.MainWindowTitle)"
}
