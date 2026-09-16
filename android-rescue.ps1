param(
    [string]$OutDir = "",
    [switch]$SkipMedia,
    [switch]$SkipApps,
    [switch]$SkipContacts,
    [switch]$SkipSms,
    [switch]$SkipCallLog,
    [switch]$SkipScreenshot,
    [switch]$SkipZip,
    [switch]$FullBasebackup
)

$ErrorActionPreference = "Stop"

function Find-Adb {
    $candidates = @(
        "adb"
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
        "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe"
        "C:\platform-tools\adb.exe"
    )
    foreach ($c in $candidates) {
        $cmd = Get-Command $c -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
        if (Test-Path -LiteralPath $c) { return $c }
    }
    return $null
}

function Get-Prop([string]$key) {
    try { return (& $adb shell getprop $key).Trim() } catch { return "" }
}

function Query-Content([string]$uri, [string]$projection = "") {
    $cmd = "content query --uri $uri"
    if ($projection) { $cmd += " --projection $projection" }
    return & $adb exec-out shell $cmd
}

$adb = Find-Adb
if (-not $adb) {
    Write-Host "adb not found. Download platform-tools:" -ForegroundColor Yellow
    Write-Host "  https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -ForegroundColor Cyan
    Write-Host "Unzip to C:\platform-tools and re-run." -ForegroundColor Yellow
    exit 1
}
Write-Host "Using adb: $adb" -ForegroundColor Green

& $adb start-server 2>$null | Out-Null
$devices = & $adb devices | Select-String "`tdevice$"
if (-not $devices) {
    Write-Host "No device connected." -ForegroundColor Red
    Write-Host "1) Settings > About phone > tap 'Build number' 7 times to unlock Developer Options." -ForegroundColor Yellow
    Write-Host "2) Turn on 'USB debugging' in Developer Options." -ForegroundColor Yellow
    Write-Host "3) Connect via USB and accept the RSA dialog on the phone." -ForegroundColor Yellow
    exit 1
}
$serial = $devices[0].Line.Split("`t")[0]
Write-Host "Device connected: $serial" -ForegroundColor Green

if (-not $OutDir) { $OutDir = "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')" }
$out = Join-Path (Get-Location) $OutDir
New-Item -ItemType Directory -Path $out -Force | Out-Null

$summary = @()

Write-Host "`n=== 1/8 Device info ===" -ForegroundColor Cyan
$info = @(
    "Model:          $(Get-Prop ro.product.model) $(Get-Prop ro.product.brand)"
    "Android:        $(Get-Prop ro.build.version.release) (SDK $(Get-Prop ro.build.version.sdk))"
    "Serial:         $serial"
    "Uptime:         $((& $adb shell uptime).Trim())"
)
$batt = (& $adb shell dumpsys battery 2>$null | Select-String "level:")
if ($batt) { $info += "Battery:        $($batt.ToString().Trim())%" }
$storage = (& $adb shell df -h /data 2>$null | Select-Object -Last 1)
if ($storage) { $info += "Storage:        $($storage.ToString().Trim() -replace '\s+', '  ')" }
$info | ForEach-Object { Write-Host $_ }
$info | Set-Content -LiteralPath (Join-Path $out "device_info.txt") -Encoding UTF8
$summary += "device_info.txt : OK"

Write-Host "`n=== 2/8 Media & documents ===" -ForegroundColor Cyan
$dirs = [ordered]@{
    "DCIM"        = "/sdcard/DCIM"
    "Pictures"    = "/sdcard/Pictures"
    "Screenshots" = "/sdcard/DCIM/Screenshots"
    "Download"    = "/sdcard/Download"
    "Documents"   = "/sdcard/Documents"
    "Music"       = "/sdcard/Music"
    "Movies"      = "/sdcard/Movies"
    "WhatsApp"    = "/sdcard/WhatsApp"
    "Telegram"    = "/sdcard/Telegram"
    "VOIP"        = "/sdcard/VOIP"
}
foreach ($name in $dirs.Keys) {
    if ($SkipMedia -and $name -notin @("Download", "Documents")) { continue }
    $local = Join-Path $out $name
    Write-Host -NoNewline "  $name ... "
    try {
        & $adb pull $($dirs[$name]) $local 2>&1 | Out-Null
        $summary += "$name : OK"
        Write-Host "OK" -ForegroundColor Green
    } catch {
        $summary += "$name : n/a"
        Write-Host "n/a" -ForegroundColor DarkGray
    }
}

Write-Host "`n=== 3/8 App list ===" -ForegroundColor Cyan
if ($SkipApps) { Write-Host "  skipped" }
else {
    & $adb shell pm list packages -3 2>$null | ForEach-Object { $_.Replace("package:", "") } |
        Where-Object { $_ } | Set-Content -LiteralPath (Join-Path $out "apps_user.txt") -Encoding UTF8
    & $adb shell pm list packages 2>$null | ForEach-Object { $_.Replace("package:", "") } |
        Where-Object { $_ } | Set-Content -LiteralPath (Join-Path $out "apps_all.txt") -Encoding UTF8
    $summary += "apps_user.txt : OK"
    $summary += "apps_all.txt : OK"
    Write-Host "  apps_user.txt + apps_all.txt" -ForegroundColor Green
}

Write-Host "`n=== 4/8 Contacts ===" -ForegroundColor Cyan
if ($SkipContacts) { Write-Host "  skipped" }
else {
    try {
        $rows = Query-Content "content://contacts/phones" "display_name,number"
        if ($rows -and $rows.Count -gt 1) {
            $rows | Set-Content -LiteralPath (Join-Path $out "contacts.txt") -Encoding UTF8
            $summary += "contacts.txt : OK ($($rows.Count - 1) rows)"
            Write-Host "  saved $($rows.Count - 1) contacts" -ForegroundColor Green
        } else {
            $summary += "contacts.txt : blocked"
            Write-Host "  permission blocked by Android" -ForegroundColor Yellow
        }
    } catch { $summary += "contacts.txt : failed" ; Write-Host "  failed" -ForegroundColor Red }
}

Write-Host "`n=== 5/8 SMS ===" -ForegroundColor Cyan
if ($SkipSms) { Write-Host "  skipped" }
else {
    try {
        $sms = Query-Content "content://sms" "address,date,body"
        if ($sms -and $sms.Count -gt 1) {
            $sms | Set-Content -LiteralPath (Join-Path $out "sms.txt") -Encoding UTF8
            $summary += "sms.txt : OK ($($sms.Count - 1) rows)"
            Write-Host "  saved SMS log" -ForegroundColor Green
        } else {
            $summary += "sms.txt : blocked"
            Write-Host "  permission blocked (needs root or Samsung Smart Switch)" -ForegroundColor Yellow
        }
    } catch { $summary += "sms.txt : failed" ; Write-Host "  failed" -ForegroundColor Red }
}

Write-Host "`n=== 6/8 Call log ===" -ForegroundColor Cyan
if ($SkipCallLog) { Write-Host "  skipped" }
else {
    try {
        $calls = Query-Content "content://call_log/calls" "number,date,duration,type"
        if ($calls -and $calls.Count -gt 1) {
            $calls | Set-Content -LiteralPath (Join-Path $out "call_log.txt") -Encoding UTF8
            $summary += "call_log.txt : OK ($($calls.Count - 1) rows)"
            Write-Host "  saved call log" -ForegroundColor Green
        } else {
            $summary += "call_log.txt : blocked"
            Write-Host "  permission blocked" -ForegroundColor Yellow
        }
    } catch { $summary += "call_log.txt : failed" ; Write-Host "  failed" -ForegroundColor Red }
}

Write-Host "`n=== 7/8 Screenshot ===" -ForegroundColor Cyan
if ($SkipScreenshot) { Write-Host "  skipped" }
else {
    $shot = Join-Path $out "screen.png"
    try {
        Start-Process -FilePath $adb -ArgumentList 'exec-out','screencap','-p' -RedirectStandardOutput $shot -NoNewWindow -Wait
        if (Test-Path $shot) { $summary += "screen.png : OK" ; Write-Host "  saved screen.png" -ForegroundColor Green }
        else { $summary += "screen.png : failed" ; Write-Host "  failed (screen may be locked)" -ForegroundColor Red }
    } catch { $summary += "screen.png : failed" ; Write-Host "  failed" -ForegroundColor Red }
}

if ($FullBasebackup) {
    Write-Host "`n=== 7.5/8 Full Android backup ===" -ForegroundColor Cyan
    Write-Host "  Unlock the phone and tap BACK UP when prompted." -ForegroundColor Yellow
    $abFile = Join-Path $out "full_backup.ab"
    & $adb backup -apk -shared -all -f $abFile
    if (Test-Path $abFile) { $summary += "full_backup.ab : OK" }
}

Write-Host "`n=== 8/8 Package ===" -ForegroundColor Cyan
$reportLines = @(
    "Android Rescue Report"
    "Device:      $serial"
    "Model:       $(Get-Prop ro.product.model)"
    "Created at:  $(Get-Date)"
    ""
    "--- Results ---"
) + $summary
$reportLines | Set-Content -LiteralPath (Join-Path $out "REPORT.txt") -Encoding UTF8
$reportLines | ForEach-Object { Write-Host $_ }

$here = Get-Location
Set-Location $here
if (-not $SkipZip) {
    Write-Host "  Zipping ..." -ForegroundColor Cyan
    Compress-Archive -Path $out -DestinationPath "$out.zip" -Force
    Write-Host "  Created $out.zip" -ForegroundColor Green
}

Write-Host "`nDone. Backup at: $out" -ForegroundColor Green
Write-Host "Tips: SMS blocked? Use Samsung Smart Switch or Google backup. For a full backup rather than the .ab tool route, Samsung/Google backup in phone settings works." -ForegroundColor DarkGray