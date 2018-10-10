SET NOCOUNT ON;

SELECT t.[name] AS table_name, s.[name] AS [schema_name], p.[rows] AS row_count,
    (SUM(a.total_pages) * 8) / 1024 AS total_space_in_mb, (SUM(a.used_pages) * 8) / 1024 AS used_space_in_mb,
    ((SUM(a.total_pages) - SUM(a.used_pages)) * 8) / 1024 AS unused_space_in_mb
FROM sys.tables AS t
	JOIN sys.indexes AS i ON t.[object_id] = i.[object_id]
	JOIN sys.partitions AS p ON i.[object_id] = p.[object_id] AND i.index_id = p.index_id
	JOIN sys.allocation_units AS a ON p.[partition_id] = a.container_id
	LEFT JOIN sys.schemas AS s ON t.[schema_id] = s.[schema_id]
WHERE t.[name] NOT LIKE 'dt%'
    AND t.is_ms_shipped = 0
    AND i.[object_id] > 255
GROUP BY t.[name], s.[name], p.[rows]
ORDER BY total_space_in_mb DESC, used_space_in_mb DESC, table_name;