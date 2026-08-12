-- 标签: battery
-- 用途: 查看电量/电压/电荷完整时间线（官方 android.battery 模块拼好的视图）

INCLUDE PERFETTO MODULE android.battery;

SELECT
  ts,
  capacity_percent,
  voltage_uv,
  current_ua,
  charge_uah
FROM android_battery_charge
ORDER BY ts;
