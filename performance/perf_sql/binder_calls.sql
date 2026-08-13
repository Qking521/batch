-- 统计 Binder 事务跨进程通信耗时Top 30
SELECT 
    slice.name AS binder_call,
    slice.dur / 1000000.0 AS dur_ms,
    process.name AS client_process,
    thread.name AS client_thread
FROM slice
JOIN thread_track ON slice.track_id = thread_track.id
JOIN thread USING (utid)
JOIN process USING (upid)
WHERE slice.name LIKE '%binder transaction%'
   OR slice.name LIKE '%binder reply%'
ORDER BY slice.dur DESC
LIMIT 30;
