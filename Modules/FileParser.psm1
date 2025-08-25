# FileParser.psm1 - File Parsing and Analysis Functions  
# Extracted from Anime-File-Organizer.ps1 (lines 254-484)
# Complex filename parsing logic - no changes to preserve functionality

# Supported video file extensions
$VideoExtensions = @(".mkv", ".mp4", ".avi", ".m4v", ".wmv", ".flv", ".webm")

# Debug mode flag for compatibility
$DebugMode = $true

function Write-Debug-Info {
    param($Message, $Color = "Cyan")
    if ($DebugMode) {
        Write-Host "[DEBUG] $Message" -ForegroundColor $Color
    }
}

function Find-VideoFiles {
    param($Directory)
    
    Write-Host "[SCAN] Scanning for video files (including subdirectories)..." -ForegroundColor Yellow
    Write-Host "[INFO] Ignoring 'Extras' folders (contain random content like openings/endings)" -ForegroundColor Cyan
    
    $videoFiles = Get-ChildItem -LiteralPath $Directory -File -Recurse | Where-Object { 
        # Skip files in any folder called "Extras" (case-insensitive)
        $relativePath = $_.FullName.Replace($Directory, "").TrimStart("\")
        if ($relativePath -match "(?i)(?:^|\\)Extras(?:$|\\)") {
            Write-Debug-Info "Skipping file in Extras folder: $relativePath"
            return $false
        }
        
        # Only include video files
        return $VideoExtensions -contains $_.Extension.ToLower()
    } | Sort-Object FullName
    
    if ($videoFiles.Count -eq 0) {
        Write-Host "[ERROR] No video files found in directory or subdirectories" -ForegroundColor Red
        return @()
    }
    
    Write-Host "[SUCCESS] Found $($videoFiles.Count) video files" -ForegroundColor Green
    foreach ($file in $videoFiles) {
        $relativePath = $file.FullName.Replace("$Directory\", "")
        Write-Host "  - $relativePath" -ForegroundColor Gray
    }
    
    return $videoFiles
}

function Parse-EpisodeNumber {
    param($FileName)
    
    Write-Debug-Info "Parsing filename: $FileName"
    
    # Universal regex patterns for anime filename formats (ordered by specificity)
    # Note: PowerShell uses .NET regex, so we need to be careful with syntax
    $patterns = @(
        # 1. Hash/pound formats (most specific first)
        '^#(\d+)\..*$',                                                       # #02. Title.mkv
        
        # 2. Episode number only formats (at start of filename)
        '^(\d+)(?:\s*-\s*)(.+?)\..*$',                                        # 10 - Title.mkv
        '^(\d+)\..*$',                                                        # 07.mkv, 08.mkv (simple numbered files)
        
        # 3. Standard SxxExx formats
        '^[Ss](\d+)[Ee](\d+).*\..*$',                                         # S01E01 Title.mkv or s01e09.mkv
        '^(.+?)\s+[Ss](\d+)[Ee](\d+).*\..*$',                                 # Series S01E01 Title.mkv
        '^(.+?)[Ss](\d+)[Ee](\d+).*\..*$',                                    # Series.S01E01 Title.mkv (no spaces)
        
        # 4. Series - Episode formats (with dash separator)
        '^(.+?)\s*-\s*(\d+).*\..*$',                                          # Series - 01.mkv
        
        # 5. Episode/Ep keyword formats
        '^(.+?)\s+(?:Episode|Ep|E)\s*(\d+).*\..*$',                           # Series Episode 01.mkv
        
        # 6. Numbered episode formats (space separated)
        '^(.+?)\s+(\d{1,3})(?:\s+.*)?\..*$',                                  # Series 01 Title.mkv
        
        # 7. OVA/Special formats
        '^(.+?)\s+(?:OVA|OAD|Special)\s*(\d+)?.*\..*$',                       # Series OVA 1.mkv
        
        # 8. Bracketed episode numbers
        '^(.+?)\s*\[(\d+)\].*\..*$',                                          # Series [01] Title.mkv
        '^(.+?)\s*\((\d+)\).*\..*$'                                           # Series (01) Title.mkv
    )
    
    # Simple test patterns for the specific files we see
    Write-Debug-Info "Testing simple patterns first..."
    
    # Test basic hash pattern
    if ($FileName -match '^#(\d+)\.') {
        Write-Debug-Info "BASIC HASH PATTERN MATCHED: Episode $($Matches[1])"
        return @{
            SeriesName = "Unknown Series"
            EpisodeNumber = [int]$Matches[1]
            SeasonNumber = 1
            DetectedPattern = "basic-hash"
        }
    }
    
    # Test basic SxxExx pattern
    if ($FileName -match '^[Ss](\d+)[Ee](\d+)') {
        Write-Debug-Info "BASIC SXXEXX PATTERN MATCHED: Season $($Matches[1]), Episode $($Matches[2])"
        return @{
            SeriesName = "Unknown Series"
            EpisodeNumber = [int]$Matches[2]
            SeasonNumber = [int]$Matches[1]
            DetectedPattern = "basic-sxxexx"
        }
    }
    
    # Test basic episode number pattern (like "01 - Title.mkv")
    if ($FileName -match '^(\d{1,2})\s*-\s*(.+?)\.') {
        Write-Debug-Info "BASIC EPISODE NUMBER PATTERN MATCHED: Episode $($Matches[1])"
        return @{
            SeriesName = "Unknown Series"
            EpisodeNumber = [int]$Matches[1]
            SeasonNumber = 1
            DetectedPattern = "basic-episode-number"
        }
    }
    
    # Test sub-episode pattern (like "01a.mkv", "01b.mkv")
    if ($FileName -match '^(\d{1,2})([a-z])\..*$') {
        Write-Debug-Info "SUB-EPISODE PATTERN MATCHED: Episode $($Matches[1])$($Matches[2])"
        return @{
            SeriesName = "Unknown Series"
            EpisodeNumber = [int]$Matches[1]
            SeasonNumber = 1
            DetectedPattern = "sub-episode"
        }
    }
    
    # Test simple numbered files (like "07.mkv", "08.mkv")
    if ($FileName -match '^(\d{1,2})\..*$') {
        Write-Debug-Info "SIMPLE NUMBERED PATTERN MATCHED: Episode $($Matches[1])"
        return @{
            SeriesName = "Unknown Series"
            EpisodeNumber = [int]$Matches[1]
            SeasonNumber = 1
            DetectedPattern = "simple-numbered"
        }
    }
    
    foreach ($pattern in $patterns) {
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
            
            # Clean up series name (remove common artifacts)
            $seriesName = $seriesName -replace '\[.*?\]', ''                    # Remove [tags]
            $seriesName = $seriesName -replace '\(.*?\)', ''                    # Remove (tags)
            $seriesName = $seriesName -replace '【.*?】', ''                     # Remove 【tags】
            $seriesName = $seriesName -replace '『.*?』', ''                     # Remove 『tags』
            $seriesName = $seriesName -replace '「.*?」', ''                     # Remove 「tags」
            $seriesName = $seriesName -replace '\.+', ' '                       # Replace dots with spaces
            $seriesName = $seriesName -replace '_+', ' '                        # Replace underscores with spaces
            $seriesName = $seriesName -replace '\s+', ' '                       # Normalize spaces
            $seriesName = $seriesName.Trim()
            
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
    
    Write-Debug-Info "No pattern matched for: $FileName"
    return $null
}

function Get-SafeFileName {
    param($FileName)
    
    # Windows invalid characters: < > : " / \ | ? *
    # Replace with safe alternatives
    $safeFileName = $FileName -replace ':', '-'        # Replace colons with dash
    $safeFileName = $safeFileName -replace '/', '-'    # Replace forward slashes with dash
    $safeFileName = $safeFileName -replace '\\', '-'   # Replace backslashes with dash
    $safeFileName = $safeFileName -replace '\|', '-'   # Replace pipes with dash
    $safeFileName = $safeFileName -replace '\?', ''    # Remove question marks
    $safeFileName = $safeFileName -replace '\*', ''    # Remove asterisks
    $safeFileName = $safeFileName -replace '<', ''     # Remove less than
    $safeFileName = $safeFileName -replace '>', ''     # Remove greater than
    $safeFileName = $safeFileName -replace '"', ''     # Remove double quotes
    
    # Clean up multiple dashes and trim
    $safeFileName = $safeFileName -replace '\s*-\s*', '-'  # Normalize spacing around dashes
    $safeFileName = $safeFileName -replace '-+', '-'       # Replace multiple dashes with single dash
    $safeFileName = $safeFileName -replace '^-|-$', ''     # Remove leading/trailing dashes
    $safeFileName = $safeFileName.Trim()
    
    return $safeFileName
}

# Export functions
Export-ModuleMember -Function Find-VideoFiles, Parse-EpisodeNumber, Get-SafeFileName