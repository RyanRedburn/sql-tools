SET NOCOUNT ON;

--NOTE: Put a name in the DB_ID() function if you're looking for results from a context different from the executing one.
DECLARE @databaseId INT = DB_ID();

--Most expensive by reads
SELECT TOP 10 qt.[text] AS query, qs.execution_count, qs.total_logical_reads, qs.last_logical_reads,
	qs.max_logical_reads, qs.total_logical_writes, qs.last_logical_writes, qs.max_logical_writes,
	qs.total_worker_time, qs.last_worker_time, qs.max_worker_time, qs.total_elapsed_time,
	qs.last_elapsed_time, qs.max_elapsed_time, qs.last_execution_time, qp.query_plan
FROM sys.dm_exec_query_stats AS qs
	CROSS APPLY sys.dm_exec_sql_text(qs.[sql_handle]) AS qt
	CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
	CROSS APPLY sys.dm_exec_plan_attributes(qs.plan_handle) AS pa
WHERE pa.attribute = N'dbid'
	AND pa.[value] = @databaseId
ORDER BY qs.total_logical_reads DESC;

--Most expensive by writes
SELECT TOP 10 qt.[text] AS query, qs.execution_count, qs.total_logical_reads, qs.last_logical_reads,
	qs.max_logical_reads, qs.total_logical_writes, qs.last_logical_writes, qs.max_logical_writes,
	qs.total_worker_time, qs.last_worker_time, qs.max_worker_time, qs.total_elapsed_time,
	qs.last_elapsed_time, qs.max_elapsed_time, qs.last_execution_time, qp.query_plan
FROM sys.dm_exec_query_stats AS qs
	CROSS APPLY sys.dm_exec_sql_text(qs.[sql_handle]) AS qt
	CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
	CROSS APPLY sys.dm_exec_plan_attributes(qs.plan_handle) AS pa
WHERE pa.attribute = N'dbid'
	AND pa.[value] = @databaseId
ORDER BY qs.total_logical_writes DESC;

--Most expensive by CPU time
SELECT TOP 10 qt.[text] AS query, qs.execution_count, qs.total_logical_reads, qs.last_logical_reads,
	qs.max_logical_reads, qs.total_logical_writes, qs.last_logical_writes, qs.max_logical_writes,
	qs.total_worker_time, qs.last_worker_time, qs.max_worker_time, qs.total_elapsed_time,
	qs.last_elapsed_time, qs.max_elapsed_time, qs.last_execution_time, qp.query_plan
FROM sys.dm_exec_query_stats AS qs
	CROSS APPLY sys.dm_exec_sql_text(qs.[sql_handle]) AS qt
	CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
	CROSS APPLY sys.dm_exec_plan_attributes(qs.plan_handle) AS pa
WHERE pa.attribute = N'dbid'
	AND pa.[value] = @databaseId
ORDER BY qs.total_worker_time DESC;