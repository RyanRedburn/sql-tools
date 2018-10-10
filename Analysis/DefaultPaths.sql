SET NOCOUNT ON;

DECLARE @default_data NVARCHAR(512);
EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData', @default_data OUTPUT;

DECLARE @default_log NVARCHAR(512);
EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultLog', @default_log OUTPUT;

DECLARE @default_backup NVARCHAR(512);
EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', @default_backup OUTPUT;

DECLARE @master_data NVARCHAR(512);
EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer\Parameters', N'SqlArg0', @master_data OUTPUT;
SELECT @master_data = SUBSTRING(@master_data, 3, 255);
SELECT @master_data = SUBSTRING(@master_data, 1, LEN(@master_data) - CHARINDEX('\', REVERSE(@master_data)));

DECLARE @master_log NVARCHAR(512);
EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer\Parameters', N'SqlArg2', @master_log OUTPUT;
SELECT @master_log = SUBSTRING(@master_log, 3, 255);
SELECT @master_log = SUBSTRING(@master_log, 1, LEN(@master_log) - CHARINDEX('\', REVERSE(@master_log)));

SELECT COALESCE(@default_data, @master_data) AS default_data, COALESCE(@default_log, @master_log) AS default_log, COALESCE(@default_backup, @master_log) AS default_backup;