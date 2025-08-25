# TheTVDB.psm1 - TheTVDB API Functions
# Extracted from Anime-File-Organizer.ps1 (lines 22-252)
# Pure API functionality - no dependencies

# TheTVDB API Configuration
$BaseApiUrl = "https://api4.thetvdb.com/v4"
$Headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}

# Debug mode flag for compatibility
$DebugMode = $true

function Write-Debug-Info {
    param($Message, $Color = "Cyan")
    if ($DebugMode) {
        Write-Host "[DEBUG] $Message" -ForegroundColor $Color
    }
}

# Heuristic check: returns $true if a name looks like romanized Japanese rather than a localized English title
function Test-IsRomanizedJapaneseName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    # Indicators: macrons (āēīōū), common romanized particles, or typical romaji terms
    $hasMacrons = $Name -match '[āēīōū]'
    $hasParticles = $Name -match '(?i)\b(no|ni|wo|ga|to|de|wa|ka)\b'
    $hasRomajiTerms = $Name -match '(?i)(mahou|mahō|jutsushi|yarinaoshi|shoujo|shōjo|otome|seishun|monogatari|senpai|kouhai)'
    return ($hasMacrons -or $hasParticles -or $hasRomajiTerms)
}

function Get-TheTVDBToken {
    param($ApiKey, $Pin)
    
    Write-Debug-Info "Starting authentication process"
    $keyPreview = if ($ApiKey.Length -ge 8) { $ApiKey.Substring(0,8) } else { $ApiKey }
    Write-Debug-Info "API Key: ${keyPreview}..." "Gray"
    
    $loginBody = @{
        apikey = $ApiKey
    }
    
    if ($Pin) {
        $loginBody.pin = $Pin
        Write-Debug-Info "Using PIN for authentication" "Gray"
    }
    
    try {
        Write-Host "[AUTH] Authenticating with TheTVDB API..." -ForegroundColor Yellow
        Write-Debug-Info "Sending request to: $BaseApiUrl/login"
        $response = Invoke-RestMethod -Uri "$BaseApiUrl/login" -Method POST -Body ($loginBody | ConvertTo-Json) -Headers $Headers
        Write-Host "[SUCCESS] Authentication successful" -ForegroundColor Green
        Write-Debug-Info "Token received successfully" "Green"
        return $response.data.token
    }
    catch {
        Write-Host "[ERROR] Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Debug-Info "Authentication error details: $($_.Exception)" "Red"
        Write-Host "Please check your API key and PIN, or try without PIN for basic access." -ForegroundColor Red
        return $null
    }
}

function Get-SeriesInfo {
    param($Token, $SeriesId)
    
    $authHeaders = $Headers.Clone()
    $authHeaders["Authorization"] = "Bearer $Token"
    
    try {
        Write-Host "[API] Fetching series information..." -ForegroundColor Yellow
        Write-Debug-Info "Fetching series data for ID: $SeriesId"
        $response = Invoke-RestMethod -Uri "$BaseApiUrl/series/$SeriesId" -Method GET -Headers $authHeaders
        $seriesData = $response.data
        
        Write-Debug-Info "Original series name: $($seriesData.name)"
        
        # FORCE English translations - try multiple approaches
        $englishName = $null
        
        # Method 1: Check if original name is already in English (prioritize main title if English)
        if ($seriesData.name -match '^[\x20-\x7E]+$' -and 
            $seriesData.name -match '\b(the|and|in|on|at|for|with|by|from|up|about|into|over|after|of|to|a|an)\b' -and
            $seriesData.name -notmatch '(?i)(kaifuku|jutsushi|yarinaoshi|sokushi|mahō|mahou|skill|copy|choetsu|heal|kaiyari)') {
            $englishName = $seriesData.name
            Write-Debug-Info "Original name appears to be English: $englishName"
        }
        
        # Method 2: Try English translations endpoint (only if original wasn't English)
        if (-not $englishName) {
            try {
                Write-Debug-Info "Trying English translations endpoint..."
                $translationResponse = Invoke-RestMethod -Uri "$BaseApiUrl/series/$SeriesId/translations/eng" -Method GET -Headers $authHeaders
                Write-Debug-Info "Translation response: $($translationResponse | ConvertTo-Json -Depth 3)"
                if ($translationResponse.data -and $translationResponse.data.name) {
                    $englishName = $translationResponse.data.name
                    Write-Debug-Info "Found English translation: $englishName"
                } else {
                    Write-Debug-Info "No translation data or name found in response"
                }
            }
            catch {
                Write-Debug-Info "English translations endpoint failed: $($_.Exception.Message)"
            }
        }
        
        # Method 3: Try to get alternate names/aliases (only if still no English name found)
        if (-not $englishName) {
            try {
                Write-Debug-Info "Trying series extended info for aliases..."
                $extendedResponse = Invoke-RestMethod -Uri "$BaseApiUrl/series/$SeriesId/extended" -Method GET -Headers $authHeaders
                if ($extendedResponse.data.aliases) {
                    Write-Debug-Info "Found $($extendedResponse.data.aliases.Count) aliases to check"
                    foreach ($alias in $extendedResponse.data.aliases) {
                        Write-Debug-Info "Checking alias: '$($alias.name)' (Language: $($alias.language))"
                        # Only accept aliases that are clearly English translations, not romanized Japanese
                        if ($alias.language -eq "eng" -and 
                            $alias.name -match '^[\x20-\x7E]+$' -and
                            $alias.name -notmatch '(?i)(kaifuku|jutsushi|yarinaoshi|sokushi|mahō|mahou|skill|copy|choetsu|heal|kaiyari)' -and
                            $alias.name -match '\b(of|the|and|in|on|at|for|with|by|from|up|about|into|over|after)\b') {
                            $englishName = $alias.name
                            Write-Debug-Info "Found English alias: $englishName"
                            break
                        } else {
                            Write-Debug-Info "Rejected alias '$($alias.name)' - reason: language=$($alias.language), contains_japanese=$($alias.name -match '(?i)(kaifuku|jutsushi|yarinaoshi|sokushi|mahō|mahou|skill|copy|choetsu|heal|kaiyari)')"
                        }
                    }
                } else {
                    Write-Debug-Info "No aliases found in extended data"
                }
            }
            catch {
                Write-Debug-Info "Extended series info failed: $($_.Exception.Message)"
            }
        }
        
        # Use English name if found, otherwise use original with warning
        if ($englishName) {
            $seriesData.name = $englishName
            Write-Host "[SUCCESS] Using English name: $englishName" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] No English translation found, using original/romanized name: $($seriesData.name)" -ForegroundColor Yellow
            Write-Host "[INFO] Consider adding the English title to TheTVDB if you know it" -ForegroundColor Gray
        }
        
        return $seriesData
    }
    catch {
        Write-Host "[ERROR] Failed to get series information: $($_.Exception.Message)" -ForegroundColor Red
        Write-Debug-Info "Series info error: $($_.Exception.Message)" "Red"
        return $null
    }
}

function Get-SeriesEpisodes {
    param($Token, $SeriesId)
    
    $authHeaders = $Headers.Clone()
    $authHeaders["Authorization"] = "Bearer $Token"
    
    try {
        Write-Host "[API] Fetching all episodes and seasons..." -ForegroundColor Yellow
        Write-Debug-Info "Fetching episodes for series ID: $SeriesId"
        $allEpisodes = @()
        $page = 0
        
        do {
            Write-Debug-Info "Fetching page $page of episodes..."
            $response = Invoke-RestMethod -Uri "$BaseApiUrl/series/$SeriesId/episodes/default?page=$page" -Method GET -Headers $authHeaders
            if ($response.data.episodes) {
                $allEpisodes += $response.data.episodes
                Write-Debug-Info "Found $($response.data.episodes.Count) episodes on page $page"
            }
            $page++
        } while ($response.data.episodes -and $response.data.episodes.Count -gt 0)
        
        Write-Debug-Info "Total episodes fetched: $($allEpisodes.Count)"
        
        # Process each episode to get English titles
        foreach ($episode in $allEpisodes) {
            $originalName = $episode.name
            Write-Debug-Info "Processing episode $($episode.number): $originalName"
            
            # Try to get English translation for this episode
            try {
                $episodeTranslation = Invoke-RestMethod -Uri "$BaseApiUrl/episodes/$($episode.id)/translations/eng" -Method GET -Headers $authHeaders
                if ($episodeTranslation.data -and $episodeTranslation.data.name -and $episodeTranslation.data.name -match '^[\x20-\x7E]+$') {
                    $episode.name = $episodeTranslation.data.name
                    Write-Debug-Info "  -> Using English title: $($episode.name)"
                } else {
                    # Check if original name is already English (ASCII only)
                    if ($originalName -match '^[\x20-\x7E]+$') {
                        Write-Debug-Info "  -> Original title appears to be English: $originalName"
                    } else {
                        # If no English translation and not ASCII, use a generic title
                        $episode.name = "Episode $($episode.number)"
                        Write-Debug-Info "  -> No English title found, using generic: $($episode.name)"
                    }
                }
            }
            catch {
                # If translation fails, check if original is English or use generic
                if ($originalName -match '^[\x20-\x7E]+$') {
                    Write-Debug-Info "  -> Translation failed, but original appears English: $originalName"
                } else {
                    $episode.name = "Episode $($episode.number)"
                    Write-Debug-Info "  -> Translation failed, using generic: $($episode.name)"
                }
            }
        }
        
        return $allEpisodes
    }
    catch {
        Write-Host "[ERROR] Failed to get episodes: $($_.Exception.Message)" -ForegroundColor Red
        Write-Debug-Info "Episodes fetch error: $($_.Exception.Message)" "Red"
        return @()
    }
}

# Export functions
Export-ModuleMember -Function Get-TheTVDBToken, Get-SeriesInfo, Get-SeriesEpisodes, Test-IsRomanizedJapaneseName