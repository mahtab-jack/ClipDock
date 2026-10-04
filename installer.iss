; Inno Setup Script for Clip Dock (cNote)
; Output file will be created in build\installer\ClipDock-Setup-v1.2.0.exe

#define MyAppName "Clip Dock"
#define MyAppVersion "1.2.0"
#define MyAppPublisher "Mahtab Jack"
#define MyAppURL "https://github.com/mahtab-jack"
#define MyAppExeName "cnote.exe"

[Setup]
AppId={{D37E84B1-6458-45F2-8182-3A657C6ACD1A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\ClipDock
DisableProgramGroupPage=yes
OutputDir=build\installer
OutputBaseFilename=ClipDock-Setup-v1.2.0
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Setup
VersionInfoTextVersion={#MyAppVersion}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoProductName={#MyAppName}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
CloseApplications=yes
CloseApplicationsFilter=*.exe
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce
Name: "startupicon"; Description: "Start Clip Dock when Windows starts"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueName: "ClipDock"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"""; Tasks: startupicon; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueName: "cnote"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"; ValueName: "ClipDock"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder"; ValueName: "{#MyAppName}.lnk"; Flags: uninsdeletevalue

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
Type: files; Name: "{userstartup}\{#MyAppName}.lnk"
Type: files; Name: "{userstartup}\cnote.lnk"
Type: files; Name: "{userstartup}\Clip Dock.lnk"
Type: files; Name: "{autodesktop}\{#MyAppName}.lnk"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
function InitializeUninstall(): Boolean;
var
  ErrorCode: Integer;
begin
  // Force terminate cnote.exe process tree before uninstaller starts
  Exec('taskkill.exe', '/f /im cnote.exe /t', '', SW_HIDE, ewWaitUntilTerminated, ErrorCode);
  Sleep(300);
  Result := True;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ErrorCode: Integer;
  UninstallUrl: String;
begin
  if CurUninstallStep = usUninstall then
  begin
    Exec('taskkill.exe', '/f /im cnote.exe /t', '', SW_HIDE, ewWaitUntilTerminated, ErrorCode);
    Sleep(300);
  end
  else if CurUninstallStep = usDone then
  begin
    UninstallUrl := 'https://mahtab-jack.github.io/uninstall?app=clipdock&version=' + '{#MyAppVersion}';
    ShellExec('open', UninstallUrl, '', '', SW_SHOW, ewNoWait, ErrorCode);
  end;
end;
