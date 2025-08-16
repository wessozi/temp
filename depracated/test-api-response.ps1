# Test script to check TheTVDB API response for Freezing episode titles
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

# Main execution
Write-Host "Testing TheTVDB API Response for Freezing (ID: 219701)" -ForegroundColor Cyan
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

Write-Host "[SUCCESS] Found $($episodes.Count) episodes" -ForegroundColor Green
Write-Host ""

# Show first 5 episodes from each season
Write-Host "Sample Episode Titles:" -ForegroundColor Magenta
Write-Host ""

$seasonGroups = $episodes | Group-Object seasonNumber | Sort-Object Name
foreach ($seasonGroup in $seasonGroups) {
    $season = $seasonGroup.Name
    $seasonEpisodes = $seasonGroup.Group | Sort-Object number | Select-Object -First 5
    
    Write-Host "Season $season Episodes:" -ForegroundColor Cyan
    foreach ($episode in $seasonEpisodes) {
        Write-Host "  Episode $($episode.number): '$($episode.name)'" -ForegroundColor White
        
        # Check if title contains Japanese characters
        if ($episode.name -match '[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]') {
            Write-Host "    ^ Contains Japanese characters" -ForegroundColor Red
        } else {
            Write-Host "    ^ English title" -ForegroundColor Green
        }
    }
    Write-Host ""
}

Write-Host "Test completed!" -ForegroundColor Green