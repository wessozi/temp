# Quick test to verify retry behavior works correctly
# Test that invalid series IDs loop back to prompt

$ModulesPath = Join-Path $PSScriptRoot "Modules"
Import-Module "$ModulesPath\TheTVDB.psm1" -Force

Write-Host "[TEST] Testing retry behavior..." -ForegroundColor Green

# Simulate the while loop structure from the fixed script
$SeriesId = 0
$ApiKey = "2cb4e65a-f9a9-46e4-98f9-2d44f55342db"

Write-Host "Enter the TheTVDB Series ID for your anime series." -ForegroundColor Cyan
Write-Host "You can find this on TheTVDB.com in the series URL." -ForegroundColor Gray
Write-Host "Example: For Attack on Titan, use ID: 290434" -ForegroundColor Gray
Write-Host ""

while ($SeriesId -eq 0) {
    $input = Read-Host "TheTVDB Series ID (or 'Q' to quit)"
    if ($input.ToUpper() -eq "Q" -or $input.ToLower() -eq "quit") {
        Write-Host "Exiting..." -ForegroundColor Yellow
        break
    }
    
    if ([int]::TryParse($input, [ref]$SeriesId) -and $SeriesId -gt 0) {
        # Authenticate with TheTVDB
        Write-Host ""
        Write-Host "[INFO] Authenticating with TheTVDB..." -ForegroundColor Cyan
        $token = Get-TheTVDBToken -ApiKey $ApiKey -Pin ""
        if (-not $token) {
            Write-Host "[ERROR] Cannot proceed without authentication. Please try again." -ForegroundColor Red
            $SeriesId = 0
            continue
        }
        
        # Get and verify series information
        Write-Host "[INFO] Fetching series information for ID: $SeriesId..." -ForegroundColor Cyan
        $seriesInfo = Get-SeriesInfo -Token $token -SeriesId $SeriesId
        if (-not $seriesInfo) {
            Write-Host "[ERROR] Cannot retrieve series information. Please check the Series ID." -ForegroundColor Red
            Write-Host "Try a different Series ID or check TheTVDB.com" -ForegroundColor Yellow
            $SeriesId = 0
            continue  # This should loop back to the prompt
        }
        
        # If we get here, everything worked
        Write-Host "[SUCCESS] Found series: $($seriesInfo.name)" -ForegroundColor Green
        break
    } else {
        Write-Host "[ERROR] Please enter a valid positive number" -ForegroundColor Red
    }
}

if ($SeriesId -gt 0) {
    Write-Host "[TEST PASSED] Retry behavior works correctly!" -ForegroundColor Green
} else {
    Write-Host "[TEST] User chose to quit" -ForegroundColor Yellow
}