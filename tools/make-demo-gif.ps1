$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationCore, WindowsBase, System.Drawing

$w = 920
$h = 560
$bgColor     = [System.Windows.Media.Color]::FromRgb(17, 17, 27)
$fgGreen     = [System.Windows.Media.Color]::FromRgb(166, 227, 161)
$fgCyan      = [System.Windows.Media.Color]::FromRgb(137, 180, 250)
$fgWhite     = [System.Windows.Media.Color]::FromRgb(205, 214, 244)
$fgYellow    = [System.Windows.Media.Color]::FromRgb(249, 226, 175)
$fgGray      = [System.Windows.Media.Color]::FromRgb(118, 122, 146)

$typeface = New-Object System.Windows.Media.Typeface("Consolas")
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$flow = [System.Windows.FlowDirection]::LeftToRight

$lines = New-Object System.Collections.ArrayList
function Add-Line([string]$text, $color, [bool]$bold = $false) {
    $null = $lines.Add([pscustomobject]@{ t = $text; c = $color; b = $bold })
}

Add-Line "" $fgGray
Add-Line "Windows PowerShell" $fgWhite $true
Add-Line "Copyright (C) Microsoft Corporation. All rights reserved." $fgGray
Add-Line "" $fgGray
Add-Line "PS C:\Users\LENOVO> .\android-rescue.ps1" $fgWhite $true
Add-Line "" $fgGray
Add-Line "Using adb: C:\Users\LENOVO\AppData\Local\Android\Sdk\platform-tools\adb.exe" $fgGreen
Add-Line "Device connected: R58M82XYZ0U  (Pixel 7)" $fgGreen
Add-Line "" $fgGray
Add-Line "=== 1/8 Device info ===" $fgCyan $true
Add-Line "  Model      Google Pixel 7" $fgWhite
Add-Line "  Android    14 (SDK 34)" $fgWhite
Add-Line "  Battery    52%" $fgWhite
Add-Line "" $fgGray
Add-Line "=== 2/8 Media & documents ===" $fgCyan $true
Add-Line "  DCIM ....... OK" $fgGreen
Add-Line "  Pictures ... OK" $fgGreen
Add-Line "  WhatsApp ... OK" $fgGreen
Add-Line "" $fgGray
Add-Line "=== 3/8 App list ===" $fgCyan $true
Add-Line "  apps_user.txt + apps_all.txt" $fgGreen
Add-Line "" $fgGray
Add-Line "=== 4/8 Contacts ===" $fgCyan $true
Add-Line "  blocked - Android privacy" $fgYellow
Add-Line "" $fgGray
Add-Line "=== 5/8 SMS ===" $fgCyan $true
Add-Line "  blocked - Android privacy" $fgYellow
Add-Line "" $fgGray
Add-Line "=== 6/8 Call log ===" $fgCyan $true
Add-Line "  blocked - Android privacy" $fgYellow
Add-Line "" $fgGray
Add-Line "=== 7/8 Screenshot ===" $fgCyan $true
Add-Line "  screen.png saved" $fgGreen
Add-Line "" $fgGray
Add-Line "=== 8/8 Package ===" $fgCyan $true
Add-Line "  backup_20260916_141233.zip created" $fgGreen
Add-Line "" $fgGray
Add-Line "Done. Files at .\backup_20260916_141233\" $fgGreen $true

function Draw-Frame([int]$reveal) {
    $dv = New-Object System.Windows.Media.DrawingVisual
    $dc = $dv.RenderOpen()
    $bgRect = [System.Windows.Rect]::new(0, 0, $w, $h)
    $bgBrush = [System.Windows.Media.SolidColorBrush]::new($bgColor)
    $dc.DrawRectangle($bgBrush, $null, $bgRect) | Out-Null

    $y = 26.0
    for ($i = 0; $i -lt [Math]::Min($reveal, $lines.Count); $i++) {
        $ln = $lines[$i]
        if ($ln.t -eq "") { $y += 5; continue }
        $size = if ($ln.b) { 17.0 } else { 15.0 }
        $ft = New-Object System.Windows.Media.FormattedText($ln.t, $culture, $flow,
            $typeface, $size, (New-Object System.Windows.Media.SolidColorBrush($ln.c)), 1.0)
        $dc.DrawText($ft, (New-Object System.Windows.Point(36, $y))) | Out-Null
        $y += 27
    }

    if ($reveal -lt $lines.Count) {
        $cursorY = $y - 10
        $cursorRect = [System.Windows.Rect]::new(36, $cursorY, 10, 2)
        $cursorBrush = [System.Windows.Media.SolidColorBrush]::new($fgYellow)
        $dc.DrawRectangle($cursorBrush, $null, $cursorRect) | Out-Null
    }

    $dc.Close()
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($w, $h, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($dv)
    return $rtb
}

$outDir = Join-Path $PSScriptRoot "..\images"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$enc = New-Object System.Windows.Media.Imaging.GifBitmapEncoder
$framePlan = New-Object System.Collections.ArrayList
foreach ($i in (5..$lines.Count)) { $null = $framePlan.Add($i) }
foreach ($h2 in 1..7) { $null = $framePlan.Add($lines.Count) }

foreach ($reveal in $framePlan) {
    $src = Draw-Frame $reveal
    $null = $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($src))
}

$gifPath = Join-Path $outDir "android-rescue-demo.gif"
$fs = [System.IO.File]::Create($gifPath)
try { $enc.Save($fs) } finally { $fs.Dispose() }

$bytes = [System.IO.File]::ReadAllBytes($gifPath)
$first = -1
for ($i = 0; $i -lt $bytes.Length - 256; $i++) {
    if ($bytes[$i] -eq 0x21 -and $bytes[$i+1] -eq 0xF9 -and $bytes[$i+2] -eq 0x04) { $first = $i; break }
}
if ($first -ge 0) {
    $loop = [byte[]]@(0x21, 0xFF, 0x0B, 0x4E, 0x45, 0x54, 0x53, 0x43, 0x41, 0x50, 0x45, 0x32, 0x2E, 0x30, 0x03, 0x01, 0x00, 0x00, 0x00)
    $newBytes = New-Object System.Collections.Generic.List[byte]
    foreach ($b in $bytes[0..($first - 1)]) { $newBytes.Add([byte]$b) }
    foreach ($b in $loop) { $newBytes.Add([byte]$b) }
    for ($i = $first; $i -lt $bytes.Length; $i++) { $newBytes.Add([byte]$bytes[$i]) }
    $bytes = $newBytes.ToArray()

    for ($i = 0; $i -lt $bytes.Length - 8; $i++) {
        if ($bytes[$i] -eq 0x21 -and $bytes[$i+1] -eq 0xF9 -and $bytes[$i+2] -eq 0x04) {
            $bytes[$i+4] = 0x64
            $bytes[$i+5] = 0x00
        }
    }
    [System.IO.File]::WriteAllBytes($gifPath, $bytes)
}

Write-Host "GIF written: $gifPath ($([math]::Round((Get-Item $gifPath).Length / 1kb)) KB, $($framePlan.Count) frames)"