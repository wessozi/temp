# Anime File Organizer - Technical Handoff Documentation

## Project Overview
PowerShell script for organizing anime files using TheTVDB API with universal filename parsing and English-only output enforcement.

**Location**: `E:\Media\File organizer\Anime-File-Organizer.ps1`

## Recent Modifications Summary

### 1. Debug System Implementation
```powershell
# Global debug flag
$DebugMode = $true

# Debug function with color support
function Write-Debug-Info {
    param($Message, $Color = "Cyan")
    if ($DebugMode) {
        Write-Host "[DEBUG] $Message" -ForegroundColor $Color
    }
}
```

**Impact**: Comprehensive logging throughout script execution for troubleshooting and monitoring.

### 2. Universal Filename Parsing Engine

#### Enhanced Regex Patterns
```powershell
$patterns = @(
    '^#(\d+)\..*$',                                    # #02. Title.mkv
    '^[Ss](\d+)[Ee](\d+).*\..*$',                     # S01E01 Title.mkv
    '^(.+?)\s+[Ss](\d+)[Ee](\d+).*\..*$',             # Series S01E01 Title.mkv
    '^(.+?)\s*-\s*(\d+).*\..*$',                      # Series - 01.mkv
    '^(.+?)\s+(?:Episode|Ep|E)\s*(\d+).*\..*$',       # Series Episode 01.mkv
    '^(.+?)\s+(\d{1,3})(?:\s+.*)?\..*$',              # Series 01 Title.mkv
    '^(.+?)\s+(?:OVA|OAD|Special)\s*(\d+)?.*\..*$',   # Series OVA 1.mkv
    '^(.+?)\s*\[(\d+)\].*\..*$',                      # Series [01] Title.mkv
    '^(.+?)\s*\((\d+)\).*\..*$'                       # Series (01) Title.mkv
)
```

#### Pattern Matching Logic
- **Ordered by specificity** - most specific patterns first
- **Capture group handling** - dynamic based on match count
- **Fallback mechanisms** - graceful degradation when patterns fail
- **Series name cleanup** - removes tags, normalizes spacing

### 3. English-Only Title Enforcement

#### Multi-Method English Detection
```powershell
# ASCII validation regex
'^[\x20-\x7E]+$'  # Only printable ASCII characters
```

#### Series Name Resolution
1. **Primary**: English translations endpoint (`/translations/eng`)
2. **Secondary**: ASCII-only validation of original name
3. **Tertiary**: Series aliases/extended info search
4. **Fallback**: Original name with warning

#### Episode Title Resolution
```powershell
# Per-episode English translation
$episodeTranslation = Invoke-RestMethod -Uri "$BaseApiUrl/episodes/$($episode.id)/translations/eng"

# Fallback hierarchy:
# 1. English translation
# 2. ASCII-validated original
# 3. Generic "Episode X"
```

### 4. Enhanced User Experience

#### Exit Point Management
- **Replaced**: `Press any key to exit`
- **With**: R/Q option menus at all exit points
- **Benefit**: Consistent restart/quit behavior

#### Error Handling Improvements
```powershell
# Restart capability on errors
do {
    $choice = Read-Host "Choose (R/Q)"
    if ($choice -eq "R") { $shouldRestart = $true; break }
    elseif ($choice -eq "Q") { exit 1 }
} while ($true)
```

#### Operation Summary
```powershell
Write-Host "Folders created: $folderCreateCount" -ForegroundColor Cyan
Write-Host "Files moved successfully: $successCount" -ForegroundColor Green
Write-Host "Errors encountered: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Green" })
```

## Technical Architecture

### API Integration
- **TheTVDB API v4** integration
- **Bearer token authentication** with error handling
- **Paginated episode fetching** with automatic continuation
- **Rate limiting consideration** (implicit through sequential calls)

### Data Flow
1. **Authentication** → Token acquisition
2. **Series Resolution** → ID to metadata mapping
3. **Episode Enumeration** → Complete episode list with translations
4. **File Discovery** → Recursive video file scanning
5. **Pattern Matching** → Filename to episode mapping
6. **Preview Generation** → Operation planning
7. **User Confirmation** → Explicit approval
8. **Execution** → File operations with error handling

### Error Handling Strategy
- **Graceful degradation** at each API call
- **User choice preservation** on failures
- **Detailed error logging** with debug context
- **Restart capability** without data loss

## Known Issues & Considerations

### Performance
- **Sequential API calls** for episode translations (potential optimization target)
- **Memory usage** scales with episode count
- **Network dependency** for all operations

### Reliability
- **API availability** dependent
- **Translation coverage** varies by series
- **File system permissions** assumed

### Limitations
- **Single series processing** per execution
- **English language bias** in title resolution
- **No batch series processing**

## Future Enhancement Opportunities

1. **Parallel API calls** for episode translations
2. **Caching layer** for frequently accessed series
3. **Batch processing** multiple series
4. **Configuration file** for user preferences
5. **Undo functionality** for file operations
6. **Progress indicators** for long operations

## Testing Validation

### Test Cases Covered
- **Hash format**: `#02. 『Antidote (Candy)』.mkv` → Episode 2
- **Standard format**: `S01E01 Death Row Inmate.mkv` → Season 1, Episode 1
- **Lowercase format**: `s01e09.mkv` → Season 1, Episode 9
- **Mixed case**: `s01E12.mkv` → Season 1, Episode 12

### Output Validation
- **English-only filenames** confirmed
- **Proper season/episode formatting** (S01E01)
- **Safe filename characters** enforced
- **Folder structure creation** validated

## Dependencies
- **PowerShell 5.1+** (Windows PowerShell or PowerShell Core)
- **Internet connectivity** for TheTVDB API
- **TheTVDB API key** (currently embedded)
- **.NET Framework** regex engine compatibility