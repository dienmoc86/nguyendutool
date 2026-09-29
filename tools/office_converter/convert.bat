@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
if "%~1"=="" (
    echo Nguyen Du Tool - Universal Document Converter
    echo Usage:
    echo   convert.bat input.pdf [docx^|xlsx^|pptx]
    echo   convert.bat input.docx [pdf]
    echo   convert.bat input.xlsx [pdf]
    echo   convert.bat input.pptx [pdf]
    echo.
    echo Or simply drag and drop a file onto this bat file!
    pause
    exit /b 1
)

python "%SCRIPT_DIR%converter.py" "%~1" %*
if %ERRORLEVEL% EQU 0 (
    echo.
    echo Conversion completed successfully!
) else (
    echo.
    echo Conversion encountered an error.
)
pause
