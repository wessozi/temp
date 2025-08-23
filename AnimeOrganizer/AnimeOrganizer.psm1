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

# Import TheTVDB module
$TheTVDBModulePath = Get-AnimeOrganizerPath "Modules\AnimeOrganizer.TheTVDB.psm1"
if (Test-Path $TheTVDBModulePath) {
    Import-Module $TheTVDBModulePath -Force
    Write-Host "[MODULE] TheTVDB module loaded successfully" -ForegroundColor Green
} else {
    Write-Warning "TheTVDB module not found at: $TheTVDBModulePath"
}

# Import FileParser module
$FileParserModulePath = Get-AnimeOrganizerPath "Modules\AnimeOrganizer.FileParser.psm1"
if (Test-Path $FileParserModulePath) {
    Import-Module $FileParserModulePath -Force
    Write-Host "[MODULE] FileParser module loaded successfully" -ForegroundColor Green
} else {
    Write-Warning "FileParser module not found at: $FileParserModulePath"
}

# TODO: Import other modules as they are created
# Import-Module (Get-AnimeOrganizerPath "Modules\AnimeOrganizer.FileOperations.psm1") -Force
# Import-Module (Get-AnimeOrganizerPath "Modules\AnimeOrganizer.UserInterface.psm1") -Force
# Import-Module (Get-AnimeOrganizerPath "Modules\AnimeOrganizer.Logging.psm1") -Force

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
    
    Write-Host "=======================================================================" -ForegroundColor Cyan
    Write-Host "                 Universal Anime File Organizer (Modular)            " -ForegroundColor Cyan  
    Write-Host "                        Using TheTVDB API (Free)                     " -ForegroundColor Cyan
    Write-Host "=======================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Load configuration
    $config = Get-AnimeOrganizerConfig
    if (-not $config) {
        Write-Error "Failed to load configuration. Cannot proceed."
        return
    }
    
    # Test TheTVDB module functionality
    Write-Host "[INFO] Testing TheTVDB module..." -ForegroundColor Yellow
    
    try {
        # Use config API key if not provided
        if (-not $ApiKey) {
            $ApiKey = $config.api.tvdb_key
        }
        
        $token = Get-TheTVDBToken -ApiKey $ApiKey -Pin $Pin
        if ($token) {
            Write-Host "[SUCCESS] TheTVDB module is working correctly!" -ForegroundColor Green
            
            # Test with a sample series ID if provided
            if ($SeriesId -gt 0) {
                Write-Host "[INFO] Testing with Series ID: $SeriesId" -ForegroundColor Yellow
                $seriesInfo = Get-SeriesInfo -Token $token -SeriesId $SeriesId
                if ($seriesInfo) {
                    Write-Host "[SUCCESS] Retrieved series: $($seriesInfo.name)" -ForegroundColor Green
                } else {
                    Write-Warning "Failed to retrieve series information for ID: $SeriesId"
                }
            }
        } else {
            Write-Error "Failed to authenticate with TheTVDB. Check your API key."
        }
    }
    catch {
        Write-Error "Error testing TheTVDB module: $($_.Exception.Message)"
    }
    
    Write-Host ""
    Write-Host "[INFO] Modular version is currently in development." -ForegroundColor Yellow
    Write-Host "[INFO] Use the original Anime-File-Organizer.ps1 for full functionality." -ForegroundColor Yellow
    Write-Host "[INFO] This modular version currently demonstrates TheTVDB API functionality." -ForegroundColor Yellow
}

# Export main functions
Export-ModuleMember -Function Start-AnimeOrganization, Get-AnimeOrganizerConfig

# Re-export TheTVDB functions for direct access
Export-ModuleMember -Function Get-TheTVDBToken, Get-SeriesInfo, Get-SeriesEpisodes

# Re-export FileParser functions for direct access
Export-ModuleMember -Function Test-IsRomanizedJapaneseName, Get-SafeFileName, Parse-EpisodeNumber