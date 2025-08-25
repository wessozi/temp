# Organize-Anime.ps1 - Modular Anime File Organizer Entry Point
# Simplified entry script using modular architecture
# Original: 1,397 lines | This version: ~50 lines

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
    [switch]$Interactive = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$RunTests = $false
)

# Import the main AnimeOrganizer module
$ModulePath = Join-Path $PSScriptRoot "AnimeOrganizer\AnimeOrganizer.psm1"

try {
    Import-Module $ModulePath -Force
    Write-Host "[SUCCESS] AnimeOrganizer module loaded successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to import AnimeOrganizer module: $($_.Exception.Message)"
    Write-Host "Please ensure the module files are in the correct locations." -ForegroundColor Red
    exit 1
}

# Run tests if requested
if ($RunTests) {
    Write-Host ""
    Write-Host "[INFO] Running module tests..." -ForegroundColor Yellow
    $TestScript = Join-Path $PSScriptRoot "AnimeOrganizer\Tests\TheTVDB.Tests.ps1"
    if (Test-Path $TestScript) {
        & $TestScript
        
        # Also run FileParser tests
        Write-Host ""
        $FileParserTestScript = Join-Path $PSScriptRoot "AnimeOrganizer\Tests\FileParser.Simple.Tests.ps1"
        if (Test-Path $FileParserTestScript) {
            Write-Host "[INFO] Running FileParser tests..." -ForegroundColor Yellow
            & $FileParserTestScript
        }
        
        Write-Host ""
        Write-Host "[INFO] All tests completed. Use -Interactive to run the organizer." -ForegroundColor Yellow
        exit 0
    } else {
        Write-Warning "Test script not found: $TestScript"
        exit 1
    }
}

# Start the anime organization process
try {
    Start-AnimeOrganization -ApiKey $ApiKey -Pin $Pin -WorkingDirectory $WorkingDirectory -SeriesId $SeriesId -Interactive:$Interactive
}
catch {
    Write-Error "Error during anime organization: $($_.Exception.Message)"
    exit 1
}

Write-Host ""
Write-Host "=======================================================================" -ForegroundColor Cyan
Write-Host "                       MODULAR VERSION INFO                           " -ForegroundColor Cyan
Write-Host "=======================================================================" -ForegroundColor Cyan
Write-Host "This is the modular version of the Anime File Organizer." -ForegroundColor Yellow
Write-Host ""
Write-Host "Current Status:" -ForegroundColor Cyan
Write-Host "  ✅ Directory structure created" -ForegroundColor Green
Write-Host "  ✅ Configuration externalized" -ForegroundColor Green  
Write-Host "  ✅ TheTVDB API module extracted and tested" -ForegroundColor Green
Write-Host "  ✅ FileParser module extracted and tested" -ForegroundColor Green
Write-Host "  ⏳ File operations module (Phase 3)" -ForegroundColor Yellow
Write-Host "  ⏳ User interface module (Phase 3)" -ForegroundColor Yellow
Write-Host "  ⏳ Full integration (Phase 3)" -ForegroundColor Yellow
Write-Host ""
Write-Host "To test all functionality:" -ForegroundColor Cyan
Write-Host "  .\Organize-Anime.ps1 -RunTests" -ForegroundColor White
Write-Host ""
Write-Host "To test with a specific series:" -ForegroundColor Cyan
Write-Host "  .\Organize-Anime.ps1 -SeriesId 452826" -ForegroundColor White
Write-Host ""
Write-Host "For full functionality, use the original script:" -ForegroundColor Cyan
Write-Host "  .\Anime-File-Organizer.ps1" -ForegroundColor White
Write-Host ""
do {
    Write-Host ""
    Write-Host "Would you like to:" -ForegroundColor Cyan
    Write-Host "  [R] Restart the organizer" -ForegroundColor White
    Write-Host "  [Q] Quit" -ForegroundColor White
    Write-Host ""
    $choice = Read-Host "Choose (R/Q)"
    
    switch ($choice.ToUpper()) {
        'R' {
            Write-Host "Restarting..." -ForegroundColor Green
            Write-Host ""
            try {
                Start-AnimeOrganization -ApiKey $ApiKey -Pin $Pin -WorkingDirectory $WorkingDirectory -SeriesId $SeriesId -Interactive:$Interactive
            }
            catch {
                Write-Error "Error during anime organization: $($_.Exception.Message)"
            }
        }
        'Q' {
            Write-Host "Goodbye!" -ForegroundColor Green
            break
        }
        default {
            Write-Host "Invalid choice. Please select R or Q." -ForegroundColor Red
        }
    }
} while ($choice.ToUpper() -ne 'Q')