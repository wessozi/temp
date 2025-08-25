# AnimeOrganizer.StateAnalyzer.psm1
# Analyzes file states and categorizes them for intelligent processing

function Analyze-FileStates {
    param(
        [Parameter(Mandatory=$true)]
        [array]$VideoFiles,
        
        [Parameter(Mandatory=$true)]
        [array]$Episodes,
        
        [Parameter(Mandatory=$true)]
        [object]$SeriesInfo,
        
        [Parameter(Mandatory=$true)]
        [object]$NamingConvention,
        
        [Parameter(Mandatory=$false)]
        [string]$WorkingDirectory = "."
    )
    
    Write-Host "[ANALYSIS] Analyzing $($VideoFiles.Count) video files..." -ForegroundColor Cyan
    
    # Initialize result categories
    $analysis = @{
        skip = @()          # Files already correctly named
        rename = @()        # Files that need renaming
        duplicates = @{}    # Files with duplicate episodes
        specials = @()      # Special files (season 0)
    }
    
    # Check if TheTVDB has any official specials (season 0 episodes)
    $hasOfficialSpecials = $Episodes | Where-Object { $_.seasonNumber -eq 0 } | Measure-Object | Select-Object -ExpandProperty Count
    Write-Host "[ANALYSIS] TheTVDB has $hasOfficialSpecials official special episodes (season 0)" -ForegroundColor Cyan
    
    # Separate special files from regular files
    $specialFiles = @()
    $regularFiles = @()
    
    foreach ($file in $VideoFiles) {
        # Validate file object has a name
        if ([string]::IsNullOrEmpty($file.Name)) {
            Write-Warning "[ANALYSIS] Skipping file with empty name. Full path: $($file.FullName)"
            continue
        }
        
        $relativePath = $file.FullName.Replace($WorkingDirectory, "").TrimStart("\")
        $folderPath = Split-Path $relativePath -Parent
        
        # Check if file is in any special content folder (OVAs, OADs, Specials, Extras, Movies, etc.)
        if ($folderPath -match "(?i)(?:^|\\)(S\d+\s+)?(OVAs?|OADs?|Specials?|Extras?|Movies?)(?:$|\\)") {
            $specialFiles += $file
            Write-Host "[SPECIAL] Detected special content file: $relativePath (in folder: $folderPath)" -ForegroundColor Yellow
        } else {
            $regularFiles += $file
        }
    }
    
    Write-Host "[ANALYSIS] Found $($specialFiles.Count) special files and $($regularFiles.Count) regular files" -ForegroundColor Cyan
    
    # Process regular files
    if ($regularFiles.Count -gt 0) {
        # Group regular files by episode for duplicate detection
        $episodeGroups = Group-FilesByEpisode -VideoFiles $regularFiles -Episodes $Episodes -SeriesInfo $SeriesInfo -NamingConvention $NamingConvention
        
        # Process each episode group
        foreach ($episodeNum in $episodeGroups.Keys) {
            $filesInEpisode = $episodeGroups[$episodeNum]
            
            if ($filesInEpisode.Count -eq 1) {
                # Single file for this episode - check if already correct
                $fileData = $filesInEpisode[0]
                
                if (Test-FileAlreadyCorrect -FileData $fileData) {
                    $analysis.skip += $fileData
                } else {
                    $analysis.rename += $fileData
                }
            } else {
                # Multiple files for same episode - duplicates
                $analysis.duplicates[$episodeNum] = $filesInEpisode
            }
        }
    }
    
    # Process special files (will be handled by specials processing logic)
    if ($specialFiles.Count -gt 0) {
        $analysis.specials = $specialFiles
        Write-Host "[SPECIAL] $($specialFiles.Count) special files will be processed separately" -ForegroundColor Yellow
    }
    
    # Log analysis results
    Write-Host "[ANALYSIS] Results:" -ForegroundColor Green
    Write-Host "  Already correct: $($analysis.skip.Count)" -ForegroundColor Green
    Write-Host "  Need renaming: $($analysis.rename.Count)" -ForegroundColor Yellow
    Write-Host "  Duplicate episodes: $($analysis.duplicates.Keys.Count)" -ForegroundColor Red
    Write-Host "  Special files: $($analysis.specials.Count)" -ForegroundColor Magenta
    
    return $analysis
}

function Group-FilesByEpisode {
    param(
        [Parameter(Mandatory=$true)]
        [array]$VideoFiles,
        
        [Parameter(Mandatory=$true)]
        [array]$Episodes,
        
        [Parameter(Mandatory=$true)]
        [object]$SeriesInfo,
        
        [Parameter(Mandatory=$true)]
        [object]$NamingConvention
    )
    
    $episodeGroups = @{}
    
    foreach ($file in $VideoFiles) {
        # Validate file object has a name
        if ([string]::IsNullOrEmpty($file.Name)) {
            Write-Warning "[ANALYSIS] Skipping file with empty name. Full path: $($file.FullName)"
            continue
        }
        
        # Parse episode number from filename
        $parseResult = Parse-EpisodeNumber -FileName $file.Name
        
        if ($parseResult -and $parseResult.EpisodeNumber -gt 0) {
            $episodeNum = $parseResult.EpisodeNumber
            $episode = $Episodes | Where-Object { $_.number -eq $episodeNum -and $_.seasonNumber -eq $parseResult.SeasonNumber } | Select-Object -First 1
            
            if (-not $episode) {
                Write-Warning "[ANALYSIS] No episode found for Season $($parseResult.SeasonNumber) Episode $episodeNum"
                continue
            }
            
            # Generate target filename for this file
            $targetName = Format-SeriesEpisodeName -SeriesInfo $SeriesInfo -SeasonNumber $parseResult.SeasonNumber -EpisodeNumber $episodeNum -EpisodeInfo $episode -FileExtension $file.Extension -Convention $NamingConvention
            
            # Create file data object with analysis info
            $fileData = [PSCustomObject]@{
                File = $file
                OriginalName = $file.Name
                SourcePath = $file.FullName
                TargetName = $targetName
                EpisodeNumber = $episodeNum
                EpisodeInfo = $episode
                IsCorrect = (Normalize-FileName $file.Name) -eq (Normalize-FileName $targetName)
            }
            
            # Add to episode group
            if (-not $episodeGroups.ContainsKey($episodeNum)) {
                $episodeGroups[$episodeNum] = @()
            }
            $episodeGroups[$episodeNum] += $fileData
        } else {
            Write-Warning "[ANALYSIS] Could not parse episode number from: '$($file.Name)' (Parse result: $(if ($parseResult) { 'Success' } else { 'Failed' }))"
            if ($parseResult) {
                Write-Warning "[ANALYSIS] Parse result - Season: $($parseResult.SeasonNumber), Episode: $($parseResult.EpisodeNumber), Episodes count: $($Episodes.Count)"
            }
        }
    }
    
    return $episodeGroups
}

function Test-FileAlreadyCorrect {
    param(
        [Parameter(Mandatory=$true)]
        [object]$FileData
    )
    
    return $FileData.IsCorrect
}

function Build-RenameOperations {
    param(
        [Parameter(Mandatory=$true)]
        [array]$FilesToRename
    )
    
    $operations = @()
    
    foreach ($fileData in $FilesToRename) {
        $operation = [PSCustomObject]@{
            OriginalFile = $fileData.OriginalName
            SourcePath = $fileData.SourcePath
            NewFileName = $fileData.TargetName
            TargetFolder = "."
            OperationType = "Rename"
            EpisodeNumber = $fileData.EpisodeNumber
            EpisodeInfo = $fileData.EpisodeInfo
        }
        
        $operations += $operation
    }
    
    return $operations
}

function Get-AnalysisStatistics {
    param(
        [Parameter(Mandatory=$true)]
        [object]$Analysis
    )
    
    $duplicateFileCount = 0
    foreach ($episodeFiles in $Analysis.duplicates.Values) {
        $duplicateFileCount += $episodeFiles.Count
    }
    
    $stats = @{
        total_files = $Analysis.skip.Count + $Analysis.rename.Count + $duplicateFileCount + $Analysis.specials.Count
        already_correct = $Analysis.skip.Count
        need_renaming = $Analysis.rename.Count
        duplicate_episodes = $Analysis.duplicates.Keys.Count
        duplicate_files = $duplicateFileCount
        special_files = $Analysis.specials.Count
    }
    
    return $stats
}

# Simple placeholder for episode parsing - will be replaced by real implementation
function Parse-EpisodeNumber {
    param([string]$FileName)
    
    # Basic patterns to detect episode numbers
    if ($FileName -match 'S\d+E(\d+)') {
        return @{ EpisodeNumber = [int]$matches[1] }
    }
    if ($FileName -match '\.(\d{1,2})\.') {
        return @{ EpisodeNumber = [int]$matches[1] }
    }
    if ($FileName -match '-(\d{1,2})-') {
        return @{ EpisodeNumber = [int]$matches[1] }
    }
    
    return $null
}

function Normalize-FileName {
    param([string]$FileName)
    
    # Normalize by replacing spaces with dots for comparison
    # This allows files with spaces to be considered equivalent to files with dots
    $normalized = $FileName -replace '\s+', '.'
    
    # Also remove any version suffixes for comparison
    $normalized = $normalized -replace '\.v\d+', ''
    
    return $normalized
}

# Export functions
Export-ModuleMember -Function Analyze-FileStates, Group-FilesByEpisode, Test-FileAlreadyCorrect, Build-RenameOperations, Get-AnalysisStatistics, Normalize-FileName