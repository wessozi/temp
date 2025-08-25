# NamingConvention.psm1 - Super Simple Naming Convention
# MINIMAL module - only handles final filename assembly
# Easy to modify naming patterns in one place

<#
=============================================================================
🎯 FOR FUTURE LLM REFERENCE: HOW TO CHANGE NAMING CONVENTIONS
=============================================================================

TO CHANGE NAMING FORMAT:
1. This is the ONLY file you need to modify
2. Change the return statements in lines ~22 and ~40 (Get-EpisodeFileName and Get-SpecialFileName)
3. Both functions should use the SAME formatting logic for consistency

CURRENT FORMAT:
- Input:  "Series Name, Subtitle.S01E01.Episode Title.mkv"
- Output: "Series.Name.Subtitle.S01E01.Episode.Title.mkv"  
- Logic:  Remove ", " then replace spaces with dots

COMMON FORMAT EXAMPLES:
# Dots format (current):
return $assembled -replace ', ', '' -replace ' ', '.'
# Result: Series.Name.S01E01.Episode.Title.mkv

# Dash format:
return "$SeriesName - $episodeKey$VersionSuffix - $EpisodeTitle$FileExtension"  
# Result: Series Name - S01E01 - Episode Title.mkv

# Bracket format:
return "$SeriesName [$episodeKey$VersionSuffix] $EpisodeTitle$FileExtension"
# Result: Series Name [S01E01] Episode Title.mkv

# Plex format:
return "$SeriesName - s{0:D2}e{1:D2}$VersionSuffix - $EpisodeTitle$FileExtension" -f $SeasonNumber, $EpisodeNumber
# Result: Series Name - s01e02 - Episode Title.mkv

REMEMBER: Change BOTH Get-EpisodeFileName AND Get-SpecialFileName functions!
=============================================================================
#>

function Get-EpisodeFileName {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SeriesName,
        [Parameter(Mandatory=$true)]
        [int]$SeasonNumber,
        [Parameter(Mandatory=$true)]
        [int]$EpisodeNumber,
        [Parameter(Mandatory=$true)]
        [string]$EpisodeTitle,
        [Parameter(Mandatory=$true)]
        [string]$FileExtension,
        [string]$VersionSuffix = ""
    )
    
    $episodeKey = "S{0:D2}E{1:D2}" -f $SeasonNumber, $EpisodeNumber
    $assembled = "$SeriesName.$episodeKey$VersionSuffix.$EpisodeTitle$FileExtension"
    return $assembled -replace ', ', '' -replace ' ', '.'
}

function Get-SpecialFileName {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SeriesName,
        [Parameter(Mandatory=$true)]
        [int]$EpisodeNumber,
        [Parameter(Mandatory=$true)]
        [string]$EpisodeTitle,
        [Parameter(Mandatory=$true)]
        [string]$FileExtension,
        [string]$VersionSuffix = ""
    )
    
    $episodeKey = "S00E{0:D2}" -f $EpisodeNumber
    $assembled = "$SeriesName.$episodeKey$VersionSuffix.$EpisodeTitle$FileExtension"
    return $assembled -replace ', ', '' -replace ' ', '.'
}

# Alternative naming patterns (easy to switch)
function Get-AlternativeFileName {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SeriesName,
        [Parameter(Mandatory=$true)]
        [int]$SeasonNumber,
        [Parameter(Mandatory=$true)]
        [int]$EpisodeNumber,
        [Parameter(Mandatory=$true)]
        [string]$EpisodeTitle,
        [Parameter(Mandatory=$true)]
        [string]$FileExtension,
        [string]$VersionSuffix = ""
    )
    
    # Alternative format: Series Name - S01E01 - Episode Title.mkv
    return "$SeriesName - S{0:D2}E{1:D2}$VersionSuffix - $EpisodeTitle$FileExtension" -f $SeasonNumber, $EpisodeNumber
}

# Export functions
Export-ModuleMember -Function Get-EpisodeFileName, Get-SpecialFileName, Get-AlternativeFileName