# 项目背景：Android 性能与调试工具

## 概述
此仓库包含一套 Windows 批处理脚本，旨在自动化收集、提取和分析 Android 系统日志和性能追踪（Perfetto）。

## 技术栈与依赖
- **语言：** Windows 批处理 (.bat)
- **主要工具：**
  - `adb` (Android Debug Bridge)
  - `perfetto` (追踪收集工具)
  - `7-zip` (用于日志提取)
  - `Notepad++` (用于日志查看)

## 项目结构
- `/performance/perfettoCaptureTools_original/`: 包含不同时长（5秒、10秒、30秒）的 Perfetto 捕获脚本，并集成了自动追踪处理器。
- `alias.bat`: 集中管理常用的 ADB 和系统命令别名。
- `milog.bat`: 用于特定设备日志结构的专用提取逻辑。

## 编码标准与模式
- **脚本头部：** 每个脚本都应包含作者、日期和描述的说明性头部。
- **环境：** 始终使用 `@echo off` 和 `setlocal` 来防止变量泄露。
- **安全性：** 在执行设备相关命令之前，使用 `adb wait-for-device`。
- **路径：** 使用 `%cd%` 表示相对执行路径，或使用环境变量来指定工具路径。

## AI 协助指令
- 在生成新脚本时，优先考虑健壮的错误处理（例如，检查 `7z.exe` 等依赖是否存在）。
- 在修改 Perfetto 配置时，确保输出保持为有效的 `.pbtxt` 结构，如同 `generate_config` 例程中所用。
- 保持 `alias.bat` 中现有的别名命名约定（例如，`gsys` 用于全局设置，`gses` 用于安全设置）。
- 除非明确要求，否则避免使用 PowerShell；坚持使用 CMD 兼容的批处理逻辑。
