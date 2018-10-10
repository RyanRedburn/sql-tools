--NOTE: Change the scan mode on the sys.dm_db_index_physical_stats query depending on need (SAMPLED, DETAILED, etc.).

SET NOCOUNT ON;

--Fill in database, schema, and table names as necessary
DECLARE @database_name SYSNAME = DB_NAME(),
		@table_prefix SYSNAME = N'dbo',
		@table_name SYSNAME = N'Employee';

--Basic index information
SELECT index_id, [name] AS index_name, [type], [type_desc], is_primary_key, is_unique_constraint, fill_factor, is_padded,
	has_filter, filter_definition
FROM sys.indexes
WHERE [object_id] = OBJECT_ID(@table_prefix + N'.' + @table_name)
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
WHERE i.[object_id] = OBJECT_ID(@table_prefix + N'.' + @table_name)
ORDER BY i.index_id, ic.key_ordinal;

--Index storage/fragmentation information
SELECT index_id, index_type_desc, index_depth, index_level, page_count, record_count, ghost_record_count,
	version_ghost_record_count,	avg_page_space_used_in_percent, avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(@database_name), OBJECT_ID(@table_prefix + N'.' + @table_name), NULL, NULL, N'SAMPLED')
ORDER BY index_id, index_level;

--Index usage information
SELECT index_id, user_seeks, user_scans, user_updates, last_user_seek, last_user_scan, last_user_update
FROM sys.dm_db_index_usage_stats
WHERE database_id = DB_ID(@database_name)
	AND [object_id] = OBJECT_ID(@table_prefix + N'.' + @table_name)
ORDER BY index_id;

--Missing index information
SELECT index_handle, equality_columns, inequality_columns, included_columns
FROM sys.dm_db_missing_index_details
WHERE database_id = DB_ID(@database_name)
	AND [object_id] = OBJECT_ID(@table_prefix + N'.' + @table_name)
ORDER BY index_handle;