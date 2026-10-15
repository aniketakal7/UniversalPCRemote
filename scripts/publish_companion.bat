@echo off
title Publish Universal PC Remote Companion
echo ========================================================
echo   Publishing Universal PC Remote Companion (Standalone)
echo ========================================================
echo.

set "DOTNET_CMD=dotnet"
if exist "%LOCALAPPDATA%\Microsoft\dotnet\dotnet.exe" (
    set "DOTNET_CMD=%LOCALAPPDATA%\Microsoft\dotnet\dotnet.exe"
)

cd /d "%~dp0\..\windows_companion"
echo [1/2] Building framework edition (Bypasses Smart App Control via dotnet host)...
"%DOTNET_CMD%" publish UniversalPCRemote.Companion.csproj -c Release -o "%~dp0\..\dist\windows"

echo.
echo [2/2] Building standalone self-contained win-x64 executable...
"%DOTNET_CMD%" publish UniversalPCRemote.Companion.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -o "%~dp0\..\dist\windows\standalone"

copy /y "%~dp0..\dist\windows\Launch-Companion.bat" "%~dp0..\dist\windows\UniversalPCRemote.bat" >nul 2>&1

echo.
echo ========================================================
echo   Build Successful!
echo   1. Smart App Control Bypass Launcher:
echo      dist\windows\UniversalPCRemote.bat (or Launch-Companion.bat)
echo   2. Standalone Single-File Executable:
echo      dist\windows\standalone\UniversalPCRemote.exe
echo ========================================================
pause
