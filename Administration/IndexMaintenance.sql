--NOTE: This operation runs in the current database context

--@show_messaging: Operation prints informational messages if set to 1
DECLARE @show_messaging BIT = 1;

--@rebuild_bound: (0.00 to 100.00) The fragmentation value at or above which an index should be rebuilt
--@reorg_bound: (0.00 to 100.00) The fragmentation value at or above which an index should be reorganized
--@fill_factor: (0 to 100) The percent of an index leaf level which should be filled after a rebuild
--@pad_index: (ON, OFF) Whether or not the specified fill factor should also apply to the index intermediate level(s)
--@online: (ON, OFF) Whether or not index rebuilds should take place online (prevents blocking)
--@sample_mode: (DETAILED, SAMPLED, LIMITED, DEFAULT) The sample mode used for index fragmentation analysis
--@ignore_disabled: If 1 disabled indexes will be ignored
--@rebuild_all: If 1 all indexes will be rebuilt (this process respects the @ignore_disabled parameter)
DECLARE @rebuild_bound FLOAT = 30.00,
		@reorg_bound FLOAT = 10.00,
		@fill_factor TINYINT = 100,
		@pad_index NCHAR(3) = N'OFF',
		@online NCHAR(3) = N'OFF',
		@sample_mode NVARCHAR(8) = N'SAMPLED',
		@ignore_disabled BIT = 1,
		@rebuild_all BIT = 0;

BEGIN TRY
	SET NOCOUNT ON;

	DECLARE @option_error BIT = 0;

	--Validate user options
	IF @rebuild_bound NOT BETWEEN 0.00 AND 100.00
		OR @reorg_bound NOT BETWEEN 0.00 AND 100.00
	BEGIN
		PRINT (N'The rebuild and reorg bounds must be between 0.00 and 100.00.');
		SET @option_error = 1;
	END
	IF @rebuild_bound <= @reorg_bound
	BEGIN
		PRINT (N'The rebuild bound must be greater than the reorg bound.');
		SET @option_error = 1;
	END
	IF @fill_factor NOT BETWEEN 0 AND 100
	BEGIN
		PRINT (N'Fill factor must be between 0 and 100.');
		SET @option_error = 1;
	END
	IF @pad_index NOT IN (N'ON', N'OFF')
		OR @online NOT IN (N'ON', N'OFF')
	BEGIN
		PRINT (N'Pad index and online must be ON or OFF.');
		SET @option_error = 1;
	END
	IF @sample_mode NOT IN (N'DETAILED', N'SAMPLED', N'LIMITED', N'DEFAULT')
	BEGIN
		PRINT (N'Sample mode must be DETAILED, SAMPLED, LIMITED, or DEFAULT.');
		SET @option_error = 1;
	END

	IF @option_error = 1
		RETURN;

	DECLARE @index_name SYSNAME, @schema_name SYSNAME, @table_name SYSNAME, @operation TINYINT, @command NVARCHAR(300);

	--Get candidate index set
	DECLARE index_cursor CURSOR FAST_FORWARD
	FOR
	SELECT s.[name], t.[name], i.[name],
		CASE WHEN ips.avg_fragmentation_in_percent >= @rebuild_bound OR @rebuild_all = 1 THEN 2
		WHEN ips.avg_fragmentation_in_percent >= @reorg_bound AND ips.avg_fragmentation_in_percent < @rebuild_bound THEN 1
		ELSE 0 END
	FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, @sample_mode) AS ips
		JOIN sys.indexes AS i ON i.[object_id] = ips.[object_id]
			AND i.index_id = ips.index_id
		JOIN sys.tables AS t ON t.[object_id] = i.[object_id]
		JOIN sys.schemas AS s ON s.[schema_id] = t.[schema_id]
	WHERE t.type = 'U'
		AND ips.index_level = 0
		AND i.is_disabled = 0
		AND ((ips.page_count > 8 AND ips.avg_fragmentation_in_percent >= @reorg_bound)
			OR (@rebuild_all = 1 AND ips.page_count > 0))
	UNION ALL
	SELECT s.[name], t.[name], i.[name], 2
	FROM sys.indexes AS i
		JOIN sys.tables AS t ON t.[object_id] = i.[object_id]
		JOIN sys.schemas AS s ON s.[schema_id] = t.[schema_id]
	WHERE t.type = 'U'
		AND i.is_disabled = 1
		AND @ignore_disabled = 0;

	OPEN index_cursor;

	FETCH NEXT FROM index_cursor
	INTO @schema_name, @table_name, @index_name, @operation;

	DECLARE @result_count INT = 0;
	WHILE @@FETCH_STATUS = 0
	BEGIN
		BEGIN TRY
			--Perform appropriate alter index operation
			IF @operation <> 0
				SET @command = N'ALTER INDEX [' + @index_name + N'] ON [' + @schema_name + N'].[' + @table_name + N']';

			IF @operation = 2
			BEGIN
				IF @show_messaging = 1
					PRINT N'Rebuilding: ' + @index_name + N' on ' + @schema_name + N'.' + @table_name;

				SET @command = @command + N' REBUILD WITH (PAD_INDEX = ' + @pad_index + N', FILLFACTOR = ' + CAST(@fill_factor AS NVARCHAR(5))
					+ N', ONLINE = ' + @online + N');';

				EXEC (@command);
			END
			ELSE IF @operation = 1
			BEGIN
				IF @show_messaging = 1
					PRINT N'Reorganizing: ' + @index_name + N' on ' + @schema_name + N'.' + @table_name;

				SET @command = @command + N' REORGANIZE;';

				EXEC (@command);
			END

			SET @result_count = @result_count + 1;
		END TRY
		BEGIN CATCH
			PRINT (N'Msg ' + COALESCE(CAST(ERROR_NUMBER() AS NVARCHAR(10)), N'')
				+ N', Level ' + COALESCE(CAST(ERROR_SEVERITY() AS NVARCHAR(10)), N'')
				+ N', State ' +  COALESCE(CAST(ERROR_STATE() AS NVARCHAR(10)), N'')
				+ N', Line ' + COALESCE(CAST(ERROR_LINE() AS NVARCHAR(10)), N'')
				+ N', ' + COALESCE(ERROR_MESSAGE(), N''));
		END CATCH

		FETCH NEXT FROM index_cursor
		INTO @schema_name, @table_name, @index_name, @operation;
	END;

	PRINT (N'');
	PRINT (N'Number of indexes reorganized/rebuilt: ' + CAST(@result_count AS NVARCHAR(10)));

	CLOSE index_cursor;
	DEALLOCATE index_cursor;

	SET NOCOUNT OFF;
END TRY
BEGIN CATCH
	PRINT (N'Msg ' + COALESCE(CAST(ERROR_NUMBER() AS NVARCHAR(10)), N'')
		+ N', Level ' + COALESCE(CAST(ERROR_SEVERITY() AS NVARCHAR(10)), N'')
		+ N', State ' +  COALESCE(CAST(ERROR_STATE() AS NVARCHAR(10)), N'')
		+ N', Line ' + COALESCE(CAST(ERROR_LINE() AS NVARCHAR(10)), N'')
		+ N', ' + COALESCE(ERROR_MESSAGE(), N''));

	DECLARE @cursor_status SMALLINT = (SELECT CURSOR_STATUS(N'global', N'index_cursor'));
	IF @cursor_status = 1
	BEGIN
		CLOSE index_cursor;
		DEALLOCATE index_cursor;
	END
	ELSE IF @cursor_status = -1
		DEALLOCATE index_cursor;

	SET NOCOUNT OFF;
END CATCH