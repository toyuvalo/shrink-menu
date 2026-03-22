@echo off
REM build.cmd -- Builds ShrinkMenu-Install.exe using iexpress (built into Windows)

set "SED=%TEMP%\shrinkmenu_build.sed"
set "OUT=%~dp0ShrinkMenu-Install.exe"
set "SRC=%~dp0"

(
echo [Version]
echo Class=IEXPRESS
echo SEDVersion=3
echo [Options]
echo PackagePurpose=InstallApp
echo ShowInstallProgramWindow=0
echo HideExtractAnimation=0
echo UseLongFileName=1
echo InsideCompressed=0
echo CAB_FixedSize=0
echo CAB_ResvCodeSigning=0
echo RebootMode=N
echo InstallPrompt=
echo DisplayLicense=
echo FinishMessage=
echo TargetName=%OUT%
echo FriendlyName=Shrink Menu Installer
echo AppLaunched=setup.cmd
echo PostInstallCmd=^<None^>
echo AdminQuietInstCmd=
echo UserQuietInstCmd=
echo SourceFiles=SourceFiles
echo [Strings]
echo FILE0="setup.cmd"
echo FILE1="setup.ps1"
echo FILE2="shrink.ps1"
echo FILE3="launcher.vbs"
echo FILE4="install.ps1"
echo FILE5="uninstall.ps1"
echo [SourceFiles]
echo SourceFiles0=%SRC%
echo [SourceFiles0]
echo %%FILE0%%=
echo %%FILE1%%=
echo %%FILE2%%=
echo %%FILE3%%=
echo %%FILE4%%=
echo %%FILE5%%=
) > "%SED%"

iexpress /N /Q "%SED%"
del "%SED%" >nul 2>&1

if exist "%OUT%" (
    echo.
    echo   Built: %OUT%
    echo.
) else (
    echo.
    echo   ERROR: Build failed. Make sure iexpress.exe is on PATH.
    echo.
)
