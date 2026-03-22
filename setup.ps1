# setup.ps1 -- Shrink Menu one-click installer GUI
# Extracted by iexpress, copies files + registers context menu

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$dest = Join-Path $env:LOCALAPPDATA "ShrinkMenu"

# ======================================
#  UI
# ======================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Shrink Menu Setup"
$form.Size = New-Object System.Drawing.Size(440, 210)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(22, 22, 24)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.TopMost = $true

$title = New-Object System.Windows.Forms.Label
$title.Text = "Installing Shrink Menu..."
$title.Location = New-Object System.Drawing.Point(20, 14)
$title.Size = New-Object System.Drawing.Size(390, 28)
$title.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(255, 160, 60)
$form.Controls.Add($title)

$status = New-Object System.Windows.Forms.Label
$status.Text = "Starting..."
$status.Location = New-Object System.Drawing.Point(20, 52)
$status.Size = New-Object System.Drawing.Size(390, 22)
$status.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$form.Controls.Add($status)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(20, 82)
$progress.Size = New-Object System.Drawing.Size(390, 24)
$progress.Style = "Continuous"
$progress.Minimum = 0
$progress.Maximum = 100
$form.Controls.Add($progress)

$detail = New-Object System.Windows.Forms.Label
$detail.Text = ""
$detail.Location = New-Object System.Drawing.Point(20, 114)
$detail.Size = New-Object System.Drawing.Size(390, 20)
$detail.ForeColor = [System.Drawing.Color]::FromArgb(110, 110, 110)
$detail.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$form.Controls.Add($detail)

$closeBtn = New-Object System.Windows.Forms.Button
$closeBtn.Text = "Close"
$closeBtn.Location = New-Object System.Drawing.Point(325, 142)
$closeBtn.Size = New-Object System.Drawing.Size(85, 30)
$closeBtn.FlatStyle = "Flat"
$closeBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
$closeBtn.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 57)
$closeBtn.ForeColor = [System.Drawing.Color]::White
$closeBtn.Visible = $false
$closeBtn.Add_Click({ $form.Close() })
$form.Controls.Add($closeBtn)

function Set-Status($msg, $pct, $det) {
    $status.Text = $msg
    if ($pct -ge 0) { $progress.Value = [Math]::Min($pct, 100) }
    if ($null -ne $det) { $detail.Text = $det }
    $form.Refresh()
}

# ======================================
#  INSTALL LOGIC (timer-deferred so form renders first)
# ======================================

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 120
$script:started = $false

$timer.Add_Tick({
    if ($script:started) { return }
    $script:started = $true
    $timer.Stop()

    try {
        # -- Step 1: Create destination --
        Set-Status "Creating install folder..." 10 $dest
        if (-not (Test-Path $dest)) { New-Item -Path $dest -ItemType Directory -Force | Out-Null }

        # -- Step 2: Copy files --
        Set-Status "Copying files..." 25 ""
        $scriptDir = $PSScriptRoot
        if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.ScriptName }
        if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

        $files = @("shrink.ps1","launcher.vbs","install.ps1","uninstall.ps1","setup.ps1","setup.cmd")
        $copied = 0
        foreach ($f in $files) {
            $src = Join-Path $scriptDir $f
            if (Test-Path $src) {
                Copy-Item -Path $src -Destination $dest -Force
                $copied++
            }
        }
        Set-Status "Copying files..." 40 "Copied $copied file(s) to $dest"

        # -- Step 3: Register context menu --
        Set-Status "Registering context menu..." 65 ""
        $launcherPath = Join-Path $dest "launcher.vbs"
        $cmd = "wscript.exe `"$launcherPath`" `"%1`""
        $menuIcon = "shell32.dll,23"

        $extensions = @(
            '.jpg','.jpeg','.png','.webp','.bmp','.tiff','.tif','.gif','.heic','.heif','.avif',
            '.mp3','.wav','.flac','.aac','.ogg','.wma','.m4a','.opus','.aiff','.ape','.m4b','.weba',
            '.mp4','.mkv','.avi','.mov','.webm','.wmv','.flv','.ts','.m4v','.3gp'
        )

        foreach ($ext in $extensions) {
            $regPath = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\ShrinkMenu"
            if (Test-Path $regPath) { Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue }
            New-Item -Path $regPath -Force | Out-Null
            Set-ItemProperty -Path $regPath -Name "(Default)"        -Value "Shrink..."
            Set-ItemProperty -Path $regPath -Name "Icon"             -Value $menuIcon
            Set-ItemProperty -Path $regPath -Name "MultiSelectModel" -Value "Player"
            $cmdKey = "$regPath\command"
            New-Item -Path $cmdKey -Force | Out-Null
            Set-ItemProperty -Path $cmdKey -Name "(Default)" -Value $cmd
        }
        Set-Status "Registering context menu..." 90 "Registered $($extensions.Count) file types"

        # -- Step 4: Check tools --
        $missingTools = @()
        if (-not (Get-Command magick  -ErrorAction SilentlyContinue)) { $missingTools += "ImageMagick (for images)" }
        if (-not (Get-Command ffmpeg  -ErrorAction SilentlyContinue)) { $missingTools += "ffmpeg (for videos)" }

        # -- Done --
        $title.Text = "Shrink Menu installed!"
        $title.ForeColor = [System.Drawing.Color]::FromArgb(80, 210, 120)
        $progress.Value = 100

        if ($missingTools.Count -gt 0) {
            $status.Text = "Installed -- some tools missing (see below)"
            $status.ForeColor = [System.Drawing.Color]::FromArgb(255, 200, 80)
            $detail.Text = "Not found: " + ($missingTools -join ", ")
            $detail.ForeColor = [System.Drawing.Color]::FromArgb(255, 160, 60)
        } else {
            $status.Text = "Right-click any image or video to see 'Shrink...'"
            $status.ForeColor = [System.Drawing.Color]::FromArgb(80, 210, 120)
            $detail.Text = "ImageMagick + ffmpeg detected. All features ready."
            $detail.ForeColor = [System.Drawing.Color]::FromArgb(110, 110, 110)
        }

        $closeBtn.Visible = $true
        $closeBtn.Focus()

    } catch {
        $title.Text = "Installation failed"
        $title.ForeColor = [System.Drawing.Color]::FromArgb(255, 80, 70)
        $status.Text = $_.Exception.Message
        $detail.Text = "Try running install.ps1 manually from $dest"
        $closeBtn.Visible = $true
    }
})

$form.Add_Shown({ $timer.Start() })
[System.Windows.Forms.Application]::Run($form)
