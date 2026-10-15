@echo off
title Universal PC Remote — Firewall Setup
echo ========================================================
echo   Configuring Windows Defender Firewall for Universal PC Remote
echo ========================================================
echo.

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Administrator privileges required. Prompting for elevation...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [*] Adding Inbound TCP Rule for Port 51234 (WebSocket Commands)...
netsh advfirewall firewall add rule name="Universal PC Remote (TCP 51234)" dir=in action=allow protocol=TCP localport=51234 profile=any

echo [*] Adding Inbound UDP Rule for Port 51235 (Discovery Beacon)...
netsh advfirewall firewall add rule name="Universal PC Remote (UDP 51235)" dir=in action=allow protocol=UDP localport=51235 profile=any

set "COMPANION_EXE=%~dp0..\dist\windows\UniversalPCRemote.exe"
if exist "%COMPANION_EXE%" (
    echo [*] Adding Application Firewall Exemption...
    netsh advfirewall firewall add rule name="Universal PC Remote Companion App" dir=in action=allow program="%COMPANION_EXE%" enable=yes profile=any
)

echo.
echo ========================================================
echo   [SUCCESS] Windows Firewall is configured for Universal PC Remote!
echo ========================================================
echo.
pause
