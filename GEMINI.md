# 项目背景：Android 功耗、温升与性能调试工具

## 概述
此仓库包含一套 Windows 批处理脚本，旨在自动化收集、提取和分析 Android 系统的功耗电流、温升状态、硬件监控数据以及性能追踪（Perfetto）。

## 技术栈与依赖
- **语言：** Windows 批处理 (.bat)
- **主要工具：**
  - `adb` (Android Debug Bridge)
  - `perfetto` (追踪收集工具)
  - `7-zip` (用于日志提取)
  - `Notepad++` (用于日志查看)

## 项目结构
- `power_all.bat`: 电源管理指令主入口，集成所有子功能。
- `power_info.bat`: 设备综合信息看板（涵盖 CPU 布局、GPU、存储、电池实时功率等）。
- `power_thermal_zones.bat`: 热管理区（Thermal Zones）状态监控及开关控制。
- `power_hwmon.bat`: 硬件监控节点（风扇、PWM、NTC）数据提取。
- `power_supply.bat`: 电源子系统（Battery/USB）底层属性详细列表。
- `power_clear_recent.bat`: 基于 UI Automator 的后台应用自动清理脚本。
- `alias.bat`: 集中管理常用的 ADB 和系统命令别名。
- `batch_spec.md`: Windows 批处理编写规范指南。

## 编码标准与模式
- **脚本头部：** 每个脚本都应包含作者、日期和描述的说明性头部。
- **环境：** 始终使用 `@echo off` 和 `setlocal` 来防止变量泄露。
- **安全性：** 在执行设备相关命令之前，使用 `adb wait-for-device`。
- **路径：** 使用 `%cd%` 表示相对执行路径，或使用环境变量来指定工具路径。
- **分发模式：** 对于复杂的 Shell 逻辑，优先采用“混合脚本分发模式”。

## AI 协助指令
- 在生成新脚本时，优先考虑健壮的错误处理（例如，检查 `7z.exe` 等依赖是否存在）。
- 在修改 Perfetto 配置时，确保输出保持为有效的 `.pbtxt` 结构，如同 `generate_config` 例程中所用。
- 保持 `alias.bat` 中现有的别名命名约定（例如，`gsys` 用于全局设置，`gses` 用于安全设置）。
- 除非明确要求，否则避免使用 PowerShell；坚持使用 CMD 兼容的批处理逻辑。

### AI 协助常用提示词 (Prompt Keywords)
- **脚本重构：** "请参考 GEMINI.md 中的『嵌入式跨平台混合脚本分发模式』，重构一下这个脚本。"
- **逻辑克隆：** "仿照 [文件名.bat] 的逻辑，为 [路径/功能] 编写一个新脚本，要求同步添加相关参数。"

## Windows 批处理规范 (重要)
- **编码格式：** 必须使用 `UTF-8` 编码，并在脚本头部添加 `chcp 65001 >nul`。
- **变量安全：** 在进行 `set /a` 计算或 `if` 比较前，必须初始化变量（如 `set var=0`），并使用引号包裹（如 `if "!var!"=="val"`），防止因 ADB 返回空值导致的语法崩溃。
- **字符转义：** 在 `echo` 中显示 `|`、`&`、`>` 等字符时，必须使用 `^` 进行转义（例如 `echo A ^| B`），否则会被误认为指令。
- **性能优化：** 严禁在循环内频繁调用 `adb shell`，必须合并查询指令。
- **输出精简：** 除非用户要求详细日志，否则仅保留核心指标，过滤冗余信息。
- **字符陷阱：** 严禁在 `echo` 语句中使用特殊多字节符号（如 `℃`），这会导致 CMD 解析器发生字节对齐偏移，导致下一行命令（如 `echo`）被“吞掉”并报错“xxx is not recognized”。优先使用标准 ASCII 字符（如 `C`）。
- **硬件信息：** 采集 CPU/GPU 信息时，应优先使用 `getprop` 和 `dumpsys SurfaceFlinger` 以保证轻量化。

## 进阶开发范式

### 1. 嵌入式跨平台混合脚本分发模式 (Hybrid Script Delivery Pattern)
*   **定义**：在 Windows Batch 脚本底部嵌入原生 Linux Shell 代码，运行时动态提取、推送并执行。
*   **核心优势**：
    1.  **零转义污染**：无需处理 Batch 复杂的转义规则（如 `%%`, `^|`, `\"`），保持 Shell 代码纯净。
    2.  **单次连接性能**：避免在 Batch 循环中频繁调用 `adb shell` 产生的连接握手开销。
*   **标准实现标准**：
    1.  **定位**：利用 `findstr /n` 获取标签 `:BEGIN_SHELL_SCRIPT` 的行号。
    2.  **提取**：使用 `more +%SKIP%` 提取内容，确保跳过标签行，使 Shebang (`#!`) 位于首行。
    3.  **适配**：`adb push` 后必须执行 `sed -i 's/\r//'` 消除 Windows 换行符（CRLF）导致的语法错误。
*   **模版代码**：
    ```batch
    set "LOCAL_SH=%TEMP%\myscript.sh"
    for /f "tokens=1 delims=:" %%n in ('findstr /n "^:BEGIN_SHELL_SCRIPT" "%~f0"') do set /a SKIP=%%n
    more +%SKIP% "%~f0" > "%LOCAL_SH%"
    adb push "%LOCAL_SH%" /data/local/tmp/myscript.sh
    adb shell "sed -i 's/\r//' /data/local/tmp/myscript.sh && sh /data/local/tmp/myscript.sh"
    ```

## 问题记录 (Troubleshooting)

### 1. Shell 脚本运行提示 `syntax error: unexpected 'do'`
*   **原因**：Windows (CRLF) 与 Linux (LF) 换行符不兼容。提取的脚本末尾带 `\r`，导致 `do`, `then` 等关键字解析失败。
*   **解决方案**：推送后执行 `adb shell "sed -i 's/\r//' <remote_path>"`。

### 2. 自提取脚本首行出现冒号 `:` 污染
*   **原因**：`more +n` 偏移量计算不准导致包含标签行。
*   **解决方案**：确保 `SKIP` 变量准确指向标签所在行号，`more +%SKIP%` 正好会从下一行（Shebang行）开始读取。

---
