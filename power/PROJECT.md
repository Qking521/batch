# batScript 项目规范 (PROJECT.md)

---

## [规则-001] BAT 文件必须使用 CRLF 行尾符

### 问题描述

Windows `cmd.exe` 解析 `.bat` 文件时**严格依赖 CRLF (`\r\n`) 行尾符**。
若文件为 LF (`\n`) 行尾（Linux 格式），cmd 会把多行内容拼到一起解析，
导致 token 截断，产生一系列莫名报错：

```
'r_supply' is not recognized as an internal or external command
'_DIRparam1.sql"' is not recognized ...
'xit' is not recognized ...
do was unexpected at this time
```

这些错误**不是逻辑问题，也不是中文问题**，根本原因是行尾符错误。

### 根本原因

AI 工具（write_to_file）写出的文件默认是 LF 行尾，
Windows bat 文件需要 CRLF 行尾，cmd.exe 才能正确逐行解析。

### 修复规则

| 文件类型 | 行尾符要求 |
|---|---|
| `.bat` | **必须 CRLF**，LF 会导致解析错误 |
| `.sql` / `.md` / `.sh` / `.py` | LF 或 CRLF 均可 |

### 修复方法

每次 AI 工具生成或修改 `.bat` 文件后，需手动或通过命令转换行尾符：

**方法一：编辑器**（推荐日常使用）
- VS Code 右下角点击 `LF` → 改为 `CRLF`，保存

**方法二：命令行转换（必须指定 UTF8 编码，否则中文会乱码）**
```powershell
(Get-Content "xxx.bat" -Encoding UTF8) | Set-Content "xxx.bat" -Encoding UTF8
```

**方法三：git 配置**（一劳永逸）
```bash
git config core.autocrlf true
```

### 受影响文件记录

| 文件 | 时间 | 问题 | 处理 |
|---|---|---|---|
| `power\power_sql.bat` | 2026-08-12 | AI 写出 LF 行尾导致解析错误 | 手动改为 CRLF 后恢复正常 |

---

## [规则-002] SH 脚本必须把 usage 独立成函数，且无参数时调用 usage

### 问题描述

`.sh` 脚本（经 `adb shell "sh -s <args>" < xxx.sh` 调用）里若 help/usage 文本直接内联在
`case` 分支中，容易重复、遗漏，且调用方传入 `-h/--help` 时行为不一致。

### 规范要求

1. **usage 必须独立成函数**：用 `usage() { ... }` 定义，内容统一打印用法与示例。
2. **无参数（空串）必须进 usage**：`case "$ACTION" in ... "") usage ;;`。
3. **`-h/--help` 也进 usage**：`case` 分支里 `-h|--help|help|usage|"") usage ;;`。
4. **未知参数**：打印错误到 stderr 后仍调用 usage 并 `exit 1`。

### 参考模板

```sh
ACTION="$1"

usage() {
    echo "Usage:"
    echo "  power cat wl     Show wake locks"
    echo "  power cat gpio   Show GPIO status"
}

case "$ACTION" in
    wl)   do_wakelock ;;
    gpio) do_gpio ;;
    -h|--help|help|usage|"")
        usage
        ;;
    *)
        echo "[ERROR] 未知参数: $ACTION" >&2
        usage
        exit 1
        ;;
esac
```

### 为什么 `-h` 不能直接传进 sh

`adb shell "sh -s -h"` 里 `-h` 以 `-` 开头，会被设备上的 sh（toybox）当作 sh 自身的选项吞掉，
导致脚本 `$1` 为空。**必须**在 bat 层先把 `-h/--help` 规范化为 `help`（不含 `-`）再传给 sh：

```bat
set "CAT_ACTION=%param1%"
if /i "%CAT_ACTION%"=="-h"     set "CAT_ACTION=help"
if /i "%CAT_ACTION%"=="--help" set "CAT_ACTION=help"
adb shell "sh -s %CAT_ACTION%" < "%SH_SCRIPT%"
```

---

## 目录结构

```
power/
  power_sql.bat          # bat 调度脚本（必须 CRLF）
  PROJECT.md             # 本规范文档
  power_sqls/
    battery.sql          # tag: battery  查看电量/电压时间线
    power.sql            # tag: power    Power Rails 分轨道能耗
    dcr.sql              # tag: dcr      电池耗电速率分析（含 __BATTERY_CAP__ 占位符）
    wakelock.sql         # tag: wakelock wakelock 持有统计
    test.sql             # tag: test     临时测试
```

## SQL 标签机制

- **标签 = 文件名**：`power_sqls\<tag名>.sql` 即为一个可用标签
- **新增标签**：在 `power_sqls\` 目录下新建 `.sql` 文件即可，无需修改 bat
- **直接执行**：`.sql` 文件可直接在任何 SQL 工具中打开执行

## SQL 占位符

bat 执行时会对 `.sql` 文件做占位符替换（`:build_sql_with_vars`）：

| 占位符 | 替换值 | 来源 |
|---|---|---|
| `__BATTERY_CAP__` | 实际电池额定容量 (mAh) | `adb shell cat .../charge_full_design`，失败时默认 5200 |

在其他工具中直接执行 SQL 时，手动将 `__BATTERY_CAP__` 替换为实际容量数字即可。
