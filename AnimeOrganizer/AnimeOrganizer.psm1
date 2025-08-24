# AnimeOrganizer.psm1 - Main Module Manifest
# Modular PowerShell-based Anime File Organizer
# Refactored from the original single-file Anime-File-Organizer.ps1

# Import configuration functions
$script:ModuleRoot = $PSScriptRoot

function Get-AnimeOrganizerPath {
    param([string]$SubPath)
    return Join-Path $script:ModuleRoot $SubPath
}

# Load configuration
function Get-AnimeOrganizerConfig {
    $configPath = Get-AnimeOrganizerPath "Config\settings.json"
    if (Test-Path $configPath) {
        return Get-Content $configPath | ConvertFrom-Json
    } else {
        Write-Warning "Configuration file not found at: $configPath"
        return $null
    }
}

# Import Logging module first
$LoggingModulePath = Get-AnimeOrganizerPath "Modules\AnimeOrganizer.Logging.psm1"
if (Test-Path $LoggingModulePath) {
    Import-Module $LoggingModulePath -Force
    Initialize-Logging -LogLevel "INFO" -LogToFile $true
    Write-InfoLog "Logging module loaded successfully" -Category "ModuleLoad"
} else {
    Write-Warning "Logging module not found at: $LoggingModulePath"
}

# Import TheTVDB module
$TheTVDBModulePath = Get-AnimeOrganizerPath "Modules\AnimeOrganizer.TheTVDB.psm1"
if (Test-Path $TheTVDBModulePath) {
    Import-Module $TheTVDBModulePath -Force
    Write-InfoLog "TheTVDB module loaded successfully" -Category "ModuleLoad"
} else {
    Write-Warning "TheTVDB module not found at: $TheTVDBModulePath"
}

# Import FileParser module
$FileParserModulePath = Get-AnimeOrganizerPath "Modules\AnimeOrganizer.FileParser.psm1"
if (Test-Path $FileParserModulePath) {
    Import-Module $FileParserModulePath -Force
    Write-InfoLog "FileParser module loaded successfully" -Category "ModuleLoad"
} else {
    Write-Warning "FileParser module not found at: $FileParserModulePath"
}

# Import ErrorHandling module
$ErrorHandlingModulePath = Get-AnimeOrganizerPath "Modules\AnimeOrganizer.ErrorHandling.psm1"
if (Test-Path $ErrorHandlingModulePath) {
    Import-Module $ErrorHandlingModulePath -Force
    $config = Get-AnimeOrganizerConfig
    $enableRollback = if ($config -and $config.behavior.enable_rollback) { $config.behavior.enable_rollback } else { $false }
    Initialize-ErrorHandling -MaxRetryAttempts 3 -RetryDelayMs 1000 -EnableRollback $enableRollback
    Write-InfoLog "ErrorHandling module loaded successfully" -Category "ModuleLoad"
} else {
    Write-Warning "ErrorHandling module not found at: $ErrorHandlingModulePath"
}

# Import FileOperations module
$FileOperationsModulePath = Get-AnimeOrganizerPath "Modules\AnimeOrganizer.FileOperations.psm1"
if (Test-Path $FileOperationsModulePath) {
    Import-Module $FileOperationsModulePath -Force
    Write-InfoLog "FileOperations module loaded successfully" -Category "ModuleLoad"
} else {
    Write-Warning "FileOperations module not found at: $FileOperationsModulePath"
}

# Import UserInterface module
$UserInterfaceModulePath = Get-AnimeOrganizerPath "Modules\AnimeOrganizer.UserInterface.psm1"
if (Test-Path $UserInterfaceModulePath) {
    Import-Module $UserInterfaceModulePath -Force
    Write-InfoLog "UserInterface module loaded successfully" -Category "ModuleLoad"
} else {
    Write-Warning "UserInterface module not found at: $UserInterfaceModulePath"
}

# Main orchestration function - Full Interactive Workflow
function Start-AnimeOrganization {
    param(
        [Parameter(Mandatory=$false)]
        [string]$ApiKey = "",
        
        [Parameter(Mandatory=$false)]
        [string]$Pin = "",
        
        [Parameter(Mandatory=$false)]
        [string]$WorkingDirectory = (Get-Location).Path,
        
        [Parameter(Mandatory=$false)]
        [int]$SeriesId = 0,
        
        [Parameter(Mandatory=$false)]
        [switch]$Interactive = $true
    )
    
    # Load configuration
    $config = Get-AnimeOrganizerConfig
    if (-not $config) {
        Write-ErrorLog "Failed to load configuration. Cannot proceed." -Category "Configuration"
        return
    }
    
    # Use config API key if not provided
    if (-not $ApiKey) {
        $ApiKey = $config.api.tvdb_key
        Write-DebugLog "Using API key from configuration" -Category "API"
    }
    
    # Main workflow loop
    do {
        # Show header
        Write-Header
        
        try {
            # Get TheTVDB token
            $token = Measure-Performance "TheTVDB Authentication" -ScriptBlock {
                Get-TheTVDBToken -ApiKey $ApiKey -Pin $Pin
            } -Category "Performance"
            
            if (-not $token) {
                Write-Host "[ERROR] Failed to authenticate with TheTVDB. Check your API key." -ForegroundColor Red
                $restartChoice = Show-RestartOptions -Context "Authentication"
                if ($restartChoice -eq "quit") { return }
                continue
            }
            
            # Get Series ID from user if not provided
            if ($SeriesId -eq 0 -and $Interactive) {
                $SeriesId = Get-SeriesIdFromUser
                if (-not $SeriesId) { return }
            }
            
            # Get series information
            $seriesInfo = Measure-Performance "Series Info Retrieval" -ScriptBlock {
                Get-SeriesInfo -Token $token -SeriesId $SeriesId
            } -Category "Performance"
            
            if (-not $seriesInfo) {
                Write-Host "[ERROR] Could not retrieve series information for ID: $SeriesId" -ForegroundColor Red
                $restartChoice = Show-RestartOptions -Context "Series Info"
                if ($restartChoice -eq "quit") { return }
                $SeriesId = 0
                continue
            }
            
            # Verify series with user
            if ($Interactive) {
                $seriesConfirmed = Show-SeriesVerification -SeriesInfo $seriesInfo -SeriesId $SeriesId
                if ($seriesConfirmed -eq $null) { return }
                if (-not $seriesConfirmed) {
                    $SeriesId = 0
                    continue
                }
            }
            
            # Get working directory from user
            if ($Interactive) {
                $WorkingDirectory = Get-WorkingDirectoryFromUser -CurrentDirectory $WorkingDirectory
                if (-not $WorkingDirectory) { return }
            }
            
            # Get operation type from user
            if ($Interactive) {
                $renameOnly = Get-OperationTypeFromUser
                if ($renameOnly -eq $null) { return }
            } else {
                $renameOnly = $false
            }
            
            # Find video files
            $videoFiles = Find-VideoFiles -Directory $WorkingDirectory
            if ($videoFiles.Count -eq 0) {
                Write-Host "[ERROR] No video files found in directory" -ForegroundColor Red
                $restartChoice = Show-RestartOptions -Context "File Scan"
                if ($restartChoice -eq "quit") { return }
                continue
            }
            
            # Get episode information
            $episodes = Measure-Performance "Episode Info Retrieval" -ScriptBlock {
                Get-SeriesEpisodes -Token $token -SeriesId $SeriesId
            } -Category "Performance"
            
            if (-not $episodes -or $episodes.Count -eq 0) {
                Write-Host "[ERROR] Could not retrieve episode information" -ForegroundColor Red
                $restartChoice = Show-RestartOptions -Context "Episode Info"
                if ($restartChoice -eq "quit") { return }
                continue
            }
            
            # Parse files and create operations
            $operations = @()
            foreach ($file in $videoFiles) {
                $parseResult = Parse-EpisodeNumber -FileName $file.Name
                if ($parseResult -and $parseResult.EpisodeNumber -gt 0 -and $parseResult.EpisodeNumber -le $episodes.Count) {
                    $episodeNum = $parseResult.EpisodeNumber
                    $episode = $episodes[$episodeNum - 1]
                    $newFileName = Get-SafeFileName -FileName "$($seriesInfo.name).S01E$($episodeNum.ToString('00')).$($episode.name)$($file.Extension)"
                    
                    $operations += [PSCustomObject]@{
                        OriginalFile = $file.Name
                        SourcePath = $file.FullName
                        NewFileName = $newFileName
                        TargetFolder = if ($renameOnly) { "." } else { "Season 1" }
                        EpisodeNumber = $episodeNum
                        EpisodeName = $episode.name
                    }
                }
            }
            
            if ($operations.Count -eq 0) {
                Write-Host "[ERROR] No episodes could be matched to files" -ForegroundColor Red
                $restartChoice = Show-RestartOptions -Context "Episode Matching"
                if ($restartChoice -eq "quit") { return }
                continue
            }
            
            # Show preview
            Show-Preview -Operations $operations
            
            # Get user confirmation
            if ($Interactive) {
                $userChoice = Confirm-Operations
                switch ($userChoice) {
                    "proceed" {
                        # Log operations before executing
                        Write-OperationLog -Operations $operations -WorkingDirectory $WorkingDirectory -SeriesName $seriesInfo.name
                        
                        # Execute operations
                        $success = Execute-FileOperations -Operations $operations -WorkingDirectory $WorkingDirectory
                        
                        if ($success) {
                            # Offer folder rename for Hama compatibility
                            $WorkingDirectory = Rename-SeriesFolder -WorkingDirectory $WorkingDirectory -SeriesId $SeriesId -EnglishSeriesName $seriesInfo.name
                            
                            Write-Host ""
                            Write-Host "[COMPLETE] All operations completed successfully!" -ForegroundColor Green
                            Write-InfoLog "Anime organization completed successfully for: $($seriesInfo.name)" -Category "Complete"
                        }
                        return
                    }
                    "cancel" {
                        Write-Host "[INFO] Operations cancelled by user" -ForegroundColor Yellow
                        return
                    }
                    "quit" {
                        return
                    }
                    "restart" {
                        $SeriesId = 0
                        continue
                    }
                }
            } else {
                # Non-interactive mode: execute directly
                Write-OperationLog -Operations $operations -WorkingDirectory $WorkingDirectory -SeriesName $seriesInfo.name
                Execute-FileOperations -Operations $operations -WorkingDirectory $WorkingDirectory
                Rename-SeriesFolder -WorkingDirectory $WorkingDirectory -SeriesId $SeriesId -EnglishSeriesName $seriesInfo.name
                return
            }
        }
        catch {
            Write-ErrorLog "Error in main workflow: $($_.Exception.Message)" -Category "Workflow"
            Write-Host "[ERROR] An unexpected error occurred: $($_.Exception.Message)" -ForegroundColor Red
            
            $restartChoice = Show-RestartOptions -Context "Unexpected Error"
            if ($restartChoice -eq "quit") { return }
            $SeriesId = 0
        }
    } while ($Interactive)
}

# Export main functions
Export-ModuleMember -Function Start-AnimeOrganization, Get-AnimeOrganizerConfig

# Re-export TheTVDB functions for direct access
Export-ModuleMember -Function Get-TheTVDBToken, Get-SeriesInfo, Get-SeriesEpisodes, Clear-Cache

# Re-export FileParser functions for direct access
Export-ModuleMember -Function Test-IsRomanizedJapaneseName, Get-SafeFileName, Parse-EpisodeNumber

# Re-export Logging functions for direct access
Export-ModuleMember -Function Initialize-Logging, Write-DebugLog, Write-InfoLog, Write-WarningLog, Write-ErrorLog, Measure-Performance

# Re-export ErrorHandling functions for direct access
Export-ModuleMember -Function Initialize-ErrorHandling, Invoke-SafeOperation, Invoke-SafeFileOperation, Invoke-SafeApiCall, Invoke-RollbackOperations, Clear-OperationStack

# Re-export FileOperations functions for direct access
Export-ModuleMember -Function Find-VideoFiles, Execute-FileOperations, Write-OperationLog, Rename-SeriesFolder

# Re-export UserInterface functions for direct access
Export-ModuleMember -Function Write-Header, Show-Preview, Confirm-Operations, Get-SeriesIdFromUser, Get-WorkingDirectoryFromUser, Get-OperationTypeFromUser, Show-SeriesVerification, Show-RestartOptions