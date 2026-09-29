@echo off
setlocal
echo ========================================================
echo   Nguyen Du Tool - VietOCR 6.21.0 Launcher
echo   Offline Vietnamese Optical Character Recognition Engine
echo ========================================================
echo.

set "VIETOCR_DIR=%~dp0VietOCR\VietOCR3"
if not exist "%VIETOCR_DIR%\VietOCR.jar" (
    echo Error: VietOCR.jar not found at %VIETOCR_DIR%
    pause
    exit /b 1
)

cd /d "%VIETOCR_DIR%"
start "" javaw -Xms128m -Xmx2048m -jar VietOCR.jar
echo VietOCR has been started. You can now recognize scanned Vietnamese documents.
