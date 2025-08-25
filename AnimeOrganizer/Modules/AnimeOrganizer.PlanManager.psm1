# AnimeOrganizer.PlanManager.psm1
# Comprehensive planning and preview system

# Import required modules
function Import-RequiredModules {
    if (-not (Get-Command "Show-Preview" -ErrorAction SilentlyContinue)) {
        $uiModulePath = Join-Path $PSScriptRoot "AnimeOrganizer.UserInterface.psm1"
        if (Test-Path $uiModulePath) {
            Import-Module $uiModulePath -Force
        }
    }
    
    if (-not (Get-Command "Get-AnalysisStatistics" -ErrorAction SilentlyContinue)) {
        $analyzerPath = Join-Path $PSScriptRoot "AnimeOrganizer.StateAnalyzer.psm1"
        if (Test-Path $analyzerPath) {
            Import-Module $analyzerPath -Force
        }
    }
}

function Build-CompletePlan {
    param(
        [Parameter(Mandatory=$true)]
        [array]$VideoFiles,
        [Parameter(Mandatory=$true)]
        [array]$Episodes,
        [Parameter(Mandatory=$true)]
        [object]$SeriesInfo,
        [Parameter(Mandatory=$true)]
        [object]$NamingConvention
    )
    
    Import-RequiredModules
    
    Write-Host "[PLANNING] Building comprehensive operation plan..." -ForegroundColor Green
    
    # Analyze file states
    $analysis = Analyze-FileStates -VideoFiles $VideoFiles -Episodes $Episodes -SeriesInfo $SeriesInfo -NamingConvention $NamingConvention
    
    # Build operations
    $operations = @()
    
    # Add skip operations
    foreach ($fileData in $analysis.skip) {
        $operations += [PSCustomObject]@{
            OperationType = "Skip"
            OriginalFile = $fileData.OriginalName
            NewFileName = $fileData.TargetName
            TargetFolder = "."
            EpisodeNumber = $fileData.EpisodeNumber
            EpisodeName = if ($fileData.EpisodeInfo) { $fileData.EpisodeInfo.name } else { "Unknown" }
            Status = "Already Correct"
        }
    }
    
    # Add rename operations
    if ($analysis.rename.Count -gt 0) {
        $renameOps = Build-RenameOperations -FilesToRename $analysis.rename
        foreach ($op in $renameOps) {
            $operations += [PSCustomObject]@{
                OperationType = "Rename"
                OriginalFile = $op.OriginalFile
                NewFileName = $op.NewFileName
                TargetFolder = $op.TargetFolder
                EpisodeNumber = $op.EpisodeNumber
                EpisodeName = if ($op.EpisodeInfo) { $op.EpisodeInfo.name } else { "Unknown" }
                Status = "Ready"
            }
        }
    }
    
    # Add versioning operations if any
    if ($analysis.duplicates.Keys.Count -gt 0) {
        $versioningConfig = Get-VersioningConfig
        $versionOps = Enter-VersioningMode -DuplicateGroups $analysis.duplicates -Mode $versioningConfig.mode -SeriesInfo $SeriesInfo -Episodes $Episodes -NamingConvention $NamingConvention
        
        foreach ($op in $versionOps) {
            $operations += [PSCustomObject]@{
                OperationType = $op.OperationType
                OriginalFile = $op.OriginalFile
                SourcePath = if ($op.SourcePath) { $op.SourcePath } else { $op.OriginalFile }
                NewFileName = $op.NewFileName
                TargetFolder = $op.TargetFolder
                EpisodeNumber = $op.EpisodeNumber
                EpisodeName = if ($op.EpisodeInfo) { $op.EpisodeInfo.name } else { "Unknown" }
                Status = "Ready"
                VersionNumber = if ($op.VersionNumber) { $op.VersionNumber } else { $null }
            }
        }
    }
    
    # Get statistics
    $stats = Get-AnalysisStatistics -Analysis $analysis
    
    return [PSCustomObject]@{
        Operations = $operations
        Statistics = $stats
        Validation = Validate-OperationPlan -Plan $operations
        SeriesInfo = $SeriesInfo
        TotalOperations = $operations.Count
    }
}

function Show-OperationPreview {
    param([Parameter(Mandatory=$true)][object]$Plan)
    
    Import-RequiredModules
    
    if ($Plan.Operations.Count -eq 0) {
        Write-Host "No operations to preview" -ForegroundColor Yellow
        return
    }
    
    # Use the existing UI module's preview function
    Show-Preview -Operations $Plan.Operations
}

function Get-PlanSummary {
    param([Parameter(Mandatory=$true)][object]$Plan)
    
    $stats = $Plan.Statistics
    $skipCount = ($Plan.Operations | Where-Object { $_.OperationType -eq "Skip" }).Count
    $renameCount = ($Plan.Operations | Where-Object { $_.OperationType -eq "Rename" }).Count
    $versionCount = ($Plan.Operations | Where-Object { $_.OperationType -match "Versioning" }).Count
    
    return "Total: $($stats.total_files) files | Skip: $skipCount | Rename: $renameCount | Versioning: $versionCount | Duplicates: $($stats.duplicate_episodes)"
}

function Validate-OperationPlan {
    param([Parameter(Mandatory=$true)][object]$Plan)
    
    $issues = @()
    
    # Check for null or empty paths
    foreach ($op in $Plan) {
        if ([string]::IsNullOrEmpty($op.OriginalFile)) {
            $issues += "Operation missing OriginalFile"
        }
        if ([string]::IsNullOrEmpty($op.NewFileName)) {
            $issues += "Operation missing NewFileName"
        }
        if ([string]::IsNullOrEmpty($op.TargetFolder)) {
            $issues += "Operation missing TargetFolder"
        }
    }
    
    return [PSCustomObject]@{
        IsValid = ($issues.Count -eq 0)
        Issues = $issues
        IssueCount = $issues.Count
    }
}

function Execute-OperationPlan {
    param(
        [Parameter(Mandatory=$true)]
        [object]$Plan,
        [switch]$DryRun
    )
    
    if (-not (Get-Command "Execute-FileOperations" -ErrorAction SilentlyContinue)) {
        $opsModulePath = Join-Path $PSScriptRoot "AnimeOrganizer.FileOperations.psm1"
        if (Test-Path $opsModulePath) {
            Import-Module $opsModulePath -Force
        }
    }
    
    if ($DryRun) {
        Write-Host "[DRY RUN] Would execute $($Plan.Operations.Count) operations" -ForegroundColor Cyan
        return [PSCustomObject]@{ Success = $true; DryRun = $true }
    }
    
    # Convert plan operations to file operations format
    $fileOperations = @()
    foreach ($op in $Plan.Operations) {
        if ($op.OperationType -ne "Skip") {
            $fileOperations += [PSCustomObject]@{
                OriginalFile = $op.OriginalFile
                SourcePath = if ($op.SourcePath) { $op.SourcePath } else { $op.OriginalFile }
                NewFileName = $op.NewFileName
                TargetFolder = $op.TargetFolder
                EpisodeNumber = $op.EpisodeNumber
                EpisodeInfo = if ($op.EpisodeName -ne "Unknown") { @{ name = $op.EpisodeName } } else { $null }
            }
        }
    }
    
    if ($fileOperations.Count -eq 0) {
        Write-Host "[INFO] No file operations to execute" -ForegroundColor Yellow
        return [PSCustomObject]@{ Success = $true; OperationsExecuted = 0 }
    }
    
    # Execute operations
    $success = Execute-FileOperations -Operations $fileOperations -WorkingDirectory (Get-Location).Path
    
    return [PSCustomObject]@{
        Success = $success
        OperationsExecuted = $fileOperations.Count
        TotalOperations = $Plan.Operations.Count
    }
}

Export-ModuleMember -Function Build-CompletePlan, Show-OperationPreview, Get-PlanSummary, Validate-OperationPlan, Execute-OperationPlan