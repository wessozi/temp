# NamingConvention.psm1 - Super Simple Naming Convention
# MINIMAL module - only handles final filename assembly
# Easy to modify naming patterns in one place

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
    return "$SeriesName.$episodeKey$VersionSuffix.$EpisodeTitle$FileExtension"
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
    return "$SeriesName.$episodeKey$VersionSuffix.$EpisodeTitle$FileExtension"
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