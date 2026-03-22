# make-screenshots.ps1 -- Generate README screenshots for ShrinkMenu
# Builds mock forms identical to the real app and captures them with CopyFromScreen

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$here   = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$outDir = Join-Path $here "screenshots"
New-Item -Path $outDir -ItemType Directory -Force | Out-Null

function Capture-Form {
    param($Form, $Path)
    $Form.Show()
    $Form.BringToFront()
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 350
    [System.Windows.Forms.Application]::DoEvents()
    $loc = $Form.Location
    $bmp = New-Object System.Drawing.Bitmap($Form.Width, $Form.Height)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($loc.X, $loc.Y, 0, 0, [System.Drawing.Size]::new($Form.Width, $Form.Height))
    $g.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $Form.Close()
    $Form.Dispose()
    [System.Windows.Forms.Application]::DoEvents()
}

# -----------------------------------------------------------------------
#  SHARED COLORS
# -----------------------------------------------------------------------
$bgColor     = [System.Drawing.Color]::FromArgb(22, 22, 24)
$btnColor    = [System.Drawing.Color]::FromArgb(50, 50, 52)
$accentColor = [System.Drawing.Color]::FromArgb(255, 160, 60)
$dimColor    = [System.Drawing.Color]::FromArgb(110, 110, 110)
$whiteColor  = [System.Drawing.Color]::White
$darkText    = [System.Drawing.Color]::FromArgb(20, 20, 20)

function New-Label { param($Text,$X,$Y,$W,$H,$Color=$whiteColor,$FontSize=9,$Bold=$false)
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text; $l.Location = New-Object System.Drawing.Point($X,$Y)
    $l.Size = New-Object System.Drawing.Size($W,$H); $l.ForeColor = $Color
    $style = if ($Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $l.Font = New-Object System.Drawing.Font("Segoe UI", $FontSize, $style)
    return $l
}
function New-FlatBtn { param($Text,$X,$Y,$W,$H,$Bg,$Fg,$BorderColor,[bool]$Bold=$false)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text; $b.Location = New-Object System.Drawing.Point($X,$Y)
    $b.Size = New-Object System.Drawing.Size($W,$H); $b.FlatStyle = "Flat"
    $b.FlatAppearance.BorderSize = 1; $b.FlatAppearance.BorderColor = $BorderColor
    $b.BackColor = $Bg; $b.ForeColor = $Fg
    $style = if ($Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 9, $style)
    return $b
}
function Add-Separator { param($Form,$Y)
    $s = New-Object System.Windows.Forms.Panel
    $s.Location = New-Object System.Drawing.Point(20,$Y); $s.Size = New-Object System.Drawing.Size(320,1)
    $s.BackColor = [System.Drawing.Color]::FromArgb(55,55,57)
    $Form.Controls.Add($s)
}

# -----------------------------------------------------------------------
#  SCREENSHOT 1: PICKER (all 3 sections, resize enabled at 75%)
# -----------------------------------------------------------------------
function New-PickerForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Shrink"; $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedSingle"; $form.MaximizeBox = $false
    $form.BackColor = $bgColor; $form.ForeColor = $whiteColor
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.TopMost = $true

    $form.Controls.Add((New-Label "Shrink" 20 14 200 28 $accentColor 14 $true))
    $yPos = 50

    # Output toggle
    $form.Controls.Add((New-Label "Output" 20 ($yPos+2) 55 22 $dimColor 8))
    $form.Controls.Add((New-FlatBtn "Overwrite" 78 ($yPos-1) 90 26 $accentColor $darkText $accentColor $true))
    $form.Controls.Add((New-FlatBtn "Save copy" 172 ($yPos-1) 90 26 $btnColor $whiteColor ([System.Drawing.Color]::FromArgb(70,70,70))))
    $yPos += 34

    # ---- IMAGES ----
    $yPos += 4; Add-Separator $form $yPos; $yPos += 8
    $form.Controls.Add((New-Label "Images  (3 files)" 20 $yPos 320 18 $dimColor 8))
    $yPos += 22

    $form.Controls.Add((New-Label "Quality" 20 ($yPos+4) 52 20 $whiteColor 9))
    $form.Controls.Add((New-Label "82%" 300 ($yPos+4) 34 20 $accentColor 9 $true))

    $slider = New-Object System.Windows.Forms.TrackBar
    $slider.Location = New-Object System.Drawing.Point(72, $yPos); $slider.Size = New-Object System.Drawing.Size(224,26)
    $slider.Minimum = 10; $slider.Maximum = 100; $slider.Value = 82; $slider.TickFrequency = 10
    $slider.TickStyle = "BottomRight"; $slider.BackColor = $bgColor
    $form.Controls.Add($slider); $yPos += 30

    $form.Controls.Add((New-Label "Format" 20 $yPos 320 18 $dimColor 8)); $yPos += 20
    $fmtOpts = @("Same","JPEG","PNG","WebP"); $fmtX = 20
    for ($fi = 0; $fi -lt 4; $fi++) {
        $bg = if ($fi -eq 0) { $accentColor } else { $btnColor }
        $fg = if ($fi -eq 0) { $darkText } else { $whiteColor }
        $bc = if ($fi -eq 0) { $accentColor } else { [System.Drawing.Color]::FromArgb(70,70,70) }
        $form.Controls.Add((New-FlatBtn $fmtOpts[$fi] $fmtX $yPos 76 28 $bg $fg $bc ($fi -eq 0)))
        $fmtX += 81
    }
    $yPos += 34

    # Resize (enabled state, showing 75%)
    $form.Controls.Add((New-Label "Resize" 20 ($yPos+4) 52 20 $whiteColor 9))
    $rzChk = New-Object System.Windows.Forms.CheckBox
    $rzChk.Text = ""; $rzChk.Location = New-Object System.Drawing.Point(72,($yPos+3))
    $rzChk.Size = New-Object System.Drawing.Size(20,22); $rzChk.BackColor = $bgColor
    $rzChk.Checked = $true
    $form.Controls.Add($rzChk)
    $form.Controls.Add((New-Label "1920 x 1080  (first file)" 95 ($yPos+5) 240 18 $dimColor 8))
    $yPos += 28

    foreach ($ctrl in @(
        @{T="NUD"; X=20; Y=$yPos; W=72; H=24; V=1440},
        @{T="LBL"; X=96; Y=($yPos+4); W=12; H=18; Text="x"},
        @{T="NUD"; X=110; Y=$yPos; W=72; H=24; V=810}
    )) {
        if ($ctrl.T -eq "NUD") {
            $n = New-Object System.Windows.Forms.NumericUpDown
            $n.Location = New-Object System.Drawing.Point($ctrl.X,$ctrl.Y); $n.Size = New-Object System.Drawing.Size($ctrl.W,$ctrl.H)
            $n.Minimum = 1; $n.Maximum = 9999; $n.Value = $ctrl.V
            $n.BackColor = [System.Drawing.Color]::FromArgb(50,50,52); $n.ForeColor = $whiteColor
            $form.Controls.Add($n)
        } else {
            $form.Controls.Add((New-Label $ctrl.Text $ctrl.X $ctrl.Y $ctrl.W $ctrl.H $dimColor 9))
        }
    }
    $pctNUD = New-Object System.Windows.Forms.NumericUpDown
    $pctNUD.Location = New-Object System.Drawing.Point(196,$yPos); $pctNUD.Size = New-Object System.Drawing.Size(62,24)
    $pctNUD.Minimum = 1; $pctNUD.Maximum = 500; $pctNUD.Value = 75
    $pctNUD.BackColor = [System.Drawing.Color]::FromArgb(50,50,52); $pctNUD.ForeColor = $accentColor
    $form.Controls.Add($pctNUD)
    $form.Controls.Add((New-Label "%" 261 ($yPos+4) 18 18 $dimColor 9))
    $yPos += 32

    $shrImgBtn = New-Object System.Windows.Forms.Button
    $shrImgBtn.Text = "Shrink 3 Images"; $shrImgBtn.Location = New-Object System.Drawing.Point(20,$yPos)
    $shrImgBtn.Size = New-Object System.Drawing.Size(320,34); $shrImgBtn.FlatStyle = "Flat"
    $shrImgBtn.FlatAppearance.BorderSize = 0; $shrImgBtn.BackColor = [System.Drawing.Color]::FromArgb(70,46,14)
    $shrImgBtn.ForeColor = $accentColor
    $shrImgBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($shrImgBtn); $yPos += 40

    # ---- AUDIO ----
    $yPos += 4; Add-Separator $form $yPos; $yPos += 8
    $form.Controls.Add((New-Label "Audio  (2 files)" 20 $yPos 320 18 $dimColor 8)); $yPos += 22

    $audioPresets = @(
        @{ L = "Voice    64 kbps mono";   S = "voice memos, podcasts -- tiny" }
        @{ L = "Small   128 kbps";         S = "general use  ~70% smaller than WAV/FLAC" }
        @{ L = "Good    192 kbps";         S = "music quality" }
        @{ L = "HQ      320 kbps";         S = "max MP3 -- best for lossless source" }
        @{ L = "Opus     96 kbps";         S = "modern codec, very small  -> .opus" }
    )
    foreach ($ap in $audioPresets) {
        $ab = New-Object System.Windows.Forms.Button
        $ab.Text = $ap.L; $ab.Location = New-Object System.Drawing.Point(20,$yPos)
        $ab.Size = New-Object System.Drawing.Size(320,30); $ab.FlatStyle = "Flat"
        $ab.FlatAppearance.BorderSize = 0; $ab.BackColor = $btnColor; $ab.ForeColor = $whiteColor
        $ab.TextAlign = "MiddleLeft"; $ab.Padding = New-Object System.Windows.Forms.Padding(10,0,0,0)
        $ab.Font = New-Object System.Drawing.Font("Segoe UI", 9)
        $form.Controls.Add($ab)
        $form.Controls.Add((New-Label $ap.S 32 ($yPos+16) 290 14 $dimColor 7))
        $yPos += 36
    }

    # ---- VIDEOS ----
    $yPos += 4; Add-Separator $form $yPos; $yPos += 8
    $form.Controls.Add((New-Label "Videos  (1 file)" 20 $yPos 320 18 $dimColor 8)); $yPos += 22

    $videoPresets = @(
        @{ L = "1080p   High quality";  S = "1920x? AR preserved  ~50% smaller" }
        @{ L = "720p    Balanced";       S = "1280x? AR preserved  ~70% smaller" }
        @{ L = "480p    Small file";     S = "854x?  AR preserved  ~85% smaller" }
        @{ L = "Web     Fast download";  S = "720p, fast-start, AR preserved" }
        @{ L = "Discord Fits 8 MB";      S = "480p, targets 8MB, AR preserved" }
    )
    foreach ($vp in $videoPresets) {
        $vb = New-Object System.Windows.Forms.Button
        $vb.Text = $vp.L; $vb.Location = New-Object System.Drawing.Point(20,$yPos)
        $vb.Size = New-Object System.Drawing.Size(320,30); $vb.FlatStyle = "Flat"
        $vb.FlatAppearance.BorderSize = 0; $vb.BackColor = $btnColor; $vb.ForeColor = $whiteColor
        $vb.TextAlign = "MiddleLeft"; $vb.Padding = New-Object System.Windows.Forms.Padding(10,0,0,0)
        $vb.Font = New-Object System.Drawing.Font("Segoe UI", 9)
        $form.Controls.Add($vb)
        $form.Controls.Add((New-Label $vp.S 32 ($yPos+16) 290 14 $dimColor 7))
        $yPos += 36
    }

    $yPos += 2
    $form.Controls.Add((New-Label "Custom" 20 ($yPos+5) 58 20 $whiteColor 9))
    $cNUD = New-Object System.Windows.Forms.NumericUpDown
    $cNUD.Location = New-Object System.Drawing.Point(80,$yPos); $cNUD.Size = New-Object System.Drawing.Size(80,24)
    $cNUD.Minimum = 144; $cNUD.Maximum = 4320; $cNUD.Value = 720
    $cNUD.BackColor = [System.Drawing.Color]::FromArgb(50,50,52); $cNUD.ForeColor = $whiteColor
    $form.Controls.Add($cNUD)
    $form.Controls.Add((New-Label "px height  AR preserved" 164 ($yPos+5) 160 20 $dimColor 8))
    $cBtn = New-Object System.Windows.Forms.Button
    $cBtn.Text = "Shrink custom"; $cBtn.Location = New-Object System.Drawing.Point(20,($yPos+30))
    $cBtn.Size = New-Object System.Drawing.Size(320,28); $cBtn.FlatStyle = "Flat"
    $cBtn.FlatAppearance.BorderSize = 0; $cBtn.BackColor = $btnColor; $cBtn.ForeColor = $whiteColor
    $cBtn.TextAlign = "MiddleLeft"; $cBtn.Padding = New-Object System.Windows.Forms.Padding(10,0,0,0)
    $form.Controls.Add($cBtn)
    $yPos += 64

    $form.ClientSize = New-Object System.Drawing.Size(360, ($yPos + 10))
    return $form
}

# -----------------------------------------------------------------------
#  SCREENSHOT 2: PROGRESS (mid-run)
#  SCREENSHOT 3: DONE
# -----------------------------------------------------------------------
function New-ProgressForm {
    param([bool]$Done = $false)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Shrink"; $form.Size = New-Object System.Drawing.Size(575,440)
    $form.StartPosition = "CenterScreen"; $form.FormBorderStyle = "FixedSingle"
    $form.MaximizeBox = $false; $form.BackColor = $bgColor; $form.ForeColor = $whiteColor
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9); $form.TopMost = $true

    $tl = New-Object System.Windows.Forms.Label
    $tl.Text = "Shrinking 3 file(s)  --  Images  Quality 82%  -> JPEG"
    $tl.Location = New-Object System.Drawing.Point(20,16); $tl.Size = New-Object System.Drawing.Size(520,26)
    $tl.Font = New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
    $tl.ForeColor = $accentColor; $form.Controls.Add($tl)

    $pb = New-Object System.Windows.Forms.ProgressBar
    $pb.Location = New-Object System.Drawing.Point(20,52); $pb.Size = New-Object System.Drawing.Size(520,24)
    $pb.Style = "Continuous"; $pb.Minimum = 0; $pb.Maximum = 3
    $pb.Value = if ($Done) { 3 } else { 1 }; $form.Controls.Add($pb)

    $sl = New-Object System.Windows.Forms.Label
    $sl.Location = New-Object System.Drawing.Point(20,84); $sl.Size = New-Object System.Drawing.Size(520,20)
    if ($Done) {
        $sl.Text = "Done -- 3 shrunk, 0 failed"
        $sl.ForeColor = [System.Drawing.Color]::FromArgb(80,210,120)
    } else {
        $sl.Text = "Shrinking: photo_sunset.jpg"
        $sl.ForeColor = [System.Drawing.Color]::FromArgb(160,160,160)
    }
    $form.Controls.Add($sl)

    $lv = New-Object System.Windows.Forms.ListView
    $lv.Location = New-Object System.Drawing.Point(20,112); $lv.Size = New-Object System.Drawing.Size(520,238)
    $lv.View = "Details"; $lv.FullRowSelect = $true
    $lv.BackColor = [System.Drawing.Color]::FromArgb(40,40,42); $lv.ForeColor = $whiteColor
    $lv.Font = New-Object System.Drawing.Font("Consolas",9); $lv.BorderStyle = "None"
    $lv.HeaderStyle = "Nonclickable"; $lv.GridLines = $false
    $lv.Columns.Add("File",300) | Out-Null; $lv.Columns.Add("Status",80) | Out-Null
    $lv.Columns.Add("Before",66) | Out-Null; $lv.Columns.Add("After",64) | Out-Null

    $rows = if ($Done) {
        @(
            @{ N="photo_beach.jpg";    St="Done";    B="2.4 MB"; A="790 KB"; C=[System.Drawing.Color]::FromArgb(80,210,120) }
            @{ N="photo_sunset.jpg";   St="Done";    B="3.1 MB"; A="1.0 MB"; C=[System.Drawing.Color]::FromArgb(80,210,120) }
            @{ N="background.png";     St="Done";    B="4.1 MB"; A="1.2 MB"; C=[System.Drawing.Color]::FromArgb(80,210,120) }
        )
    } else {
        @(
            @{ N="photo_beach.jpg";    St="Done";    B="2.4 MB"; A="790 KB"; C=[System.Drawing.Color]::FromArgb(80,210,120) }
            @{ N="photo_sunset.jpg";   St="Working"; B="3.1 MB"; A="";       C=[System.Drawing.Color]::FromArgb(255,215,80) }
            @{ N="background.png";     St="Queued";  B="4.1 MB"; A="";       C=[System.Drawing.Color]::FromArgb(130,130,130) }
        )
    }
    foreach ($row in $rows) {
        $item = New-Object System.Windows.Forms.ListViewItem($row.N)
        $item.SubItems.Add($row.St) | Out-Null
        $item.SubItems.Add($row.B)  | Out-Null
        $item.SubItems.Add($row.A)  | Out-Null
        $item.ForeColor = $row.C
        $lv.Items.Add($item) | Out-Null
    }
    $form.Controls.Add($lv)

    if ($Done) {
        $cb = New-Object System.Windows.Forms.Button
        $cb.Text = "Close"; $cb.Location = New-Object System.Drawing.Point(435,362)
        $cb.Size = New-Object System.Drawing.Size(105,32); $cb.FlatStyle = "Flat"
        $cb.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70,70,70)
        $cb.BackColor = [System.Drawing.Color]::FromArgb(55,55,57); $cb.ForeColor = $whiteColor
        $form.Controls.Add($cb)
    }

    return $form
}

# -----------------------------------------------------------------------
#  RUN
# -----------------------------------------------------------------------
Write-Host "Generating screenshots..." -ForegroundColor Yellow

$pickerPath = Join-Path $outDir "picker.png"
Capture-Form -Form (New-PickerForm) -Path $pickerPath
Write-Host "  [1/3] picker.png" -ForegroundColor Green

$progressPath = Join-Path $outDir "progress.png"
Capture-Form -Form (New-ProgressForm -Done $false) -Path $progressPath
Write-Host "  [2/3] progress.png" -ForegroundColor Green

$donePath = Join-Path $outDir "done.png"
Capture-Form -Form (New-ProgressForm -Done $true) -Path $donePath
Write-Host "  [3/3] done.png" -ForegroundColor Green

Write-Host ""
Write-Host "Done. Screenshots saved to: $outDir" -ForegroundColor Green
