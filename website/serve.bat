@echo off
title Universal PC Remote - Download Host
cd /d "%~dp0"
python serve.py
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Python was not found or failed. Trying standard python3...
    python3 serve.py
)
pause
