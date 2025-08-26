# VideoMetadata.psm1 - Video Metadata Extraction using FFprobe
# Extracts video quality information to enhance filename generation
# Requires FFprobe.exe to be available in the bin directory

function Test-FFprobeDependency {
    <#
    .SYNOPSIS
    Checks if FFprobe.exe is available and accessible
    
    .DESCRIPTION
    Verifies that FFprobe.exe exists in the expected location and can be executed
    Returns $true if available, $false otherwise with helpful error messages
    #>
    param()
    
    $ffprobePath = Join-Path $PSScriptRoot "..\bin\ffprobe\ffprobe.exe"
    
    if (-not (Test-Path $ffprobePath)) {
        Write-Host "[ERROR] FFprobe.exe not found!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Metadata extraction requires FFprobe.exe" -ForegroundColor Yellow
        Write-Host "Please download FFmpeg from: https://ffmpeg.org/download.html" -ForegroundColor Cyan
        Write-Host "Extract ffprobe.exe and place it in: .\bin\ffprobe\ffprobe.exe" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "After installing FFprobe, restart the script to use metadata extraction." -ForegroundColor Yellow
        Write-Host ""
        return $false
    }
    
    try {
        # Test if FFprobe can be executed (quick version check)
        $testResult = & $ffprobePath -version 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] FFprobe.exe found but cannot be executed!" -ForegroundColor Red
            Write-Host "Error: $testResult" -ForegroundColor Red
            return $false
        }
        
        Write-Host "[SUCCESS] FFprobe.exe found and operational" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[ERROR] FFprobe.exe found but failed to execute: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Get-VideoMetadata {
    <#
    .SYNOPSIS
    Extracts comprehensive video metadata using FFprobe
    
    .DESCRIPTION
    Analyzes video file and returns detailed metadata including:
    - Video codec, resolution, bit depth
    - HDR information (HDR10, HLG, Dolby Vision)
    - Bitrate information
    - Audio stream details
    
    .PARAMETER FilePath
    Path to the video file to analyze
    
    .EXAMPLE
    $metadata = Get-VideoMetadata -FilePath "C:\Videos\episode.mkv"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    if (-not (Test-Path -LiteralPath $FilePath)) {
        Write-Warning "File not found: $FilePath"
        return $null
    }
    
    $ffprobePath = Join-Path $PSScriptRoot "..\bin\ffprobe\ffprobe.exe"
    
    if (-not (Test-Path $ffprobePath)) {
        Write-Warning "FFprobe.exe not found. Metadata extraction skipped for: $FilePath"
        return $null
    }
    
    try {
        $ffprobeArgs = @(
            '-v', 'quiet'
            '-print_format', 'json'
            '-show_format'
            '-show_streams'
            $FilePath
        )
        
        $jsonResult = & $ffprobePath @ffprobeArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "FFprobe failed for file: $FilePath. Error: $jsonResult"
            return $null
        }
        
        $metadata = $jsonResult | ConvertFrom-Json
        
        # Extract video stream information
        $videoStream = $metadata.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1
        $audioStreams = $metadata.streams | Where-Object { $_.codec_type -eq 'audio' }
        
        if (-not $videoStream) {
            Write-Warning "No video stream found in: $FilePath"
            return $null
        }
        
        # Calculate bitrates
        $totalBitrate = if ($metadata.format.bit_rate) { 
            [math]::Round($metadata.format.bit_rate / 1000000, 2) 
        } else { "Unknown" }
        
        $videoBitrate = if ($videoStream.bit_rate) { 
            [math]::Round($videoStream.bit_rate / 1000000, 2) 
        } else { "Unknown" }
        
        # Determine bit depth
        $bitDepth = if ($videoStream.bits_per_raw_sample) { 
            "$($videoStream.bits_per_raw_sample)bit" 
        } elseif ($videoStream.pix_fmt -match 'p10|10le|10be') { 
            "10bit" 
        } elseif ($videoStream.pix_fmt -match 'p12|12le|12be') { 
            "12bit" 
        } else { 
            "8bit" 
        }
        
        # HDR detection
        $isHDR = $false
        $hdrFormat = "SDR"
        if ($videoStream.color_transfer -eq 'smpte2084') {
            $isHDR = $true
            $hdrFormat = "HDR10"
        } elseif ($videoStream.color_transfer -eq 'arib-std-b67') {
            $isHDR = $true
            $hdrFormat = "HLG"
        } elseif ($videoStream.side_data_list) {
            $dolbyVision = $videoStream.side_data_list | Where-Object { $_.side_data_type -eq "DOVI configuration record" }
            if ($dolbyVision) {
                $isHDR = $true
                $hdrFormat = "Dolby.Vision"
            }
        }
        
        # Audio details
        $audioDetails = $audioStreams | ForEach-Object {
            $channels = switch ($_.channels) {
                1 { "1.0" }
                2 { "2.0" }
                6 { "5.1" }
                8 { "7.1" }
                default { "$($_.channels)ch" }
            }
            
            $audioBitrate = if ($_.bit_rate) { 
                [math]::Round($_.bit_rate / 1000, 0) 
            } else { "Unknown" }
            
            "$($_.codec_name) $channels ($audioBitrate kbps)"
        }
        
        return @{
            # Basic info
            VideoCodec = $videoStream.codec_name
            Width = $videoStream.width
            Height = $videoStream.height
            Resolution = "$($videoStream.width)x$($videoStream.height)"
            
            # Quality info
            BitDepth = $bitDepth
            PixelFormat = $videoStream.pix_fmt
            ColorSpace = $videoStream.color_space
            
            # HDR info
            IsHDR = $isHDR
            HDRFormat = $hdrFormat
            ColorTransfer = $videoStream.color_transfer
            
            # Bitrate info
            TotalBitrate = $totalBitrate
            VideoBitrate = $videoBitrate
            
            # Audio info
            AudioStreams = $audioDetails
            AudioCount = $audioStreams.Count
            
            # File info
            Duration = $metadata.format.duration
            FileSize = $metadata.format.size
            Container = $metadata.format.format_name
        }
    }
    catch {
        Write-Warning "Error extracting metadata from $FilePath : $($_.Exception.Message)"
        return $null
    }
}

function Get-QualityTag {
    <#
    .SYNOPSIS
    Formats video metadata into a dot-separated quality tag for filenames
    
    .DESCRIPTION
    Takes metadata object and creates a concise, readable quality tag
    Compatible with dot-based naming convention
    
    .PARAMETER Metadata
    Metadata object returned from Get-VideoMetadata
    
    .EXAMPLE
    $qualityTag = Get-QualityTag -Metadata $metadata
    # Returns: ".1080p.x264" or ".2160p.x265.10bit.HDR10"
    #>
    param(
        [Parameter(Mandatory=$true)]
        $Metadata
    )
    
    if (-not $Metadata) {
        return ""
    }
    
    $tags = @()
    
    # Resolution - convert height to standard format
    if ($Metadata.Height) {
        $resolution = if ($Metadata.Height -ge 2160) {
            "2160p"
        } elseif ($Metadata.Height -ge 1440) {
            "1440p"
        } elseif ($Metadata.Height -ge 1080) {
            "1080p"
        } elseif ($Metadata.Height -ge 720) {
            "720p"
        } elseif ($Metadata.Height -ge 480) {
            "480p"
        } else {
            "$($Metadata.Height)p"
        }
        $tags += $resolution
    }
    
    # Video codec - normalize common codec names
    if ($Metadata.VideoCodec) {
        $codec = switch ($Metadata.VideoCodec) {
            "hevc" { "x265" }
            "h264" { "x264" }
            "h265" { "x265" }
            "av1" { "AV1" }
            default { $Metadata.VideoCodec.ToUpper() }
        }
        $tags += $codec
    }
    
    # Bit depth - only include if not standard 8bit
    if ($Metadata.BitDepth -and $Metadata.BitDepth -ne "8bit") {
        $tags += $Metadata.BitDepth
    }
    
    # HDR format - only include if HDR content
    if ($Metadata.IsHDR -and $Metadata.HDRFormat -ne "SDR") {
        $tags += $Metadata.HDRFormat
    }
    
    # Join with dots and prefix with dot for filename integration
    if ($tags.Count -gt 0) {
        return "." + ($tags -join ".")
    } else {
        return ""
    }
}

function Write-MetadataProgress {
    <#
    .SYNOPSIS
    Shows progress for metadata extraction operations
    
    .PARAMETER Current
    Current file number being processed
    
    .PARAMETER Total
    Total number of files to process
    
    .PARAMETER FileName
    Name of current file being processed
    #>
    param(
        [int]$Current,
        [int]$Total,
        [string]$FileName
    )
    
    $percentage = [math]::Round(($Current / $Total) * 100, 1)
    Write-Host "[METADATA] Processing file $Current of $Total ($percentage%) - $FileName" -ForegroundColor Cyan
}

# Export functions
Export-ModuleMember -Function Test-FFprobeDependency, Get-VideoMetadata, Get-QualityTag, Write-MetadataProgress