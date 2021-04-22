--@database_name: The database name used in the event filter (i.e., this trace will only capture events for the named database).
--@session_name: The name of the extended events session. Note that if a session with this name already exists it will be replaced.
--@include_start_events: Whether or not start events should be recorded.
--@save_to_file: Whether or not the trace results should be saved to file.
--@file_path: The full file path for the trace file. The file should use the .xel extension (e.g., C:\Logs\DatabaseTrace.xel).
--@max_file_size: The maximum file size in MB.
--@max_rollover_files: The maximum number of rollover files that should be created. Set to 0 to disable rollover.
DECLARE @database_name SYSNAME = N'',
		@session_name SYSNAME = N'DatabaseTrace',
        @include_start_events BIT = 1,
		@save_to_file BIT = 0,
		@file_path NVARCHAR(250) = N'',
		@max_file_size INT = 1024,
		@max_rollover_files TINYINT = 0;

DECLARE @file_target NVARCHAR(MAX) =
    CASE WHEN @save_to_file = 1
    THEN N'ADD TARGET package0.event_file(SET filename=N''' + @file_path + N''',max_file_size=(' + CAST(@max_file_size AS NVARCHAR(10)) + N'),max_rollover_files=(' + CAST(@max_rollover_files AS NVARCHAR(10)) + N'))'
    ELSE N'' END;

DECLARE @database_id SMALLINT = DB_ID(@database_name);

DECLARE @start_events NVARCHAR(MAX) =
    CASE WHEN @include_start_events = 1
    THEN
        N'ADD EVENT sqlserver.rpc_starting(
            ACTION(sqlserver.database_id,sqlserver.database_name,sqlserver.plan_handle,sqlserver.username)
            WHERE ([sqlserver].[database_name]=N''' + @database_name + N''')),
        ADD EVENT sqlserver.sql_batch_starting(
            ACTION(sqlserver.database_id,sqlserver.database_name,sqlserver.plan_handle,sqlserver.username)
            WHERE ([sqlserver].[database_name]=N''' + @database_name + N''')),'
    ELSE N'' END;

DECLARE @sql NVARCHAR(MAX) = N'
IF EXISTS (SELECT [name] FROM sys.server_event_sessions WHERE [name] = N''' + @session_name + N''')
	DROP EVENT SESSION ' + @session_name + N' ON SERVER;

CREATE EVENT SESSION [' + @session_name + N'] ON SERVER '
+ @start_events
+ N'ADD EVENT sqlserver.lock_deadlock(
    ACTION(sqlserver.plan_handle,sqlserver.username)
    WHERE ([sqlserver].[database_id]=' + CAST(@database_id AS NVARCHAR) + N')),
ADD EVENT sqlserver.lock_deadlock_chain(
    ACTION(sqlserver.database_name,sqlserver.plan_handle,sqlserver.username)
    WHERE ([database_id]=' + CAST(@database_id AS NVARCHAR) + N')),
ADD EVENT sqlserver.rpc_completed(
    ACTION(sqlserver.database_id,sqlserver.database_name,sqlserver.plan_handle,sqlserver.username)
    WHERE ([sqlserver].[database_name]=N''' + @database_name + N''')),
ADD EVENT sqlserver.sql_batch_completed(
    ACTION(sqlserver.database_id,sqlserver.database_name,sqlserver.plan_handle,sqlserver.username)
    WHERE ([sqlserver].[database_name]=N''' + @database_name + N''')),
ADD EVENT sqlserver.database_xml_deadlock_report(
    ACTION(sqlserver.database_id,sqlserver.plan_handle,sqlserver.username)
    WHERE ([database_name]=N''' + @database_name + N'''))'
+ @file_target
+ N'WITH (MAX_MEMORY=8192 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=5 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=PER_CPU,TRACK_CAUSALITY=ON,STARTUP_STATE=OFF);
';

EXEC (@sql);
GO
