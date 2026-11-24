; PeaZip Modern Shell Extension v1.2.1 (upgrade/uninstall hardening)
; Independent per-user companion. Does not bundle or modify PeaZip itself.
; MSIX registration occurs in PrepareToInstall, before Inno copies its files.
#define MyName "PeaZip Modern Menu - Community Companion"
#define MyVersion "1.2.1"
#define MyAppId "{{DE451A2C-E3B1-410D-AC5A-1FC0C683FA48}"
#define MsixName "PeaZip.ModernMenu.Community_1.2.1.0_x64.msix"

[Setup]
AppId={#MyAppId}
AppName={#MyName}
AppVersion={#MyVersion}
AppPublisher=Independent PeaZip Community Project
DefaultDirName={localappdata}\Programs\PeaZip Modern Menu
DefaultGroupName=PeaZip Modern Menu
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64os
MinVersion=10.0.22000
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
UninstallDisplayIcon={app}\PeaZipMenuConfig.exe
OutputDir=..\out\installer
OutputBaseFilename=PeaZip-ModernMenu-Setup-v1.2.1
CloseApplications=yes
RestartApplications=no
ChangesAssociations=yes

[Files]
; PrepareToInstall: register MSIX before installing the EXE/shortcuts/uninstaller.
; Separate temporary destination names prevent an ambiguous extraction.
Source: "..\out\{#MsixName}"; DestName: "Preinstall-Companion.msix"; Flags: dontcopy noencryption
Source: "..\out\stage\AppxManifest.xml"; DestName: "Preinstall-AppxManifest.xml"; Flags: dontcopy noencryption
Source: "..\tools\Install-Companion.ps1"; DestName: "Preinstall-Companion.ps1"; Flags: dontcopy noencryption
; Persist normal installer assets only AFTER MSIX registration succeeds.
Source: "..\out\{#MsixName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\out\stage\AppxManifest.xml"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\out\stage\PeaZipMenuConfig.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\tools\Install-Companion.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\tools\Uninstall-Companion.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{userprograms}\PeaZip Modern Menu\Configure menu"; Filename: "{app}\PeaZipMenuConfig.exe"; Comment: "Show, hide, and reorder PeaZip menu commands"
Name: "{userprograms}\PeaZip Modern Menu\Uninstall"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\PeaZipMenuConfig.exe"; Description: "Configure PeaZip context menu"; Flags: nowait postinstall skipifsilent

[Code]
function RunPS(const ScriptPath, ManifestPath, PackagePath, Extra: String): Boolean;
var
  ResultCode: Integer;
  Args: String;
begin
  ResultCode := -1;
  Args := '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' +
    ScriptPath + '" -ManifestPath "' + ManifestPath + '"';
  if PackagePath <> '' then
    Args := Args + ' -PackagePath "' + PackagePath + '"';
  Args := Args + Extra;
  Result := Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    Args, ExtractFileDir(ScriptPath), SW_HIDE, ewWaitUntilTerminated, ResultCode);
  if not Result then
    Log('Could not start PowerShell for ' + ScriptPath)
  else
    Log(ScriptPath + ' exited with code ' + IntToStr(ResultCode));
  Result := Result and (ResultCode = 0);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  TempDir: String;
begin
  Result := '';
  NeedsRestart := False;
  TempDir := ExpandConstant('{tmp}\');
  try
    ExtractTemporaryFile('Preinstall-Companion.msix');
    ExtractTemporaryFile('Preinstall-AppxManifest.xml');
    ExtractTemporaryFile('Preinstall-Companion.ps1');
  except
    Result := 'Could not extract the MSIX installation prerequisites: ' +
      GetExceptionMessage;
    exit;
  end;
  if not RunPS(TempDir + 'Preinstall-Companion.ps1',
               TempDir + 'Preinstall-AppxManifest.xml',
               TempDir + 'Preinstall-Companion.msix', '') then
  begin
    Result := 'MSIX installation or update failed. No companion files have been installed by this setup attempt.' + #13#10 +
      'Windows may be using an older Explorer extension, or the MSIX signing certificate is not trusted.' + #13#10 +
      'Existing PeaZip files and the old MSIX are not deliberately removed.' + #13#10 +
      'See ' + GetEnv('TEMP') + '\PeaZipModernMenu-Install.log for details.';
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Extra: String;
begin
  if CurUninstallStep = usUninstall then
  begin
    Extra := '';
    if (not UninstallSilent) and
       (MsgBox('Also delete your PeaZip Modern Menu preferences and command order?' + #13#10 +
               'Choose No to preserve them for a later reinstall.',
               mbConfirmation, MB_YESNO) = IDYES) then
      Extra := ' -RemoveSettings';
    if not RunPS(ExpandConstant('{app}\Uninstall-Companion.ps1'),
                 ExpandConstant('{app}\AppxManifest.xml'), '', Extra) then
    begin
      MsgBox('The companion MSIX could not be removed. The uninstaller will stop to avoid leaving a registered extension without its management files.' + #13#10 +
             'Please close Explorer windows or sign out and try again.' + #13#10 +
             'See ' + GetEnv('TEMP') + '\PeaZipModernMenu-Uninstall.log',
             mbError, MB_OK);
      Abort; // documented to abort Uninstall when called from usUninstall
    end;
  end;
end;
