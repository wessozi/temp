# Test the final version placement
$testFileName = "Please.Put.Them.On.Takamine-san.S01E11.I'll.Let.You.Do.a.Dry.Run.mkv"

Write-Host "Testing filename: $testFileName" -ForegroundColor Green

# Test the actual regex pattern from the module
$newTargetName = $testFileName -replace '(S\d{2}E\d{2})\.', "`$1.v3."
Write-Host "Result: $newTargetName" -ForegroundColor Cyan

# Test what the pattern actually captures
if ($testFileName -match '(S\d{2}E\d{2})\.') {
    Write-Host "Pattern matched: $($Matches[1])" -ForegroundColor Yellow
}

# Test the expected result
$expected = "Please.Put.Them.On.Takamine-san.S01E11.v3.I'll.Let.You.Do.a.Dry.Run.mkv"
Write-Host "Expected: $expected" -ForegroundColor Green
Write-Host "Actual:   $newTargetName" -ForegroundColor Cyan
Write-Host "Match: $($newTargetName -eq $expected)" -ForegroundColor $(if ($newTargetName -eq $expected) { 'Green' } else { 'Red' })