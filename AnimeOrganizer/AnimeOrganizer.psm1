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
    Initialize-ErrorHandling -MaxRetryAttempts 3 -RetryDelayMs 1000 -EnableRollback $true
    Write-InfoLog "ErrorHandling module loaded successfully" -Category "ModuleLoad"
} else {
    Write-Warning "ErrorHandling module not found at: $ErrorHandlingModulePath"
}

# TODO: Import other modules as they are created
# Import-Module (Get-AnimeOrganizerPath "Modules\AnimeOrganizer.FileOperations.psm1") -Force
# Import-Module (Get-AnimeOrganizerPath "Modules\AnimeOrganizer.UserInterface.psm1") -Force

# Main orchestration function (placeholder for future implementation)
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
    
    Write-InfoLog "=======================================================================" -Category "UI"
    Write-InfoLog "                 Universal Anime File Organizer (Modular)            " -Category "UI"
    Write-InfoLog "                        Using TheTVDB API (Free)                     " -Category "UI"
    Write-InfoLog "=======================================================================" -Category "UI"
    Write-InfoLog "" -Category "UI"
    
    # Load configuration
    $config = Get-AnimeOrganizerConfig
    if (-not $config) {
        Write-ErrorLog "Failed to load configuration. Cannot proceed." -Category "Configuration"
        return
    }
    
    # Test TheTVDB module functionality
    Write-InfoLog "Testing TheTVDB module..." -Category "API"
    
    try {
        # Use config API key if not provided
        if (-not $ApiKey) {
            $ApiKey = $config.api.tvdb_key
            Write-DebugLog "Using API key from configuration" -Category "API"
        }
        
        $token = Measure-Performance "TheTVDB Authentication" -ScriptBlock {
            Get-TheTVDBToken -ApiKey $ApiKey -Pin $Pin
        } -Category "Performance"
        
        if ($token) {
            Write-InfoLog "TheTVDB module is working correctly!" -Category "API"
            
            # Test with a sample series ID if provided
            if ($SeriesId -gt 0) {
                Write-InfoLog "Testing with Series ID: $SeriesId" -Category "API"
                $seriesInfo = Measure-Performance "Series Info Retrieval" -ScriptBlock {
                    Get-SeriesInfo -Token $token -SeriesId $SeriesId
                } -Category "Performance"
                
                if ($seriesInfo) {
                    Write-InfoLog "Retrieved series: $($seriesInfo.name)" -Category "API"
                } else {
                    Write-WarningLog "Failed to retrieve series information for ID: $SeriesId" -Category "API"
                }
            }
        } else {
            Write-ErrorLog "Failed to authenticate with TheTVDB. Check your API key." -Category "API"
        }
    }
    catch {
        Write-ErrorLog "Error testing TheTVDB module: $($_.Exception.Message)" -Category "API"
    }
    
    Write-InfoLog "" -Category "UI"
    Write-InfoLog "Modular version is currently in development." -Category "Info"
    Write-InfoLog "Use the original Anime-File-Organizer.ps1 for full functionality." -Category "Info"
    Write-InfoLog "This modular version currently demonstrates TheTVDB API functionality." -Category "Info"
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