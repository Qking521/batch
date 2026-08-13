-- 导出耗时最长的 Slice 事件（前 30 名）
SELECT 
    name AS slice_name,
    dur / 1000000.0 AS duration_ms,
    ts / 1000000.0 AS timestamp_ms,
    process.name AS process_name,
    thread.name AS thread_name
FROM slice
JOIN thread_track ON slice.track_id = thread_track.id
JOIN thread USING (utid)
JOIN process USING (upid)
WHERE dur > 0
ORDER BY dur DESC
LIMIT 30;
