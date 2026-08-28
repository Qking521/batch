# 项目背景：Android 功耗、温升与性能调试工具

## 概述
此仓库包含一套 Windows 批处理脚本，旨在自动化收集、提取和分析 Android 系统的功耗电流、温升状态、性能追踪（Perfetto）。

## 技术栈与依赖
- **语言：** Windows 批处理 (.bat) + Android/Linux Shell (.sh) + Python
- **主要工具：**
  - `adb` (Android Debug Bridge)
  - `perfetto` (追踪收集工具)
  - `7-zip` (用于日志提取)
  - `Notepad++` (用于日志查看)

## 项目结构
- `power/power_all.bat`: 电源管理指令主入口 (别名: `pw`)
- `thermal/thermal_all.bat`: 热管理指令主入口 (别名: `tm`)
- `performance/perf_all.bat`: 性能管理指令主入口 (别名: `pf`)
- `android/android_all.bat`: Android 通用命令指令主入口 (别名: `ad`)
- `windows/windows_all.bat`: Windows 自动化脚本入口 (别名: `wd`)
- `mediatek/mtklog.bat`: MediaTek 日志抓取与管理 (别名: `mtk`)

---

## 核心架构范式：双层控制模型

这是本项目最重要的设计原则，所有涉及设备端操作的脚本都应遵循。

### 单/双层控制范式说明

根据功能场景及对 PC 本地资源的依赖程度，选择最简高效的执行模式：

| 范式 | 文件组成 | 适用场景 | 架构原则 |
|------|----------|----------|----------|
| **主入口直接注入 (纯 Shell 业务)** | `*_all.bat` (主入口) + `*.sh` (业务层) | 纯设备端逻辑（如查询/修改节点、提取 Property 等），无需 PC 本地交互 | **优先采用此方式**。纯设备端操作只维护独立的 `.sh` 业务文件，由 `*_all.bat` 直接通过 `adb shell "sh -s"` 管道调用 `.sh`，**严禁保留多余的单功能 `.bat` 中转层**。 |
| **双层包装模型 (含 PC 端逻辑)** | `*.bat` (PC代理/入口) + `*.sh` (设备业务) | 需要 PC 端资源参与（如保存截图/录屏文件到 PC 本地、解压 7z、调用 python 等） | 由 `*_all.bat` 调用子 `*.bat`，子 `*.bat` 处理 PC 端逻辑并配合调用 `.sh`。 |

> **关键原则：** 入口层不应重复业务层已做的校验逻辑。无 PC 本地资源依赖的纯设备端操作，一律直接将逻辑整合为纯 `.sh` 脚本，由 `*_all.bat` 统筹分发，彻底移除中间多余的单功能 `.bat` 代理文件！


### 调用方式：stdin 注入模式（推荐）

通过 `adb shell "sh -s <参数>"` 配合重定向 `< script.sh`，将 Shell 脚本内容通过 stdin 传入设备执行，**无需 push 文件**，避免了 CRLF 换行符污染问题。

```bat
:: bat 入口层调用示例（由 *_all.bat 直接分发）
set "SH_SCRIPT=%SCRIPT_DIR%your_script.sh"
adb shell "sh -s %ACTION% %PARAM%" < "%SH_SCRIPT%"
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
- **参数校验在 shell 内做**：包括参数合法性、目录/节点是否存在等，不依赖 bat 层重复校验
- **路由分发单行紧凑规范**：Shell 业务层中的 `case "$ACTION" in` 命令分发分支，**必须尽量写成单行**（如 `apply) do_apply ;;`），使路由表一目了然，避免简单分支多行展开占用行数：
  ```sh
  case "$ACTION" in
      apply)   do_apply ;;
      restore) do_restore ;;
      info)    do_info ;;
      *)       echo "[ERROR] 未知命令: $ACTION"; exit 1 ;;
  esac
  ```

### 参考实现

| 范式分类 | 典型实现 | 说明 |
|------|------|------|
| **纯 Shell 业务（主入口直连）** | `android_all.bat` + `android_device_info.sh`<br>`android_all.bat` + `android_refresh_rate.sh` | 纯 Android 设备端操作，无单独子 bat 中转 |
| **双层包装（PC 本地交互）** | `android_screen_record.bat` + `android_screen_record.sh` | 涉及从设备拉取文件到 PC 本地 `MODULE_OUT_DIR` 并自动打开 |
| **纯 Shell 轻量查询** | `thermal/thermal_infos.sh` | 轻量只读查询的 shell 范例 |

### 跨平台解释器声明行（#! Shebang）兼容规范

> **什么是 `#!`（Shebang）：** Shell 脚本第一行的 `#!/system/bin/sh` 叫做"解释器声明行"（英文俚语 Shebang，取自 `#` = sharp、`!` = bang）。它告诉操作系统用哪个程序来执行这个脚本文件。

- **规范**：Shell 脚本文件首行统一声明为 `#!/system/bin/sh`（Android 默认 Shell 解释器路径）。
- **跨平台兼容**：在双层模型中，由于我们主要通过 PC 端的 `adb shell "sh -s ... " < script.sh` 管道方式注入执行，该命令直接由 Android 端本机的 `sh` 解析 stdin，不依赖首行解释器声明。因此，Windows 批处理入口调用此模式不受 `#!` 首行限制。
- **Linux 环境直接执行**：如果在纯 Linux 宿主机下以 `./script.sh` 直接运行，可能会因找不到 `/system/bin/sh` 路径而报错。这属于正常环境差异，在 Linux 下测试时可以通过 `sh script.sh` 手动运行，或在 Linux 系统中建立软链接 `ln -s /bin/sh /system/bin/sh` 来保障完美兼容。代码中应统一保持 `#!/system/bin/sh`。


### Root 权限检查与节点访问安全规范 (防闪退/报错)

- **Root 权限检查**：功耗与性能调试脚本经常读写 `/sys` 或 `/proc` 节点，必须在 Shell 业务层前置进行 root 检查，防止无权限导致逻辑失效：
  ```sh
  if [ "$(id -u)" -ne 0 ]; then
      echo "[ERROR] 此操作需要 root 权限，请在执行前运行 adb root" >&2
      exit 1
  fi
  ```
- **防御性节点写入**：严禁在 Shell 脚本中直接使用裸 `echo val > /sys/...` 的写入形式。为了防范节点不存在或权限受限时脚本崩溃，必须使用统一的封装函数进行写入，对存在性及写入状态进行防御检查：
  ```sh
  # write_sysfs <path> <value> <description>
  write_sysfs() {
      local path="$1"
      local value="$2"
      local desc="$3"
      if [ ! -e "$path" ]; then
          echo "[WARN] 节点不存在，跳过写入: $path ($desc)" >&2
          return 1
      fi
      if ! echo "$value" > "$path" 2>/dev/null; then
          echo "[ERROR] 写入节点失败: $path <- $value ($desc)" >&2
          return 1
      fi
      echo "[INFO] $desc 成功 -> $value ($path)"
      return 0
  }
  ```

### 错误状态回传与拦截机制 (Exit Codes)

- **Shell 退出码规范**：Shell 脚本在检测到严重错误（如参数校验失败、关键节点不可写入）时必须显式以 `exit 1`（或其他非 0 状态码）退出；在执行成功时必须以 `exit 0` 退出。
- **ADB 退出码继承**：在使用 `adb shell "sh -s" < script.sh` 执行脚本时，若 adb 连接正常，`adb shell` 命令本身的退出状态码将完美继承自 Shell 脚本的 `exit` 退出码。
- **Bat 入口层阻断**：Bat 入口脚本调用 `adb shell` 后，必须检查 `!ERRORLEVEL!`。如果退出码非 0，必须立即拦截后续操作，避免继续执行不安全的命令或尝试拉取不存在的日志：
  ```bat
  adb shell "sh -s %ACTION%" < "%SH_SCRIPT%"
  if !ERRORLEVEL! neq 0 (
      echo [ERROR] 脚本执行失败，退出码: !ERRORLEVEL!
      exit /b !ERRORLEVEL!
  )
  ```

---

## Windows 批处理编码规范

### 脚本头部（强制格式）

```bat
@echo off
chcp 65001 >nul
:: ============================================================
:: Author: WangQiang
:: Date:   <日期>
:: Desc:   <脚本功能描述>
:: Usage:  <脚本名>.bat [参数说明]
:: ============================================================
setlocal
:: 默认只使用 setlocal。仅在明确需要复合语句/循环/条件块内动态计算并立即读取变量时，才使用 setlocal EnableDelayedExpansion。
```

> **注意顺序与原则：**
> 1. `chcp 65001` 必须在 `setlocal` **之前**，否则代码页设置不生效。
> 2. **Author 声明规范**：所有新建或维护的 `.bat` 及 `.sh` 脚本头部，Author 字段一律统一声明为 `wangqiang`。
> 3. **延迟变量扩展最小化原则**：默认一律使用 `setlocal`。除非脚本内存在 `for` / `if` 块中需要原地修改并立刻消费变量（如 `!VAR!`），否则**严禁无意义地默认开启 `setlocal EnableDelayedExpansion`**，避免引入感叹号转义等副作用。

### *_all.bat 主入口初始化顺序（强制）

`*_all.bat` 主入口脚本必须严格按照以下顺序执行初始化，**不得颠倒**：

```bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "cmd=%~1"
set "param1=%~2"

:: 1. 优先判断 help，无需初始化环境直接响应，避免无谓的 ADB 检测
if "%cmd%"==""   goto :usage
if /i "%cmd%"=="-h"   goto :usage
if /i "%cmd%"=="help" goto :usage

:: 2. 通过 help 检测后，才初始化环境变量（SCRIPT_DIR / MODULE_OUT_DIR 等）
call %INIT_BAT% %~dp0

:: 3. 环境就绪后，执行 ADB 连接检查（白名单命令会自动跳过）
call "%ADB_CHECK_BAT%" "%cmd%"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] ADB check failed.
    exit /b %ERRORLEVEL%
)

:: 4. 确保输出目录存在
if not exist "%MODULE_OUT_DIR%" mkdir "%MODULE_OUT_DIR%"

:: 5. 命令分发 (路由分发必须尽量写成单行，保持对齐与紧凑)
if /i "%cmd%"=="top"   goto :top_activity
if /i "%cmd%"=="qs"    goto :quick_search
if /i "%cmd%"=="xxx"   goto :xxx
```

> **关键原则：**
> 1. help 判断必须放在 `call %INIT_BAT%` **之前**，确保用户单纯查看帮助时不触发环境初始化和 ADB 检测，保证响应速度且避免误报错。
> 2. **路由分发单行原则**：无论 Bat 主入口的 `if /i "%cmd%"=="xxx" goto :xxx` 还是子脚本中的命令分发，**必须尽量写成单行**，保持分发区紧凑、整洁、易读。

### 帮助信息规范（强制）

- **Bat 脚本**：帮助标签一律统一命名为 `:usage`（跳转 `goto :usage`），结尾显式 `exit /b 0`。
- **Shell 脚本**：帮助展示函数一律统一命名为 `usage()`（禁止使用 `show_help` 等自定义名称），支持 `help` / `-h` 参数触发。

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

> **规范细节：** 所有 `:usage` 标签结尾必须显式 `exit /b 0`。

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

- **文件编码限制（强制）**：所有 `.bat` 批处理文件必须严格保存为 **UTF-8 无 BOM (CRLF)** 换行符格式！带有 UTF-8 BOM 头的文件会导致 CMD 解析器发生严重偏移错乱，吞掉变量或命令。
- **避免多字节符号引发的命令截断**：严禁在 `echo` 语句中使用特殊多字节符号（如 `℃`、`→` 等），且带有中文字符的 `echo` 提示行末尾建议使用 `...` 或改用标准 ASCII 字符（如 `[INFO]`、`[ERROR]`、`[OK]`）。中文字符串如果处于 CMD 的 512 字节读块切分边界上，会导致部分汉字被斩断并报错 `xxx is not recognized`。
- 统一使用标准 ASCII 字符代替特殊符号（如用 `C` 代替 `℃`）。

### 前置条件检查

**ADB 设备检查只在 `*_all.bat` 中做一次**（由 `adb_check.bat` 统一处理），子脚本（如 `power_screen_record.bat`）不应重复检查 ADB 连接，避免冗余和不一致。

调用 `adb_check.bat` 时需传入当前子命令 `%cmd%`，由 `adb_check.bat` 内部白名单进行判断（如 `adbd`、`key` 等无需依赖真实设备在线的子命令跳过设备连接检查直接放行）：

```bat
call "%ADB_CHECK_BAT%" "%cmd%"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] ADB check failed.
    exit /b %ERRORLEVEL%
)
```

子脚本只需检查自身依赖的 `.sh` 文件是否存在：

```bat
:: 子脚本只检查 .sh 依赖文件，不重复做 ADB 检查
if not exist "%SH_SCRIPT%" (
    echo [ERROR] 找不到 shell 脚本: %SH_SCRIPT%
    exit /b 1
)
```

### 全局公共变量规范

为了避免在各子脚本中重复初始化基础变量或硬编码路径，项目通过 `init.bat` 统一提取并对外导出以下全局环境变量：
- `FORMAT_TIME`：格式为 `MMDD-HHMM` 的当前时间，用于日志和 Trace 文件的命名。
- `SCRIPT_DIR`：当前执行脚本所在的目录绝对路径（**末尾带反斜杠 `\`**）。
- `MODULE_OUT_DIR`：由当前脚本所在子目录名自动生成的输出日志存放路径（例如 `OUT\android`，**末尾不带反斜杠**）。
- `ADB_CHECK_BAT`：全局 adb 检测脚本 `adb_check.bat` 的绝对路径。

**注意**：
- `*_all.bat` 主入口必须在通过 help 检查之后，才通过 `call %INIT_BAT% %~dp0` 初始化环境变量上下文（详见"主入口初始化顺序"章节）。
- `MODULE_OUT_DIR` 末尾**不带反斜杠**，引用路径时写 `"%MODULE_OUT_DIR%\file.txt"` 而不是 `"%MODULE_OUT_DIR%file.txt"`。
- 路径变量引用时务必用双引号包裹，避免路径含空格时报错：
  ```bat
  if not exist "%MODULE_OUT_DIR%" mkdir "%MODULE_OUT_DIR%"
  ```

### 参数安全与防御

- 在批处理中解析用户传入的参数 `%1`, `%2` 时，极易因为参数为空或带空格导致脚本解析崩溃。
- 赋值时应先使用 `%~1` 剥离可能存在的双引号，再在 `set` 语句中用双引号包裹进行赋值，例如：
  ```bat
  set "cmd=%~1"
  set "param=%~2"
  ```
- 进行 `if` 逻辑比较时，变量两端必须用双引号包裹，防御变量为空的场景：
  ```bat
  if "!cmd!"=="" goto :usage
  if /i "!cmd!"=="help" goto :usage
  ```

### 统一的日志回显前缀规范

无论是 Bat 脚本还是 Shell 脚本，在回显时都应遵循统一的日志前缀规范，使控制台回显清晰，易于过滤：
- `[INFO]`：常规提示信息或当前正在执行的步骤。
- `[WARN]`：节点不存在、配置不完美但无需阻断脚本的警告提示。
- `[ERROR]`：导致脚本执行中断、返回非 0 值或设备连接失效的错误提示。
- `[OK]`：某个大型任务或初始化步骤成功完成。

### 其他规范

- **避免使用 PowerShell**：除非明确要求，坚持使用 CMD 兼容的批处理逻辑
- **硬件信息采集**：优先使用 `getprop` 和 `dumpsys SurfaceFlinger`，保证轻量化
- **输出精简**：仅保留核心指标，过滤冗余信息，除非用户要求详细日志

---

## AI 协助指令

### 常用提示词

- **双层重构：**
  > "参考 PROJECT.md 的双层控制模型，优先将指定的 bat 脚本改造成同功能的 shell 脚本，然后由主入口脚本直接通过 stdin 管道注入调用（参考 `android_all.bat` 调用 `android_refresh_rate.sh`）"
  > "针对涉及本地资源无法直接改造成纯 shell 的脚本，重构为 `.bat`（入口层/PC代理）+ `.sh`（设备业务层）的结构（参考 `power_screen_record.bat` + `power_screen_record.sh`）"

- **新脚本生成：**
  > "参考 PROJECT.md 的规范，为 [功能] 生成脚本，要求包含帮助信息、ADB 连接检查和错误处理。"

### AI 生成脚本注意事项

- 生成新脚本时，优先考虑健壮的错误处理（检查 `7z.exe`、sh 文件等依赖是否存在）
- 修改 Perfetto 配置时，确保输出保持为有效的 `.pbtxt` 结构
- 生成 `*_all.bat` 主入口时，**严格遵守主入口初始化顺序**：help 检查 → init → adb_check → mkdir → 命令分发

---

## 问题记录 (Troubleshooting)

### 1. Shell 脚本运行提示 `syntax error: unexpected 'do'`
- **原因**：Windows (CRLF) 与 Linux (LF) 换行符不兼容，脚本行尾带 `\r` 导致 `do`、`then` 等关键字解析失败
- **根本解法**：使用 **stdin 注入模式**（`adb shell "sh -s" < script.sh`），内容通过管道传输，不涉及文件换行符
- **备用方案**：push 文件后执行 `adb shell "sed -i 's/\r//' <remote_path>"` 去除 `\r`

### 2. 自提取脚本首行出现冒号 `:` 污染
- **原因**：`more +n` 偏移量计算不准，包含了标签行
- **解决方案**：确保 `SKIP` 变量准确指向标签所在行号，`more +%SKIP%` 从下一行（解释器声明行 `#!`）开始读取

### 3. Git 换行符 (CRLF) 自动转换防范
- **原因**：Windows 系统的 Git 客户端在克隆或检出代码时，默认可能会把 Linux 换行符（LF）自动转换为 Windows 换行符（CRLF），从而破坏 `.sh` 脚本在 Linux/Android 环境下的运行。
- **预防解法**：项目根目录已配置 `.gitattributes` 强制规定 `*.sh text eol=lf`。
- **修复命令**：如果本地个别文件已经被污染或编辑时意外引入了 CRLF，可以通过以下命令让 Git 重新扫描并强制规范化所有文件：
  ```bash
  git add --renormalize .
  ```

### 4. help 显示也要求 ADB 连接（主入口初始化顺序错误）
- **原因**：`call %INIT_BAT%` 和 `call "%ADB_CHECK_BAT%"` 被放在了 help 判断之前，导致用户只想看帮助时也必须有 ADB 设备连接。
- **解决方案**：严格遵守**主入口初始化顺序**规范，将 help 判断提到最前面，通过 help 检查后再执行 init 和 adb_check（参考 `android_all.bat` 的正确实现）。

### 5. 路径变量未加引号导致含空格路径失败
- **原因**：`if not exist %MODULE_OUT_DIR%` 或 `mkdir %MODULE_OUT_DIR%` 未用双引号包裹，当路径含空格时被截断。
- **解决方案**：所有路径变量引用一律加双引号：`if not exist "%MODULE_OUT_DIR%" mkdir "%MODULE_OUT_DIR%"`。

### 6. Bat 脚本运行报 `'oto'` / `'过）'` 不是内部或外部命令
- **现象**：执行脚本时随机抛出 `'oto' is not recognized` 或中文字符片段（如 `'过）' is not recognized` 等奇怪的命令解析错误。
- **原因**：`.bat` 批处理文件被意外保存成了 **纯 Linux LF (`\n`)** 换行符。Windows 的 `cmd.exe` 解释器内部采用固定 **512 字节读缓冲区** 机制，当换行符缺少 `\r` (CRLF) 且混杂 UTF-8 多字节中文时，跨 512 字节切分点会导致字符偏移严重错乱（例如 `goto` 前部被吞噬变成 `'oto'`，中文注释被腰斩残留当成命令执行）。
- **根本解法**：
  1. 所有 `.bat` 文件**必须严格保存为 UTF-8 无 BOM (CRLF 换行符)**；
  2. 修复/转换命令：在仓库根目录用脚本将所有 `.bat` 文件的 `\n` 统一规范化替换为 `\r\n`。

---
