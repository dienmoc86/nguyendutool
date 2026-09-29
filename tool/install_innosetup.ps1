$installer = "C:\Users\dienmoc\AppData\Local\Temp\WinGet\JRSoftware.InnoSetup.6.7.3\innosetup-6.7.3.exe"
$destDir = "C:\Users\dienmoc\AppData\Local\Programs\InnoSetup"

if (-not (Test-Path $installer)) {
    Write-Host "Installer not found at $installer"
    exit 1
}

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $installer
$psi.Arguments = "/DIR=""$destDir"" /PORTABLE=1 /CURRENTUSER /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-"
$psi.EnvironmentVariables["__COMPAT_LAYER"] = "RunAsInvoker"
$psi.UseShellExecute = $false

$p = [System.Diagnostics.Process]::Start($psi)
$p.WaitForExit()
Write-Host "Inno Setup ExitCode: $($p.ExitCode)"

if (Test-Path "$destDir\ISCC.exe") {
    Write-Host "SUCCESS: ISCC.exe is ready at $destDir\ISCC.exe"
} else {
    Write-Host "ISCC.exe not found at $destDir\ISCC.exe"
}
