# Known Bugs

## Restart Function Issue - Find-VideoFiles Not Recognized

### Description
When using the restart functionality ("R/Restart" option) within the script, the `Find-VideoFiles` function becomes unavailable and throws a "CommandNotFoundException", causing the script to fail at the file scanning stage.

### Symptoms
- Script restart function works for initial steps (authentication, series selection, directory selection)
- Other module functions continue to work normally (TheTVDB functions, UI functions)
- Specifically fails at line 204 in Organize-Anime.ps1: `$videoFiles = Find-VideoFiles -Directory $WorkingDirectory`
- Error: `Find-VideoFiles : The term 'Find-VideoFiles' is not recognized as the name of a cmdlet, function, script file, or operable program`

### Investigation Notes
- Issue is NOT a general module import problem (other module functions work fine after restart)
- Find-VideoFiles is defined in `Modules\FileParser.psm1` and properly exported
- Appears to be a scoping or context issue specific to this function
- The restart mechanism (`Reset-AllVariablesForRestart`) clears global variables but doesn't affect module imports
- PowerShell modules imported with `-Force` should remain in memory during restart

### Workaround
**Temporary Solution**: Close the script completely and restart it fresh instead of using the "R/Restart" option.

### Status
**Known Issue** - Needs investigation to determine root cause of why specifically `Find-VideoFiles` becomes unavailable during restart while other module functions remain accessible.

### Affected Files
- `Organize-Anime.ps1` (line 204)
- `Modules\FileParser.psm1` (Find-VideoFiles function)

### Date Identified
2025-08-26