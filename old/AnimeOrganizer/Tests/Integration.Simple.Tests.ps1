# Simple integration test for all modules working together
Write-Host "===== INTEGRATION TEST =====" -ForegroundColor Cyan

# Test that all modules can be loaded together
$ModulesPath = Join-Path $PSScriptRoot "..\Modules"

try {
    Import-Module (Join-Path $ModulesPath "AnimeOrganizer.NamingConvention.psm1") -Force
    Write-Host "✓ NamingConvention module loaded" -ForegroundColor Green
    
    Import-Module (Join-Path $ModulesPath "AnimeOrganizer.VersionManager.psm1") -Force
    Write-Host "✓ VersionManager module loaded" -ForegroundColor Green
    
    Import-Module (Join-Path $ModulesPath "AnimeOrganizer.StateAnalyzer.psm1") -Force
    Write-Host "✓ StateAnalyzer module loaded" -ForegroundColor Green
    
    Write-Host "`nALL MODULES LOADED SUCCESSFULLY" -ForegroundColor Green
    
    # Test basic functionality
    $convention = Import-NamingConvention
    Write-Host "✓ Can import naming convention" -ForegroundColor Green
    
    $versionConfig = Get-VersioningConfig
    Write-Host "✓ Can get versioning config" -ForegroundColor Green
    
    # Test naming
    $testName = Format-SeriesEpisodeName -SeriesInfo @{name="Test"} -SeasonNumber 1 -EpisodeNumber 1 -EpisodeInfo @{name="Episode"} -FileExtension ".mkv"
    Write-Host "✓ Generated name: $testName" -ForegroundColor Green
    
    Write-Host "`nINTEGRATION TEST PASSED" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Integration test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "===== INTEGRATION TEST COMPLETE =====" -ForegroundColor Cyan