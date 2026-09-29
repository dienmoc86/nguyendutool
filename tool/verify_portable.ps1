$ErrorActionPreference = 'Stop'

$testDir = "build\portable_test_run"
if (Test-Path $testDir) {
    Remove-Item -Recurse -Force $testDir
}
New-Item -ItemType Directory -Path $testDir | Out-Null

Write-Host "Extracting portable package to $testDir..."
Expand-Archive -Path "release\1.5.1\NguyenDuTool_Portable_1.5.1.zip" -DestinationPath $testDir

Write-Host "Running portable self-test..."
$proc = Start-Process -FilePath "$testDir\NguyenDuTool.exe" -ArgumentList "--self-test" -Wait -PassThru -NoNewWindow
$exitCode = $proc.ExitCode
Write-Host "Portable self-test exit code: $exitCode"

if (Test-Path "SELF_TEST_RESULT.json") {
    $res = Get-Content "SELF_TEST_RESULT.json" -Raw | ConvertFrom-Json
    Write-Host "Self-Test Status: $($res.overallStatus)"
    Write-Host "Duration: $($res.totalDurationMs) ms"
    foreach ($chk in $res.checks) {
        Write-Host "  [$($chk.status)] $($chk.name): $($chk.details)"
    }
}

Remove-Item -Recurse -Force $testDir
Write-Host "Portable test complete and temporary directory cleaned up."
