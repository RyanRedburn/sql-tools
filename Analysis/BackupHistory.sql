SET NOCOUNT ON;

SELECT s.database_name, s.backup_start_date, s.backup_finish_date, s.recovery_model, s.is_copy_only, s.is_damaged,
	m.physical_block_size, s.expiration_date, s.compatibility_level
FROM msdb.dbo.backupset AS s
	INNER JOIN msdb.dbo.backupmediafamily AS m ON s.media_set_id = m.media_set_id
ORDER BY s.database_name, s.backup_start_date DESC;