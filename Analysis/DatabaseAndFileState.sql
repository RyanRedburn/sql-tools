--NOTE: Remove the "is_query_store_on" column from the first query if running on a version of SQL prior to 2016.

SET NOCOUNT ON;

--Database state information
WITH database_size(database_id, size_in_mb_excluding_fs)
AS
(
	SELECT DISTINCT database_id, (SUM(size) OVER(PARTITION BY database_id) * 8) / 1024
	FROM sys.master_files
)
SELECT d.database_id, d.[name] AS [database_name], create_date, [compatibility_level], l.[name] AS [owner], ds.size_in_mb_excluding_fs,
	collation_name, user_access_desc, d.is_read_only, is_auto_close_on, is_auto_shrink_on, d.state_desc,
	snapshot_isolation_state_desc, is_read_committed_snapshot_on, recovery_model_desc, page_verify_option_desc,
	is_auto_create_stats_on, is_auto_update_stats_on, is_query_store_on, is_subscribed, is_published
FROM sys.databases AS d
	LEFT JOIN sys.syslogins AS l ON l.[sid] = d.owner_sid
	LEFT JOIN database_size AS ds ON ds.database_id = d.database_id
ORDER BY d.[name];

--TDE state information
SELECT d.[name] AS [database_name], ek.encryption_state, ek.create_date, ek.regenerate_date,
	ek.modify_date, ek.set_date, ek.opened_date, ek.key_algorithm, ek.key_length
FROM sys.databases AS d
	join sys.dm_database_encryption_keys AS ek ON ek.database_id = d.database_id;

--Database file state information
SELECT d.[name] AS [database_name], mf.[name] AS [file_name], [type_desc], physical_name, mf.state_desc,
	(CAST(size AS BIGINT) * 8) / 1024 AS size_in_mb,
	CASE WHEN max_size <> -1 THEN (CAST(max_size AS BIGINT) * 8) / 1024 ELSE NULL END AS max_size_in_mb,
	CASE WHEN is_percent_growth = 0 THEN (CAST(growth AS BIGINT) * 8) / 1024 ELSE NULL END AS growth_in_mb,
	CASE WHEN is_percent_growth = 1 THEN growth ELSE NULL END AS growth_in_percent,
	mf.is_read_only, is_sparse
FROM sys.master_files AS mf
	JOIN sys.databases AS d ON d.database_id = mf.database_id
ORDER BY d.[name], mf.[file_id];