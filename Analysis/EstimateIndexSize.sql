--NOTE: This operation runs in the current database context
--NOTE: Estimates are only available/accurate for nonclustered indexes (exluding columnstore)
--NOTE: Estimates tend to be slightly high
--NOTE: Add the desired index columns in the VALUES clause of the INSERT statement on line 26

SET NOCOUNT ON;

-- @table_name - The table the index will be built on
-- @table_schema - The schema the target table belongs to
-- @index_is_unique - Whether or not the index will be unique
-- @fill_factor - This should match the fill factor setting for the target database
-- @pad_index - This should match the pad index setting for the target database
-- @row_count_override - This can be used to create the estimate with a simulated row count (must be greater than zero)
DECLARE @table_name SYSNAME = N'',
        @table_schema SYSNAME = N'dbo',
        @index_is_unique BIT = 0,
        @fill_factor TINYINT = 100,
        @pad_index BIT = 0,
        @row_count_override BIGINT = -1;

IF (SELECT OBJECT_ID('tempdb..#index_column')) IS NOT NULL
	DROP TABLE #index_column;

CREATE TABLE #index_column([name] SYSNAME NOT NULL, is_key_column BIT NOT NULL);

--NOTE: If creating a nonclustered index over a clustered index all clustering key columns are included whether or not the user specifies them.
--For this reason, all clustering key columns must be included in the list below (and marked as key columns) for the estimate to be accurate.
INSERT #index_column([name], is_key_column)
VALUES (N'', 1); --Add index columns

DECLARE @columns_specified INT, @columns_found INT;

SELECT @columns_specified = COUNT(*)
FROM #index_column
WHERE LEN([name]) > 0;

SELECT @columns_found = COUNT(*)
FROM sys.tables AS t
    JOIN sys.columns AS c ON c.[object_id] = t.[object_id]
    JOIN sys.schemas AS s ON s.[schema_id] = t.[schema_id]
    JOIN #index_column AS ic ON ic.[name] = c.[name]
WHERE t.[name] = @table_name
    AND s.[name] = @table_schema;

IF @columns_specified = 0
    THROW 50000, 'No index columns were specified.', 1;
ELSE IF @columns_specified <> @columns_found
BEGIN
    SELECT [name]
    FROM #index_column
    EXCEPT
    SELECT C.[name]
    FROM sys.tables AS t
        JOIN sys.columns AS c ON c.[object_id] = t.[object_id]
        JOIN sys.schemas AS s ON s.[schema_id] = t.[schema_id]
        JOIN #index_column AS ic ON ic.[name] = c.[name]
    WHERE t.[name] = @table_name
        AND s.[name] = @table_schema;

    THROW 50001, 'One or more specified columns were not found in the target table. Check the results for more detail.', 1;
END;

DECLARE @table_type TINYINT, @row_count BIGINT;

IF @row_count_override < 1
    SELECT @row_count = SUM(ps.row_count), @table_type = MAX(i.[type])
    FROM sys.tables AS t
        JOIN sys.schemas AS s ON s.[schema_id] = t.[schema_id]
        JOIN sys.indexes AS i ON i.[object_id] = t.[object_id]
        JOIN sys.dm_db_partition_stats AS ps ON ps.[object_id] = i.[object_id]
            AND ps.index_id = i.index_id
    WHERE t.[type] = 'U'
        AND t.is_ms_shipped = 0
        AND i.[type] IN (0, 1, 5)
        AND t.[name] = @table_name
        AND s.[name] = @table_schema
    GROUP BY t.[object_id], t.[schema_id];
ELSE
    SET @row_count = @row_count_override;

IF @row_count <= 0
    THROW 50002, 'No rows detected. If this script is being run on a system with no data, @row_count_override can be used to project a simulated row count.', 1;

--Index key (non-leaf level(s))
DECLARE @num_key_colummns INT, @fixed_key_size INT, @num_var_key_columns INT, @max_var_key_size INT, @key_null_bitmap INT, @key_contains_nullable_columns BIT;

SELECT @num_key_colummns = COUNT(*)
FROM #index_column
WHERE is_key_column = 1;

SELECT @fixed_key_size = COALESCE(SUM(c.max_length), 0)
FROM sys.tables AS t
    JOIN sys.columns AS c ON c.[object_id] = t.[object_id]
    JOIN sys.schemas AS s ON s.[schema_id] = t.[schema_id]
    JOIN #index_column AS ic ON ic.[name] = c.[name]
WHERE t.[name] = @table_name
    AND s.[name] = @table_schema
    AND ic.is_key_column = 1
    AND c.user_type_id NOT IN (34, 35, 98, 99, 165, 167, 231);

SELECT @max_var_key_size = COALESCE(SUM(c.max_length), 0), @num_var_key_columns = COUNT(*)
FROM sys.tables AS t
    JOIN sys.columns AS c ON c.[object_id] = t.[object_id]
    JOIN sys.schemas AS s ON s.[schema_id] = t.[schema_id]
    JOIN #index_column AS ic ON ic.[name] = c.[name]
WHERE t.[name] = @table_name
    AND s.[name] = @table_schema
    AND ic.is_key_column = 1
    AND c.user_type_id IN (34, 35, 98, 99, 165, 167, 231);

SELECT TOP 1 @key_contains_nullable_columns = COALESCE(c.is_nullable, 0)
FROM sys.tables AS t
    JOIN sys.columns AS c ON c.[object_id] = t.[object_id]
    JOIN sys.schemas AS s ON s.[schema_id] = t.[schema_id]
    JOIN #index_column AS ic ON ic.[name] = c.[name]
WHERE t.[name] = @table_name
    AND s.[name] = @table_schema
    AND ic.is_key_column = 1
ORDER BY c.is_nullable DESC;

IF @key_contains_nullable_columns = 1
    SET @key_null_bitmap = 2 + ((@num_key_colummns + 7) / 8);
ELSE
    SET @key_null_bitmap = 0;

--Index data (leaf level)
DECLARE @num_leaf_colummns INT, @fixed_leaf_size INT, @num_var_leaf_columns INT, @max_var_leaf_size INT, @leaf_null_bitmap INT, @leaf_contains_nullable_columns BIT;

SELECT @num_leaf_colummns = COUNT(*)
FROM #index_column;

SELECT @fixed_leaf_size = COALESCE(SUM(c.max_length), 0)
FROM sys.tables AS t
    JOIN sys.columns AS c ON c.[object_id] = t.[object_id]
    JOIN sys.schemas AS s ON s.[schema_id] = t.[schema_id]
    JOIN #index_column AS ic ON ic.[name] = c.[name]
WHERE t.[name] = @table_name
    AND s.[name] = @table_schema
    AND c.user_type_id NOT IN (34, 35, 98, 99, 165, 167, 231);

SELECT @max_var_leaf_size = COALESCE(SUM(c.max_length), 0), @num_var_leaf_columns = COUNT(*)
FROM sys.tables AS t
    JOIN sys.columns AS c ON c.[object_id] = t.[object_id]
    JOIN sys.schemas AS s ON s.[schema_id] = t.[schema_id]
    JOIN #index_column AS ic ON ic.[name] = c.[name]
WHERE t.[name] = @table_name
    AND s.[name] = @table_schema
    AND c.user_type_id IN (34, 35, 98, 99, 165, 167, 231);

IF @key_contains_nullable_columns = 0
    SELECT TOP 1 @leaf_contains_nullable_columns = COALESCE(c.is_nullable, 0)
    FROM sys.tables AS t
        JOIN sys.columns AS c ON c.[object_id] = t.[object_id]
        JOIN sys.schemas AS s ON s.[schema_id] = t.[schema_id]
        JOIN #index_column AS ic ON ic.[name] = c.[name]
    WHERE t.[name] = @table_name
        AND s.[name] = @table_schema
    ORDER BY c.is_nullable DESC;
ELSE
    SET @leaf_contains_nullable_columns = 1;

IF @leaf_contains_nullable_columns = 1
    SET @leaf_null_bitmap = 2 + ((@num_leaf_colummns + 7) / 8);
ELSE
    SET @leaf_null_bitmap = 0;

--Index rows-per-page estimates
DECLARE @var_key_size INT, @var_leaf_size INT, @non_leaf_rows_per_page INT, @leaf_rows_per_page INT, @free_rows_per_non_leaf_page INT, @free_rows_per_leaf_page INT;
DECLARE @non_leaf_row_size INT, @leaf_row_size INT;

IF @index_is_unique = 0 AND @table_type = 0
BEGIN
    SET @num_leaf_colummns = @num_leaf_colummns + 1;
    SET @num_var_leaf_columns = @num_var_leaf_columns + 1;
    SET @max_var_leaf_size = @max_var_leaf_size + 8;

    SET @num_key_colummns = @num_key_colummns + 1;
    SET @num_var_key_columns = @num_var_key_columns + 1;
    SET @max_var_key_size = @max_var_key_size + 8;
END;

--NOTE: Casts to NUMERIC are done to preserve fractional numbers (needed for accuracy)

SET @var_key_size = CASE WHEN @num_var_key_columns > 0 THEN 2 + (@num_var_key_columns * 2) + @max_var_key_size ELSE 0 END;
SET @non_leaf_row_size = @fixed_key_size + @var_key_size + @key_null_bitmap + 7;
SET @non_leaf_rows_per_page = 8096 / (@non_leaf_row_size + 2);
SET @free_rows_per_non_leaf_page = CASE WHEN @pad_index = 1 THEN 8096 * ((100 - CAST(@fill_factor AS NUMERIC)) / 100) / (@non_leaf_row_size + 2) ELSE 0 END;

SET @var_leaf_size = CASE WHEN @num_var_leaf_columns > 0 THEN 2 + (@num_leaf_colummns * 2) + @max_var_leaf_size ELSE 0 END;
SET @leaf_row_size = @fixed_leaf_size + @var_leaf_size + @leaf_null_bitmap + 7;
SET @leaf_rows_per_page = 8096 / (@leaf_row_size + 2);
SET @free_rows_per_leaf_page = 8096 * ((100 - CAST(@fill_factor AS NUMERIC)) / 100) / (@leaf_row_size + 2);

--Calculate index size estimate
DECLARE @non_leaf_space_used BIGINT, @leaf_space_used BIGINT, @num_non_leaf_pages BIGINT, @num_leaf_pages BIGINT, @non_leaf_levels INT;

SET @num_leaf_pages = CEILING(CAST(@row_count AS NUMERIC) / (@leaf_rows_per_page - @free_rows_per_leaf_page));
SET @leaf_space_used = 8192 * @num_leaf_pages;

SET @non_leaf_levels = CEILING(1 + LOG(@non_leaf_rows_per_page) / (@num_leaf_pages / @non_leaf_rows_per_page));

DECLARE @level_counter INT = 1;
WHILE @level_counter <= @non_leaf_levels
BEGIN
    SET @num_non_leaf_pages = COALESCE(@num_non_leaf_pages, 0) + CEILING((@num_leaf_pages / POWER(CAST(@non_leaf_rows_per_page AS NUMERIC), @level_counter)));
    SET @level_counter = @level_counter + 1;
END;

SET @non_leaf_space_used = 8192 * @num_non_leaf_pages;

DECLARE @estimate_in_bytes NUMERIC = @leaf_space_used + @non_leaf_space_used;
SELECT @estimate_in_bytes AS EstimatedIndexSpaceInBytes, estimate_in_bytes / 1024 AS EstimatedIndexSpaceInKB,
    estimate_in_bytes / POWER(1024, 2) AS EstimatedIndexSpaceInMB, estimate_in_bytes / POWER(1024, 3) AS EstimatedIndexSpaceInGB;

DROP TABLE #index_column;

SET NOCOUNT OFF;
