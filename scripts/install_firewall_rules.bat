@echo off
echo ========================================================
echo   Configuring Windows Defender Firewall for Universal PC Remote
echo ========================================================
echo.
echo Please run this script as Administrator if prompted.
echo.

netsh advfirewall firewall add rule name="Universal PC Remote WebSocket" dir=in action=allow protocol=TCP localport=51234
netsh advfirewall firewall add rule name="Universal PC Remote Discovery" dir=in action=allow protocol=UDP localport=51235

echo.
echo Firewall rules added successfully!
echo Inbound TCP 51234 and UDP 51235 are now allowed.
pause
