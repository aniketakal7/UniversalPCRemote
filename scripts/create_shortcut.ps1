$distDir = Resolve-Path (Join-Path $PSScriptRoot "..\dist\windows")
$dotnetCmd = (Get-Command dotnet).Source
$icoPath = Join-Path $distDir "assets\app_icon.ico"
$dllPath = Join-Path $distDir "UniversalPCRemote.dll"

$vbsPath = Join-Path $distDir "Launch-Silently.vbs"
$wscriptCmd = Join-Path $env:SystemRoot "System32\wscript.exe"

$wsh = New-Object -ComObject WScript.Shell

# 1. Shortcut inside dist\windows
$shortcutInDist = Join-Path $distDir "Universal PC Remote.lnk"
$s1 = $wsh.CreateShortcut($shortcutInDist)
$s1.TargetPath = $wscriptCmd
$s1.Arguments = "`"$vbsPath`""
$s1.WorkingDirectory = $distDir.Path
$s1.IconLocation = "$icoPath,0"
$s1.Description = "Universal PC Remote Companion"
$s1.Save()

# 2. Shortcut on User's Desktop
$desktopDir = [Environment]::GetFolderPath("Desktop")
$shortcutOnDesktop = Join-Path $desktopDir "Universal PC Remote.lnk"
$s2 = $wsh.CreateShortcut($shortcutOnDesktop)
$s2.TargetPath = $wscriptCmd
$s2.Arguments = "`"$vbsPath`""
$s2.WorkingDirectory = $distDir.Path
$s2.IconLocation = "$icoPath,0"
$s2.Description = "Universal PC Remote Companion"
$s2.Save()

Write-Host "Created shortcuts successfully:"
Write-Host "1. $shortcutInDist"
Write-Host "2. $shortcutOnDesktop"
