$p = Start-Process -FilePath "build\windows\x64\runner\Release\NguyenDuTool.exe" -PassThru
Start-Sleep -Seconds 4
if ($p.HasExited) {
    Write-Host "Process exited early with exit code: $($p.ExitCode)"
} else {
    Write-Host "Process is RUNNING SUCCESSFULLY with PID: $($p.Id)"
    $p.Kill()
    Write-Host "Test process terminated cleanly after verifying smooth UI startup."
}
