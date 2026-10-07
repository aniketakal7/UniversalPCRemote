@echo off
echo ========================================================
echo   Publishing Universal PC Remote Companion (Release)
echo ========================================================
echo.
cd /d "%~dp0\..\windows_companion"
dotnet publish UniversalPCRemote.Companion.csproj -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true -o "%~dp0\..\dist\windows"
echo.
echo Published companion executable to dist\windows\UniversalPCRemote.Companion.exe
pause
