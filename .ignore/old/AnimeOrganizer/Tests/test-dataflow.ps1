# Test script to check data flow for versioning operations
Import-Module .\AnimeOrganizer\AnimeOrganizer.psm1 -Force

# Create test file objects to simulate the issue
$testFiles = @(
    [PSCustomObject]@{
        Name = "Please.Put.Them.On.Takamine-san.S01E11.v2.I'll.Let.You.Do.a.Dry.Run.mkv"
        FullName = "Z:\Media\NSFW\Haite Kudasai, Takamine-san [tvdb-452826]\Please.Put.Them.On.Takamine-san.S01E11.v2.I'll.Let.You.Do.a.Dry.Run.mkv"
        Extension = ".mkv"
        BaseName = "Please.Put.Them.On.Takamine-san.S01E11.v2.I'll.Let.You.Do.a.Dry.Run"
    }
)

# Test duplicate detection
$duplicates = @{11 = $testFiles}

Write-Host "Testing data flow for versioning operations..." -ForegroundColor Green

# Test versioning operations creation
$versionOps = Apply-TemporaryVersioning -DuplicateGroups $duplicates

Write-Host "Versioning operations created:" -ForegroundColor Yellow
foreach ($op in $versionOps) {
    Write-Host "  OriginalFile: '$($op.OriginalFile)'" -ForegroundColor White
    Write-Host "  SourcePath: '$($op.SourcePath)'" -ForegroundColor White
    Write-Host "  NewFileName: '$($op.NewFileName)'" -ForegroundColor White
    Write-Host "" -ForegroundColor Gray
}

# Test the main module's operation creation logic
$operations = @()
foreach ($op in $versionOps) {
    $operations += [PSCustomObject]@{
        OriginalFile = $op.OriginalFile
        SourcePath = if ($op.SourcePath) { $op.SourcePath } else { $op.OriginalFile }
        NewFileName = $op.NewFileName
        TargetFolder = "."
        EpisodeNumber = $op.EpisodeNumber
        EpisodeName = "Test Episode"
        OperationType = $op.OperationType
    }
}

Write-Host "Operations after main module processing:" -ForegroundColor Yellow
foreach ($op in $operations) {
    Write-Host "  OriginalFile: '$($op.OriginalFile)'" -ForegroundColor White
    Write-Host "  SourcePath: '$($op.SourcePath)'" -ForegroundColor White
    Write-Host "  NewFileName: '$($op.NewFileName)'" -ForegroundColor White
    Write-Host "" -ForegroundColor Gray
}

Write-Host "Test completed." -ForegroundColor Green