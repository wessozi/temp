# Anime Organizer Refactoring Analysis

## Current State Assessment

**Script Metrics:**
- **990 lines** - substantial single-file script
- **11 functions** - good modularization attempts
- **Multiple responsibilities** - API handling, file parsing, UI, file operations
- **Growing complexity** - TVDB integration, special episode handling, folder renaming

**Complexity Indicators:**
1. **Single file approaching 1000 lines**
2. **Mixed concerns** - API, UI, file operations, parsing all in one file
3. **Parameter passing** becoming cumbersome (functions taking 4+ parameters)
4. **Debugging complexity** - hard to isolate issues in different subsystems
5. **Future maintenance** - adding new features requires touching the monolithic script

## Architecture Options

### Option 1: Modular PowerShell Application ⭐ **RECOMMENDED**

**Structure:**
```
AnimeOrganizer/
├── AnimeOrganizer.psm1           # Main module
├── Config/
│   └── settings.json             # Configuration
├── Modules/
│   ├── TheTVDB.psm1             # API functions
│   ├── FileParser.psm1          # Filename parsing
│   ├── FileOperations.psm1      # File moving/renaming
│   └── UserInterface.psm1       # UI/prompts
├── Scripts/
│   └── Organize-Anime.ps1        # Main entry point
└── Tests/
    └── *.Tests.ps1              # Unit tests
```

**Benefits:**
- **Separation of concerns**
- **Easier testing** per module
- **Reusable components**
- **Configuration management**
- **Still PowerShell** - no new dependencies

**Module Breakdown:**

#### TheTVDB.psm1
- `Get-TheTVDBToken`
- `Get-SeriesInfo`
- `Get-SeriesEpisodes`
- API error handling
- Rate limiting logic

#### FileParser.psm1
- `Parse-EpisodeNumber`
- Regex patterns for filenames
- Season/episode detection
- Special episode identification

#### FileOperations.psm1
- `Find-VideoFiles`
- `Execute-FileOperations`
- File validation
- Safe file moving/renaming

#### UserInterface.psm1
- `Show-Preview`
- `Confirm-Operations`
- User prompts and menus
- Progress indicators

### Option 2: C# Console Application

**Structure:**
```
AnimeOrganizer/
├── Program.cs                    # Entry point
├── Services/
│   ├── TheTVDBService.cs        # API service
│   ├── FileParsingService.cs    # Parsing logic
│   └── FileOperationService.cs  # File operations
├── Models/
│   ├── Episode.cs               # Data models
│   └── Series.cs
├── Configuration/
│   └── AppSettings.cs           # Config management
└── AnimeOrganizer.csproj
```

**Benefits:**
- **Strongly typed**
- **Better IDE support**
- **NuGet packages** for HTTP, JSON, etc.
- **Easier deployment** (single exe)
- **Performance improvements**

**Drawbacks:**
- **New runtime dependency** (.NET)
- **Learning curve** for PowerShell users
- **Compilation step** required

### Option 3: Python Application

**Structure:**
```
anime_organizer/
├── __main__.py                   # Entry point
├── api/
│   └── tvdb_client.py           # API client
├── parsers/
│   └── filename_parser.py       # Parsing logic
├── operations/
│   └── file_manager.py          # File operations
├── ui/
│   └── console_ui.py            # User interface
├── config.yaml                  # Configuration
└── requirements.txt
```

**Benefits:**
- **Rich ecosystem** (requests, pathlib, etc.)
- **Cross-platform**
- **Easy configuration** with YAML
- **Package management** with pip

**Drawbacks:**
- **New runtime dependency** (Python)
- **Different language** from current PowerShell
- **Additional complexity** for Windows users

## Recommended Approach: Modular PowerShell

### Phase 1: Module Extraction

**Step 1: Create TheTVDB Module**
- Extract all API-related functions
- Add proper error handling
- Implement configuration for API keys

**Step 2: Create FileParser Module**
- Extract parsing logic and regex patterns
- Add comprehensive filename pattern support
- Include special episode detection

**Step 3: Create FileOperations Module**
- Extract file system operations
- Add safety checks and validation
- Implement atomic operations

**Step 4: Create UserInterface Module**
- Extract all UI functions
- Standardize user prompts
- Add consistent styling

### Phase 2: Configuration Management

**Settings Structure:**
```json
{
  "api": {
    "tvdb_key": "your-api-key",
    "timeout": 30,
    "retry_count": 3
  },
  "files": {
    "extensions": [".mkv", ".mp4", ".avi"],
    "backup_originals": false
  },
  "naming": {
    "series_format": "{series} - S{season:D2}E{episode:D2} - {title}",
    "special_format": "{series} - S00E{episode:D2} - {title}",
    "include_tvdb_id": true
  },
  "behavior": {
    "interactive": true,
    "debug_mode": false,
    "auto_rename_folders": true
  }
}
```

### Phase 3: Enhanced Features

1. **Logging System**
   - Replace debug prints with structured logging
   - Log levels (Debug, Info, Warning, Error)
   - File-based logging for troubleshooting

2. **Unit Testing**
   - Test each module independently
   - Mock API responses for testing
   - Validate parsing logic with known files

3. **Error Recovery**
   - Graceful handling of API failures
   - Rollback capabilities for failed operations
   - Better user guidance on errors

4. **Performance Improvements**
   - Parallel API calls where possible
   - Caching of series information
   - Optimized file scanning

## Migration Strategy

### Approach: Gradual Refactoring

1. **Keep current script functional** during transition
2. **Extract one module at a time** starting with TheTVDB
3. **Test each module independently**
4. **Create new main script** that uses modules
5. **Parallel testing** with existing script
6. **Final cutover** when confidence is high

### Timeline Estimate

- **Week 1**: TheTVDB module extraction and testing
- **Week 2**: FileParser module extraction and testing  
- **Week 3**: FileOperations module extraction and testing
- **Week 4**: UserInterface module and integration testing
- **Week 5**: Configuration system and final testing

## Benefits of Modular Approach

### Maintainability
- **Single responsibility** per module
- **Easier debugging** - isolate issues to specific modules
- **Independent updates** - update API module without touching file operations

### Testability
- **Unit testing** each module in isolation
- **Mock dependencies** for reliable testing
- **Regression testing** to prevent breaking changes

### Extensibility
- **New APIs** can be added as separate modules
- **Different naming conventions** without core changes
- **Plugin architecture** possible for future features

### Reusability
- **Modules can be used** in other projects
- **Shared parsing logic** across different organizers
- **Common API patterns** for media databases

## Conclusion

The current script has grown to a point where modularization would significantly improve maintainability, testability, and extensibility. The modular PowerShell approach provides the best balance of:

- **Familiar technology** (PowerShell)
- **No new dependencies**
- **Gradual migration path**
- **Significant architectural improvements**

This refactoring should be prioritized before adding major new features to prevent further complexity growth.