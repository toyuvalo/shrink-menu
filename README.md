# Shrink Menu

Right-click any image or video on Windows → **Shrink...** → instant size picker GUI.

## Install

**One click:** Download `ShrinkMenu-Install.exe` and run it.

**Manual:** Clone the repo, right-click `install.ps1` → Run with PowerShell.

## What it does

### Images (requires ImageMagick)
- Quality slider 10–100%
- Format: keep same / JPEG / PNG / WebP
- PNG uses color quantization (lossless → palette reduction)
- **Overwrite** original or **Save copy** with `_shrunk` suffix

### Videos (requires ffmpeg)
| Preset | Resolution | Notes |
|--------|-----------|-------|
| 1080p | 1920×1080 | ~50% smaller, high quality |
| 720p | 1280×720 | ~70% smaller, balanced |
| 480p | 854×480 | ~85% smaller, small file |
| Web | 1280×720 | fast-start, streaming optimized |
| Discord | 854×480 | targets Discord 8 MB free upload limit |

Before/after file size shown per file in the progress window.

## Requirements

- ImageMagick 7+ — [imagemagick.org](https://imagemagick.org/script/download.php#windows)
- ffmpeg — [gyan.dev/ffmpeg/builds](https://www.gyan.dev/ffmpeg/builds/)

Both must be on your system PATH. The installer checks and warns if they're missing.

## Integration

The installer registers `Shrink...` on right-click for:

**Images:** jpg jpeg png webp bmp tiff gif heic heif avif
**Videos:** mp4 mkv avi mov webm wmv flv ts m4v 3gp

A **Shrink...** button also appears at the bottom of the [FFmpeg Convert](https://github.com/toyuvalo/ffmpeg-context-menu) and [Doc Convert](https://github.com/toyuvalo/doc-convert-menu) pickers.

## Uninstall

Run `uninstall.ps1` with PowerShell.

## Build the exe yourself

```cmd
build.cmd
```

Requires `iexpress.exe` (built into Windows).
