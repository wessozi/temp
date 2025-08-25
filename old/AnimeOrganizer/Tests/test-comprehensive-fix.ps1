# Comprehensive test to verify all fixes are working
Import-Module .\AnimeOrganizer\AnimeOrganizer.psm1 -Force

# Create test file objects that simulate the problematic files
$testFiles = @(
    [PSCustomObject]@{
        Name = "Please.Put.Them.On.Takamine-san.S01E11.v2.I'll.Let.You.Do.a.Dry.Run.mkv"
        FullName = "Z:\Media\NSFW\Haite Kudasai, Takamine-san [tvdb-452826]\Please.Put.Them.On.Takamine-san.S01E11.v2.I'll.Let.You.Do.a.Dry.Run.mkv"
        Extension = ".mkv"
        BaseName = "Please.Put.Them.On.Takamine-san.S01E11.v2.I'll.Let.You.Do.a.Dry.Run"
        Length = 1024MB
    },
    [PSCustomObject]@{
        Name = "Please.Put.Them.On.Takamine-san.S01E11.v2.v2.I'll.Let.You.Do.a.Dry.Run.mkv"
        FullName = "Z:\Media\NSFW\Haite Kudasai, Takamine-san [tvdb-452826]\Please.Put.Them.On.Takamine-san.S01E11.v2.v2.I'll.Let.You.Do.a.Dry.Run.mkv"
        Extension = ".mkv"
        BaseName = "Please.Put.Them.On.Takamine-san.S01E11.v2.v2.I'll.Let.You.Do.a.Dry.Run"
        Length = 1024MB
    },
    [PSCustomObject]@{
        Name = "Please.Put.Them.On.Takamine-san.S01E11.v3.I'll.Let.You.Do.a.Dry.Run.mkv"
        FullName = "Z:\Media\NSFW\Haite Kudasai, Takamine-san [tvdb-452826]\Please.Put.Them.On.Takamine-san.S01E11.v3.I'll.Let.You.Do.a.Dry.Run.mkv"
        Extension = ".mkv"
        BaseName = "Please.Put.Them.On.Takamine-san.S01E11.v3.I'll.Let.You.Do.a.Dry.Run"
        Length = 1024MB
    }
)

# Mock series info and episodes for testing
$seriesInfo = [PSCustomObject]@{
    name = "Please Put Them On, Takamine-san"
    id = 452826
    year = 2024
}

$episodes = @(
    [PSCustomObject]@{
        number = 11
        name = "I'll Let You Do a Dry Run"
        seasonNumber = 1
    }
)

# Import naming convention
$namingConvention = Import-NamingConvention

Write-Host "=== COMPREHENSIVE TEST ===" -ForegroundColor Green
Write-Host "Testing double versioning fix and null path resolution" -ForegroundColor Yellow
Write-Host ""

# Test 1: Version detection in VersionManager
Write-Host "1. Testing version detection..." -ForegroundColor Cyan
$duplicates = @{11 = $testFiles}
$versionOps = Apply-TemporaryVersioning -DuplicateGroups $duplicates

Write-Host "   Versioning operations created:" -ForegroundColor White
foreach ($op in $versionOps) {
    Write-Host "   - $($op.OriginalFile) -> $($op.NewFileName) (v$($op.VersionNumber))" -ForegroundColor Gray
}

# Test 2: Main module operation creation
Write-Host ""
Write-Host "2. Testing main module operation creation..." -ForegroundColor Cyan
$operations = @()
foreach ($op in $versionOps) {
    $operations += [PSCustomObject]@{
        OriginalFile = $op.OriginalFile
        SourcePath = if ($op.SourcePath) { $op.SourcePath } else { $op.OriginalFile }
        NewFileName = $op.NewFileName
        TargetFolder = "."
        EpisodeNumber = $op.EpisodeNumber
        EpisodeName = "I'll Let You Do a Dry Run"
        OperationType = $op.OperationType
        Status = "Ready"
    }
}

Write-Host "   Operations with SourcePath fallback:" -ForegroundColor White
foreach ($op in $operations) {
    $hasSourcePath = -not [string]::IsNullOrEmpty($op.SourcePath)
    $hasOriginalFile = -not [string]::IsNullOrEmpty($op.OriginalFile)
    Write-Host "   - SourcePath: $hasSourcePath, OriginalFile: $hasOriginalFile" -ForegroundColor $(if ($hasSourcePath -and $hasOriginalFile) { "Green" } else { "Red" })
}

# Test 3: UI Preview
Write-Host ""
Write-Host "3. Testing UI preview..." -ForegroundColor Cyan
$plan = [PSCustomObject]@{
    Operations = $operations
    Statistics = [PSCustomObject]@{ total_files = 3 }
    Validation = [PSCustomObject]@{ IsValid = $true }
    SeriesInfo = $seriesInfo
    TotalOperations = $operations.Count
}

Show-OperationPreview -Plan $plan

# Test 4: Execution plan
Write-Host ""
Write-Host "4. Testing execution plan..." -ForegroundColor Cyan
$result = Execute-OperationPlan -Plan $plan -DryRun
Write-Host "   Dry run result: $($result.Success)" -ForegroundColor $(if ($result.Success) { "Green" } else { "Red" })

Write-Host ""
Write-Host "=== TEST COMPLETED ===" -ForegroundColor Green
Write-Host "Double versioning should be fixed and null path errors resolved." -ForegroundColor Yellow