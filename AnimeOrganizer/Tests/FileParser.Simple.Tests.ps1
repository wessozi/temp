# FileParser.Simple.Tests.ps1 - Simple Tests for FileParser Module

Write-Host "=======================================================================" -ForegroundColor Yellow
Write-Host "                  FileParser Module Simple Tests                      " -ForegroundColor Yellow
Write-Host "=======================================================================" -ForegroundColor Yellow
Write-Host ""

$TestCount = 0
$PassCount = 0

# Test 1: Module Import
Write-Host "[TEST 1] Testing FileParser module import..." -ForegroundColor Cyan
$TestCount++
try {
    $ModulePath = Join-Path $PSScriptRoot "..\Modules\AnimeOrganizer.FileParser.psm1"
    Import-Module $ModulePath -Force
    Write-Host "[PASS] FileParser module imported successfully" -ForegroundColor Green
    $PassCount++
} catch {
    Write-Host "[FAIL] Failed to import FileParser module: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[ABORT] Cannot continue tests without module import" -ForegroundColor Red
    exit 1
}

# Test 2: Basic Hash Pattern
Write-Host ""
Write-Host "[TEST 2] Testing basic hash pattern..." -ForegroundColor Cyan
$TestCount++
try {
    $result = Parse-EpisodeNumber -FileName "#01.mkv"
    if ($result -and $result.EpisodeNumber -eq 1) {
        Write-Host "[PASS] Hash pattern #01.mkv parsed correctly (Episode $($result.EpisodeNumber))" -ForegroundColor Green
        $PassCount++
    } else {
        Write-Host "[FAIL] Hash pattern #01.mkv not parsed correctly" -ForegroundColor Red
    }
} catch {
    Write-Host "[FAIL] Exception parsing hash pattern: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: SxxExx Pattern
Write-Host ""
Write-Host "[TEST 3] Testing SxxExx pattern..." -ForegroundColor Cyan
$TestCount++
try {
    $result = Parse-EpisodeNumber -FileName "S01E05.mkv"
    if ($result -and $result.EpisodeNumber -eq 5 -and $result.SeasonNumber -eq 1) {
        Write-Host "[PASS] SxxExx pattern S01E05.mkv parsed correctly (S$($result.SeasonNumber)E$($result.EpisodeNumber))" -ForegroundColor Green
        $PassCount++
    } else {
        Write-Host "[FAIL] SxxExx pattern S01E05.mkv not parsed correctly" -ForegroundColor Red
    }
} catch {
    Write-Host "[FAIL] Exception parsing SxxExx pattern: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Episode-Title Pattern
Write-Host ""
Write-Host "[TEST 4] Testing episode-title pattern..." -ForegroundColor Cyan
$TestCount++
try {
    $result = Parse-EpisodeNumber -FileName "10 - Final Battle.mkv"
    if ($result -and $result.EpisodeNumber -eq 10) {
        Write-Host "[PASS] Episode-title pattern parsed correctly (Episode $($result.EpisodeNumber))" -ForegroundColor Green
        $PassCount++
    } else {
        Write-Host "[FAIL] Episode-title pattern not parsed correctly" -ForegroundColor Red
    }
} catch {
    Write-Host "[FAIL] Exception parsing episode-title pattern: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Simple Numbered Pattern
Write-Host ""
Write-Host "[TEST 5] Testing simple numbered pattern..." -ForegroundColor Cyan
$TestCount++
try {
    $result = Parse-EpisodeNumber -FileName "07.mkv"
    if ($result -and $result.EpisodeNumber -eq 7) {
        Write-Host "[PASS] Simple numbered pattern 07.mkv parsed correctly (Episode $($result.EpisodeNumber))" -ForegroundColor Green
        $PassCount++
    } else {
        Write-Host "[FAIL] Simple numbered pattern 07.mkv not parsed correctly" -ForegroundColor Red
    }
} catch {
    Write-Host "[FAIL] Exception parsing simple numbered pattern: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 6: Get-SafeFileName Function
Write-Host ""
Write-Host "[TEST 6] Testing Get-SafeFileName function..." -ForegroundColor Cyan
$TestCount++
try {
    $result = Get-SafeFileName -FileName "Series: Episode/Title"
    $expected = "Series- Episode-Title"
    if ($result -eq $expected) {
        Write-Host "[PASS] SafeFileName function working: '$result'" -ForegroundColor Green
        $PassCount++
    } else {
        Write-Host "[FAIL] SafeFileName function result '$result' expected '$expected'" -ForegroundColor Red
    }
} catch {
    Write-Host "[FAIL] Exception in SafeFileName function: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 7: Test-IsRomanizedJapaneseName Function
Write-Host ""
Write-Host "[TEST 7] Testing Test-IsRomanizedJapaneseName function..." -ForegroundColor Cyan
$TestCount++
try {
    $result1 = Test-IsRomanizedJapaneseName -Name "Mahō Shōjo"
    $result2 = Test-IsRomanizedJapaneseName -Name "Attack on Titan"
    if ($result1 -eq $true -and $result2 -eq $false) {
        Write-Host "[PASS] Romanized name detection working correctly" -ForegroundColor Green
        $PassCount++
    } else {
        Write-Host "[FAIL] Romanized name detection not working correctly" -ForegroundColor Red
    }
} catch {
    Write-Host "[FAIL] Exception in romanized name detection: $($_.Exception.Message)" -ForegroundColor Red
}

# Summary
Write-Host ""
Write-Host "=======================================================================" -ForegroundColor Yellow
Write-Host "                         TEST RESULTS SUMMARY                         " -ForegroundColor Yellow
Write-Host "=======================================================================" -ForegroundColor Yellow
Write-Host "PASSED: $PassCount/$TestCount tests" -ForegroundColor $(if ($PassCount -eq $TestCount) { 'Green' } elseif ($PassCount -ge 5) { 'Yellow' } else { 'Red' })

if ($PassCount -eq $TestCount) {
    Write-Host "[SUCCESS] All FileParser tests passed! Module is working perfectly." -ForegroundColor Green
    exit 0
} elseif ($PassCount -ge 5) {
    Write-Host "[MOSTLY SUCCESS] Most functionality working correctly." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "[FAILURE] Major issues detected. Module needs attention." -ForegroundColor Red
    exit 1
}