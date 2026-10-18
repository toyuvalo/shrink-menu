; ShrinkMenu.iss -- Inno Setup script for ShrinkMenu-Install.exe (v1.5.1)
; Replaces the IExpress package. IExpress extracted to %TEMP% and ran
; setup.cmd -> powershell -ExecutionPolicy Bypass, the same chain malware
; droppers use, and antivirus flags it. This installer runs no scripts:
; it copies files and writes the HKCU context-menu keys itself. v1.5.1: when
; ffmpeg or ImageMagick is not on the PATH, it downloads them (dvlce-deps.iss).
; Build: build.cmd (needs Inno Setup 6, ISCC.exe).

#define AppVersion "1.5.1"
#define AppGuid "9C4D2E7B-1A6F-4B83-8E25-6F3B0A9D1C57"
#define NeedFFmpeg
#define NeedMagick

[Setup]
AppId={{{#AppGuid}}
AppName=Shrink Menu
AppVersion={#AppVersion}
AppPublisher=DVLCE
AppPublisherURL=https://webdev.dvlce.ca/shrink
AppSupportURL=https://github.com/toyuvalo/shrink-menu
VersionInfoVersion={#AppVersion}
VersionInfoDescription=Shrink Menu Setup
; Per-user install, no admin. Same folder as the old installer, so it upgrades in place.
PrivilegesRequired=lowest
DefaultDirName={localappdata}\ShrinkMenu
DisableDirPage=yes
DisableProgramGroupPage=yes
OutputDir=..
OutputBaseFilename=ShrinkMenu-Install
SetupIconFile=..\shrink.ico
UninstallDisplayIcon={app}\ShrinkMenu.exe
UninstallDisplayName=Shrink Menu
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ChangesAssociations=yes
ChangesEnvironment=yes
#ifdef SIGN
; build.cmd passes /DSIGN and /Sazsign=<command> (Azure Artifact Signing).
SignTool=azsign
SignedUninstaller=yes
#endif

[Files]
Source: "..\build\ShrinkMenu.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\shrink.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\shrink.ico"; DestDir: "{app}"; Flags: ignoreversion

[InstallDelete]
; Left behind by the IExpress-era installer.
Type: files; Name: "{app}\launcher.vbs"
Type: files; Name: "{app}\setup.cmd"
Type: files; Name: "{app}\setup.ps1"
Type: files; Name: "{app}\install.ps1"
Type: files; Name: "{app}\uninstall.ps1"

#define MenuKey(Ext) "Software\Classes\SystemFileAssociations\" + Ext + "\shell\ShrinkMenu"
#define Entry(Ext) \
  'Root: HKCU; Subkey: "' + MenuKey(Ext) + '"; ValueType: none; Flags: deletekey' + NewLine + \
  'Root: HKCU; Subkey: "' + MenuKey(Ext) + '"; ValueType: string; ValueName: ""; ValueData: "Shrink..."; Flags: uninsdeletekey' + NewLine + \
  'Root: HKCU; Subkey: "' + MenuKey(Ext) + '"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\shrink.ico,0"' + NewLine + \
  'Root: HKCU; Subkey: "' + MenuKey(Ext) + '"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Player"' + NewLine + \
  'Root: HKCU; Subkey: "' + MenuKey(Ext) + '\command"; ValueType: string; ValueName: ""; ValueData: """{app}\ShrinkMenu.exe"" ""%1"""' + NewLine

[Registry]
#emit Entry(".jpg")
#emit Entry(".jpeg")
#emit Entry(".png")
#emit Entry(".webp")
#emit Entry(".bmp")
#emit Entry(".tiff")
#emit Entry(".tif")
#emit Entry(".gif")
#emit Entry(".heic")
#emit Entry(".heif")
#emit Entry(".avif")
#emit Entry(".mp3")
#emit Entry(".wav")
#emit Entry(".flac")
#emit Entry(".aac")
#emit Entry(".ogg")
#emit Entry(".wma")
#emit Entry(".m4a")
#emit Entry(".opus")
#emit Entry(".aiff")
#emit Entry(".ape")
#emit Entry(".m4b")
#emit Entry(".weba")
#emit Entry(".mp4")
#emit Entry(".mkv")
#emit Entry(".avi")
#emit Entry(".mov")
#emit Entry(".webm")
#emit Entry(".wmv")
#emit Entry(".flv")
#emit Entry(".ts")
#emit Entry(".m4v")
#emit Entry(".3gp")

#include "dvlce-deps.iss"

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then InstallDeps();
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then UninstallDeps();
end;
