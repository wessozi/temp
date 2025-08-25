# AnimeOrganizer.UserInterface.psm1 - User Interface Functions Module
# Phase 3: User Interface - Extracted from original Anime-File-Organizer.ps1

# Import logging with fallbacks
function Write-InfoLogFallback {
    param([string]$Message, [string]$Category = "UserInterface")
    if (Get-Command "Write-InfoLog" -ErrorAction SilentlyContinue) {
        Write-InfoLog -Message $Message -Category $Category
    } else {
        Write-Host "[INFO] $Message" -ForegroundColor White
    }
}

function Write-DebugLogFallback {
    param([string]$Message, [string]$Category = "UserInterface")
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
        return @{
            behavior = @{
                debug_mode = $true
            }
        }
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
    
    Write-InfoLogFallback "User interface header displayed"
}

function Show-Preview {
    param($Operations)
    
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Magenta
    Write-Host "                           PREVIEW OF CHANGES                          " -ForegroundColor Magenta
    Write-Host "                        (NO CHANGES MADE YET)                        " -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Magenta
    Write-Host ""
    
    Write-DebugLogFallback "Generating preview for $($Operations.Count) operations"
    Write-InfoLogFallback "Displaying preview of $($Operations.Count) file operations"
    
    $folderOperations = $Operations | Group-Object TargetFolder
    
    foreach ($folderGroup in $folderOperations) {
        Write-Host "FOLDER: $($folderGroup.Name)" -ForegroundColor Cyan
        Write-DebugLogFallback "Folder '$($folderGroup.Name)' will contain $($folderGroup.Group.Count) files"
        
        # Sort operations by episode number for logical ordering
        $sortedOperations = $folderGroup.Group | Sort-Object { 
            if ($_.EpisodeNumber) { $_.EpisodeNumber } else { 999 } 
        }
        
        foreach ($op in $sortedOperations) {
            $fromDisplay = if ([string]::IsNullOrEmpty($op.OriginalFile)) { "(temporary file)" } else { $op.OriginalFile }
            
            # Handle different operation types with different colors
            if ($op.OperationType -eq "Skip" -or $op.Status -eq "Already Correct") {
                Write-Host "   FROM: $fromDisplay" -ForegroundColor Gray
                Write-Host "     TO: NO CHANGE" -ForegroundColor Magenta
                Write-DebugLogFallback "Operation: File '$fromDisplay' is already correct - no change needed"
            } elseif ($op.OperationType -eq "Special") {
                Write-Host "   FROM: $fromDisplay" -ForegroundColor Cyan
                Write-Host "     TO: SPECIAL CONTENT (needs manual review)" -ForegroundColor Magenta
                Write-DebugLogFallback "Operation: Special file '$fromDisplay' moved to Specials folder"
            } else {
                Write-Host "   FROM: $fromDisplay" -ForegroundColor Yellow
                Write-Host "     TO: $($op.NewFileName)" -ForegroundColor Green
                Write-DebugLogFallback "Operation: Move '$fromDisplay' to '$($op.TargetFolder)\$($op.NewFileName)'"
            }
            Write-Host ""
        }
    }
    
    Write-Host "Total operations: $($Operations.Count)" -ForegroundColor White
    Write-Host "Folders to create: $($folderOperations.Count)" -ForegroundColor White
    Write-Host ""
    Write-Host "WARNING: Review the above changes carefully before proceeding!" -ForegroundColor Red
    Write-Host ""
    
    Write-InfoLogFallback "Preview displayed - Operations: $($Operations.Count), Folders: $($folderOperations.Count)"
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
    
    Write-InfoLogFallback "Displaying confirmation dialog"
    
    do {
        $choice = Read-Host "Do you want to proceed? (Y/N/Q/R, default: Y)"
        
        # Default to Y if user just presses Enter
        if ([string]::IsNullOrWhiteSpace($choice)) {
            $choice = "Y"
        }
        $choice = $choice.ToUpper()
        
        Write-DebugLogFallback "User choice: $choice"
        
        if ($choice -eq "Y" -or $choice -eq "YES") {
            Write-DebugLogFallback "User confirmed to proceed with operations"
            Write-InfoLogFallback "User confirmed to proceed with file operations"
            return "proceed"
        } elseif ($choice -eq "N" -or $choice -eq "NO") {
            Write-DebugLogFallback "User chose to cancel operations"
            Write-InfoLogFallback "User cancelled file operations"
            return "cancel"
        } elseif ($choice -eq "Q" -or $choice -eq "QUIT") {
            Write-DebugLogFallback "User chose to quit program"
            Write-InfoLogFallback "User chose to quit program"
            return "quit"
        } elseif ($choice -eq "R" -or $choice -eq "RESTART") {
            Write-DebugLogFallback "User chose to restart script"
            Write-InfoLogFallback "User chose to restart script"
            return "restart"
        } else {
            Write-Host "Please enter Y (Yes), N (No), Q (Quit), or R (Restart)" -ForegroundColor Red
        }
    } while ($true)
}

function Get-SeriesIdFromUser {
    Write-Host "Enter the TheTVDB Series ID for your anime series." -ForegroundColor Cyan
    Write-Host "You can find this on TheTVDB.com in the series URL." -ForegroundColor Gray
    Write-Host "Example: For Attack on Titan, use ID: 290434" -ForegroundColor Gray
    Write-Host "Example: For Please Put Them On, Takamine-san, use ID: 452826" -ForegroundColor Gray
    Write-Host ""
    
    $SeriesId = 0
    while ($SeriesId -eq 0) {
        $input = Read-Host "TheTVDB Series ID (or 'Q' to quit)"
        if ([string]::IsNullOrWhiteSpace($input)) {
            continue  # Ask again if no input
        }
        if ($input.ToUpper() -eq "Q" -or $input.ToLower() -eq "quit") {
            Write-Host "Exiting..." -ForegroundColor Yellow
            Write-InfoLogFallback "User chose to quit during Series ID input"
            return $null
        }
        
        if ([int]::TryParse($input, [ref]$SeriesId) -and $SeriesId -gt 0) {
            Write-InfoLogFallback "User entered Series ID: $SeriesId"
            return $SeriesId
        } else {
            Write-Host "[ERROR] Please enter a valid positive number" -ForegroundColor Red
        }
    }
}

function Get-WorkingDirectoryFromUser {
    param([string]$CurrentDirectory = (Get-Location).Path)
    
    Write-Host ""
    Write-Host "Working Directory: $CurrentDirectory" -ForegroundColor Cyan
    
    do {
        $newDir = Read-Host "Enter working directory path (or '.' for current directory, 'Q' to quit)"
        if ([string]::IsNullOrWhiteSpace($newDir)) {
            continue  # Ask again if no input
        }
        if ($newDir.ToUpper() -eq "Q" -or $newDir.ToLower() -eq "quit") {
            Write-Host "Exiting..." -ForegroundColor Yellow
            Write-InfoLogFallback "User chose to quit during directory input"
            return $null
        }
        
        # Clean up the path (remove quotes, trim whitespace)
        $newDir = $newDir.Trim().Trim('"').Trim("'")
        
        # Handle current directory (.)
        if ($newDir -eq ".") {
            $WorkingDirectory = (Get-Location).Path
            Write-Host "[INFO] Using current directory: $WorkingDirectory" -ForegroundColor Green
            Write-InfoLogFallback "User selected current directory: $WorkingDirectory"
            return $WorkingDirectory
        }
        
        Write-DebugLogFallback "Testing path: '$newDir'"
        if (Test-Path -LiteralPath $newDir) {
            $WorkingDirectory = $newDir
            Write-Host "[INFO] Working directory set to: $WorkingDirectory" -ForegroundColor Green
            Write-InfoLogFallback "User selected working directory: $WorkingDirectory"
            return $WorkingDirectory
        } else {
            Write-Host "[ERROR] Directory does not exist. Please enter a valid path." -ForegroundColor Red
        }
    } while ($true)
}

function Get-OperationTypeFromUser {
    Write-Host ""
    Write-Host "Choose operation:" -ForegroundColor Cyan
    Write-Host "1. Rename only (keep current folder structure)" -ForegroundColor Yellow
    Write-Host "2. Reorganize (create Season folders and move files)" -ForegroundColor Yellow
    Write-Host ""
    
    do {
        $operation = Read-Host "Select operation (1/2/Q)"
        if ([string]::IsNullOrWhiteSpace($operation)) {
            continue  # Ask again if no input
        }
        if ($operation.ToUpper() -eq "Q" -or $operation.ToLower() -eq "quit") {
            Write-Host "Exiting..." -ForegroundColor Yellow
            Write-InfoLogFallback "User chose to quit during operation selection"
            return $null
        }
        if ($operation -eq "1" -or $operation -eq "2") {
            $renameOnly = ($operation -eq "1")
            Write-InfoLogFallback "User selected operation type: $(if ($renameOnly) { 'Rename Only' } else { 'Reorganize' })"
            return $renameOnly
        } else {
            Write-Host "[ERROR] Please enter 1, 2, or Q" -ForegroundColor Red
        }
    } while ($true)
}

function Show-SeriesVerification {
    param($SeriesInfo, $SeriesId)
    
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "                           SERIES VERIFICATION                         " -ForegroundColor Green  
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Series ID: $SeriesId" -ForegroundColor Cyan
    Write-Host "Series Name: $($SeriesInfo.name)" -ForegroundColor Yellow
    Write-Host ""
    
    Write-InfoLogFallback "Displaying series verification for: $($SeriesInfo.name) (ID: $SeriesId)"
    
    do {
        $confirm = Read-Host "Is this the correct series? (Y/N/Q, default: Y)"
        
        # Handle null or empty input
        if ([string]::IsNullOrWhiteSpace($confirm)) {
            $confirm = "Y"  # Default to Y
        }
        
        switch ($confirm.ToUpper()) {
            "Y" {
                Write-Host "[SUCCESS] Series confirmed!" -ForegroundColor Green
                Write-InfoLogFallback "User confirmed series: $($SeriesInfo.name)"
                return $true
            }
            "N" {
                Write-Host "[INFO] Please enter a different Series ID." -ForegroundColor Yellow
                Write-InfoLogFallback "User rejected series: $($SeriesInfo.name)"
                return $false
            }
            "Q" {
                Write-Host "Exiting..." -ForegroundColor Yellow
                Write-InfoLogFallback "User chose to quit during series verification"
                return $null
            }
            default {
                Write-Host "Please enter Y (Yes), N (No), or Q (Quit)" -ForegroundColor Red
            }
        }
    } while ($true)
}

function Show-RestartOptions {
    param([string]$Context = "General")
    
    Write-Host "What would you like to do?" -ForegroundColor Cyan
    Write-Host "  R/Restart - Try with different settings" -ForegroundColor Green
    Write-Host "  Q/Quit    - Exit the program" -ForegroundColor Red
    
    do {
        $choice = Read-Host "Choose (R/Q)"
        if ([string]::IsNullOrWhiteSpace($choice)) {
            $choice = "Q"  # Default to quit if no input
        }
        $choice = $choice.ToUpper()
        
        if ($choice -eq "R" -or $choice -eq "RESTART") {
            Write-InfoLogFallback "User chose to restart ($Context)"
            return "restart"
        } elseif ($choice -eq "Q" -or $choice -eq "QUIT") {
            Write-Host "Goodbye!" -ForegroundColor Yellow
            Write-InfoLogFallback "User chose to quit ($Context)"
            return "quit"
        } else {
            Write-Host "Please enter R (Restart) or Q (Quit)" -ForegroundColor Red
        }
    } while ($true)
}

# Export functions
Export-ModuleMember -Function Write-Header, Show-Preview, Confirm-Operations, Get-SeriesIdFromUser, Get-WorkingDirectoryFromUser, Get-OperationTypeFromUser, Show-SeriesVerification, Show-RestartOptions