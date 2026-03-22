# shrink.ps1 -- Shrink images and videos with GUI  v1.0.0
# Images: quality slider + format (JPEG/PNG/WebP/same)
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
$videoPaths = @($allPaths | Where-Object { $videoExts -contains ([IO.Path]::GetExtension($_).ToLower()) })

$hasImages = ($magickCmd -ne $null) -and ($imagePaths.Count -gt 0)
$hasVideos = ($ffmpegCmd -ne $null) -and ($videoPaths.Count -gt 0)

# Error: no supported files at all
if ($imagePaths.Count -eq 0 -and $videoPaths.Count -eq 0) {
    $allExts = (@($allPaths | ForEach-Object { [IO.Path]::GetExtension($_).ToLower() } | Sort-Object -Unique)) -join ", "
    $msgForm = New-Object System.Windows.Forms.Form
    $msgForm.TopMost = $true; $msgForm.WindowState = "Minimized"; $msgForm.Show()
    [System.Windows.Forms.MessageBox]::Show($msgForm,
        "No supported files.`n`nSupported image types: jpg png webp bmp tiff gif heic avif`nSupported video types: mp4 mkv avi mov webm wmv flv ts`n`nSelected extensions: $allExts",
        "Shrink", "OK", "Information") | Out-Null
    $msgForm.Close(); exit 0
}

# Error: tools missing
if (-not $hasImages -and -not $hasVideos) {
    $missing = @()
    if ($imagePaths.Count -gt 0 -and -not $magickCmd)  { $missing += "ImageMagick  (images -- imagemagick.org)" }
    if ($videoPaths.Count -gt 0 -and -not $ffmpegCmd)   { $missing += "ffmpeg  (videos -- ffmpeg.org)" }
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

$script:pickedAction  = $null
$script:imageQuality  = 82
$script:imageFormat   = "same"

# ======================================
#  IMAGES SECTION
# ======================================

if ($hasImages) {
    $yPos += 4

    $sep1 = New-Object System.Windows.Forms.Panel
    $sep1.Location = New-Object System.Drawing.Point(20, $yPos)
    $sep1.Size = New-Object System.Drawing.Size(260, 1)
    $sep1.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 57)
    $pickerForm.Controls.Add($sep1)
    $yPos += 8

    $imgHdr = New-Object System.Windows.Forms.Label
    $imgHdr.Text = "Images  ($($imagePaths.Count) file$(if($imagePaths.Count -ne 1){'s'}))"
    $imgHdr.Location = New-Object System.Drawing.Point(20, $yPos)
    $imgHdr.Size = New-Object System.Drawing.Size(260, 18)
    $imgHdr.ForeColor = $dimColor
    $imgHdr.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $pickerForm.Controls.Add($imgHdr)
    $yPos += 22

    # Quality row
    $qualLabel = New-Object System.Windows.Forms.Label
    $qualLabel.Text = "Quality"
    $qualLabel.Location = New-Object System.Drawing.Point(20, ($yPos + 4))
    $qualLabel.Size = New-Object System.Drawing.Size(50, 20)
    $qualLabel.ForeColor = $whiteColor
    $qualLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $pickerForm.Controls.Add($qualLabel)

    $qualVal = New-Object System.Windows.Forms.Label
    $qualVal.Text = "82%"
    $qualVal.Location = New-Object System.Drawing.Point(242, ($yPos + 4))
    $qualVal.Size = New-Object System.Drawing.Size(32, 20)
    $qualVal.ForeColor = $accentColor
    $qualVal.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $qualVal.TextAlign = "MiddleRight"
    $pickerForm.Controls.Add($qualVal)

    $slider = New-Object System.Windows.Forms.TrackBar
    $slider.Location = New-Object System.Drawing.Point(68, $yPos)
    $slider.Size = New-Object System.Drawing.Size(170, 26)
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

    # Format row
    $fmtLabel = New-Object System.Windows.Forms.Label
    $fmtLabel.Text = "Format"
    $fmtLabel.Location = New-Object System.Drawing.Point(20, ($yPos + 4))
    $fmtLabel.Size = New-Object System.Drawing.Size(50, 20)
    $fmtLabel.ForeColor = $whiteColor
    $fmtLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $pickerForm.Controls.Add($fmtLabel)

    $fmtBtns   = @{}
    $fmtOpts   = @("Same","JPEG","PNG","WebP")
    $fmtKeys   = @("same","jpg","png","webp")
    $fmtX      = 70

    for ($fi = 0; $fi -lt $fmtOpts.Count; $fi++) {
        $fk   = $fmtKeys[$fi]
        $fbtn = New-Object System.Windows.Forms.Button
        $fbtn.Text = $fmtOpts[$fi]
        $fbtn.Location = New-Object System.Drawing.Point($fmtX, $yPos)
        $fbtn.Size = New-Object System.Drawing.Size(50, 26)
        $fbtn.FlatStyle = "Flat"
        $fbtn.FlatAppearance.BorderSize = 1
        $fbtn.Tag = $fk
        if ($fi -eq 0) {
            $fbtn.BackColor = $accentColor
            $fbtn.ForeColor = $darkText
            $fbtn.FlatAppearance.BorderColor = $accentColor
            $fbtn.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
        } else {
            $fbtn.BackColor = $btnColor
            $fbtn.ForeColor = $whiteColor
            $fbtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70,70,70)
            $fbtn.Font = New-Object System.Drawing.Font("Segoe UI", 8)
        }
        $fbtn.Add_Click({
            $script:imageFormat = $this.Tag
            foreach ($b in $fmtBtns.Values) {
                $b.BackColor = $btnColor; $b.ForeColor = $whiteColor
                $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70,70,70)
                $b.Font = New-Object System.Drawing.Font("Segoe UI", 8)
            }
            $this.BackColor = $accentColor; $this.ForeColor = $darkText
            $this.FlatAppearance.BorderColor = $accentColor
            $this.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
        })
        $fmtBtns[$fk] = $fbtn
        $pickerForm.Controls.Add($fbtn)
        $fmtX += 54
    }
    $yPos += 34

    # Shrink Images button
    $shrinkImgBtn = New-Object System.Windows.Forms.Button
    $shrinkImgBtn.Text = "Shrink $($imagePaths.Count) Image$(if($imagePaths.Count -ne 1){'s'})"
    $shrinkImgBtn.Location = New-Object System.Drawing.Point(20, $yPos)
    $shrinkImgBtn.Size = New-Object System.Drawing.Size(260, 34)
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
#  VIDEOS SECTION
# ======================================

if ($hasVideos) {
    $yPos += 4

    $sep2 = New-Object System.Windows.Forms.Panel
    $sep2.Location = New-Object System.Drawing.Point(20, $yPos)
    $sep2.Size = New-Object System.Drawing.Size(260, 1)
    $sep2.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 57)
    $pickerForm.Controls.Add($sep2)
    $yPos += 8

    $vidHdr = New-Object System.Windows.Forms.Label
    $vidHdr.Text = "Videos  ($($videoPaths.Count) file$(if($videoPaths.Count -ne 1){'s'}))"
    $vidHdr.Location = New-Object System.Drawing.Point(20, $yPos)
    $vidHdr.Size = New-Object System.Drawing.Size(260, 18)
    $vidHdr.ForeColor = $dimColor
    $vidHdr.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $pickerForm.Controls.Add($vidHdr)
    $yPos += 22

    $presets = @(
        @{ Label = "1080p   High quality";  Key = "1080p";   Sub = "Full HD  ~50% smaller" }
        @{ Label = "720p    Balanced";       Key = "720p";    Sub = "HD  ~70% smaller" }
        @{ Label = "480p    Small file";     Key = "480p";    Sub = "SD  ~85% smaller" }
        @{ Label = "Web     Fast download";  Key = "web";     Sub = "720p, fast-start optimized" }
        @{ Label = "Discord Fits 8 MB";      Key = "discord"; Sub = "Targets Discord free limit" }
    )

    foreach ($preset in $presets) {
        $pKey  = $preset.Key
        $pSub  = $preset.Sub
        $pbtn  = New-Object System.Windows.Forms.Button
        $pbtn.Text = $preset.Label
        $pbtn.Location = New-Object System.Drawing.Point(20, $yPos)
        $pbtn.Size = New-Object System.Drawing.Size(260, 30)
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
        $subLabel.Size = New-Object System.Drawing.Size(230, 14)
        $subLabel.ForeColor = $dimColor
        $subLabel.Font = New-Object System.Drawing.Font("Segoe UI", 7)
        $pickerForm.Controls.Add($subLabel)

        $yPos += 36
    }
}

$pickerForm.ClientSize = New-Object System.Drawing.Size(300, ($yPos + 10))
[System.Windows.Forms.Application]::Run($pickerForm)

if (-not $script:pickedAction) { exit 0 }

$isImageJob  = ($script:pickedAction -eq "images")
$isVideoJob  = ($script:pickedAction -like "video:*")
$videoPreset = if ($isVideoJob) { $script:pickedAction.Substring(6) } else { $null }
$saveMode    = $script:saveMode

# ======================================
#  BUILD FILE LIST FOR CHOSEN ACTION
# ======================================

$files = @()
if ($isImageJob) {
    foreach ($p in $imagePaths) { if (Test-Path $p -PathType Leaf) { $files += Get-Item $p } }
} elseif ($isVideoJob) {
    foreach ($p in $videoPaths) { if (Test-Path $p -PathType Leaf) { $files += Get-Item $p } }
}

if ($files.Count -eq 0) { exit 0 }

$actionLabel = if ($isImageJob) {
    $fmtNote = if ($script:imageFormat -ne "same") { " -> " + $script:imageFormat.ToUpper() } else { "" }
    "Images  Quality $($script:imageQuality)%$fmtNote"
} else {
    "Videos  $videoPreset"
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

        # PNG is lossless -- map quality to color quantization
        $isPngOut = ($outExt -eq ".png")
        if ($isPngOut) {
            $pngColors = if ($qual -ge 90) { $null } elseif ($qual -ge 70) { 256 } elseif ($qual -ge 50) { 128 } else { 64 }
            if ($pngColors) {
                $pinfo.Arguments = "`"$inPath`" -strip -colors $pngColors `"$dest`""
            } else {
                $pinfo.Arguments = "`"$inPath`" -strip `"$dest`""
            }
        } else {
            $pinfo.Arguments = "`"$inPath`" -quality $qual `"$dest`""
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
