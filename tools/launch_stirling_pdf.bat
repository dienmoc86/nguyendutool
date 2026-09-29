@echo off
setlocal
echo ========================================================
echo   Nguyen Du Tool - Stirling-PDF Launcher
echo   All-in-One PDF & Office Conversion Web Suite
echo ========================================================
echo.

set "STIRLING_DIR=%~dp0Stirling-PDF"
set "JAR_PATH=%STIRLING_DIR%\Stirling-PDF.jar"

if not exist "%JAR_PATH%" (
    echo Stirling-PDF.jar is still downloading or not found at:
    echo %JAR_PATH%
    pause
    exit /b 1
)

echo Starting Stirling-PDF Server on port 8080...
echo Once started, your default browser will open http://localhost:8080
echo To stop Stirling-PDF, close this window.
echo.

start "" http://localhost:8080
java -Dserver.port=8080 -jar "%JAR_PATH%"
pause
