# ErrorHandling.Tests.ps1 - Comprehensive Tests for Error Handling Module
# Phase 3: Enhanced Features - Error Recovery Testing

Write-Host "=======================================================================" -ForegroundColor Yellow
Write-Host "                 Error Handling Module Comprehensive Tests              " -ForegroundColor Yellow
Write-Host "=======================================================================" -ForegroundColor Yellow
Write-Host ""

# Test 1: Module Import
Write-Host "[TEST 1] Testing error handling module import..." -ForegroundColor Cyan
try {
    $ModulePath = Join-Path $PSScriptRoot "..\Modules\AnimeOrganizer.ErrorHandling.psm1"
    Import-Module $ModulePath -Force
    Write-Host "[PASS] Error handling module imported successfully" -ForegroundColor Green
    $ImportTest = $true
} catch {
    Write-Host "[FAIL] Failed to import error handling module: $($_.Exception.Message)" -ForegroundColor Red
    $ImportTest = $false
    exit 1
}

# Test 2: Module Initialization
Write-Host ""
Write-Host "[TEST 2] Testing error handling initialization..." -ForegroundColor Cyan
try {
    Initialize-ErrorHandling -MaxRetryAttempts 2 -RetryDelayMs 100 -EnableRollback $true
    Write-Host "[PASS] Error handling initialized successfully" -ForegroundColor Green
    $InitTest = $true
} catch {
    Write-Host "[FAIL] Failed to initialize error handling: $($_.Exception.Message)" -ForegroundColor Red
    $InitTest = $false
}

# Test 3: Safe Operation with Retry (Successful)
Write-Host ""
Write-Host "[TEST 3] Testing safe operation with successful execution..." -ForegroundColor Cyan
try {
    $counter = 0
    $result = Invoke-SafeOperation -OperationName "Successful Test" -Operation {
        $counter++
        return "Success on attempt $counter"
    }
    
    if ($result -eq "Success on attempt 1") {
        Write-Host "[PASS] Safe operation completed successfully on first attempt" -ForegroundColor Green
        $SafeOpTest1 = $true
    } else {
        Write-Host "[FAIL] Unexpected result: $result" -ForegroundColor Red
        $SafeOpTest1 = $false
    }
} catch {
    Write-Host "[FAIL] Safe operation failed: $($_.Exception.Message)" -ForegroundColor Red
    $SafeOpTest1 = $false
}

# Test 4: Safe Operation with Retry (Failure then Success)
Write-Host ""
Write-Host "[TEST 4] Testing safe operation with retry (fail then succeed)..." -ForegroundColor Cyan
try {
    $script:attemptCount = 0
    $result = Invoke-SafeOperation -OperationName "Retry Test" -Operation {
        $script:attemptCount++
        if ($script:attemptCount -lt 2) {
            throw "Simulated failure on attempt $script:attemptCount"
        }
        return "Success on attempt $script:attemptCount"
    } -MaxRetries 3
    
    if ($result -eq "Success on attempt 2" -and $script:attemptCount -eq 2) {
        Write-Host "[PASS] Safe operation succeeded after retry" -ForegroundColor Green
        $SafeOpTest2 = $true
    } else {
        Write-Host "[FAIL] Unexpected result: $result (attempts: $script:attemptCount)" -ForegroundColor Red
        $SafeOpTest2 = $false
    }
} catch {
    Write-Host "[FAIL] Safe operation with retry failed: $($_.Exception.Message)" -ForegroundColor Red
    $SafeOpTest2 = $false
}

# Test 5: Safe Operation with Maximum Retries Exceeded
Write-Host ""
Write-Host "[TEST 5] Testing safe operation with max retries exceeded..." -ForegroundColor Cyan
try {
    $script:attemptCount = 0
    $result = Invoke-SafeOperation -OperationName "Max Retry Test" -Operation {
        $script:attemptCount++
        throw "Always failing on attempt $script:attemptCount"
    } -MaxRetries 2
    
    Write-Host "[FAIL] Operation should have thrown an exception" -ForegroundColor Red
    $SafeOpTest3 = $false
} catch {
    if ($script:attemptCount -eq 2) { # 1 initial + 1 retry (MaxRetries=2 means total 2 attempts)
        Write-Host "[PASS] Maximum retries correctly exceeded (attempts: $script:attemptCount)" -ForegroundColor Green
        $SafeOpTest3 = $true
    } else {
        Write-Host "[FAIL] Incorrect number of attempts: $script:attemptCount (expected: 2)" -ForegroundColor Red
        $SafeOpTest3 = $false
    }
}

# Test 6: Operation Stack Tracking
Write-Host ""
Write-Host "[TEST 6] Testing operation stack tracking..." -ForegroundColor Cyan
try {
    # Clear any existing operations
    Clear-OperationStack
    
    # Track an operation
    $rollbackCalled = $false
    $testOperation = {
        # This would be the actual operation
        return "Test Result"
    }
    
    $testRollback = {
        $rollbackCalled = $true
    }
    
    $result = Invoke-SafeOperation -OperationName "Stack Test" -Operation $testOperation -RollbackOperation $testRollback
    
    # Operation should be removed from stack after success
    if ($result -eq "Test Result" -and (-not $rollbackCalled)) {
        Write-Host "[PASS] Operation stack correctly managed" -ForegroundColor Green
        $StackTest = $true
    } else {
        Write-Host "[FAIL] Stack management incorrect (rollback called: $rollbackCalled)" -ForegroundColor Red
        $StackTest = $false
    }
} catch {
    Write-Host "[FAIL] Operation stack test failed: $($_.Exception.Message)" -ForegroundColor Red
    $StackTest = $false
}

# Test 7: Safe API Call
Write-Host ""
Write-Host "[TEST 7] Testing safe API call wrapper..." -ForegroundColor Cyan
try {
    $apiResult = Invoke-SafeApiCall -ApiName "Test API" -ApiCall {
        return @{ Status = "OK"; Data = "Test Data" }
    }
    
    if ($apiResult.Status -eq "OK" -and $apiResult.Data -eq "Test Data") {
        Write-Host "[PASS] Safe API call completed successfully" -ForegroundColor Green
        $ApiTest = $true
    } else {
        Write-Host "[FAIL] API call returned unexpected result" -ForegroundColor Red
        $ApiTest = $false
    }
} catch {
    Write-Host "[FAIL] Safe API call test failed: $($_.Exception.Message)" -ForegroundColor Red
    $ApiTest = $false
}

# Test Summary
Write-Host ""
Write-Host "=======================================================================" -ForegroundColor Yellow
Write-Host "                           TEST RESULTS                               " -ForegroundColor Yellow
Write-Host "=======================================================================" -ForegroundColor Yellow

$tests = @(
    @{Name = "Module Import"; Result = $ImportTest},
    @{Name = "Initialization"; Result = $InitTest},
    @{Name = "Safe Operation (Success)"; Result = $SafeOpTest1},
    @{Name = "Safe Operation (Retry)"; Result = $SafeOpTest2},
    @{Name = "Safe Operation (Max Retries)"; Result = $SafeOpTest3},
    @{Name = "Operation Stack"; Result = $StackTest},
    @{Name = "Safe API Call"; Result = $ApiTest}
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
    Write-Host "[SUCCESS] All error handling tests passed! Error handling module is working correctly." -ForegroundColor Green
    exit 0
} else {
    Write-Host "[PARTIAL] Some error handling tests failed. Review the results above." -ForegroundColor Yellow
    exit 1
}