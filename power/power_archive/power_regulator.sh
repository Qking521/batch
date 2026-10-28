#!/bin/sh
echo "正在获取供电单元信息 (Regulators)..."
printf '%-3s %-15s %-30s %-10s\n' 'ID' 'TYPE' 'NAME' 'USERS'
echo "----------------------------------------------------------------"
for d in /sys/class/regulator/regulator.[0-9]*; do
  [ -d "$d" ] || continue
  id=${d##*regulator.}
  name=$(cat $d/name 2>/dev/null || echo 'N/A')
  type=$(cat $d/type 2>/dev/null || echo 'N/A')
  num_users=$(cat $d/num_users 2>/dev/null || echo 'N/A')
  printf '%-3s %-15s %-30s %-10s\n' "$id" "$type" "$name" "$num_users"
done | sort -n