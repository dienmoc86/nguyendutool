; Inno Setup Script for NguyenDu Tool v1.5.1
; Production Remediation & Release Candidate Gate (Phase 5R)

#define MyAppName "NguyenDu Tool"
#define MyAppVersion "1.5.1"
#define MyAppPublisher "iBest Group"
#define MyAppExeName "NguyenDuTool.exe"

[Setup]
; Unique AppId for upgrade detection
AppId={{C73E4A28-09F2-4DE6-8DF3-B8B79B5A81A9}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
; Per-user installation by default (%LOCALAPPDATA%\Programs\NguyenDu Tool\)
DefaultDirName={localappdata}\Programs\NguyenDu Tool
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; Per-user privileges (does not require Administrator UAC by default)
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline dialog
OutputDir=..\release\1.5.1
OutputBaseFilename=NguyenDuTool_Setup_1.5.1
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
VersionInfoVersion=1.5.1.8
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=NguyenDu Tool Desktop Application by iBest Group
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion=1.5.1

[Languages]
Name: "vi"; MessagesFile: "Vietnamese.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Release application binaries and flutter dependencies
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Licenses directory
Source: "..\licenses\*"; DestDir: "{app}\licenses"; Flags: ignoreversion recursesubdirs createallsubdirs
; Version metadata
Source: "..\VERSION.json"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Clean up runtime caches and temporary logs on uninstall while preserving user documents
Type: filesandordirs; Name: "{localappdata}\NguyenDu Tool\temp"
Type: filesandordirs; Name: "{localappdata}\NguyenDu Tool\cache"
