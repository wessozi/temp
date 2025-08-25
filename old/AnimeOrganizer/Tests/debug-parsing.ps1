# Debug script to test episode parsing
Import-Module .\AnimeOrganizer\Modules\AnimeOrganizer.FileParser.psm1 -Force

$testFileName = "World's End Harem - S01E01 - World of Women.mkv"

Write-Host "=== PARSING DEBUG ===" -ForegroundColor Green
Write-Host "Testing filename: $testFileName" -ForegroundColor Yellow

# Enable debug mode
$config = Get-AnimeOrganizerConfig
$config.parsing.debug_mode = $true

# Test basic patterns
Write-Host ""
Write-Host "Testing basic patterns..." -ForegroundColor Cyan
$basicResult = Test-BasicPatterns -FileName $testFileName
if ($basicResult) {
    Write-Host "Basic pattern matched: $($basicResult.DetectedPattern)" -ForegroundColor Green
    Write-Host "  Season: $($basicResult.SeasonNumber), Episode: $($basicResult.EpisodeNumber)" -ForegroundColor White
} else {
    Write-Host "No basic pattern matched" -ForegroundColor Yellow
}

# Test advanced patterns
Write-Host ""
Write-Host "Testing advanced patterns..." -ForegroundColor Cyan
$advancedResult = Test-AdvancedPatterns -FileName $testFileName
if ($advancedResult) {
    Write-Host "Advanced pattern matched: $($advancedResult.DetectedPattern)" -ForegroundColor Green
    Write-Host "  Season: $($advancedResult.SeasonNumber), Episode: $($advancedResult.EpisodeNumber)" -ForegroundColor White
} else {
    Write-Host "No advanced pattern matched" -ForegroundColor Red
}

# Test main parsing function
Write-Host ""
Write-Host "Testing main Parse-EpisodeNumber function..." -ForegroundColor Cyan
$parseResult = Parse-EpisodeNumber -FileName $testFileName
if ($parseResult) {
    Write-Host "Parse successful: $($parseResult.DetectedPattern)" -ForegroundColor Green
    Write-Host "  Season: $($parseResult.SeasonNumber), Episode: $($parseResult.EpisodeNumber)" -ForegroundColor White
} else {
    Write-Host "Parse failed" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== DEBUG COMPLETED ===" -ForegroundColor Green