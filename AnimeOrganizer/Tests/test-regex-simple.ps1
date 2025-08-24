# Test simple regex patterns
$testFileName = "Please.Put.Them.On.Takamine-san.S01E11.I'll.Let.You.Do.a.Dry.Run.mkv"

Write-Host "Testing filename: $testFileName" -ForegroundColor Green

# Test different patterns
$patterns = @(
    '(S\d{2}E\d{2})',
    '(S\d{2}E\d{2}\.)',
    '(S01E11)',
    '(S01E11\.)',
    '(\..*?\..*?\..*?\.mkv)$'
)

foreach ($pattern in $patterns) {
    if ($testFileName -match $pattern) {
        Write-Host "Pattern '$pattern' matched: $($Matches[0])" -ForegroundColor Green
    } else {
        Write-Host "Pattern '$pattern' failed" -ForegroundColor Red
    }
}