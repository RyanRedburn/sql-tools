USE [master];

--@user_only: 1 = Only user databases are examined, 0 = all databases are examined
--@user_inclusion_only: If 1 only databases specified in the user inclusion list are examined (list below)
--@include_info_messages: If 1 corruption check results will include informational messages
--@show_raw_results: If 1 the raw DBCC output is returned instead of the user friendly results
--@run_full_check: If 1 an extensive, expensive examination is done, else only a basic examination is done (PHYSICAL_ONLY)
--@show_messaging: Operation prints informational messages if set to 1
DECLARE @user_only BIT = 1,
		@user_inclusion_only BIT = 0,
		@include_info_messages BIT = 1,
		@show_raw_dbcc_results BIT = 0,
		@run_full_check BIT = 0,
		@show_messaging BIT = 1;

BEGIN TRY
	SET NOCOUNT ON;

	CREATE TABLE #candidate([name] SYSNAME NOT NULL);

	--Update the inclusion list as necessary (do not delimit names) and set @user_inclusion_only = 1 to use it
	IF @user_inclusion_only = 1
		INSERT #candidate([name])
		VALUES (N''); --Inclusion list
	ELSE IF @user_only = 1
		INSERT #candidate([name])
		SELECT [name]
		FROM sys.databases
		WHERE [name] NOT IN (N'master', N'model', N'msdb', N'tempdb',
			N'Resource', N'distribution', N'reportserver', N'reportservertempdb', N'SSISDB');
	ELSE
		INSERT #candidate([name])
		SELECT [name]
		FROM sys.databases;

	DECLARE @db_count INT = (SELECT COUNT(*) FROM #candidate);

	IF @show_messaging = 1
		PRINT (N'Executing a ' + CASE WHEN @run_full_check = 1 THEN N'full' ELSE N'simple' END
			+ N' corruption examination for ' + CAST(@db_count AS NVARCHAR(10)) + N' databases.');

	IF @db_count > 0
	BEGIN
		CREATE TABLE #check_result(error INT, [level] INT, [state] INT, message_text NVARCHAR(1000), repair_level NVARCHAR(1000),
			[status] INT, [db_id] INT, db_frag_id INT, [object_id] INT, index_id INT, [partition_id] BIGINT, alloc_unit_id BIGINT,
			rid_db_id INT, rid_pru_id INT, [file] INT, [page] INT, slot INT, ref_db_id INT, ref_pru_id INT, ref_file INT,
			ref_page INT, ref_slot INT, allocation INT);

		DECLARE @command_base NVARCHAR(100) = N'DBCC CHECKDB ([',
				@command_options_simple NVARCHAR(100) = N']) WITH TABLERESULTS, PHYSICAL_ONLY'
					+ CASE @include_info_messages WHEN 0 THEN N', NO_INFOMSGS;' ELSE N';' END,
				@command_options_full NVARCHAR(100) = N']) WITH TABLERESULTS, DATA_PURITY, EXTENDED_LOGICAL_CHECKS'
					+ CASE @include_info_messages WHEN 0 THEN N', NO_INFOMSGS;' ELSE N';' END,
				@db_name SYSNAME,
				@command NVARCHAR(250);

		IF @show_messaging = 1
			PRINT (N'Command: ' + @command_base + N'<DatabaseName>'
				+ CASE @run_full_check WHEN 1 THEN @command_options_full ELSE @command_options_simple END);

		DECLARE db_cursor CURSOR FORWARD_ONLY READ_ONLY STATIC LOCAL
		FOR
		SELECT [name] FROM #candidate;

		OPEN db_cursor;

		FETCH NEXT FROM db_cursor
		INTO @db_name;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			BEGIN TRY
				IF @run_full_check = 1
					SET @command = @command_base + @db_name + @command_options_full;
				ELSE
					SET @command = @command_base + @db_name + @command_options_simple;

				INSERT #check_result
				EXEC (@command);
			END TRY
			BEGIN CATCH
				PRINT (N'Msg ' + COALESCE(CAST(ERROR_NUMBER() AS NVARCHAR(10)), N'')
					+ N', Level ' + COALESCE(CAST(ERROR_SEVERITY() AS NVARCHAR(10)), N'')
					+ N', State ' +  COALESCE(CAST(ERROR_STATE() AS NVARCHAR(10)), N'')
					+ N', Line ' + COALESCE(CAST(ERROR_LINE() AS NVARCHAR(10)), N'')
					+ N', ' + COALESCE(ERROR_MESSAGE(), N''));
			END CATCH

			FETCH NEXT FROM db_cursor
			INTO @db_name;
		END

		CLOSE db_cursor;
		DEALLOCATE db_cursor;

		IF @show_raw_dbcc_results = 1
			SELECT * FROM #check_result;
		ELSE
			SELECT DB_NAME(db_id) AS database_name, OBJECT_NAME(object_id, db_id) AS object_name, message_text, error, level, state, status
			FROM #check_result;

		DROP TABLE #check_result;
	END

	DROP TABLE #candidate;

	SET NOCOUNT OFF;
END TRY
BEGIN CATCH
	PRINT (N'Msg ' + COALESCE(CAST(ERROR_NUMBER() AS NVARCHAR(10)), N'')
		+ N', Level ' + COALESCE(CAST(ERROR_SEVERITY() AS NVARCHAR(10)), N'')
		+ N', State ' +  COALESCE(CAST(ERROR_STATE() AS NVARCHAR(10)), N'')
		+ N', Line ' + COALESCE(CAST(ERROR_LINE() AS NVARCHAR(10)), N'')
		+ N', ' + COALESCE(ERROR_MESSAGE(), N''));

	DECLARE @status SMALLINT = (SELECT CURSOR_STATUS('global', 'db_cursor'));
	IF @status = 1
	BEGIN
		CLOSE db_cursor;
		DEALLOCATE db_cursor;
	END
	ELSE IF @status = -1
		DEALLOCATE db_cursor;

	IF (SELECT OBJECT_ID('tempdb..#candidate')) IS NOT NULL
		DROP TABLE #candidate;
	IF (SELECT OBJECT_ID('tempdb..#check_result')) IS NOT NULL
		DROP TABLE #candidate;

	SET NOCOUNT OFF;
END CATCH