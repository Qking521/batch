-- 标签: power
-- 用途: 查看 Power Rails / ODPM 分轨道能耗（仅部分机型有硬件功耗计数据）
-- 注意: 官方视图名是 android_power_rails_counters（带 _counters 后缀）

INCLUDE PERFETTO MODULE android.power_rails;

SELECT
  *,
  datetime(ts / 1e9, 'unixepoch') AS ts_utc
FROM android_power_rails_counters
ORDER BY ts;
