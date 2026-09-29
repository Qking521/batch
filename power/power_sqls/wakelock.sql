-- 标签: wakelock
-- 用途: 统计各进程持有 wakelock 的次数、总时长、最大时长、平均时长

WITH target_tracks AS (
  SELECT id, name FROM track
  WHERE id IN (9, 35)
     OR LOWER(name) LIKE '%wakelock%'
     OR LOWER(name) LIKE '%power%'
),
wakelock_slices AS (
  SELECT
    s.id AS slice_id,
    s.name AS wakelock_name,
    s.dur AS dur,
    COALESCE(pt.upid, th.upid) AS upid
  FROM slice s
  JOIN target_tracks tr ON s.track_id = tr.id
  LEFT JOIN process_track pt ON s.track_id = pt.id
  LEFT JOIN thread_track t_tr ON s.track_id = t_tr.id
  LEFT JOIN thread th ON t_tr.utid = th.utid
)
SELECT
  COALESCE(p.name, '[Kernel/System]') AS process_name,
  w.wakelock_name,
  COUNT(*) AS hold_count,
  ROUND(SUM(w.dur) / 1e6, 2) AS total_dur_ms,
  ROUND(MAX(w.dur) / 1e6, 2) AS max_dur_ms,
  ROUND(AVG(w.dur) / 1e6, 2) AS avg_dur_ms
FROM wakelock_slices w
LEFT JOIN process p ON w.upid = p.upid
WHERE w.dur > 0
GROUP BY process_name, w.wakelock_name
ORDER BY total_dur_ms DESC;
