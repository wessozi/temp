# Simple test for state analyzer module
Write-Host "Testing State Analyzer Module" -ForegroundColor Cyan

# Import modules
$NamingModulePath = Join-Path $PSScriptRoot "..\Modules\AnimeOrganizer.NamingConvention.psm1"
$StateModulePath = Join-Path $PSScriptRoot "..\Modules\AnimeOrganizer.StateAnalyzer.psm1"

Import-Module $NamingModulePath -Force
Import-Module $StateModulePath -Force
Write-Host "Modules imported" -ForegroundColor Green

# Mock data
$mockSeriesInfo = @{ name = "Test Series" }
$mockEpisodes = @(
    @{ name = "Episode 1 Title" },
    @{ name = "Episode 2 Title" }
)

$mockVideoFiles = @(
    [PSCustomObject]@{ 
        Name = "Test.Series.S01E01.Episode.1.Title.mkv"
        BaseName = "Test.Series.S01E01.Episode.1.Title"
        Extension = ".mkv"
        FullName = "C:\test\Test.Series.S01E01.Episode.1.Title.mkv"
    },
    [PSCustomObject]@{ 
        Name = "Original Name - 02 - Some Title.mkv"
        BaseName = "Original Name - 02 - Some Title"
        Extension = ".mkv"
        FullName = "C:\test\Original Name - 02 - Some Title.mkv"
    }
)

$convention = Import-NamingConvention

# Test file grouping
$episodeGroups = Group-FilesByEpisode -VideoFiles $mockVideoFiles -Episodes $mockEpisodes -SeriesInfo $mockSeriesInfo -NamingConvention $convention
Write-Host "Episode groups: $($episodeGroups.Keys.Count)" -ForegroundColor White

# Test analysis
$analysis = Analyze-FileStates -VideoFiles $mockVideoFiles -Episodes $mockEpisodes -SeriesInfo $mockSeriesInfo -NamingConvention $convention

Write-Host "Analysis complete" -ForegroundColor Green
Write-Host "  Skip: $($analysis.skip.Count)" -ForegroundColor Green
Write-Host "  Rename: $($analysis.rename.Count)" -ForegroundColor Yellow
Write-Host "  Duplicates: $($analysis.duplicates.Keys.Count)" -ForegroundColor Red

Write-Host "Simple test complete" -ForegroundColor Green