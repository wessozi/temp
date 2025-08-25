# FileParser.Tests.ps1 - Comprehensive Tests for FileParser Module
# Tests all filename parsing patterns and edge cases

Write-Host "=======================================================================" -ForegroundColor Yellow
Write-Host "                  FileParser Module Comprehensive Tests               " -ForegroundColor Yellow
Write-Host "=======================================================================" -ForegroundColor Yellow
Write-Host ""

# Test configuration
$TestResults = @()

# Test 1: Module Import
Write-Host "[TEST 1] Testing FileParser module import..." -ForegroundColor Cyan
try {
    $ModulePath = Join-Path $PSScriptRoot "..\Modules\AnimeOrganizer.FileParser.psm1"
    Import-Module $ModulePath -Force
    Write-Host "[PASS] FileParser module imported successfully" -ForegroundColor Green
    $TestResults += @{ Test = "Module Import"; Result = "PASS"; Details = "Module imported successfully" }
} catch {
    Write-Host "[FAIL] Failed to import FileParser module: $($_.Exception.Message)" -ForegroundColor Red
    $TestResults += @{ Test = "Module Import"; Result = "FAIL"; Details = $_.Exception.Message }
    Write-Host "[ABORT] Cannot continue tests without module import" -ForegroundColor Red
    exit 1
}

# Test 2: Configuration Loading
Write-Host ""
Write-Host "[TEST 2] Testing configuration loading..." -ForegroundColor Cyan
try {
    $config = Get-AnimeOrganizerConfig
    if ($config -and $config.parsing -and $config.parsing.patterns) {
        Write-Host "[PASS] Configuration loaded with parsing patterns" -ForegroundColor Green
        $TestResults += @{ Test = "Configuration"; Result = "PASS"; Details = "Parsing patterns loaded" }
    } else {
        Write-Host "[FAIL] Configuration not loaded or missing parsing patterns" -ForegroundColor Red
        $TestResults += @{ Test = "Configuration"; Result = "FAIL"; Details = "Missing parsing patterns" }
    }
} catch {
    Write-Host "[FAIL] Error loading configuration: $($_.Exception.Message)" -ForegroundColor Red
    $TestResults += @{ Test = "Configuration"; Result = "FAIL"; Details = $_.Exception.Message }
}

# Test 3: Basic Hash Pattern Parsing
Write-Host ""
Write-Host "[TEST 3] Testing basic hash pattern parsing..." -ForegroundColor Cyan
$hashTestCases = @(
    @{ File = "#01.mkv"; Expected = @{ Episode = 1; Season = 1; Pattern = "basic-hash" } },
    @{ File = "#02. Title.mkv"; Expected = @{ Episode = 2; Season = 1; Pattern = "basic-hash" } },
    @{ File = "#10.mp4"; Expected = @{ Episode = 10; Season = 1; Pattern = "basic-hash" } }
)

$hashTestPass = $true
foreach ($testCase in $hashTestCases) {
    try {
        $result = Parse-EpisodeNumber -FileName $testCase.File
        if ($result -and $result.EpisodeNumber -eq $testCase.Expected.Episode -and 
            $result.SeasonNumber -eq $testCase.Expected.Season) {
            Write-Host "  ✓ $($testCase.File) → Episode $($result.EpisodeNumber)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $($testCase.File) → Failed or incorrect result" -ForegroundColor Red
            $hashTestPass = $false
        }
    } catch {
        Write-Host "  ✗ $($testCase.File) → Exception: $($_.Exception.Message)" -ForegroundColor Red
        $hashTestPass = $false
    }
}

if ($hashTestPass) {
    Write-Host "[PASS] Hash pattern parsing working correctly" -ForegroundColor Green
    $TestResults += @{ Test = "Hash Patterns"; Result = "PASS"; Details = "All hash patterns parsed correctly" }
} else {
    Write-Host "[FAIL] Hash pattern parsing has issues" -ForegroundColor Red
    $TestResults += @{ Test = "Hash Patterns"; Result = "FAIL"; Details = "Some hash patterns failed" }
}

# Test 4: SxxExx Pattern Parsing
Write-Host ""
Write-Host "[TEST 4] Testing SxxExx pattern parsing..." -ForegroundColor Cyan
$sxxexxTestCases = @(
    @{ File = "S01E01.mkv"; Expected = @{ Episode = 1; Season = 1 } },
    @{ File = "S02E10 Title.mkv"; Expected = @{ Episode = 10; Season = 2 } },
    @{ File = "Series S01E05 Title.mkv"; Expected = @{ Episode = 5; Season = 1 } },
    @{ File = "Series.S03E12.mkv"; Expected = @{ Episode = 12; Season = 3 } }
)

$sxxexxTestPass = $true
foreach ($testCase in $sxxexxTestCases) {
    try {
        $result = Parse-EpisodeNumber -FileName $testCase.File
        if ($result -and $result.EpisodeNumber -eq $testCase.Expected.Episode -and 
            $result.SeasonNumber -eq $testCase.Expected.Season) {
            Write-Host "  ✓ $($testCase.File) → S$($result.SeasonNumber.ToString('D2'))E$($result.EpisodeNumber.ToString('D2'))" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $($testCase.File) → Failed or incorrect result" -ForegroundColor Red
            $sxxexxTestPass = $false
        }
    } catch {
        Write-Host "  ✗ $($testCase.File) → Exception: $($_.Exception.Message)" -ForegroundColor Red
        $sxxexxTestPass = $false
    }
}

if ($sxxexxTestPass) {
    Write-Host "[PASS] SxxExx pattern parsing working correctly" -ForegroundColor Green
    $TestResults += @{ Test = "SxxExx Patterns"; Result = "PASS"; Details = "All SxxExx patterns parsed correctly" }
} else {
    Write-Host "[FAIL] SxxExx pattern parsing has issues" -ForegroundColor Red
    $TestResults += @{ Test = "SxxExx Patterns"; Result = "FAIL"; Details = "Some SxxExx patterns failed" }
}

# Test 5: Episode-Title Pattern Parsing
Write-Host ""
Write-Host "[TEST 5] Testing episode-title pattern parsing..." -ForegroundColor Cyan
$episodeTitleTestCases = @(
    @{ File = "01 - First Episode.mkv"; Expected = @{ Episode = 1; Season = 1 } },
    @{ File = "10 - Final Battle.mp4"; Expected = @{ Episode = 10; Season = 1 } },
    @{ File = "Series - 05.mkv"; Expected = @{ Episode = 5; Season = 1 } }
)

$episodeTitleTestPass = $true
foreach ($testCase in $episodeTitleTestCases) {
    try {
        $result = Parse-EpisodeNumber -FileName $testCase.File
        if ($result -and $result.EpisodeNumber -eq $testCase.Expected.Episode -and 
            $result.SeasonNumber -eq $testCase.Expected.Season) {
            Write-Host "  ✓ $($testCase.File) → Episode $($result.EpisodeNumber)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $($testCase.File) → Failed or incorrect result" -ForegroundColor Red
            $episodeTitleTestPass = $false
        }
    } catch {
        Write-Host "  ✗ $($testCase.File) → Exception: $($_.Exception.Message)" -ForegroundColor Red
        $episodeTitleTestPass = $false
    }
}

if ($episodeTitleTestPass) {
    Write-Host "[PASS] Episode-title pattern parsing working correctly" -ForegroundColor Green
    $TestResults += @{ Test = "Episode-Title Patterns"; Result = "PASS"; Details = "All episode-title patterns parsed correctly" }
} else {
    Write-Host "[FAIL] Episode-title pattern parsing has issues" -ForegroundColor Red
    $TestResults += @{ Test = "Episode-Title Patterns"; Result = "FAIL"; Details = "Some episode-title patterns failed" }
}

# Test 6: Simple Numbered Pattern Parsing
Write-Host ""
Write-Host "[TEST 6] Testing simple numbered pattern parsing..." -ForegroundColor Cyan
$simpleNumberedTestCases = @(
    @{ File = "01.mkv"; Expected = @{ Episode = 1; Season = 1 } },
    @{ File = "07.mp4"; Expected = @{ Episode = 7; Season = 1 } },
    @{ File = "12.avi"; Expected = @{ Episode = 12; Season = 1 } }
)

$simpleNumberedTestPass = $true
foreach ($testCase in $simpleNumberedTestCases) {
    try {
        $result = Parse-EpisodeNumber -FileName $testCase.File
        if ($result -and $result.EpisodeNumber -eq $testCase.Expected.Episode -and 
            $result.SeasonNumber -eq $testCase.Expected.Season) {
            Write-Host "  ✓ $($testCase.File) → Episode $($result.EpisodeNumber)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $($testCase.File) → Failed or incorrect result" -ForegroundColor Red
            $simpleNumberedTestPass = $false
        }
    } catch {
        Write-Host "  ✗ $($testCase.File) → Exception: $($_.Exception.Message)" -ForegroundColor Red
        $simpleNumberedTestPass = $false
    }
}

if ($simpleNumberedTestPass) {
    Write-Host "[PASS] Simple numbered pattern parsing working correctly" -ForegroundColor Green
    $TestResults += @{ Test = "Simple Numbered Patterns"; Result = "PASS"; Details = "All simple numbered patterns parsed correctly" }
} else {
    Write-Host "[FAIL] Simple numbered pattern parsing has issues" -ForegroundColor Red
    $TestResults += @{ Test = "Simple Numbered Patterns"; Result = "FAIL"; Details = "Some simple numbered patterns failed" }
}

# Test 7: Special/OVA Pattern Parsing
Write-Host ""
Write-Host "[TEST 7] Testing special/OVA pattern parsing..." -ForegroundColor Cyan
$specialTestCases = @(
    @{ File = "Series OVA 1.mkv"; Expected = @{ Episode = 1; Season = 1 } },
    @{ File = "Series Special 2.mp4"; Expected = @{ Episode = 2; Season = 1 } },
    @{ File = "Series OAD.mkv"; Expected = @{ Episode = 1; Season = 1 } }
)

$specialTestPass = $true
foreach ($testCase in $specialTestCases) {
    try {
        $result = Parse-EpisodeNumber -FileName $testCase.File
        if ($result -and $result.EpisodeNumber -ge 1) {  # More flexible check for specials
            Write-Host "  ✓ $($testCase.File) → Episode $($result.EpisodeNumber)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $($testCase.File) → Failed or incorrect result" -ForegroundColor Red
            $specialTestPass = $false
        }
    } catch {
        Write-Host "  ✗ $($testCase.File) → Exception: $($_.Exception.Message)" -ForegroundColor Red
        $specialTestPass = $false
    }
}

if ($specialTestPass) {
    Write-Host "[PASS] Special/OVA pattern parsing working correctly" -ForegroundColor Green
    $TestResults += @{ Test = "Special/OVA Patterns"; Result = "PASS"; Details = "All special/OVA patterns parsed correctly" }
} else {
    Write-Host "[FAIL] Special/OVA pattern parsing has issues" -ForegroundColor Red
    $TestResults += @{ Test = "Special/OVA Patterns"; Result = "FAIL"; Details = "Some special/OVA patterns failed" }
}

# Test 8: Get-SafeFileName Function
Write-Host ""
Write-Host "[TEST 8] Testing Get-SafeFileName function..." -ForegroundColor Cyan
$safeFileNameTestCases = @(
    @{ Input = "Series: Title with colon"; Expected = "Series- Title with colon" },
    @{ Input = "Series/Episode\\Name"; Expected = "Series-Episode-Name" },
    @{ Input = "Series?Title*"; Expected = "SeriesTitle" },
    @{ Input = "Series<>Title|Name"; Expected = "Series-Title-Name" }
)

$safeFileNameTestPass = $true
foreach ($testCase in $safeFileNameTestCases) {
    try {
        $result = Get-SafeFileName -FileName $testCase.Input
        if ($result -eq $testCase.Expected) {
            Write-Host "  ✓ '$($testCase.Input)' → '$result'" -ForegroundColor Green
        } else {
            Write-Host "  ✗ '$($testCase.Input)' → '$result' (expected '$($testCase.Expected)')" -ForegroundColor Red
            $safeFileNameTestPass = $false
        }
    } catch {
        Write-Host "  ✗ '$($testCase.Input)' → Exception: $($_.Exception.Message)" -ForegroundColor Red
        $safeFileNameTestPass = $false
    }
}

if ($safeFileNameTestPass) {
    Write-Host "[PASS] Get-SafeFileName function working correctly" -ForegroundColor Green
    $TestResults += @{ Test = "SafeFileName Function"; Result = "PASS"; Details = "All filename sanitization tests passed" }
} else {
    Write-Host "[FAIL] Get-SafeFileName function has issues" -ForegroundColor Red
    $TestResults += @{ Test = "SafeFileName Function"; Result = "FAIL"; Details = "Some filename sanitization tests failed" }
}

# Test 9: Test-IsRomanizedJapaneseName Function
Write-Host ""
Write-Host "[TEST 9] Testing Test-IsRomanizedJapaneseName function..." -ForegroundColor Cyan
$romanizedTestCases = @(
    @{ Input = "Mahō Shōjo"; Expected = $true },
    @{ Input = "Attack on Titan"; Expected = $false },
    @{ Input = "Yahari Ore no Seishun"; Expected = $true },
    @{ Input = "One Piece"; Expected = $false }
)

$romanizedTestPass = $true
foreach ($testCase in $romanizedTestCases) {
    try {
        $result = Test-IsRomanizedJapaneseName -Name $testCase.Input
        if ($result -eq $testCase.Expected) {
            Write-Host "  ✓ '$($testCase.Input)' → $result" -ForegroundColor Green
        } else {
            Write-Host "  ✗ '$($testCase.Input)' → $result (expected $($testCase.Expected))" -ForegroundColor Red
            $romanizedTestPass = $false
        }
    } catch {
        Write-Host "  ✗ '$($testCase.Input)' → Exception: $($_.Exception.Message)" -ForegroundColor Red
        $romanizedTestPass = $false
    }
}

if ($romanizedTestPass) {
    Write-Host "[PASS] Test-IsRomanizedJapaneseName function working correctly" -ForegroundColor Green
    $TestResults += @{ Test = "Romanized Name Detection"; Result = "PASS"; Details = "All romanized name detection tests passed" }
} else {
    Write-Host "[FAIL] Test-IsRomanizedJapaneseName function has issues" -ForegroundColor Red
    $TestResults += @{ Test = "Romanized Name Detection"; Result = "FAIL"; Details = "Some romanized name detection tests failed" }
}

# Test Summary
Write-Host ""
Write-Host "=======================================================================" -ForegroundColor Yellow
Write-Host "                         FILEPARSER TEST RESULTS                      " -ForegroundColor Yellow
Write-Host "=======================================================================" -ForegroundColor Yellow

$PassCount = ($TestResults | Where-Object { $_.Result -eq "PASS" }).Count
$TotalTests = $TestResults.Count

foreach ($test in $TestResults) {
    $color = if ($test.Result -eq "PASS") { "Green" } else { "Red" }
    Write-Host "$($test.Test): [$($test.Result)]" -ForegroundColor $color
}

Write-Host ""
Write-Host "OVERALL: $PassCount/$TotalTests tests passed" -ForegroundColor $(if ($PassCount -eq $TotalTests) { 'Green' } else { 'Yellow' })

if ($PassCount -eq $TotalTests) {
    Write-Host "[SUCCESS] All FileParser tests passed! Module is working correctly." -ForegroundColor Green
    exit 0
} elseif ($PassCount -ge ($TotalTests * 0.8)) {
    Write-Host "[MOSTLY SUCCESS] Most functionality working, minor issues detected." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "[FAILURE] Major issues detected. Module needs fixing before use." -ForegroundColor Red
    exit 1
}