; deps-harness.iss -- test installer for installer\dvlce-deps.iss. It installs nothing
; but the dependencies, writes no menu keys, and has its own AppId, so a test install
; and uninstall never touch the real tool. It ignores the PATH, so it always downloads.
; Test steps: see the README section "Testing the dependency download".

#define AppGuid "00D3B5A1-7E2C-4F18-9A6B-DE9500000001"
#define NeedFFmpeg
#define NeedMagick
#define DepsTestIgnorePath
; The harness itself plus a fake tool; create HKCU\...\Uninstall\{FAKE}_is1 to test "still needed".
#define DepsTestTools "{00D3B5A1-7E2C-4F18-9A6B-DE9500000001} {00D3B5A1-7E2C-4F18-9A6B-DE9500000002}"

[Setup]
AppId={{{#AppGuid}}
AppName=DVLCE Deps Harness
AppVersion=1.0
PrivilegesRequired=lowest
DefaultDirName={localappdata}\DVLCEDepsHarness
DisableDirPage=yes
DisableProgramGroupPage=yes
OutputBaseFilename=deps-harness
Uninstallable=yes
ChangesEnvironment=yes

[Files]
Source: "deps-harness.iss"; DestDir: "{app}"

#include "..\installer\dvlce-deps.iss"

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then InstallDeps();
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then UninstallDeps();
end;
