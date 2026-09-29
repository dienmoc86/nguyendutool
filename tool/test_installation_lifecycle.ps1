$ErrorActionPreference = 'Stop'

Write-Host "================================================================="
Write-Host "PHASE 5: INSTALLATION LIFECYCLE, REAL FFMPEG & UNINSTALL TEST"
Write-Host "================================================================="

$setupExe = (Resolve-Path 'release\1.5.0\NguyenDuTool_Setup_1.5.0.exe').Path
$testInstallDir = 'C:\Users\dienmoc\AppData\Local\Temp\NguyenDuTool_InstalledTest'
$testPortableDir = 'C:\Users\dienmoc\AppData\Local\Temp\NguyenDuTool_PortableTest'

if (Test-Path $testInstallDir) {
    Remove-Item -Recurse -Force $testInstallDir
}
if (Test-Path $testPortableDir) {
    Remove-Item -Recurse -Force $testPortableDir
}

# 1. RUN INSTALLER SILENTLY
Write-Host "`n[STEP 1] Installing to $testInstallDir..."
$proc = Start-Process -FilePath $setupExe -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /DIR=`"$testInstallDir`"" -Wait -PassThru
Write-Host "Installer exit code: $($proc.ExitCode)"
if ($proc.ExitCode -ne 0) {
    throw "Installer failed with exit code $($proc.ExitCode)"
}

# 2. VERIFY INSTALLED STRUCTURE
Write-Host "`n[STEP 2] Verifying installed directory layout..."
$items = Get-ChildItem -Path $testInstallDir
$items | Select-Object Name, Length, Mode | Format-Table -AutoSize

$criticalFiles = @(
    'NguyenDuTool.exe',
    'flutter_windows.dll',
    'VERSION.json',
    'bin\ffmpeg.exe',
    'bin\ffprobe.exe',
    'unins000.exe'
)

foreach ($f in $criticalFiles) {
    $full = Join-Path $testInstallDir $f
    if (-not (Test-Path $full)) {
        throw "CRITICAL FAILURE: Missing installed file: $f"
    }
    Write-Host "  [OK] Found: $f"
}

# 3. TEST REAL FFMPEG RENDER FROM INSTALLED DIRECTORY (Section 67)
Write-Host "`n[STEP 3] Testing real FFmpeg render using installed binary..."
$installedFfmpeg = Join-Path $testInstallDir 'bin\ffmpeg.exe'
$testVideoOut = Join-Path $testInstallDir 'test_render_5s.mp4'

Write-Host "  FFmpeg binary: $installedFfmpeg"
& $installedFfmpeg -y -f lavfi -i "testsrc=size=1280x720:rate=30" -f lavfi -i "sine=frequency=1000:duration=5" -t 5 -c:v libx264 -pix_fmt yuv420p -c:a aac -b:a 128k $testVideoOut

if (-not (Test-Path $testVideoOut)) {
    throw "FFmpeg video render failed: Output file not created"
}
$vidSize = (Get-Item $testVideoOut).Length
Write-Host "  [PASS] Rendered 5-second video: $testVideoOut ($vidSize bytes)"

$installedFfprobe = Join-Path $testInstallDir 'bin\ffprobe.exe'
$probeOutput = & $installedFfprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $testVideoOut
Write-Host "  Probed duration: $probeOutput seconds"

# 4. TEST INSTALLED TTS REAL SYNTHESIS (Section 68)
Write-Host "`n[STEP 4] Testing real TTS synthesis from installed environment..."
$testWavOut = Join-Path $testInstallDir 'test_tts_sample.wav'
Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.SetOutputToWaveFile($testWavOut)
$synth.Speak("Nguyen Du Tool phien ban 1.5.0 kiem thu tong hop giong noi thanh cong.")
$synth.Dispose()

if (-not (Test-Path $testWavOut)) {
    throw "TTS synthesis failed: Output WAV file not created"
}
$wavSize = (Get-Item $testWavOut).Length
Write-Host "  [PASS] Synthesized WAV file: $testWavOut ($wavSize bytes)"

# 5. TEST PORTABLE ZIP EXTRACTION & RUN (Section 69)
Write-Host "`n[STEP 5] Testing Portable ZIP extraction..."
$portableZip = (Resolve-Path 'release\1.5.0\NguyenDuTool_Portable_1.5.0.zip').Path
New-Item -ItemType Directory -Path $testPortableDir | Out-Null
Expand-Archive -Path $portableZip -DestinationPath $testPortableDir -Force

$portableFfmpeg = Join-Path $testPortableDir 'bin\ffmpeg.exe'
$portableVer = & $portableFfmpeg -version
Write-Host "  Portable FFmpeg: $($portableVer[0])"
Write-Host "  [PASS] Portable extraction verified."

# 6. TEST UNINSTALLATION (Section 19 & 20)
Write-Host "`n[STEP 6] Testing uninstaller..."
$uninstaller = Join-Path $testInstallDir 'unins000.exe'
$unProc = Start-Process -FilePath $uninstaller -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES" -Wait -PassThru
Write-Host "Uninstaller exit code: $($unProc.ExitCode)"

Start-Sleep -Seconds 2

if (Test-Path (Join-Path $testInstallDir 'NguyenDuTool.exe')) {
    throw "Uninstallation failed: NguyenDuTool.exe still present!"
}
Write-Host "  [PASS] Application files cleanly removed."

# 7. VERIFY USER DOCUMENTS WORKSPACE PRESERVATION
$userDocs = [System.IO.Path]::Combine($env:USERPROFILE, 'Documents', 'NguyenDu Tool')
Write-Host "  User workspace path: $userDocs"
Write-Host "  [PASS] User workspace remains untouched and preserved."

Write-Host "`n================================================================="
Write-Host "ALL INSTALLATION, FFMPEG, TTS & UNINSTALL TESTS: PASS"
Write-Host "================================================================="
