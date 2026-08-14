#!/system/bin/sh
# alias.sh —— 生成设备端 shell 别名，定义前做内建命令/关键字冲突检测

# 常见 shell 内建命令 + 关键字，按需补充
RESERVED="cd ls pwd echo exit export read set type alias unalias cat kill jobs wait trap test true false break continue return shift eval exec unset umask ulimit times hash getopts printf source . [ ["

check_conflict() {
    case " $RESERVED " in
        *" $1 "*)
            echo "[WARN] 别名 '$1' 与 shell 内建命令/关键字重名，已跳过定义" >&2
            return 1
            ;;
    esac
    return 0
}

# 用法: define_alias <别名> <目标脚本路径>
define_alias() {
    name="$1"
    target="$2"
    if check_conflict "$name"; then
        eval "$name() { \"$target\" \"\$@\"; }"
    fi
}

# ---- 别名定义区，只在这里加新的 ----
alias ll="ls -al"
define_alias detail /data/local/tmp/detail.sh