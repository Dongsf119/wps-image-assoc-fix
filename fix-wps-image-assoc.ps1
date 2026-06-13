param([switch]$Silent)

# ============================================================================
# WPS Image Association Fix - Permanently stop WPS from hijacking image files
# Version: 4.0 (2026-06-13)
# License: MIT
# ============================================================================

$logFile = "$env:TEMP\wps-image-fix.log"
"$(Get-Date)  [START] Script begins" | Out-File $logFile -Encoding UTF8

try {
    # ---- Step 1: Admin check ----
    "$(Get-Date)  [STEP1] Admin check..." | Out-File $logFile -Append -Encoding UTF8
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        "$(Get-Date)  [ERROR] Not admin" | Out-File $logFile -Append -Encoding UTF8
        if (-not $Silent) {
            Write-Host "[ERROR] Please run as Administrator!" -ForegroundColor Red
            Read-Host "Press Enter to exit"
        }
        exit 1
    }

    # ---- Step 2: Find Honeyview ----
    "$(Get-Date)  [STEP2] Finding Honeyview..." | Out-File $logFile -Append -Encoding UTF8
    $honeyviewPath = $null
    foreach ($candidate in @(
        "C:\Program Files\Honeyview\Honeyview.exe",
        "C:\Program Files\Bandisoft\Honeyview\Honeyview.exe",
        "${env:ProgramFiles}\Honeyview\Honeyview.exe",
        "${env:ProgramFiles(x86)}\Honeyview\Honeyview.exe"
    )) {
        if (Test-Path $candidate) { $honeyviewPath = $candidate; break }
    }
    # Search via registry as fallback
    if (-not $honeyviewPath) {
        $reg = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*Honeyview*" } | Select-Object -First 1
        if ($reg -and $reg.InstallLocation) {
            $try = Join-Path $reg.InstallLocation "Honeyview.exe"
            if (Test-Path $try) { $honeyviewPath = $try }
        }
    }
    if (-not $honeyviewPath) {
        "$(Get-Date)  [ERROR] Honeyview.exe not found!" | Out-File $logFile -Append -Encoding UTF8
        if (-not $Silent) {
            Write-Host "[ERROR] Honeyview.exe not found! Please install Honeyview first." -ForegroundColor Red
            Read-Host "Press Enter to exit"
        }
        exit 1
    }
    "$(Get-Date)  [STEP2] Honeyview: $honeyviewPath" | Out-File $logFile -Append -Encoding UTF8

    # ---- Step 3: Kill WPS processes ----
    "$(Get-Date)  [STEP3] Killing WPS..." | Out-File $logFile -Append -Encoding UTF8
    foreach ($p in @("wps","wpp","et","ksolaunch","ksomisc","wpscloudsvr","wpsupdate","wpscenter","wpsnotify")) {
        Get-Process -Name $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    # ---- Step 4: Delete WPS scheduled tasks + block recreation ----
    "$(Get-Date)  [STEP4] Deleting WPS tasks..." | Out-File $logFile -Append -Encoding UTF8
    $allTasks = Get-ScheduledTask -ErrorAction SilentlyContinue
    foreach ($task in $allTasks) {
        if ($task.TaskName -like "*Wps*" -or $task.TaskName -like "*Kingsoft*" -or $task.TaskPath -like "*Wps*") {
            try { Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false -ErrorAction SilentlyContinue } catch {}
        }
    }
    # Block WPS task recreation by creating read-only empty dirs with DENY WRITE ACL
    foreach ($tp in @(
        "$env:SystemRoot\System32\Tasks\WpsUpdaterLogonTask_$env:USERNAME",
        "$env:SystemRoot\System32\Tasks\WpsUpdateTask_$env:USERNAME",
        "$env:SystemRoot\System32\Tasks\WpsWakeupWsLoginTask",
        "$env:SystemRoot\System32\Tasks\WpsUpdateLogonTask_$env:USERNAME"
    )) {
        if (Test-Path $tp) { Remove-Item -Path $tp -Force -ErrorAction SilentlyContinue }
        try {
            New-Item -Path $tp -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
            $acl = Get-Acl -Path $tp -ErrorAction SilentlyContinue
            if ($acl) {
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone","Write","ContainerInherit,ObjectInherit","None","Deny")
                $acl.AddAccessRule($rule)
                Set-Acl -Path $tp -AclObject $acl -ErrorAction SilentlyContinue
            }
        } catch {}
    }

    # ---- Step 5: Remove WPS image ProgIDs ----
    "$(Get-Date)  [STEP5] Removing WPS ProgIDs..." | Out-File $logFile -Append -Encoding UTF8
    $wpsIds = @("WPS.PIC.jpg","WPS.PIC.jpeg","WPS.PIC.jpe","WPS.PIC.jfif","WPS.PIC.png","WPS.PIC.gif","WPS.PIC.bmp",
                "WPS.PIC.tiff","WPS.PIC.tif","WPS.PIC.webp","WPS.PIC.ico","WPS.PIC.svg","WPS.PIC.tga",
                "WPS.PIC.pcx","WPS.PIC.psd","WPS.PIC.avif","WPS.PIC.heic","WPS.PIC.wdp","WPS.PIC.dds","WPS.PIC.hdr","WPS.PIC.exr")
    foreach ($id in $wpsIds) {
        foreach ($root in @("HKCU:\Software\Classes","HKLM:\SOFTWARE\Classes")) {
            if (Test-Path "$root\$id") { Remove-Item "$root\$id" -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    # ---- Step 6: Deep-disable WPS self-check config ----
    "$(Get-Date)  [STEP6] WPS config lock-down..." | Out-File $logFile -Append -Encoding UTF8
    $wpsPaths = @("HKCU:\Software\Kingsoft\Office","HKCU:\Software\Kingsoft\Office\6.0\common","HKCU:\Software\Kingsoft\KCommon")
    foreach ($wp in $wpsPaths) {
        if (Test-Path $wp) {
            Set-ItemProperty -Path $wp -Name "AutoCheck" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $wp -Name "CheckOnStartup" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        }
    }
    $cp = "HKCU:\Software\Kingsoft\Office\6.0\common"
    if (Test-Path $cp) {
        Set-ItemProperty -Path $cp -Name "first_detect_file_association_while_startup" -Value "false" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cp -Name "do_not_detect_file_association_while_startup" -Value "true" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cp -Name "enableImageViewer" -Value "false" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cp -Name "AssoProtectSwitch" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        $now = Get-Date -Format "yyyy-MM-dd"
        Set-ItemProperty -Path $cp -Name "img_last_unasso_time" -Value $now -ErrorAction SilentlyContinue
        # Remove image types from compatible_type
        try {
            $ct = (Get-ItemProperty -Path $cp -Name "compatible_type" -ErrorAction SilentlyContinue).compatible_type
            if ($ct) {
                $ct = ($ct -split ";" | Where-Object { $_ -notin @("Png","Jpg","Gif","Bmp","Tiff","Webp","Svg") }) -join ";"
                Set-ItemProperty -Path $cp -Name "compatible_type" -Value $ct -ErrorAction SilentlyContinue
            }
        } catch {}
    }
    foreach ($path in @("HKCU:\Software\Kingsoft\Office\6.0\common\ksomisc")) {
        if (Test-Path $path) {
            Set-ItemProperty -Path $path -Name "AssoImagePreview" -Value "false" -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $path -Name "OldAssoImagePreview" -Value "false" -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $path -Name "AssoWpsAndPdfPreview" -Value "false" -ErrorAction SilentlyContinue
        }
    }
    $up = "HKCU:\Software\Kingsoft\Office\6.0\common\updateinfo"
    if (Test-Path $up) {
        Set-ItemProperty -Path $up -Name "UpdateMode" -Value "manual" -ErrorAction SilentlyContinue
    }

    # ---- Step 7: Clean HKCU overrides + FileExts ----
    "$(Get-Date)  [STEP7] Cleaning extensions..." | Out-File $logFile -Append -Encoding UTF8
    $extMap = @{
        ".jpg"="Honeyview.jpg"; ".jpeg"="Honeyview.jpg"; ".jpe"="Honeyview.jpg"; ".jfif"="Honeyview.jpg";
        ".png"="Honeyview.png"; ".gif"="Honeyview.gif"; ".bmp"="Honeyview.bmp";
        ".tiff"="Honeyview.tiff"; ".tif"="Honeyview.tiff"; ".webp"="Honeyview.webp";
        ".ico"="Honeyview.ico"; ".svg"="Honeyview.svg"; ".tga"="Honeyview.tga";
        ".pcx"="Honeyview.pcx"; ".psd"="Honeyview.psd"; ".avif"="Honeyview.avif";
        ".heic"="Honeyview.heic"; ".wdp"="Honeyview.wdp"; ".dds"="Honeyview.dds";
        ".hdr"="Honeyview.hdr"; ".exr"="Honeyview.exr"
    }
    foreach ($ext in $extMap.Keys) {
        if (Test-Path "HKCU:\Software\Classes\$ext") { Remove-Item "HKCU:\Software\Classes\$ext" -Recurse -Force -ErrorAction SilentlyContinue }
        $fe = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
        if (Test-Path $fe) { Remove-Item $fe -Recurse -Force -ErrorAction SilentlyContinue }
    }

    # ---- Step 8: Create Honeyview ProgIDs + set associations ----
    "$(Get-Date)  [STEP8] Creating Honeyview ProgIDs + setting associations..." | Out-File $logFile -Append -Encoding UTF8
    $doneProgs = @{}
    foreach ($ext in $extMap.Keys) {
        $pgid = $extMap[$ext]
        if (-not $doneProgs.ContainsKey($pgid)) {
            $doneProgs[$pgid] = $true
            $cmdP = "HKCU:\Software\Classes\$pgid\shell\open\command"
            New-Item $cmdP -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty $cmdP -Name "(Default)" -Value "`"$honeyviewPath`" `"%1`"" -ErrorAction SilentlyContinue
            $iconP = "HKCU:\Software\Classes\$pgid\DefaultIcon"
            New-Item $iconP -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty $iconP -Name "(Default)" -Value "$honeyviewPath,0" -ErrorAction SilentlyContinue
        }
        # Use .NET API to set default value (New-ItemProperty cannot set the real "(Default)" value)
        $rk = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("Software\Classes\$ext")
        if ($rk) { $rk.SetValue("", $pgid); $rk.Close() }
        cmd /c "assoc $ext=$pgid" 2>$null
    }
    # Register ftype for each unique ProgID
    foreach ($pgid in $doneProgs.Keys) {
        cmd /c "ftype $pgid=`"$honeyviewPath`" `"%1`"" 2>$null
    }

    # ---- Step 9: Refresh Windows cache ----
    "$(Get-Date)  [STEP9] Refreshing cache..." | Out-File $logFile -Append -Encoding UTF8
    ie4uinit.exe -show 2>$null
    Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class W32{[DllImport("shell32.dll",CharSet=CharSet.Auto)]public static extern void SHChangeNotify(int e,int f,IntPtr a,IntPtr b);}' -ErrorAction SilentlyContinue
    [W32]::SHChangeNotify(0x08000000,0,[IntPtr]::Zero,[IntPtr]::Zero)
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue

    # ---- Step 10: Create/update guard scheduled task ----
    "$(Get-Date)  [STEP10] Updating guard task..." | Out-File $logFile -Append -Encoding UTF8
    # IMPORTANT: Must use English path for scheduled task (Chinese paths get corrupted in UTF-16 XML)
    $myPath = $MyInvocation.MyCommand.Path
    $silentArg = "-NoProfile -ExecutionPolicy Bypass -File `"$myPath`" -Silent"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $silentArg
    $trigger = New-ScheduledTaskTrigger -AtLogon
    $trigger.Delay = "PT2M"
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    $taskExists = $false
    try { $null = Get-ScheduledTask -TaskName "HoneyviewAssocGuard" -ErrorAction Stop; $taskExists = $true } catch {}

    if ($taskExists) {
        try {
            Set-ScheduledTask -TaskName "HoneyviewAssocGuard" -Action $action -ErrorAction Stop | Out-Null
            Enable-ScheduledTask -TaskName "HoneyviewAssocGuard" -ErrorAction SilentlyContinue | Out-Null
            "$(Get-Date)  [STEP10] Guard task updated" | Out-File $logFile -Append -Encoding UTF8
        } catch {
            Enable-ScheduledTask -TaskName "HoneyviewAssocGuard" -ErrorAction SilentlyContinue | Out-Null
            "$(Get-Date)  [STEP10] Guard task enabled (not updated)" | Out-File $logFile -Append -Encoding UTF8
        }
    } else {
        try {
            Register-ScheduledTask -TaskName "HoneyviewAssocGuard" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -Description "WPS Image Association Guard - auto-fix image file associations hijacked by WPS" -ErrorAction Stop | Out-Null
            "$(Get-Date)  [STEP10] Guard task created" | Out-File $logFile -Append -Encoding UTF8
        } catch {
            "$(Get-Date)  [STEP10] Guard task creation failed" | Out-File $logFile -Append -Encoding UTF8
        }
    }

    "$(Get-Date)  [DONE] SUCCESS!" | Out-File $logFile -Append -Encoding UTF8

} catch {
    "$(Get-Date)  [ERROR] $_" | Out-File $logFile -Append -Encoding UTF8
    "$(Get-Date)  [STACK] $($_.ScriptStackTrace)" | Out-File $logFile -Append -Encoding UTF8
}
exit 0
