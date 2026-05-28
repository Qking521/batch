# Windows Batch Script Language Specification  
Windows 批处理脚本语言规范  
（适用于 `.bat` / `.cmd`）

---

## 1. 概述

Windows Batch Script 是由 **cmd.exe** 解释执行的脚本语言，用于自动化 Windows 系统任务。  
它属于行式解释语言，语法简单但解析规则复杂，尤其在变量展开、转义、换行符等方面有独特行为。

---

## 2. 文件格式规范

### 2.1 文件扩展名
- `.bat`（推荐）
- `.cmd`（行为略有差异，但大多数场景等价）

### 2.2 换行符（极重要）
- **必须使用 CRLF (`\r\n`)**
- 使用 LF (`\n`) 会导致：
  - `for` 循环失效  
  - `goto` 标签无法识别  
  - `call` 参数错乱  
  - 输出出现 `^M`  
  - 脚本随机失败  

### 2.3 字符编码
- 推荐：ANSI / ASCII  
- 支持：UTF‑8（无 BOM）  
- 不推荐：UTF‑8 BOM（可能导致脚本开头出现乱码字符）

---

## 3. 执行模型

### 3.1 解析顺序（cmd.exe 的核心机制）
cmd.exe 在执行一行命令时按以下顺序解析：

1. **变量替换**（`%VAR%`）  
2. **引号处理**  
3. **命令分割**（`&`, `&&`, `||`）  
4. **重定向解析**（`>`, `>>`, `<`）  
5. **管道解析**（`|`）  
6. **执行命令**

### 3.2 执行方式
- 直接执行脚本  
  ```
  script.bat
  ```
- 调用子脚本（不退出当前脚本）  
  ```
  call script.bat
  ```
- 退出当前脚本  
  ```
  exit /b
  ```

---

## 4. 注释规范

### 4.1 单行注释
```
REM 这是注释
```

### 4.2 快速注释（非正式）
```
:: 这是注释
```
> 注意：`::` 在某些上下文（如括号内）可能被解析为标签，不完全可靠。

---

## 5. 变量系统

### 5.1 定义变量
```
set VAR=value
```

### 5.2 读取变量
```
echo %VAR%
```

### 5.3 延迟变量展开（循环中必须）
```
setlocal enabledelayedexpansion
echo !VAR!
```

### 5.4 环境变量示例
- `%PATH%`
- `%CD%`
- `%ERRORLEVEL%`

---

## 6. 控制流语法

### 6.1 条件判断
```
if EXIST file.txt echo found
if "%VAR%"=="value" echo equal
if ERRORLEVEL 1 echo error
```

### 6.2 多分支
```
if ... (
    ...
) else (
    ...
)
```

---

## 7. 循环语法

### 7.1 遍历文件
```
for %%f in (*.txt) do echo %%f
```

### 7.2 数字循环
```
for /l %%i in (1,1,10) do echo %%i
```

### 7.3 遍历命令输出
```
for /f "tokens=*" %%a in ('dir /b') do echo %%a
```

---

## 8. 标签与“函数”

### 8.1 定义标签
```
:myfunc
echo hello
exit /b
```

### 8.2 调用标签
```
call :myfunc
```

### 8.3 返回值
```
exit /b 1
```

---

## 9. 输入输出

### 9.1 输出文本
```
echo text
echo(
```

### 9.2 重定向
```
command > file
command >> file
command < input.txt
```

### 9.3 管道
```
command1 | command2
```

---

## 10. 字符串处理

### 10.1 子串
```
%VAR:~0,3%
```

### 10.2 替换
```
%VAR:old=new%
```

---

## 11. 特殊字符与转义

### 11.1 需要转义的字符
```
& | < > ^ % ! ( )
```

### 11.2 转义方式
```
^&
^|
^>
```

---

## 12. 错误处理

### 12.1 检查 ERRORLEVEL
```
if errorlevel 1 echo failed
```

### 12.2 设置 ERRORLEVEL
```
exit /b 1
```

---

## 13. 常用命令列表

| 命令 | 说明 |
|------|------|
| `echo` | 输出文本 |
| `set` | 设置变量 |
| `if` | 条件判断 |
| `for` | 循环 |
| `call` | 调用脚本或标签 |
| `goto` | 跳转 |
| `exit` | 退出脚本 |
| `dir` | 列出文件 |
| `copy` | 复制文件 |
| `move` | 移动文件 |
| `del` | 删除文件 |

---

## 14. 批处理最佳实践

- 开头使用：
  ```
  @echo off
  setlocal enabledelayedexpansion
  ```
- `.bat` 文件必须使用 **CRLF**
- 避免 UTF‑8 BOM
- 使用 `call` 调用子脚本
- 使用 `echo(` 输出空行
- 使用 `.gitattributes` 管理换行符

---

