-- 标签: dcr
-- 用途: 基于 batt.charge_uah 统计电池电量消耗速率、每小时耗电量(mAh)及每小时掉电百分比(%/h)
-- 电池额定容量由调用方注入，占位符为 __BATTERY_CAP__（默认 5200 mAh）
-- 直接在其他工具执行时，手动将 __BATTERY_CAP__ 替换为实际容量（单位 mAh）

WITH pct AS (
  SELECT ts, value AS pct
  FROM counter c
  LEFT JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'batt.capacity_pct'
),
charge AS (
  SELECT ts, value AS charge_uah
  FROM counter c
  LEFT JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'batt.charge_uah'
),
charge_with_pct AS (
  SELECT
    c.ts,
    c.charge_uah,
    (SELECT p.pct FROM pct p WHERE p.ts <= c.ts ORDER BY p.ts DESC LIMIT 1) AS pct
  FROM charge c
),
rate AS (
  SELECT
    ts,
    pct,
    charge_uah,
    LEAD(charge_uah) OVER (ORDER BY ts) - charge_uah AS delta_uah,
    (LEAD(ts) OVER (ORDER BY ts) - ts) / 1e9 AS delta_s
  FROM charge_with_pct
)
SELECT
  datetime(ts / 1e9, 'unixepoch') AS time_utc,
  pct AS battery_pct,
  charge_uah AS charge_value_uah,
  delta_uah / NULLIF(delta_s, 0) AS raw_rate_uah_per_s,
  (delta_uah / NULLIF(delta_s, 0)) * 3600 / 1000 AS rate_mah_per_h,
  (delta_uah / NULLIF(delta_s, 0)) * 3600 / 1000 / __BATTERY_CAP__ * 100 AS rate_pct_per_h
FROM rate
ORDER BY ts;
