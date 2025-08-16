# Fix Season 2 episode titles using correct TheTVDB API data
param(
    [Parameter(Mandatory=$false)]
    [string]$ApiKey = "2cb4e65a-f9a9-46e4-98f9-2d44f55342db"
)

$BaseApiUrl = "https://api4.thetvdb.com/v4"
$Headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}

function Get-TheTVDBToken {
    param($ApiKey)
    
    $loginBody = @{
        apikey = $ApiKey
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

function Get-SeriesEpisodes {
    param($Token, $SeriesId)
    
    $authHeaders = $Headers.Clone()
    $authHeaders["Authorization"] = "Bearer $Token"
    
    try {
        Write-Host "[API] Fetching episodes for series $SeriesId..." -ForegroundColor Yellow
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

function Get-SafeFileName {
    param($FileName)
    $invalidChars = '[<>:"/\\|?*]'
    return $FileName -replace $invalidChars, ''
}

# Main execution
Write-Host "Fixing Season 2 Episode Titles for Freezing" -ForegroundColor Cyan
Write-Host ""

# Authenticate
$token = Get-TheTVDBToken -ApiKey $ApiKey
if (-not $token) {
    Write-Host "[ERROR] Cannot proceed without authentication" -ForegroundColor Red
    exit 1
}

# Get episodes
$episodes = Get-SeriesEpisodes -Token $token -SeriesId 219701
if ($episodes.Count -eq 0) {
    Write-Host "[ERROR] No episodes found" -ForegroundColor Red
    exit 1
}

# Get Season 2 episodes from API
$season2Episodes = $episodes | Where-Object { $_.seasonNumber -eq 2 } | Sort-Object number

Write-Host "[INFO] Found $($season2Episodes.Count) Season 2 episodes in API" -ForegroundColor Green
Write-Host ""

# Get current Season 2 files
$s2Path = "Z:\Media\NSFW\Freezing\Freezing Vibration S2"
if (-not (Test-Path $s2Path)) {
    Write-Host "[ERROR] Season 2 folder not found: $s2Path" -ForegroundColor Red
    exit 1
}

$s2Files = Get-ChildItem -Path $s2Path -Filter "*.mkv" | Sort-Object Name

Write-Host "Current Season 2 files to fix:" -ForegroundColor Yellow
foreach ($file in $s2Files) {
    Write-Host "  $($file.Name)" -ForegroundColor Gray
}
Write-Host ""

# Create rename operations
$renameOps = @()
foreach ($file in $s2Files) {
    # Parse current filename to get episode number
    if ($file.Name -match 'Freezing - S02E(\d+) - (.+)\.mkv') {
        $episodeNum = [int]$Matches[1]
        $currentTitle = $Matches[2]
        
        # Find corresponding API episode
        $apiEpisode = $season2Episodes | Where-Object { $_.number -eq $episodeNum }
        if ($apiEpisode) {
            $correctTitle = Get-SafeFileName -FileName $apiEpisode.name
            $correctFileName = "Freezing - S02E{0:D2} - $correctTitle.mkv" -f $episodeNum
            
            if ($currentTitle -ne $correctTitle) {
                $renameOps += @{
                    CurrentFile = $file.FullName
                    CurrentName = $file.Name
                    NewName = $correctFileName
                    EpisodeNum = $episodeNum
                    CurrentTitle = $currentTitle
                    CorrectTitle = $correctTitle
                }
                
                Write-Host "[NEEDS FIX] Episode $episodeNum" -ForegroundColor Red
                Write-Host "  Current: $currentTitle" -ForegroundColor Yellow
                Write-Host "  Correct: $correctTitle" -ForegroundColor Green
                Write-Host ""
            } else {
                Write-Host "[ALREADY OK] Episode $episodeNum: $currentTitle" -ForegroundColor Green
            }
        } else {
            Write-Host "[WARNING] No API data found for episode $episodeNum" -ForegroundColor Yellow
        }
    }
}

if ($renameOps.Count -eq 0) {
    Write-Host "[SUCCESS] All Season 2 episode titles are already correct!" -ForegroundColor Green
    exit 0
}

Write-Host "========================================" -ForegroundColor Magenta
Write-Host "SUMMARY OF REQUIRED FIXES" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

foreach ($op in $renameOps) {
    Write-Host "Episode $($op.EpisodeNum):" -ForegroundColor White
    Write-Host "  FROM: $($op.CurrentName)" -ForegroundColor Yellow
    Write-Host "    TO: $($op.NewName)" -ForegroundColor Green
    Write-Host ""
}

Write-Host "Total files to rename: $($renameOps.Count)" -ForegroundColor White
Write-Host ""

# Get confirmation
do {
    $choice = Read-Host "Proceed with renaming these files? (Y/N)"
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

# Execute renames
Write-Host ""
Write-Host "[EXECUTE] Renaming files..." -ForegroundColor Green
Write-Host ""

foreach ($op in $renameOps) {
    $newPath = Join-Path -Path $s2Path -ChildPath $op.NewName
    
    try {
        Rename-Item -LiteralPath $op.CurrentFile -NewName $op.NewName -ErrorAction Stop
        Write-Host "[SUCCESS] Episode $($op.EpisodeNum): $($op.CorrectTitle)" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to rename episode $($op.EpisodeNum): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "[COMPLETE] Season 2 episode title fix completed!" -ForegroundColor Green