# UserInterface.psm1 - User Interface and Interactive Functions
# Extracted from Anime-File-Organizer.ps1 - All UI elements
# Preserves exact user experience and interaction flow

# Debug mode flag for compatibility
$DebugMode = $true

function Write-Debug-Info {
    param($Message, $Color = "Cyan")
    if ($DebugMode) {
        Write-Host "[DEBUG] $Message" -ForegroundColor $Color
    }
}

function Write-Header {
    Clear-Host
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "                   Universal Anime File Organizer                      " -ForegroundColor Cyan
    Write-Host "                       Using TheTVDB API (Free)                        " -ForegroundColor Cyan
    Write-Host "                              DEBUG MODE: ON                           " -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Metadata provided by TheTVDB (https://thetvdb.com)" -ForegroundColor Gray
    Write-Host "Please consider contributing missing information or subscribing." -ForegroundColor Gray
    Write-Host ""
}

function Get-SeriesIdFromUser {
    param()
    
    Write-Host "Enter the TheTVDB Series ID for your anime series." -ForegroundColor Cyan
    Write-Host "You can find this on TheTVDB.com in the series URL." -ForegroundColor Gray
    Write-Host "Example: For Attack on Titan, use ID: 290434" -ForegroundColor Gray
    Write-Host ""
    
    $SeriesId = 0
    while ($SeriesId -eq 0) {
        $input = Read-Host "TheTVDB Series ID (or 'Q' to quit)"
        
        # Handle null input (non-interactive environments)
        if ([string]::IsNullOrEmpty($input)) {
            Write-Host "[ERROR] Please enter a valid positive number" -ForegroundColor Red
            continue
        }
        
        if ($input.ToUpper() -eq "Q" -or $input.ToLower() -eq "quit") {
            Write-Host "Exiting..." -ForegroundColor Yellow
            return $null
        }
        
        if ([int]::TryParse($input, [ref]$SeriesId) -and $SeriesId -gt 0) {
            return $SeriesId
        } else {
            Write-Host "[ERROR] Please enter a valid positive number" -ForegroundColor Red
        }
    }
}

function Confirm-SeriesSelection {
    param($SeriesInfo, $SeriesId)
    
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "                           SERIES VERIFICATION                         " -ForegroundColor Green  
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Series ID: $SeriesId" -ForegroundColor Cyan
    Write-Host "Series Name: $($SeriesInfo.name)" -ForegroundColor Yellow
    Write-Host ""
    
    do {
        $confirm = Read-Host "Is this the correct series? (Y/N/Q, default: Y)"
        if ([string]::IsNullOrEmpty($confirm)) { $confirm = "Y" } # Default to Y
        switch ($confirm.ToUpper()) {
            "Y" {
                Write-Host "[SUCCESS] Series confirmed!" -ForegroundColor Green
                Write-Host ""
                return $true
            }
            "N" {
                Write-Host "[INFO] Please try with a different Series ID." -ForegroundColor Yellow
                return $false
            }
            "Q" {
                Write-Host "Exiting..." -ForegroundColor Yellow
                return $null
            }
            default {
                Write-Host "Please enter Y (Yes), N (No), or Q (Quit)" -ForegroundColor Red
            }
        }
    } while ($true)
}

function Get-WorkingDirectoryFromUser {
    param($CurrentDirectory)
    
    Write-Host ""
    Write-Host "Working Directory: $CurrentDirectory" -ForegroundColor Cyan
    
    do {
        $newDir = Read-Host "Enter working directory path (or '.' for current directory, 'Q' to quit)"
        if ([string]::IsNullOrEmpty($newDir)) {
            Write-Host "[ERROR] Directory cannot be empty. Please enter a valid path." -ForegroundColor Red
            continue
        }
        if ($newDir.ToUpper() -eq "Q" -or $newDir.ToLower() -eq "quit") {
            Write-Host "Exiting..." -ForegroundColor Yellow
            return $null
        }
        
        # Clean up the path (remove quotes, trim whitespace)
        $newDir = $newDir.Trim().Trim('"').Trim("'")
        
        # Handle current directory (.)
        if ($newDir -eq ".") {
            $workingDir = (Get-Location).Path
            Write-Host "[INFO] Using current directory: $workingDir" -ForegroundColor Green
            return $workingDir
        }
        
        Write-Debug-Info "Testing path: '$newDir'"
        if (Test-Path -LiteralPath $newDir) {
            Write-Host "[INFO] Working directory set to: $newDir" -ForegroundColor Green
            return $newDir
        } else {
            Write-Host "[ERROR] Directory does not exist. Please enter a valid path." -ForegroundColor Red
        }
    } while ($true)
}

function Get-OperationTypeFromUser {
    param()
    
    Write-Host ""
    Write-Host "Choose operation:" -ForegroundColor Cyan
    Write-Host "1. Rename only (keep current folder structure)" -ForegroundColor Yellow
    Write-Host "2. Reorganize (create Season folders and move files)" -ForegroundColor Yellow
    Write-Host ""
    
    do {
        $operation = Read-Host "Select operation (1/2/Q)"
        if ([string]::IsNullOrEmpty($operation)) {
            Write-Host "[ERROR] Please enter 1, 2, or Q" -ForegroundColor Red
            continue
        }
        if ($operation.ToUpper() -eq "Q" -or $operation.ToLower() -eq "quit") {
            Write-Host "Exiting..." -ForegroundColor Yellow
            return $null
        }
        if ($operation -eq "1" -or $operation -eq "2") {
            return ($operation -eq "1")  # Return $true for rename only, $false for reorganize
        } else {
            Write-Host "[ERROR] Please enter 1, 2, or Q" -ForegroundColor Red
        }
    } while ($true)
}

function Show-Preview {
    param($Operations)
    
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Magenta
    Write-Host "                           PREVIEW OF CHANGES                          " -ForegroundColor Magenta
    Write-Host "                        (NO CHANGES MADE YET)                        " -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Magenta
    Write-Host ""
    
    Write-Debug-Info "Generating preview for $($Operations.Count) operations"
    
    $folderOperations = $Operations | Group-Object TargetFolder
    
    foreach ($folderGroup in $folderOperations) {
        Write-Host "FOLDER: $($folderGroup.Name)" -ForegroundColor Cyan
        Write-Debug-Info "Folder '$($folderGroup.Name)' will contain $($folderGroup.Group.Count) files"
        
        foreach ($op in $folderGroup.Group) {
            Write-Host "   FROM: $($op.OriginalFile)" -ForegroundColor Yellow
            Write-Host "     TO: $($op.NewFileName)" -ForegroundColor Green
            Write-Debug-Info "Operation: Move '$($op.OriginalFile)' to '$($op.TargetFolder)\$($op.NewFileName)'"
            Write-Host ""
        }
    }
    
    Write-Host "Total operations: $($Operations.Count)" -ForegroundColor White
    Write-Host "Folders to create: $($folderOperations.Count)" -ForegroundColor White
    Write-Host ""
    Write-Host "WARNING: Review the above changes carefully before proceeding!" -ForegroundColor Red
    Write-Host ""
}

function Confirm-Operations {
    Write-Host "==========================================================================" -ForegroundColor Red
    Write-Host "                              CONFIRMATION                             " -ForegroundColor Red
    Write-Host "==========================================================================" -ForegroundColor Red
    Write-Host "WARNING: This will permanently move and rename your files!" -ForegroundColor Yellow
    Write-Host "Make sure you have reviewed the preview above carefully." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  Y/Yes    - Proceed with file operations" -ForegroundColor Green
    Write-Host "  N/No     - Cancel and exit" -ForegroundColor Yellow
    Write-Host "  Q/Quit   - Exit program" -ForegroundColor Red
    Write-Host "  R/Restart- Start over with new settings" -ForegroundColor Magenta
    Write-Host ""
    
    do {
        $choice = Read-Host "Do you want to proceed? (Y/N/Q/R, default: Y)"
        if ([string]::IsNullOrEmpty($choice)) { $choice = "Y" } # Default to Y
        $choice = $choice.ToUpper()
        
        Write-Debug-Info "User choice: $choice"
        
        if ($choice -eq "Y" -or $choice -eq "YES" -or $choice -eq "") {
            Write-Debug-Info "User confirmed to proceed with operations"
            return "proceed"
        } elseif ($choice -eq "N" -or $choice -eq "NO") {
            Write-Debug-Info "User chose to cancel operations"
            return "cancel"
        } elseif ($choice -eq "Q" -or $choice -eq "QUIT") {
            Write-Debug-Info "User chose to quit program"
            return "quit"
        } elseif ($choice -eq "R" -or $choice -eq "RESTART") {
            Write-Debug-Info "User chose to restart script"
            return "restart"
        } else {
            Write-Host "Please enter Y (Yes), N (No), Q (Quit), or R (Restart)" -ForegroundColor Red
        }
    } while ($true)
}

function Rename-SeriesFolder {
    param($WorkingDirectory, $SeriesId, $EnglishSeriesName)
    
    # Import Get-SafeFileName from FileParser module
    Import-Module "$PSScriptRoot\FileParser.psm1" -Force
    
    $currentFolderName = Split-Path $WorkingDirectory -Leaf
    $tvdbPattern = '\[tvdb-\d+\]'
    
    if ($currentFolderName -match $tvdbPattern) {
        Write-Host "[INFO] Folder already has TVDB ID format: $currentFolderName" -ForegroundColor Green
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
        if ([string]::IsNullOrEmpty($choice)) { $choice = "Y" } # Default to Y
        switch ($choice.ToUpper()) {
            "Y" {
                try {
                    $parentPath = Split-Path $WorkingDirectory -Parent
                    $newWorkingDirectory = Join-Path $parentPath $newFolderName
                    
                    Write-Host "[INFO] Renaming series folder..." -ForegroundColor Cyan
                    Rename-Item -LiteralPath $WorkingDirectory -NewName $newFolderName -ErrorAction Stop
                    Write-Host "[SUCCESS] Folder renamed to: $newFolderName" -ForegroundColor Green
                    return $newWorkingDirectory
                }
                catch {
                    Write-Host "[ERROR] Could not rename folder: $($_.Exception.Message)" -ForegroundColor Red
                    return $WorkingDirectory
                }
            }
            "N" {
                Write-Host "[INFO] Folder rename skipped." -ForegroundColor Yellow
                return $WorkingDirectory
            }
            "" {
                # Default to Yes
                try {
                    $parentPath = Split-Path $WorkingDirectory -Parent
                    $newWorkingDirectory = Join-Path $parentPath $newFolderName
                    
                    Write-Host "[INFO] Renaming series folder..." -ForegroundColor Cyan
                    Rename-Item -LiteralPath $WorkingDirectory -NewName $newFolderName -ErrorAction Stop
                    Write-Host "[SUCCESS] Folder renamed to: $newFolderName" -ForegroundColor Green
                    return $newWorkingDirectory
                }
                catch {
                    Write-Host "[ERROR] Could not rename folder: $($_.Exception.Message)" -ForegroundColor Red
                    return $WorkingDirectory
                }
            }
            default {
                Write-Host "Please enter Y (Yes) or N (No)" -ForegroundColor Red
            }
        }
    } while ($true)
}

function Show-RestartOptions {
    param($Context = "Error")
    
    do {
        Write-Host "What would you like to do?" -ForegroundColor Cyan
        Write-Host "  R/Restart - Try again with different settings" -ForegroundColor Green
        Write-Host "  Q/Quit    - Exit the program" -ForegroundColor Red
        $choice = Read-Host "Choose (R/Q)"
        if ([string]::IsNullOrEmpty($choice)) {
            Write-Host "Please enter R (Restart) or Q (Quit)" -ForegroundColor Red
            continue
        }
        $choice = $choice.ToUpper()
        
        if ($choice -eq "R" -or $choice -eq "RESTART") {
            Write-Debug-Info "User chose to restart after $Context"
            return "restart"
        } elseif ($choice -eq "Q" -or $choice -eq "QUIT") {
            Write-Debug-Info "User chose to quit after $Context"
            return "quit"
        } else {
            Write-Host "Please enter R (Restart) or Q (Quit)" -ForegroundColor Red
        }
    } while ($true)
}

function Show-CompletionOptions {
    param()
    
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "                              SCRIPT COMPLETE                           " -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "Thank you for using Universal Anime File Organizer!" -ForegroundColor Cyan
    Write-Host "Attribution: Metadata provided by TheTVDB (https://thetvdb.com)" -ForegroundColor Gray
    Write-Host ""
    Write-Debug-Info "Script execution completed"
    
    do {
        Write-Host "What would you like to do?" -ForegroundColor Cyan
        Write-Host "  R/Restart - Run the script again" -ForegroundColor Green
        Write-Host "  Q/Quit    - Exit the program" -ForegroundColor Red
        $choice = Read-Host "Choose (R/Q)"
        if ([string]::IsNullOrEmpty($choice)) {
            Write-Host "Please enter R (Restart) or Q (Quit)" -ForegroundColor Red
            continue
        }
        $choice = $choice.ToUpper()
        
        if ($choice -eq "R" -or $choice -eq "RESTART") {
            Write-Debug-Info "User chose to restart after completion"
            return "restart"
        } elseif ($choice -eq "Q" -or $choice -eq "QUIT") {
            Write-Debug-Info "User chose to quit after completion"
            return "quit"
        } else {
            Write-Host "Please enter R (Restart) or Q (Quit)" -ForegroundColor Red
        }
    } while ($true)
}

# Export functions
Export-ModuleMember -Function Write-Header, Get-SeriesIdFromUser, Confirm-SeriesSelection, Get-WorkingDirectoryFromUser, Get-OperationTypeFromUser, Show-Preview, Confirm-Operations, Rename-SeriesFolder, Show-RestartOptions, Show-CompletionOptions