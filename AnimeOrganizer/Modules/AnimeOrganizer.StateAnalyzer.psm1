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
        [object]$NamingConvention
    )
    
    Write-Host "[ANALYSIS] Analyzing $($VideoFiles.Count) video files..." -ForegroundColor Cyan
    
    # Initialize result categories
    $analysis = @{
        skip = @()          # Files already correctly named
        rename = @()        # Files that need renaming
        duplicates = @{}    # Files with duplicate episodes
    }
    
    # Group files by episode for duplicate detection
    $episodeGroups = Group-FilesByEpisode -VideoFiles $VideoFiles -Episodes $Episodes -SeriesInfo $SeriesInfo -NamingConvention $NamingConvention
    
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
    
    # Log analysis results
    Write-Host "[ANALYSIS] Results:" -ForegroundColor Green
    Write-Host "  Already correct: $($analysis.skip.Count)" -ForegroundColor Green
    Write-Host "  Need renaming: $($analysis.rename.Count)" -ForegroundColor Yellow
    Write-Host "  Duplicate episodes: $($analysis.duplicates.Keys.Count)" -ForegroundColor Red
    
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
        # Parse episode number from filename
        $parseResult = Parse-EpisodeNumber -FileName $file.Name
        
        if ($parseResult -and $parseResult.EpisodeNumber -gt 0 -and $parseResult.EpisodeNumber -le $Episodes.Count) {
            $episodeNum = $parseResult.EpisodeNumber
            $episode = $Episodes[$episodeNum - 1]
            
            # Generate target filename for this file
            $targetName = Format-SeriesEpisodeName -SeriesInfo $SeriesInfo -SeasonNumber 1 -EpisodeNumber $episodeNum -EpisodeInfo $episode -FileExtension $file.Extension -Convention $NamingConvention
            
            # Create file data object with analysis info
            $fileData = [PSCustomObject]@{
                File = $file
                OriginalName = $file.Name
                SourcePath = $file.FullName
                TargetName = $targetName
                EpisodeNumber = $episodeNum
                EpisodeInfo = $episode
                IsCorrect = ($file.Name -eq $targetName)
            }
            
            # Add to episode group
            if (-not $episodeGroups.ContainsKey($episodeNum)) {
                $episodeGroups[$episodeNum] = @()
            }
            $episodeGroups[$episodeNum] += $fileData
        } else {
            Write-Warning "[ANALYSIS] Could not parse episode number from: $($file.Name)"
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
        total_files = $Analysis.skip.Count + $Analysis.rename.Count + $duplicateFileCount
        already_correct = $Analysis.skip.Count
        need_renaming = $Analysis.rename.Count
        duplicate_episodes = $Analysis.duplicates.Keys.Count
        duplicate_files = $duplicateFileCount
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

# Export functions
Export-ModuleMember -Function Analyze-FileStates, Group-FilesByEpisode, Test-FileAlreadyCorrect, Build-RenameOperations, Get-AnalysisStatistics