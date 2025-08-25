# Test script to verify parsing functionality
Import-Module .\AnimeOrganizer\Modules\AnimeOrganizer.FileParser.psm1 -Force

$testFileName = "Please.Put.Them.On.Takamine-san.S01E11.v2.I'll.Let.You.Do.a.Dry.Run.mkv"

Write-Host "=== PARSING TEST ===" -ForegroundColor Green
Write-Host "Testing filename: $testFileName" -ForegroundColor Yellow
Write-Host ""

# Test basic patterns
Write-Host "Testing basic patterns..." -ForegroundColor Cyan
$basicResult = Test-BasicPatterns -FileName $testFileName
if ($basicResult) {
    Write-Host "Basic pattern matched: $($basicResult.DetectedPattern)" -ForegroundColor Green
    Write-Host "  Season: $($basicResult.SeasonNumber), Episode: $($basicResult.EpisodeNumber)" -ForegroundColor White
} else {
    Write-Host "No basic pattern matched" -ForegroundColor Yellow
}

Write-Host ""

# Test advanced patterns
Write-Host "Testing advanced patterns..." -ForegroundColor Cyan
$advancedResult = Test-AdvancedPatterns -FileName $testFileName
if ($advancedResult) {
    Write-Host "Advanced pattern matched: $($advancedResult.DetectedPattern)" -ForegroundColor Green
    Write-Host "  Season: $($advancedResult.SeasonNumber), Episode: $($advancedResult.EpisodeNumber)" -ForegroundColor White
} else {
    Write-Host "No advanced pattern matched" -ForegroundColor Red
}

Write-Host ""

# Test main parsing function
Write-Host "Testing main Parse-EpisodeNumber function..." -ForegroundColor Cyan
$parseResult = Parse-EpisodeNumber -FileName $testFileName
if ($parseResult) {
    Write-Host "Parse successful: $($parseResult.DetectedPattern)" -ForegroundColor Green
    Write-Host "  Season: $($parseResult.SeasonNumber), Episode: $($parseResult.EpisodeNumber)" -ForegroundColor White
} else {
    Write-Host "Parse failed" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== TEST COMPLETED ===" -ForegroundColor Green