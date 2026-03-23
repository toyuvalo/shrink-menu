# uninstall.ps1 -- Remove Shrink context menu entries
# Run: powershell -ExecutionPolicy Bypass -File uninstall.ps1

Write-Host "Shrink Menu -- Uninstaller" -ForegroundColor Yellow
Write-Host ""

$extensions = @(
    '.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tiff', '.tif', '.gif', '.heic', '.heif', '.avif',
    '.mp3', '.wav', '.flac', '.aac', '.ogg', '.wma', '.m4a', '.opus', '.aiff', '.ape', '.m4b', '.weba',
    '.mp4', '.mkv', '.avi', '.mov', '.webm', '.wmv', '.flv', '.ts', '.m4v', '.3gp'
)

$removed = 0
foreach ($ext in $extensions) {
    $regPath = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\ShrinkMenu"
    if (Test-Path $regPath) {
        Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
        $removed++
    }
}

Write-Host "Removed $removed registry entries." -ForegroundColor Green
Write-Host ""
Write-Host "Restart Explorer to apply:" -ForegroundColor Yellow
Write-Host "  taskkill /f /im explorer.exe && start explorer.exe" -ForegroundColor DarkGray
Write-Host ""
Read-Host "Press Enter to close"
