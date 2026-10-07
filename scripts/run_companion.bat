@echo off
echo ========================================================
echo   Universal PC Remote — Companion Server
echo ========================================================
echo.
cd /d "%~dp0\..\windows_companion"
dotnet run -c Release --project UniversalPCRemote.Companion.csproj
pause
