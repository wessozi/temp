# StateAnalyzer.Tests.ps1
# Test script for the state analyzer module

Write-Host "===== STATE ANALYZER MODULE TESTS =====" -ForegroundColor Cyan

# Import modules
$NamingModulePath = Join-Path $PSScriptRoot "..\Modules\AnimeOrganizer.NamingConvention.psm1"
$StateModulePath = Join-Path $PSScriptRoot "..\Modules\AnimeOrganizer.StateAnalyzer.psm1"

Import-Module $NamingModulePath -Force
Import-Module $StateModulePath -Force

Write-Host "Modules imported successfully" -ForegroundColor Green

# Test 1: File state analysis setup
Write-Host "`nTEST 1: File state analysis setup" -ForegroundColor Yellow

# Mock series and episode data
$mockSeriesInfo = @{ name = "Test Series" }
$mockEpisodes = @(
    @{ name = "Episode 1 Title" },
    @{ name = "Episode 2 Title" },
    @{ name = "Episode 3 Title" }
)

# Mock video files - mix of correct, incorrect, and duplicates
$mockVideoFiles = @(
    # Already correct file
    [PSCustomObject]@{ 
        Name = "Test.Series.S01E01.Episode.1.Title.mkv"
        BaseName = "Test.Series.S01E01.Episode.1.Title"
        Extension = ".mkv"
        FullName = "C:\test\Test.Series.S01E01.Episode.1.Title.mkv"
    },
    # File needing rename
    [PSCustomObject]@{ 
        Name = "Original Name - 02 - Some Title.mkv"
        BaseName = "Original Name - 02 - Some Title"
        Extension = ".mkv"
        FullName = "C:\test\Original Name - 02 - Some Title.mkv"
    },
    # Duplicate files for episode 3
    [PSCustomObject]@{ 
        Name = "Episode.3.Version.A.mkv"
        BaseName = "Episode.3.Version.A"
        Extension = ".mkv"
        FullName = "C:\test\Episode.3.Version.A.mkv"
    },
    [PSCustomObject]@{ 
        Name = "Episode.3.Version.B.mkv"
        BaseName = "Episode.3.Version.B"
        Extension = ".mkv"
        FullName = "C:\test\Episode.3.Version.B.mkv"
    }
)

$convention = Import-NamingConvention
Write-Host "Mock data created: $($mockVideoFiles.Count) files, $($mockEpisodes.Count) episodes" -ForegroundColor White

# Test 2: File grouping by episode
Write-Host "`nTEST 2: File grouping by episode" -ForegroundColor Yellow
$episodeGroups = Group-FilesByEpisode -VideoFiles $mockVideoFiles -Episodes $mockEpisodes -SeriesInfo $mockSeriesInfo -NamingConvention $convention

Write-Host "Episode groups created:" -ForegroundColor White
foreach ($episodeNum in $episodeGroups.Keys) {
    $files = $episodeGroups[$episodeNum]
    Write-Host "  Episode ${episodeNum}: $($files.Count) files" -ForegroundColor White
    foreach ($fileData in $files) {
        $status = if ($fileData.IsCorrect) { "[CORRECT]" } else { "[NEEDS RENAME]" }
        Write-Host "    $status $($fileData.OriginalName)" -ForegroundColor White
    }
}

# Test 3: Full analysis
Write-Host "`nTEST 3: Full file state analysis" -ForegroundColor Yellow
$analysis = Analyze-FileStates -VideoFiles $mockVideoFiles -Episodes $mockEpisodes -SeriesInfo $mockSeriesInfo -NamingConvention $convention

Write-Host "Analysis results:" -ForegroundColor White
Write-Host "  Skip: $($analysis.skip.Count) files" -ForegroundColor Green
Write-Host "  Rename: $($analysis.rename.Count) files" -ForegroundColor Yellow  
Write-Host "  Duplicates: $($analysis.duplicates.Keys.Count) episodes" -ForegroundColor Red

# Test 4: Analysis preview
Write-Host "`nTEST 4: Analysis preview display" -ForegroundColor Yellow
Show-AnalysisPreview -Analysis $analysis

# Test 5: Statistics and integrity
Write-Host "`nTEST 5: Statistics and integrity check" -ForegroundColor Yellow
$stats = Get-AnalysisStatistics -Analysis $analysis
Write-Host "Statistics:" -ForegroundColor White
Write-Host "  Total files: $($stats.total_files)" -ForegroundColor White
Write-Host "  Already correct: $($stats.already_correct)" -ForegroundColor Green
Write-Host "  Need renaming: $($stats.need_renaming)" -ForegroundColor Yellow
Write-Host "  Duplicate episodes: $($stats.duplicate_episodes)" -ForegroundColor Red
Write-Host "  Duplicate files: $($stats.duplicate_files)" -ForegroundColor Red

$integrityCheck = Test-AnalysisIntegrity -Analysis $analysis -OriginalFileCount $mockVideoFiles.Count
if ($integrityCheck) {
    Write-Host "✓ Integrity check passed" -ForegroundColor Green
} else {
    Write-Host "✗ Integrity check failed" -ForegroundColor Red
}

# Test 6: Operation building
Write-Host "`nTEST 6: Building rename operations" -ForegroundColor Yellow
$renameOps = Build-RenameOperations -FilesToRename $analysis.rename -NamingConvention $convention

Write-Host "Rename operations:" -ForegroundColor White
foreach ($op in $renameOps) {
    Write-Host "  $($op.OriginalFile) -> $($op.NewFileName)" -ForegroundColor White
}

Write-Host "`n===== STATE ANALYZER TESTS COMPLETE =====" -ForegroundColor Cyan
Write-Host "Phase 3 testing finished. Check results above." -ForegroundColor White