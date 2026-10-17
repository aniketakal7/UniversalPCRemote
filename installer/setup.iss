; Inno Setup Script for Universal PC Remote Companion
; Generates UniversalPCRemote-Setup.exe

#define MyAppName "Universal PC Remote™"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Aniket Akal"
#define MyAppCopyright "© 2026 Aniket Akal. All rights reserved."
#define MyAppURL "https://github.com/aniketakal7/UniversalPCRemote"
#define MyAppExeName "UniversalPCRemote.exe"

[Setup]
AppId={{9C5E487B-11E5-46D9-8F7E-971A02844DE7}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppCopyright={#MyAppCopyright}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=..\dist\installer
OutputBaseFilename=UniversalPCRemote-Setup
SetupIconFile=..\windows_companion\assets\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon"; Description: "Automatically start with Windows at sign-in"; GroupDescription: "Startup:"; Flags: unchecked

[Files]
Source: "..\dist\windows\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\windows_companion\assets\app_icon.ico"; DestDir: "{app}\assets"; Flags: ignoreversion
Source: "..\scripts\setup_firewall.bat"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\assets\app_icon.ico"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\assets\app_icon.ico"
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Parameters: "--minimized"; Tasks: startupicon; IconFilename: "{app}\assets\app_icon.ico"

[Run]
Filename: "{app}\setup_firewall.bat"; Description: "Configure Windows Firewall (Recommended)"; Flags: postinstall shellexec skipifsilent
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
