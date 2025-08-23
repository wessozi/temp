# Logging.Tests.ps1 - Comprehensive Tests for Logging Module
# Phase 3: Enhanced Features - Unit Testing Implementation

Write-Host "=======================================================================" -ForegroundColor Yellow
Write-Host "                    Logging Module Comprehensive Tests                  " -ForegroundColor Yellow
Write-Host "=======================================================================" -ForegroundColor Yellow
Write-Host ""

# Test 1: Module Import
Write-Host "[TEST 1] Testing logging module import..." -ForegroundColor Cyan
try {
    $ModulePath = Join-Path $PSScriptRoot "..\Modules\AnimeOrganizer.Logging.psm1"
    Import-Module $ModulePath -Force
    Write-Host "[PASS] Logging module imported successfully" -ForegroundColor Green
    $ImportTest = $true
} catch {
    Write-Host "[FAIL] Failed to import logging module: $($_.Exception.Message)" -ForegroundColor Red
    $ImportTest = $false
    exit 1
}

# Test 2: Logging Initialization
Write-Host ""
Write-Host "[TEST 2] Testing logging initialization..." -ForegroundColor Cyan
try {
    Initialize-Logging -LogLevel "DEBUG" -LogToFile $false -ConsoleOutput $true
    Write-Host "[PASS] Logging initialized successfully" -ForegroundColor Green
    $InitTest = $true
} catch {
    Write-Host "[FAIL] Failed to initialize logging: $($_.Exception.Message)" -ForegroundColor Red
    $InitTest = $false
}

# Test 3: Log Level Filtering
Write-Host ""
Write-Host "[TEST 3] Testing log level filtering..." -ForegroundColor Cyan
try {
    # Test with DEBUG level (should log everything)
    Initialize-Logging -LogLevel "DEBUG" -LogToFile $false
    $debugShouldLog = Should-Log -Level "DEBUG"
    $infoShouldLog = Should-Log -Level "INFO"
    $warningShouldLog = Should-Log -Level "WARNING"
    $errorShouldLog = Should-Log -Level "ERROR"
    
    if ($debugShouldLog -and $infoShouldLog -and $warningShouldLog -and $errorShouldLog) {
        Write-Host "[PASS] DEBUG level correctly allows all log levels" -ForegroundColor Green
        $LevelTest1 = $true
    } else {
        Write-Host "[FAIL] DEBUG level filtering incorrect" -ForegroundColor Red
        $LevelTest1 = $false
    }
    
    # Test with WARNING level (should only log WARNING and ERROR)
    Initialize-Logging -LogLevel "WARNING" -LogToFile $false
    $debugShouldLog = Should-Log -Level "DEBUG"
    $infoShouldLog = Should-Log -Level "INFO"
    $warningShouldLog = Should-Log -Level "WARNING"
    $errorShouldLog = Should-Log -Level "ERROR"
    
    if ((-not $debugShouldLog) -and (-not $infoShouldLog) -and $warningShouldLog -and $errorShouldLog) {
        Write-Host "[PASS] WARNING level correctly filters lower levels" -ForegroundColor Green
        $LevelTest2 = $true
    } else {
        Write-Host "[FAIL] WARNING level filtering incorrect" -ForegroundColor Red
        $LevelTest2 = $false
    }
    
    $LevelTest = $LevelTest1 -and $LevelTest2
    
} catch {
    Write-Host "[FAIL] Log level testing error: $($_.Exception.Message)" -ForegroundColor Red
    $LevelTest = $false
}

# Test 4: Log Message Writing
Write-Host ""
Write-Host "[TEST 4] Testing log message writing..." -ForegroundColor Cyan
try {
    Initialize-Logging -LogLevel "DEBUG" -LogToFile $false
    
    # Test all log levels
    Write-DebugLog "This is a debug message" -Category "Test"
    Write-InfoLog "This is an info message" -Category "Test"
    Write-WarningLog "This is a warning message" -Category "Test"
    Write-ErrorLog "This is an error message" -Category "Test"
    
    Write-Host "[PASS] All log levels written successfully (check console output)" -ForegroundColor Green
    $WriteTest = $true
} catch {
    Write-Host "[FAIL] Log writing error: $($_.Exception.Message)" -ForegroundColor Red
    $WriteTest = $false
}

# Test 5: Performance Measurement
Write-Host ""
Write-Host "[TEST 5] Testing performance measurement..." -ForegroundColor Cyan
try {
    Initialize-Logging -LogLevel "INFO" -LogToFile $false
    
    $result = Measure-Performance "Test Operation" -ScriptBlock {
        Start-Sleep -Milliseconds 100
        return "Test Result"
    } -Category "PerformanceTest"
    
    if ($result -eq "Test Result") {
        Write-Host "[PASS] Performance measurement completed successfully" -ForegroundColor Green
        $PerfTest = $true
    } else {
        Write-Host "[FAIL] Performance measurement returned unexpected result" -ForegroundColor Red
        $PerfTest = $false
    }
} catch {
    Write-Host "[FAIL] Performance measurement error: $($_.Exception.Message)" -ForegroundColor Red
    $PerfTest = $false
}

# Test 6: File Logging (if enabled)
Write-Host ""
Write-Host "[TEST 6] Testing file logging..." -ForegroundColor Cyan
try {
    $testLogDir = Join-Path $PSScriptRoot "..\..\test-logs"
    Initialize-Logging -LogLevel "INFO" -LogToFile $true -LogDirectory $testLogDir
    
    Write-InfoLog "Test message for file logging" -Category "FileTest"
    
    # Check if log file was created
    $logFiles = Get-ChildItem $testLogDir -Filter "*.log" | Sort-Object LastWriteTime -Descending
    if ($logFiles.Count -gt 0) {
        $latestLog = $logFiles[0].FullName
        $logContent = Get-Content $latestLog -Tail 1 | ConvertFrom-Json
        
        if ($logContent.Message -eq "Test message for file logging") {
            Write-Host "[PASS] File logging working correctly" -ForegroundColor Green
            $FileTest = $true
        } else {
            Write-Host "[FAIL] File log content incorrect" -ForegroundColor Red
            $FileTest = $false
        }
        
        # Clean up test logs
        Remove-Item $testLogDir -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "[FAIL] No log files created" -ForegroundColor Red
        $FileTest = $false
    }
} catch {
    Write-Host "[FAIL] File logging error: $($_.Exception.Message)" -ForegroundColor Red
    $FileTest = $false
    # Clean up on error
    Remove-Item $testLogDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Test Summary
Write-Host ""
Write-Host "=======================================================================" -ForegroundColor Yellow
Write-Host "                           TEST RESULTS                               " -ForegroundColor Yellow
Write-Host "=======================================================================" -ForegroundColor Yellow

$tests = @(
    @{Name = "Module Import"; Result = $ImportTest},
    @{Name = "Initialization"; Result = $InitTest},
    @{Name = "Level Filtering"; Result = $LevelTest},
    @{Name = "Message Writing"; Result = $WriteTest},
    @{Name = "Performance Measurement"; Result = $PerfTest},
    @{Name = "File Logging"; Result = $FileTest}
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
    Write-Host "[SUCCESS] All logging tests passed! Logging module is working correctly." -ForegroundColor Green
    exit 0
} else {
    Write-Host "[PARTIAL] Some logging tests failed. Review the results above." -ForegroundColor Yellow
    exit 1
}