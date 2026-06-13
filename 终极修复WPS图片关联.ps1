#Requires -RunAsAdministrator
# ============================================================================
# WPS 图片关联修复 - 中文名入口脚本
# 实际工作由 C:\wps-fix\fix-wps-image-assoc.ps1 完成（纯英文路径，避免乱码）
# 此文件仅作为"用户双击入口"，请勿删除
# ============================================================================

$ErrorActionPreference = "Stop"

# 目标脚本：纯英文路径，计划任务也使用此路径
$engScript = "C:\wps-fix\fix-wps-image-assoc.ps1"

if (-not (Test-Path $engScript)) {
    Write-Host "[ERROR] 找不到 $engScript" -ForegroundColor Red
    Write-Host "请确保 C:\wps-fix\fix-wps-image-assoc.ps1 存在" -ForegroundColor Red
    Read-Host "按回车退出"
    exit 1
}

# 以静默模式运行英文版脚本（UAC提权）
$powerShell = "powershell.exe"
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$engScript`" -Silent"
Start-Process $powerShell -ArgumentList $arguments -Wait -Verb RunAs

# 显示结果
$logFile = "$env:TEMP\wps-image-fix.log"
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  WPS 图片关联修复 已完成" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
if (Test-Path $logFile) {
    Get-Content $logFile -Tail 15 | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "[WARN] 日志文件未生成" -ForegroundColor Yellow
}
Write-Host ""
Read-Host "按回车退出"
