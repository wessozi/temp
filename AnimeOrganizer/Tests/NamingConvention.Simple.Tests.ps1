# Simple test for naming convention module
Write-Host "Testing Naming Convention Module" -ForegroundColor Cyan

# Import the module
$ModulePath = Join-Path $PSScriptRoot "..\Modules\AnimeOrganizer.NamingConvention.psm1"
Import-Module $ModulePath -Force
Write-Host "Module imported" -ForegroundColor Green

# Test 1: Import convention
$convention = Import-NamingConvention
Write-Host "Convention: $($convention.series_format)" -ForegroundColor White

# Test 2: Basic naming
$seriesInfo = @{ name = "Test Series" }
$episodeInfo = @{ name = "Test Episode" }

$testName = Format-SeriesEpisodeName -SeriesInfo $seriesInfo -SeasonNumber 1 -EpisodeNumber 1 -EpisodeInfo $episodeInfo -FileExtension ".mkv"
Write-Host "Generated name: $testName" -ForegroundColor White

# Test 3: Safe filename
$safeName = Get-SafeFileName -FileName "Test: Series With Spaces"
Write-Host "Safe name: $safeName" -ForegroundColor White

Write-Host "Simple tests complete" -ForegroundColor Green