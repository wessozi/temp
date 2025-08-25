# Test script to check versioning operations
Import-Module .\AnimeOrganizer\AnimeOrganizer.psm1 -Force

# Create test file objects to simulate the issue
$testFiles = @(
    [PSCustomObject]@{
        Name = "Please.Put.Them.On.Takamine-san.S01E11.v2.I'll.Let.You.Do.a.Dry.Run.mkv"
        FullName = "Z:\Media\NSFW\Haite Kudasai, Takamine-san [tvdb-452826]\Please.Put.Them.On.Takamine-san.S01E11.v2.I'll.Let.You.Do.a.Dry.Run.mkv"
        Extension = ".mkv"
        BaseName = "Please.Put.Them.On.Takamine-san.S01E11.v2.I'll.Let.You.Do.a.Dry.Run"
    },
    [PSCustomObject]@{
        Name = "Please.Put.Them.On.Takamine-san.S01E11.v2.v2.I'll.Let.You.Do.a.Dry.Run.mkv"
        FullName = "Z:\Media\NSFW\Haite Kudasai, Takamine-san [tvdb-452826]\Please.Put.Them.On.Takamine-san.S01E11.v2.v2.I'll.Let.You.Do.a.Dry.Run.mkv"
        Extension = ".mkv"
        BaseName = "Please.Put.Them.On.Takamine-san.S01E11.v2.v2.I'll.Let.You.Do.a.Dry.Run"
    },
    [PSCustomObject]@{
        Name = "Please.Put.Them.On.Takamine-san.S01E11.v3.I'll.Let.You.Do.a.Dry.Run.mkv"
        FullName = "Z:\Media\NSFW\Haite Kudasai, Takamine-san [tvdb-452826]\Please.Put.Them.On.Takamine-san.S01E11.v3.I'll.Let.You.Do.a.Dry.Run.mkv"
        Extension = ".mkv"
        BaseName = "Please.Put.Them.On.Takamine-san.S01E11.v3.I'll.Let.You.Do.a.Dry.Run"
    }
)

# Test duplicate detection
$duplicates = @{11 = $testFiles}

Write-Host "Testing versioning operations..." -ForegroundColor Green
Write-Host "Duplicate files:" -ForegroundColor Yellow
foreach ($file in $testFiles) {
    Write-Host "  - $($file.Name)" -ForegroundColor White
}

# Test temporary versioning
$versionOps = Apply-TemporaryVersioning -DuplicateGroups $duplicates

Write-Host "`nVersioning operations:" -ForegroundColor Yellow
foreach ($op in $versionOps) {
    Write-Host "  OriginalFile: '$($op.OriginalFile)'" -ForegroundColor White
    Write-Host "  SourcePath: '$($op.SourcePath)'" -ForegroundColor White
    Write-Host "  NewFileName: '$($op.NewFileName)'" -ForegroundColor White
    Write-Host "" -ForegroundColor Gray
}

Write-Host "Test completed." -ForegroundColor Green