# Universal Interactive Anime File Organizer - Usage Guide

## Overview
This PowerShell script organizes ANY anime series using TheTVDB API. It creates proper folder structures and renames files to standard format with episode titles.

## Features ✨
- **Universal** - Works with any anime series via TheTVDB ID
- **Interactive** - Prompts for input and shows preview before changes
- **Multi-format** - Supports .mkv, .mp4, .avi, .m4v, .wmv, .flv, .webm
- **Smart parsing** - Detects episode numbers from various filename patterns  
- **Auto-organization** - Creates Season folders and moves files appropriately
- **Free** - Uses TheTVDB's free API tier
- **Safe** - Preview mode and confirmation before making changes

## Requirements
- PowerShell 5.1 or later
- Internet connection
- TheTVDB series ID for your anime

## Quick Start

### 1. Find Your Series ID
Visit https://thetvdb.com and search for your anime series. The ID is in the URL:
- Example: `https://thetvdb.com/series/attack-on-titan` → ID would be in the series page URL

### 2. Run the Script
```powershell
# Navigate to folder containing your anime files
cd "C:\Your\Anime\Folder"

# Run the script (it will prompt for series ID)
.\Anime-File-Organizer.ps1
```

### 3. Follow Interactive Prompts
The script will ask you for:
- TheTVDB Series ID
- Confirmation of working directory
- Preview of all changes
- Final confirmation before execution

## Advanced Usage

### Non-Interactive Mode
```powershell
.\Anime-File-Organizer.ps1 -SeriesId 290434 -Interactive:$false -WorkingDirectory "C:\Anime\AttackOnTitan"
```

### With Custom API Key
```powershell  
.\Anime-File-Organizer.ps1 -ApiKey "your_api_key" -SeriesId 290434
```

### With Subscriber PIN
```powershell
.\Anime-File-Organizer.ps1 -Pin "your_pin" -SeriesId 290434
```

## File Organization Results

### Input Files (Examples)
```
[SubGroup] Attack on Titan - 01.mkv
[SubGroup] Attack on Titan - 02.mkv
[SubGroup] Attack on Titan S2 - 01.mkv
[SubGroup] Attack on Titan OVA - 01.mkv
```

### Output Structure
```
Attack on Titan/
├── Season 01/
│   ├── Attack on Titan - S01E01 - To You, in 2000 Years.mkv
│   ├── Attack on Titan - S01E02 - That Day.mkv
│   └── ...
├── Season 02/
│   ├── Attack on Titan - S02E01 - Beast Titan.mkv
│   └── ...
└── Specials/
    ├── Attack on Titan - S00E01 - Ilse's Notebook.mkv
    └── ...
```

## Supported Filename Patterns

The script recognizes these common anime filename formats:
- `[Group] Series Name - 01.ext`
- `Series Name Episode 01.ext`  
- `Series Name 01.ext`
- `Series.Name.S01E01.ext`
- `Series Name - S01E01.ext`

## Popular Series IDs

| Series | TheTVDB ID |
|--------|------------|
| Attack on Titan | 290434 |
| Demon Slayer | 355567 |
| My Hero Academia | 305074 |
| One Piece | 81797 |
| Naruto | 78857 |
| Dragon Ball Z | 81280 |
| Freezing | 248741 |
| Freezing Vibration | 276252 |

## Error Handling

### Common Issues:
1. **No video files found** - Ensure you're in the correct directory
2. **Authentication failed** - Check your API key or try without PIN
3. **Series not found** - Verify the TheTVDB Series ID is correct
4. **Episodes not matching** - Script will warn about unmatched files

### The Script Will:
- Skip files it can't parse
- Warn about missing episode data
- Create folders as needed
- Handle existing files gracefully

## Example Session
```
Universal Anime File Organizer
Using TheTVDB API (Free)

🎯 Enter the TheTVDB Series ID: 290434
📂 Working Directory: C:\Anime\AttackOnTitan
🔐 Authenticating with TheTVDB API...
✓ Authentication successful
📺 Fetching series information...
✓ Series: Shingeki no Kyojin
📋 Fetching all episodes and seasons...
✓ Found 87 episodes across all seasons
🔍 Scanning for video files...
✓ Found 25 video files
🔄 Analyzing files and matching with episode data...

PREVIEW OF CHANGES:
📁 Season 01
   📄 [SubGroup] Attack on Titan - 01.mkv
   ➡️  Attack on Titan - S01E01 - To You, in 2000 Years.mkv

⚠️  This will organize your files according to the preview above.
Do you want to proceed? (Y/N): Y

🚀 Executing file operations...
✓ Created folder: Season 01
✓ [SubGroup] Attack on Titan - 01.mkv → Season 01/Attack on Titan - S01E01 - To You, in 2000 Years.mkv

🎉 File organization completed!
```

## API Information
- **Your API Key**: `2cb4e65a-f9a9-46e4-98f9-2d44f55342db` (built into script)
- **Free Tier**: Available for personal use under $50k/year revenue
- **Attribution**: Required - automatically included in script output

## License
This script is completely free with no licensing requirements. Use and modify as needed.

## Attribution
Metadata provided by TheTVDB (https://thetvdb.com). Please consider contributing missing information or subscribing to support the service.