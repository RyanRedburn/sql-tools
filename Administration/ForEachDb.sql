--NOTE: The operation to be performed per database should be added at line 46.

--@user_only: 1 = Only user databases are included, 0 = all databases are included
--@user_inclusion_only: If 1 only databases specified in the user inclusion list will be included (list below)
DECLARE @user_only BIT = 1,
		@user_inclusion_only BIT = 0;

BEGIN TRY
	SET NOCOUNT ON;

	CREATE TABLE #candidate([name] SYSNAME NOT NULL);

	--Update the inclusion list as necessary (do not delimit names) and set @user_inclusion_only = 1 to use it.
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

	IF @db_count > 0
	BEGIN
		DECLARE @db_name SYSNAME;

		DECLARE db_cursor CURSOR FORWARD_ONLY READ_ONLY STATIC LOCAL
		FOR
		SELECT [name]
		FROM #candidate;

		OPEN db_cursor;

		FETCH NEXT FROM db_cursor
		INTO @db_name;

		--NOTE: A temp table created outside of the scope of the WHILE loop can be used to aggregate results across executions, if desired.
		WHILE @@FETCH_STATUS = 0
		BEGIN
			EXEC (N'USE [' + @db_name + N']; '); --Operation

			FETCH NEXT FROM db_cursor
			INTO @db_name;
		END

		CLOSE db_cursor;
		DEALLOCATE db_cursor;
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

	DECLARE @status SMALLINT = (SELECT CURSOR_STATUS(N'local', N'db_cursor'));
	IF @status = 1
	BEGIN
		CLOSE db_cursor;
		DEALLOCATE db_cursor;
	END
	ELSE IF @status = -1
		DEALLOCATE db_cursor;

	IF (SELECT OBJECT_ID(N'tempdb..#candidate')) IS NOT NULL
		DROP TABLE #candidate;

	SET NOCOUNT OFF;
END CATCH
