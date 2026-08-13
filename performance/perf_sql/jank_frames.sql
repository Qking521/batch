-- 统计绘制帧及掉帧/超时帧（如 Choreographer#doFrame 耗时大于 16.6ms 的帧）
SELECT 
    process.name AS process_name,
    thread.name AS thread_name,
    slice.name AS frame_name,
    slice.dur / 1000000.0 AS dur_ms,
    slice.ts / 1000000.0 AS start_time_ms
FROM slice
JOIN thread_track ON slice.track_id = thread_track.id
JOIN thread USING (utid)
JOIN process USING (upid)
WHERE slice.name LIKE '%Choreographer#doFrame%' 
   OR slice.name LIKE '%DrawFrame%'
ORDER BY slice.dur DESC
LIMIT 50;
