# Freezing Episode Renamer - Usage Guide

## Overview
This PowerShell script renames Freezing anime episodes using TheTVDB API to proper S01E01 format with episode titles.

## Requirements
- PowerShell 5.1 or later
- Internet connection
- TheTVDB API key (free for personal use under $50k/year)

## API Key Configuration

**Your API Key:** `2cb4e65a-f9a9-46e4-98f9-2d44f55342db`

### Getting a TheTVDB API Key (if needed)
1. Visit https://thetvdb.com/dashboard/account/apikey
2. Apply for a free API key for personal use
3. Note: For the free tier, each user needs a $12/year subscription PIN

## Usage

### Basic Usage (What-If mode to preview changes)
```powershell
.\Rename-FreezingEpisodes.ps1 -ApiKey "2cb4e65a-f9a9-46e4-98f9-2d44f55342db" -WhatIf
```

### With Subscriber PIN (if required)
```powershell
.\Rename-FreezingEpisodes.ps1 -ApiKey "2cb4e65a-f9a9-46e4-98f9-2d44f55342db" -Pin "your_pin_here" -WhatIf
```

### Actually Rename Files (remove -WhatIf)
```powershell
.\Rename-FreezingEpisodes.ps1 -ApiKey "2cb4e65a-f9a9-46e4-98f9-2d44f55342db"
```

### Custom Base Path
```powershell
.\Rename-FreezingEpisodes.ps1 -ApiKey "2cb4e65a-f9a9-46e4-98f9-2d44f55342db" -BasePath "C:\Your\Path\To\Freezing"
```

## Before and After Examples

### Season 1
**Before:** `[Anime Time] Freezing - 01.mkv`  
**After:** `Freezing - S01E01 - First Contact.mkv`

### Season 2 (Vibration)
**Before:** `[Anime Time] Freezing Vibration - 01.mkv`  
**After:** `Freezing - S02E01 - Pandora Mode.mkv`

### Specials/OVAs
**Before:** `[Anime Time] Freezing OVA - 01.mkv`  
**After:** `Freezing - S00E01 - Special Episode Title.mkv`

## Script Features

- **Free to use** - No licensing requirements
- **TheTVDB Attribution** - Complies with API terms
- **Safe renaming** - Removes invalid filename characters
- **What-If mode** - Preview changes before applying
- **Multiple seasons** - Handles both Freezing and Freezing Vibration
- **Specials support** - Renames OVAs as Season 0 episodes
- **Error handling** - Graceful handling of API failures

## File Structure Expected

```
Freezing/
├── Freezing S1/
│   ├── [Anime Time] Freezing - 01.mkv
│   ├── [Anime Time] Freezing - 02.mkv
│   └── ...
├── Freezing Vibration S2/
│   ├── [Anime Time] Freezing Vibration - 01.mkv
│   ├── [Anime Time] Freezing Vibration - 02.mkv
│   └── ...
└── Specials/
    ├── S1/
    │   ├── [Anime Time] Freezing OVA - 01.mkv
    │   └── ...
    └── S2/
        ├── [Anime Time] Freezing Vibration OVA - 01.mkv
        └── ...
```

## Attribution
Metadata provided by TheTVDB (https://thetvdb.com). Please consider contributing missing information or subscribing to support the service.

## Troubleshooting

1. **Authentication Failed**: Verify your API key and PIN
2. **No Episodes Found**: Check if the series exists on TheTVDB
3. **Permission Errors**: Run PowerShell as Administrator
4. **Rate Limiting**: The script includes basic error handling for API limits

## License
This script is completely free with no licensing requirements. Use and modify as needed.