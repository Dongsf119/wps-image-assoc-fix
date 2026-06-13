#Requires -RunAsAdministrator
# ============================================================================
# WPS Image Association Fix - Chinese name launcher
# This file calls the English-named script (required for Task Scheduler compatibility)
# ============================================================================

$ErrorActionPreference = "Stop"

# Find the English-named script in the same directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$engScript = Join-Path $scriptDir "fix-wps-image-assoc.ps1"

if (-not (Test-Path $engScript)) {
    Write-Host "[ERROR] Cannot find fix-wps-image-assoc.ps1 in:" -ForegroundColor Red
    Write-Host "  $scriptDir" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure fix-wps-image-assoc.ps1 is in the same folder." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Run the English-named script with UAC elevation
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$engScript`""
Start-Process "powershell.exe" -ArgumentList $arguments -Wait -Verb RunAs

# Show result
$logFile = "$env:TEMP\wps-image-fix.log"
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  WPS Image Association Fix - Complete" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
if (Test-Path $logFile) {
    Get-Content $logFile -Tail 15 | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "[WARN] Log file not found" -ForegroundColor Yellow
}
Write-Host ""
Read-Host "Press Enter to exit"
