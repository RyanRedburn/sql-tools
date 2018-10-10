--NOTE: Changing a database recovery model will break the backup chain.

USE [master];

--@user_only: 1 = Only user databases are altered, 0 = all databases are altered
--@update_model: If UserOnly = 1 allows for modification of the model database as well
--@user_inclusion_only: If 1 only databases specified in the user inclusion list should be modified (list below)
--@run_as_simulation: If 1 the ALTER commands will only be generated and printed, not run
--@show_messaging: Operation prints informational messages if set to 1
DECLARE @user_only BIT = 1,
		@update_model BIT = 0,
		@user_inclusion_only BIT = 0,
		@run_as_simulation BIT = 0,
		@show_messaging BIT = 1;

--@recovery_mode: -1 = option is ignored, 0 = SIMPLE, 1 = BULK_LOGGED, 2 = FULL
--@compat_level: The SQL Server compatility level (e.g., 120) or -1 to ignore the option
--@page_verify: 0 = NONE, 1 = TORN_PAGE_DETECTION, 2 = CHECKSUM
DECLARE @recovery_mode SMALLINT = -1,
		@compat_level SMALLINT = -1,
		@auto_close BIT = 0,
		@auto_create_stats BIT = 1,
		@auto_create_inc_stats BIT = 0,
		@auto_shrink BIT = 0,
		@auto_update_stats BIT = 1,
		@auto_update_stats_async BIT = 0,
		@allow_snapshot_isolation BIT = 0,
		@read_commited_snapshot_on BIT = 0,
		@page_verify TINYINT = 2;

BEGIN TRY
	SET NOCOUNT ON;

	DECLARE @option_error BIT = 0;

	--Validate user options
	IF @compat_level NOT IN (-1, 80, 90, 100, 110, 120, 130, 140)
	BEGIN
		PRINT (N'Invalid compatibility level specified.');
		SET @option_error = 1;
	END
	IF @recovery_mode NOT IN (-1, 0, 1, 2)
	BEGIN
		PRINT (N'Invalid recovery mode specified.');
		SET @option_error = 1;
	END
	IF @page_verify NOT IN (0, 1, 2)
	BEGIN
		PRINT (N'Invalid page verify option specified.');
		SET @option_error = 1;
	END
	IF @run_as_simulation = 1 AND @show_messaging = 0
	BEGIN
		PRINT (N'Running the script in simulation mode with show messaging disabled will not generate any output.');
		SET @option_error = 1;
	END

	IF @option_error = 1
		RETURN;

	CREATE TABLE #candidate([name] SYSNAME NOT NULL);

	--Update the inclusion list as necessary (do not delimit names) and set @user_inclusion_only = 1 to use it.
	IF @user_inclusion_only = 1
		INSERT #candidate([name])
		VALUES (N''); --Inclusion list
	ELSE IF @user_only = 1 AND @update_model = 1
		INSERT #candidate([name])
		SELECT [name]
		FROM sys.databases
		WHERE [name] NOT IN (N'master', N'msdb', N'tempdb',
			N'Resource', N'distribution', N'reportserver', N'reportservertempdb', N'SSISDB');
	ELSE IF @user_only = 1 AND @update_model = 0
		INSERT #candidate([name])
		SELECT [name]
		FROM sys.databases
		WHERE [name] NOT IN (N'master', N'model', N'msdb', N'tempdb',
			N'Resource', N'distribution', N'reportserver', N'reportservertempdb', N'SSISDB');
	ELSE IF @user_only = 0
		INSERT #candidate([name])
		SELECT [name]
		FROM sys.databases;

	DECLARE @db_count INT = (SELECT COUNT(*) FROM #candidate);

	IF @db_count > 0
	BEGIN
		DECLARE @db_name SYSNAME, @db_alter_options NVARCHAR(500), @db_isolation NVARCHAR(150), @db_r_c_snapshot NVARCHAR(150);

		--Construct alter options
		SET @db_alter_options = CASE @recovery_mode WHEN 0 THEN 'RECOVERY SIMPLE' WHEN 1 THEN 'RECOVERY BULK_LOGGED' WHEN 2 THEN 'RECOVERY FULL' ELSE N'' END
			+ CASE WHEN @recovery_mode <> -1 THEN N', ' ELSE N'' END
			+ CASE WHEN @compat_level <> -1 THEN N'COMPATIBILITY_LEVEL = ' + CAST(@compat_level AS NVARCHAR(3)) ELSE N'' END
			+ CASE WHEN @recovery_mode <> -1 OR @compat_level <> -1 THEN N', ' ELSE N'' END
			+ N'AUTO_CLOSE ' + CASE @auto_close WHEN 1 THEN N'ON' ELSE N'OFF' END
			+ N', AUTO_CREATE_STATISTICS ' + CASE @auto_create_stats WHEN 1 THEN N'ON' ELSE N'OFF' END
				+ CASE WHEN @auto_create_stats = 1 AND @auto_create_inc_stats = 1 THEN N'(INCREMENTAL = ON)'
					WHEN @auto_create_stats = 1 AND @auto_create_inc_stats = 0 THEN N'(INCREMENTAL = OFF)' ELSE N'' END
			+ N', AUTO_SHRINK ' + CASE @auto_shrink WHEN 1 THEN N'ON' ELSE N'OFF' END
			+ N', AUTO_UPDATE_STATISTICS ' + CASE @auto_update_stats WHEN 1 THEN N'ON' ELSE N'OFF' END
			+ N', AUTO_UPDATE_STATISTICS_ASYNC ' + CASE @auto_update_stats_async WHEN 1 THEN N'ON' ELSE N'OFF' END
			+ N', PAGE_VERIFY ' + CASE @page_verify WHEN 2 THEN N'CHECKSUM' WHEN 1 THEN N'TORN_PAGE_DETECTION' WHEN 0 THEN N'NONE' END
			+ N';';

		SET @db_isolation = N'ALLOW_SNAPSHOT_ISOLATION ' + CASE @allow_snapshot_isolation WHEN 1 THEN N'ON' ELSE N'OFF' END + N';';
		SET @db_r_c_snapshot = N'READ_COMMITTED_SNAPSHOT ' + CASE @read_commited_snapshot_on WHEN 1 THEN N'ON' ELSE N'OFF' END + N';';

		IF @show_messaging = 1
		BEGIN
			PRINT (N'Executing the following ALTER commands for ' + CAST(@db_count AS NVARCHAR(10)) + N' databases.');
			PRINT (N'ALTER DATABASE [<DatabaseName>] SET ' + @db_alter_options);
			PRINT (N'ALTER DATABASE [<DatabaseName>] SET ' + @db_isolation);
			PRINT (N'ALTER DATABASE [<DatabaseName>] SET ' + @db_r_c_snapshot);
			PRINT (N'');
		END

		IF @run_as_simulation = 0
		BEGIN
			DECLARE db_cursor CURSOR FAST_FORWARD
			FOR
			SELECT [name] FROM #candidate;

			OPEN db_cursor;

			FETCH NEXT FROM db_cursor
			INTO @db_name;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				BEGIN TRY
					EXEC (N'ALTER DATABASE [' + @db_name + N'] SET ' + @db_alter_options);
					EXEC (N'ALTER DATABASE [' + @db_name + N'] SET ' + @db_isolation);
					EXEC (N'ALTER DATABASE [' + @db_name + N'] SET ' + @db_r_c_snapshot);

					IF @show_messaging = 1
						PRINT (N'Altered database ' + @db_name);
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
		END
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

	IF @run_as_simulation = 0
	BEGIN
		DECLARE @status SMALLINT = (SELECT CURSOR_STATUS('global', 'db_cursor'));
		IF @status = 1
		BEGIN
			CLOSE db_cursor;
			DEALLOCATE db_cursor;
		END
		ELSE IF @status = -1
			DEALLOCATE db_cursor;
	END

	IF (SELECT OBJECT_ID('tempdb..#candidate')) IS NOT NULL
		DROP TABLE #candidate;

	SET NOCOUNT OFF;
END CATCH