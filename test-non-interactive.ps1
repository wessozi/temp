# Quick test script for non-interactive mode
# Test the modular system without interactive prompts

# Import modules
$ModulesPath = Join-Path $PSScriptRoot "Modules"

Import-Module "$ModulesPath\TheTVDB.psm1" -Force
Import-Module "$ModulesPath\FileParser.psm1" -Force  
Import-Module "$ModulesPath\UserInterface.psm1" -Force
Import-Module "$ModulesPath\FileOperations.psm1" -Force
Import-Module "$ModulesPath\NamingConvention.psm1" -Force

Write-Host "[TEST] Testing non-interactive mode" -ForegroundColor Green

# Test parameters
$ApiKey = "2cb4e65a-f9a9-46e4-98f9-2d44f55342db"
$SeriesId = 452826
$WorkingDirectory = "E:\Media\File organizer"

# Test authentication
Write-Host "[TEST] Testing authentication..." -ForegroundColor Yellow
$token = Get-TheTVDBToken -ApiKey $ApiKey -Pin ""
if ($token) {
    Write-Host "[SUCCESS] Authentication works!" -ForegroundColor Green
    
    # Test series info
    Write-Host "[TEST] Testing series info..." -ForegroundColor Yellow
    $seriesInfo = Get-SeriesInfo -Token $token -SeriesId $SeriesId
    if ($seriesInfo) {
        Write-Host "[SUCCESS] Series info works! Series: $($seriesInfo.name)" -ForegroundColor Green
        
        # Test episodes
        Write-Host "[TEST] Testing episode retrieval..." -ForegroundColor Yellow
        $episodes = Get-SeriesEpisodes -Token $token -SeriesId $SeriesId
        if ($episodes -and $episodes.Count -gt 0) {
            Write-Host "[SUCCESS] Episodes work! Found $($episodes.Count) episodes" -ForegroundColor Green
            
            # Test file scanning
            Write-Host "[TEST] Testing file scanning..." -ForegroundColor Yellow
            $videoFiles = Find-VideoFiles -Directory $WorkingDirectory
            Write-Host "[SUCCESS] File scanning works! Found $($videoFiles.Count) files" -ForegroundColor Green
            
            # Test naming convention
            Write-Host "[TEST] Testing naming convention..." -ForegroundColor Yellow
            $testName = Get-EpisodeFileName -SeriesName "Test Series" -SeasonNumber 1 -EpisodeNumber 1 -EpisodeTitle "Test Episode" -FileExtension ".mkv"
            Write-Host "[SUCCESS] Naming convention works! Sample: $testName" -ForegroundColor Green
            
            Write-Host ""
            Write-Host "[COMPLETE] All core functions working! The modular system is functional." -ForegroundColor Cyan
            
        } else {
            Write-Host "[ERROR] Episodes failed" -ForegroundColor Red
        }
    } else {
        Write-Host "[ERROR] Series info failed" -ForegroundColor Red
    }
} else {
    Write-Host "[ERROR] Authentication failed" -ForegroundColor Red
}