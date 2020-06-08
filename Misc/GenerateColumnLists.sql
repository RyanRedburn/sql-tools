SET NOCOUNT ON;

--NOTE: Any/all qualifier values must contain the entire qualifier (e.g., if you want the result u.<column_name>, the qualifier value should be N'u.').
DECLARE @schema_name SYSNAME = N'dbo',
		@object_name SYSNAME = N'',
		@column_qualifier NVARCHAR(25) = N'',
		@merge_target_qualifier NVARCHAR(25) = N'',
		@merge_source_qualifier NVARCHAR(25) = N'';

DECLARE @quoted_with_spaces NVARCHAR(MAX), @quoted_no_spaces NVARCHAR(MAX),
		@not_quoted_with_spaces NVARCHAR(MAX), @not_quoted_no_spaces NVARCHAR(MAX),
		@merge_update_quoted NVARCHAR(MAX), @merge_update_not_quoted NVARCHAR(MAX);

SELECT @quoted_with_spaces = COALESCE(@quoted_with_spaces + N', ', N'') + @column_qualifier + QUOTENAME(c.[name]),
	@quoted_no_spaces = COALESCE(@quoted_no_spaces + N',', N'') + @column_qualifier + QUOTENAME(c.[name]),
	@not_quoted_with_spaces = COALESCE(@not_quoted_with_spaces + N', ', N'') + @column_qualifier + c.[name],
	@not_quoted_no_spaces = COALESCE(@not_quoted_no_spaces + N',', N'') + @column_qualifier + c.[name],
	@merge_update_quoted = COALESCE(@merge_update_quoted + N', ', N'') + @merge_target_qualifier + QUOTENAME(c.[name]) + N' = ' + @merge_source_qualifier + QUOTENAME(c.[name]),
	@merge_update_not_quoted = COALESCE(@merge_update_not_quoted + N', ', N'') + @merge_target_qualifier + c.[name] + N' = ' + @merge_source_qualifier + c.[name]
FROM sys.columns AS c
	LEFT JOIN sys.tables AS t ON t.[object_id] = c.[object_id]
	LEFT JOIN sys.views AS v ON v.[object_id] = c.[object_id]
	JOIN sys.schemas AS s ON s.[schema_id] = t.[schema_id]
		OR s.[schema_id] = v.[schema_id]
WHERE s.[name] = @schema_name
	AND (t.[name] = @object_name OR v.[name] = @object_name)
ORDER BY c.column_id;

SELECT output_type, content
FROM (VALUES
	(N'Quoted/Spaces', @quoted_with_spaces),
	(N'Quoted/No Spaces', @quoted_no_spaces),
	(N'Not Quoted/Spaces', @not_quoted_with_spaces),
	(N'Not Quoted/No Spaces', @not_quoted_no_spaces),
	(N'Merge Update/Quoted', @merge_update_quoted),
	(N'Merge Update/Not Quoted', @merge_update_not_quoted)) AS t(output_type, content);

SET NOCOUNT OFF;
