# AnimeOrganizer.VersionManager.psm1
# Handles duplicate episode versioning and conflict resolution

function Detect-DuplicateEpisodes {
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
    
    # Group files by episode number
    $episodeGroups = @{}
    
    foreach ($file in $VideoFiles) {
        $parseResult = Parse-EpisodeNumber -FileName $file.Name
        if ($parseResult -and $parseResult.EpisodeNumber -gt 0 -and $parseResult.EpisodeNumber -le $Episodes.Count) {
            $episodeNum = $parseResult.EpisodeNumber
            
            if (-not $episodeGroups.ContainsKey($episodeNum)) {
                $episodeGroups[$episodeNum] = @()
            }
            $episodeGroups[$episodeNum] += $file
        }
    }
    
    # Find duplicates (episodes with more than one file)
    $duplicates = @{}
    foreach ($episodeNum in $episodeGroups.Keys) {
        if ($episodeGroups[$episodeNum].Count -gt 1) {
            $duplicates[$episodeNum] = $episodeGroups[$episodeNum]
        }
    }
    
    return $duplicates
}

function Enter-VersioningMode {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$DuplicateGroups,
        
        [Parameter(Mandatory=$true)]
        [string]$Mode,
        
        [Parameter(Mandatory=$true)]
        [object]$SeriesInfo,
        
        [Parameter(Mandatory=$true)]
        [array]$Episodes,
        
        [Parameter(Mandatory=$true)]
        [object]$NamingConvention
    )
    
    Write-Host "[VERSIONING] Found $($DuplicateGroups.Keys.Count) episodes with duplicates" -ForegroundColor Yellow
    
    switch ($Mode) {
        "temporary" {
            Write-Host "[VERSIONING] Using two-step temporary versioning" -ForegroundColor Cyan
            return Apply-TemporaryVersioning -DuplicateGroups $DuplicateGroups
        }
        "direct" {
            Write-Host "[VERSIONING] Using direct versioning" -ForegroundColor Cyan
            return Apply-DirectVersioning -DuplicateGroups $DuplicateGroups -SeriesInfo $SeriesInfo -Episodes $Episodes -NamingConvention $NamingConvention
        }
        default {
            Write-Warning "Unknown versioning mode: $Mode, using temporary"
            return Apply-TemporaryVersioning -DuplicateGroups $DuplicateGroups
        }
    }
}

function Apply-TemporaryVersioning {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$DuplicateGroups
    )
    
    $tempOperations = @()
    
    foreach ($episodeNum in $DuplicateGroups.Keys) {
        $files = $DuplicateGroups[$episodeNum]
        Write-Host "[TEMP] Episode $episodeNum has $($files.Count) files" -ForegroundColor White
        
        for ($i = 0; $i -lt $files.Count; $i++) {
            $file = $files[$i]
            $tempSuffix = "z$($i + 1)"
            $tempName = "$($file.BaseName).$tempSuffix$($file.Extension)"
            
            $tempOperations += [PSCustomObject]@{
                OriginalFile = $file.Name
                SourcePath = $file.FullName
                NewFileName = $tempName
                TargetFolder = "."
                OperationType = "TemporaryVersioning"
                EpisodeNumber = $episodeNum
                VersionNumber = $i + 1
                TempSuffix = $tempSuffix
            }
        }
    }
    
    return $tempOperations
}

function Apply-DirectVersioning {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$DuplicateGroups,
        
        [Parameter(Mandatory=$true)]
        [object]$SeriesInfo,
        
        [Parameter(Mandatory=$true)]
        [array]$Episodes,
        
        [Parameter(Mandatory=$true)]
        [object]$NamingConvention
    )
    
    $versionedOperations = @()
    
    foreach ($episodeNum in $DuplicateGroups.Keys) {
        $files = $DuplicateGroups[$episodeNum]
        $episode = $Episodes[$episodeNum - 1]
        
        for ($i = 0; $i -lt $files.Count; $i++) {
            $file = $files[$i]
            
            # Generate base name using naming convention
            $baseName = Format-SeriesEpisodeName `
                -SeriesInfo $SeriesInfo `
                -SeasonNumber 1 `
                -EpisodeNumber $episodeNum `
                -EpisodeInfo $episode `
                -FileExtension $file.Extension `
                -Convention $NamingConvention
            
            # Apply versioning
            $versionNumber = $i + 1
            $versionedName = Format-VersionedName -BaseName $baseName -VersionNumber $versionNumber -Convention $NamingConvention
            
            $versionedOperations += [PSCustomObject]@{
                OriginalFile = $file.Name
                SourcePath = $file.FullName
                NewFileName = $versionedName
                TargetFolder = "."
                OperationType = "DirectVersioning"
                EpisodeNumber = $episodeNum
                VersionNumber = $versionNumber
            }
        }
    }
    
    return $versionedOperations
}

function Apply-FinalVersioning {
    param(
        [Parameter(Mandatory=$true)]
        [array]$TemporaryFiles,
        
        [Parameter(Mandatory=$true)]
        [object]$SeriesInfo,
        
        [Parameter(Mandatory=$true)]
        [array]$Episodes,
        
        [Parameter(Mandatory=$true)]
        [object]$NamingConvention
    )
    
    $finalOperations = @()
    
    foreach ($tempOperation in $TemporaryFiles) {
        if ($tempOperation.OperationType -eq "TemporaryVersioning") {
            $episodeNum = $tempOperation.EpisodeNumber
            $versionNum = $tempOperation.VersionNumber
            $episode = $Episodes[$episodeNum - 1]
            
            # Generate final name
            $baseName = Format-SeriesEpisodeName `
                -SeriesInfo $SeriesInfo `
                -SeasonNumber 1 `
                -EpisodeNumber $episodeNum `
                -EpisodeInfo $episode `
                -FileExtension ([System.IO.Path]::GetExtension($tempOperation.NewFileName)) `
                -Convention $NamingConvention
            
            $finalName = Format-VersionedName -BaseName $baseName -VersionNumber $versionNum -Convention $NamingConvention
            
            $finalOperations += [PSCustomObject]@{
                OriginalFile = $tempOperation.NewFileName  # Now using temp name as source
                SourcePath = Join-Path (Split-Path $tempOperation.SourcePath) $tempOperation.NewFileName
                NewFileName = $finalName
                TargetFolder = "."
                OperationType = "FinalVersioning"
                EpisodeNumber = $episodeNum
                VersionNumber = $versionNum
            }
        }
    }
    
    return $finalOperations
}

function Resolve-ExistingVersions {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Files,
        
        [Parameter(Mandatory=$true)]
        [string]$BaseName
    )
    
    $existingVersions = @()
    
    foreach ($file in $Files) {
        $versionMatch = Parse-ExistingVersionNumber -FileName $file.Name -BaseName $BaseName
        if ($versionMatch) {
            $existingVersions += $versionMatch
        }
    }
    
    # Sort versions and find next available
    $existingVersions = $existingVersions | Sort-Object
    $nextVersion = 1
    
    foreach ($version in $existingVersions) {
        if ($version -eq $nextVersion) {
            $nextVersion++
        } else {
            break
        }
    }
    
    return $nextVersion
}

function Parse-ExistingVersionNumber {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileName,
        
        [Parameter(Mandatory=$true)]
        [string]$BaseName
    )
    
    # Look for version patterns like .v1, .v2, .z1, .z2
    if ($FileName -match "\.v(\d+)") {
        return [int]$matches[1]
    }
    
    if ($FileName -match "\.z(\d+)") {
        return [int]$matches[1]
    }
    
    return $null
}

function Get-VersioningConfig {
    $configPath = Join-Path $PSScriptRoot "..\Config\settings.json"
    
    if (-not (Test-Path $configPath)) {
        return Get-DefaultVersioningConfig
    }
    
    try {
        $config = Get-Content $configPath | ConvertFrom-Json
        return $config.versioning
    }
    catch {
        Write-Warning "Error loading versioning config: $($_.Exception.Message)"
        return Get-DefaultVersioningConfig
    }
}

function Get-DefaultVersioningConfig {
    return @{
        mode = "temporary"
        temporary_suffix = "z"
        version_format = "v"
        auto_process_step2 = $true
        prompt_user = $true
    }
}

function Show-DuplicateAnalysis {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$DuplicateGroups
    )
    
    Write-Host "`n=== DUPLICATE EPISODE ANALYSIS ===" -ForegroundColor Red
    
    foreach ($episodeNum in ($DuplicateGroups.Keys | Sort-Object)) {
        $files = $DuplicateGroups[$episodeNum]
        Write-Host "Episode $episodeNum has $($files.Count) files:" -ForegroundColor Yellow
        
        for ($i = 0; $i -lt $files.Count; $i++) {
            $file = $files[$i]
            $size = if ($file.Length) { "$([math]::Round($file.Length / 1MB, 1)) MB" } else { "Unknown" }
            Write-Host "  [$($i+1)] $($file.Name) ($size)" -ForegroundColor White
        }
    }
    
    Write-Host "=== END DUPLICATE ANALYSIS ===`n" -ForegroundColor Red
}

# Import required function (placeholder - will be provided by main system)
function Parse-EpisodeNumber {
    param([string]$FileName)
    # This will be imported from the main parsing system
    # Placeholder implementation
    if ($FileName -match 'S\d+E(\d+)') {
        return @{ EpisodeNumber = [int]$matches[1] }
    }
    return $null
}

# Export all functions
Export-ModuleMember -Function Detect-DuplicateEpisodes, Enter-VersioningMode, Apply-TemporaryVersioning, Apply-DirectVersioning, Apply-FinalVersioning, Resolve-ExistingVersions, Parse-ExistingVersionNumber, Get-VersioningConfig, Show-DuplicateAnalysis