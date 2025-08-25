# Anime File Organizer

A comprehensive PowerShell solution for organizing anime files using TheTVDB API metadata. Available in both original monolithic and modern modular architectures.

## 📊 Project Overview

**Anime File Organizer** automatically renames and organizes anime video files using metadata from TheTVDB.com. It handles complex filename parsing, season/episode matching, version management, and provides both interactive and automated workflows.

### ✨ Key Features

- **🎯 Intelligent Parsing** - Recognizes 15+ filename patterns (SxxExx, hash format, numbered episodes, etc.)
- **🌐 Multi-language Support** - Prioritizes English titles with fallback to romanized Japanese
- **📁 Flexible Organization** - Rename-only or full reorganization with season folders
- **🔄 Version Management** - Handles duplicate episodes with versioning (v1, v2, etc.)
- **🎭 Special Content** - Automatic detection of OVAs, specials, and extras
- **🛡️ Safety First** - Preview mode, operation logging, and atomic file operations
- **🔧 Customizable** - Easy naming convention modifications
- **📖 Interactive & Automated** - Full CLI interaction or silent batch processing

### 🏗️ Architecture Comparison

| Feature | Original Script | Modular Version |
|---------|----------------|-----------------|
| **File Size** | 1,396 lines, single file | ~1,400 lines, 5 modules |
| **Maintainability** | Monolithic, all-in-one | Logical separation of concerns |
| **Naming Changes** | Edit inline string formatting | Modify single `NamingConvention.psm1` |
| **Testing** | Test entire script | Test individual modules |
| **Complexity** | Simple, everything visible | Modular, clean boundaries |
| **Performance** | Identical | Identical |
| **Use Case** | Quick use, simple deployment | Long-term maintenance, customization |

## 🚀 Quick Start

### Prerequisites
- Windows PowerShell 5.1+ or PowerShell Core 6+
- Internet connection for TheTVDB API
- Free TheTVDB.com account (optional for basic usage)

### Basic Usage

**Original Script (Monolithic):**
```powershell
# Interactive mode
.\Anime-File-Organizer.ps1

# Automated mode
.\Anime-File-Organizer.ps1 -SeriesId 452826 -WorkingDirectory "C:\Anime\Series" -Interactive:$false
```

**Modular Version:**
```powershell
# Interactive mode
.\Organize-Anime.ps1

# Automated mode (note: parameter syntax difference)
.\Organize-Anime.ps1 -SeriesId 452826 -WorkingDirectory "C:\Anime\Series" -Interactive $false
```

## 📦 Installation

### 1. Download Files
Clone or download the repository to your desired location.

### 2. Set Execution Policy (if needed)
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 3. Choose Your Version
- **Quick & Simple:** Use `Anime-File-Organizer.ps1` (original)
- **Customizable & Maintainable:** Use `Organize-Anime.ps1` (modular)

## 📖 Usage Guide

### Finding Series IDs

1. Visit [TheTVDB.com](https://thetvdb.com)
2. Search for your anime series
3. Copy the ID from the URL: `https://thetvdb.com/series/{ID}`

**Example Series IDs:**
- Attack on Titan: `290434`
- Demon Slayer: `355567`
- One Piece: `81797`
- Please Put Them On, Takamine-san: `452826`

### Interactive Mode

Run the script without parameters for guided workflow:

1. **Enter Series ID** - Input TheTVDB series ID
2. **Verify Series** - Confirm correct anime was found
3. **Choose Directory** - Select folder containing video files
4. **Select Operation** - Rename only or full reorganization
5. **Preview Changes** - Review planned operations
6. **Execute** - Apply changes with confirmation

### Command Line Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ApiKey` | String | Built-in | TheTVDB API key |
| `Pin` | String | Empty | TheTVDB subscription PIN |
| `WorkingDirectory` | String | Current | Target directory path |
| `SeriesId` | Integer | 0 | TheTVDB series ID |
| `Interactive` | Switch/Bool | $true | Enable interactive prompts |

### File Operations

**Rename Only Mode:**
- Renames files in current locations
- Preserves existing folder structure
- Updates filenames to standard format

**Reorganize Mode:**
- Creates season folders (Season 01, Season 02, etc.)
- Moves files to appropriate season directories  
- Creates Specials folder for OVAs/extras

### Supported Filename Patterns

The parser recognizes various anime filename formats:

```
#01.mkv                           → Hash format
01 - Episode Title.mkv            → Numbered with title
Series - 01.mkv                   → Series with episode
S01E01.mkv                        → Standard TV format
Series S01E01 Title.mkv           → Full format
Series [01] Title.mkv             → Bracketed format
Series Episode 01.mkv             → Keyword format
01a.mkv, 01b.mkv                  → Sub-episodes
```

## 🔧 Module Documentation (Modular Version)

### TheTVDB.psm1 (~220 lines)
**Purpose:** TheTVDB API integration
- `Get-TheTVDBToken` - API authentication
- `Get-SeriesInfo` - Series metadata retrieval
- `Get-SeriesEpisodes` - Episode information fetching
- `Test-IsRomanizedJapaneseName` - Language detection

### FileParser.psm1 (~250 lines)
**Purpose:** Filename analysis and parsing
- `Find-VideoFiles` - Video file discovery with filtering
- `Parse-EpisodeNumber` - Complex regex-based filename parsing
- `Get-SafeFileName` - Windows-safe filename creation

### UserInterface.psm1 (~200 lines)
**Purpose:** Interactive user experience
- `Write-Header` - Application banner display
- `Get-SeriesIdFromUser` - Series ID input with validation
- `Confirm-SeriesSelection` - Series verification prompts
- `Show-Preview` - Operation preview display
- `Confirm-Operations` - Final confirmation prompts

### FileOperations.psm1 (~150 lines)
**Purpose:** File system operations
- `Execute-FileOperations` - Atomic file move/rename operations
- `Write-OperationLog` - Transaction logging for safety
- `Rename-SeriesFolder` - Hama scanner compatibility

### NamingConvention.psm1 (~50 lines)
**Purpose:** Customizable naming patterns
- `Get-EpisodeFileName` - Standard episode naming
- `Get-SpecialFileName` - Special episode naming
- `Get-AlternativeFileName` - Alternative format support

## ⚙️ Customizing Naming Conventions

The modular version allows easy naming customization:

**Current Format:** `Series.S01E01.Episode Title.mkv`

**To Change Format:**

1. Edit `Modules/NamingConvention.psm1`
2. Modify the return statements in naming functions:

```powershell
# Example: Change to "Series - S01E01 - Title.mkv" format
return "$SeriesName - S{0:D2}E{1:D2}$VersionSuffix - $EpisodeTitle$FileExtension" -f $SeasonNumber, $EpisodeNumber
```

## 🔑 TheTVDB API Setup

### Free Usage (Default)
The scripts include a built-in API key for basic usage. No setup required.

### Enhanced Usage (Subscription)
For higher rate limits and additional features:

1. Create account at [TheTVDB.com](https://thetvdb.com)
2. Subscribe to supporter plan
3. Get your API key and PIN
4. Use with `-ApiKey` and `-Pin` parameters

## 🐛 Troubleshooting

### Common Issues

**"Cannot retrieve series information"**
- Verify Series ID exists on TheTVDB.com
- Check internet connection
- Try different Series ID

**"No video files found"**
- Ensure directory contains video files (.mkv, .mp4, .avi, etc.)
- Check file permissions
- Files in "Extras" folders are ignored

**"Execution policy" errors**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Module import warnings**
- Warnings about "unapproved verbs" are cosmetic only
- Functions work normally despite warnings

### Debug Mode

Both scripts include debug output for troubleshooting:
- Shows filename parsing decisions
- Displays API responses
- Logs operation details

## 📋 Example Operations

### Basic Rename Operation
```
Input Files:
├── 01 - Episode One.mkv
├── 02 - Episode Two.mkv
└── S01E03 - Episode Three.mkv

Output (Rename Only):
├── Series Name.S01E01.Episode One.mkv
├── Series Name.S01E02.Episode Two.mkv  
└── Series Name.S01E03.Episode Three.mkv
```

### Full Reorganization
```
Input Files:
├── Various filename formats...

Output (Reorganize):
├── Season 01/
│   ├── Series Name.S01E01.Episode Title.mkv
│   ├── Series Name.S01E02.Episode Title.mkv
│   └── Series Name.S01E03.Episode Title.mkv
└── Specials/
    └── Series Name.S00E01.OVA Title.mkv
```

### Version Handling
```
Input Files:
├── Episode 01.mkv
├── Episode 01 [Director's Cut].mkv

Output:
├── Series.S01E01.Episode Title.mkv
└── Series.S01E01.v2.Episode Title.mkv
```

## 📁 Project Structure

```
📁 Anime File Organizer/
├── 📄 README.md                      # This documentation
├── 📄 Anime-File-Organizer.ps1       # Original monolithic script (1,396 lines)
├── 📄 Organize-Anime.ps1             # Modular entry point (532 lines)
├── 📁 Modules/                       # Modular architecture components
│   ├── 📄 TheTVDB.psm1               # API operations (~220 lines)
│   ├── 📄 FileParser.psm1            # Filename parsing (~250 lines)
│   ├── 📄 UserInterface.psm1         # Interactive elements (~200 lines)
│   ├── 📄 FileOperations.psm1        # File system operations (~150 lines)
│   └── 📄 NamingConvention.psm1      # Naming patterns (~50 lines)
├── 📁 docs/                          # Development documentation
└── 📁 old/                           # Previous implementation attempts
```

## 🎯 Which Version Should You Use?

### Choose **Original Script** (`Anime-File-Organizer.ps1`) if:
- ✅ You want simple, single-file deployment
- ✅ You don't need to customize naming conventions  
- ✅ You prefer having everything in one place
- ✅ You're doing occasional, small-scale organization

### Choose **Modular Version** (`Organize-Anime.ps1`) if:
- ✅ You want easy naming convention customization
- ✅ You plan to extend or modify functionality
- ✅ You prefer organized, maintainable code
- ✅ You're doing regular, large-scale organization
- ✅ You want to understand or contribute to the codebase

## 🤝 Contributing

Contributions are welcome! Please:

1. Test changes with various filename formats
2. Ensure both original and modular versions work
3. Maintain backwards compatibility
4. Update documentation for new features

## 📝 License

This project is provided as-is for personal use. TheTVDB integration requires compliance with their terms of service.

---

**Attribution:** Metadata provided by [TheTVDB](https://thetvdb.com). Please consider contributing missing information or subscribing to support their service.