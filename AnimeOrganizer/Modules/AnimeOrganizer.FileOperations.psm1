# AnimeOrganizer.FileOperations.psm1 - File System Operations Module
# Phase 3: File Operations - Extracted from original Anime-File-Organizer.ps1

# Import logging with fallbacks
function Write-InfoLogFallback {
    param([string]$Message, [string]$Category = "FileOperations")
    if (Get-Command "Write-InfoLog" -ErrorAction SilentlyContinue) {
        Write-InfoLog -Message $Message -Category $Category
    } else {
        Write-Host "[INFO] $Message" -ForegroundColor White
    }
}

function Write-ErrorLogFallback {
    param([string]$Message, [string]$Category = "FileOperations")
    if (Get-Command "Write-ErrorLog" -ErrorAction SilentlyContinue) {
        Write-ErrorLog -Message $Message -Category $Category
    } else {
        Write-Host "[ERROR] $Message" -ForegroundColor Red
    }
}

function Write-DebugLogFallback {
    param([string]$Message, [string]$Category = "FileOperations")
    if (Get-Command "Write-DebugLog" -ErrorAction SilentlyContinue) {
        Write-DebugLog -Message $Message -Category $Category
    } else {
        # Only show debug if debug mode is enabled in config
        $config = Get-AnimeOrganizerConfig
        if ($config -and $config.behavior -and $config.behavior.debug_mode) {
            Write-Host "[DEBUG] $Message" -ForegroundColor Gray
        }
    }
}

# Load configuration
function Get-AnimeOrganizerConfig {
    $configPath = Join-Path $PSScriptRoot "..\..\Config\settings.json"
    if (Test-Path $configPath) {
        return Get-Content $configPath | ConvertFrom-Json
    } else {
        # Fallback configuration
        return @{
            files = @{
                extensions = @(".mkv", ".mp4", ".avi", ".m4v", ".wmv", ".flv", ".webm")
                skip_folders = @("Extras")
            }
            behavior = @{
                debug_mode = $true
            }
        }
    }
}

function Find-VideoFiles {
    param([string]$Directory)
    
    Write-Host "[SCAN] Scanning for video files (including subdirectories)..." -ForegroundColor Yellow
    Write-Host "[INFO] Ignoring 'Extras' folders (contain random content like openings/endings)" -ForegroundColor Cyan
    
    $config = Get-AnimeOrganizerConfig
    $VideoExtensions = $config.files.extensions
    $SkipFolders = $config.files.skip_folders
    
    $videoFiles = Get-ChildItem -LiteralPath $Directory -File -Recurse | Where-Object { 
        # Skip files in skip folders (case-insensitive)
        $relativePath = $_.FullName.Replace($Directory, "").TrimStart("\")
        foreach ($skipFolder in $SkipFolders) {
            if ($relativePath -match "(?i)(?:^|\\)$skipFolder(?:$|\\)") {
                Write-DebugLogFallback "Skipping file in $skipFolder folder: $relativePath"
                return $false
            }
        }
        
        # Only include video files
        return $VideoExtensions -contains $_.Extension.ToLower()
    } | Sort-Object FullName
    
    if ($videoFiles.Count -eq 0) {
        Write-Host "[ERROR] No video files found in directory or subdirectories" -ForegroundColor Red
        Write-ErrorLogFallback "No video files found in directory: $Directory"
        return @()
    }
    
    Write-Host "[SUCCESS] Found $($videoFiles.Count) video files" -ForegroundColor Green
    Write-InfoLogFallback "Found $($videoFiles.Count) video files in directory: $Directory"
    
    foreach ($file in $videoFiles) {
        $relativePath = $file.FullName.Replace("$Directory\", "")
        Write-Host "  - $relativePath" -ForegroundColor Gray
    }
    
    return $videoFiles
}

function Execute-FileOperations {
    param($Operations, $WorkingDirectory)
    
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "                        EXECUTING FILE OPERATIONS                      " -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host ""
    
    $successCount = 0
    $errorCount = 0
    $folderCreateCount = 0
    
    Write-DebugLogFallback "Starting execution of $($Operations.Count) operations"
    Write-InfoLogFallback "Starting file operations for $($Operations.Count) files"
    
    # Create folders first
    $foldersToCreate = $Operations | Select-Object -ExpandProperty TargetFolder | Sort-Object -Unique
    Write-DebugLogFallback "Need to create $($foldersToCreate.Count) unique folders"
    
    foreach ($folder in $foldersToCreate) {
        if ($folder -eq ".") { continue }  # Skip current directory
        
        $fullPath = [System.IO.Path]::Combine($WorkingDirectory, $folder)
        Write-DebugLogFallback "Checking folder: $fullPath"
        
        if (-not (Test-Path -LiteralPath $fullPath)) {
            try {
                # Use safe file operation if available
                if (Get-Command "Invoke-SafeFileOperation" -ErrorAction SilentlyContinue) {
                    Invoke-SafeFileOperation -OperationName "Create Folder: $folder" -FileOperation {
                        New-Item -LiteralPath $fullPath -ItemType Directory -Force | Out-Null
                    } -SourcePath $WorkingDirectory -DestinationPath $fullPath
                } else {
                    New-Item -LiteralPath $fullPath -ItemType Directory -Force | Out-Null
                }
                
                Write-Host "[SUCCESS] Created folder: $folder" -ForegroundColor Green
                Write-InfoLogFallback "Successfully created folder: $fullPath"
                $folderCreateCount++
            }
            catch {
                Write-Host "[ERROR] Failed to create folder $folder : $($_.Exception.Message)" -ForegroundColor Red
                Write-ErrorLogFallback "Failed to create folder $fullPath - $($_.Exception.Message)"
                $errorCount++
                return $false
            }
        } else {
            Write-DebugLogFallback "Folder already exists: $fullPath"
        }
    }
    
    Write-Host ""
    Write-Host "[INFO] Starting file operations..." -ForegroundColor Cyan
    Write-Host ""
    
    # Move and rename files
    foreach ($operation in $Operations) {
        $sourcePath = $operation.SourcePath
        # Handle the case where TargetFolder is "." (current directory)
        if ($operation.TargetFolder -eq ".") {
            $targetPath = [System.IO.Path]::Combine($WorkingDirectory, $operation.NewFileName)
        } else {
            $targetPath = [System.IO.Path]::Combine($WorkingDirectory, $operation.TargetFolder, $operation.NewFileName)
        }
        
        Write-DebugLogFallback "Processing: $($operation.OriginalFile)"
        Write-DebugLogFallback "  Source: $sourcePath"
        Write-DebugLogFallback "  Target: $targetPath"
        
        try {            
            if (Test-Path -LiteralPath $sourcePath) {
                # Check if target already exists
                if (Test-Path -LiteralPath $targetPath) {
                    # Extract episode key from both filenames to check if this is a duplicate episode conflict
                    $sourceEpisodeKey = if ($operation.NewFileName -match '(S\d{2}E\d{2})') { $Matches[1] } else { $null }
                    $targetEpisodeKey = if ((Split-Path $targetPath -Leaf) -match '(S\d{2}E\d{2})') { $Matches[1] } else { $null }
                    
                    # Only apply versioning if this is a duplicate episode conflict
                    if ($sourceEpisodeKey -and $targetEpisodeKey -and $sourceEpisodeKey -eq $targetEpisodeKey) {
                        # Version resolution logic for duplicate episodes
                        $baseName = $operation.NewFileName -replace '\.v\d+', ''
                        $existingVersions = @()
                        
                        # Find all existing versions for this episode in the target directory
                        $targetDir = Split-Path $targetPath
                        Get-ChildItem -Path $targetDir -Filter "*$sourceEpisodeKey*" | ForEach-Object {
                            if ($_.Name -match '\.v(\d+)\.') {
                                $existingVersions += [int]$Matches[1]
                            } elseif ($_.Name -match "$sourceEpisodeKey[^v]") {
                                $existingVersions += 1  # No suffix = version 1
                            }
                        }
                        
                        $nextVersion = if ($existingVersions.Count -gt 0) { ($existingVersions | Measure-Object -Maximum).Maximum + 1 } else { 2 }
                        # Insert version number after episode number but before title
                        $newTargetName = $operation.NewFileName -replace '(S\d{2}E\d{2})\.', "`$1.v$nextVersion."
                        $newTargetPath = Join-Path $targetDir $newTargetName
                        
                        Write-Host "[VERSION] Duplicate episode conflict resolved: $($operation.NewFileName) -> $newTargetName" -ForegroundColor Yellow
                        Write-DebugLogFallback "Version conflict resolved: $targetPath -> $newTargetPath"
                        
                        # Update target path for this operation
                        $targetPath = $newTargetPath
                    } else {
                        # Regular file conflict - skip with warning
                        Write-Host "[WARNING] Target file already exists: $($operation.NewFileName)" -ForegroundColor Yellow
                        Write-DebugLogFallback "Target file exists, skipping: $targetPath"
                        continue
                    }
                }
                
                # Use safe file operation if available
                if (Get-Command "Invoke-SafeFileOperation" -ErrorAction SilentlyContinue) {
                    Invoke-SafeFileOperation -OperationName "Move File: $($operation.OriginalFile)" -FileOperation {
                        Move-Item -LiteralPath $sourcePath -Destination $targetPath -ErrorAction Stop
                    } -SourcePath $sourcePath -DestinationPath $targetPath
                } else {
                    Move-Item -LiteralPath $sourcePath -Destination $targetPath -ErrorAction Stop
                }
                
                Write-Host "[SUCCESS] $($operation.OriginalFile) -> $($operation.NewFileName)" -ForegroundColor Green
                Write-InfoLogFallback "Successfully moved file: $($operation.OriginalFile) -> $($operation.NewFileName)"
                $successCount++
            } else {
                Write-Host "[ERROR] Source file not found: $($operation.OriginalFile)" -ForegroundColor Red
                Write-ErrorLogFallback "Source file not found: $sourcePath"
                $errorCount++
            }
        }
        catch {
            Write-Host "[ERROR] Failed to move $($operation.OriginalFile): $($_.Exception.Message)" -ForegroundColor Red
            Write-ErrorLogFallback "Move operation failed: $($_.Exception.Message)"
            $errorCount++
        }
    }
    
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "                           OPERATION SUMMARY                           " -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "Folders created: $folderCreateCount" -ForegroundColor Cyan
    Write-Host "Files moved successfully: $successCount" -ForegroundColor Green
    Write-Host "Errors encountered: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Green" })
    Write-Host "Total operations: $($Operations.Count)" -ForegroundColor White
    
    Write-InfoLogFallback "File operations completed - Success: $successCount, Errors: $errorCount, Folders: $folderCreateCount"
    
    if ($errorCount -eq 0) {
        Write-Host "[COMPLETE] All file operations completed successfully!" -ForegroundColor Green
        Write-InfoLogFallback "All operations completed without errors"
    } else {
        Write-Host "[WARNING] Some operations failed. Please check the errors above." -ForegroundColor Yellow
        Write-ErrorLogFallback "$errorCount operations failed"
    }
    
    return ($errorCount -eq 0)
}

function Write-OperationLog {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Operations,
        [Parameter(Mandatory=$true)]
        [string]$WorkingDirectory,
        [Parameter(Mandatory=$true)]
        [string]$SeriesName
    )
    
    if ($Operations.Count -eq 0) {
        Write-DebugLogFallback "No operations to log"
        return
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $safeSeriesName = Get-SafeFileName -FileName $SeriesName
    $logFileName = "rename_log_${safeSeriesName}_${timestamp}.txt"
    $logPath = [System.IO.Path]::Combine($WorkingDirectory, $logFileName)
    
    try {
        $logContent = @()
        $logContent += "# Anime File Organizer - Rename Log"
        $logContent += "# Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $logContent += "# Series: $SeriesName"
        $logContent += "# Total Operations: $($Operations.Count)"
        $logContent += ""
        
        foreach ($op in $Operations) {
            $originalPath = $op.OriginalFile
            if ($op.TargetFolder -eq ".") {
                $newPath = $op.NewFileName
            } else {
                $newPath = "$($op.TargetFolder)\$($op.NewFileName)"
            }
            $logContent += "$originalPath --> $newPath"
        }
        
        $logContent | Out-File -LiteralPath $logPath -Encoding UTF8
        Write-Host "[LOG] Created rename log: $logFileName" -ForegroundColor Green
        Write-InfoLogFallback "Rename log written to: $logPath"
        
    } catch {
        Write-Host "[WARNING] Failed to create rename log: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-ErrorLogFallback "Log creation error: $($_.Exception.Message)"
    }
}

function Rename-SeriesFolder {
    param($WorkingDirectory, $SeriesId, $EnglishSeriesName)
    
    $currentFolderName = Split-Path $WorkingDirectory -Leaf
    $tvdbPattern = '\[tvdb-\d+\]'
    
    if ($currentFolderName -match $tvdbPattern) {
        Write-Host "[INFO] Folder already has TVDB ID format: $currentFolderName" -ForegroundColor Green
        Write-InfoLogFallback "Folder already has TVDB ID format: $currentFolderName"
        return $WorkingDirectory
    }
    
    $cleanSeriesName = Get-SafeFileName -FileName $EnglishSeriesName
    $newFolderName = "$cleanSeriesName [tvdb-$SeriesId]"
    
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "                         FOLDER RENAME OPTION                          " -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "For optimal Hama scanner compatibility, the series folder can be renamed:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   FROM: $currentFolderName" -ForegroundColor Yellow
    Write-Host "     TO: $newFolderName" -ForegroundColor Green
    Write-Host ""
    
    do {
        $choice = Read-Host "Rename folder for Hama compatibility? (Y/N, default: Y)"
        switch ($choice.ToUpper()) {
            "Y" {
                try {
                    $parentPath = Split-Path $WorkingDirectory -Parent
                    $newWorkingDirectory = [System.IO.Path]::Combine($parentPath, $newFolderName)
                    
                    Write-Host "[INFO] Renaming series folder..." -ForegroundColor Cyan
                    
                    # Use safe file operation if available
                    if (Get-Command "Invoke-SafeFileOperation" -ErrorAction SilentlyContinue) {
                        Invoke-SafeFileOperation -OperationName "Rename Series Folder" -FileOperation {
                            Rename-Item -LiteralPath $WorkingDirectory -NewName $newFolderName -ErrorAction Stop
                        } -SourcePath $WorkingDirectory -DestinationPath $newWorkingDirectory
                    } else {
                        Rename-Item -LiteralPath $WorkingDirectory -NewName $newFolderName -ErrorAction Stop
                    }
                    
                    Write-Host "[SUCCESS] Folder renamed to: $newFolderName" -ForegroundColor Green
                    Write-InfoLogFallback "Successfully renamed folder to: $newFolderName"
                    return $newWorkingDirectory
                }
                catch {
                    Write-Host "[ERROR] Could not rename folder: $($_.Exception.Message)" -ForegroundColor Red
                    Write-ErrorLogFallback "Could not rename folder: $($_.Exception.Message)"
                    return $WorkingDirectory
                }
            }
            "N" {
                Write-Host "[INFO] Folder rename skipped." -ForegroundColor Yellow
                Write-InfoLogFallback "Folder rename skipped"
                return $WorkingDirectory
            }
            "" {
                # Default to Y if user just presses Enter
                $choice = "Y"
            }
            default {
                Write-Host "Please enter Y (Yes) or N (No)" -ForegroundColor Red
            }
        }
    } while ($choice.ToUpper() -ne "Y" -and $choice.ToUpper() -ne "N")
    
    return $WorkingDirectory
}

# Export functions
Export-ModuleMember -Function Find-VideoFiles, Execute-FileOperations, Write-OperationLog, Rename-SeriesFolder