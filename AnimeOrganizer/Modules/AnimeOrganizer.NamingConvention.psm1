# AnimeOrganizer.NamingConvention.psm1
# Centralized naming convention system for anime file organization

function Import-NamingConvention {
    param(
        [string]$ConventionName = $null
    )
    
    # Get config path
    $configPath = Join-Path $PSScriptRoot "..\Config\settings.json"
    
    if (-not (Test-Path $configPath)) {
        Write-Warning "Configuration file not found at: $configPath"
        return Get-DefaultConvention
    }
    
    try {
        $config = Get-Content $configPath | ConvertFrom-Json
        
        # Determine which convention to use
        $activeConvention = $ConventionName
        if (-not $activeConvention) {
            $activeConvention = $config.naming.active_convention
        }
        
        # Get the specific convention
        $convention = $config.naming.conventions.$activeConvention
        
        if (-not $convention) {
            Write-Warning "Convention '$activeConvention' not found, using default"
            return Get-DefaultConvention
        }
        
        return $convention
    }
    catch {
        Write-Warning "Error loading naming convention: $($_.Exception.Message)"
        return Get-DefaultConvention
    }
}

function Get-DefaultConvention {
    return @{
        series_format = "{series}.S{season:D2}E{episode:D2}.{title}"
        special_format = "{series}.S00E{episode:D2}.{title}"
        version_format = "{base}.v{version}"
        metadata = @{
            include_resolution = $false
            include_codec = $false
            include_source = $false
            include_year = $false
        }
    }
}

function Format-SeriesEpisodeName {
    param(
        [Parameter(Mandatory=$true)]
        [object]$SeriesInfo,
        
        [Parameter(Mandatory=$true)]
        [int]$SeasonNumber,
        
        [Parameter(Mandatory=$true)]
        [int]$EpisodeNumber,
        
        [Parameter(Mandatory=$true)]
        [object]$EpisodeInfo,
        
        [Parameter(Mandatory=$true)]
        [string]$FileExtension,
        
        [hashtable]$Metadata = @{},
        
        [object]$Convention = $null
    )
    
    if (-not $Convention) {
        $Convention = Import-NamingConvention
    }
    
    # Determine which format to use
    $template = if ($SeasonNumber -eq 0) { 
        $Convention.special_format 
    } else { 
        $Convention.series_format 
    }
    
    # Prepare variables for template expansion
    $variables = @{
        series = $SeriesInfo.name
        season = $SeasonNumber
        episode = $EpisodeNumber
        title = $EpisodeInfo.name
    }
    
    # Add metadata if convention requires it
    if ($Convention.metadata.include_year -and $Metadata.year) {
        $variables.year = $Metadata.year
    }
    if ($Convention.metadata.include_resolution -and $Metadata.resolution) {
        $variables.resolution = $Metadata.resolution
    }
    if ($Convention.metadata.include_codec -and $Metadata.codec) {
        $variables.codec = $Metadata.codec
    }
    if ($Convention.metadata.include_source -and $Metadata.source) {
        $variables.source = $Metadata.source
    }
    
    # Expand template
    $fileName = Expand-NamingTemplate -Template $template -Variables $variables
    
    # Add extension
    $fileName = $fileName + $FileExtension
    
    # Clean filename
    $fileName = Get-SafeFileName -FileName $fileName
    
    return $fileName
}

function Format-VersionedName {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BaseName,
        
        [Parameter(Mandatory=$true)]
        [int]$VersionNumber,
        
        [object]$Convention = $null
    )
    
    if (-not $Convention) {
        $Convention = Import-NamingConvention
    }
    
    $variables = @{
        base = $BaseName
        version = $VersionNumber
    }
    
    return Expand-NamingTemplate -Template $Convention.version_format -Variables $variables
}

function Expand-NamingTemplate {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Template,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Variables
    )
    
    $result = $Template
    
    # Handle formatting directives like {episode:D2}
    $result = [regex]::Replace($result, '\{(\w+):D(\d+)\}', {
        param($match)
        $varName = $match.Groups[1].Value
        $digits = [int]$match.Groups[2].Value
        if ($Variables.ContainsKey($varName)) {
            $Variables[$varName].ToString().PadLeft($digits, '0')
        } else {
            $match.Value
        }
    })
    
    # Replace simple {variable} placeholders
    foreach ($key in $Variables.Keys) {
        $placeholder = "{$key}"
        $value = $Variables[$key]
        if ($value) {
            $result = $result -replace [regex]::Escape($placeholder), $value
        }
    }
    
    return $result
}

function Extract-MediaMetadata {
    param(
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]$File
    )
    
    $metadata = @{
        resolution = $null
        codec = $null
        source = $null
        year = $null
    }
    
    $name = $File.BaseName
    
    # Resolution detection
    if ($name -match '(1080p|720p|480p|4K|2160p|1440p)') {
        $metadata.resolution = $matches[1]
    }
    
    # Codec detection  
    if ($name -match '(x264|x265|H\.264|H\.265|HEVC|AV1)') {
        $metadata.codec = $matches[1]
    }
    
    # Source detection
    if ($name -match '(BluRay|BDRip|WEB-DL|WEBRip|HDTV|DVDRip)') {
        $metadata.source = $matches[1]  
    }
    
    # Year detection
    if ($name -match '(19\d{2}|20\d{2})') {
        $metadata.year = $matches[1]
    }
    
    return $metadata
}

function Get-AvailableConventions {
    $configPath = Join-Path $PSScriptRoot "..\Config\settings.json"
    
    if (-not (Test-Path $configPath)) {
        return @("default")
    }
    
    try {
        $config = Get-Content $configPath | ConvertFrom-Json
        return $config.naming.conventions.PSObject.Properties.Name
    }
    catch {
        Write-Warning "Error reading conventions: $($_.Exception.Message)"
        return @("default")
    }
}

function Test-NamingConvention {
    param(
        [string]$ConventionName,
        [hashtable]$SampleData
    )
    
    $convention = Import-NamingConvention -ConventionName $ConventionName
    
    $testResult = Format-SeriesEpisodeName `
        -SeriesInfo $SampleData.SeriesInfo `
        -SeasonNumber $SampleData.SeasonNumber `
        -EpisodeNumber $SampleData.EpisodeNumber `
        -EpisodeInfo $SampleData.EpisodeInfo `
        -FileExtension $SampleData.FileExtension `
        -Metadata $SampleData.Metadata `
        -Convention $convention
    
    return $testResult
}

function Get-SafeFileName {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileName
    )
    
    # Replace all spaces with dots (as requested)
    $safeFileName = $FileName -replace '\s+', '.'
    
    # Replace invalid filename characters
    $safeFileName = $safeFileName -replace ':', '-'
    $safeFileName = $safeFileName -replace '/', '-'
    $safeFileName = $safeFileName -replace '\\', '-'
    $safeFileName = $safeFileName -replace '\|', '-'
    $safeFileName = $safeFileName -replace '\?', ''
    $safeFileName = $safeFileName -replace '\*', ''
    $safeFileName = $safeFileName -replace '<', ''
    $safeFileName = $safeFileName -replace '>', ''
    $safeFileName = $safeFileName -replace '"', ''
    
    # Clean up multiple dots and dashes
    $safeFileName = $safeFileName -replace '\.+', '.'
    $safeFileName = $safeFileName -replace '-+', '-'
    $safeFileName = $safeFileName -replace '^\.|-$', ''
    $safeFileName = $safeFileName.Trim()
    
    return $safeFileName
}

# Export all functions
Export-ModuleMember -Function Import-NamingConvention, Format-SeriesEpisodeName, Format-VersionedName, Extract-MediaMetadata, Get-AvailableConventions, Test-NamingConvention, Get-SafeFileName, Expand-NamingTemplate