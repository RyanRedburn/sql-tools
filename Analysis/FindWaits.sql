SET NOCOUNT ON;

SELECT req.session_id, blocking_session_id, ses.[host_name], DB_NAME(req.database_id) AS [database_name],
	ses.login_name, req.[status], req.command, req.start_time, req.cpu_time,
	req.total_elapsed_time / 1000.0 AS total_elapsed_time, req.command, req.wait_type, sqltext.[text]
FROM sys.dm_exec_requests AS req
	CROSS APPLY sys.dm_exec_sql_text(req.[sql_handle]) AS sqltext
	JOIN sys.dm_exec_sessions AS ses ON ses.session_id = req.session_id
WHERE req.wait_type IS NOT NULL;

SET NOCOUNT OFF;
