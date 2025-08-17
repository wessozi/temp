# Universal Interactive Anime File Organizer using TheTVDB API
# Completely free PowerShell script for organizing anime files
# No licensing requirements - uses free TheTVDB API access

param(
    [Parameter(Mandatory=$false)]
    [string]$ApiKey = "2cb4e65a-f9a9-46e4-98f9-2d44f55342db",
    
    [Parameter(Mandatory=$false)]
    [string]$Pin = "",
    
    [Parameter(Mandatory=$false)]
    [string]$WorkingDirectory = (Get-Location).Path,
    
    [Parameter(Mandatory=$false)]
    [int]$SeriesId = 0,
    
    [Parameter(Mandatory=$false)]
    [switch]$Interactive = $true
)

# TheTVDB API Configuration
$BaseApiUrl = "https://api4.thetvdb.com/v4"
$Headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}

# Supported video file extensions
$VideoExtensions = @(".mkv", ".mp4", ".avi", ".m4v", ".wmv", ".flv", ".webm")

# Debug mode flag
$DebugMode = $true

function Write-Debug-Info {
    param($Message, $Color = "Cyan")
    if ($DebugMode) {
        Write-Host "[DEBUG] $Message" -ForegroundColor $Color
    }
}

# Heuristic check: returns $true if a name looks like romanized Japanese rather than a localized English title
function Test-IsRomanizedJapaneseName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    # Indicators: macrons (āēīōū), common romanized particles, or typical romaji terms
    $hasMacrons = $Name -match '[āēīōū]'
    $hasParticles = $Name -match '(?i)\b(no|ni|wo|ga|to|de|wa|ka)\b'
    $hasRomajiTerms = $Name -match '(?i)(mahou|mahō|jutsushi|yarinaoshi|shoujo|shōjo|otome|seishun|monogatari|senpai|kouhai)'
    return ($hasMacrons -or $hasParticles -or $hasRomajiTerms)
}

function Write-Header {
    Clear-Host
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "                   Universal Anime File Organizer                      " -ForegroundColor Cyan
    Write-Host "                       Using TheTVDB API (Free)                        " -ForegroundColor Cyan
    Write-Host "                              DEBUG MODE: ON                           " -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Metadata provided by TheTVDB (https://thetvdb.com)" -ForegroundColor Gray
    Write-Host "Please consider contributing missing information or subscribing." -ForegroundColor Gray
    Write-Host ""
}

function Get-TheTVDBToken {
    param($ApiKey, $Pin)
    
    Write-Debug-Info "Starting authentication process"
    Write-Debug-Info "API Key: $($ApiKey.Substring(0,8))..." "Gray"
    
    $loginBody = @{
        apikey = $ApiKey
    }
    
    if ($Pin) {
        $loginBody.pin = $Pin
        Write-Debug-Info "Using PIN for authentication" "Gray"
    }
    
    try {
        Write-Host "[AUTH] Authenticating with TheTVDB API..." -ForegroundColor Yellow
        Write-Debug-Info "Sending request to: $BaseApiUrl/login"
        $response = Invoke-RestMethod -Uri "$BaseApiUrl/login" -Method POST -Body ($loginBody | ConvertTo-Json) -Headers $Headers
        Write-Host "[SUCCESS] Authentication successful" -ForegroundColor Green
        Write-Debug-Info "Token received successfully" "Green"
        return $response.data.token
    }
    catch {
        Write-Error "[ERROR] Authentication failed: $($_.Exception.Message)"
        Write-Debug-Info "Authentication error details: $($_.Exception)" "Red"
        Write-Host "Please check your API key and PIN, or try without PIN for basic access." -ForegroundColor Red
        return $null
    }
}

function Get-SeriesInfo {
    param($Token, $SeriesId)
    
    $authHeaders = $Headers.Clone()
    $authHeaders["Authorization"] = "Bearer $Token"
    
    try {
        Write-Host "[API] Fetching series information..." -ForegroundColor Yellow
        Write-Debug-Info "Fetching series data for ID: $SeriesId"
        $response = Invoke-RestMethod -Uri "$BaseApiUrl/series/$SeriesId" -Method GET -Headers $authHeaders
        $seriesData = $response.data
        
        Write-Debug-Info "Original series name: $($seriesData.name)"
        
        # FORCE English translations - try multiple approaches
        $englishName = $null
        
        # Method 1: Try English translations endpoint
        try {
            Write-Debug-Info "Trying English translations endpoint..."
            $translationResponse = Invoke-RestMethod -Uri "$BaseApiUrl/series/$SeriesId/translations/eng" -Method GET -Headers $authHeaders
            Write-Debug-Info "Translation response: $($translationResponse | ConvertTo-Json -Depth 3)"
            if ($translationResponse.data -and $translationResponse.data.name) {
                $englishName = $translationResponse.data.name
                Write-Debug-Info "Found English translation: $englishName"
            } else {
                Write-Debug-Info "No translation data or name found in response"
            }
        }
        catch {
            Write-Debug-Info "English translations endpoint failed: $($_.Exception.Message)"
        }
        
        # Method 2: Removed - ASCII check is misleading (romanized Japanese ≠ English)
        
        # Method 3: Try to get alternate names/aliases  
        try {
            Write-Debug-Info "Trying series extended info for aliases..."
            $extendedResponse = Invoke-RestMethod -Uri "$BaseApiUrl/series/$SeriesId/extended" -Method GET -Headers $authHeaders
            if ($extendedResponse.data.aliases) {
                Write-Debug-Info "Found $($extendedResponse.data.aliases.Count) aliases to check"
                foreach ($alias in $extendedResponse.data.aliases) {
                    Write-Debug-Info "Checking alias: '$($alias.name)' (Language: $($alias.language))"
                    # Only accept aliases that are clearly English translations, not romanized Japanese
                    if ($alias.language -eq "eng" -and 
                        $alias.name -match '^[\x20-\x7E]+$' -and
                        $alias.name -notmatch '(?i)(kaifuku|jutsushi|yarinaoshi|sokushi|mahō|mahou|skill|copy|choetsu|heal|kaiyari)' -and
                        $alias.name -match '\b(of|the|and|in|on|at|for|with|by|from|up|about|into|over|after)\b') {
                        $englishName = $alias.name
                        Write-Debug-Info "Found English alias: $englishName"
                        break
                    } else {
                        Write-Debug-Info "Rejected alias '$($alias.name)' - reason: language=$($alias.language), contains_japanese=$($alias.name -match '(?i)(kaifuku|jutsushi|yarinaoshi|sokushi|mahō|mahou|skill|copy|choetsu|heal|kaiyari)')"
                    }
                }
            } else {
                Write-Debug-Info "No aliases found in extended data"
            }
        }
        catch {
            Write-Debug-Info "Extended series info failed: $($_.Exception.Message)"
        }
        
        # Use English name if found, otherwise use original with warning
        if ($englishName) {
            $seriesData.name = $englishName
            Write-Host "[SUCCESS] Using English translated name: $englishName" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] No English translation found, using original/romanized name: $($seriesData.name)" -ForegroundColor Yellow
            Write-Host "[INFO] Consider adding the English title to TheTVDB if you know it" -ForegroundColor Gray
        }
        
        return $seriesData
    }
    catch {
        Write-Error "[ERROR] Failed to get series information: $($_.Exception.Message)"
        Write-Debug-Info "Series info error: $($_.Exception.Message)" "Red"
        return $null
    }
}

function Get-SeriesEpisodes {
    param($Token, $SeriesId)
    
    $authHeaders = $Headers.Clone()
    $authHeaders["Authorization"] = "Bearer $Token"
    
    try {
        Write-Host "[API] Fetching all episodes and seasons..." -ForegroundColor Yellow
        Write-Debug-Info "Fetching episodes for series ID: $SeriesId"
        $allEpisodes = @()
        $page = 0
        
        do {
            Write-Debug-Info "Fetching page $page of episodes..."
            $response = Invoke-RestMethod -Uri "$BaseApiUrl/series/$SeriesId/episodes/default?page=$page" -Method GET -Headers $authHeaders
            if ($response.data.episodes) {
                $allEpisodes += $response.data.episodes
                Write-Debug-Info "Found $($response.data.episodes.Count) episodes on page $page"
            }
            $page++
        } while ($response.data.episodes -and $response.data.episodes.Count -gt 0)
        
        Write-Debug-Info "Total episodes fetched: $($allEpisodes.Count)"
        
        # Process each episode to get English titles
        foreach ($episode in $allEpisodes) {
            $originalName = $episode.name
            Write-Debug-Info "Processing episode $($episode.number): $originalName"
            
            # Try to get English translation for this episode
            try {
                $episodeTranslation = Invoke-RestMethod -Uri "$BaseApiUrl/episodes/$($episode.id)/translations/eng" -Method GET -Headers $authHeaders
                if ($episodeTranslation.data -and $episodeTranslation.data.name -and $episodeTranslation.data.name -match '^[\x20-\x7E]+$') {
                    $episode.name = $episodeTranslation.data.name
                    Write-Debug-Info "  -> Using English title: $($episode.name)"
                } else {
                    # Check if original name is already English (ASCII only)
                    if ($originalName -match '^[\x20-\x7E]+$') {
                        Write-Debug-Info "  -> Original title appears to be English: $originalName"
                    } else {
                        # If no English translation and not ASCII, use a generic title
                        $episode.name = "Episode $($episode.number)"
                        Write-Debug-Info "  -> No English title found, using generic: $($episode.name)"
                    }
                }
            }
            catch {
                # If translation fails, check if original is English or use generic
                if ($originalName -match '^[\x20-\x7E]+$') {
                    Write-Debug-Info "  -> Translation failed, but original appears English: $originalName"
                } else {
                    $episode.name = "Episode $($episode.number)"
                    Write-Debug-Info "  -> Translation failed, using generic: $($episode.name)"
                }
            }
        }
        
        return $allEpisodes
    }
    catch {
        Write-Error "[ERROR] Failed to get episodes: $($_.Exception.Message)"
        Write-Debug-Info "Episodes fetch error: $($_.Exception.Message)" "Red"
        return @()
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
    $safeFileName = $FileName -replace ':', ' - '      # Replace colons with space-dash-space
    $safeFileName = $safeFileName -replace '/', ' - '  # Replace forward slashes with space-dash-space
    $safeFileName = $safeFileName -replace '\\', ' - ' # Replace backslashes with space-dash-space
    $safeFileName = $safeFileName -replace '\|', ' - ' # Replace pipes with space-dash-space
    $safeFileName = $safeFileName -replace '\?', ''    # Remove question marks
    $safeFileName = $safeFileName -replace '\*', ''    # Remove asterisks
    $safeFileName = $safeFileName -replace '<', ''     # Remove less than
    $safeFileName = $safeFileName -replace '>', ''     # Remove greater than
    $safeFileName = $safeFileName -replace '"', ''     # Remove double quotes
    
    # Clean up multiple dashes and trim
    $safeFileName = $safeFileName -replace '-+', '-'   # Replace multiple dashes with single dash
    $safeFileName = $safeFileName -replace '^-|-$', '' # Remove leading/trailing dashes
    $safeFileName = $safeFileName.Trim()
    
    return $safeFileName
}

function Show-Preview {
    param($Operations)
    
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Magenta
    Write-Host "                           PREVIEW OF CHANGES                          " -ForegroundColor Magenta
    Write-Host "                        (NO CHANGES MADE YET)                        " -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Magenta
    Write-Host ""
    
    
    Write-Debug-Info "Generating preview for $($Operations.Count) operations"
    
    $folderOperations = $Operations | Group-Object TargetFolder
    
    foreach ($folderGroup in $folderOperations) {
        Write-Host "FOLDER: $($folderGroup.Name)" -ForegroundColor Cyan
        Write-Debug-Info "Folder '$($folderGroup.Name)' will contain $($folderGroup.Group.Count) files"
        
        foreach ($op in $folderGroup.Group) {
            Write-Host "   FROM: $($op.OriginalFile)" -ForegroundColor Yellow
            Write-Host "     TO: $($op.NewFileName)" -ForegroundColor Green
            Write-Debug-Info "Operation: Move '$($op.OriginalFile)' to '$($op.TargetFolder)\$($op.NewFileName)'"
            Write-Host ""
        }
    }
    
    Write-Host "Total operations: $($Operations.Count)" -ForegroundColor White
    Write-Host "Folders to create: $($folderOperations.Count)" -ForegroundColor White
    Write-Host ""
    Write-Host "WARNING: Review the above changes carefully before proceeding!" -ForegroundColor Red
    Write-Host ""
}

function Confirm-Operations {
    Write-Host "==========================================================================" -ForegroundColor Red
    Write-Host "                              CONFIRMATION                             " -ForegroundColor Red
    Write-Host "==========================================================================" -ForegroundColor Red
    Write-Host "WARNING: This will permanently move and rename your files!" -ForegroundColor Yellow
    Write-Host "Make sure you have reviewed the preview above carefully." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  Y/Yes    - Proceed with file operations" -ForegroundColor Green
    Write-Host "  N/No     - Cancel and exit" -ForegroundColor Yellow
    Write-Host "  Q/Quit   - Exit program" -ForegroundColor Red
    Write-Host "  R/Restart- Start over with new settings" -ForegroundColor Magenta
    Write-Host ""
    
    do {
        $choice = Read-Host "Do you want to proceed? (Y/N/Q/R, default: Y)"
        $choice = $choice.ToUpper()
        
        Write-Debug-Info "User choice: $choice"
        
        if ($choice -eq "Y" -or $choice -eq "YES") {
            Write-Debug-Info "User confirmed to proceed with operations"
            return "proceed"
        } elseif ($choice -eq "N" -or $choice -eq "NO") {
            Write-Debug-Info "User chose to cancel operations"
            return "cancel"
        } elseif ($choice -eq "Q" -or $choice -eq "QUIT") {
            Write-Debug-Info "User chose to quit program"
            return "quit"
        } elseif ($choice -eq "R" -or $choice -eq "RESTART") {
            Write-Debug-Info "User chose to restart script"
            return "restart"
        } else {
            Write-Host "Please enter Y (Yes), N (No), Q (Quit), or R (Restart)" -ForegroundColor Red
        }
    } while ($true)
}

function Rename-SeriesFolder {
    param($WorkingDirectory, $SeriesId, $EnglishSeriesName)
    
    $currentFolderName = Split-Path $WorkingDirectory -Leaf
    $tvdbPattern = '\[tvdb-\d+\]'
    
    if ($currentFolderName -match $tvdbPattern) {
        Write-Host "[INFO] Folder already has TVDB ID format: $currentFolderName" -ForegroundColor Green
        return $WorkingDirectory
    }
    
    $cleanSeriesName = Get-SafeFileName -FileName $EnglishSeriesName
    $newFolderName = "$cleanSeriesName [tvdb-$SeriesId]"
    
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "                         FOLDER RENAME OPTION                          " -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "For optimal Hama scanner compatibility, the series folder can be renamed:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   FROM: $currentFolderName" -ForegroundColor Yellow
    Write-Host "     TO: $newFolderName" -ForegroundColor Green
    Write-Host ""
    
    do {
        $choice = Read-Host "Rename folder for Hama compatibility? (Y/N, default: Y)"
        switch ($choice.ToUpper()) {
            "Y" {
                try {
                    $parentPath = Split-Path $WorkingDirectory -Parent
                    $newWorkingDirectory = Join-Path $parentPath $newFolderName
                    
                    Write-Host "[INFO] Renaming series folder..." -ForegroundColor Cyan
                    Rename-Item -LiteralPath $WorkingDirectory -NewName $newFolderName -ErrorAction Stop
                    Write-Host "[SUCCESS] Folder renamed to: $newFolderName" -ForegroundColor Green
                    return $newWorkingDirectory
                }
                catch {
                    Write-Host "[ERROR] Could not rename folder: $($_.Exception.Message)" -ForegroundColor Red
                    return $WorkingDirectory
                }
            }
            "N" {
                Write-Host "[INFO] Folder rename skipped." -ForegroundColor Yellow
                return $WorkingDirectory
            }
            default {
                Write-Host "Please enter Y (Yes) or N (No)" -ForegroundColor Red
            }
        }
    } while ($true)
}

function Execute-FileOperations {
    param($Operations, $WorkingDirectory)
    
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "                        EXECUTING FILE OPERATIONS                      " -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host ""
    
    $successCount = 0
    $errorCount = 0
    $folderCreateCount = 0
    
    Write-Debug-Info "Starting execution of $($Operations.Count) operations"
    
    
    # Create folders first
    $foldersToCreate = $Operations | Select-Object -ExpandProperty TargetFolder | Sort-Object -Unique
    Write-Debug-Info "Need to create $($foldersToCreate.Count) unique folders"
    
    foreach ($folder in $foldersToCreate) {
        $fullPath = Join-Path -Path $WorkingDirectory -ChildPath $folder
        Write-Debug-Info "Checking folder: $fullPath"
        
        if (-not (Test-Path -LiteralPath $fullPath)) {
            try {
                New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
                Write-Host "[SUCCESS] Created folder: $folder" -ForegroundColor Green
                Write-Debug-Info "Successfully created folder: $fullPath" "Green"
                $folderCreateCount++
            }
            catch {
                Write-Error "[ERROR] Failed to create folder $folder : $($_.Exception.Message)"
                Write-Debug-Info "Failed to create folder: $fullPath - $($_.Exception.Message)" "Red"
                $errorCount++
                return $false
            }
        } else {
            Write-Debug-Info "Folder already exists: $fullPath" "Gray"
        }
    }
    
    Write-Host ""
    Write-Host "[INFO] Starting file operations..." -ForegroundColor Cyan
    Write-Host ""
    
    # Move and rename files
    foreach ($operation in $Operations) {
        $sourcePath = $operation.SourcePath
        # Handle the case where TargetFolder is "." (current directory)
        if ($operation.TargetFolder -eq ".") {
            $targetPath = Join-Path -Path $WorkingDirectory -ChildPath $operation.NewFileName
        } else {
            $targetPath = Join-Path -Path $WorkingDirectory -ChildPath (Join-Path -Path $operation.TargetFolder -ChildPath $operation.NewFileName)
        }
        
        Write-Debug-Info "Processing: $($operation.OriginalFile)"
        Write-Debug-Info "  Source: $sourcePath"
        Write-Debug-Info "  Target: $targetPath"
        
        try {            
            if (Test-Path -LiteralPath $sourcePath) {
                # Check if target already exists
                if (Test-Path -LiteralPath $targetPath) {
                    Write-Host "[WARNING] Target file already exists: $($operation.NewFileName)" -ForegroundColor Yellow
                    Write-Debug-Info "Target file exists, skipping: $targetPath" "Yellow"
                    continue
                }
                
                Move-Item -LiteralPath $sourcePath -Destination $targetPath -ErrorAction Stop
                Write-Host "[SUCCESS] $($operation.OriginalFile) -> $($operation.NewFileName)" -ForegroundColor Green
                Write-Debug-Info "Successfully moved file" "Green"
                $successCount++
            } else {
                Write-Host "[ERROR] Source file not found: $($operation.OriginalFile)" -ForegroundColor Red
                Write-Debug-Info "Source file not found: $sourcePath" "Red"
                $errorCount++
            }
        }
        catch {
            Write-Host "[ERROR] Failed to move $($operation.OriginalFile): $($_.Exception.Message)" -ForegroundColor Red
            Write-Debug-Info "Move operation failed: $($_.Exception.Message)" "Red"
            $errorCount++
        }
    }
    
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "                           OPERATION SUMMARY                           " -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "Folders created: $folderCreateCount" -ForegroundColor Cyan
    Write-Host "Files moved successfully: $successCount" -ForegroundColor Green
    Write-Host "Errors encountered: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Green" })
    Write-Host "Total operations: $($Operations.Count)" -ForegroundColor White
    
    if ($errorCount -eq 0) {
        Write-Host "[COMPLETE] All file operations completed successfully!" -ForegroundColor Green
        Write-Debug-Info "All operations completed without errors" "Green"
    } else {
        Write-Host "[WARNING] Some operations failed. Please check the errors above." -ForegroundColor Yellow
        Write-Debug-Info "$errorCount operations failed" "Red"
    }
    
    return ($errorCount -eq 0)
}

# Main execution starts here
do {
    $shouldRestart = $false
    Write-Header

    # Interactive mode
if ($Interactive) {
    if ($SeriesId -eq 0) {
        Write-Host "Enter the TheTVDB Series ID for your anime series." -ForegroundColor Cyan
        Write-Host "You can find this on TheTVDB.com in the series URL." -ForegroundColor Gray
        Write-Host "Example: For Attack on Titan, use ID: 290434" -ForegroundColor Gray
        Write-Host ""
        
        while ($SeriesId -eq 0) {
            $input = Read-Host "TheTVDB Series ID (or 'Q' to quit)"
            if ($input.ToUpper() -eq "Q" -or $input.ToLower() -eq "quit") {
                Write-Host "Exiting..." -ForegroundColor Yellow
                exit 0
            }
            
            if ([int]::TryParse($input, [ref]$SeriesId) -and $SeriesId -gt 0) {
                # Authenticate with TheTVDB
                Write-Host ""
                Write-Host "[INFO] Authenticating with TheTVDB..." -ForegroundColor Cyan
                $token = Get-TheTVDBToken -ApiKey $ApiKey -Pin $Pin
                if (-not $token) {
                    Write-Host "[ERROR] Cannot proceed without authentication. Please try again." -ForegroundColor Red
                    $SeriesId = 0
                    continue
                }
                
                # Get and verify series information
                Write-Host "[INFO] Fetching series information for ID: $SeriesId..." -ForegroundColor Cyan
                $seriesInfo = Get-SeriesInfo -Token $token -SeriesId $SeriesId
                if (-not $seriesInfo) {
                    Write-Host "[ERROR] Cannot retrieve series information. Please check the Series ID." -ForegroundColor Red
                    Write-Host "Try a different Series ID or check TheTVDB.com" -ForegroundColor Yellow
                    $SeriesId = 0
                    continue
                }
                
                # Show series info and ask for confirmation
                Write-Host ""
                Write-Host "==========================================================================" -ForegroundColor Green
                Write-Host "                           SERIES VERIFICATION                         " -ForegroundColor Green  
                Write-Host "==========================================================================" -ForegroundColor Green
                Write-Host ""
                Write-Host "Series ID: $SeriesId" -ForegroundColor Cyan
                Write-Host "Series Name: $($seriesInfo.name)" -ForegroundColor Yellow
                Write-Host ""
                
                # Ask for confirmation and handle response
                $seriesVerificationDone = $false
                do {
                    $confirm = Read-Host "Is this the correct series? (Y/N/Q, default: Y)"
                    switch ($confirm.ToUpper()) {
                        "Y" {
                            Write-Host "[SUCCESS] Series confirmed!" -ForegroundColor Green
                            Write-Host ""
                            # $SeriesId stays > 0, so outer loop will exit
                            $seriesVerificationDone = $true
                        }
                        "N" {
                            Write-Host "[INFO] Please enter a different Series ID." -ForegroundColor Yellow
                            $SeriesId = 0  # This will cause outer loop to continue
                            $seriesVerificationDone = $true
                        }
                        "Q" {
                            Write-Host "Exiting..." -ForegroundColor Yellow
                            exit 0
                        }
                        default {
                            Write-Host "Please enter Y (Yes), N (No), or Q (Quit)" -ForegroundColor Red
                        }
                    }
                    if ($seriesVerificationDone) { break }
                } while ($true)
            } else {
                Write-Host "[ERROR] Please enter a valid positive number" -ForegroundColor Red
            }
        }
    }
    
    Write-Host ""
    Write-Host "Working Directory: $WorkingDirectory" -ForegroundColor Cyan
    
    do {
        $newDir = Read-Host "Enter working directory path (or '.' for current directory, 'Q' to quit)"
        if ($newDir.ToUpper() -eq "Q" -or $newDir.ToLower() -eq "quit") {
            Write-Host "Exiting..." -ForegroundColor Yellow
            exit 0
        }
        # Clean up the path (remove quotes, trim whitespace)
        $newDir = $newDir.Trim().Trim('"').Trim("'")
        
        # Handle current directory (.)
        if ($newDir -eq ".") {
            $WorkingDirectory = (Get-Location).Path
            Write-Host "[INFO] Using current directory: $WorkingDirectory" -ForegroundColor Green
            break
        }
        
        Write-Debug-Info "Testing path: '$newDir'"
        if (Test-Path -LiteralPath $newDir) {
            $WorkingDirectory = $newDir
            Write-Host "[INFO] Working directory set to: $WorkingDirectory" -ForegroundColor Green
            break
        } else {
            Write-Host "[ERROR] Directory does not exist. Please enter a valid path." -ForegroundColor Red
        }
    } while ($true)
    
    # Choose operation type
    Write-Host ""
    Write-Host "Choose operation:" -ForegroundColor Cyan
    Write-Host "1. Rename only (keep current folder structure)" -ForegroundColor Yellow
    Write-Host "2. Reorganize (create Season folders and move files)" -ForegroundColor Yellow
    Write-Host ""
    
    do {
        $operation = Read-Host "Select operation (1/2/Q)"
        if ($operation.ToUpper() -eq "Q" -or $operation.ToLower() -eq "quit") {
            Write-Host "Exiting..." -ForegroundColor Yellow
            exit 0
        }
        if ($operation -eq "1" -or $operation -eq "2") {
            break
        } else {
            Write-Host "[ERROR] Please enter 1, 2, or Q" -ForegroundColor Red
        }
    } while ($true)
    
    $renameOnly = ($operation -eq "1")
}

# Authentication and series info already handled in interactive mode above
# For non-interactive mode, we still need to authenticate and get series info
if (-not $Interactive) {
    # Authenticate with TheTVDB
    $token = Get-TheTVDBToken -ApiKey $ApiKey -Pin $Pin
    if (-not $token) {
        Write-Host "[ERROR] Cannot proceed without authentication. Exiting." -ForegroundColor Red
        exit 1
    }
    
    # Get series information
    Write-Debug-Info "Fetching series information for ID: $SeriesId"
    $seriesInfo = Get-SeriesInfo -Token $token -SeriesId $SeriesId
    if (-not $seriesInfo) {
        Write-Host "[ERROR] Cannot retrieve series information for Series ID: $SeriesId" -ForegroundColor Red
        exit 1
    }
}

Write-Host "[SUCCESS] Series: $($seriesInfo.name)" -ForegroundColor Green
Write-Host "[SUCCESS] Status: $($seriesInfo.status.name)" -ForegroundColor Green

# Get all episodes
Write-Debug-Info "Fetching episode list for series"
$episodes = Get-SeriesEpisodes -Token $token -SeriesId $SeriesId
if ($episodes.Count -eq 0) {
    Write-Host "[ERROR] No episodes found for this series." -ForegroundColor Red
    Write-Debug-Info "No episodes found for series ID: $SeriesId" "Red"
    
    do {
        Write-Host "What would you like to do?" -ForegroundColor Cyan
        Write-Host "  R/Restart - Try with a different Series ID" -ForegroundColor Green
        Write-Host "  Q/Quit    - Exit the program" -ForegroundColor Red
        $choice = Read-Host "Choose (R/Q)"
        $choice = $choice.ToUpper()
        
        if ($choice -eq "R" -or $choice -eq "RESTART") {
            Write-Debug-Info "User chose to restart after episodes error"
            $shouldRestart = $true
            $SeriesId = 0
            $WorkingDirectory = (Get-Location).Path
            break
        } elseif ($choice -eq "Q" -or $choice -eq "QUIT") {
            Write-Debug-Info "User chose to quit after episodes error"
            Write-Host "Goodbye!" -ForegroundColor Yellow
            exit 1
        } else {
            Write-Host "Please enter R (Restart) or Q (Quit)" -ForegroundColor Red
        }
    } while ($true)
    
    if ($shouldRestart) {
        continue
    }
}

Write-Host "[SUCCESS] Found $($episodes.Count) episodes across all seasons" -ForegroundColor Green

# Store the English series name from API for consistent use
$globalEnglishSeriesName = $seriesInfo.name
Write-Debug-Info "Stored global English series name: '$globalEnglishSeriesName'"

# If the series name seems to be missing the main title (like "Queen's Blade"), 
# we might need to use a different approach or manually handle known series
if ([string]::IsNullOrWhiteSpace($globalEnglishSeriesName)) {
    Write-Host "[WARNING] API returned empty series name. Using Series ID as fallback." -ForegroundColor Yellow
    $globalEnglishSeriesName = "Series-$SeriesId"
}


# Find video files
Write-Debug-Info "Scanning for video files in: $WorkingDirectory"
$videoFiles = Find-VideoFiles -Directory $WorkingDirectory
if ($videoFiles.Count -eq 0) {
    do {
        Write-Host "What would you like to do?" -ForegroundColor Cyan
        Write-Host "  R/Restart - Try with a different directory" -ForegroundColor Green
        Write-Host "  Q/Quit    - Exit the program" -ForegroundColor Red
        $choice = Read-Host "Choose (R/Q)"
        $choice = $choice.ToUpper()
        
        if ($choice -eq "R" -or $choice -eq "RESTART") {
            Write-Debug-Info "User chose to restart after no files found"
            $shouldRestart = $true
            $SeriesId = 0
            $WorkingDirectory = (Get-Location).Path
            break
        } elseif ($choice -eq "Q" -or $choice -eq "QUIT") {
            Write-Debug-Info "User chose to quit after no files found"
            Write-Host "Goodbye!" -ForegroundColor Yellow
            exit 1
        } else {
            Write-Host "Please enter R (Restart) or Q (Quit)" -ForegroundColor Red
        }
    } while ($true)
    
    if ($shouldRestart) {
        continue
    }
}

# Parse filenames and match with episodes
Write-Host "[PROCESS] Analyzing files and matching with episode data..." -ForegroundColor Yellow
$operations = @()

# FIRST PASS: Check if TheTVDB has any official specials (season 0 episodes)
$hasOfficialSpecials = $episodes | Where-Object { $_.seasonNumber -eq 0 } | Measure-Object | Select-Object -ExpandProperty Count
Write-Debug-Info "TheTVDB has $hasOfficialSpecials official special episodes (season 0)"

# Separate special files from regular files
$specialFiles = @()
$regularFiles = @()

# First pass: Detect special content folders across all seasons (OVAs, OADs, Specials, Extras, Movies)
$specialFolders = @()
$regularFolders = @()

foreach ($file in $videoFiles) {
    $relativePath = $file.FullName.Replace($WorkingDirectory, "").TrimStart("\")
    $folderPath = Split-Path $relativePath -Parent
    
    # Check if file is in any special content folder (OVAs, OADs, Specials, Extras, Movies, etc.)
    if ($folderPath -match "(?i)(?:^|\\)(S\d+\s+)?(OVAs?|OADs?|Specials?|Extras?|Movies?)(?:$|\\)") {
        $specialFolders += $folderPath
        $specialFiles += $file
        Write-Debug-Info "Special content file detected: $relativePath (in folder: $folderPath)"
    } else {
        $regularFiles += $file
    }
}

# Remove duplicate folder paths
$specialFolders = $specialFolders | Sort-Object -Unique
Write-Debug-Info "Found special content folders: $($specialFolders -join ', ')"

Write-Debug-Info "Found $($specialFiles.Count) special files and $($regularFiles.Count) regular files"

if ($specialFolders.Count -gt 0) {
    Write-Host "[INFO] Detected special content folders across multiple seasons:" -ForegroundColor Cyan
    foreach ($folder in $specialFolders) {
        $folderFileCount = ($specialFiles | Where-Object { (Split-Path $_.FullName -Parent) -eq $folder }).Count
        Write-Host "  - $folder ($folderFileCount files)" -ForegroundColor Gray
    }
    Write-Host "[INFO] All special content will be consolidated into a single Specials folder with sequential numbering" -ForegroundColor Green
}

# Initialize episode version tracking (used by both specials and regular episodes)
$episodeVersionCounts = @{}

# Process special files first
if ($specialFiles.Count -gt 0) {
    Write-Host "[INFO] Processing $($specialFiles.Count) special files..." -ForegroundColor Cyan
    
    # Sort special files by name for consistent S00E numbering
    $specialFiles = $specialFiles | Sort-Object Name
    
    if ($hasOfficialSpecials -gt 0) {
        Write-Host "[INFO] Using TheTVDB special episode data (found $hasOfficialSpecials episodes)" -ForegroundColor Green
        # Use existing logic - match with actual episode data
        foreach ($file in $specialFiles) {
            $parsedFile = Parse-EpisodeNumber -FileName $file.Name
            
            if (-not $parsedFile) {
                Write-Warning "[WARNING] Could not parse episode number from: $($file.Name)"
                continue
            }
            
            # Find matching episode from TheTVDB data
            $matchingEpisodes = $episodes | Where-Object { $_.number -eq $parsedFile.EpisodeNumber }
            
            if ($matchingEpisodes.Count -eq 0) {
                Write-Warning "[WARNING] No episode data found for episode $($parsedFile.EpisodeNumber): $($file.Name)"
                continue
            }
            
            # For special files, prefer special episodes (season 0) or use first available
            $episode = $matchingEpisodes | Where-Object { $_.seasonNumber -eq 0 } | Select-Object -First 1
            if (-not $episode) {
                $episode = $matchingEpisodes | Select-Object -First 1
            }
            Write-Debug-Info "Special file - selected episode (season $($episode.seasonNumber))"
            
            # Use the series name from API
            $englishSeriesName = $seriesInfo.name
            
            # Determine target folder and filename
            $episodeTitle = Get-SafeFileName -FileName $episode.name
            
            Write-Host "[INFO] Using API title for S00E$($parsedFile.EpisodeNumber.ToString('D2')): $episodeTitle" -ForegroundColor Green
            
            if ($renameOnly) {
                $targetFolder = Split-Path $file.FullName -Parent
                $targetFolder = $targetFolder.Replace($WorkingDirectory, "").TrimStart("\")
                if ([string]::IsNullOrEmpty($targetFolder)) { $targetFolder = "." }
            } else {
                $targetFolder = "Specials"
            }
            
            $safeSeriesName = Get-SafeFileName -FileName $englishSeriesName
            # Check for duplicate special episodes and add version numbers
        $episodeKey = "S00E{0:D2}" -f $parsedFile.EpisodeNumber
        if ($episodeVersionCounts.ContainsKey($episodeKey)) {
            $episodeVersionCounts[$episodeKey]++
            $versionSuffix = " v$($episodeVersionCounts[$episodeKey])"
            Write-Debug-Info "Duplicate special episode detected: $episodeKey - adding version $($episodeVersionCounts[$episodeKey])"
        } else {
            $episodeVersionCounts[$episodeKey] = 1
            $versionSuffix = ""
        }
        
        $newFileName = "$safeSeriesName - $episodeKey$versionSuffix - $episodeTitle$($file.Extension)"
            
        # Skip if filename is already correct (optimization for NAS performance)
        if ($file.Name -eq $newFileName) {
            Write-Debug-Info "Skipping $($file.Name) - already has correct name"
            continue
        }
            
            $operation = New-Object PSObject -Property @{
                OriginalFile = $file.FullName.Replace($WorkingDirectory, "").TrimStart("\")
                SourcePath = $file.FullName
                NewFileName = $newFileName
                TargetFolder = $targetFolder
                EpisodeData = $episode
            }
            $operations += $operation
        }
        } else {
        Write-Host "[INFO] No TheTVDB special episodes found - assigning sequential S00E numbers across all seasons" -ForegroundColor Yellow
        
        # No official specials - assign sequential S00E01, S00E02, etc. across all OVA folders
        $specialEpisodeCounter = 1
        
        # Sort special files by folder path and then by filename for consistent ordering
        $sortedSpecialFiles = $specialFiles | Sort-Object @{Expression={Split-Path $_.FullName -Parent}; Ascending=$true}, Name
        
        foreach ($file in $sortedSpecialFiles) {
            if ($renameOnly) {
                $targetFolder = Split-Path $file.FullName -Parent
                $targetFolder = $targetFolder.Replace($WorkingDirectory, "").TrimStart("\")
                if ([string]::IsNullOrEmpty($targetFolder)) { $targetFolder = "." }
            } else {
                $targetFolder = "Specials"
            }
            
            $safeSeriesName = Get-SafeFileName -FileName $seriesInfo.name
        
        # Check for duplicate special episodes and add version numbers
        $episodeKey = "S00E{0:D2}" -f $specialEpisodeCounter
        if ($episodeVersionCounts.ContainsKey($episodeKey)) {
            $episodeVersionCounts[$episodeKey]++
            $versionSuffix = " v$($episodeVersionCounts[$episodeKey])"
            Write-Debug-Info "Duplicate sequential special episode detected: $episodeKey - adding version $($episodeVersionCounts[$episodeKey])"
        } else {
            $episodeVersionCounts[$episodeKey] = 1
            $versionSuffix = ""
        }
        
        $newFileName = "$safeSeriesName - $episodeKey$versionSuffix - $($file.BaseName)$($file.Extension)"
            
        # Skip if filename is already correct (optimization for NAS performance)
        if ($file.Name -eq $newFileName) {
            Write-Debug-Info "Skipping $($file.Name) - already has correct name"
            continue
        }
            
            $operation = New-Object PSObject -Property @{
                OriginalFile = $file.FullName.Replace($WorkingDirectory, "").TrimStart("\")
                SourcePath = $file.FullName
                NewFileName = $newFileName
                TargetFolder = $targetFolder
                EpisodeData = $null
            }
            $operations += $operation
            
            $specialEpisodeCounter++
        }
    }
}

# Process regular files normally
Write-Host "[INFO] Processing $($regularFiles.Count) regular files..." -ForegroundColor Cyan

# Track episode numbers to detect duplicates and add version numbers (initialized earlier)

foreach ($file in $regularFiles) {
    $parsedFile = Parse-EpisodeNumber -FileName $file.Name
    
    if (-not $parsedFile) {
        Write-Warning "[WARNING] Could not parse episode number from: $($file.Name)"
        continue
    }
    
    # Find matching episode(s) from TheTVDB data by episode number
    $matchingEpisodes = $episodes | Where-Object { $_.number -eq $parsedFile.EpisodeNumber }
    
    if ($matchingEpisodes.Count -eq 0) {
        Write-Warning "[WARNING] No episode data found for episode $($parsedFile.EpisodeNumber): $($file.Name)"
        continue
    }
    
    # Determine season strictly from parsed filename (supports mixed seasons in same folder)
    $detectedSeason = $parsedFile.SeasonNumber
    
    # Select the episode that belongs to the detected season; fallback to any if not found
    $episode = $matchingEpisodes | Where-Object { $_.seasonNumber -eq $detectedSeason } | Select-Object -First 1
    if (-not $episode) {
        $episode = $matchingEpisodes | Select-Object -First 1
        Write-Warning "[WARNING] No Season $detectedSeason match for E$($parsedFile.EpisodeNumber). Using closest available season $($episode.seasonNumber)."
    }
    Write-Debug-Info "Regular file - selected episode (season $($episode.seasonNumber))"
    
    # Use the series name from API
    $englishSeriesName = $seriesInfo.name
    
    # Determine target folder and filename
    $episodeTitle = Get-SafeFileName -FileName $episode.name
    
    Write-Host "[INFO] Using API title for S${detectedSeason}E$($parsedFile.EpisodeNumber): $episodeTitle" -ForegroundColor Green
    
    if ($renameOnly) {
        $targetFolder = Split-Path $file.FullName -Parent
        $targetFolder = $targetFolder.Replace($WorkingDirectory, "").TrimStart("\")
        if ([string]::IsNullOrEmpty($targetFolder)) { $targetFolder = "." }
    } else {
        $targetFolder = "Season {0:D2}" -f $detectedSeason
    }
    
    $safeSeriesName = Get-SafeFileName -FileName $englishSeriesName
            # Check for duplicate episodes and add version numbers
        $episodeKey = "S{0:D2}E{1:D2}" -f $detectedSeason, $parsedFile.EpisodeNumber
        if ($episodeVersionCounts.ContainsKey($episodeKey)) {
            $episodeVersionCounts[$episodeKey]++
            $versionSuffix = " v$($episodeVersionCounts[$episodeKey])"
            Write-Debug-Info "Duplicate episode detected: $episodeKey - adding version $($episodeVersionCounts[$episodeKey])"
        } else {
            $episodeVersionCounts[$episodeKey] = 1
            $versionSuffix = ""
        }
        
        $newFileName = "$safeSeriesName - $episodeKey$versionSuffix - $episodeTitle$($file.Extension)"
    
    # Skip if filename is already correct (optimization for NAS performance)
    if ($file.Name -eq $newFileName) {
        Write-Debug-Info "Skipping $($file.Name) - already has correct name"
        continue
    }
    
    $operation = New-Object PSObject -Property @{
        OriginalFile = $file.FullName.Replace($WorkingDirectory, "").TrimStart("\")
        SourcePath = $file.FullName
        NewFileName = $newFileName
        TargetFolder = $targetFolder
        EpisodeData = $episode
    }
    $operations += $operation
}

if ($operations.Count -eq 0) {
    Write-Host "[ERROR] No files could be matched with episode data." -ForegroundColor Red
    Write-Debug-Info "No files could be matched - $($videoFiles.Count) files scanned" "Red"
    
    do {
        Write-Host "What would you like to do?" -ForegroundColor Cyan
        Write-Host "  R/Restart - Try with different settings" -ForegroundColor Green
        Write-Host "  Q/Quit    - Exit the program" -ForegroundColor Red
        $choice = Read-Host "Choose (R/Q)"
        $choice = $choice.ToUpper()
        
        if ($choice -eq "R" -or $choice -eq "RESTART") {
            Write-Debug-Info "User chose to restart after no matches"
            $shouldRestart = $true
            $SeriesId = 0
            $WorkingDirectory = (Get-Location).Path
            break
        } elseif ($choice -eq "Q" -or $choice -eq "QUIT") {
            Write-Debug-Info "User chose to quit after no matches"
            Write-Host "Goodbye!" -ForegroundColor Yellow
            exit 1
        } else {
            Write-Host "Please enter R (Restart) or Q (Quit)" -ForegroundColor Red
        }
    } while ($true)
    
    if ($shouldRestart) {
        continue
    }
}

# Show preview
Show-Preview -Operations $operations

# Get confirmation and execute
if ($Interactive) {
    $userChoice = Confirm-Operations
    switch ($userChoice) {
        "proceed" {
            $result = Execute-FileOperations -Operations $operations -WorkingDirectory $WorkingDirectory
            # Always offer folder renaming, regardless of file operation success
            # (folder renaming is independent of file operations)
            $WorkingDirectory = Rename-SeriesFolder -WorkingDirectory $WorkingDirectory -SeriesId $SeriesId -EnglishSeriesName $globalEnglishSeriesName
        }
        "cancel" {
            Write-Host "[CANCELLED] Operation cancelled by user." -ForegroundColor Yellow
            Write-Debug-Info "User cancelled the operation"
            
            do {
                Write-Host "What would you like to do?" -ForegroundColor Cyan
                Write-Host "  R/Restart - Start over with new settings" -ForegroundColor Green
                Write-Host "  Q/Quit    - Exit the program" -ForegroundColor Red
                $choice = Read-Host "Choose (R/Q)"
                $choice = $choice.ToUpper()
                
                if ($choice -eq "R" -or $choice -eq "RESTART") {
                    Write-Debug-Info "User chose to restart after cancel"
                    $shouldRestart = $true
                    $SeriesId = 0
                    $WorkingDirectory = (Get-Location).Path
                    break
                } elseif ($choice -eq "Q" -or $choice -eq "QUIT") {
                    Write-Debug-Info "User chose to quit after cancel"
                    Write-Host "Goodbye!" -ForegroundColor Yellow
                    exit 0
                } else {
                    Write-Host "Please enter R (Restart) or Q (Quit)" -ForegroundColor Red
                }
            } while ($true)
        }
        "quit" {
            Write-Host "Exiting..." -ForegroundColor Yellow
            Write-Debug-Info "User chose to quit"
            exit 0
        }
        "restart" {
            Write-Host "[RESTART] Restarting script..." -ForegroundColor Yellow
            Write-Debug-Info "User chose to restart script"
            $shouldRestart = $true
            # Reset variables for restart
            $SeriesId = 0
            $WorkingDirectory = (Get-Location).Path
        }
    }
} else {
    Write-Debug-Info "Running in non-interactive mode, proceeding with operations"
    $result = Execute-FileOperations -Operations $operations -WorkingDirectory $WorkingDirectory
    if ($result) {
        Write-Host "All operations completed successfully in non-interactive mode." -ForegroundColor Green
        # Note: Folder renaming skipped in non-interactive mode
        Write-Host "[INFO] Folder renaming skipped in non-interactive mode. Use interactive mode for folder renaming." -ForegroundColor Yellow
    } else {
        Write-Host "Some operations failed in non-interactive mode." -ForegroundColor Red
    }
}

if (-not $shouldRestart) {
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "                              SCRIPT COMPLETE                           " -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "Thank you for using Universal Anime File Organizer!" -ForegroundColor Cyan
    Write-Host "Attribution: Metadata provided by TheTVDB (https://thetvdb.com)" -ForegroundColor Gray
    Write-Host ""
    Write-Debug-Info "Script execution completed"
    
    # Ask user what to do next
    do {
        Write-Host "What would you like to do?" -ForegroundColor Cyan
        Write-Host "  R/Restart - Run the script again" -ForegroundColor Green
        Write-Host "  Q/Quit    - Exit the program" -ForegroundColor Red
        $choice = Read-Host "Choose (R/Q)"
        $choice = $choice.ToUpper()
        
        if ($choice -eq "R" -or $choice -eq "RESTART") {
            Write-Debug-Info "User chose to restart after completion"
            $shouldRestart = $true
            $SeriesId = 0
            $WorkingDirectory = (Get-Location).Path
            break
        } elseif ($choice -eq "Q" -or $choice -eq "QUIT") {
            Write-Debug-Info "User chose to quit after completion"
            Write-Host "Goodbye!" -ForegroundColor Yellow
            break
        } else {
            Write-Host "Please enter R (Restart) or Q (Quit)" -ForegroundColor Red
        }
    } while ($true)
}

} while ($shouldRestart)