# AnimeOrganizer.FileParser.psm1 - Filename Parsing Functions Module
# Extracted from Anime-File-Organizer.ps1 for modular architecture

# Load configuration
$script:Config = $null

function Get-AnimeOrganizerConfig {
    if ($null -eq $script:Config) {
        $configPath = Join-Path $PSScriptRoot "..\..\Config\settings.json"
        if (Test-Path $configPath) {
            $script:Config = Get-Content $configPath | ConvertFrom-Json
        } else {
            # Fallback configuration
            $script:Config = @{
                parsing = @{
                    debug_mode = $true
                    patterns = @{
                        basic = @{
                            hash = "^#(\d+)\..*$"
                            sxxexx = "^[Ss](\d+)[Ee](\d+)"
                            episode_number = "^(\d{1,2})\s*-\s*(.+?)\..*$"
                            sub_episode = "^(\d{1,2})([a-z])\..*$"
                            simple_numbered = "^(\d{1,2})\..*$"
                        }
                        advanced = @(
                            "^#(\d+)\..*$",
                            "^(\d+)(?:\s*-\s*)(.+?)\..*$",
                            "^(\d+)\..*$",
                            "^[Ss](\d+)[Ee](\d+).*\..*$",
                            "^(.+?)\s+[Ss](\d+)[Ee](\d+).*\..*$",
                            "^(.+?)[Ss](\d+)[Ee](\d+).*\..*$",
                            "^(.+?)\s*-\s*(\d+).*\..*$",
                            "^(.+?)\s+(?:Episode|Ep|E)\s*(\d+).*\..*$",
                            "^(.+?)\s+(\d{1,3})(?:\s+.*)?\..*$",
                            "^(.+?)\s+(?:OVA|OAD|Special)\s*(\d+)?.*\..*$",
                            "^(.+?)\s*\[(\d+)\].*\..*$",
                            "^(.+?)\s*\((\d+)\).*\..*$"
                        )
                    }
                    series_name_cleaning = @{
                        remove_brackets = @(
                            "\[.*?\]",
                            "\(.*?\)",
                            "【.*?】",
                            "『.*?』",
                            "「.*?」"
                        )
                        replace_patterns = @{
                            "\.+" = " "
                            "_+" = " "
                            "\s+" = " "
                        }
                    }
                }
            }
        }
    }
    return $script:Config
}

# Debug function for compatibility
function Write-Debug-Info {
    param($Message, $Color = "Cyan")
    $config = Get-AnimeOrganizerConfig
    if ($config.parsing.debug_mode) {
        Write-Host "[DEBUG] $Message" -ForegroundColor $Color
    }
}

# Helper Functions

function Get-ParsingPatterns {
    $config = Get-AnimeOrganizerConfig
    return $config.parsing.patterns
}

function Test-BasicPatterns {
    param([string]$FileName)
    
    Write-Debug-Info "Testing basic patterns first..."
    $patterns = Get-ParsingPatterns
    
    # Test basic hash pattern
    if ($FileName -match $patterns.basic.hash) {
        Write-Debug-Info "BASIC HASH PATTERN MATCHED: Episode $($Matches[1])"
        return @{
            SeriesName = "Unknown Series"
            EpisodeNumber = [int]$Matches[1]
            SeasonNumber = 1
            DetectedPattern = "basic-hash"
        }
    }
    
    # Test basic SxxExx pattern
    if ($FileName -match $patterns.basic.sxxexx) {
        Write-Debug-Info "BASIC SXXEXX PATTERN MATCHED: Season $($Matches[1]), Episode $($Matches[2])"
        return @{
            SeriesName = "Unknown Series"
            EpisodeNumber = [int]$Matches[2]
            SeasonNumber = [int]$Matches[1]
            DetectedPattern = "basic-sxxexx"
        }
    }
    
    # Test basic episode number pattern (like "01 - Title.mkv")
    if ($FileName -match $patterns.basic.episode_number) {
        Write-Debug-Info "BASIC EPISODE NUMBER PATTERN MATCHED: Episode $($Matches[1])"
        return @{
            SeriesName = "Unknown Series"
            EpisodeNumber = [int]$Matches[1]
            SeasonNumber = 1
            DetectedPattern = "basic-episode-number"
        }
    }
    
    # Test sub-episode pattern (like "01a.mkv", "01b.mkv")
    if ($FileName -match $patterns.basic.sub_episode) {
        Write-Debug-Info "SUB-EPISODE PATTERN MATCHED: Episode $($Matches[1])$($Matches[2])"
        return @{
            SeriesName = "Unknown Series"
            EpisodeNumber = [int]$Matches[1]
            SeasonNumber = 1
            DetectedPattern = "sub-episode"
        }
    }
    
    # Test simple numbered files (like "07.mkv", "08.mkv")
    if ($FileName -match $patterns.basic.simple_numbered) {
        Write-Debug-Info "SIMPLE NUMBERED PATTERN MATCHED: Episode $($Matches[1])"
        return @{
            SeriesName = "Unknown Series"
            EpisodeNumber = [int]$Matches[1]
            SeasonNumber = 1
            DetectedPattern = "simple-numbered"
        }
    }
    
    return $null
}

function Test-AdvancedPatterns {
    param([string]$FileName)
    
    $patterns = Get-ParsingPatterns
    
    foreach ($pattern in $patterns.advanced) {
        Write-Debug-Info "Trying pattern: $pattern"
        if ($FileName -match $pattern) {
            Write-Debug-Info "Pattern matched! Matches count: $($Matches.Count)"
            
            $seriesName = ""
            $episodeNum = 1  # Default episode (never 0)
            $seasonNum = 1  # Default season
            
            # Handle different pattern types based on capture groups
            # Special handling for Specials/OVA without an explicit number
            if ($pattern -eq '^(.+?)\s+(?:OVA|OAD|Special)\s*(\d+)?\..*$' -and $Matches.Count -eq 2) {
                $seriesName = $Matches[1].Trim()
                $episodeNum = 1
                Write-Debug-Info "Special/OVA without number detected. Defaulting to Episode 1"
            }
            else {
                switch ($Matches.Count) {
                    2 {
                        # Single capture group - episode number only
                        $episodeNum = [int]$Matches[1]
                        $seriesName = "Unknown Series"  # Will use API series name
                        Write-Debug-Info "Single capture: Episode $episodeNum"
                    }
                    3 {
                        # Two capture groups - could be "Series - Episode" or "Episode - Title"
                        # Check if first group is numeric (episode number)
                        if ($Matches[1] -match '^\d+$') {
                            # Pattern: "10 - Title.mkv" (episode number + title)
                            $episodeNum = [int]$Matches[1]
                            $seriesName = "Unknown Series"  # Will use API series name
                            Write-Debug-Info "Episode+Title: Episode $episodeNum, Title: '$($Matches[2])'"
                        } else {
                            # Pattern: "Series - 10.mkv" (series + episode)
                            $seriesName = $Matches[1].Trim()
                            $episodeNum = [int]$Matches[2]
                            Write-Debug-Info "Series+Episode: '$seriesName', Episode $episodeNum"
                        }
                    }
                    4 {
                        # Three capture groups - series, season, episode (SxxExx format)
                        $seriesName = $Matches[1].Trim()
                        $seasonNum = [int]$Matches[2]
                        $episodeNum = [int]$Matches[3]
                        Write-Debug-Info "Series+Season+Episode: '$seriesName', Season $seasonNum, Episode $episodeNum"
                    }
                }
            }
            
            # Clean up series name
            $seriesName = Clean-SeriesName -SeriesName $seriesName
            
            # Handle edge cases
            if ([string]::IsNullOrEmpty($seriesName)) {
                $seriesName = "Unknown Series"
            }
            
            $result = @{
                SeriesName = $seriesName
                EpisodeNumber = $episodeNum
                SeasonNumber = $seasonNum
                DetectedPattern = $pattern
            }
            
            Write-Debug-Info "Parse result: Series='$seriesName', Season=$seasonNum, Episode=$episodeNum"
            return $result
        }
    }
    
    return $null
}

function Clean-SeriesName {
    param([string]$SeriesName)
    
    if ([string]::IsNullOrWhiteSpace($SeriesName)) {
        return $SeriesName
    }
    
    $config = Get-AnimeOrganizerConfig
    $cleaningRules = $config.parsing.series_name_cleaning
    
    # Remove brackets and tags
    foreach ($bracketPattern in $cleaningRules.remove_brackets) {
        $SeriesName = $SeriesName -replace $bracketPattern, ''
    }
    
    # Replace patterns
    foreach ($pattern in $cleaningRules.replace_patterns.PSObject.Properties) {
        $SeriesName = $SeriesName -replace $pattern.Name, $pattern.Value
    }
    
    return $SeriesName.Trim()
}

# Main Exported Functions

function Test-IsRomanizedJapaneseName {
    param([string]$Name)
    
    if ([string]::IsNullOrWhiteSpace($Name)) { 
        return $false 
    }
    
    # Indicators: macrons (āēīōū), common romanized particles, or typical romaji terms
    $hasMacrons = $Name -match '[āēīōū]'
    $hasParticles = $Name -match '(?i)\b(no|ni|wo|ga|to|de|wa|ka)\b'
    $hasRomajiTerms = $Name -match '(?i)(mahou|mahō|jutsushi|yarinaoshi|shoujo|shōjo|otome|seishun|monogatari|senpai|kouhai)'
    
    return ($hasMacrons -or $hasParticles -or $hasRomajiTerms)
}

function Get-SafeFileName {
    param([string]$FileName)
    
    # Replace spaces with dots FIRST
    $safeFileName = $FileName -replace '\s+', '.'
    
    # Remove commas (grammatically should be followed by dots, so just remove them)
    $safeFileName = $safeFileName -replace ',', ''
    
    # Windows invalid characters: < > : " / \ | ? *
    # Replace with safe alternatives
    $safeFileName = $safeFileName -replace ':', '-'        # Replace colons with dash
    $safeFileName = $safeFileName -replace '/', '-'    # Replace forward slashes with dash
    $safeFileName = $safeFileName -replace '\\', '-'   # Replace backslashes with dash
    $safeFileName = $safeFileName -replace '\|', '-'   # Replace pipes with dash
    $safeFileName = $safeFileName -replace '\?', ''    # Remove question marks
    $safeFileName = $safeFileName -replace '\*', ''    # Remove asterisks
    $safeFileName = $safeFileName -replace '<', ''     # Remove less than
    $safeFileName = $safeFileName -replace '>', ''     # Remove greater than
    $safeFileName = $safeFileName -replace '"', ''     # Remove double quotes
    
    # Clean up multiple dots and dashes
    $safeFileName = $safeFileName -replace '\.+', '.'       # Multiple dots -> single dot
    $safeFileName = $safeFileName -replace '-+', '-'       # Multiple dashes -> single dash
    $safeFileName = $safeFileName -replace '^\.|\.$', ''   # Remove leading/trailing dots
    $safeFileName = $safeFileName -replace '^-|-$', ''     # Remove leading/trailing dashes
    
    return $safeFileName.Trim()
}

function Parse-EpisodeNumber {
    param([string]$FileName)
    
    Write-Debug-Info "Parsing filename: $FileName"
    
    # Try basic patterns first (faster and more reliable)
    $basicResult = Test-BasicPatterns -FileName $FileName
    if ($basicResult) {
        return $basicResult
    }
    
    # Try advanced patterns if basic patterns failed
    $advancedResult = Test-AdvancedPatterns -FileName $FileName
    if ($advancedResult) {
        return $advancedResult
    }
    
    Write-Debug-Info "No pattern matched for: $FileName"
    return $null
}

# Export functions
Export-ModuleMember -Function Test-IsRomanizedJapaneseName, Get-SafeFileName, Parse-EpisodeNumber