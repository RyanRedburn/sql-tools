SET NOCOUNT ON;

SELECT t.[object_id], t.[name] AS table_name, s.stats_id, s.[name] AS stats_name, s.auto_created, s.user_created, s.no_recompute, s.is_temporary,
	s.is_incremental, sp.last_updated, sp.[rows], sp.rows_sampled, sp.steps, sp.unfiltered_rows, sp.modification_counter
FROM sys.tables AS t
	JOIN sys.stats AS s ON s.[object_id] = t.[object_id]
	CROSS APPLY sys.dm_db_stats_properties(s.[object_id], s.stats_id) AS sp
ORDER BY t.[name], s.[name];