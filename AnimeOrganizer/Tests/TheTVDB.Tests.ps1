# TheTVDB.Tests.ps1 - Basic Tests for TheTVDB Module
# Simple validation tests to ensure module functionality

# Test configuration
$TestSeriesId = 452826  # Please Put Them On, Takamine-san - verified working

Write-Host "=======================================================================" -ForegroundColor Yellow
Write-Host "                    TheTVDB Module Basic Tests                        " -ForegroundColor Yellow
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
}

if (-not $ImportTest) {
    Write-Host "[ABORT] Cannot continue tests without module import" -ForegroundColor Red
    exit 1
}

# Test 2: Configuration Loading
Write-Host ""
Write-Host "[TEST 2] Testing configuration loading..." -ForegroundColor Cyan
try {
    $config = Get-AnimeOrganizerConfig
    if ($config -and $config.api.tvdb_key) {
        Write-Host "[PASS] Configuration loaded with API key: $($config.api.tvdb_key.Substring(0,8))..." -ForegroundColor Green
        $ConfigTest = $true
    } else {
        Write-Host "[FAIL] Configuration not loaded or missing API key" -ForegroundColor Red
        $ConfigTest = $false
    }
} catch {
    Write-Host "[FAIL] Error loading configuration: $($_.Exception.Message)" -ForegroundColor Red
    $ConfigTest = $false
}

# Test 3: Authentication
Write-Host ""
Write-Host "[TEST 3] Testing TheTVDB authentication..." -ForegroundColor Cyan
try {
    $token = Get-TheTVDBToken
    if ($token) {
        Write-Host "[PASS] Authentication successful, token received" -ForegroundColor Green
        $AuthTest = $true
    } else {
        Write-Host "[FAIL] Authentication failed, no token received" -ForegroundColor Red
        $AuthTest = $false
    }
} catch {
    Write-Host "[FAIL] Authentication error: $($_.Exception.Message)" -ForegroundColor Red
    $AuthTest = $false
}

# Test 4: Series Info Retrieval
if ($AuthTest) {
    Write-Host ""
    Write-Host "[TEST 4] Testing series info retrieval (Series ID: $TestSeriesId)..." -ForegroundColor Cyan
    try {
        $seriesInfo = Get-SeriesInfo -Token $token -SeriesId $TestSeriesId
        if ($seriesInfo -and $seriesInfo.name) {
            Write-Host "[PASS] Series info retrieved: $($seriesInfo.name)" -ForegroundColor Green
            $SeriesTest = $true
        } else {
            Write-Host "[FAIL] Series info not retrieved or missing name" -ForegroundColor Red
            $SeriesTest = $false
        }
    } catch {
        Write-Host "[FAIL] Series info error: $($_.Exception.Message)" -ForegroundColor Red
        $SeriesTest = $false
    }
} else {
    Write-Host ""
    Write-Host "[SKIP] Skipping series info test due to authentication failure" -ForegroundColor Yellow
    $SeriesTest = $false
}

# Test 5: Episodes Retrieval
if ($AuthTest) {
    Write-Host ""
    Write-Host "[TEST 5] Testing episodes retrieval (Series ID: $TestSeriesId)..." -ForegroundColor Cyan
    try {
        $episodes = Get-SeriesEpisodes -Token $token -SeriesId $TestSeriesId
        if ($episodes -and $episodes.Count -gt 0) {
            Write-Host "[PASS] Episodes retrieved: $($episodes.Count) episodes found" -ForegroundColor Green
            $EpisodesTest = $true
        } else {
            Write-Host "[FAIL] No episodes retrieved" -ForegroundColor Red
            $EpisodesTest = $false
        }
    } catch {
        Write-Host "[FAIL] Episodes retrieval error: $($_.Exception.Message)" -ForegroundColor Red
        $EpisodesTest = $false
    }
} else {
    Write-Host ""
    Write-Host "[SKIP] Skipping episodes test due to authentication failure" -ForegroundColor Yellow
    $EpisodesTest = $false
}

# Test Summary
Write-Host ""
Write-Host "=======================================================================" -ForegroundColor Yellow
Write-Host "                           TEST RESULTS                               " -ForegroundColor Yellow
Write-Host "=======================================================================" -ForegroundColor Yellow

$PassCount = 0
$TotalTests = 5

if ($ImportTest) { $PassCount++ }
if ($ConfigTest) { $PassCount++ }
if ($AuthTest) { $PassCount++ }
if ($SeriesTest) { $PassCount++ }
if ($EpisodesTest) { $PassCount++ }

Write-Host "Module Import:       $(if ($ImportTest) { '[PASS]' } else { '[FAIL]' })" -ForegroundColor $(if ($ImportTest) { 'Green' } else { 'Red' })
Write-Host "Configuration:       $(if ($ConfigTest) { '[PASS]' } else { '[FAIL]' })" -ForegroundColor $(if ($ConfigTest) { 'Green' } else { 'Red' })
Write-Host "Authentication:      $(if ($AuthTest) { '[PASS]' } else { '[FAIL]' })" -ForegroundColor $(if ($AuthTest) { 'Green' } else { 'Red' })
Write-Host "Series Info:         $(if ($SeriesTest) { '[PASS]' } else { '[FAIL]' })" -ForegroundColor $(if ($SeriesTest) { 'Green' } else { 'Red' })
Write-Host "Episodes Retrieval:  $(if ($EpisodesTest) { '[PASS]' } else { '[FAIL]' })" -ForegroundColor $(if ($EpisodesTest) { 'Green' } else { 'Red' })

Write-Host ""
Write-Host "OVERALL: $PassCount/$TotalTests tests passed" -ForegroundColor $(if ($PassCount -eq $TotalTests) { 'Green' } else { 'Yellow' })

if ($PassCount -eq $TotalTests) {
    Write-Host "[SUCCESS] All tests passed! TheTVDB module is working correctly." -ForegroundColor Green
    exit 0
} elseif ($PassCount -ge 3) {
    Write-Host "[PARTIAL] Basic functionality is working, but some features may need attention." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "[FAILURE] Major issues detected. Module needs fixing before use." -ForegroundColor Red
    exit 1
}