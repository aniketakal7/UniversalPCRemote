@echo off
title Universal PC Remote - Web Download Host
cd /d "%~dp0website"
python serve.py
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Python failed or was not found. Trying standard python3...
    python3 serve.py
)
pause
