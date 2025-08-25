 ½/!&=()/½ &#=(!"/# Debug script to test episode parsing
Import-Module .\AnimeOrganizer\Modules\AnimeOrganizer.FileParser.psm1 -Force

$testFileName = "World's End Harem - S01E01 - World of Women.mkv"

Write-Host "=== PARSING DEBUG ===" -ForegroundColor Green
Write-Host "Testing filename: $testFileName" -ForegroundColor Yellow

# Test main parsing function
$parseResult = Parse-EpisodeNumber -FileName $testFileName
if ($parseResult) {
    Write-Host "Parse successful: $($parseResult.DetectedPattern)" -ForegroundColor Green
    Write-Host "  Season: $($parseResult.SeasonNumber)" -ForegroundColor White
    Write-Host "  Episode: $($parseResult.EpisodeNumber)" -ForegroundColor White
} else {
    Write-Host "Parse failed" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== DEBUG COMPLETED ===" -ForegroundColor Green