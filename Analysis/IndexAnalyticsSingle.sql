--NOTE: Change the scan mode (via the @sample_mode variable) on the sys.dm_db_index_physical_stats query depending on need (SAMPLED, DETAILED, etc.).

SET NOCOUNT ON;

--Fill in database, schema, and table names as necessary
--The physical stats query can be skipped to avoid the performance overhead
DECLARE @run_phys_stats_query BIT = 1,
		@sample_mode NVARCHAR(20) = N'SAMPLED',
		@database_name SYSNAME = DB_NAME(),
		@schema_name SYSNAME = N'dbo',
		@table_name SYSNAME = N'';

--Basic index information
SELECT index_id, [name] AS index_name, [type], [type_desc], is_disabled, is_primary_key, is_unique, is_unique_constraint,
	fill_factor, is_padded, has_filter, filter_definition
FROM sys.indexes
WHERE [object_id] = OBJECT_ID(@schema_name + N'.' + @table_name)
ORDER BY index_id;

--Index column information
SELECT i.index_id, i.[name] AS index_name, c.[name] AS column_name, ic.key_ordinal, t.[name] AS column_type, c.max_length,
	c.[precision], c.scale, c.collation_name, c.is_nullable, c.is_computed, c.is_sparse, ic.is_included_column,
	ic.partition_ordinal, ic.is_descending_key
FROM sys.indexes AS i
	JOIN sys.index_columns AS ic ON ic.index_id = i.index_id
		AND ic.object_id = i.object_id
	JOIN sys.columns AS c ON c.column_id = ic.column_id
		AND c.object_id = ic.object_id
	JOIN sys.types AS t ON t.user_type_id = c.user_type_id
WHERE i.[object_id] = OBJECT_ID(@schema_name + N'.' + @table_name)
ORDER BY i.index_id, ic.key_ordinal;

--Index storage/fragmentation information
IF @run_phys_stats_query = 1
	SELECT index_id, index_type_desc, index_depth, index_level, page_count, record_count, ghost_record_count,
		version_ghost_record_count,	avg_page_space_used_in_percent, avg_fragmentation_in_percent
	FROM sys.dm_db_index_physical_stats(DB_ID(@database_name), OBJECT_ID(@schema_name + N'.' + @table_name), NULL, NULL, @sample_mode)
	ORDER BY index_id, index_level;

--Index usage information
SELECT i.index_id, i.[name] AS index_name, i.[type_desc] AS index_type_desc, us.user_seeks, us.user_scans,
	us.user_updates, us.last_user_seek, us.last_user_scan, us.last_user_update
FROM sys.indexes AS i
	JOIN sys.dm_db_index_usage_stats AS us ON us.index_id = i.index_id
		AND us.[object_id] = i.[object_id]
	JOIN sys.objects AS o ON o.[object_id] = i.[object_id]
WHERE o.[type] <> 'S'
	AND us.database_id = DB_ID(@database_name)
	AND us.[object_id] = OBJECT_ID(@schema_name + N'.' + @table_name)
ORDER BY o.[name], i.[name];

--Missing index information
SELECT id.index_handle, id.[statement], id.equality_columns, id.inequality_columns, id.included_columns, gs.unique_compiles,
	gs.user_seeks, gs.last_user_seek, gs.user_scans, gs.last_user_scan, gs.avg_total_user_cost, gs.avg_user_impact
FROM sys.dm_db_missing_index_details AS id
	JOIN sys.dm_db_missing_index_groups AS ig ON ig.index_handle = id.index_handle
	JOIN sys.dm_db_missing_index_group_stats AS gs ON gs.group_handle = ig.index_group_handle
WHERE id.database_id = DB_ID()
	AND id.[object_id] = OBJECT_ID(@schema_name + N'.' + @table_name)
ORDER BY gs.avg_total_user_cost DESC, gs.avg_user_impact DESC;