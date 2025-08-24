# PlanManager.Tests.ps1
# Test script for the plan manager module

Write-Host "===== PLAN MANAGER MODULE TESTS =====" -ForegroundColor Cyan

# Import all required modules
$ModulesPath = Join-Path $PSScriptRoot "..\Modules"
Import-Module (Join-Path $ModulesPath "AnimeOrganizer.NamingConvention.psm1") -Force
Import-Module (Join-Path $ModulesPath "AnimeOrganizer.VersionManager.psm1") -Force
Import-Module (Join-Path $ModulesPath "AnimeOrganizer.StateAnalyzer.psm1") -Force
Import-Module (Join-Path $ModulesPath "AnimeOrganizer.PlanManager.psm1") -Force

Write-Host "All modules imported successfully" -ForegroundColor Green

# Test 1: Complete plan building
Write-Host "`nTEST 1: Complete plan building" -ForegroundColor Yellow

# Mock data for testing
$mockSeriesInfo = @{ name = "Test Series" }
$mockEpisodes = @(
    @{ name = "Episode 1 Title" },
    @{ name = "Episode 2 Title" },
    @{ name = "Episode 3 Title" }
)

# Mock video files with various states
$mockVideoFiles = @(
    # Already correct file
    [PSCustomObject]@{ 
        Name = "Test.Series.S01E01.Episode.1.Title.mkv"
        BaseName = "Test.Series.S01E01.Episode.1.Title"
        Extension = ".mkv"
        FullName = "C:\test\Test.Series.S01E01.Episode.1.Title.mkv"
    },
    # File needing rename (won't be parsed due to format)
    [PSCustomObject]@{ 
        Name = "Original Name - 02 - Some Title.mkv"
        BaseName = "Original Name - 02 - Some Title"
        Extension = ".mkv"
        FullName = "C:\test\Original Name - 02 - Some Title.mkv"
    }
)

$convention = Import-NamingConvention

# Build complete plan
$plan = Build-CompletePlan -VideoFiles $mockVideoFiles -Episodes $mockEpisodes -SeriesInfo $mockSeriesInfo -NamingConvention $convention

Write-Host "Plan created successfully" -ForegroundColor Green
Write-Host "  Total operations: $($plan.Operations.Skip.Count + $plan.Operations.Rename.Count + $plan.Operations.Versioning.Count)" -ForegroundColor White

# Test 2: Plan validation
Write-Host "`nTEST 2: Plan validation" -ForegroundColor Yellow
if ($plan.Validation.IsValid) {
    Write-Host "✓ Plan validation passed" -ForegroundColor Green
} else {
    Write-Host "✗ Plan validation failed:" -ForegroundColor Red
    foreach ($issue in $plan.Validation.Issues) {
        Write-Host "  • $issue" -ForegroundColor Red
    }
}

# Test 3: Preview display
Write-Host "`nTEST 3: Preview display" -ForegroundColor Yellow
Show-OperationPreview -Plan $plan

# Test 4: Plan execution (dry run)
Write-Host "`nTEST 4: Plan execution (dry run)" -ForegroundColor Yellow
$results = Execute-OperationPlan -Plan $plan -DryRun

if ($results.Success) {
    Write-Host "✓ Dry run completed successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Dry run had errors" -ForegroundColor Red
}

# Test 5: Plan summary
Write-Host "`nTEST 5: Plan summary" -ForegroundColor Yellow
$summary = Get-PlanSummary -Plan $plan
Write-Host "Summary: $summary" -ForegroundColor White

Write-Host "`n===== PLAN MANAGER TESTS COMPLETE =====" -ForegroundColor Cyan
Write-Host "Phase 4 testing finished. Check results above." -ForegroundColor White