Write-Host "Testing PowerShell syntax..."

# Test the regex patterns that were added
$testName = "進撃の巨人"
if ($testName -match '[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]') {
    Write-Host "Japanese detected correctly"
} else {
    Write-Host "Japanese detection failed"
}

Write-Host "Syntax test completed successfully"
Read-Host "Press Enter to continue"