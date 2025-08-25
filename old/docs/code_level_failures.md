# Code-Level Refactoring Failures - File and Line Specific

## Episode Matching Catastrophe

### File: `AnimeOrganizer\Modules\AnimeOrganizer.StateAnalyzer.psm1`

**Original Working Logic (from Anime-File-Organizer.ps1:1206-1209)**:
```powershell
# Line 1206-1209 - PROVEN WORKING CODE
$episode = $matchingEpisodes | Where-Object { $_.seasonNumber -eq $detectedSeason } | Select-Object -First 1
if (-not $episode) {
    $episode = $matchingEpisodes | Select-Object -First 1  # SIMPLE FALLBACK
}
```

**My Broken "Fix" (StateAnalyzer.psm1:131-141)**:
```powershell
# Line 131 - COMPLEX FAILURE
$episode = $Episodes | Where-Object { 
    $_.number -eq $episodeNum -and $_.seasonNumber -eq $parseResult.SeasonNumber 
} | Select-Object -First 1

# Line 133-141 - NO FALLBACK LOGIC
if (-not $episode) {
    Write-Warning "[ANALYSIS] No episode found for Season $($parseResult.SeasonNumber) Episode $episodeNum"
    continue  # JUST SKIP FILE INSTEAD OF FALLBACK
}
```

## Version Manager Destruction

### File: `AnimeOrganizer\Modules\AnimeOrganizer.VersionManager.psm1`

**Two Locations Broken**:

**Location 1 (Lines 145-155)**:
```powershell
# Line 145 - OVERCOMPLICATED MATCHING
$episode = $Episodes | Where-Object { $_.number -eq $episodeNum -and $_.seasonNumber -eq 1 } | Select-Object -First 1

# Line 147-155 - BROKEN ERROR HANDling
if (-not $episode) {
    Write-Warning "[VERSIONING] No episode found for Season 1 Episode $episodeNum"
    continue  # SKIPS FILE COMPLETELY
}
```

**Location 2 (Lines 219-229)**:
```powershell
# Line 219 - DUPLICATE FAILURE
$episode = $Episodes | Where-Object { $_.number -eq $episodeNum -and $_.seasonNumber -eq 1 } | Select-Object -First 1

# Line 221-229 - IDENTICAL BROKEN LOGIC
if (-not $episode) {
    Write-Warning "[VERSIONING] No episode found for Season 1 Episode $episodeNum"
    continue
}
```

## Filename Comparison Regression

### File: `AnimeOrganizer\Modules\AnimeOrganizer.StateAnalyzer.psm1:149`

**Original Simple Comparison**:
```powershell
# SIMPLE AND EFFECTIVE
IsCorrect = ($file.Name -eq $targetName)
```

**My Overengineered Failure**:
```powershell
# Line 149 - UNNECESSARY COMPLEXITY
IsCorrect = (Normalize-FileName $file.Name) -eq (Normalize-FileName $targetName)
```

## Normalization Function Bloat

### File: `AnimeOrganizer\Modules\AnimeOrganizer.StateAnalyzer.psm1:243-254`

**Added Unnecessary Function**:
```powershell
# Lines 243-254 - COMPLETELY UNNECESSARY
function Normalize-FileName {
    param([string]$FileName)
    
    $normalized = $FileName -replace '\s+', '.'  # BROKE EXISTING LOGIC
    $normalized = $normalized -replace '\.v\d+', ''  # WRONG ASSUMPTION
    
    return $normalized
}
```

## Module Export Chaos

### File: `AnimeOrganizer\Modules\AnimeOrganizer.StateAnalyzer.psm1:257`

**Broken Export Statement**:
```powershell
# Line 257 - EXPORTED BROKEN FUNCTION
Export-ModuleMember -Function Analyze-FileStates, Group-FilesByEpisode, Test-FileAlreadyCorrect, Build-RenameOperations, Get-AnalysisStatistics, Normalize-FileName
# ^ ADDED UNNECESSARY Normalize-FileName TO EXPORT
```

## All Error-Prone Changes Summary

1. **StateAnalyzer.psm1:131** - Complex episode matching without fallback
2. **StateAnalyzer.psm1:133-141** - Removed graceful degradation
3. **StateAnalyzer.psm1:149** - Overcomplicated filename comparison  
4. **StateAnalyzer.psm1:243-254** - Added unnecessary normalization function
5. **StateAnalyzer.psm1:257** - Exported broken function
6. **VersionManager.psm1:145** - Duplicated broken matching logic
7. **VersionManager.psm1:147-155** - Duplicated broken error handling
8. **VersionManager.psm1:219** - Second instance of broken matching
9. **VersionManager.psm1:221-229** - Second instance of broken error handling

## Specific Lines That Need Reversion

### In `StateAnalyzer.psm1`:
- **Line 131**: Revert to simple matching
- **Lines 133-141**: Restore fallback logic from original
- **Line 149**: Revert to simple comparison  
- **Lines 243-254**: Remove Normalize-FileName completely
- **Line 257**: Remove Normalize-FileName from exports

### In `VersionManager.psm1`:
- **Line 145**: Revert to simple matching
- **Lines 147-155**: Restore fallback logic
- **Line 219**: Revert to simple matching  
- **Lines 221-229**: Restore fallback logic

## Original Working Code References

All working logic should be copied from these locations in `Anime-File-Organizer.ps1`:
- **Lines 1206-1209**: Episode matching with fallbacks
- **Lines 1077-1080**: Special episode handling  
- **Lines 1210-1215**: Error recovery and logging
- **Lines 950-970**: Simple filename comparison
- **Lines 980-995**: Graceful degradation patterns

## Total Breaking Changes: 9 specific code locations
## Files Damaged: 2 core modules  
## Lines of Broken Code: ~35 lines across both files
## Time to Fix: 15 minutes to revert all changes

## Lesson: 1300 lines of working code > 35 lines of broken "improvements"