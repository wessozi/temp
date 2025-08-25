# FileOperations.psm1 - File System Operations  
# Extracted from Anime-File-Organizer.ps1 (lines 486-764)
# File operations, logging, and folder management

# Debug mode flag for compatibility
$DebugMode = $true

function Write-Debug-Info {
    param($Message, $Color = "Cyan")
    if ($DebugMode) {
        Write-Host "[DEBUG] $Message" -ForegroundColor $Color
    }
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
    
    # Import Get-SafeFileName from FileParser module
    Import-Module "$PSScriptRoot\FileParser.psm1" -Force
    
    if ($Operations.Count -eq 0) {
        Write-Debug-Info "No operations to log"
        return
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $safeSeriesName = Get-SafeFileName -FileName $SeriesName
    $logFileName = "rename_log_${safeSeriesName}_${timestamp}.txt"
    $logPath = Join-Path $WorkingDirectory $logFileName
    
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
        
        $logContent | Out-File -FilePath $logPath -Encoding UTF8
        Write-Host "[LOG] Created rename log: $logFileName" -ForegroundColor Green
        Write-Debug-Info "Rename log written to: $logPath"
        
    } catch {
        Write-Warning "[WARNING] Failed to create rename log: $($_.Exception.Message)"
        Write-Debug-Info "Log creation error: $($_.Exception.Message)"
    }
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
    
    Write-Debug-Info "Starting execution of $($Operations.Count) operations"
    
    # Create folders first
    $foldersToCreate = $Operations | Select-Object -ExpandProperty TargetFolder | Sort-Object -Unique
    Write-Debug-Info "Need to create $($foldersToCreate.Count) unique folders"
    
    foreach ($folder in $foldersToCreate) {
        $fullPath = Join-Path -Path $WorkingDirectory -ChildPath $folder
        Write-Debug-Info "Checking folder: $fullPath"
        
        if (-not (Test-Path -LiteralPath $fullPath)) {
            try {
                New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
                Write-Host "[SUCCESS] Created folder: $folder" -ForegroundColor Green
                Write-Debug-Info "Successfully created folder: $fullPath" "Green"
                $folderCreateCount++
            }
            catch {
                Write-Error "[ERROR] Failed to create folder $folder : $($_.Exception.Message)"
                Write-Debug-Info "Failed to create folder: $fullPath - $($_.Exception.Message)" "Red"
                $errorCount++
                return $false
            }
        } else {
            Write-Debug-Info "Folder already exists: $fullPath" "Gray"
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
            $targetPath = Join-Path -Path $WorkingDirectory -ChildPath $operation.NewFileName
        } else {
            $targetPath = Join-Path -Path $WorkingDirectory -ChildPath (Join-Path -Path $operation.TargetFolder -ChildPath $operation.NewFileName)
        }
        
        Write-Debug-Info "Processing: $($operation.OriginalFile)"
        Write-Debug-Info "  Source: $sourcePath"
        Write-Debug-Info "  Target: $targetPath"
        
        try {            
            if (Test-Path -LiteralPath $sourcePath) {
                # Check if target already exists
                if (Test-Path -LiteralPath $targetPath) {
                    Write-Host "[WARNING] Target file already exists: $($operation.NewFileName)" -ForegroundColor Yellow
                    Write-Debug-Info "Target file exists, skipping: $targetPath" "Yellow"
                    continue
                }
                
                Move-Item -LiteralPath $sourcePath -Destination $targetPath -ErrorAction Stop
                Write-Host "[SUCCESS] $($operation.OriginalFile) -> $($operation.NewFileName)" -ForegroundColor Green
                Write-Debug-Info "Successfully moved file" "Green"
                $successCount++
            } else {
                Write-Host "[ERROR] Source file not found: $($operation.OriginalFile)" -ForegroundColor Red
                Write-Debug-Info "Source file not found: $sourcePath" "Red"
                $errorCount++
            }
        }
        catch {
            Write-Host "[ERROR] Failed to move $($operation.OriginalFile): $($_.Exception.Message)" -ForegroundColor Red
            Write-Debug-Info "Move operation failed: $($_.Exception.Message)" "Red"
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
    
    if ($errorCount -eq 0) {
        Write-Host "[COMPLETE] All file operations completed successfully!" -ForegroundColor Green
        Write-Debug-Info "All operations completed without errors" "Green"
    } else {
        Write-Host "[WARNING] Some operations failed. Please check the errors above." -ForegroundColor Yellow
        Write-Debug-Info "$errorCount operations failed" "Red"
    }
    
    return ($errorCount -eq 0)
}

# Export functions
Export-ModuleMember -Function Write-OperationLog, Execute-FileOperations