# File Naming Optimization Analysis

## Current Behavior Analysis

### File Naming Flow
1. **File Discovery**: `Find-VideoFiles` scans directory for video files
2. **Episode Parsing**: `Parse-EpisodeNumber` extracts episode numbers from filenames
3. **API Integration**: Retrieves series/episode info from TheTVDB API
4. **Name Generation**: Creates new filename format at `AnimeOrganizer.psm1:203`:
   ```powershell
   $newFileName = Get-SafeFileName -FileName "$($seriesInfo.name).S01E$($episodeNum.ToString('00')).$($episode.name)$($file.Extension)"
   ```
5. **Conflict Detection**: `Execute-FileOperations` checks for existing files before moving

### Current Inefficiency
The system always generates new filenames and performs file operations, even when:
- Files are already correctly named
- Only minor formatting differences exist (spaces vs dots)
- No actual renaming is needed

### Get-SafeFileName Function (Current)
Located at `AnimeOrganizer/Modules/AnimeOrganizer.FileParser.psm1:258`
- Only handles Windows invalid characters (`<>:"/\\|?*`)
- Replaces invalid chars with dashes or removes them
- **Does NOT handle spaces** - they remain in filenames

### Example Current Output
Input: `"Interspecies Reviewers.S01E01.Episode 1.mkv"`
Output: `"Interspecies Reviewers.S01E01.Episode 1.mkv"` (unchanged)

## Optimization Plan

### 1. Space Removal Implementation
**Target**: Replace ALL spaces with dots in final filenames

**Files to Modify**:
1. `Get-SafeFileName` function - Add space-to-dot replacement
2. `settings.json` naming templates - Update format expectations

**Expected Result**:
Input: `"Interspecies Reviewers.S01E01.Episode 1.mkv"`
Output: `"Interspecies.Reviewers.S01E01.Episode.1.mkv"`

### 2. "Already Correct" Detection Optimization
**Proposed Enhancement**:
Before creating file operations, compare generated name with existing filename:
- Normalize both names (convert spaces to dots, lowercase comparison)
- Skip operation if names are effectively identical
- Reduce unnecessary file system operations

**Implementation Location**: `AnimeOrganizer.psm1:198-214` (file processing loop)

### 3. Modified Get-SafeFileName Function
```powershell
function Get-SafeFileName {
    param([string]$FileName)
    
    # Replace spaces with dots FIRST
    $safeFileName = $FileName -replace '\s+', '.'
    
    # Then handle Windows invalid characters
    $safeFileName = $safeFileName -replace ':', '-'        
    $safeFileName = $safeFileName -replace '/', '-'    
    $safeFileName = $safeFileName -replace '\\', '-'   
    $safeFileName = $safeFileName -replace '\|', '-'   
    $safeFileName = $safeFileName -replace '\?', ''    
    $safeFileName = $safeFileName -replace '\*', ''    
    $safeFileName = $safeFileName -replace '<', ''     
    $safeFileName = $safeFileName -replace '>', ''     
    $safeFileName = $safeFileName -replace '"', ''     
    
    # Clean up multiple dots and dashes
    $safeFileName = $safeFileName -replace '\.+', '.'       # Multiple dots -> single dot
    $safeFileName = $safeFileName -replace '-+', '-'       # Multiple dashes -> single dash
    $safeFileName = $safeFileName -replace '^\.|\.$', ''   # Remove leading/trailing dots
    $safeFileName = $safeFileName -replace '^-|-$', ''     # Remove leading/trailing dashes
    
    return $safeFileName.Trim()
}
```

### 4. settings.json Updates
Update naming templates to reflect dot-separated format:
```json
{
  "naming": {
    "series_format": "{series}.S{season:D2}E{episode:D2}.{title}",
    "special_format": "{series}.S00E{episode:D2}.{title}",
    "include_tvdb_id": true
  }
}
```

## Benefits
1. **Consistent Naming**: All filenames use dots instead of spaces
2. **Better Compatibility**: Dots work better with various media systems
3. **Reduced Operations**: Skip unnecessary renames when files are already correct
4. **Improved Performance**: Less file system activity

## Testing Plan
1. Test with existing spaced filenames
2. Verify dot conversion works correctly
3. Ensure no invalid characters remain
4. Test conflict detection with normalized comparison
5. Verify backward compatibility with existing organized files