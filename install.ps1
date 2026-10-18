# install.ps1 -- Register Shrink context menu entries (no admin required)
# Run: powershell -ExecutionPolicy Bypass -File install.ps1
# The one-click installer (ShrinkMenu-Install.exe) does the same without PowerShell.

$launcherPath = Join-Path $PSScriptRoot "build\ShrinkMenu.exe"
$scriptPath   = Join-Path $PSScriptRoot "shrink.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "ERROR: shrink.ps1 not found in $PSScriptRoot" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $launcherPath)) {
    # Compile the launcher with the in-box .NET Framework compiler (no extra install).
    $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
    if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe" }
    New-Item -ItemType Directory -Path (Split-Path $launcherPath) -Force | Out-Null
    & $csc /nologo /target:winexe /optimize+ "/win32icon:$(Join-Path $PSScriptRoot 'shrink.ico')" /r:Microsoft.CSharp.dll "/out:$launcherPath" (Join-Path $PSScriptRoot "launcher\ShrinkMenuLauncher.cs")
    if (-not (Test-Path $launcherPath)) {
        Write-Host "ERROR: could not build $launcherPath" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Shrink Menu -- Installer" -ForegroundColor Yellow
Write-Host "========================" -ForegroundColor Yellow
Write-Host ""

# ======================================
#  DETECT TOOLS
# ======================================

Write-Host "Checking tools..." -ForegroundColor White

$magickOk  = [bool](Get-Command magick  -ErrorAction SilentlyContinue)
$ffmpegOk  = [bool](Get-Command ffmpeg  -ErrorAction SilentlyContinue)
$ffprobeOk = [bool](Get-Command ffprobe -ErrorAction SilentlyContinue)

if ($magickOk) {
    Write-Host "  [OK] ImageMagick found  (image shrink)" -ForegroundColor Green
} else {
    Write-Host "  [!!] ImageMagick NOT found -- image shrink will not work" -ForegroundColor Yellow
    Write-Host "       Install: https://imagemagick.org/script/download.php#windows" -ForegroundColor DarkGray
}

if ($ffmpegOk) {
    Write-Host "  [OK] ffmpeg found  (video shrink)" -ForegroundColor Green
} else {
    Write-Host "  [!!] ffmpeg NOT found -- video shrink will not work" -ForegroundColor Yellow
    Write-Host "       Install: https://www.gyan.dev/ffmpeg/builds/" -ForegroundColor DarkGray
}

if ($ffprobeOk) {
    Write-Host "  [OK] ffprobe found  (Discord duration probe)" -ForegroundColor Green
} else {
    Write-Host "  [--] ffprobe not found (optional, needed for Discord preset accuracy)" -ForegroundColor DarkGray
}

if (-not $magickOk -and -not $ffmpegOk) {
    Write-Host ""
    Write-Host "WARNING: Neither ImageMagick nor ffmpeg found." -ForegroundColor Red
    Write-Host "         Shrink won't do anything until at least one is installed." -ForegroundColor Red
}

Write-Host ""

# ======================================
#  REGISTER CONTEXT MENU
# ======================================

Write-Host "Registering context menu entries..." -ForegroundColor White

$extensions = @(
    '.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tiff', '.tif', '.gif', '.heic', '.heif', '.avif',
    '.mp3', '.wav', '.flac', '.aac', '.ogg', '.wma', '.m4a', '.opus', '.aiff', '.ape', '.m4b', '.weba',
    '.mp4', '.mkv', '.avi', '.mov', '.webm', '.wmv', '.flv', '.ts', '.m4v', '.3gp'
)

$menuName  = "ShrinkMenu"
$menuLabel = "Shrink..."
$icoPath   = Join-Path $PSScriptRoot "shrink.ico"
$menuIcon  = if (Test-Path $icoPath) { "$icoPath,0" } else { "shell32.dll,23" }
$cmd       = "`"$launcherPath`" `"%1`""

foreach ($ext in $extensions) {
    $regPath = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\$menuName"
    if (Test-Path $regPath) { Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -Path $regPath -Force | Out-Null
    Set-ItemProperty -Path $regPath -Name "(Default)"        -Value $menuLabel
    Set-ItemProperty -Path $regPath -Name "Icon"             -Value $menuIcon
    Set-ItemProperty -Path $regPath -Name "MultiSelectModel" -Value "Player"
    $cmdKey = "$regPath\command"
    New-Item -Path $cmdKey -Force | Out-Null
    Set-ItemProperty -Path $cmdKey -Name "(Default)" -Value $cmd
}

Write-Host "  Registered $($extensions.Count) file types" -ForegroundColor Green
Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Right-click any image, audio, or video to see 'Shrink...'" -ForegroundColor White
Write-Host "  Images: jpg jpeg png webp bmp tiff gif heic heif avif" -ForegroundColor Gray
Write-Host "  Audio:  mp3 wav flac aac ogg wma m4a opus aiff ape" -ForegroundColor Gray
Write-Host "  Videos: mp4 mkv avi mov webm wmv flv ts m4v 3gp" -ForegroundColor Gray
Write-Host ""
Write-Host "If the menu doesn't appear, restart Explorer:" -ForegroundColor Yellow
Write-Host "  taskkill /f /im explorer.exe && start explorer.exe" -ForegroundColor DarkGray
Write-Host ""
Read-Host "Press Enter to close"
