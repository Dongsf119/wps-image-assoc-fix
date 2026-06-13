# WPS Image Association Fix

Permanently stop WPS Office from hijacking your image file associations. Automatically sets [Honeyview](https://www.honeyview.org/) as the default image viewer and creates a scheduled task guard to prevent WPS from taking over again.

## The Problem

WPS Office repeatedly hijacks image file associations (JPG, PNG, GIF, BMP, WebP, etc.) through multiple mechanisms:

1. **Startup self-check** — WPS re-associates image files every time it launches
2. **ProgID registration** — WPS registers `WPS.PIC.*` ProgIDs in both HKCU and HKLM
3. **Scheduled tasks** — WPS creates persistent scheduled tasks to monitor and reset associations
4. **Background processes** — WPS services continuously monitor file associations
5. **Update mechanism** — WPS updates can reset all customization

Even if you manually change the default program back to your preferred viewer, WPS will revert it the next time it runs.

## The Solution

This script performs a **10-step deep fix**:

| Step | Action |
|------|--------|
| 1 | Admin privilege check |
| 2 | Auto-detect Honeyview installation path |
| 3 | Kill all WPS processes |
| 4 | Delete WPS scheduled tasks + block recreation (read-only dirs + DENY WRITE ACL) |
| 5 | Remove WPS.PIC.* ProgIDs from HKCU and HKLM |
| 6 | Deep-disable WPS self-check config (9 registry values) |
| 7 | Clean HKCU overrides and FileExts for all image formats |
| 8 | Create Honeyview ProgIDs and set file associations via .NET Registry API |
| 9 | Refresh Windows cache and restart Explorer |
| 10 | Create/update guard scheduled task (HoneyviewAssocGuard) |

### Covered Image Formats (21)

`.jpg` `.jpeg` `.jpe` `.jfif` `.png` `.gif` `.bmp` `.tiff` `.tif` `.webp` `.ico` `.svg` `.tga` `.pcx` `.psd` `.avif` `.heic` `.wdp` `.dds` `.hdr` `.exr`

## Quick Start

### Prerequisites

- Windows 10/11
- [Honeyview](https://www.honeyview.org/) installed
- Administrator privileges

### Usage

1. **Download** both `fix-wps-image-assoc.ps1` and `run-fix.ps1` to the **same folder**
2. **Important**: Place them in a path with **no Chinese characters** (e.g. `C:\wps-fix\`)
3. **Right-click** `run-fix.ps1` → **Run with PowerShell**
4. Click **Yes** on the UAC prompt
5. Wait ~15 seconds for completion

### Why Two Files?

Windows Task Scheduler uses UTF-16 encoding for storing task arguments. **Chinese characters in file paths get corrupted** in this encoding, causing the scheduled task to fail with error `0xF0FD0000`. The English-named `fix-wps-image-assoc.ps1` is the actual worker script; `run-fix.ps1` is just a convenience launcher.

## Guard Task: HoneyviewAssocGuard

After running the script, a scheduled task `HoneyviewAssocGuard` is automatically created:

| Setting | Value |
|---------|-------|
| Trigger | At user logon, delayed 2 minutes |
| Run level | Highest (administrator) |
| Battery | Allowed |
| Missed execution | Catch up on next available time |
| Arguments | `-NoProfile -ExecutionPolicy Bypass -File "C:\wps-fix\fix-wps-image-assoc.ps1" -Silent` |

### Verification

1. Open Task Scheduler (`taskschd.msc`)
2. Find `HoneyviewAssocGuard`
3. Check **Last Run Result** — `0x0` means success
4. Check log file at `%TEMP%\wps-image-fix.log`

## WPS Config Lock-Down

The script disables the following WPS registry values under `HKCU\Software\Kingsoft\Office\6.0\Common`:

| Value | Set To | Purpose |
|-------|--------|---------|
| `first_detect_file_association_while_startup` | `false` | Disable startup association check |
| `do_not_detect_file_association_while_startup` | `true` | Prevent association detection |
| `enableImageViewer` | `false` | Disable WPS image viewer component |
| `AssoImagePreview` (ksomisc) | `false` | Disable image preview association |
| `OldAssoImagePreview` (ksomisc) | `false` | Disable legacy image preview |
| `AssoWpsAndPdfPreview` (ksomisc) | `false` | Disable PDF preview association |
| `AssoProtectSwitch` | `0` | Disable association protection |
| `img_last_unasso_time` | Current date | Trick WPS into thinking it already checked |
| `UpdateMode` (updateinfo) | `manual` | Prevent auto-updates from resetting config |
| `compatible_type` | Remove image types | Remove Png/Jpg/Gif from compatible types |

## Deployment for New PC Setup

1. Install Honeyview to `C:\Program Files\Honeyview\`
2. Install WPS Office
3. Copy `fix-wps-image-assoc.ps1` to `C:\wps-fix\`
4. Copy `run-fix.ps1` to the same folder (or any convenient location)
5. Right-click `run-fix.ps1` → Run with PowerShell
6. The guard task `HoneyviewAssocGuard` is created automatically
7. Reboot and verify the guard task runs successfully (result `0x0`)

## Pitfalls & Lessons Learned

### 1. Chinese Paths Corrupt in Task Scheduler
Windows Task Scheduler stores task XML in UTF-16 encoding. Chinese characters in the `-File` argument get corrupted (e.g., `U盘工具` → `U鐩樺伐鍏穃`), causing `0xF0FD0000`. **Always use English-only paths for scheduled tasks.**

### 2. `$PID` is a PowerShell Read-Only Constant
`$PID` is a built-in variable (current process ID). Using it as a custom variable name throws "Cannot overwrite variable PID". Use `$pgid` or other names instead.

### 3. No `Read-Host` in Scheduled Tasks
Scheduled tasks run in a non-interactive session. `Read-Host` will hang indefinitely, causing error `0x1`. Use the `-Silent` parameter for unattended execution.

### 4. `New-ItemProperty` Cannot Set Registry Default Values
`New-ItemProperty -Name "(Default)"` creates a value literally named "(Default)" — not the actual default value. Use the .NET API instead:
```powershell
[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("Software\Classes\.jpg").SetValue("", "Honeyview.jpg")
```

### 5. BAT Files Corrupt Chinese Characters
UTF-8 encoded `.bat` files display garbled Chinese under GBK (cmd codepage 936). Use PowerShell scripts exclusively.

## Troubleshooting

**Q: Double-clicking .ps1 does nothing?**
A: Right-click → "Run with PowerShell", or run in an admin PowerShell:
```powershell
Set-ExecutionPolicy Bypass -Scope CurrentUser
```

**Q: Guard task result is not 0x0?**
A: 1) Check that `fix-wps-image-assoc.ps1` exists at the path shown in task arguments. 2) Verify the path contains **no Chinese characters**. 3) Check `%TEMP%\wps-image-fix.log` for error details.

**Q: WPS hijacked associations again?**
A: 1) Manually run `run-fix.ps1` once. 2) Check if the guard task is still active. 3) Check if WPS recreated its scheduled tasks (if so, re-run the script).

**Q: How to completely remove this tool?**
A: 1) Delete `HoneyviewAssocGuard` from Task Scheduler. 2) Delete the script folder. 3) Optionally restore WPS settings via WPS config tool.

## Uninstall

1. Open Task Scheduler → delete `HoneyviewAssocGuard`
2. Delete the script folder (e.g. `C:\wps-fix\`)
3. WPS will gradually regain its associations — use WPS config tool if you want to re-enable image viewing

## Reference

- [WPS association hijacking analysis (Chinese)](https://www.yeyulingfeng.com/426674.html)
- Windows file association registry hierarchy: `UserChoice > HKCU\Software\Classes > HKLM\SOFTWARE\Classes`
- Windows UserChoice Hash protection requires .NET Registry API to modify

## License

MIT
