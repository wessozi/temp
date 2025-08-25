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

# Import NamingConvention module
$NamingConventionModulePath = Get-AnimeOrganizerPath "Modules\AnimeOrganizer.NamingConvention.psm1"
if (Test-Path $NamingConventionModulePath) {
    Import-Module $NamingConventionModulePath -Force
    Write-InfoLog "NamingConvention module loaded successfully" -Category "ModuleLoad"
} else {
    Write-Warning "NamingConvention module not found at: $NamingConventionModulePath"
}

# Import StateAnalyzer module
$StateAnalyzerModulePath = Get-AnimeOrganizerPath "Modules\AnimeOrganizer.StateAnalyzer.psm1"
if (Test-Path $StateAnalyzerModulePath) {
    Import-Module $StateAnalyzerModulePath -Force
    Write-InfoLog "StateAnalyzer module loaded successfully" -Category "ModuleLoad"
} else {
    Write-Warning "StateAnalyzer module not found at: $StateAnalyzerModulePath"
}

# Import VersionManager module
$VersionManagerModulePath = Get-AnimeOrganizerPath "Modules\AnimeOrganizer.VersionManager.psm1"
if (Test-Path $VersionManagerModulePath) {
    Import-Module $VersionManagerModulePath -Force
    Write-InfoLog "VersionManager module loaded successfully" -Category "ModuleLoad"
} else {
    Write-Warning "VersionManager module not found at: $VersionManagerModulePath"
}

# Import PlanManager module
$PlanManagerModulePath = Get-AnimeOrganizerPath "Modules\AnimeOrganizer.PlanManager.psm1"
if (Test-Path $PlanManagerModulePath) {
    Import-Module $PlanManagerModulePath -Force
    Write-InfoLog "PlanManager module loaded successfully" -Category "ModuleLoad"
} else {
    Write-Warning "PlanManager module not found at: $PlanManagerModulePath"
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
            
            # NEW MODULAR SYSTEM: Import naming convention and build comprehensive plan
            Write-InfoLog "Using new modular naming and versioning system" -Category "ModularSystem"
            
            # Import naming convention
            $namingConvention = Import-NamingConvention
            Write-DebugLog "Imported naming convention: $($namingConvention.series_format)" -Category "NamingConvention"
            
            # Analyze file states and create comprehensive plan
            $fileAnalysis = Analyze-FileStates -VideoFiles $videoFiles -Episodes $episodes -SeriesInfo $seriesInfo -NamingConvention $namingConvention -WorkingDirectory $WorkingDirectory
            
            # Build operations from analysis
            $operations = @()
            
            # Add skip operations (files already correct)
            foreach ($fileData in $fileAnalysis.skip) {
                Write-DebugLog "Skipping already correct file: $($fileData.OriginalName)" -Category "Skip"
            }
            
            # Add rename operations (normal files needing rename)
            if ($fileAnalysis.rename.Count -gt 0) {
                $renameOps = Build-RenameOperations -FilesToRename $fileAnalysis.rename
                foreach ($op in $renameOps) {
                    $operations += [PSCustomObject]@{
                        OriginalFile = $op.OriginalFile
                        SourcePath = $op.SourcePath
                        NewFileName = $op.NewFileName
                        TargetFolder = if ($renameOnly) { "." } else { "Season 01" }
                        EpisodeNumber = $op.EpisodeNumber
                        EpisodeName = $op.EpisodeInfo.name
                        OperationType = "Rename"
                    }
                }
            }
            
            # Add versioning operations (duplicate episodes)
            if ($fileAnalysis.duplicates.Keys.Count -gt 0) {
                Write-InfoLog "Processing $($fileAnalysis.duplicates.Keys.Count) episodes with duplicates using versioning system" -Category "Versioning"
                
                $versioningConfig = Get-VersioningConfig
                $versionOps = Enter-VersioningMode -DuplicateGroups $fileAnalysis.duplicates -Mode $versioningConfig.mode -SeriesInfo $seriesInfo -Episodes $episodes -NamingConvention $namingConvention
                
                foreach ($op in $versionOps) {
                    $operations += [PSCustomObject]@{
                        OriginalFile = $op.OriginalFile
                        SourcePath = if ($op.SourcePath) { $op.SourcePath } else { $op.OriginalFile }
                        NewFileName = $op.NewFileName
                        TargetFolder = if ($renameOnly) { "." } else { "Season 01" }
                        EpisodeNumber = $op.EpisodeNumber
                        EpisodeName = if ($op.EpisodeInfo) { $op.EpisodeInfo.name } else { "Episode $($op.EpisodeNumber)" }
                        OperationType = $op.OperationType
                    }
                }
            }
            
            # Add specials processing (season 0 files)
            if ($fileAnalysis.specials.Count -gt 0) {
                Write-InfoLog "Processing $($fileAnalysis.specials.Count) special files" -Category "Specials"
                
                # For now, add special files as skip operations (they need special handling)
                foreach ($specialFile in $fileAnalysis.specials) {
                    $operations += [PSCustomObject]@{
                        OriginalFile = $specialFile.Name
                        SourcePath = $specialFile.FullName
                        NewFileName = $specialFile.Name  # Keep original name for now
                        TargetFolder = "Specials"
                        EpisodeNumber = 0
                        EpisodeName = "Special Content"
                        OperationType = "Special"
                    }
                }
            }
            
            # Create comprehensive plan using the new PlanManager
            Write-InfoLog "Creating comprehensive operation plan" -Category "Planning"
            $comprehensivePlan = Build-CompletePlan -VideoFiles $videoFiles -Episodes $episodes -SeriesInfo $seriesInfo -NamingConvention $namingConvention
            
            # Log analysis results
            $stats = Get-AnalysisStatistics -Analysis $fileAnalysis
            Write-InfoLog "File Analysis Complete - Total: $($stats.total_files), Skip: $($stats.already_correct), Rename: $($stats.need_renaming), Duplicates: $($stats.duplicate_episodes), Specials: $($stats.special_files)" -Category "Analysis"
            
            # Show enhanced preview using new PlanManager (regardless of operation count)
            Show-OperationPreview -Plan $comprehensivePlan
            
            # Check if no operations are needed (all files already correct)
            if ($operations.Count -eq 0) {
                Write-Host ""
                Write-Host "[SUCCESS] All files are already correctly named! No changes needed." -ForegroundColor Green
                Write-Host ""
                $restartChoice = Show-RestartOptions -Context "All Files Correct"
                if ($restartChoice -eq "quit") { return }
                continue
            }
            
            # Get user confirmation with enhanced interface
            if ($Interactive) {
                # Show plan summary
                $planSummary = Get-PlanSummary -Plan $comprehensivePlan
                Write-Host "`n[SUMMARY] $planSummary" -ForegroundColor Cyan
                
                $userChoice = Confirm-Operations
                switch ($userChoice) {
                    "proceed" {
                        Write-Host "`n[EXECUTION] Starting operations..." -ForegroundColor Cyan
                        
                        # Log operations before executing
                        Write-OperationLog -Operations $operations -WorkingDirectory $WorkingDirectory -SeriesName $seriesInfo.name
                        
                        # Execute operations using new plan structure
                        $success = Execute-FileOperations -Operations $operations -WorkingDirectory $WorkingDirectory
                        
                        if ($success) {
                            # Offer folder rename for Hama compatibility
                            $WorkingDirectory = Rename-SeriesFolder -WorkingDirectory $WorkingDirectory -SeriesId $SeriesId -EnglishSeriesName $seriesInfo.name
                            
                            Write-Host ""
                            Write-Host "[COMPLETE] All operations completed successfully!" -ForegroundColor Green
                            Write-InfoLog "Anime organization completed successfully for: $($seriesInfo.name)" -Category "Complete"
                            
                            # Offer restart after successful completion
                            Write-Host ""
                            Write-Host "Would you like to organize another series?" -ForegroundColor Cyan
                            Write-Host "[R] Restart with new series"
                            Write-Host "[Q] Quit"
                            
                            do {
                                $restartChoice = Read-Host "Enter your choice (R/Q)"
                                switch ($restartChoice.ToUpper()) {
                                    "R" {
                                        Write-Host "[INFO] Restarting for new series..." -ForegroundColor Yellow
                                        $SeriesId = 0
                                        break
                                    }
                                    "Q" {
                                        Write-Host "[INFO] Exiting application. Thank you!" -ForegroundColor Green
                                        return
                                    }
                                    default {
                                        Write-Host "[ERROR] Invalid choice. Please enter R or Q" -ForegroundColor Red
                                    }
                                }
                            } while ($restartChoice.ToUpper() -ne "R" -and $restartChoice.ToUpper() -ne "Q")
                        } else {
                            return
                        }
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
Export-ModuleMember -Function Test-IsRomanizedJapaneseName, Get-SafeFileName, Parse-EpisodeNumber, Get-SeasonFromFolderPath

# Re-export Logging functions for direct access
Export-ModuleMember -Function Initialize-Logging, Write-DebugLog, Write-InfoLog, Write-WarningLog, Write-ErrorLog, Measure-Performance

# Re-export ErrorHandling functions for direct access
Export-ModuleMember -Function Initialize-ErrorHandling, Invoke-SafeOperation, Invoke-SafeFileOperation, Invoke-SafeApiCall, Invoke-RollbackOperations, Clear-OperationStack

# Re-export FileOperations functions for direct access
Export-ModuleMember -Function Find-VideoFiles, Execute-FileOperations, Write-OperationLog, Rename-SeriesFolder

# Re-export UserInterface functions for direct access
Export-ModuleMember -Function Write-Header, Show-Preview, Confirm-Operations, Get-SeriesIdFromUser, Get-WorkingDirectoryFromUser, Get-OperationTypeFromUser, Show-SeriesVerification, Show-RestartOptions

# Re-export NamingConvention functions for direct access
Export-ModuleMember -Function Import-NamingConvention, Format-SeriesEpisodeName, Format-VersionedName, Get-SafeFileName, Expand-NamingTemplate

# Re-export StateAnalyzer functions for direct access
Export-ModuleMember -Function Analyze-FileStates, Group-FilesByEpisode, Test-FileAlreadyCorrect, Build-RenameOperations, Get-AnalysisStatistics

# Re-export VersionManager functions for direct access
Export-ModuleMember -Function Detect-DuplicateEpisodes, Enter-VersioningMode, Apply-TemporaryVersioning, Apply-DirectVersioning, Apply-FinalVersioning, Get-VersioningConfig

# Re-export PlanManager functions for direct access
Export-ModuleMember -Function Build-CompletePlan, Show-OperationPreview, Execute-OperationPlan, Get-PlanSummary