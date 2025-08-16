# Universal Interactive Anime File Organizer using TheTVDB API
# Completely free PowerShell script for organizing anime files

param(
    [Parameter(Mandatory=$false)]
    [string]$ApiKey = "2cb4e65a-f9a9-46e4-98f9-2d44f55342db",
    
    [Parameter(Mandatory=$false)]
    [string]$Pin = "",
    
    [Parameter(Mandatory=$false)]
    [string]$WorkingDirectory = (Get-Location).Path,
    
    [Parameter(Mandatory=$false)]
    [int]$SeriesId = 0
)

# TheTVDB API Configuration
$BaseApiUrl = "https://api4.thetvdb.com/v4"
$Headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}

# Supported video file extensions
$VideoExtensions = @(".mkv", ".mp4", ".avi", ".m4v", ".wmv", ".flv", ".webm")

function Write-Header {
    Clear-Host
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "                   Universal Anime File Organizer                      " -ForegroundColor Cyan
    Write-Host "                       Using TheTVDB API (Free)                        " -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Metadata provided by TheTVDB (https://thetvdb.com)" -ForegroundColor Gray
    Write-Host ""
}

function Get-TheTVDBToken {
    param($ApiKey, $Pin)
    
    $loginBody = @{
        apikey = $ApiKey
    }
    
    if ($Pin) {
        $loginBody.pin = $Pin
    }
    
    try {
        Write-Host "[AUTH] Authenticating with TheTVDB API..." -ForegroundColor Yellow
        $response = Invoke-RestMethod -Uri "$BaseApiUrl/login" -Method POST -Body ($loginBody | ConvertTo-Json) -Headers $Headers
        Write-Host "[SUCCESS] Authentication successful" -ForegroundColor Green
        return $response.data.token
    }
    catch {
        Write-Error "[ERROR] Authentication failed: $($_.Exception.Message)"
        return $null
    }
}

function Get-SeriesInfo {
    param($Token, $SeriesId)
    
    $authHeaders = $Headers.Clone()
    $authHeaders["Authorization"] = "Bearer $Token"
    
    try {
        Write-Host "[API] Fetching series information..." -ForegroundColor Yellow
        $response = Invoke-RestMethod -Uri "$BaseApiUrl/series/$SeriesId" -Method GET -Headers $authHeaders
        $seriesData = $response.data
        
        # Force English name for known series
        if ($SeriesId -eq 219701) {
            $seriesData.name = "Freezing"
        }
        
        return $seriesData
    }
    catch {
        Write-Error "[ERROR] Failed to get series information: $($_.Exception.Message)"
        return $null
    }
}

function Get-SeriesEpisodes {
    param($Token, $SeriesId)
    
    $authHeaders = $Headers.Clone()
    $authHeaders["Authorization"] = "Bearer $Token"
    
    try {
        Write-Host "[API] Fetching all episodes and seasons..." -ForegroundColor Yellow
        $allEpisodes = @()
        $page = 0
        
        do {
            $response = Invoke-RestMethod -Uri "$BaseApiUrl/series/$SeriesId/episodes/default?page=$page" -Method GET -Headers $authHeaders
            if ($response.data.episodes) {
                $allEpisodes += $response.data.episodes
            }
            $page++
        } while ($response.data.episodes -and $response.data.episodes.Count -gt 0)
        
        return $allEpisodes
    }
    catch {
        Write-Error "[ERROR] Failed to get episodes: $($_.Exception.Message)"
        return @()
    }
}

function Find-VideoFiles {
    param($Directory)
    
    Write-Host "[SCAN] Scanning for video files (including subdirectories)..." -ForegroundColor Yellow
    $videoFiles = Get-ChildItem -Path $Directory -File -Recurse | Where-Object { 
        $VideoExtensions -contains $_.Extension.ToLower() 
    } | Sort-Object FullName
    
    if ($videoFiles.Count -eq 0) {
        Write-Host "[ERROR] No video files found" -ForegroundColor Red
        return @()
    }
    
    Write-Host "[SUCCESS] Found $($videoFiles.Count) video files" -ForegroundColor Green
    return $videoFiles
}

function Parse-EpisodeNumber {
    param($FileName)
    
    $patterns = @(
        '(?:\[.*?\])?\s*(.+?)\s*-\s*(\d+)(?:\s*\[.*?\])?\..*$',
        '(.+?)\s+(?:Episode\s*|Ep\s*|E)(\d+)\..*$',
        '(.+?)\s+(\d+)\..*$'
    )
    
    foreach ($pattern in $patterns) {
        if ($FileName -match $pattern) {
            return @{
                SeriesName = $Matches[1].Trim()
                EpisodeNumber = [int]$Matches[2]
            }
        }
    }
    
    return $null
}

function Get-SafeFileName {
    param($FileName)
    $invalidChars = '[<>:"/\\|?*]'
    return $FileName -replace $invalidChars, ''
}

# Main execution
Write-Header

# Get Series ID
if ($SeriesId -eq 0) {
    do {
        $input = Read-Host "TheTVDB Series ID (or 'Q' to quit)"
        if ($input.ToUpper() -eq "Q") {
            exit 0
        }
        if ([int]::TryParse($input, [ref]$SeriesId) -and $SeriesId -gt 0) {
            break
        } else {
            Write-Host "[ERROR] Please enter a valid positive number" -ForegroundColor Red
        }
    } while ($true)
}

# Choose operation mode
Write-Host ""
Write-Host "Choose operation:" -ForegroundColor Cyan
Write-Host "1. Rename only (keep current folder structure)" -ForegroundColor Yellow
Write-Host "2. Reorganize (create Season folders and move files)" -ForegroundColor Yellow
Write-Host ""

do {
    $operation = Read-Host "Select operation (1/2/Q)"
    if ($operation.ToUpper() -eq "Q") {
        exit 0
    }
    if ($operation -eq "1" -or $operation -eq "2") {
        break
    } else {
        Write-Host "[ERROR] Please enter 1, 2, or Q" -ForegroundColor Red
    }
} while ($true)

$renameOnly = ($operation -eq "1")

# Authenticate
$token = Get-TheTVDBToken -ApiKey $ApiKey -Pin $Pin
if (-not $token) {
    Write-Host "[ERROR] Cannot proceed without authentication" -ForegroundColor Red
    exit 1
}

# Get series info
$seriesInfo = Get-SeriesInfo -Token $token -SeriesId $SeriesId
if (-not $seriesInfo) {
    Write-Host "[ERROR] Cannot retrieve series information" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCCESS] Series: $($seriesInfo.name)" -ForegroundColor Green

# Get episodes
$episodes = Get-SeriesEpisodes -Token $token -SeriesId $SeriesId
if ($episodes.Count -eq 0) {
    Write-Host "[ERROR] No episodes found" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCCESS] Found $($episodes.Count) episodes" -ForegroundColor Green

# Find video files
$videoFiles = Find-VideoFiles -Directory $WorkingDirectory
if ($videoFiles.Count -eq 0) {
    exit 1
}

# Process files
Write-Host "[PROCESS] Analyzing files..." -ForegroundColor Yellow
$operations = @()

foreach ($file in $videoFiles) {
    $parsedFile = Parse-EpisodeNumber -FileName $file.Name
    
    if (-not $parsedFile) {
        Write-Warning "Could not parse: $($file.Name)"
        continue
    }
    
    # Find matching episode
    $matchingEpisodes = $episodes | Where-Object { $_.number -eq $parsedFile.EpisodeNumber }
    
    if ($matchingEpisodes.Count -eq 0) {
        Write-Warning "No episode data for episode $($parsedFile.EpisodeNumber)"
        continue
    }
    
    $episode = $matchingEpisodes | Where-Object { $_.seasonNumber -ne 0 } | Select-Object -First 1
    if (-not $episode) {
        $episode = $matchingEpisodes | Select-Object -First 1
    }
    
    # Generate new filename
    $seasonNumber = $episode.seasonNumber
    $episodeTitle = Get-SafeFileName -FileName $episode.name
    $englishSeriesName = $seriesInfo.name
    
    # Detect season from path for Freezing
    $detectedSeason = 1
    if ($file.FullName -match "Vibration|S2") {
        $detectedSeason = 2
    }
    
    # Check if special
    $isSpecial = ($seasonNumber -eq 0) -or ($file.Name -match "OVA")
    
    if ($isSpecial) {
        if ($renameOnly) {
            $targetFolder = Split-Path $file.FullName -Parent
            $targetFolder = $targetFolder.Replace($WorkingDirectory, "").TrimStart("\")
        } else {
            $targetFolder = "Specials"
        }
        $newFileName = "$englishSeriesName - S00E{0:D2} - $episodeTitle$($file.Extension)" -f $parsedFile.EpisodeNumber
    } else {
        if ($renameOnly) {
            $targetFolder = Split-Path $file.FullName -Parent
            $targetFolder = $targetFolder.Replace($WorkingDirectory, "").TrimStart("\")
        } else {
            $targetFolder = "Season {0:D2}" -f $detectedSeason
        }
        $newFileName = "$englishSeriesName - S{0:D2}E{1:D2} - $episodeTitle$($file.Extension)" -f $detectedSeason, $parsedFile.EpisodeNumber
    }
    
    $operation = New-Object PSObject -Property @{
        OriginalFile = $file.FullName.Replace($WorkingDirectory, "").TrimStart("\")
        SourcePath = $file.FullName
        NewFileName = $newFileName
        TargetFolder = $targetFolder
    }
    $operations += $operation
}

if ($operations.Count -eq 0) {
    Write-Host "[ERROR] No files could be matched" -ForegroundColor Red
    exit 1
}

# Show preview
Write-Host ""
Write-Host "PREVIEW OF CHANGES:" -ForegroundColor Magenta
Write-Host ""

$folderOperations = $operations | Group-Object TargetFolder
foreach ($folderGroup in $folderOperations) {
    Write-Host "FOLDER: $($folderGroup.Name)" -ForegroundColor Cyan
    foreach ($op in $folderGroup.Group) {
        Write-Host "   FROM: $($op.OriginalFile)" -ForegroundColor Yellow
        Write-Host "     TO: $($op.NewFileName)" -ForegroundColor Green
        Write-Host ""
    }
}

# Get confirmation
do {
    $choice = Read-Host "Do you want to proceed? (Y/N)"
    $choice = $choice.ToUpper()
    
    if ($choice -eq "Y" -or $choice -eq "YES") {
        break
    } elseif ($choice -eq "N" -or $choice -eq "NO") {
        Write-Host "Operation cancelled" -ForegroundColor Yellow
        exit 0
    } else {
        Write-Host "Please enter Y (Yes) or N (No)" -ForegroundColor Red
    }
} while ($true)

# Execute operations
Write-Host ""
Write-Host "[EXECUTE] Processing files..." -ForegroundColor Green
Write-Host ""

# Create folders first
$foldersToCreate = $operations | Select-Object -ExpandProperty TargetFolder | Sort-Object -Unique
foreach ($folder in $foldersToCreate) {
    $fullPath = Join-Path -Path $WorkingDirectory -ChildPath $folder
    if (-not (Test-Path $fullPath)) {
        try {
            New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
            Write-Host "[SUCCESS] Created folder: $folder" -ForegroundColor Green
        }
        catch {
            Write-Error "[ERROR] Failed to create folder $folder"
        }
    }
}

# Move and rename files
foreach ($operation in $operations) {
    $sourcePath = $operation.SourcePath
    $targetPath = Join-Path -Path $WorkingDirectory -ChildPath (Join-Path -Path $operation.TargetFolder -ChildPath $operation.NewFileName)
    
    try {
        if (Test-Path -LiteralPath $sourcePath) {
            Move-Item -LiteralPath $sourcePath -Destination $targetPath -ErrorAction Stop
            Write-Host "[SUCCESS] $($operation.OriginalFile) -> $($operation.NewFileName)" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Source not found: $($operation.OriginalFile)" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "[ERROR] Failed to rename $($operation.OriginalFile): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "[COMPLETE] File organization completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Attribution: Metadata provided by TheTVDB (https://thetvdb.com)" -ForegroundColor Gray

Read-Host "Press Enter to exit"