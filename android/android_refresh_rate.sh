#!/bin/sh
log()  { echo "[INFO] $*"; }
err()  { echo "[ERROR] $*" 1>&2; }
die()  { err "$*"; exit 1; }
 
usage() {
    cat <<EOF
用法: $0 <子命令> [参数...]
  on               打开刷新率显示
  off              关闭刷新率显示
  60               设置刷新率为60Hz
  90               设置刷新率为90Hz
  120              设置刷新率为120Hz
EOF
    exit 1
}
 
open_refresh_rate_display()     { service call SurfaceFlinger 1034 i32 1 >/dev/null; }
close_refresh_rate_display()     { service call SurfaceFlinger 1034 i32 0 >/dev/null; }
fixed_refresh_rate_60()     { service call SurfaceFlinger 1035 i32 2 >/dev/null; }
fixed_refresh_rate_90()     { service call SurfaceFlinger 1035 i32 1 >/dev/null; }
fixed_refresh_rate_120()     { service call SurfaceFlinger 1035 i32 0 >/dev/null; }
 
route() {
    #bat传过来的参数是包含原始的命令的，所以这里需要shift剥掉传给bat的第一个参数
    shift 2>/dev/null
    cmd="$1"; 
    case "$cmd" in
        on)        open_refresh_rate_display ;;
        off)       close_refresh_rate_display ;;
        60)        fixed_refresh_rate_60 ;;
        90)        fixed_refresh_rate_90 ;;
        120)       fixed_refresh_rate_120 ;;
        ""|-h|--help) usage ;;
        *)          err "未知子命令: '$cmd'"; usage ;;
    esac
}
 
main() { route "$@"; }
 
main "$@"