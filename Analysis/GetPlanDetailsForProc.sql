SET NOCOUNT ON;

DECLARE @proc_name SYSNAME = N'';

--Query plan(s)
SELECT o.[object_id], s.plan_handle, s.cached_time, s.last_execution_time, s.execution_count, h.query_plan
FROM sys.objects AS o 
	JOIN sys.dm_exec_procedure_stats AS s ON o.[object_id] = s.[object_id]
	CROSS APPLY sys.dm_exec_query_plan(s.plan_handle) AS h
WHERE o.[object_id] = OBJECT_ID(@proc_name);

--Session options
SELECT o.[object_id], s.plan_handle, a.attribute, a.[value], a.is_cache_key
FROM sys.objects AS o 
	JOIN sys.dm_exec_procedure_stats AS s ON o.[object_id] = s.[object_id]
	CROSS APPLY sys.dm_exec_plan_attributes(s.plan_handle) AS a
WHERE o.[object_id] = OBJECT_ID(@proc_name)
ORDER BY o.[object_id], s.plan_handle, a.attribute;

SET NOCOUNT OFF;
