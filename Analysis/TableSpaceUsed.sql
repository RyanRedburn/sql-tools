SET NOCOUNT ON;

WITH result([object_id], [schema_id], table_type, row_count, partition_count, total_space_in_mb, used_space_in_mb, unused_space_in_mb)
AS
(
	SELECT t.[object_id], t.[schema_id], i.[type_desc], SUM(ps.row_count), COUNT(DISTINCT ps.partition_number),
		CAST(ROUND((SUM(a.total_pages) * 8) / 1024.00, 2) AS DECIMAL(18,2)), CAST(ROUND((SUM(a.used_pages) * 8) / 1024.00, 2) AS DECIMAL(18,2)),
		CAST(ROUND(((SUM(a.total_pages) - SUM(a.used_pages)) * 8) / 1024.00, 2) AS DECIMAL(18,2))
	FROM sys.tables AS t
		JOIN sys.schemas AS s ON s.[schema_id] = t.[schema_id]
		JOIN sys.indexes AS i ON i.[object_id] = t.[object_id]
		JOIN sys.dm_db_partition_stats AS ps ON ps.[object_id] = i.[object_id]
			AND ps.index_id = i.index_id
		JOIN sys.allocation_units AS a ON a.container_id = ps.[partition_id]
	WHERE t.[type] = 'U'
		AND t.is_ms_shipped = 0
		AND i.[type] IN (0, 1, 5)
	GROUP BY t.[object_id], t.[schema_id], i.[type_desc])
SELECT s.[name] AS [schema_name], t.[name] AS table_name, r.table_type, r.row_count, r.partition_count,
	r.total_space_in_mb, r.used_space_in_mb, r.unused_space_in_mb, t.lock_escalation_desc, t.is_replicated,
	t.is_published, t.is_merge_published, t.is_sync_tran_subscribed, t.is_tracked_by_cdc, t.is_filetable
FROM result AS r
	JOIN sys.tables AS t ON t.[object_id] = r.[object_id]
	JOIN sys.schemas AS s ON s.[schema_id] = t.[schema_id]
ORDER BY total_space_in_mb DESC;