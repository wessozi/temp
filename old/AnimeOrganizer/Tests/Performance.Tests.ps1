# Performance.Tests.ps1 - Performance Improvement Tests
# Phase 3: Enhanced Features - Performance Testing

Write-Host "=======================================================================" -ForegroundColor Yellow
Write-Host "                    Performance Improvement Tests                     " -ForegroundColor Yellow
Write-Host "=======================================================================" -ForegroundColor Yellow
Write-Host ""

# Test 1: Module Import
Write-Host "[TEST 1] Testing module import..." -ForegroundColor Cyan
try {
    $ModulePath = Join-Path $PSScriptRoot "..\Modules\AnimeOrganizer.TheTVDB.psm1"
    Import-Module $ModulePath -Force
    Write-Host "[PASS] TheTVDB module imported successfully" -ForegroundColor Green
    $ImportTest = $true
} catch {
    Write-Host "[FAIL] Failed to import TheTVDB module: $($_.Exception.Message)" -ForegroundColor Red
    $ImportTest = $false
    exit 1
}

# Test 2: Authentication
Write-Host ""
Write-Host "[TEST 2] Testing authentication..." -ForegroundColor Cyan
try {
    $token = Get-TheTVDBToken
    if ($token) {
        Write-Host "[PASS] Authentication successful" -ForegroundColor Green
        $AuthTest = $true
    } else {
        Write-Host "[FAIL] Authentication failed" -ForegroundColor Red
        $AuthTest = $false
        exit 1
    }
} catch {
    Write-Host "[FAIL] Authentication error: $($_.Exception.Message)" -ForegroundColor Red
    $AuthTest = $false
    exit 1
}

# Test 3: First API Call (Should be slow)
Write-Host ""
Write-Host "[TEST 3] Testing first API call (should be slow)..." -ForegroundColor Cyan
try {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $seriesInfo = Get-SeriesInfo -Token $token -SeriesId 452826
    $stopwatch.Stop()
    
    if ($seriesInfo) {
        Write-Host "[PASS] First API call completed in $($stopwatch.Elapsed.TotalMilliseconds)ms" -ForegroundColor Green
        $firstCallTime = $stopwatch.Elapsed.TotalMilliseconds
        $FirstCallTest = $true
    } else {
        Write-Host "[FAIL] First API call failed" -ForegroundColor Red
        $FirstCallTest = $false
    }
} catch {
    Write-Host "[FAIL] First API call error: $($_.Exception.Message)" -ForegroundColor Red
    $FirstCallTest = $false
}

# Test 4: Second API Call (Should be fast from cache)
Write-Host ""
Write-Host "[TEST 4] Testing second API call (should be fast from cache)..." -ForegroundColor Cyan
try {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $seriesInfo = Get-SeriesInfo -Token $token -SeriesId 452826
    $stopwatch.Stop()
    
    if ($seriesInfo) {
        Write-Host "[PASS] Second API call completed in $($stopwatch.Elapsed.TotalMilliseconds)ms" -ForegroundColor Green
        $secondCallTime = $stopwatch.Elapsed.TotalMilliseconds
        $SecondCallTest = $true
        
        # Check if caching provided significant speedup
        if ($secondCallTime -lt ($firstCallTime * 0.1)) {  # At least 10x faster
            Write-Host "[PASS] Caching provided significant performance improvement (>10x faster)" -ForegroundColor Green
            $SpeedupTest = $true
        } else {
            Write-Host "[WARNING] Caching speedup less than expected (second call: ${secondCallTime}ms, first call: ${firstCallTime}ms)" -ForegroundColor Yellow
            $SpeedupTest = $false
        }
    } else {
        Write-Host "[FAIL] Second API call failed" -ForegroundColor Red
        $SecondCallTest = $false
        $SpeedupTest = $false
    }
} catch {
    Write-Host "[FAIL] Second API call error: $($_.Exception.Message)" -ForegroundColor Red
    $SecondCallTest = $false
    $SpeedupTest = $false
}

# Test 5: Cache Clearing
Write-Host ""
Write-Host "[TEST 5] Testing cache clearing..." -ForegroundColor Cyan
try {
    Clear-Cache -CacheType "all"
    Write-Host "[PASS] Cache cleared successfully" -ForegroundColor Green
    $ClearTest = $true
} catch {
    Write-Host "[FAIL] Cache clearing error: $($_.Exception.Message)" -ForegroundColor Red
    $ClearTest = $false
}

# Test 6: Episodes Caching
Write-Host ""
Write-Host "[TEST 6] Testing episodes caching..." -ForegroundColor Cyan
try {
    # First call (should be slow)
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $episodes = Get-SeriesEpisodes -Token $token -SeriesId 452826
    $stopwatch.Stop()
    $firstEpisodesTime = $stopwatch.Elapsed.TotalMilliseconds
    
    # Second call (should be fast)
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $episodes = Get-SeriesEpisodes -Token $token -SeriesId 452826
    $stopwatch.Stop()
    $secondEpisodesTime = $stopwatch.Elapsed.TotalMilliseconds
    
    if ($episodes.Count -gt 0) {
        Write-Host "[PASS] Episodes caching working (first: ${firstEpisodesTime}ms, second: ${secondEpisodesTime}ms)" -ForegroundColor Green
        $EpisodesTest = $true
        
        if ($secondEpisodesTime -lt ($firstEpisodesTime * 0.1)) {
            Write-Host "[PASS] Episodes caching provided significant performance improvement" -ForegroundColor Green
            $EpisodesSpeedupTest = $true
        } else {
            Write-Host "[WARNING] Episodes caching speedup less than expected" -ForegroundColor Yellow
            $EpisodesSpeedupTest = $false
        }
    } else {
        Write-Host "[FAIL] No episodes retrieved" -ForegroundColor Red
        $EpisodesTest = $false
        $EpisodesSpeedupTest = $false
    }
} catch {
    Write-Host "[FAIL] Episodes caching test error: $($_.Exception.Message)" -ForegroundColor Red
    $EpisodesTest = $false
    $EpisodesSpeedupTest = $false
}

# Test Summary
Write-Host ""
Write-Host "=======================================================================" -ForegroundColor Yellow
Write-Host "                           TEST RESULTS                               " -ForegroundColor Yellow
Write-Host "=======================================================================" -ForegroundColor Yellow

$tests = @(
    @{Name = "Module Import"; Result = $ImportTest},
    @{Name = "Authentication"; Result = $AuthTest},
    @{Name = "First API Call"; Result = $FirstCallTest},
    @{Name = "Second API Call (Cache)"; Result = $SecondCallTest},
    @{Name = "Cache Speedup"; Result = $SpeedupTest},
    @{Name = "Cache Clearing"; Result = $ClearTest},
    @{Name = "Episodes Caching"; Result = $EpisodesTest},
    @{Name = "Episodes Speedup"; Result = $EpisodesSpeedupTest}
)

$PassCount = 0
$TotalTests = $tests.Count

foreach ($test in $tests) {
    $status = if ($test.Result) { "[PASS]" } else { "[FAIL]" }
    $color = if ($test.Result) { "Green" } else { "Red" }
    Write-Host "$($test.Name): $status" -ForegroundColor $color
    if ($test.Result) { $PassCount++ }
}

Write-Host ""
Write-Host "OVERALL: $PassCount/$TotalTests tests passed" -ForegroundColor $(if ($PassCount -eq $TotalTests) { 'Green' } else { 'Yellow' })

if ($PassCount -eq $TotalTests) {
    Write-Host "[SUCCESS] All performance tests passed! Caching is working correctly." -ForegroundColor Green
    exit 0
} else {
    Write-Host "[PARTIAL] Some performance tests failed. Review the results above." -ForegroundColor Yellow
    exit 1
}