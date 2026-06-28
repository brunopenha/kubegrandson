; ============================================================
;  Kubegrandson – Inno Setup Installer Script
;  https://jrsoftware.org/isinfo.php
;
;  Prerequisites
;    1. Build the Flutter Windows release first:
;         flutter build windows --release
;    2. Compile this script with Inno Setup 6+:
;         iscc windows\kubegrandson_setup.iss
;       or open it in the Inno Setup IDE and press Ctrl+F9.
;
;  Output: build\windows\installer\kubegrandson_setup.exe
; ============================================================

#define MyAppName      "Kubegrandson"
#define MyAppVersion   "0.7.1"
#define MyAppPublisher "Bruno Penha"
#define MyAppURL       "https://github.com/brunopenha/kubegrandson"
#define MyAppExeName   "kubegrandson.exe"
#define MyAppIcoName   "Kubegrandson.ico"

; ---- Paths relative to this .iss file (windows\) -----------
#define SrcBuildDir    "..\build\windows\x64\runner\Release"
#define SrcIconFile    "..\assets\icons\" + MyAppIcoName
; WizardSmallImageFile must be BMP or PNG – ICO is NOT accepted here.
#define SrcWizardImg   "..\assets\icons\Kubegrandson_64.png"

[Setup]
; A unique GUID for this application – regenerate with Tools > Generate GUID if you fork.
AppId={{A3F2E1D0-7B4C-4F9A-8E6D-1C2B3A4D5E6F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Default installation folder
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; Installer/uninstaller icons
SetupIconFile={#SrcIconFile}
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

; Output
OutputDir=..\build\windows\installer
; kubegrandson_v0.7.1_amd64_windows.exe
OutputBaseFilename=kubegrandson_v{#MyAppVersion}_amd64_windows

; Compression
Compression=lzma2/ultra64
SolidCompression=yes

; Wizard appearance
WizardStyle=modern
; Must be BMP or PNG (not ICO) – use the 64×64 PNG asset.
WizardSmallImageFile={#SrcWizardImg}

; Minimum Windows version: Windows 10
MinVersion=10.0

; Run at the lowest privilege level that works:
;   - Launched as admin  → installs to C:\Program Files\Kubegrandson\
;   - Launched as normal user → installs to %LOCALAPPDATA%\Programs\Kubegrandson\
; This avoids all mid-wizard privilege switching (ShellExecuteEx de-elevation)
; that causes "CallSpawnServer" and "ShellExecuteEx hProcess=0" errors.
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; \
  Description: "{cm:CreateDesktopIcon}"; \
  GroupDescription: "{cm:AdditionalIcons}"; \
  Flags: unchecked

[Files]
; Flutter release bundle – all files and sub-folders (data/, flutter_assets/, etc.)
Source: "{#SrcBuildDir}\*"; \
  DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Start Menu shortcut
Name: "{group}\{#MyAppName}"; \
  Filename: "{app}\{#MyAppExeName}"

; Start Menu – Uninstall shortcut
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; \
  Filename: "{uninstallexe}"

; Desktop shortcut (optional – only created when the task is selected)
Name: "{autodesktop}\{#MyAppName}"; \
  Filename: "{app}\{#MyAppExeName}"; \
  Tasks: desktopicon

[Run]
; Offer to launch the app immediately after installation.
; * shellexec  – uses ShellExecuteEx (avoids the spawn-server de-elevation
;                path that causes "CallSpawnServer: Unexpected response: $0"
;                when the installer ran elevated).
; * WorkingDir – ensures flutter_windows.dll and sibling DLLs are found.
Filename: "{app}\{#MyAppExeName}"; \
  WorkingDir: "{app}"; \
  Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; \
  Flags: shellexec nowait postinstall skipifsilent

; ============================================================
;  Uninstall
; ============================================================

[UninstallDelete]
; Remove runtime data written by the app itself.
; Flutter's path_provider (getApplicationSupportDirectory) and
; shared_preferences put data under %LOCALAPPDATA%\<app>.
Type: filesandordirs; Name: "{localappdata}\{#MyAppName}"
; flutter_secure_storage may also write to the roaming profile.
Type: filesandordirs; Name: "{userappdata}\{#MyAppName}"

[Code]
// ----------------------------------------------------------
//  Uninstall – optional user-data removal
//
//  When the user runs the uninstaller they are asked whether
//  they also want to wipe their personal app data (settings,
//  kubeconfig cache, stored credentials, etc.).
//  Choosing "No" keeps the data so a reinstall can pick it up.
// ----------------------------------------------------------

var
  RemoveUserData: Boolean;

// Called once before the uninstall wizard starts.
function InitializeUninstall(): Boolean;
var
  Answer: Integer;
begin
  Result := True; // always allow the uninstall to proceed

  Answer := MsgBox(
    'Do you also want to remove all Kubegrandson user data?' + #13#10 +
    '(saved settings, kubeconfig cache and stored credentials)' + #13#10 +
    'Click Yes to delete all data, or No to keep it for a future reinstall.',
    mbConfirmation,
    MB_YESNO or MB_DEFBUTTON2   // "No" is the safe default
  );

  RemoveUserData := (Answer = IDYES);
end;

// Called at each step of the uninstall process.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  // usPostUninstall fires after the files have been removed.
  if (CurUninstallStep = usPostUninstall) and RemoveUserData then
  begin
    // Delete %LOCALAPPDATA%\Kubegrandson  (Flutter app-support dir)
    DelTree(ExpandConstant('{localappdata}\{#MyAppName}'), True, True, True);
    // Delete %APPDATA%\Kubegrandson  (roaming profile, flutter_secure_storage)
    DelTree(ExpandConstant('{userappdata}\{#MyAppName}'), True, True, True);
  end;
end;
