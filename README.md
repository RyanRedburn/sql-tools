# sql-tools

## Introduction
This project contains a variety of scripts and miscellaneous other items for use with SQL Server.

## Contents

### Adminstration
- ChangeDatabaseOptions.sql - Changes various options (recovery model, compatibility, etc.) of one or more databases.
- CorruptionCheck.sql - Check for database corruption on a user selected set of databases.
- ForEachDb.sql - Runs a given operation for the specified databases.
- IndexMaintenance.sql - Rebuilds/reorganizes database indexes based on user configured parameters.
- SqlServerAssessment.ps1 - Runs the Microsoft SQL Server General and Vulnerability assessments for all/select instances and databases (as applicable) on the current machine. Note that assessment results are Microsoft's recommendations and users should exercise discretion when determining action items.
    - The script will prompt the user for various options when run.
    - Scans will fail for offline instances. This does not impact overall script execution.
    - The default instance name will be blank. Console output and scan results without an instance prefix belong to the default instance.

### Analysis
- BackupHistory.sql - Gets the backup history for a given database.
- DatabaseAndFileState.sql - Get state information for all databases and database files on a given instance.
- DefaultPaths.sql - Gets the default paths (e.g., data, log, etc.) for a database engine instance.
- EstimateIndexSize.sql - Generates size estimates for nonclustered indexes.
- FindWaits.sql - Gets waiting queries with detail info.
- GetPlanDetailsForProc.sql - Gets execution plan(s) and session options for said plans for a given procedure.
- IndexAnalyticsMulti.sql - Gets info (fragmentation, size, missing indexes, etc.) about a given database's indexes.
- IndexAnalyticsSingle.sql - Gets detailed info for a single table.
- MostExpensiveQueries.sql - Get the 10 most expensive queries by reads, writes, and CPU time.
- StatsInfo.sql - Gets statistics info for a given database.
- TableSpaceUsed.sql - Gets the physical space used per user table.

### Documents
- DatabaseAdministration.md - A document outlining what I consider to be important topical areas to examine when performing database administration. This should not be considered a comprehensive guide to database administration.

### Misc
- DatabaseTrace.sql - Creates an extended events session with a filter on database name. Captures events useful for analyzing operational workloads (e.g., RCPs, SQL batches, locks, ect.).
- QueryShortcuts.sql - Miscellaneous queries that are useful as query shortcuts.
- GenerateColumnLists.sql - Generates multiple column lists (for use in insert statements, logic can be repurposed for dynamic pivots, etc.) for a given table with different formats.

### Snippet
- CarefulBatch.snippet - Expansion snippet for designing high concurrency batch operations.
- RecursiveHierachy.snippet - Expansion snippit for querying adjancy list style hierarchy tables.
- SimpleCursor.snippet - Expansion snippet for a single variable, fast-forward cursor.
- SimpleTransaction.snippet - SurroundsWith snippet for simple transaction management boilerplate.
- SingleUserMode.snippet - Expansion snippet for enabling/disabling single-user mode.
- SnippetTemplate.txt - T-SQL snippet template (includes a link to the schema definition).
