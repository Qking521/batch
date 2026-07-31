# 项目背景：Android 功耗、温升与性能调试工具

## 概述
此仓库包含一套 Windows 批处理脚本，旨在自动化收集、提取和分析 Android 系统的功耗电流、温升状态、硬件监控数据以及性能追踪（Perfetto）。

## 技术栈与依赖
- **语言：** Windows 批处理 (.bat) + Android/Linux Shell (.sh)
- **主要工具：**
  - `adb` (Android Debug Bridge)
  - `perfetto` (追踪收集工具)
  - `7-zip` (用于日志提取)
  - `Notepad++` (用于日志查看)

## 项目结构
- `power_all.bat`: 电源管理指令主入口
- `thermal_all.bat`: 热管理指令主入口
- `perf_all.bat`: 性能管理指令主入口
- `android_all.bat`: Android 通用命令指令主入口
- `batch_spec.md`: Windows 批处理编写规范指南

---

## 核心架构范式：双层控制模型

这是本项目最重要的设计原则，所有涉及设备端操作的脚本都应遵循。

### 分层职责

| 层级 | 文件 | 职责 |
|------|------|------|
| 入口层 | `*.bat` | ① 检查外部前置条件（设备连接、依赖文件存在）<br>② 将参数传给 Shell 脚本执行<br>③ 回显执行结果给用户 |
| 业务层 | `*.sh` | 所有业务逻辑：参数校验、设备操作、可复用函数、恢复/回滚 |

> **关键原则：** 入口层（bat）不应重复业务层（sh）已做的校验逻辑，否则两边容易不一致。

### 调用方式：stdin 注入模式（推荐）

通过 `adb shell "sh -s <参数>"` 配合重定向 `< script.sh`，将 Shell 脚本内容通过 stdin 传入设备执行，**无需 push 文件**，避免了 CRLF 换行符污染问题。

```bat
:: bat 入口层调用示例
adb shell "sh -s %ACTION% %PARAM%" < "%SCRIPT_DIR%your_script.sh"
```

```sh
#!/system/bin/sh
# sh 业务层通过 $1 $2 接收参数
ACTION="$1"
PARAM="$2"
case "$ACTION" in
    apply)   do_apply ;;
    restore) do_restore ;;
    *)       echo "[ERROR] 未知命令: $ACTION"; exit 1 ;;
esac
```

### Shell 业务层规范

- **用函数封装复用逻辑**：将重复操作（sysfs 写入、状态检查等）抽成函数，不要每处手写一遍
- **恢复/回滚必须是独立函数**：`restore` 或 `reset` 应作为 shell 内单独可调用的分支，统一维护
- **参数校验在 shell 内做**：包括参数合法性、目录/节点是否存在等，不依赖 bat 层重复校验

### 参考实现

| 文件 | 说明 |
|------|------|
| `power/power_eet.bat` + `power_eet.sh` | 完整双层模型范例，含参数分发、restore 分支、错误处理 |
| `thermal/thermal_infos.bat` + `thermal_infos.sh` | 多命令分发范例（tz/cd/hw） |
| `thermal/thermal_cooling_devices.sh` | 轻量只读查询的 shell 范例 |

---

## Windows 批处理编码规范

### 脚本头部（强制格式）

```bat
@echo off
chcp 65001 >nul
:: ============================================================
:: Author: <作者>
:: Date:   <日期>
:: Desc:   <脚本功能描述>
:: Usage:  <脚本名>.bat [参数说明]
:: ============================================================
setlocal EnableDelayedExpansion
```

> **注意顺序：** `chcp 65001` 必须在 `setlocal` **之前**，否则代码页设置不生效。

### 帮助信息（强制）

所有脚本的帮助标签统一命名为 `:usage`，并统一支持 `help` 和 `-h` 参数触发。

**无参数的行为根据脚本类型分两种模式：**

#### 模式 A：参数必填型（写入/修改类）
脚本必须接收参数才能执行（如 `apply`/`restore`），无参数时跳转 `:usage`：

```bat
if /i "%~1"=="help" goto :usage
if /i "%~1"=="-h"   goto :usage
if "%~1"==""        goto :usage

:: ... 业务逻辑 ...

:usage
echo 用法: script.bat ^<命令^>
echo.
echo 命令:
echo   apply    执行操作
echo   restore  恢复操作
echo   help     显示此帮助信息
echo.
exit /b 0
```

#### 模式 B：默认执行型（查询/只读类）
脚本无参数时有合理的默认动作（如直接查询并展示信息），无参数时执行默认逻辑而非显示 `:usage`：

```bat
if /i "%~1"=="help" goto :usage
if /i "%~1"=="-h"   goto :usage
if "%~1"=="" set "cmd=info"

:: ... 业务逻辑 ...

:usage
echo 用法: script.bat [命令]
echo.
echo 命令:
echo   info     查询并显示信息（无参数时的默认行为）
echo   help     显示此帮助信息
echo.
exit /b 0
```

> **判断依据：** 脚本是否存在"无副作用、只读"的合理默认行为。查询/展示类用模式 B，写入/修改类用模式 A。

### 变量安全

- 在 `setlocal EnableDelayedExpansion` 环境下，循环体内和条件块内的变量**必须用 `!VAR!`** 而非 `%VAR%`
- `ERRORLEVEL` 同理：循环/条件块内必须用 `!ERRORLEVEL!`，否则取到的是块执行前的旧值
- `if` 比较变量时使用引号包裹，防止变量为空导致语法崩溃：`if "!var!"=="val"`
- 进行 `set /a` 计算前必须初始化变量：`set var=0`

### 字符转义

在 `echo` 语句中显示特殊字符时必须用 `^` 转义：

| 字符 | 写法 |
|------|------|
| `\|` | `echo A ^| B` |
| `>` | `echo A ^> B` |
| `&` | `echo A ^& B` |
| `<` | `echo A ^< B` |

### 字符陷阱（重要）

**严禁**在 `echo` 语句中使用特殊多字节符号（如 `℃`、`→` 等）。这类符号会导致 CMD 解析器发生字节对齐偏移，使下一行命令被"吞掉"并报错 `xxx is not recognized`。统一使用标准 ASCII 字符代替（如用 `C` 代替 `℃`）。

### 前置条件检查

**ADB 设备检查只在 `*_all.bat` 中做一次**（由 `adb_check.bat` 统一处理），子脚本（如 `power_standby.bat`）不应重复检查 ADB 连接，避免冗余和不一致。

子脚本只需检查自身依赖的 `.sh` 文件是否存在：

```bat
:: 子脚本只检查 .sh 依赖文件，不重复做 ADB 检查
if not exist "%SH_SCRIPT%" (
    echo [ERROR] 找不到 shell 脚本: %SH_SCRIPT%
    exit /b 1
)
```

### 其他规范

- **避免使用 PowerShell**：除非明确要求，坚持使用 CMD 兼容的批处理逻辑
- **硬件信息采集**：优先使用 `getprop` 和 `dumpsys SurfaceFlinger`，保证轻量化
- **输出精简**：仅保留核心指标，过滤冗余信息，除非用户要求详细日志

---

## AI 协助指令

### 常用提示词

- **双层重构：**
  > "参考 GEMINI.md 的双层控制模型，优先将指定的bat脚本改造成同功能的shel脚本，然后由入口脚本调用，参考android_all.bat调用android_refresh_rate.sh”
  > "针对涉及本地资源无法直接将bat直接改造成shell脚本的，将这个脚本重构为 `.bat`（入口层）+ `.sh`（业务层）的结构。参考`power_eet.bat` + `power_eet.sh` 的结构"

- **新脚本生成：**
  > "参考 GEMINI.md 的规范，为 [功能] 生成脚本，要求包含帮助信息、ADB 连接检查和错误处理。"

### AI 生成脚本注意事项

- 生成新脚本时，优先考虑健壮的错误处理（检查 `7z.exe`、sh 文件等依赖是否存在）
- 修改 Perfetto 配置时，确保输出保持为有效的 `.pbtxt` 结构

---

## 问题记录 (Troubleshooting)

### 1. Shell 脚本运行提示 `syntax error: unexpected 'do'`
- **原因**：Windows (CRLF) 与 Linux (LF) 换行符不兼容，脚本行尾带 `\r` 导致 `do`、`then` 等关键字解析失败
- **根本解法**：使用 **stdin 注入模式**（`adb shell "sh -s" < script.sh`），内容通过管道传输，不涉及文件换行符
- **备用方案**：push 文件后执行 `adb shell "sed -i 's/\r//' <remote_path>"` 去除 `\r`

### 2. 自提取脚本首行出现冒号 `:` 污染
- **原因**：`more +n` 偏移量计算不准，包含了标签行
- **解决方案**：确保 `SKIP` 变量准确指向标签所在行号，`more +%SKIP%` 从下一行（Shebang 行）开始读取

---
