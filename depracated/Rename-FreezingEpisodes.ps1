# Freezing Episode Renamer using TheTVDB API
# Completely free PowerShell script for renaming anime files
# No licensing requirements - uses free TheTVDB API access

param(
    [Parameter(Mandatory=$false)]
    [string]$ApiKey = "2cb4e65a-f9a9-46e4-98f9-2d44f55342db",
    
    [Parameter(Mandatory=$false)]
    [string]$Pin = "",
    
    [Parameter(Mandatory=$false)]
    [string]$BasePath = "Z:\Media\NSFW\Freezing",
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

# TheTVDB API Configuration
$BaseApiUrl = "https://api4.thetvdb.com/v4"
$Headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}

# Series mapping for Freezing
$SeriesMapping = @{
    "Freezing" = @{
        SeriesId = 248741
        Season = 1
    }
    "Freezing Vibration" = @{
        SeriesId = 276252  
        Season = 1
    }
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
        $response = Invoke-RestMethod -Uri "$BaseApiUrl/login" -Method POST -Body ($loginBody | ConvertTo-Json) -Headers $Headers
        return $response.data.token
    }
    catch {
        Write-Error "Failed to authenticate with TheTVDB API: $($_.Exception.Message)"
        return $null
    }
}

function Get-SeriesEpisodes {
    param($Token, $SeriesId, $Season)
    
    $authHeaders = $Headers.Clone()
    $authHeaders["Authorization"] = "Bearer $Token"
    
    try {
        $response = Invoke-RestMethod -Uri "$BaseApiUrl/series/$SeriesId/episodes/default?page=0&season=$Season" -Method GET -Headers $authHeaders
        return $response.data.episodes
    }
    catch {
        Write-Error "Failed to get episodes for series $SeriesId season $Season : $($_.Exception.Message)"
        return @()
    }
}

function Parse-FileName {
    param($FileName)
    
    # Parse different filename patterns
    if ($FileName -match '\[Anime Time\] (Freezing(?:\s+Vibration)?)(?: OVA)? - (\d+)\.mkv') {
        $seriesName = $Matches[1]
        $episodeNum = [int]$Matches[2]
        $isOVA = $FileName -match "OVA"
        
        return @{
            SeriesName = $seriesName
            EpisodeNumber = $episodeNum
            IsOVA = $isOVA
            OriginalName = $FileName
        }
    }
    
    return $null
}

function Get-SafeFileName {
    param($FileName)
    
    # Remove invalid characters for Windows filenames
    $invalidChars = '[<>:"/\\|?*]'
    return $FileName -replace $invalidChars, ''
}

function Rename-Episodes {
    param($Token, $FolderPath, $SeriesName, $Season, $IsSpecial = $false)
    
    Write-Host "Processing $SeriesName episodes in $FolderPath..." -ForegroundColor Green
    
    # Get series info
    $seriesInfo = $SeriesMapping[$SeriesName]
    if (-not $seriesInfo) {
        Write-Warning "No series mapping found for $SeriesName"
        return
    }
    
    # Get episodes from API
    $episodes = Get-SeriesEpisodes -Token $Token -SeriesId $seriesInfo.SeriesId -Season $Season
    if ($episodes.Count -eq 0) {
        Write-Warning "No episodes found for $SeriesName season $Season"
        return
    }
    
    # Get all files in the folder
    $files = Get-ChildItem -Path $FolderPath -Filter "*.mkv" | Sort-Object Name
    
    foreach ($file in $files) {
        $parsedFile = Parse-FileName -FileName $file.Name
        if (-not $parsedFile) {
            Write-Warning "Could not parse filename: $($file.Name)"
            continue
        }
        
        # Find matching episode
        $episode = $episodes | Where-Object { $_.number -eq $parsedFile.EpisodeNumber }
        if (-not $episode) {
            Write-Warning "No episode data found for episode $($parsedFile.EpisodeNumber)"
            continue
        }
        
        # Generate new filename
        $episodeTitle = Get-SafeFileName -FileName $episode.name
        if ($IsSpecial) {
            $newName = "Freezing - S00E{0:D2} - {1}.mkv" -f $parsedFile.EpisodeNumber, $episodeTitle
        } else {
            $seasonNum = if ($SeriesName -eq "Freezing Vibration") { 2 } else { 1 }
            $newName = "Freezing - S{0:D2}E{1:D2} - {2}.mkv" -f $seasonNum, $parsedFile.EpisodeNumber, $episodeTitle
        }
        
        $newPath = Join-Path -Path $FolderPath -ChildPath $newName
        
        # Display the rename operation
        Write-Host "  $($file.Name)" -ForegroundColor Yellow
        Write-Host "  -> $newName" -ForegroundColor Cyan
        
        # Perform rename (or show what would happen)
        if ($WhatIf) {
            Write-Host "  [WHAT-IF] Would rename file" -ForegroundColor Magenta
        } else {
            try {
                Rename-Item -Path $file.FullName -NewName $newName -ErrorAction Stop
                Write-Host "  ✓ Renamed successfully" -ForegroundColor Green
            }
            catch {
                Write-Error "  ✗ Failed to rename: $($_.Exception.Message)"
            }
        }
        Write-Host ""
    }
}

# Main execution
Write-Host "Freezing Episode Renamer" -ForegroundColor Magenta
Write-Host "Using TheTVDB API (Free Tier)" -ForegroundColor Gray
Write-Host "Metadata provided by TheTVDB. Please consider adding missing information or subscribing." -ForegroundColor Gray
Write-Host ""

# Authenticate with TheTVDB
Write-Host "Authenticating with TheTVDB API..." -ForegroundColor Yellow
$token = Get-TheTVDBToken -ApiKey $ApiKey -Pin $Pin

if (-not $token) {
    Write-Error "Authentication failed. Please check your API key and PIN."
    exit 1
}

Write-Host "✓ Authentication successful" -ForegroundColor Green
Write-Host ""

# Process Season 1
$s1Path = Join-Path -Path $BasePath -ChildPath "Freezing S1"
if (Test-Path $s1Path) {
    Rename-Episodes -Token $token -FolderPath $s1Path -SeriesName "Freezing" -Season 1
}

# Process Season 2 (Vibration)
$s2Path = Join-Path -Path $BasePath -ChildPath "Freezing Vibration S2"
if (Test-Path $s2Path) {
    Rename-Episodes -Token $token -FolderPath $s2Path -SeriesName "Freezing Vibration" -Season 1
}

# Process Specials
$specialsS1Path = Join-Path -Path $BasePath -ChildPath "Specials\S1"
if (Test-Path $specialsS1Path) {
    Rename-Episodes -Token $token -FolderPath $specialsS1Path -SeriesName "Freezing" -Season 0 -IsSpecial $true
}

$specialsS2Path = Join-Path -Path $BasePath -ChildPath "Specials\S2"
if (Test-Path $specialsS2Path) {
    Rename-Episodes -Token $token -FolderPath $specialsS2Path -SeriesName "Freezing Vibration" -Season 0 -IsSpecial $true
}

Write-Host "Episode renaming completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Attribution: Metadata provided by TheTVDB (https://thetvdb.com)" -ForegroundColor Gray