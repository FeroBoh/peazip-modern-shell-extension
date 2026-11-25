; PeaZip Modern Shell Extension v1.2.3 minimal candidate (v1.2.2 installer baseline + English prompts)
; Independent per-user companion. Does not bundle or modify PeaZip itself.
; MSIX registration occurs in PrepareToInstall, before Inno copies its files.
#define MyName "PeaZip Modern Shell Extension - Community Companion"
#define MyVersion "1.2.3"
#define MyAppId "{{DE451A2C-E3B1-410D-AC5A-1FC0C683FA48}"
#define MsixName "PeaZip.ModernMenu.Community_1.2.3.0_x64.msix"
; Build-Inno.ps1 injects these two SHA-256 pins into the compiled EXE.
; They are NEVER read from the certificate or MSIX at installation time.
#ifndef ExpectedCertSha256
  #error ExpectedCertSha256 not supplied: compile using tools\Build-Inno.ps1
#endif
#ifndef ExpectedMsixSha256
  #error ExpectedMsixSha256 not supplied: compile using tools\Build-Inno.ps1
#endif

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
OutputBaseFilename=PeaZip-ModernMenu-Setup-v1.2.3
CloseApplications=yes
RestartApplications=no
ChangesAssociations=yes

[Files]
; PrepareToInstall: register MSIX before installing the EXE/shortcuts/uninstaller.
; Separate temporary destination names prevent an ambiguous extraction.
Source: "..\out\{#MsixName}"; DestName: "Preinstall-Companion.msix"; Flags: dontcopy noencryption
Source: "..\out\stage\AppxManifest.xml"; DestName: "Preinstall-AppxManifest.xml"; Flags: dontcopy noencryption
Source: "..\tools\Install-Companion.ps1"; DestName: "Preinstall-Companion.ps1"; Flags: dontcopy noencryption
Source: "..\tools\Trust-CompanionCertificate.ps1"; DestName: "Preinstall-Trust.ps1"; Flags: dontcopy noencryption
Source: "..\out\PeaZipModernMenuCommunity.cer"; DestName: "Preinstall-Community.cer"; Flags: dontcopy noencryption
; Persist normal installer assets only AFTER MSIX registration succeeds.
Source: "..\out\{#MsixName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\out\stage\AppxManifest.xml"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\out\stage\PeaZipMenuConfig.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\tools\Install-Companion.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\tools\Uninstall-Companion.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\tools\Trust-CompanionCertificate.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\out\PeaZipModernMenuCommunity.cer"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{userprograms}\PeaZip Modern Menu\Configure menu"; Filename: "{app}\PeaZipMenuConfig.exe"; Comment: "Show, hide, and reorder PeaZip menu commands"
Name: "{userprograms}\PeaZip Modern Menu\Uninstall"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\PeaZipMenuConfig.exe"; Description: "Configure PeaZip context menu"; Flags: nowait postinstall skipifsilent

[Code]
var
  CertPage: TWizardPage;
  ConsentBox: TNewCheckBox;
  ConsentExitApproved: Boolean;

procedure InitializeWizard();
var
  Info: TNewStaticText;
begin
  CertPage := CreateCustomPage(wpSelectDir, 'Community signing certificate',
    'Explicit consent is required before installing this unsigned-publisher community companion.');
  Info := TNewStaticText.Create(CertPage);
  Info.Parent := CertPage.Surface;
  Info.Left := 0;
  Info.Top := ScaleY(5);
  Info.Width := CertPage.SurfaceWidth;
  Info.Height := ScaleY(160);
  Info.AutoSize := False;
  Info.WordWrap := True;
  Info.Caption := 'This unsigned-publisher installer includes a signed MSIX and its PUBLIC, self-signed code-signing certificate.' + #13#10 +
    'With your consent and separate administrator UAC approval, only this certificate will be trusted in LocalMachine\TrustedPeople (NOT Trusted Root).' + #13#10 +
    'Trust may also apply to OTHER packages signed with this same key. No private key is distributed.' + #13#10 +
    'The installer verifies the exact SHA-256 fingerprint pinned at build time BEFORE import.' + #13#10 +
    'Certificate SHA-256: {#ExpectedCertSha256}';
  ConsentBox := TNewCheckBox.Create(CertPage);
  ConsentBox.Parent := CertPage.Surface;
  ConsentBox.Left := 0;
  ConsentBox.Top := ScaleY(172);
  ConsentBox.Width := CertPage.SurfaceWidth;
  ConsentBox.Caption := 'I understand and consent to trusting this community certificate if needed';
  ConsentBox.Checked := False;
end;

// Inno Setup: returning False from NextButtonClick only blocks the page transition.
// Exit is user-confirmed and routed through the normal Cancel workflow.
// Override the normal wizard Cancel / window-close confirmation: native
// Windows MessageBox labels are localized to the OS language (e.g. Ano/Nie).
// TaskDialogMsgBox uses our explicit English labels on supported Windows 11.
procedure CancelButtonClick(CurPageID: Integer; var Cancel, Confirm: Boolean);
begin
  Confirm := False; // Never show the OS-localized built-in Exit Setup question.
  if ConsentExitApproved then
  begin
    Cancel := True; // NextButtonClick already received explicit consent to exit.
    exit;
  end;
  Cancel := (TaskDialogMsgBox('Exit Setup?',
      'Do you want to cancel installation and exit Setup?',
      mbConfirmation, MB_YESNO, ['Yes', 'No'], 0) = IDYES);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if (CurPageID = CertPage.ID) and (not ConsentBox.Checked) then
  begin
    Result := False;
    if TaskDialogMsgBox(
      'Community certificate consent required',
      'You have not agreed to trust the community signing certificate.' + #13#10 +
      'Without your consent, this extension cannot be installed.' + #13#10 + #13#10 +
      'Do you want to exit Setup now?',
      mbConfirmation, MB_YESNO, ['Yes', 'No'], 0) = IDYES then
    begin
      ConsentExitApproved := True;
      WizardForm.Close;
    end;
  end;
end;

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
    ExtractTemporaryFile('Preinstall-Trust.ps1');
    ExtractTemporaryFile('Preinstall-Community.cer');
  except
    Result := 'Could not extract the MSIX installation prerequisites: ' +
      GetExceptionMessage;
    exit;
  end;
  if not RunPS(TempDir + 'Preinstall-Companion.ps1',
               TempDir + 'Preinstall-AppxManifest.xml',
               TempDir + 'Preinstall-Companion.msix',
               ' -CertificatePath "' + TempDir + 'Preinstall-Community.cer" -TrustHelperPath "' + TempDir + 'Preinstall-Trust.ps1"' +
               ' -ExpectedCertSha256 "{#ExpectedCertSha256}" -ExpectedMsixSha256 "{#ExpectedMsixSha256}" -AllowTrustImport') then
  begin
    Result := 'MSIX installation or update failed. No companion files have been installed by this setup attempt.' + #13#10 +
      'Windows could not deploy the MSIX. Check the deployment log for AppX volume and error details.' + #13#10 +
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
       (TaskDialogMsgBox('Remove saved preferences?',
               'Also delete your PeaZip Modern Menu preferences and command order?' + #13#10 +
               'Choose No to preserve them for a later reinstall.',
               mbConfirmation, MB_YESNO, ['Yes', 'No'], 0) = IDYES) then
      Extra := ' -RemoveSettings';
    if (not UninstallSilent) and
       (TaskDialogMsgBox('Remove community certificate trust?',
               'Remove this companion installer-managed community certificate from Windows TrustedPeople, if no other user requires it?' + #13#10 +
               'A Windows administrator UAC prompt may be shown. Certificates not imported by this installer will not be removed.',
               mbConfirmation, MB_YESNO, ['Yes', 'No'], 0) = IDYES) then
      Extra := Extra + ' -RemoveTrust';
    Extra := Extra + ' -CertificatePath "' + ExpandConstant('{app}\PeaZipModernMenuCommunity.cer') +
      '" -TrustHelperPath "' + ExpandConstant('{app}\Trust-CompanionCertificate.ps1') +
      '" -ExpectedCertSha256 "{#ExpectedCertSha256}"';
    if not RunPS(ExpandConstant('{app}\Uninstall-Companion.ps1'),
                 ExpandConstant('{app}\AppxManifest.xml'), '', Extra) then
    begin
      TaskDialogMsgBox('Unable to remove companion MSIX',
             'The companion MSIX could not be removed. The uninstaller will stop to avoid leaving a registered extension without its management files.' + #13#10 +
             'Please close Explorer windows or sign out and try again.' + #13#10 +
             'See ' + GetEnv('TEMP') + '\PeaZipModernMenu-Uninstall.log',
             mbError, MB_OK, ['OK'], 0);
      Abort; // documented to abort Uninstall when called from usUninstall
    end;
  end;
end;
