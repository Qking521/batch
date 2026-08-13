-- 分析应用冷启动/热启动或 Activity 启动相关的耗时点
SELECT 
    slice.name AS stage_name,
    slice.dur / 1000000.0 AS dur_ms,
    process.name AS process_name,
    slice.ts / 1000000.0 AS start_time_ms
FROM slice
JOIN thread_track ON slice.track_id = thread_track.id
JOIN thread USING (utid)
JOIN process USING (upid)
WHERE slice.name LIKE '%launching%' 
   OR slice.name LIKE '%activityStart%'
   OR slice.name LIKE '%bindApplication%'
   OR slice.name LIKE '%activityResume%'
ORDER BY slice.dur DESC;
