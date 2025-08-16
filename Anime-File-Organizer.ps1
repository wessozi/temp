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
            if ($translationResponse.data -and $translationResponse.data.name) {
                $englishName = $translationResponse.data.name
                Write-Debug-Info "Found English translation: $englishName"
            }
        }
        catch {
            Write-Debug-Info "English translations endpoint failed: $($_.Exception.Message)"
        }
        
        # Method 2: Check if the original name contains only ASCII characters
        if (-not $englishName -and $seriesData.name -match '^[\x20-\x7E]+$') {
            $englishName = $seriesData.name
            Write-Debug-Info "Original name appears to be English: $englishName"
        }
        
        # Method 3: Try to get alternate names/aliases
        try {
            Write-Debug-Info "Trying series extended info for aliases..."
            $extendedResponse = Invoke-RestMethod -Uri "$BaseApiUrl/series/$SeriesId/extended" -Method GET -Headers $authHeaders
            if ($extendedResponse.data.aliases) {
                foreach ($alias in $extendedResponse.data.aliases) {
                    if ($alias.name -match '^[\x20-\x7E]+$') {
                        $englishName = $alias.name
                        Write-Debug-Info "Found English alias: $englishName"
                        break
                    }
                }
            }
        }
        catch {
            Write-Debug-Info "Extended series info failed: $($_.Exception.Message)"
        }
        
        # Use English name if found, otherwise use original
        if ($englishName) {
            $seriesData.name = $englishName
            Write-Host "[SUCCESS] Using English name: $englishName" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] No English name found, using: $($seriesData.name)" -ForegroundColor Yellow
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
    $videoFiles = Get-ChildItem -LiteralPath $Directory -File -Recurse | Where-Object { 
        $VideoExtensions -contains $_.Extension.ToLower() 
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
        
        # 2. Standard SxxExx formats
        '^[Ss](\d+)[Ee](\d+).*\..*$',                                         # S01E01 Title.mkv or s01e09.mkv
        '^(.+?)\s+[Ss](\d+)[Ee](\d+).*\..*$',                                 # Series S01E01 Title.mkv
        
        # 3. Series - Episode formats (with dash separator)
        '^(.+?)\s*-\s*(\d+).*\..*$',                                          # Series - 01.mkv
        
        # 4. Episode/Ep keyword formats
        '^(.+?)\s+(?:Episode|Ep|E)\s*(\d+).*\..*$',                           # Series Episode 01.mkv
        
        # 5. Numbered episode formats (space separated)
        '^(.+?)\s+(\d{1,3})(?:\s+.*)?\..*$',                                  # Series 01 Title.mkv
        
        # 6. OVA/Special formats
        '^(.+?)\s+(?:OVA|OAD|Special)\s*(\d+)?.*\..*$',                       # Series OVA 1.mkv
        
        # 7. Bracketed episode numbers
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
    
    foreach ($pattern in $patterns) {
        Write-Debug-Info "Trying pattern: $pattern"
        if ($FileName -match $pattern) {
            Write-Debug-Info "Pattern matched! Matches count: $($Matches.Count)"
            
            $seriesName = ""
            $episodeNum = 0
            $seasonNum = 1  # Default season
            
            # Handle different pattern types based on capture groups
            switch ($Matches.Count) {
                2 {
                    # Single capture group - episode number only
                    $episodeNum = [int]$Matches[1]
                    $seriesName = "Unknown Series"  # Will use API series name
                    Write-Debug-Info "Single capture: Episode $episodeNum"
                }
                3 {
                    # Two capture groups - series and episode
                    $seriesName = $Matches[1].Trim()
                    $episodeNum = [int]$Matches[2]
                    Write-Debug-Info "Series+Episode: '$seriesName', Episode $episodeNum"
                }
                4 {
                    # Three capture groups - series, season, episode (SxxExx format)
                    $seriesName = $Matches[1].Trim()
                    $seasonNum = [int]$Matches[2]
                    $episodeNum = [int]$Matches[3]
                    Write-Debug-Info "Series+Season+Episode: '$seriesName', Season $seasonNum, Episode $episodeNum"
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
    
    $invalidChars = '[<>:"/\\|?*]'
    return $FileName -replace $invalidChars, ''
}

function Show-Preview {
    param($Operations, $WorkingDirectory, $SeriesId, $EnglishSeriesName)
    
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Magenta
    Write-Host "                           PREVIEW OF CHANGES                          " -ForegroundColor Magenta
    Write-Host "                        (NO CHANGES MADE YET)                        " -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Magenta
    Write-Host ""
    
    # Check if folder needs TVDB ID renaming
    $currentFolderName = Split-Path $WorkingDirectory -Leaf
    $tvdbPattern = '\[tvdb-\d+\]'
    $folderRenameNeeded = $currentFolderName -notmatch $tvdbPattern
    
    if ($folderRenameNeeded) {
        $cleanSeriesName = Get-SafeFileName -FileName $EnglishSeriesName
        $newFolderName = "$cleanSeriesName [tvdb-$SeriesId]"
        Write-Host "FOLDER RENAME (for Hama scanner compatibility):" -ForegroundColor Magenta
        Write-Host "   FROM: $currentFolderName" -ForegroundColor Yellow
        Write-Host "     TO: $newFolderName" -ForegroundColor Green
        Write-Host ""
    }
    
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
        $choice = Read-Host "Do you want to proceed? (Y/N/Q/R)"
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

function Execute-FileOperations {
    param($Operations, $WorkingDirectory, $SeriesId, $EnglishSeriesName)
    
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "                        EXECUTING FILE OPERATIONS                      " -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host ""
    
    $successCount = 0
    $errorCount = 0
    $folderCreateCount = 0
    
    Write-Debug-Info "Starting execution of $($Operations.Count) operations"
    
    # First, handle folder renaming if needed
    $currentFolderName = Split-Path $WorkingDirectory -Leaf
    $tvdbPattern = '\[tvdb-\d+\]'
    
    if ($currentFolderName -notmatch $tvdbPattern) {
        $cleanSeriesName = Get-SafeFileName -FileName $EnglishSeriesName
        $newFolderName = "$cleanSeriesName [tvdb-$SeriesId]"
        $parentPath = Split-Path $WorkingDirectory -Parent
        $newWorkingDirectory = Join-Path $parentPath $newFolderName
        
        Write-Host "[INFO] Renaming series folder for Hama scanner compatibility..." -ForegroundColor Cyan
        Write-Debug-Info "Renaming: '$currentFolderName' -> '$newFolderName'"
        
        try {
            Rename-Item -Path $WorkingDirectory -NewName $newFolderName -ErrorAction Stop
            $WorkingDirectory = $newWorkingDirectory
            Write-Host "[SUCCESS] Folder renamed to: $newFolderName" -ForegroundColor Green
            Write-Debug-Info "Updated working directory: $WorkingDirectory"
        }
        catch {
            Write-Host "[ERROR] Could not rename folder: $($_.Exception.Message)" -ForegroundColor Red
            Write-Debug-Info "Folder rename failed: $($_.Exception.Message)" "Red"
            $errorCount++
        }
    }
    
    # Create folders first
    $foldersToCreate = $Operations | Select-Object -ExpandProperty TargetFolder | Sort-Object -Unique
    Write-Debug-Info "Need to create $($foldersToCreate.Count) unique folders"
    
    foreach ($folder in $foldersToCreate) {
        $fullPath = Join-Path -Path $WorkingDirectory -ChildPath $folder
        Write-Debug-Info "Checking folder: $fullPath"
        
        if (-not (Test-Path $fullPath)) {
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
        $targetPath = Join-Path -Path $WorkingDirectory -ChildPath (Join-Path -Path $operation.TargetFolder -ChildPath $operation.NewFileName)
        
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
        
        do {
            $input = Read-Host "TheTVDB Series ID (or 'Q' to quit)"
            if ($input.ToUpper() -eq "Q" -or $input.ToLower() -eq "quit") {
                Write-Host "Exiting..." -ForegroundColor Yellow
                exit 0
            }
            if ([int]::TryParse($input, [ref]$SeriesId) -and $SeriesId -gt 0) {
                break
            } else {
                Write-Host "[ERROR] Please enter a valid positive number" -ForegroundColor Red
            }
        } while ($true)
    }
    
    Write-Host ""
    Write-Host "Working Directory: $WorkingDirectory" -ForegroundColor Cyan
    $changeDir = Read-Host "Change directory? (Y/N/Q, default: N)"
    
    if ($changeDir.ToUpper() -eq "Q" -or $changeDir.ToLower() -eq "quit") {
        Write-Host "Exiting..." -ForegroundColor Yellow
        exit 0
    }
    if ($changeDir.ToUpper() -eq "Y" -or $changeDir.ToUpper() -eq "YES") {
        do {
            $newDir = Read-Host "Enter new directory path (or 'Q' to quit)"
            if ($newDir.ToUpper() -eq "Q" -or $newDir.ToLower() -eq "quit") {
                Write-Host "Exiting..." -ForegroundColor Yellow
                exit 0
            }
            # Clean up the path (remove quotes, trim whitespace)
            $newDir = $newDir.Trim().Trim('"').Trim("'")
            Write-Debug-Info "Testing path: '$newDir'"
            if (Test-Path -LiteralPath $newDir) {
                $WorkingDirectory = $newDir
                break
            } else {
                Write-Host "[ERROR] Directory does not exist. Please enter a valid path." -ForegroundColor Red
            }
        } while ($true)
    }
    
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
    Write-Host "[ERROR] Cannot retrieve series information. Please check the Series ID." -ForegroundColor Red
    Write-Debug-Info "Failed to retrieve series information for ID: $SeriesId" "Red"
    
    do {
        Write-Host "What would you like to do?" -ForegroundColor Cyan
        Write-Host "  R/Restart - Try with a different Series ID" -ForegroundColor Green
        Write-Host "  Q/Quit    - Exit the program" -ForegroundColor Red
        $choice = Read-Host "Choose (R/Q)"
        $choice = $choice.ToUpper()
        
        if ($choice -eq "R" -or $choice -eq "RESTART") {
            Write-Debug-Info "User chose to restart after series error"
            $shouldRestart = $true
            $SeriesId = 0
            $WorkingDirectory = (Get-Location).Path
            break
        } elseif ($choice -eq "Q" -or $choice -eq "QUIT") {
            Write-Debug-Info "User chose to quit after series error"
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

foreach ($file in $videoFiles) {
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
    
    # Check if this file is in a special folder first
    $relativePath = $file.FullName.Replace($WorkingDirectory, "").TrimStart("\")
    $isInSpecialFolder = $relativePath -match "(?i)(Specials?|OVA|OAD|Movies?|Extra)"
    
    # Choose episode based on file location
    if ($isInSpecialFolder) {
        # For files in special folders, prefer special episodes (season 0)
        $episode = $matchingEpisodes | Where-Object { $_.seasonNumber -eq 0 } | Select-Object -First 1
        if (-not $episode) {
            $episode = $matchingEpisodes | Select-Object -First 1
        }
        Write-Debug-Info "File in special folder - selected special episode (season $($episode.seasonNumber))"
    } else {
        # For regular files, prefer non-special episodes
        $episode = $matchingEpisodes | Where-Object { $_.seasonNumber -ne 0 } | Select-Object -First 1
        if (-not $episode) {
            $episode = $matchingEpisodes | Select-Object -First 1
        }
        Write-Debug-Info "File in regular folder - selected regular episode (season $($episode.seasonNumber))"
    }
    
    # Use the series name from API (with English override for known series)
    $englishSeriesName = $seriesInfo.name
    
    # Use season number from API data
    $detectedSeason = $episode.seasonNumber
    if ($detectedSeason -eq 0) {
        $detectedSeason = 1  # Default to season 1 for specials if needed
    }
    
    # Determine target folder and filename
    $seasonNumber = $episode.seasonNumber
    $episodeTitle = Get-SafeFileName -FileName $episode.name
    
    Write-Host "[INFO] Using API title for S${detectedSeason}E$($parsedFile.EpisodeNumber): $episodeTitle" -ForegroundColor Green
    
    # Check if this is a special episode (using already calculated values plus additional checks)
    $isSpecial = ($episode.seasonNumber -eq 0) -or ($file.Name -match "OVA") -or $isInSpecialFolder
    
    Write-Debug-Info "File path analysis: '$relativePath'"
    Write-Debug-Info "Is in special folder: $isInSpecialFolder"
    Write-Debug-Info "Final isSpecial determination: $isSpecial"
    
    if ($isSpecial) {
        if ($renameOnly) {
            $targetFolder = Split-Path $file.FullName -Parent
            $targetFolder = $targetFolder.Replace($WorkingDirectory, "").TrimStart("\")
            if ([string]::IsNullOrEmpty($targetFolder)) { $targetFolder = "." }
        } else {
            $targetFolder = "Specials"
        }
        $newFileName = "$englishSeriesName - S00E{0:D2} - $episodeTitle$($file.Extension)" -f $parsedFile.EpisodeNumber
    } else {
        if ($renameOnly) {
            $targetFolder = Split-Path $file.FullName -Parent
            $targetFolder = $targetFolder.Replace($WorkingDirectory, "").TrimStart("\")
            if ([string]::IsNullOrEmpty($targetFolder)) { $targetFolder = "." }
        } else {
            $targetFolder = "Season {0:D2}" -f $detectedSeason
        }
        $newFileName = "$englishSeriesName - S{0:D2}E{1:D2} - $episodeTitle$($file.Extension)" -f $detectedSeason, $parsedFile.EpisodeNumber
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
Show-Preview -Operations $operations -WorkingDirectory $WorkingDirectory -SeriesId $SeriesId -EnglishSeriesName $seriesInfo.EnglishName

# Get confirmation and execute
if ($Interactive) {
    $userChoice = Confirm-Operations
    switch ($userChoice) {
        "proceed" {
            Execute-FileOperations -Operations $operations -WorkingDirectory $WorkingDirectory -SeriesId $SeriesId -EnglishSeriesName $seriesInfo.EnglishName
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
    $result = Execute-FileOperations -Operations $operations -WorkingDirectory $WorkingDirectory -SeriesId $SeriesId -EnglishSeriesName $seriesInfo.EnglishName
    if ($result) {
        Write-Host "All operations completed successfully in non-interactive mode." -ForegroundColor Green
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