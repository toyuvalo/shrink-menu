# create-icon.ps1 -- Generate shrink.ico using ImageMagick drawing primitives
# Design: dark rounded bg, two orange compress arrows pointing toward center

param([string]$Dest = $PSScriptRoot)
if (-not $Dest) { $Dest = (Get-Location).Path }

if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: ImageMagick not found" -ForegroundColor Red; exit 1
}

$ico = Join-Path $Dest "shrink.ico"
$tmp = Join-Path $env:TEMP "shrinkicon_build"
New-Item -Path $tmp -ItemType Directory -Force | Out-Null

try {
    # -----------------------------------------------------------------------
    # Draw at 256x256 (transparent bg, dark rounded rect, orange compress arrows)
    #
    # Down arrow (pointing toward center, tip at y=140):
    #   body  x=98-158  y=28-98   (60 wide)
    #   head  x=63-193  y=98-140  (130 wide)
    #
    # Up arrow (pointing toward center, tip at y=116):
    #   body  x=98-158  y=228-158  (60 wide)
    #   head  x=63-193  y=158-116  (130 wide)
    #
    # Gap between arrow tips: y=116 to y=140 (24 px = ~9% of canvas)
    # -----------------------------------------------------------------------

    $arrow_down = "polygon 98,28 158,28 158,98 193,98 128,140 63,98 98,98"
    $arrow_up   = "polygon 98,228 158,228 158,158 193,158 128,116 63,158 98,158"

    Write-Host "  Generating 256x256 master..." -ForegroundColor DarkGray
    & magick `
        -size 256x256 xc:none `
        -fill "#161618" `
        -draw "roundrectangle 0,0,255,255,42,42" `
        -fill "#FFA03C" `
        -draw $arrow_down `
        -draw $arrow_up `
        (Join-Path $tmp "s256.png")

    foreach ($sz in @(48, 32, 16)) {
        Write-Host "  Downscaling to ${sz}x${sz}..." -ForegroundColor DarkGray
        & magick (Join-Path $tmp "s256.png") -resize "${sz}x${sz}" -filter Lanczos `
            (Join-Path $tmp "s${sz}.png")
    }

    Write-Host "  Combining into ICO..." -ForegroundColor DarkGray
    & magick `
        (Join-Path $tmp "s16.png") `
        (Join-Path $tmp "s32.png") `
        (Join-Path $tmp "s48.png") `
        (Join-Path $tmp "s256.png") `
        $ico

    Write-Host "  Created: $ico" -ForegroundColor Green
} finally {
    Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
