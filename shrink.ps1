# shrink.ps1 -- Shrink images, audio, and videos with GUI  v1.1.0
# Images: quality slider + format (JPEG/PNG/WebP/same)
# Audio:  bitrate presets (Voice/Small/Good/HQ/Opus) -> MP3 or Opus
# Videos: resolution/bitrate presets (1080p, 720p, 480p, Web, Discord)

param(
    [string]$Path,
    [string]$ListFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ======================================
#  TOOL DETECTION
# ======================================

$magickCmd  = $null
$ffmpegCmd  = $null
$ffprobeCmd = $null
if (Get-Command magick  -ErrorAction SilentlyContinue) { $magickCmd  = "magick"  }
if (Get-Command ffmpeg  -ErrorAction SilentlyContinue) { $ffmpegCmd  = "ffmpeg"  }
if (Get-Command ffprobe -ErrorAction SilentlyContinue) { $ffprobeCmd = "ffprobe" }

# ======================================
#  FILE TYPE GROUPS
# ======================================

$imageExts = @('.jpg','.jpeg','.png','.webp','.bmp','.tiff','.tif','.gif','.heic','.heif','.avif')
$audioExts = @('.mp3','.wav','.flac','.aac','.ogg','.wma','.m4a','.opus','.aiff','.ape','.m4b','.weba')
$videoExts = @('.mp4','.mkv','.avi','.mov','.webm','.wmv','.flv','.ts','.m4v','.3gp')

# ======================================
#  LOAD FILE LIST
# ======================================

$allPaths = @()
if ($ListFile -and (Test-Path $ListFile)) {
    $allPaths = @(Get-Content $ListFile -Encoding UTF8 |
        Where-Object { $_.Trim() -ne "" } |
        ForEach-Object { $_.Trim() })
    Remove-Item $ListFile -Force -ErrorAction SilentlyContinue
} elseif ($Path) {
    $allPaths = @($Path)
}

if ($allPaths.Count -eq 0) { exit 0 }

$imagePaths = @($allPaths | Where-Object { $imageExts -contains ([IO.Path]::GetExtension($_).ToLower()) })
$audioPaths = @($allPaths | Where-Object { $audioExts -contains ([IO.Path]::GetExtension($_).ToLower()) })
$videoPaths = @($allPaths | Where-Object { $videoExts -contains ([IO.Path]::GetExtension($_).ToLower()) })

$hasImages = ($magickCmd -ne $null) -and ($imagePaths.Count -gt 0)
$hasAudio  = ($ffmpegCmd -ne $null) -and ($audioPaths.Count -gt 0)
$hasVideos = ($ffmpegCmd -ne $null) -and ($videoPaths.Count -gt 0)

# Error: no supported files at all
if ($imagePaths.Count -eq 0 -and $audioPaths.Count -eq 0 -and $videoPaths.Count -eq 0) {
    $allExts = (@($allPaths | ForEach-Object { [IO.Path]::GetExtension($_).ToLower() } | Sort-Object -Unique)) -join ", "
    $msgForm = New-Object System.Windows.Forms.Form
    $msgForm.TopMost = $true; $msgForm.WindowState = "Minimized"; $msgForm.Show()
    [System.Windows.Forms.MessageBox]::Show($msgForm,
        "No supported files.`n`nImages: jpg png webp bmp tiff gif heic avif`nAudio:  mp3 wav flac aac ogg wma m4a opus aiff ape`nVideo:  mp4 mkv avi mov webm wmv flv ts`n`nSelected: $allExts",
        "Shrink", "OK", "Information") | Out-Null
    $msgForm.Close(); exit 0
}

# Error: tools missing
if (-not $hasImages -and -not $hasAudio -and -not $hasVideos) {
    $missing = @()
    if ($imagePaths.Count -gt 0 -and -not $magickCmd) { $missing += "ImageMagick  (images -- imagemagick.org)" }
    if ($audioPaths.Count -gt 0 -and -not $ffmpegCmd) { $missing += "ffmpeg  (audio -- ffmpeg.org)" }
    if ($videoPaths.Count -gt 0 -and -not $ffmpegCmd) { $missing += "ffmpeg  (videos -- ffmpeg.org)" }
    $msgForm = New-Object System.Windows.Forms.Form
    $msgForm.TopMost = $true; $msgForm.WindowState = "Minimized"; $msgForm.Show()
    [System.Windows.Forms.MessageBox]::Show($msgForm,
        "Required tools not found:`n`n" + ($missing -join "`n") + "`n`nInstall them and add to PATH, then retry.",
        "Shrink", "OK", "Warning") | Out-Null
    $msgForm.Close(); exit 0
}

# ======================================
#  COLORS
# ======================================

$bgColor     = [System.Drawing.Color]::FromArgb(22, 22, 24)
$btnColor    = [System.Drawing.Color]::FromArgb(50, 50, 52)
$btnHover    = [System.Drawing.Color]::FromArgb(65, 65, 68)
$accentColor = [System.Drawing.Color]::FromArgb(255, 160, 60)
$dimColor    = [System.Drawing.Color]::FromArgb(110, 110, 110)
$whiteColor  = [System.Drawing.Color]::White
$darkText    = [System.Drawing.Color]::FromArgb(20, 20, 20)

# ======================================
#  PICKER FORM
# ======================================

$pickerForm = New-Object System.Windows.Forms.Form
$pickerForm.Text = "Shrink"
$pickerForm.StartPosition = "CenterScreen"
$pickerForm.FormBorderStyle = "FixedSingle"
$pickerForm.MaximizeBox = $false
$pickerForm.BackColor = $bgColor
$pickerForm.ForeColor = $whiteColor
$pickerForm.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$pickerForm.TopMost = $true

# Header
$headerLabel = New-Object System.Windows.Forms.Label
$headerLabel.Text = "Shrink"
$headerLabel.Location = New-Object System.Drawing.Point(20, 14)
$headerLabel.Size = New-Object System.Drawing.Size(200, 28)
$headerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$headerLabel.ForeColor = $accentColor
$pickerForm.Controls.Add($headerLabel)

$yPos = 50

# ---- Output mode toggle (Overwrite / Save copy) ----
$saveModeLabel = New-Object System.Windows.Forms.Label
$saveModeLabel.Text = "Output"
$saveModeLabel.Location = New-Object System.Drawing.Point(20, ($yPos + 2))
$saveModeLabel.Size = New-Object System.Drawing.Size(55, 22)
$saveModeLabel.ForeColor = $dimColor
$saveModeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$pickerForm.Controls.Add($saveModeLabel)

$script:saveMode = "overwrite"

$btnOverwrite = New-Object System.Windows.Forms.Button
$btnOverwrite.Text = "Overwrite"
$btnOverwrite.Location = New-Object System.Drawing.Point(78, ($yPos - 1))
$btnOverwrite.Size = New-Object System.Drawing.Size(90, 26)
$btnOverwrite.FlatStyle = "Flat"
$btnOverwrite.FlatAppearance.BorderSize = 1
$btnOverwrite.FlatAppearance.BorderColor = $accentColor
$btnOverwrite.BackColor = $accentColor
$btnOverwrite.ForeColor = $darkText
$btnOverwrite.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

$btnSaveCopy = New-Object System.Windows.Forms.Button
$btnSaveCopy.Text = "Save copy"
$btnSaveCopy.Location = New-Object System.Drawing.Point(172, ($yPos - 1))
$btnSaveCopy.Size = New-Object System.Drawing.Size(90, 26)
$btnSaveCopy.FlatStyle = "Flat"
$btnSaveCopy.FlatAppearance.BorderSize = 1
$btnSaveCopy.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
$btnSaveCopy.BackColor = $btnColor
$btnSaveCopy.ForeColor = $whiteColor
$btnSaveCopy.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$btnOverwrite.Add_Click({
    $script:saveMode = "overwrite"
    $btnOverwrite.BackColor = $accentColor;  $btnOverwrite.ForeColor = $darkText
    $btnOverwrite.FlatAppearance.BorderColor = $accentColor
    $btnOverwrite.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $btnSaveCopy.BackColor = $btnColor;  $btnSaveCopy.ForeColor = $whiteColor
    $btnSaveCopy.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70,70,70)
    $btnSaveCopy.Font = New-Object System.Drawing.Font("Segoe UI", 9)
})
$btnSaveCopy.Add_Click({
    $script:saveMode = "copy"
    $btnSaveCopy.BackColor = $accentColor;  $btnSaveCopy.ForeColor = $darkText
    $btnSaveCopy.FlatAppearance.BorderColor = $accentColor
    $btnSaveCopy.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $btnOverwrite.BackColor = $btnColor;  $btnOverwrite.ForeColor = $whiteColor
    $btnOverwrite.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70,70,70)
    $btnOverwrite.Font = New-Object System.Drawing.Font("Segoe UI", 9)
})

$pickerForm.Controls.Add($btnOverwrite)
$pickerForm.Controls.Add($btnSaveCopy)
$yPos += 34

$script:pickedAction       = $null
$script:imageQuality       = 82
$script:imageFormat        = "same"
$script:imageMaxDim        = 0
$script:audioPreset        = $null
$script:videoCustomHeight  = 720

# ======================================
#  IMAGES SECTION
# ======================================

if ($hasImages) {
    $yPos += 4

    $sep1 = New-Object System.Windows.Forms.Panel
    $sep1.Location = New-Object System.Drawing.Point(20, $yPos)
    $sep1.Size = New-Object System.Drawing.Size(320, 1)
    $sep1.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 57)
    $pickerForm.Controls.Add($sep1)
    $yPos += 8

    $imgHdr = New-Object System.Windows.Forms.Label
    $imgHdr.Text = "Images  ($($imagePaths.Count) file$(if($imagePaths.Count -ne 1){'s'}))"
    $imgHdr.Location = New-Object System.Drawing.Point(20, $yPos)
    $imgHdr.Size = New-Object System.Drawing.Size(320, 18)
    $imgHdr.ForeColor = $dimColor
    $imgHdr.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $pickerForm.Controls.Add($imgHdr)
    $yPos += 22

    # Quality row
    $qualLabel = New-Object System.Windows.Forms.Label
    $qualLabel.Text = "Quality"
    $qualLabel.Location = New-Object System.Drawing.Point(20, ($yPos + 4))
    $qualLabel.Size = New-Object System.Drawing.Size(52, 20)
    $qualLabel.ForeColor = $whiteColor
    $qualLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $pickerForm.Controls.Add($qualLabel)

    $qualVal = New-Object System.Windows.Forms.Label
    $qualVal.Text = "82%"
    $qualVal.Location = New-Object System.Drawing.Point(300, ($yPos + 4))
    $qualVal.Size = New-Object System.Drawing.Size(34, 20)
    $qualVal.ForeColor = $accentColor
    $qualVal.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $qualVal.TextAlign = "MiddleRight"
    $pickerForm.Controls.Add($qualVal)

    $slider = New-Object System.Windows.Forms.TrackBar
    $slider.Location = New-Object System.Drawing.Point(72, $yPos)
    $slider.Size = New-Object System.Drawing.Size(224, 26)
    $slider.Minimum = 10
    $slider.Maximum = 100
    $slider.Value = 82
    $slider.TickFrequency = 10
    $slider.TickStyle = "BottomRight"
    $slider.BackColor = $bgColor
    $slider.Add_Scroll({
        $script:imageQuality = $slider.Value
        $qualVal.Text = "$($slider.Value)%"
    })
    $pickerForm.Controls.Add($slider)
    $yPos += 30

    # Format label (own row)
    $fmtHdrLabel = New-Object System.Windows.Forms.Label
    $fmtHdrLabel.Text = "Format"
    $fmtHdrLabel.Location = New-Object System.Drawing.Point(20, $yPos)
    $fmtHdrLabel.Size = New-Object System.Drawing.Size(320, 18)
    $fmtHdrLabel.ForeColor = $dimColor
    $fmtHdrLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $pickerForm.Controls.Add($fmtHdrLabel)
    $yPos += 20

    # Format buttons row — 4 buttons, full width, 4px gaps
    $fmtBtns   = @{}
    $fmtOpts   = @("Same","JPEG","PNG","WebP")
    $fmtKeys   = @("same","jpg","png","webp")
    $fmtBtnW   = 76
    $fmtGap    = 5
    $fmtX      = 20

    for ($fi = 0; $fi -lt $fmtOpts.Count; $fi++) {
        $fk   = $fmtKeys[$fi]
        $fbtn = New-Object System.Windows.Forms.Button
        $fbtn.Text = $fmtOpts[$fi]
        $fbtn.Location = New-Object System.Drawing.Point($fmtX, $yPos)
        $fbtn.Size = New-Object System.Drawing.Size($fmtBtnW, 28)
        $fbtn.FlatStyle = "Flat"
        $fbtn.FlatAppearance.BorderSize = 1
        $fbtn.Tag = $fk
        if ($fi -eq 0) {
            $fbtn.BackColor = $accentColor
            $fbtn.ForeColor = $darkText
            $fbtn.FlatAppearance.BorderColor = $accentColor
            $fbtn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        } else {
            $fbtn.BackColor = $btnColor
            $fbtn.ForeColor = $whiteColor
            $fbtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70,70,70)
            $fbtn.Font = New-Object System.Drawing.Font("Segoe UI", 9)
        }
        $fbtn.Add_Click({
            $script:imageFormat = $this.Tag
            foreach ($b in $fmtBtns.Values) {
                $b.BackColor = $btnColor; $b.ForeColor = $whiteColor
                $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70,70,70)
                $b.Font = New-Object System.Drawing.Font("Segoe UI", 9)
            }
            $this.BackColor = $accentColor; $this.ForeColor = $darkText
            $this.FlatAppearance.BorderColor = $accentColor
            $this.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        })
        $fmtBtns[$fk] = $fbtn
        $pickerForm.Controls.Add($fbtn)
        $fmtX += $fmtBtnW + $fmtGap
    }
    $yPos += 34

    # Resize row — optional max dimension
    $resizeLabel = New-Object System.Windows.Forms.Label
    $resizeLabel.Text = "Max size"
    $resizeLabel.Location = New-Object System.Drawing.Point(20, ($yPos + 4))
    $resizeLabel.Size = New-Object System.Drawing.Size(62, 20)
    $resizeLabel.ForeColor = $whiteColor
    $resizeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $pickerForm.Controls.Add($resizeLabel)

    $resizeNUD = New-Object System.Windows.Forms.NumericUpDown
    $resizeNUD.Location = New-Object System.Drawing.Point(84, $yPos)
    $resizeNUD.Size = New-Object System.Drawing.Size(88, 24)
    $resizeNUD.Minimum = 0
    $resizeNUD.Maximum = 8000
    $resizeNUD.Increment = 100
    $resizeNUD.Value = 0
    $resizeNUD.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 52)
    $resizeNUD.ForeColor = $whiteColor
    $resizeNUD.Add_ValueChanged({ $script:imageMaxDim = [int]$resizeNUD.Value })
    $pickerForm.Controls.Add($resizeNUD)

    $resizePxLabel = New-Object System.Windows.Forms.Label
    $resizePxLabel.Text = "px  longest side  (0 = no resize)"
    $resizePxLabel.Location = New-Object System.Drawing.Point(176, ($yPos + 4))
    $resizePxLabel.Size = New-Object System.Drawing.Size(164, 20)
    $resizePxLabel.ForeColor = $dimColor
    $resizePxLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $pickerForm.Controls.Add($resizePxLabel)
    $yPos += 32

    # Shrink Images button
    $shrinkImgBtn = New-Object System.Windows.Forms.Button
    $shrinkImgBtn.Text = "Shrink $($imagePaths.Count) Image$(if($imagePaths.Count -ne 1){'s'})"
    $shrinkImgBtn.Location = New-Object System.Drawing.Point(20, $yPos)
    $shrinkImgBtn.Size = New-Object System.Drawing.Size(320, 34)
    $shrinkImgBtn.FlatStyle = "Flat"
    $shrinkImgBtn.FlatAppearance.BorderSize = 0
    $shrinkImgBtn.BackColor = [System.Drawing.Color]::FromArgb(70, 46, 14)
    $shrinkImgBtn.ForeColor = $accentColor
    $shrinkImgBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $shrinkImgBtn.Add_Click({
        $script:pickedAction = "images"
        $pickerForm.Close()
    })
    $shrinkImgBtn.Add_MouseEnter({ $this.BackColor = [System.Drawing.Color]::FromArgb(90, 60, 20) })
    $shrinkImgBtn.Add_MouseLeave({ $this.BackColor = [System.Drawing.Color]::FromArgb(70, 46, 14) })
    $pickerForm.Controls.Add($shrinkImgBtn)
    $yPos += 40
}

# ======================================
#  AUDIO SECTION
# ======================================

if ($hasAudio) {
    $yPos += 4

    $sepAud = New-Object System.Windows.Forms.Panel
    $sepAud.Location = New-Object System.Drawing.Point(20, $yPos)
    $sepAud.Size = New-Object System.Drawing.Size(320, 1)
    $sepAud.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 57)
    $pickerForm.Controls.Add($sepAud)
    $yPos += 8

    $audHdr = New-Object System.Windows.Forms.Label
    $audHdr.Text = "Audio  ($($audioPaths.Count) file$(if($audioPaths.Count -ne 1){'s'}))"
    $audHdr.Location = New-Object System.Drawing.Point(20, $yPos)
    $audHdr.Size = New-Object System.Drawing.Size(320, 18)
    $audHdr.ForeColor = $dimColor
    $audHdr.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $pickerForm.Controls.Add($audHdr)
    $yPos += 22

    $audioPresets = @(
        @{ Label = "Voice    64 kbps mono";   Key = "voice"; Sub = "voice memos, podcasts -- tiny" }
        @{ Label = "Small   128 kbps";         Key = "small"; Sub = "general use  ~70% smaller than WAV/FLAC" }
        @{ Label = "Good    192 kbps";         Key = "good";  Sub = "music quality" }
        @{ Label = "HQ      320 kbps";         Key = "hq";    Sub = "max MP3 -- best for lossless source" }
        @{ Label = "Opus     96 kbps";         Key = "opus";  Sub = "modern codec, very small  -> .opus" }
    )

    foreach ($ap in $audioPresets) {
        $apKey  = $ap.Key
        $apSub  = $ap.Sub
        $apbtn  = New-Object System.Windows.Forms.Button
        $apbtn.Text = $ap.Label
        $apbtn.Location = New-Object System.Drawing.Point(20, $yPos)
        $apbtn.Size = New-Object System.Drawing.Size(320, 30)
        $apbtn.FlatStyle = "Flat"
        $apbtn.FlatAppearance.BorderSize = 0
        $apbtn.BackColor = $btnColor
        $apbtn.ForeColor = $whiteColor
        $apbtn.TextAlign = "MiddleLeft"
        $apbtn.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
        $apbtn.Tag = $apKey
        $apbtn.Add_Click({
            $script:pickedAction = "audio:" + $this.Tag
            $pickerForm.Close()
        })
        $apbtn.Add_MouseEnter({ $this.BackColor = $btnHover })
        $apbtn.Add_MouseLeave({ $this.BackColor = $btnColor })
        $pickerForm.Controls.Add($apbtn)

        $apSubLbl = New-Object System.Windows.Forms.Label
        $apSubLbl.Text = $apSub
        $apSubLbl.Location = New-Object System.Drawing.Point(32, ($yPos + 16))
        $apSubLbl.Size = New-Object System.Drawing.Size(290, 14)
        $apSubLbl.ForeColor = $dimColor
        $apSubLbl.Font = New-Object System.Drawing.Font("Segoe UI", 7)
        $pickerForm.Controls.Add($apSubLbl)

        $yPos += 36
    }
}

# ======================================
#  VIDEOS SECTION
# ======================================

if ($hasVideos) {
    $yPos += 4

    $sep2 = New-Object System.Windows.Forms.Panel
    $sep2.Location = New-Object System.Drawing.Point(20, $yPos)
    $sep2.Size = New-Object System.Drawing.Size(320, 1)
    $sep2.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 57)
    $pickerForm.Controls.Add($sep2)
    $yPos += 8

    $vidHdr = New-Object System.Windows.Forms.Label
    $vidHdr.Text = "Videos  ($($videoPaths.Count) file$(if($videoPaths.Count -ne 1){'s'}))"
    $vidHdr.Location = New-Object System.Drawing.Point(20, $yPos)
    $vidHdr.Size = New-Object System.Drawing.Size(320, 18)
    $vidHdr.ForeColor = $dimColor
    $vidHdr.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $pickerForm.Controls.Add($vidHdr)
    $yPos += 22

    $presets = @(
        @{ Label = "1080p   High quality";  Key = "1080p";   Sub = "1920x? AR preserved  ~50% smaller" }
        @{ Label = "720p    Balanced";       Key = "720p";    Sub = "1280x? AR preserved  ~70% smaller" }
        @{ Label = "480p    Small file";     Key = "480p";    Sub = "854x?  AR preserved  ~85% smaller" }
        @{ Label = "Web     Fast download";  Key = "web";     Sub = "720p, fast-start, AR preserved" }
        @{ Label = "Discord Fits 8 MB";      Key = "discord"; Sub = "480p, targets 8MB, AR preserved" }
    )

    foreach ($preset in $presets) {
        $pKey  = $preset.Key
        $pSub  = $preset.Sub
        $pbtn  = New-Object System.Windows.Forms.Button
        $pbtn.Text = $preset.Label
        $pbtn.Location = New-Object System.Drawing.Point(20, $yPos)
        $pbtn.Size = New-Object System.Drawing.Size(320, 30)
        $pbtn.FlatStyle = "Flat"
        $pbtn.FlatAppearance.BorderSize = 0
        $pbtn.BackColor = $btnColor
        $pbtn.ForeColor = $whiteColor
        $pbtn.TextAlign = "MiddleLeft"
        $pbtn.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
        $pbtn.Tag = $pKey
        $pbtn.Add_Click({
            $script:pickedAction = "video:" + $this.Tag
            $pickerForm.Close()
        })
        $pbtn.Add_MouseEnter({ $this.BackColor = $btnHover })
        $pbtn.Add_MouseLeave({ $this.BackColor = $btnColor })
        $pickerForm.Controls.Add($pbtn)

        $subLabel = New-Object System.Windows.Forms.Label
        $subLabel.Text = $pSub
        $subLabel.Location = New-Object System.Drawing.Point(32, ($yPos + 16))
        $subLabel.Size = New-Object System.Drawing.Size(290, 14)
        $subLabel.ForeColor = $dimColor
        $subLabel.Font = New-Object System.Drawing.Font("Segoe UI", 7)
        $pickerForm.Controls.Add($subLabel)

        $yPos += 36
    }

    # Custom height row
    $yPos += 2
    $customHLabel = New-Object System.Windows.Forms.Label
    $customHLabel.Text = "Custom"
    $customHLabel.Location = New-Object System.Drawing.Point(20, ($yPos + 5))
    $customHLabel.Size = New-Object System.Drawing.Size(58, 20)
    $customHLabel.ForeColor = $whiteColor
    $customHLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $pickerForm.Controls.Add($customHLabel)

    $customNUD = New-Object System.Windows.Forms.NumericUpDown
    $customNUD.Location = New-Object System.Drawing.Point(80, $yPos)
    $customNUD.Size = New-Object System.Drawing.Size(80, 24)
    $customNUD.Minimum = 144
    $customNUD.Maximum = 4320
    $customNUD.Increment = 10
    $customNUD.Value = 720
    $customNUD.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 52)
    $customNUD.ForeColor = $whiteColor
    $customNUD.Add_ValueChanged({ $script:videoCustomHeight = [int]$customNUD.Value })
    $pickerForm.Controls.Add($customNUD)

    $customPxLabel = New-Object System.Windows.Forms.Label
    $customPxLabel.Text = "px height  AR preserved"
    $customPxLabel.Location = New-Object System.Drawing.Point(164, ($yPos + 5))
    $customPxLabel.Size = New-Object System.Drawing.Size(160, 20)
    $customPxLabel.ForeColor = $dimColor
    $customPxLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $pickerForm.Controls.Add($customPxLabel)

    $customBtn = New-Object System.Windows.Forms.Button
    $customBtn.Text = "Shrink custom"
    $customBtn.Location = New-Object System.Drawing.Point(20, ($yPos + 30))
    $customBtn.Size = New-Object System.Drawing.Size(320, 28)
    $customBtn.FlatStyle = "Flat"
    $customBtn.FlatAppearance.BorderSize = 0
    $customBtn.BackColor = $btnColor
    $customBtn.ForeColor = $whiteColor
    $customBtn.TextAlign = "MiddleLeft"
    $customBtn.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
    $customBtn.Add_Click({
        $script:pickedAction = "video:custom"
        $pickerForm.Close()
    })
    $customBtn.Add_MouseEnter({ $this.BackColor = $btnHover })
    $customBtn.Add_MouseLeave({ $this.BackColor = $btnColor })
    $pickerForm.Controls.Add($customBtn)
    $yPos += 64
}

$pickerForm.ClientSize = New-Object System.Drawing.Size(360, ($yPos + 10))
[System.Windows.Forms.Application]::Run($pickerForm)

if (-not $script:pickedAction) { exit 0 }

$isImageJob  = ($script:pickedAction -eq "images")
$isAudioJob  = ($script:pickedAction -like "audio:*")
$isVideoJob  = ($script:pickedAction -like "video:*")
$audioPreset = if ($isAudioJob) { $script:pickedAction.Substring(6) } else { $null }
$videoPreset = if ($isVideoJob) { $script:pickedAction.Substring(6) } else { $null }
$saveMode    = $script:saveMode

# ======================================
#  BUILD FILE LIST FOR CHOSEN ACTION
# ======================================

$files = @()
if ($isImageJob) {
    foreach ($p in $imagePaths) { if (Test-Path $p -PathType Leaf) { $files += Get-Item $p } }
} elseif ($isAudioJob) {
    foreach ($p in $audioPaths) { if (Test-Path $p -PathType Leaf) { $files += Get-Item $p } }
} elseif ($isVideoJob) {
    foreach ($p in $videoPaths) { if (Test-Path $p -PathType Leaf) { $files += Get-Item $p } }
}

if ($files.Count -eq 0) { exit 0 }

$actionLabel = if ($isImageJob) {
    $fmtNote = if ($script:imageFormat -ne "same") { " -> " + $script:imageFormat.ToUpper() } else { "" }
    "Images  Quality $($script:imageQuality)%$fmtNote"
} elseif ($isAudioJob) {
    $audLabel = switch ($audioPreset) {
        "voice" { "Voice  64kbps mono MP3" }
        "small" { "Small  128kbps MP3" }
        "good"  { "Good   192kbps MP3" }
        "hq"    { "HQ     320kbps MP3" }
        "opus"  { "Opus   96kbps .opus" }
        default { "Audio  $audioPreset" }
    }
    "Audio  $audLabel"
} else {
    $vLabel = switch ($videoPreset) {
        "1080p"  { "1080p" }
        "720p"   { "720p" }
        "480p"   { "480p" }
        "web"    { "Web" }
        "discord"{ "Discord" }
        "custom" { "Custom $($script:videoCustomHeight)px" }
        default  { $videoPreset }
    }
    "Videos  $vLabel  (AR preserved)"
}

# ======================================
#  PROGRESS FORM
# ======================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Shrink"
$form.Size = New-Object System.Drawing.Size(575, 440)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = $bgColor
$form.ForeColor = $whiteColor
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Shrinking $($files.Count) file(s)  --  $actionLabel"
$titleLabel.Location = New-Object System.Drawing.Point(20, 16)
$titleLabel.Size = New-Object System.Drawing.Size(520, 26)
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = $accentColor
$form.Controls.Add($titleLabel)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 52)
$progressBar.Size = New-Object System.Drawing.Size(520, 24)
$progressBar.Style = "Continuous"
$progressBar.Minimum = 0
$progressBar.Maximum = [Math]::Max($files.Count, 1)
$progressBar.Value = 0
$form.Controls.Add($progressBar)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Starting..."
$statusLabel.Location = New-Object System.Drawing.Point(20, 84)
$statusLabel.Size = New-Object System.Drawing.Size(520, 20)
$statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 160)
$form.Controls.Add($statusLabel)

$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(20, 112)
$listView.Size = New-Object System.Drawing.Size(520, 238)
$listView.View = "Details"
$listView.FullRowSelect = $true
$listView.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 42)
$listView.ForeColor = $whiteColor
$listView.Font = New-Object System.Drawing.Font("Consolas", 9)
$listView.BorderStyle = "None"
$listView.HeaderStyle = "Nonclickable"
$listView.GridLines = $false
$listView.Columns.Add("File", 300) | Out-Null
$listView.Columns.Add("Status", 80) | Out-Null
$listView.Columns.Add("Before", 66) | Out-Null
$listView.Columns.Add("After",  64) | Out-Null

foreach ($file in $files) {
    $item = New-Object System.Windows.Forms.ListViewItem($file.Name)
    $item.SubItems.Add("Queued") | Out-Null
    $sizeStr = if ($file.Length -ge 1MB) { "$([math]::Round($file.Length/1MB,1)) MB" } else { "$([math]::Round($file.Length/1KB,0)) KB" }
    $item.SubItems.Add($sizeStr) | Out-Null
    $item.SubItems.Add("") | Out-Null
    $item.ForeColor = [System.Drawing.Color]::FromArgb(130, 130, 130)
    $listView.Items.Add($item) | Out-Null
}
$form.Controls.Add($listView)

$closeBtn = New-Object System.Windows.Forms.Button
$closeBtn.Text = "Close"
$closeBtn.Location = New-Object System.Drawing.Point(435, 362)
$closeBtn.Size = New-Object System.Drawing.Size(105, 32)
$closeBtn.FlatStyle = "Flat"
$closeBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70,70,70)
$closeBtn.BackColor = [System.Drawing.Color]::FromArgb(55,55,57)
$closeBtn.ForeColor = $whiteColor
$closeBtn.Visible = $false
$closeBtn.Add_Click({ $form.Close() })
$form.Controls.Add($closeBtn)

# ======================================
#  CONVERSION ENGINE
# ======================================

$script:jobQueue     = New-Object System.Collections.Queue
$script:runningJob   = $null
$script:doneCount    = 0
$script:successCount = 0
$script:failCount    = 0

for ($i = 0; $i -lt $files.Count; $i++) { $script:jobQueue.Enqueue($i) }

function Start-ShrinkJob {
    param([int]$Idx)

    $file   = $files[$Idx]
    $inPath = $file.FullName
    $ext    = $file.Extension.ToLower()
    $base   = [IO.Path]::GetFileNameWithoutExtension($file.Name)
    $dir    = $file.DirectoryName

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.UseShellExecute        = $false
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError  = $true
    $pinfo.CreateNoWindow         = $true

    $outPath = $null
    $tmpPath = $null
    $useTemp = $false

    if ($isImageJob) {
        $outExt = switch ($script:imageFormat) {
            "jpg"  { ".jpg" }
            "png"  { ".png" }
            "webp" { ".webp" }
            default { $ext }
        }
        $qual = $script:imageQuality

        if ($saveMode -eq "overwrite") {
            $tmpPath = Join-Path $env:TEMP "shrink_img_${Idx}_tmp${outExt}"
            $outPath = Join-Path $dir "$base$outExt"
            $useTemp = $true
            $dest    = $tmpPath
        } else {
            $outPath = Join-Path $dir "${base}_shrunk${outExt}"
            $dest    = $outPath
        }

        $pinfo.FileName = "magick"

        # Optional resize: -resize NxN> shrinks longest side to N, preserves AR, never enlarges
        $resizeStr = if ($script:imageMaxDim -gt 0) { " -resize $($script:imageMaxDim)x$($script:imageMaxDim)>" } else { "" }

        # PNG is lossless -- map quality to color quantization
        $isPngOut = ($outExt -eq ".png")
        if ($isPngOut) {
            $pngColors = if ($qual -ge 90) { $null } elseif ($qual -ge 70) { 256 } elseif ($qual -ge 50) { 128 } else { 64 }
            if ($pngColors) {
                $pinfo.Arguments = "`"$inPath`"$resizeStr -strip -colors $pngColors `"$dest`""
            } else {
                $pinfo.Arguments = "`"$inPath`"$resizeStr -strip `"$dest`""
            }
        } else {
            $pinfo.Arguments = "`"$inPath`"$resizeStr -quality $qual `"$dest`""
        }

    } elseif ($isAudioJob) {
        $outExt3 = if ($audioPreset -eq "opus") { ".opus" } else { ".mp3" }

        if ($saveMode -eq "overwrite") {
            $tmpPath = Join-Path $env:TEMP "shrink_aud_${Idx}_tmp${outExt3}"
            $outPath = Join-Path $dir "$base$outExt3"
            $useTemp = $true
            $dest    = $tmpPath
        } else {
            $outPath = Join-Path $dir "${base}_shrunk${outExt3}"
            $dest    = $outPath
        }

        $pinfo.FileName = "ffmpeg"
        $pinfo.Arguments = switch ($audioPreset) {
            "voice" { "-i `"$inPath`" -c:a libmp3lame -b:a 64k -ac 1 -y `"$dest`"" }
            "small" { "-i `"$inPath`" -c:a libmp3lame -b:a 128k -y `"$dest`"" }
            "good"  { "-i `"$inPath`" -c:a libmp3lame -b:a 192k -y `"$dest`"" }
            "hq"    { "-i `"$inPath`" -c:a libmp3lame -b:a 320k -y `"$dest`"" }
            "opus"  { "-i `"$inPath`" -c:a libopus -b:a 96k -y `"$dest`"" }
        }

    } elseif ($isVideoJob) {
        $outExt2 = ".mp4"

        if ($saveMode -eq "overwrite") {
            $tmpPath = Join-Path $env:TEMP "shrink_vid_${Idx}_tmp.mp4"
            $outPath = Join-Path $dir "$base$outExt2"
            # If same file would be overwritten, temp-swap is fine; distinct input format leaves original untouched
            $useTemp = $true
            $dest    = $tmpPath
        } else {
            $outPath = Join-Path $dir "${base}_shrunk$outExt2"
            $dest    = $outPath
        }

        $pinfo.FileName = "ffmpeg"

        $ffArgs = switch ($videoPreset) {
            "1080p" {
                "-i `"$inPath`" -vf `"scale=-2:1080`" -c:v libx264 -crf 22 -preset medium -c:a aac -b:a 128k -movflags +faststart -y `"$dest`""
            }
            "720p" {
                "-i `"$inPath`" -vf `"scale=-2:720`" -c:v libx264 -crf 23 -preset medium -c:a aac -b:a 128k -movflags +faststart -y `"$dest`""
            }
            "480p" {
                "-i `"$inPath`" -vf `"scale=-2:480`" -c:v libx264 -crf 28 -preset medium -c:a aac -b:a 96k -movflags +faststart -y `"$dest`""
            }
            "web" {
                "-i `"$inPath`" -vf `"scale=-2:720`" -c:v libx264 -crf 28 -preset fast -c:a aac -b:a 96k -movflags +faststart -y `"$dest`""
            }
            "custom" {
                "-i `"$inPath`" -vf `"scale=-2:$($script:videoCustomHeight)`" -c:v libx264 -crf 23 -preset medium -c:a aac -b:a 128k -movflags +faststart -y `"$dest`""
            }
            "discord" {
                # Probe duration, calculate bitrate to hit ~7.5 MB
                $dur = 60.0
                if ($ffprobeCmd) {
                    try {
                        $probed = & ffprobe -v error -show_entries format=duration -of csv=p=0 "$inPath" 2>&1
                        if ($probed -match '[\d.]+') { $dur = [double]$Matches[0] }
                    } catch {}
                }
                $targetBits = [long](7.5 * 1024 * 1024 * 8)
                $totalKbps  = [int]($targetBits / $dur / 1000)
                $audioKbps  = 96
                $videoKbps  = [Math]::Max(100, $totalKbps - $audioKbps)
                $bufKbps    = $videoKbps * 2
                "-i `"$inPath`" -vf `"scale=-2:480`" -c:v libx264 -b:v ${videoKbps}k -maxrate ${videoKbps}k -bufsize ${bufKbps}k -c:a aac -b:a ${audioKbps}k -movflags +faststart -y `"$dest`""
            }
        }
        $pinfo.Arguments = $ffArgs
    }

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $pinfo
    $proc.Start() | Out-Null
    $proc.StandardOutput.ReadToEndAsync() | Out-Null
    $proc.StandardError.ReadToEndAsync() | Out-Null

    $listView.Items[$Idx].SubItems[1].Text = "Working"
    $listView.Items[$Idx].ForeColor = [System.Drawing.Color]::FromArgb(255, 215, 80)

    $script:runningJob = @{
        Process  = $proc
        Idx      = $Idx
        OutPath  = $outPath
        TmpPath  = $tmpPath
        UseTemp  = $useTemp
        OrigPath = $inPath
    }
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 250

$timer.Add_Tick({
    if ($script:runningJob -ne $null) {
        $job = $script:runningJob
        if (-not $job.Process.HasExited) { return }

        $idx     = $job.Idx
        $success = $false

        if ($job.UseTemp -and $job.Process.ExitCode -eq 0 -and (Test-Path $job.TmpPath)) {
            try {
                if (Test-Path $job.OutPath) { Remove-Item $job.OutPath -Force -ErrorAction Stop }
                Move-Item $job.TmpPath $job.OutPath -Force -ErrorAction Stop
                $success = Test-Path $job.OutPath
            } catch { $success = $false }
        } else {
            $success = ($job.Process.ExitCode -eq 0) -and ($job.OutPath -ne $null) -and (Test-Path $job.OutPath)
        }

        if ($success) {
            $newSize = (Get-Item $job.OutPath).Length
            $newStr  = if ($newSize -ge 1MB) { "$([math]::Round($newSize/1MB,1)) MB" } else { "$([math]::Round($newSize/1KB,0)) KB" }
            $listView.Items[$idx].SubItems[1].Text = "Done"
            $listView.Items[$idx].SubItems[3].Text = $newStr
            $listView.Items[$idx].ForeColor = [System.Drawing.Color]::FromArgb(80, 210, 120)
            $script:successCount++
        } else {
            if ($job.TmpPath -and (Test-Path $job.TmpPath)) {
                Remove-Item $job.TmpPath -Force -ErrorAction SilentlyContinue
            }
            $listView.Items[$idx].SubItems[1].Text = "Failed"
            $listView.Items[$idx].ForeColor = [System.Drawing.Color]::FromArgb(255, 80, 70)
            $script:failCount++
        }

        $script:doneCount++
        $progressBar.Value = $script:doneCount
        $script:runningJob = $null
    }

    if ($script:runningJob -eq $null -and $script:jobQueue.Count -gt 0) {
        $nextIdx = $script:jobQueue.Dequeue()
        $statusLabel.Text = "Shrinking: $($files[$nextIdx].Name)"
        Start-ShrinkJob -Idx $nextIdx
        return
    }

    if ($script:runningJob -eq $null -and $script:jobQueue.Count -eq 0 -and $script:doneCount -ge $files.Count) {
        $timer.Stop()
        $statusLabel.Text = "Done -- $($script:successCount) shrunk, $($script:failCount) failed"
        $statusLabel.ForeColor = if ($script:failCount -gt 0) {
            [System.Drawing.Color]::FromArgb(255, 100, 80)
        } else {
            [System.Drawing.Color]::FromArgb(80, 210, 120)
        }
        $progressBar.Value = $files.Count
        $closeBtn.Visible  = $true
    }
})

$form.Add_Shown({
    $statusLabel.Text = "Shrinking: $($files[0].Name)"
    Start-ShrinkJob -Idx ($script:jobQueue.Dequeue())
    $timer.Start()
})

$form.Add_FormClosing({
    $timer.Stop()
    if ($script:runningJob -ne $null) {
        try { $script:runningJob.Process.Kill() } catch {}
        if ($script:runningJob.TmpPath -and (Test-Path $script:runningJob.TmpPath)) {
            Remove-Item $script:runningJob.TmpPath -Force -ErrorAction SilentlyContinue
        }
    }
})

[System.Windows.Forms.Application]::Run($form)
