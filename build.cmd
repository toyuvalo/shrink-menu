@echo off
REM build.cmd -- Builds ShrinkMenu-Install.exe using iexpress (built into Windows)

set "SED=%TEMP%\shrinkmenu_build.sed"
set "OUT=%~dp0ShrinkMenu-Install.exe"
set "SRC=%~dp0"

REM Regenerate icon if ImageMagick is available
where magick >nul 2>&1
if %errorlevel%==0 (
    echo Generating icon...
    powershell -NonInteractive -NoProfile -ExecutionPolicy Bypass -File "%~dp0create-icon.ps1" -Dest "%~dp0"
)

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
echo FILE6="shrink.ico"
echo [SourceFiles]
echo SourceFiles0=%SRC%
echo [SourceFiles0]
echo %%FILE0%%=
echo %%FILE1%%=
echo %%FILE2%%=
echo %%FILE3%%=
echo %%FILE4%%=
echo %%FILE5%%=
echo %%FILE6%%=
) > "%SED%"

REM Record the existing build so success can be judged on the timestamp.
REM "if exist" alone is a false positive: it passes on a stale .exe from a
REM previous build, which is how a broken iexpress call went unnoticed for
REM months.
set "STAMP="
if exist "%OUT%" for %%F in ("%OUT%") do set "STAMP=%%~tF"

REM Do NOT quote %SED%. IExpress takes the quotes as part of the file name and
REM fails with "Error opening the IExpress Self Extraction Directive file" --
REM silently, because /Q suppresses that dialog. Keep %TEMP% free of spaces.
iexpress /N /Q %SED%
del "%SED%" >nul 2>&1

set "NEWSTAMP="
if exist "%OUT%" for %%F in ("%OUT%") do set "NEWSTAMP=%%~tF"

if not defined NEWSTAMP (
    echo.
    echo   ERROR: Build failed - no output. Make sure iexpress.exe is on PATH.
    echo.
) else if "%NEWSTAMP%"=="%STAMP%" (
    echo.
    echo   ERROR: Build failed - %OUT% is unchanged ^(%NEWSTAMP%^).
    echo          iexpress produced nothing; the old installer is still there.
    echo.
) else (
    echo.
    echo   Built: %OUT%  ^(%NEWSTAMP%^)
    echo.
)
