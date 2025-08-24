# NamingConvention.Tests.ps1
# Test script for the naming convention module

Write-Host "===== NAMING CONVENTION MODULE TESTS =====" -ForegroundColor Cyan

# Import the module
$ModulePath = Join-Path $PSScriptRoot "..\Modules\AnimeOrganizer.NamingConvention.psm1"
Import-Module $ModulePath -Force

Write-Host "Module imported successfully" -ForegroundColor Green

# Test 1: Import naming convention
Write-Host "`nTEST 1: Import naming convention" -ForegroundColor Yellow
try {
    $convention = Import-NamingConvention
    Write-Host "✓ Convention imported: $($convention.series_format)" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import convention: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Basic name formatting
Write-Host "`nTEST 2: Basic name formatting" -ForegroundColor Yellow
try {
    $seriesInfo = @{ name = "Test Series" }
    $episodeInfo = @{ name = "Test Episode Title" }
    
    $testName = Format-SeriesEpisodeName `
        -SeriesInfo $seriesInfo `
        -SeasonNumber 1 `
        -EpisodeNumber 5 `
        -EpisodeInfo $episodeInfo `
        -FileExtension ".mkv"
    
    Write-Host "Generated name: $testName" -ForegroundColor White
    $expected = "Test.Series.S01E05.Test.Episode.Title.mkv"
    
    if ($testName -eq $expected) {
        Write-Host "✓ Basic naming works correctly" -ForegroundColor Green
    } else {
        Write-Host "✗ Expected: $expected" -ForegroundColor Red
        Write-Host "✗ Got: $testName" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Basic naming failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Safe filename generation
Write-Host "`nTEST 3: Safe filename generation" -ForegroundColor Yellow
try {
    $unsafeName = "Series: Name With Spaces/And\\Invalid|Chars?<>*.mkv"
    $safeName = Get-SafeFileName -FileName $unsafeName
    
    Write-Host "Unsafe name: $unsafeName" -ForegroundColor White
    Write-Host "Safe name: $safeName" -ForegroundColor White
    
    # Should have no spaces, replaced invalid chars
    if ($safeName -notmatch '\s' -and $safeName -notmatch '[:/\\|?<>*]') {
        Write-Host "✓ Safe filename generation works correctly" -ForegroundColor Green
    } else {
        Write-Host "✗ Safe filename still contains invalid characters" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Safe filename generation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Template expansion
Write-Host "`nTEST 4: Template expansion" -ForegroundColor Yellow
try {
    $template = "{series}.S{season:D2}E{episode:D2}.{title}"
    $variables = @{
        series = "My.Series"
        season = 1
        episode = 5
        title = "Episode.Title"
    }
    
    $expanded = Expand-NamingTemplate -Template $template -Variables $variables
    $expected = "My.Series.S01E05.Episode.Title"
    
    Write-Host "Expanded template: $expanded" -ForegroundColor White
    
    if ($expanded -eq $expected) {
        Write-Host "✓ Template expansion works correctly" -ForegroundColor Green
    } else {
        Write-Host "✗ Expected: $expected" -ForegroundColor Red
        Write-Host "✗ Got: $expanded" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Template expansion failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n===== NAMING CONVENTION TESTS COMPLETE =====" -ForegroundColor Cyan
Write-Host "Phase 1 testing finished. Check results above." -ForegroundColor White