# VersionManager.Tests.ps1
# Test script for the version manager module

Write-Host "===== VERSION MANAGER MODULE TESTS =====" -ForegroundColor Cyan

# Import modules
$NamingModulePath = Join-Path $PSScriptRoot "..\Modules\AnimeOrganizer.NamingConvention.psm1"
$VersionModulePath = Join-Path $PSScriptRoot "..\Modules\AnimeOrganizer.VersionManager.psm1"

Import-Module $NamingModulePath -Force
Import-Module $VersionModulePath -Force

Write-Host "Modules imported successfully" -ForegroundColor Green

# Test 1: Version config loading
Write-Host "`nTEST 1: Version config loading" -ForegroundColor Yellow
$versionConfig = Get-VersioningConfig
Write-Host "Versioning mode: $($versionConfig.mode)" -ForegroundColor White
Write-Host "Temporary suffix: $($versionConfig.temporary_suffix)" -ForegroundColor White

# Test 2: Parse existing version numbers
Write-Host "`nTEST 2: Parse existing version numbers" -ForegroundColor Yellow
$testFiles = @(
    "Series.Name.S01E01.Episode.v1.mkv",
    "Series.Name.S01E01.Episode.v2.mkv",
    "Series.Name.S01E01.Episode.z1.mkv"
)

foreach ($fileName in $testFiles) {
    $version = Parse-ExistingVersionNumber -FileName $fileName -BaseName "Series.Name.S01E01.Episode"
    Write-Host "File: $fileName -> Version: $version" -ForegroundColor White
}

# Test 3: Temporary versioning simulation
Write-Host "`nTEST 3: Temporary versioning simulation" -ForegroundColor Yellow

# Create mock file objects for testing
$mockFiles = @(
    [PSCustomObject]@{ Name = "file1.mkv"; BaseName = "file1"; Extension = ".mkv"; FullName = "C:\test\file1.mkv" },
    [PSCustomObject]@{ Name = "file2.mkv"; BaseName = "file2"; Extension = ".mkv"; FullName = "C:\test\file2.mkv" },
    [PSCustomObject]@{ Name = "file3.mkv"; BaseName = "file3"; Extension = ".mkv"; FullName = "C:\test\file3.mkv" }
)

# Mock duplicate groups (all files for episode 1)
$duplicateGroups = @{
    1 = $mockFiles
}

$tempOps = Apply-TemporaryVersioning -DuplicateGroups $duplicateGroups

Write-Host "Temporary operations generated:" -ForegroundColor White
foreach ($op in $tempOps) {
    Write-Host "  $($op.OriginalFile) -> $($op.NewFileName)" -ForegroundColor White
}

if ($tempOps.Count -eq 3 -and $tempOps[0].NewFileName -eq "file1.z1.mkv") {
    Write-Host "✓ Temporary versioning works correctly" -ForegroundColor Green
} else {
    Write-Host "✗ Temporary versioning failed" -ForegroundColor Red
}

# Test 4: Version number resolution
Write-Host "`nTEST 4: Version number resolution" -ForegroundColor Yellow
$testBaseName = "Series.S01E01.Episode"
$mockExistingFiles = @(
    [PSCustomObject]@{ Name = "$testBaseName.v1.mkv" },
    [PSCustomObject]@{ Name = "$testBaseName.v2.mkv" }
)

$nextVersion = Resolve-ExistingVersions -Files $mockExistingFiles -BaseName $testBaseName
Write-Host "Next available version: $nextVersion" -ForegroundColor White

if ($nextVersion -eq 3) {
    Write-Host "✓ Version resolution works correctly" -ForegroundColor Green
} else {
    Write-Host "✗ Version resolution failed (expected 3, got $nextVersion)" -ForegroundColor Red
}

Write-Host "`n===== VERSION MANAGER TESTS COMPLETE =====" -ForegroundColor Cyan
Write-Host "Phase 2 testing finished. Check results above." -ForegroundColor White