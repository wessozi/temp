# Standalone metadata extraction test script
# Tests FFprobe integration with width-based resolution detection

param(
    [string]$TestFile = "",
    [switch]$Interactive = $true
)

# Import the VideoMetadata module
$ModulePath = ".\Modules\VideoMetadata.psm1"
if (-not (Test-Path $ModulePath)) {
    Write-Host "[ERROR] VideoMetadata module not found at: $ModulePath" -ForegroundColor Red
    exit 1
}

Import-Module $ModulePath -Force

function Test-SingleFile {
    param([string]$FilePath)
    
    Write-Host "`n=== Testing File: $FilePath ===" -ForegroundColor Cyan
    
    if (-not (Test-Path -LiteralPath $FilePath)) {
        Write-Host "[ERROR] File not found: $FilePath" -ForegroundColor Red
        return
    }
    
    Write-Host "[INFO] Extracting metadata..." -ForegroundColor Yellow
    $metadata = Get-VideoMetadata -FilePath $FilePath
    
    if ($metadata) {
        Write-Host "`nRAW METADATA:" -ForegroundColor Green
        Write-Host "  Width: $($metadata.Width)"
        Write-Host "  Height: $($metadata.Height)"
        Write-Host "  Codec: $($metadata.VideoCodec)"
        Write-Host "  BitDepth: $($metadata.BitDepth)"
        Write-Host "  ColorSpace: $($metadata.ColorSpace)"
        Write-Host "  HDR: $($metadata.HDR)"
        
        Write-Host "`nQUALITY TAG:" -ForegroundColor Green
        $qualityTag = Get-QualityTag -Metadata $metadata
        Write-Host "  Result: '$qualityTag'"
        
        # Show resolution detection logic
        Write-Host "`nRESOLUTION DETECTION LOGIC:" -ForegroundColor Magenta
        if ($metadata.Width) {
            $resolution = if ($metadata.Width -ge 3840) {
                "2160p (4K: Width >= 3840)"
            } elseif ($metadata.Width -ge 2560) {
                "1440p (QHD: Width >= 2560)"
            } elseif ($metadata.Width -ge 1920) {
                "1080p (FHD: Width >= 1920)"
            } elseif ($metadata.Width -ge 1280) {
                "720p (HD: Width >= 1280)"
            } elseif ($metadata.Width -ge 854) {
                "480p (SD: Width >= 854)"
            } else {
                "$($metadata.Height)p (Unusual: Using height)"
            }
            Write-Host "  Resolution: $resolution" -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "[ERROR] Failed to extract metadata" -ForegroundColor Red
    }
}

function Get-VideoFilesInteractive {
    $currentDir = Get-Location
    Write-Host "Current directory: $currentDir" -ForegroundColor Cyan
    
    $videoExtensions = @('*.mkv', '*.mp4', '*.avi', '*.mov', '*.wmv', '*.flv', '*.webm', '*.m4v')
    $videoFiles = @()
    
    foreach ($ext in $videoExtensions) {
        $videoFiles += Get-ChildItem -Path $currentDir -Filter $ext -File
    }
    
    if ($videoFiles.Count -eq 0) {
        Write-Host "`n[INFO] No video files found in current directory" -ForegroundColor Yellow
        return @()
    }
    
    Write-Host "`nFound $($videoFiles.Count) video files:" -ForegroundColor Green
    for ($i = 0; $i -lt $videoFiles.Count; $i++) {
        $file = $videoFiles[$i]
        $size = [math]::Round($file.Length / 1MB, 1)
        Write-Host "  $($i + 1). $($file.Name) ($size MB)" -ForegroundColor Yellow
    }
    
    return $videoFiles
}

# Main execution
Write-Host "=== FFprobe Metadata Test Script ===" -ForegroundColor Cyan
Write-Host "Width-based resolution detection enabled" -ForegroundColor Green

# Test FFprobe dependency
if (-not (Test-FFprobeDependency)) {
    Write-Host "`n[ERROR] FFprobe dependency test failed" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCCESS] FFprobe is available" -ForegroundColor Green

if ($TestFile) {
    # Test specific file
    Test-SingleFile -FilePath $TestFile
} elseif ($Interactive) {
    # Interactive mode
    $videoFiles = Get-VideoFilesInteractive
    
    if ($videoFiles.Count -eq 0) {
        Write-Host "No files to test. Exiting." -ForegroundColor Yellow
        exit 0
    }
    
    do {
        Write-Host "`nEnter file number to test (1-$($videoFiles.Count)), or 'Q' to quit:" -ForegroundColor Cyan
        $input = Read-Host
        
        if ($input.ToUpper() -eq 'Q') {
            break
        }
        
        $fileIndex = 0
        if ([int]::TryParse($input, [ref]$fileIndex) -and $fileIndex -ge 1 -and $fileIndex -le $videoFiles.Count) {
            $selectedFile = $videoFiles[$fileIndex - 1]
            Test-SingleFile -FilePath $selectedFile.FullName
        } else {
            Write-Host "[ERROR] Invalid selection. Please enter a number between 1 and $($videoFiles.Count)" -ForegroundColor Red
        }
    } while ($true)
} else {
    Write-Host "[INFO] Non-interactive mode: Please specify -TestFile parameter" -ForegroundColor Yellow
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan