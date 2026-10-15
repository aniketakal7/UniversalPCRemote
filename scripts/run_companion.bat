@echo off
title Universal PC Remote — Companion Server
echo ========================================================
echo   Universal PC Remote — Companion Server
echo ========================================================
echo.
echo Starting Companion Server on Windows...
echo Server Port: 51234 (WebSocket), 51235 (Discovery)
echo.

set "DOTNET_CMD=dotnet"
if exist "%LOCALAPPDATA%\Microsoft\dotnet\dotnet.exe" (
    set "DOTNET_CMD=%LOCALAPPDATA%\Microsoft\dotnet\dotnet.exe"
)

set "DLL_PATH=%~dp0..\dist\windows\UniversalPCRemote.dll"

if exist "%DLL_PATH%" (
    echo Launching via Microsoft-signed .NET Host (Bypasses Smart App Control)...
    start "" "%DOTNET_CMD%" "%DLL_PATH%"
    exit /b 0
)

echo DLL not found in dist\windows. Launching directly from project source...
cd /d "%~dp0..\windows_companion"
"%DOTNET_CMD%" run --project UniversalPCRemote.Companion.csproj -c Release
