--NOTE: Change the scan mode on the sys.dm_db_index_physical_stats query depending on need (SAMPLED, DETAILED, etc.).

SET NOCOUNT ON;

--Physical statistics for indexes on user tables.
SELECT t.[name] AS table_name, i.[name] AS index_name, i.index_id, ips.index_type_desc, ips.index_level, ips.page_count,
	ips.record_count, ips.ghost_record_count, ips.version_ghost_record_count, ips.avg_page_space_used_in_percent, ips.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, N'SAMPLED') AS ips
	JOIN sys.indexes AS i ON i.[object_id] = ips.[object_id]
		AND i.index_id = ips.index_id
	JOIN sys.tables AS t ON t.[object_id] = i.[object_id]
WHERE t.[type] = 'U'
ORDER BY t.[name], i.index_id, ips.index_level;

--Total space used by table/index type.
SELECT i.[type_desc] AS index_type, COUNT(i.[object_id]) AS object_count, (SUM(s.used_page_count) * 8) / 1024 AS space_used_in_mb
FROM sys.dm_db_partition_stats AS s
	JOIN sys.indexes AS i ON s.[object_id] = i.[object_id]
		AND s.index_id = i.index_id
	JOIN sys.tables AS t ON t.[object_id] = i.[object_id]
WHERE t.[type] = 'U'
	AND t.is_ms_shipped = 0
GROUP BY i.[type_desc]
ORDER BY space_used_in_mb DESC;

--Index usage statistics (excluding clustered indexes).
SELECT o.[name] AS table_name, i.[name] AS index_name, i.[type_desc] AS index_type_desc, us.user_seeks, us.user_scans,
	us.user_updates, us.last_user_seek, us.last_user_scan, us.last_user_update
FROM sys.indexes AS i
	JOIN sys.dm_db_index_usage_stats AS us ON us.index_id = i.index_id
		AND us.[object_id] = i.[object_id]
	JOIN sys.objects AS o ON o.[object_id] = i.[object_id]
WHERE i.[type] NOT IN (0, 1)
	AND o.[type] <> 'S'
ORDER BY o.[name], i.[name];

--Missing indexes.
SELECT id.[statement], id.equality_columns, id.inequality_columns, id.included_columns, gs.unique_compiles,
	gs.user_seeks, gs.last_user_seek, gs.user_scans, gs.last_user_scan, gs.avg_total_user_cost, gs.avg_user_impact
FROM sys.dm_db_missing_index_details AS id
	JOIN sys.dm_db_missing_index_groups AS ig ON ig.index_handle = id.index_handle
	JOIN sys.dm_db_missing_index_group_stats AS gs ON gs.group_handle = ig.index_group_handle
WHERE id.database_id = DB_ID()
ORDER BY gs.avg_total_user_cost DESC, gs.avg_user_impact DESC;