<#
.SYNOPSIS
Standalone FFprobe metadata testing and debugging tool

.DESCRIPTION
This script helps debug discrepancies between filename claims and actual video metadata.
Useful for investigating cases where Plex shows one resolution but FFprobe detects another.

.PARAMETER FilePath
Path to the video file to analyze

.EXAMPLE  
.\test-metadata.ps1 -FilePath "file.mkv"

.EXAMPLE
.\test-metadata.ps1  # Interactive mode

.EXAMPLE
.\test-metadata.ps1 -FilePath "The Handmaid's Tale (2017) - S03E09 - Heroic (1080p BluRay x265 Silence).mkv"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$FilePath
)

$ffprobePath = ".\bin\ffprobe\ffprobe.exe"

function Write-DebugLog {
    <#
    .SYNOPSIS
    Write debug results to a log file
    #>
    param(
        [string]$Content,
        [string]$FilePath
    )
    
    try {
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path $FilePath -Leaf))
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $logFile = "debug-${timestamp}-${fileName}.log"
        
        $Content | Out-File -FilePath $logFile -Encoding UTF8 -Width 120
        Write-Host "Debug log saved: $logFile" -ForegroundColor Green
    }
    catch {
        Write-Host "Warning: Could not save log file: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Get-ClaimedResolution {
    <#
    .SYNOPSIS
    Extract resolution claims from filename
    #>
    param([string]$FileName)
    
    # Look for resolution patterns: 1080p, 720p, 2160p, 4K, etc.
    if ($FileName -match '(\d+)p') {
        return $matches[1] + "p"
    }
    if ($FileName -match '4K') {
        return "2160p (4K)"
    }
    if ($FileName -match '8K') {
        return "4320p (8K)"
    }
    return "Unknown"
}

function Get-RawFFprobeData {
    <#
    .SYNOPSIS
    Execute FFprobe and return raw metadata
    #>
    param([string]$FilePath)
    
    Write-Host "=== RAW FFPROBE EXECUTION ===" -ForegroundColor Cyan
    Write-Host "Command: $ffprobePath -v quiet -print_format json -show_format -show_streams `"$FilePath`""
    
    if (-not (Test-Path $ffprobePath)) {
        Write-Host "FFprobe not found at: $ffprobePath" -ForegroundColor Red
        return $null
    }
    
    try {
        $jsonResult = & $ffprobePath -v quiet -print_format json -show_format -show_streams $FilePath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "FFprobe failed with exit code: $LASTEXITCODE" -ForegroundColor Red
            Write-Host "Error: $jsonResult" -ForegroundColor Red
            return $null
        }
        
        Write-Host "Raw JSON Output:" -ForegroundColor Yellow
        Write-Host $jsonResult
        Write-Host ""
        
        return ($jsonResult | ConvertFrom-Json)
    }
    catch {
        Write-Host "Error executing FFprobe: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Analyze-VideoStreams {
    <#
    .SYNOPSIS
    Analyze all video streams and show selection logic
    #>
    param($Metadata)
    
    Write-Host "`n=== VIDEO STREAM ANALYSIS ===" -ForegroundColor Cyan
    
    $videoStreams = $metadata.streams | Where-Object { $_.codec_type -eq 'video' }
    
    if ($videoStreams.Count -eq 0) {
        Write-Host "No video streams found!" -ForegroundColor Red
        return $null
    }
    
    Write-Host "Found $($videoStreams.Count) video stream(s):"
    
    for ($i = 0; $i -lt $videoStreams.Count; $i++) {
        $stream = $videoStreams[$i]
        $isSelected = if ($i -eq 0) { " ← SELECTED (First Video Stream)" } else { "" }
        
        Write-Host "  Stream ${i}:${isSelected}" -ForegroundColor $(if ($i -eq 0) { "Green" } else { "Yellow" })
        Write-Host "    Resolution: $($stream.width)x$($stream.height)"
        Write-Host "    Codec: $($stream.codec_name)"
        Write-Host "    Profile: $($stream.profile)"
        Write-Host "    Level: $($stream.level)"
        Write-Host "    Bit Depth: $($stream.bits_per_raw_sample)"
        Write-Host "    Pixel Format: $($stream.pix_fmt)"
        Write-Host "    Duration: $($stream.duration)"
        
        # Detect potential thumbnail/preview streams
        if ($stream.width -lt 500 -or $stream.height -lt 300) {
            Write-Host "    ⚠️  POSSIBLE THUMBNAIL STREAM" -ForegroundColor Yellow
        }
        if ($stream.codec_name -eq "mjpeg") {
            Write-Host "    ⚠️  POSSIBLE POSTER/THUMBNAIL (MJPEG)" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    # Show which stream would be selected by the main script
    $selectedStream = $videoStreams | Select-Object -First 1
    Write-Host "Script Selection Logic: Uses first video stream" -ForegroundColor Cyan
    Write-Host "Selected: Stream 0 - $($selectedStream.width)x$($selectedStream.height)" -ForegroundColor Green
    
    if ($videoStreams.Count -gt 1) {
        Write-Host "⚠️  Multiple video streams detected - this could be the issue!" -ForegroundColor Yellow
    }
    
    return $selectedStream
}

function Get-DetailedCodecInfo {
    <#
    .SYNOPSIS
    Get detailed codec and quality information
    #>
    param($VideoStream)
    
    Write-Host "`n=== CODEC & QUALITY ANALYSIS ===" -ForegroundColor Cyan
    
    # Video codec mapping
    $codecName = switch ($VideoStream.codec_name) {
        "hevc" { "x265 (HEVC)" }
        "h264" { "x264 (AVC)" }
        "h265" { "x265 (HEVC)" }
        "av1" { "AV1" }
        "vp9" { "VP9" }
        "vp8" { "VP8" }
        default { $VideoStream.codec_name.ToUpper() }
    }
    
    # Bit depth analysis
    $bitDepth = if ($VideoStream.bits_per_raw_sample) { 
        "$($VideoStream.bits_per_raw_sample)bit" 
    } elseif ($VideoStream.pix_fmt -match 'p10|10le|10be') { 
        "10bit" 
    } elseif ($VideoStream.pix_fmt -match 'p12|12le|12be') { 
        "12bit" 
    } else { 
        "8bit" 
    }
    
    # HDR detection
    $hdrInfo = "SDR"
    if ($VideoStream.color_transfer -eq 'smpte2084') {
        $hdrInfo = "HDR10"
    } elseif ($VideoStream.color_transfer -eq 'arib-std-b67') {
        $hdrInfo = "HLG"
    }
    
    Write-Host "Video Codec: $codecName"
    Write-Host "Bit Depth: $bitDepth"
    Write-Host "HDR Format: $hdrInfo"
    Write-Host "Pixel Format: $($VideoStream.pix_fmt)"
    Write-Host "Color Space: $($VideoStream.color_space)"
    Write-Host "Color Transfer: $($VideoStream.color_transfer)"
    
    return @{
        Codec = $codecName
        BitDepth = $bitDepth
        HDR = $hdrInfo
    }
}

function Test-FileMetadata {
    <#
    .SYNOPSIS
    Main function to test and analyze a video file
    #>
    param([string]$FilePath)
    
    Write-Host ("="*80) -ForegroundColor Magenta
    Write-Host "METADATA DEBUG TEST" -ForegroundColor Magenta
    Write-Host ("="*80) -ForegroundColor Magenta
    
    # File validation
    if (-not (Test-Path -LiteralPath $FilePath)) {
        Write-Host "File not found: $FilePath" -ForegroundColor Red
        return
    }
    
    $fileName = Split-Path $FilePath -Leaf
    $fileInfo = Get-Item -LiteralPath $FilePath
    Write-Host "Testing File: $fileName" -ForegroundColor White
    Write-Host "Full Path: $FilePath" -ForegroundColor Gray
    Write-Host "File Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Gray
    
    # Filename analysis
    Write-Host "`n=== FILENAME ANALYSIS ===" -ForegroundColor Cyan
    $claimedRes = Get-ClaimedResolution -FileName $fileName
    Write-Host "Claimed Resolution: $claimedRes"
    
    # Extract other claims from filename
    if ($fileName -match '(x264|x265|hevc|avc|av1)') {
        Write-Host "Claimed Codec: $($matches[1])"
    }
    if ($fileName -match '(10bit|8bit|12bit)') {
        Write-Host "Claimed Bit Depth: $($matches[1])"
    }
    
    # FFprobe analysis
    $metadata = Get-RawFFprobeData -FilePath $FilePath
    if (-not $metadata) { return }
    
    $selectedStream = Analyze-VideoStreams -Metadata $metadata
    if (-not $selectedStream) { return }
    
    $codecInfo = Get-DetailedCodecInfo -VideoStream $selectedStream
    
    # Resolution calculation (matching main script logic - WIDTH-BASED)
    Write-Host "`n=== RESOLUTION CALCULATION ===" -ForegroundColor Cyan
    $detectedRes = if ($selectedStream.width -ge 3840) {
        "2160p"
    } elseif ($selectedStream.width -ge 2560) {
        "1440p"
    } elseif ($selectedStream.width -ge 1920) {
        "1080p"
    } elseif ($selectedStream.width -ge 1280) {
        "720p"
    } elseif ($selectedStream.width -ge 854) {
        "480p"
    } else {
        "$($selectedStream.height)p"  # Fallback to height for unusual cases
    }
    
    Write-Host "Width: $($selectedStream.width) pixels ← PRIMARY for resolution detection"
    Write-Host "Height: $($selectedStream.height) pixels"
    Write-Host "Aspect Ratio: $([math]::Round($selectedStream.width / $selectedStream.height, 2))"
    Write-Host "Detected Resolution: $detectedRes"
    
    # Generate quality tag (matching main script)
    $qualityTag = ".$detectedRes"
    $codecTag = switch ($selectedStream.codec_name) {
        "hevc" { "x265" }
        "h264" { "x264" }
        "h265" { "x265" }
        "av1" { "AV1" }
        default { $selectedStream.codec_name.ToUpper() }
    }
    $qualityTag += ".$codecTag"
    
    if ($codecInfo.BitDepth -ne "8bit") {
        $qualityTag += ".$($codecInfo.BitDepth)"
    }
    if ($codecInfo.HDR -ne "SDR") {
        $qualityTag += ".$($codecInfo.HDR)"
    }
    
    Write-Host "Generated Quality Tag: $qualityTag" -ForegroundColor Green
    
    # Comparison
    Write-Host "`n=== COMPARISON RESULTS ===" -ForegroundColor Yellow
    Write-Host "Filename Claims: $claimedRes"
    Write-Host "FFprobe Detects: $detectedRes"
    
    if ($claimedRes -ne $detectedRes -and $claimedRes -ne "Unknown") {
        Write-Host "`n*** MISMATCH DETECTED! ***" -ForegroundColor Red
        Write-Host "`nPossible causes:" -ForegroundColor Yellow
        Write-Host "1. Multiple video streams - wrong stream selected"
        Write-Host "2. Ultrawide/cropped content (old height-based detection issue)"
        Write-Host "3. Filename mislabeled by release group"
        Write-Host "4. Variable resolution content (different scenes at different resolutions)"
        Write-Host "5. Thumbnail/preview stream selected instead of main stream"
        
        if (($metadata.streams | Where-Object { $_.codec_type -eq 'video' }).Count -gt 1) {
            Write-Host "`n⚠️  MULTIPLE VIDEO STREAMS DETECTED - This is likely the issue!" -ForegroundColor Red
        }
        
        # Special case for ultrawide/cropped content
        if ($selectedStream.width -ge 1920 -and $selectedStream.height -lt 1080) {
            Write-Host "`n📺 ULTRAWIDE/CROPPED CONTENT DETECTED!" -ForegroundColor Yellow
            Write-Host "   Width: $($selectedStream.width) (1080p quality)"
            Write-Host "   Height: $($selectedStream.height) (cropped to remove black bars)"
            Write-Host "   This explains the mismatch - content is 1080p quality, cropped height!"
        }
    } else {
        Write-Host "`n✅ Resolution matches!" -ForegroundColor Green
    }
    
    Write-Host "`n" + ("="*80)
    
    # Capture all output for logging
    $logContent = @"
================================================================================
METADATA DEBUG TEST - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
================================================================================
Testing File: $fileName
Full Path: $FilePath
File Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB

=== FILENAME ANALYSIS ===
Claimed Resolution: $claimedRes

=== FFPROBE DETECTION ===
Width: $($selectedStream.width) pixels (PRIMARY for resolution)
Height: $($selectedStream.height) pixels
Detected Resolution: $detectedRes
Generated Quality Tag: $qualityTag

=== VIDEO STREAM INFO ===
Codec: $($selectedStream.codec_name)
Profile: $($selectedStream.profile)
Bit Depth: $($codecInfo.BitDepth)
HDR Format: $($codecInfo.HDR)
Pixel Format: $($selectedStream.pix_fmt)

=== COMPARISON RESULTS ===
Filename Claims: $claimedRes
FFprobe Detects: $detectedRes
Match Status: $(if ($claimedRes -eq $detectedRes -or $claimedRes -eq "Unknown") { "✅ MATCH" } else { "❌ MISMATCH" })

=== VIDEO STREAMS FOUND ===
Total Video Streams: $(($metadata.streams | Where-Object { $_.codec_type -eq 'video' }).Count)
"@

    if ($metadata.streams | Where-Object { $_.codec_type -eq 'video' }) {
        $streamInfo = ""
        $videoStreams = $metadata.streams | Where-Object { $_.codec_type -eq 'video' }
        for ($i = 0; $i -lt $videoStreams.Count; $i++) {
            $stream = $videoStreams[$i]
            $selected = if ($i -eq 0) { " (SELECTED)" } else { "" }
            $streamInfo += "Stream ${i}${selected}: $($stream.width)x$($stream.height) $($stream.codec_name)`n"
        }
        $logContent += "`n$streamInfo"
    }

    # Save debug log
    Write-DebugLog -Content $logContent -FilePath $FilePath
}

# Main execution
Write-Host "FFprobe Metadata Debug Tool" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan

# FFprobe dependency check
if (-not (Test-Path $ffprobePath)) {
    Write-Host "FFprobe not found at: $ffprobePath" -ForegroundColor Red
    Write-Host "Please ensure FFprobe is installed in the bin/ffprobe directory." -ForegroundColor Yellow
    Write-Host "See bin/ffprobe/README-FFprobe.md for installation instructions." -ForegroundColor Yellow
    exit 1
}

if ($FilePath) {
    # Command line parameter provided
    Test-FileMetadata -FilePath $FilePath
} else {
    # Simple single-input mode
    Write-Host "Enter the full file path to analyze:" -ForegroundColor Green
    $inputFile = Read-Host "File path"
    
    if ($inputFile) {
        $inputFile = $inputFile.Trim().Trim('"').Trim("'")  # Clean quotes
        Test-FileMetadata -FilePath $inputFile
    } else {
        Write-Host "No file path provided. Exiting." -ForegroundColor Yellow
    }
}