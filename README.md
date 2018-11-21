# sql-tools

## Introduction
This project contains a variety of scripts and miscellaneous other items for use with SQL Server.

## Contents

### Adminstration
- ChangeDatabaseOptions.sql - Changes various options (recovery model, compatibility, etc.) of one or more databases.
- CorruptionCheck.sql - Check for database corruption on a user selected set of databases.
- IndexMaintenance.sql - Rebuilds/reorganizes database indexes based on user configured parameters.

### Analysis
- BackupHistory.sql - Gets the backup history for a given database.
- DatabaseAndFileState.sql - Get state information for all databases and database files on a given server.
- DefaultPaths.sql - Gets the default paths (e.g., data, log, etc.) for a database engine instance.
- FindWaits.sql - Gets waiting queries with detail info.
- GetPlanDetailsForProc.sql - Gets execution plan(s) and session options for said plans for a given procedure.
- IndexAnalyticsMulti.sql - Gets info (fragmentation, size, missing indexes, etc.) about a given database's indexes.
- IndexAnalyticsSingle.sql - Gets detailed info for a single index.
- MostExpensiveQueries.sql - Get the 10 most expenisve queries by reads, writes, and CPU time.
- StatsInfo.sql - Gets statistics info for a given database.
- TableSpaceUsed.sql - Gets the physical space used per user table.

### Misc
- QueryShortcuts.sql - Miscellaneous queries that are useful as query shortcuts.
- GenerateColumnLists.sql - Generates multiple column lists (for use in insert statements, logic can be repurposed for dynamic pivots, etc.) for a given table with different formats.

### Snippet
- CarefulBatch.snippet - Expansion snippet for designing high concurrency batch operations.
- RecursiveHierachy.snippet - Expansion snippit for querying adjancy list style hierarchy tables.
- SimpleCursor.snippet - Expansion snippet for a single variable, fast-forward cursor.
- SimpleTransaction.snippet - SurroundsWith snippet for simple transaction management boilerplate.
- SnippetTemplate.txt - T-SQL snippet template (includes a link to the schema definition).
