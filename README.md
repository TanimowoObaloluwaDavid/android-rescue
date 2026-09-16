# Android Rescue

Back up your own Android phone's data to your PC over USB using ADB. Pure PowerShell — no Python required.

## What it does

Pull these from any Android phone connected over USB debugging:

| Step | Output |
|------|--------|
| Device info | `device_info.txt` (model, Android version, battery, storage, uptime) |
| Media | `DCIM`, `Pictures`, `Download`, `Documents`, `Music`, `Movies`, `WhatsApp`, `Telegram`, `VOIP` |
| Apps | `apps_user.txt` + `apps_all.txt` (installed apps) |
| Contacts | `contacts.txt` (display name + number) |
| SMS | `sms.txt` (address, date, body) |
| Call log | `call_log.txt` (number, date, duration, type) |
| Screenshot | `screen.png` |
| Full backup | optional `full_backup.ab` via `adb backup` |
| Report | `REPORT.txt` + everything zipped automatically |

## Requirements

- Windows (PowerShell 5.1+)
- [Google platform-tools](https://dl.google.com/android/repository/platform-tools-latest-windows.zip) (contains `adb.exe`)
- Android phone with **USB debugging** enabled

## Setup (one-time, on the phone)

1. `Settings > About phone` — tap **Build number** 7 times to unlock Developer Options.
2. `Settings > System > Developer options` — enable **USB debugging**.
3. Plug the phone in via USB and accept the RSA fingerprint dialog.

> Note: Android 11+ shows a per-connection "Allow USB debugging" prompt each time — tap **Allow**.

## Usage

```powershell
powershell -ExecutionPolicy Bypass -File android-rescue.ps1
```

### Options

```powershell
-OutDir "backup_2026"      # custom output folder
-SkipMedia                 # skip DCIM/Pictures/etc.
-SkipApps                  # skip app list
-SkipContacts              # skip contacts
-SkipSms                   # skip SMS
-SkipCallLog               # skip call log
-SkipScreenshot            # skip screenshot
-SkipZip                   # don't zip the result
-FullBasebackup            # also run adb backup -apk -shared -all
```

Example:

```powershell
powershell -ExecutionPolicy Bypass -File android-rescue.ps1 -SkipMedia -FullBasebackup
```

## Notes on blocked items

Android restricts `content://sms`, `content://call_log` and raw contact queries on most modern devices for privacy — those rows will show as **blocked** and you'll get an empty/partial file. For a full picture, use:

- **Samsung Smart Switch** — its PC backup gets SMS, contacts and call logs on Samsung phones.
- **Google / OEM backup** — the phone's own cloud backup (Settings > System > Backup).

This tool works best for files, media and metadata; OS-level data extraction beyond that is not possible without root, and rooting your device is a separate, vendor-dependent process.

## Legal

Only use this on devices **you own**. Accessing anyone else's device without permission is a crime in most jurisdictions. This tool does not bypass any security — it uses Android's standard, user-facing USB debugging interface.

## License

[MIT](LICENSE)