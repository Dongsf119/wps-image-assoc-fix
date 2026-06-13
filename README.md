# WPS 图片关联修复工具

彻底阻止 WPS Office 反复抢占图片文件默认打开方式。自动将图片关联设置为 [Honeyview](https://www.honeyview.org/)，并创建计划任务守护，防止 WPS 再次劫持。

## 问题描述

WPS Office 通过多种方式反复抢占图片文件关联（JPG、PNG、GIF、BMP、WebP 等）：

1. **启动时自检** — WPS 每次启动都会重新关联图片文件
2. **ProgID 注册** — WPS 在 HKCU 和 HKLM 两个位置注册 `WPS.PIC.*` ProgID
3. **计划任务** — WPS 创建持久化计划任务，监控并重置文件关联
4. **后台进程** — WPS 后台服务持续监控文件关联状态
5. **更新机制** — WPS 更新会重置所有自定义配置

即使你手动将默认程序改回其他看图软件，WPS 下次启动时又会自动抢回去。

## 解决方案

本脚本执行 **10 步深度修复**：

| 步骤 | 操作 |
|------|------|
| 1 | 检查管理员权限 |
| 2 | 自动查找 Honeyview 安装路径 |
| 3 | 强制结束所有 WPS 进程 |
| 4 | 删除 WPS 计划任务 + 用只读目录阻止重建（DENY WRITE ACL） |
| 5 | 删除 WPS.PIC.* ProgID（HKCU 和 HKLM 两层） |
| 6 | 深度禁用 WPS 自检配置（9 项注册表值） |
| 7 | 清理 HKCU 覆盖项和 FileExts（所有图片扩展名） |
| 8 | 创建 Honeyview ProgID 并设置文件关联（.NET Registry API） |
| 9 | 刷新 Windows 缓存 + 重启资源管理器 |
| 10 | 创建/更新守护计划任务（HoneyviewAssocGuard） |

### 覆盖的图片格式（21 种）

`.jpg` `.jpeg` `.jpe` `.jfif` `.png` `.gif` `.bmp` `.tiff` `.tif` `.webp` `.ico` `.svg` `.tga` `.pcx` `.psd` `.avif` `.heic` `.wdp` `.dds` `.hdr` `.exr`

## 快速开始

### 前置条件

- Windows 10/11
- 已安装 [Honeyview](https://www.honeyview.org/)
- 管理员权限

### 使用方法

1. 将 `fix-wps-image-assoc.ps1` 和 `run-fix.ps1` **下载到同一文件夹**
2. **重要**：路径中**不能包含中文字符**（例如 `C:\wps-fix\`）
3. **右键** `run-fix.ps1` → **使用 PowerShell 运行**
4. 在 UAC 提示中点 **是**
5. 等待约 15 秒完成

### 为什么需要两个文件？

Windows 计划任务使用 UTF-16 编码存储任务参数。文件路径中的**中文字符会被破坏**（例如 `U盘工具` → `U鐩樺伐鍏穃`），导致计划任务执行失败（错误码 `0xF0FD0000`）。因此：
- `fix-wps-image-assoc.ps1`：实际工作脚本，**必须使用英文文件名**
- `run-fix.ps1`：入口脚本，用于双击运行（自动调用英文脚本）

## 守护任务：HoneyviewAssocGuard

运行脚本后，会自动创建计划任务 `HoneyviewAssocGuard`：

| 设置项 | 值 |
|--------|-----|
| 触发器 | 用户登录时，延迟 2 分钟 |
| 运行级别 | 最高权限（管理员） |
| 电池设置 | 允许在电池供电时运行 |
| 错过执行 | 下次可用时补执行 |
| 参数 | `-NoProfile -ExecutionPolicy Bypass -File "C:\wps-fix\fix-wps-image-assoc.ps1" -Silent` |

### 验证方法

1. 打开"任务计划程序"（`taskschd.msc`）
2. 找到 `HoneyviewAssocGuard`
3. 查看**上次运行结果** — `0x0` 表示成功
4. 查看日志文件 `%TEMP%\wps-image-fix.log`

## WPS 配置项深度禁用

脚本会修改以下 WPS 注册表值（`HKCU\Software\Kingsoft\Office\6.0\Common`）：

| 注册表值 | 设置为 | 作用 |
|----------|--------|------|
| `first_detect_file_association_while_startup` | `false` | 禁用启动时关联检测 |
| `do_not_detect_file_association_while_startup` | `true` | 禁止关联检测 |
| `enableImageViewer` | `false` | 禁用 WPS 图片查看组件 |
| `AssoImagePreview`（ksomisc 下） | `false` | 禁用图片预览关联 |
| `OldAssoImagePreview`（ksomisc 下） | `false` | 禁用旧版图片预览 |
| `AssoWpsAndPdfPreview`（ksomisc 下） | `false` | 禁用 PDF 预览关联 |
| `AssoProtectSwitch` | `0` | 禁用关联保护 |
| `img_last_unasso_time` | 当前日期 | 欺骗 WPS 已检测过 |
| `UpdateMode`（updateinfo 下） | `manual` | 禁止自动更新重置配置 |
| `compatible_type` | 移除图片类型 | 移除 Png/Jpg/Gif 兼容类型 |

## 新电脑部署步骤

1. 安装 Honeyview 到 `C:\Program Files\Honeyview\`
2. 安装 WPS Office
3. 将 `fix-wps-image-assoc.ps1` 复制到 `C:\wps-fix\`
4. 将 `run-fix.ps1` 复制到同一文件夹
5. 右键 `run-fix.ps1` → 使用 PowerShell 运行
6. 守护任务 `HoneyviewAssocGuard` 自动创建
7. 重启电脑，确认守护任务执行成功（结果 `0x0`）

## 踩过的坑（关键教训）

### 1. 计划任务路径不能包含中文
Windows 计划任务 XML 使用 UTF-16 编码存储参数，中文路径会被破坏（如 `U盘工具` → `U鐩樺伐鍏穃`），导致错误 `0xF0FD0000`。**计划任务引用的脚本路径必须全英文。**

### 2. `$PID` 是 PowerShell 只读常量
`$PID` 是 PowerShell 内置变量（当前进程 ID），不可覆盖。使用自定义变量名时需避开 `$pid`，改用 `$pgid` 等名称。

### 3. 计划任务中不能有 Read-Host
计划任务运行在非交互环境，`Read-Host` 会无限挂起导致超时（错误 `0x1`）。需使用 `-Silent` 参数跳过交互。

### 4. `New-ItemProperty` 无法设置注册表默认值
`New-ItemProperty -Name "(Default)"` 创建的是名为 `(Default)` 的值，不是真正的默认值。应使用 .NET API：
```powershell
[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("Software\Classes\.jpg").SetValue("", "Honeyview.jpg")
```

### 5. BAT 文件中文乱码
UTF-8 编码的 `.bat` 文件在 GBK（cmd 936）环境下中文变乱码。应完全使用 PowerShell 脚本。

## 常见问题

**Q：双击 .ps1 文件没反应？**
A：右键 → "使用 PowerShell 运行"，或在管理员 PowerShell 中执行：
```powershell
Set-ExecutionPolicy Bypass -Scope CurrentUser
```

**Q：守护任务上次运行结果不是 0x0？**
A：1) 检查 `fix-wps-image-assoc.ps1` 是否存在于任务参数所示路径；2) 确认路径**不含中文字符**；3) 查看 `%TEMP%\wps-image-fix.log` 日志内容。

**Q：WPS 又抢回了图片关联？**
A：1) 手动运行一次 `run-fix.ps1`；2) 检查守护任务是否正常；3) 检查 WPS 计划任务是否被重建（如被重建需重新运行脚本）。

**Q：如何完全卸载本工具？**
A：1) 打开任务计划程序，删除 `HoneyviewAssocGuard`；2) 删除脚本文件夹；3) 可通过 WPS 配置工具恢复关联。

## 卸载

1. 打开任务计划程序 → 删除 `HoneyviewAssocGuard`
2. 删除脚本文件夹（如 `C:\wps-fix\`）
3. WPS 会逐渐恢复关联 — 可通过 WPS 配置工具重新启用图片查看

## 参考资料

- [WPS 抢占关联原理分析](https://www.yeyulingfeng.com/426674.html)
- Windows 文件关联注册表层级：`UserChoice > HKCU\Software\Classes > HKLM\SOFTWARE\Classes`
- Windows UserChoice Hash 保护机制：需要使用 .NET Registry API 修改

## 开源协议

MIT
