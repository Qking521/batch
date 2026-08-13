-- 统计各进程的 CPU 总耗时（毫秒）及调度切片次数
SELECT 
    process.name AS process_name,
    process.pid AS pid,
    SUM(sched.dur) / 1000000.0 AS total_cpu_dur_ms,
    COUNT(sched.id) AS sched_count
FROM sched
JOIN thread USING (utid)
JOIN process USING (upid)
WHERE sched.dur > 0
GROUP BY process.upid
ORDER BY total_cpu_dur_ms DESC
LIMIT 20;
