# Test script to verify specials detection
Import-Module .\AnimeOrganizer\AnimeOrganizer.psm1 -Force

# Create test file objects that simulate special content
$testFiles = @(
    [PSCustomObject]@{
        Name = "OVA 01.mkv"
        FullName = "Z:\Media\NSFW\Haite Kudasai, Takamine-san [tvdb-452826]\Specials\OVA 01.mkv"
        Extension = ".mkv"
        BaseName = "OVA 01"
        Length = 1024MB
    },
    [PSCustomObject]@{
        Name = "Please.Put.Them.On.Takamine-san.S01E11.v2.I'll.Let.You.Do.a.Dry.Run.mkv"
        FullName = "Z:\Media\NSFW\Haite Kudasai, Takamine-san [tvdb-452826]\Season 01\Please.Put.Them.On.Takamine-san.S01E11.v2.I'll.Let.You.Do.a.Dry.Run.mkv"
        Extension = ".mkv"
        BaseName = "Please.Put.Them.On.Takamine-san.S01E11.v2.I'll.Let.You.Do.a.Dry.Run"
        Length = 1024MB
    },
    [PSCustomObject]@{
        Name = "Special Episode.mkv"
        FullName = "Z:\Media\NSFW\Haite Kudasai, Takamine-san [tvdb-452826]\Extras\Special Episode.mkv"
        Extension = ".mkv"
        BaseName = "Special Episode"
        Length = 1024MB
    }
)

# Mock series info and episodes for testing
$seriesInfo = [PSCustomObject]@{
    name = "Please Put Them On, Takamine-san"
    id = 452826
    year = 2024
}

$episodes = @(
    [PSCustomObject]@{
        number = 11
        name = "I'll Let You Do a Dry Run"
        seasonNumber = 1
    },
    [PSCustomObject]@{
        number = 1
        name = "OVA Special"
        seasonNumber = 0
    }
)

# Import naming convention
$namingConvention = Import-NamingConvention

Write-Host "=== SPECIALS DETECTION TEST ===" -ForegroundColor Green
Write-Host "Testing special content folder detection" -ForegroundColor Yellow
Write-Host ""

# Test specials detection
$analysis = Analyze-FileStates -VideoFiles $testFiles -Episodes $episodes -SeriesInfo $seriesInfo -NamingConvention $namingConvention -WorkingDirectory "Z:\Media\NSFW\Haite Kudasai, Takamine-san [tvdb-452826]"

Write-Host "Analysis Results:" -ForegroundColor Cyan
Write-Host "  Regular files: $($analysis.rename.Count + $analysis.skip.Count)" -ForegroundColor White
Write-Host "  Special files: $($analysis.specials.Count)" -ForegroundColor Magenta
Write-Host "  Duplicates: $($analysis.duplicates.Keys.Count)" -ForegroundColor Red

if ($analysis.specials.Count -gt 0) {
    Write-Host "Detected special files:" -ForegroundColor Yellow
    foreach ($special in $analysis.specials) {
        Write-Host "  - $($special.Name)" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "=== TEST COMPLETED ===" -ForegroundColor Green