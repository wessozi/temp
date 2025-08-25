# Test the regex pattern for version placement
$testFileName = "Please.Put.Them.On.Takamine-san.S01E11.I'll.Let.You.Do.a.Dry.Run.mkv"

Write-Host "Testing filename: $testFileName" -ForegroundColor Green

# Test the current regex pattern
if ($testFileName -match '(S\d{2}E\d{2})(\.)([^\.]+\.\w+)$') {
    Write-Host "Match found!" -ForegroundColor Green
    Write-Host "Group 1 (Episode): $($Matches[1])" -ForegroundColor Cyan
    Write-Host "Group 2 (Dot): $($Matches[2])" -ForegroundColor Cyan
    Write-Host "Group 3 (Title+Ext): $($Matches[3])" -ForegroundColor Cyan
    
    $newName = $testFileName -replace '(S\d{2}E\d{2})(\.)([^\.]+\.\w+)$', "`$1.v3.`$3"
    Write-Host "Result: $newName" -ForegroundColor Yellow
} else {
    Write-Host "No match found" -ForegroundColor Red
}