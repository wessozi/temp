# Test script for comprehensive functionality testing
Import-Module .\AnimeOrganizer\Modules\AnimeOrganizer.FileParser.psm1 -Force
Import-Module .\AnimeOrganizer\Modules\AnimeOrganizer.FileOperations.psm1 -Force

# Test 1: Comma removal in Get-SafeFileName
Write-Host "=== TEST 1: Comma Removal ===" -ForegroundColor Green
$testCases = @(
    "Please.Put.Them.On,.Takamine-san.S01E11.I'll.Let.You.Do.a.Dry.Run.mkv",
    "Series,With,Commas.S01E01.Episode,Name.mkv",
    "Normal.File.Without.Commas.mkv"
)

foreach ($testCase in $testCases) {
    $result = Get-SafeFileName -FileName $testCase
    Write-Host "Input:  $testCase" -ForegroundColor Gray
    Write-Host "Output: $result" -ForegroundColor Cyan
    Write-Host "-" * 60
}

# Test 2: Version conflict resolution simulation
Write-Host "`n=== TEST 2: Version Conflict Resolution ===" -ForegroundColor Green

# Simulate the conflict scenario
$operation = [PSCustomObject]@{
    OriginalFile = "Haite Kudasai, Takamine-san - S01E11 v2 - I'll Let You Do a Dry Run.mkv"
    NewFileName = "Please.Put.Them.On.Takamine-san.S01E11.I'll.Let.You.Do.a.Dry.Run.mkv"
}

$targetDir = "test_dir"
$targetPath = Join-Path $targetDir $operation.NewFileName

# Create test directory and existing files
if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir | Out-Null }

# Create existing files that would cause conflicts
@(
    "Please.Put.Them.On.Takamine-san.S01E11.I'll.Let.You.Do.a.Dry.Run.mkv",  # v1 (no suffix)
    "Please.Put.Them.On.Takamine-san.S01E11.v2.I'll.Let.You.Do.a.Dry.Run.mkv" # v2
) | ForEach-Object {
    $testFile = Join-Path $targetDir $_
    if (-not (Test-Path $testFile)) {
        New-Item -ItemType File -Path $testFile | Out-Null
    }
}

Write-Host "Existing files in test directory:" -ForegroundColor Yellow
Get-ChildItem $targetDir | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Gray }

# Test the version resolution logic
Write-Host "`nTesting version resolution:" -ForegroundColor Yellow
$sourceEpisodeKey = if ($operation.NewFileName -match '(S\d{2}E\d{2})') { $Matches[1] } else { $null }
$targetEpisodeKey = if ((Split-Path $targetPath -Leaf) -match '(S\d{2}E\d{2})') { $Matches[1] } else { $null }

Write-Host "Source episode key: $sourceEpisodeKey" -ForegroundColor Gray
Write-Host "Target episode key: $targetEpisodeKey" -ForegroundColor Gray

if ($sourceEpisodeKey -and $targetEpisodeKey -and $sourceEpisodeKey -eq $targetEpisodeKey) {
    Write-Host "Duplicate episode conflict detected!" -ForegroundColor Red
    
    $baseName = $operation.NewFileName -replace '\.v\d+', ''
    $existingVersions = @()
    
    Get-ChildItem -Path $targetDir -Filter "*$sourceEpisodeKey*" | ForEach-Object {
        if ($_.Name -match '\.v(\d+)\.') {
            $existingVersions += [int]$Matches[1]
            Write-Host "Found version $($Matches[1]): $($_.Name)" -ForegroundColor Gray
        } elseif ($_.Name -match "$sourceEpisodeKey[^v]") {
            $existingVersions += 1
            Write-Host "Found version 1 (no suffix): $($_.Name)" -ForegroundColor Gray
        }
    }
    
    $nextVersion = if ($existingVersions.Count -gt 0) { ($existingVersions | Measure-Object -Maximum).Maximum + 1 } else { 2 }
    $newTargetName = $operation.NewFileName -replace '(\.\w+)$', ".v$nextVersion`$1"
    
    Write-Host "Next available version: v$nextVersion" -ForegroundColor Green
    Write-Host "Original target: $($operation.NewFileName)" -ForegroundColor Gray
    Write-Host "Resolved target: $newTargetName" -ForegroundColor Cyan
} else {
    Write-Host "Not a duplicate episode conflict" -ForegroundColor Yellow
}

# Cleanup
Remove-Item $targetDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n=== TEST COMPLETE ===" -ForegroundColor Green