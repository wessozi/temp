# Organize-Anime.ps1 - Main Entry Point for Modular Anime Organizer
# Orchestrates the complete workflow using logical modules
# IDENTICAL functionality to original Anime-File-Organizer.ps1

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
    [bool]$Interactive = $true
)

# Import all modules
$ModulesPath = Join-Path $PSScriptRoot "Modules"

try {
    Import-Module "$ModulesPath\TheTVDB.psm1" -Force
    Import-Module "$ModulesPath\FileParser.psm1" -Force  
    Import-Module "$ModulesPath\UserInterface.psm1" -Force
    Import-Module "$ModulesPath\FileOperations.psm1" -Force
    Import-Module "$ModulesPath\NamingConvention.psm1" -Force
    Write-Host "[SUCCESS] All modules loaded successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to import modules: $($_.Exception.Message)"
    Write-Host "Please ensure all module files exist in the Modules directory." -ForegroundColor Red
    exit 1
}

# Debug mode flag
$DebugMode = $true

function Write-Debug-Info {
    param($Message, $Color = "Cyan")
    if ($DebugMode) {
        Write-Host "[DEBUG] $Message" -ForegroundColor $Color
    }
}

# Helper function to reset all variables for restart
function Reset-AllVariablesForRestart {
    # Clear all variables that could persist from previous run
    $Global:token = $null
    $Global:seriesInfo = $null
    $Global:episodes = $null
    $Global:operations = @()
    $Global:globalEnglishSeriesName = $null
    $Global:episodeVersionCounts = @{}
    $Global:videoFiles = @()
    $Global:specialFiles = @()
    $Global:regularFiles = @()
    
    Write-Debug-Info "All variables cleared for restart" "Green"
}

# Main execution starts here - FIXED authentication flow
do {
    $shouldRestart = $false
    Write-Header
    
    # Debug: Check Interactive parameter value
    Write-Host "[DEBUG] Interactive mode is: $Interactive" -ForegroundColor Magenta

    # Interactive mode - exact structure from original
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
                } else {
                    Write-Host "[ERROR] Please enter a valid positive number" -ForegroundColor Red
                }
            }
        }
    } else {
        # Non-interactive mode
        Write-Host ""
        Write-Host "[INFO] Authenticating with TheTVDB..." -ForegroundColor Cyan
        $token = Get-TheTVDBToken -ApiKey $ApiKey -Pin $Pin
        if (-not $token) {
            Write-Host "[ERROR] Cannot proceed without authentication. Exiting." -ForegroundColor Red
            exit 1
        }
        
        Write-Host "[INFO] Fetching series information for ID: $SeriesId..." -ForegroundColor Cyan
        $seriesInfo = Get-SeriesInfo -Token $token -SeriesId $SeriesId
        if (-not $seriesInfo) {
            Write-Host "[ERROR] Cannot retrieve series information for Series ID: $SeriesId" -ForegroundColor Red
            exit 1
        }
    }
    
    # Interactive-only prompts
    if ($Interactive) {
        # Show series info and ask for confirmation
        $confirmed = Confirm-SeriesSelection -SeriesInfo $seriesInfo -SeriesId $SeriesId
        if ($confirmed -eq $null) {
            Write-Host "Exiting..." -ForegroundColor Yellow
            exit 0
        }
        if (-not $confirmed) {
            $SeriesId = 0
            continue
        }
        
        # Get working directory
        $WorkingDirectory = Get-WorkingDirectoryFromUser -CurrentDirectory $WorkingDirectory
        if (-not $WorkingDirectory) {
            Write-Host "Exiting..." -ForegroundColor Yellow
            exit 0
        }
        
        # Choose operation type
        $renameOnly = Get-OperationTypeFromUser
        if ($renameOnly -eq $null) {
            Write-Host "Exiting..." -ForegroundColor Yellow
            exit 0
        }
    } else {
        # Non-interactive defaults
        $renameOnly = $false
    }

    Write-Host "[SUCCESS] Series: $($seriesInfo.name)" -ForegroundColor Green
    Write-Host "[SUCCESS] Status: $($seriesInfo.status.name)" -ForegroundColor Green

    # Get all episodes
    Write-Debug-Info "Fetching episode list for series"
    $episodes = Get-SeriesEpisodes -Token $token -SeriesId $SeriesId
    if ($episodes.Count -eq 0) {
        Write-Host "[ERROR] No episodes found for this series." -ForegroundColor Red
        Write-Debug-Info "No episodes found for series ID: $SeriesId" "Red"
        
        if ($Interactive) {
            $choice = Show-RestartOptions -Context "No Episodes"
            if ($choice -eq "quit") { 
                Write-Host "Goodbye!" -ForegroundColor Yellow
                exit 1 
            }
            if ($choice -eq "restart") {
                $shouldRestart = $true
                Reset-AllVariablesForRestart
                $SeriesId = 0
                $WorkingDirectory = (Get-Location).Path
                continue
            }
        } else {
            exit 1
        }
    }

    Write-Host "[SUCCESS] Found $($episodes.Count) episodes across all seasons" -ForegroundColor Green

    # Store the English series name from API for consistent use
    $globalEnglishSeriesName = $seriesInfo.name
    Write-Debug-Info "Stored global English series name: '$globalEnglishSeriesName'"

    # If the series name seems to be missing the main title, use Series ID as fallback
    if ([string]::IsNullOrWhiteSpace($globalEnglishSeriesName)) {
        Write-Host "[WARNING] API returned empty series name. Using Series ID as fallback." -ForegroundColor Yellow
        $globalEnglishSeriesName = "Series-$SeriesId"
    }

    # Find video files
    Write-Debug-Info "Scanning for video files in: $WorkingDirectory"
    $videoFiles = Find-VideoFiles -Directory $WorkingDirectory
    if ($videoFiles.Count -eq 0) {
        if ($Interactive) {
            $choice = Show-RestartOptions -Context "No Files Found"
            if ($choice -eq "quit") { 
                Write-Host "Goodbye!" -ForegroundColor Yellow
                exit 1 
            }
            if ($choice -eq "restart") {
                $shouldRestart = $true
                Reset-AllVariablesForRestart
                $SeriesId = 0
                $WorkingDirectory = (Get-Location).Path
                continue
            }
        } else {
            exit 1
        }
    }

    # Parse filenames and match with episodes - EXACT LOGIC FROM ORIGINAL
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
            $folderFileCount = ($specialFiles | Where-Object { (Split-Path $_.FullName.Replace($WorkingDirectory, "").TrimStart("\") -Parent) -eq $folder }).Count
            Write-Host "  - $folder ($folderFileCount files)" -ForegroundColor Gray
        }
        Write-Host "[INFO] All special content will be consolidated into a single Specials folder with sequential numbering" -ForegroundColor Green
    }

    # Initialize episode version tracking
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
                
                $safeSeriesName = Get-SafeFileName -FileName $globalEnglishSeriesName
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
                
                $newFileName = Get-SpecialFileName -SeriesName $safeSeriesName -EpisodeNumber $parsedFile.EpisodeNumber -EpisodeTitle $episodeTitle -FileExtension $file.Extension -VersionSuffix $versionSuffix
                
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
                
                $newFileName = Get-SpecialFileName -SeriesName $safeSeriesName -EpisodeNumber $specialEpisodeCounter -EpisodeTitle $file.BaseName -FileExtension $file.Extension -VersionSuffix $versionSuffix
                
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
        
        $safeSeriesName = Get-SafeFileName -FileName $globalEnglishSeriesName
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
        
        $newFileName = Get-EpisodeFileName -SeriesName $safeSeriesName -SeasonNumber $detectedSeason -EpisodeNumber $parsedFile.EpisodeNumber -EpisodeTitle $episodeTitle -FileExtension $file.Extension -VersionSuffix $versionSuffix
        
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
        
        if ($Interactive) {
            $choice = Show-RestartOptions -Context "No Matches"
            if ($choice -eq "quit") { 
                Write-Host "Goodbye!" -ForegroundColor Yellow
                exit 1 
            }
            if ($choice -eq "restart") {
                $shouldRestart = $true
                Reset-AllVariablesForRestart
                $SeriesId = 0
                $WorkingDirectory = (Get-Location).Path
                continue
            }
        } else {
            exit 1
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
                # Create operation log after successful execution
                if ($operations.Count -gt 0) {
                    Write-OperationLog -Operations $operations -WorkingDirectory $WorkingDirectory -SeriesName $globalEnglishSeriesName
                }
                # Always offer folder renaming, regardless of file operation success
                $WorkingDirectory = Rename-SeriesFolder -WorkingDirectory $WorkingDirectory -SeriesId $SeriesId -EnglishSeriesName $globalEnglishSeriesName
            }
            "cancel" {
                Write-Host "[CANCELLED] Operation cancelled by user." -ForegroundColor Yellow
                Write-Debug-Info "User cancelled the operation"
                
                $choice = Show-RestartOptions -Context "User Cancelled"
                if ($choice -eq "quit") { 
                    Write-Host "Goodbye!" -ForegroundColor Yellow
                    exit 0 
                }
                if ($choice -eq "restart") {
                    $shouldRestart = $true
                    Reset-AllVariablesForRestart
                    $SeriesId = 0
                    $WorkingDirectory = (Get-Location).Path
                    continue
                }
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
                Reset-AllVariablesForRestart
                $SeriesId = 0
                $WorkingDirectory = (Get-Location).Path
            }
        }
    } else {
        Write-Debug-Info "Running in non-interactive mode, proceeding with operations"
        $result = Execute-FileOperations -Operations $operations -WorkingDirectory $WorkingDirectory
        # Create operation log after execution in non-interactive mode
        if ($operations.Count -gt 0) {
            Write-OperationLog -Operations $operations -WorkingDirectory $WorkingDirectory -SeriesName $globalEnglishSeriesName
        }
        if ($result) {
            Write-Host "All operations completed successfully in non-interactive mode." -ForegroundColor Green
            # Note: Folder renaming skipped in non-interactive mode
            Write-Host "[INFO] Folder renaming skipped in non-interactive mode. Use interactive mode for folder renaming." -ForegroundColor Yellow
        } else {
            Write-Host "Some operations failed in non-interactive mode." -ForegroundColor Red
        }
    }

    if (-not $shouldRestart) {
        if ($Interactive) {
            $choice = Show-CompletionOptions
            if ($choice -eq "restart") {
                $shouldRestart = $true
                Reset-AllVariablesForRestart
                $SeriesId = 0
                $WorkingDirectory = (Get-Location).Path
            } else {
                Write-Host "Goodbye!" -ForegroundColor Yellow
            }
        }
    }

} while ($shouldRestart)