#!/bin/bash
#!/usr/bin/env bash
set -euo pipefail
set -u # 即使开启了 strict mode 也能安全运行

CONTAINER="power-docker_servod"
SERVOD_CMD="start-servod -c local -b bluey -m mica -n power -- -c mica_rev0.xml"
#设置默认时间
TIME=5
ACTION=""
CUSTOM_ARG=""
OPEN=false

usage() {
    cat <<EOF
Usage: power [OPTIONS]

Options:
    -t <sec>  Set time TIME in seconds
    -c        Run CUR action
    -v        Run VOL action
    -w        Run POWER action
    -o        open csv file action
    -s        Stop the container
    -h        Show help

Examples:
  power -c
  power -v
  power -w
  power -t 5 -c
EOF
}

ensure_container() {
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        echo "Container ${CONTAINER} not found, creating..."
        ${SERVOD_CMD}
    else
        echo "Container ${CONTAINER} already exists, skipping creation."
    fi
}

csv_file_config() {
	OUTPUT_DIR="$HOME/power_logs"
	mkdir -p "$OUTPUT_DIR"
	TIMESTAMP=$(date +%Y%m%d_%H%M%S)
	RAW_LOG="$OUTPUT_DIR/raw_${TIMESTAMP}.txt"
	CSV_FILE="$OUTPUT_DIR/power_data_${TIMESTAMP}.csv"
}

action_power() {
    echo "Running POWER action...,time: $TIME"
	csv_file_config
	POWER_PARAMETER="PPVAR_BATT_mw BL_PWR_mw PP3800_VPH_PWR_A_S5_mw PP3800_VPH_PWR_B_S5_mw PP3300_Z1_mw PP5000_S5_mw PP3300_GSC_Z1_mw PP3300_EC_Z1_mw PP3300_TCHPAD_S3_mw PP3300_WLAN_X_mw PP3300_NVME_X_mw PP3300_TCHSCR_X_mw PP3300_UCAM_X_mw PP3300_FP_Z1_X_mw PP3300_DISP_X_mw PP0900_RT_X_mw GFX_VIN_V_mw APC0_VIN_V_mw APC1_VIN_V_mw PP1200_L12B_S3_mw PP1800_L15B_S3_mw PP0730_S12C_S0_mw PP0710_S78C_S0_mw PP1800_L1I_S3_mw PP0900_VDD2L_MEM_S3_mw PP1080_S23I_S3_mw PP0800_S56I_S0_mw PP0500_VDDQ_MEM_S0_mw PP0730_S12J_S3_mw PP0800_S34J_S0_mw PP0730_S678J_S0_mw"
    if [ -n "$CUSTOM_ARG" ]; then
        POWER_PARAMETER="$CUSTOM_ARG"
    fi
    dut-control -- $POWER_PARAMETER -t $TIME | tee "$RAW_LOG"
	if [ "$OPEN" = true ]; then
		open_csv_file
    fi
}

action_voltage() {
    echo "Running VOL action...,time: $TIME"
	csv_file_config
	VOLTAGE_PARAMETER="PPVAR_BATT_mv BL_PWR_mv PP3800_VPH_PWR_A_S5_mv PP3800_VPH_PWR_B_S5_mv PP3300_Z1_mv PP5000_S5_mv PP3300_GSC_Z1_mv PP3300_EC_Z1_mv PP3300_TCHPAD_S3_mv PP3300_WLAN_X_mv PP3300_NVME_X_mv PP3300_TCHSCR_X_mv PP3300_UCAM_X_mv PP3300_FP_Z1_X_mv PP3300_DISP_X_mv PP0900_RT_X_mv GFX_VIN_V_mv APC0_VIN_V_mv APC1_VIN_V_mv PP1200_L12B_S3_mv PP1800_L15B_S3_mv PP0730_S12C_S0_mv PP0710_S78C_S0_mv PP1800_L1I_S3_mv PP0900_VDD2L_MEM_S3_mv PP1080_S23I_S3_mv PP0800_S56I_S0_mv PP0500_VDDQ_MEM_S0_mv PP0730_S12J_S3_mv PP0800_S34J_S0_mv PP0730_S678J_S0_mv"
    if [ -n "$CUSTOM_ARG" ]; then
        VOLTAGE_PARAMETER="$CUSTOM_ARG"
    fi
    dut-control -- $VOLTAGE_PARAMETER -t $TIME | tee "$RAW_LOG"
	if [ "$OPEN" = true ]; then
		open_csv_file
    fi
}

action_current() {
    echo "Running CURRENT action...,time: $TIME"
	csv_file_config
	CURRENT_PARAMETER="PPVAR_BATT_ma BL_PWR_ma PP3800_VPH_PWR_A_S5_ma PP3800_VPH_PWR_B_S5_ma PP3300_Z1_ma PP5000_S5_ma PP3300_GSC_Z1_ma PP3300_EC_Z1_ma PP3300_TCHPAD_S3_ma PP3300_WLAN_X_ma PP3300_NVME_X_ma PP3300_TCHSCR_X_ma PP3300_UCAM_X_ma PP3300_FP_Z1_X_ma PP3300_DISP_X_ma PP0900_RT_X_ma GFX_VIN_V_ma APC0_VIN_V_ma APC1_VIN_V_ma PP1200_L12B_S3_ma PP1800_L15B_S3_ma PP0730_S12C_S0_ma PP0710_S78C_S0_ma PP1800_L1I_S3_ma PP0900_VDD2L_MEM_S3_ma PP1080_S23I_S3_ma PP0800_S56I_S0_ma PP0500_VDDQ_MEM_S0_ma PP0730_S12J_S3_ma PP0800_S34J_S0_ma PP0730_S678J_S0_ma"
    if [ -n "$CUSTOM_ARG" ]; then
        CURRENT_PARAMETER="$CUSTOM_ARG"
    fi
    dut-control -- $CURRENT_PARAMETER -t $TIME | tee "$RAW_LOG"
	if [ "$OPEN" = true ]; then
		open_csv_file
    fi
}

action_custom() {
    echo "Running custom action...$1, time: $TIME"
	csv_file_config
    dut-control -- $1 -t $TIME | tee "$RAW_LOG"
	if [ "$OPEN" = true ]; then
		open_csv_file
    fi
}

action_stop() {
    echo "Running STOP $CONTAINER"
    docker rm -f power-docker_servod 2>/dev/null || echo "容器不存在"
}

open_csv_file() {
    {
		echo "NAME,COUNT,AVERAGE,STDDEV,MAX,MIN"
		grep '^@@' "$RAW_LOG" \
			| sed 's/^@@[[:space:]]*//' \
			| awk 'NF==6 && $1!="NAME" {print $1","$2","$3","$4","$5","$6}'
	} > "$CSV_FILE"

	echo CSV_FILE1=$CSV_FILE
    if [[ ! -e "$CSV_FILE" ]]; then
        echo "目标文件不存在，请确认!!!"
        exit 1
    fi
	explorer.exe "$(wslpath -w "$CSV_FILE")"
}

# 提取辅助函数：循环抓取所有后续非 '-' 开头的可选参数
parse_optional_arg() {
    CUSTOM_ARG=""
    local args=()

    # 循环检查 OPTIND 指向的参数，只要存在且不以 '-' 开头就全抓进来
    while [[ $OPTIND -le $# ]]; do
        local next_token="${@:$OPTIND:1}"
        if [[ -n "$next_token" && "$next_token" != -* ]]; then
            args+=("$next_token")
            OPTIND=$((OPTIND + 1)) # 索引递增
        else
            break # 遇到以 '-' 开头的选项（如 -t）或者末尾，立即退出循环
        fi
    done

    # 将抓取到的多个参数用空格拼成一个字符串赋值给 CUSTOM_ARG
    # 例如："PP3300_TCHSCR_X_mw PP5000_S5_mw"
    CUSTOM_ARG="${args[*]-}"
}
# -------------------------
# 参数解析
# -------------------------
if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

ensure_container

while getopts "t:cvwsdho" opt; do
    case "$opt" in
        t) TIME="$OPTARG" ;;
        c) ACTION="current"; parse_optional_arg "$@" ;;
        v) ACTION="voltage"; parse_optional_arg "$@" ;;
        w) ACTION="power"; parse_optional_arg "$@" ;;
        s) ACTION="stop" ;;
		o) OPEN=true ;;
        h) ACTION="help" ;;
        *) ACTION="help" ;;
    esac
done

echo "CUSTOM_ARG: $CUSTOM_ARG"

case "$ACTION" in 
    "current") action_current;;
    "voltage") action_voltage;;
    "power") action_power;;
    "stop") action_stop ;;
    "help") usage; exit 0 ;;
    *) usage; exit 0 ;;
esac