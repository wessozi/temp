# AnimeOrganizer.Logging.psm1 - Enhanced Logging System
# Phase 3: Enhanced Features - Structured Logging Implementation

# Logging Configuration
$script:LogConfig = @{
    LogLevel = "INFO"  # DEBUG, INFO, WARNING, ERROR
    LogToFile = $true
    LogFilePath = Join-Path $PSScriptRoot "..\..\logs"
    LogFileName = "anime-organizer-$(Get-Date -Format 'yyyyMMdd').log"
    ConsoleOutput = $true
    ColorsEnabled = $true
}

# Log Level Enum
enum LogLevel {
    DEBUG = 1
    INFO = 2
    WARNING = 3
    ERROR = 4
}

# Initialize logging
function Initialize-Logging {
    param(
        [string]$LogLevel = "INFO",
        [bool]$LogToFile = $true,
        [bool]$ConsoleOutput = $true,
        [string]$LogDirectory = (Join-Path $PSScriptRoot "..\..\logs")
    )
    
    $script:LogConfig.LogLevel = $LogLevel.ToUpper()
    $script:LogConfig.LogToFile = $LogToFile
    $script:LogConfig.ConsoleOutput = $ConsoleOutput
    $script:LogConfig.LogFilePath = $LogDirectory
    
    # Create logs directory if it doesn't exist
    if ($LogToFile -and (-not (Test-Path $LogDirectory))) {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
    }
    
    # Set log file name with timestamp
    $script:LogConfig.LogFileName = "anime-organizer-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
}

# Get current log level as numeric value
function Get-LogLevelValue {
    param([string]$Level)
    
    switch ($Level.ToUpper()) {
        "DEBUG" { return [LogLevel]::DEBUG }
        "INFO" { return [LogLevel]::INFO }
        "WARNING" { return [LogLevel]::WARNING }
        "ERROR" { return [LogLevel]::ERROR }
        default { return [LogLevel]::INFO }
    }
}

# Check if logging is enabled for given level
function Should-Log {
    param([string]$Level)
    
    $currentLevel = Get-LogLevelValue -Level $script:LogConfig.LogLevel
    $requestedLevel = Get-LogLevelValue -Level $Level
    
    return $requestedLevel -ge $currentLevel
}

# Write log message
function Write-Log {
    param(
        [string]$Level,
        [string]$Message,
        [string]$Category = "General",
        [hashtable]$ExtraData = $null
    )
    
    if (-not (Should-Log -Level $Level)) {
        return
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = @{
        Timestamp = $timestamp
        Level = $Level.ToUpper()
        Category = $Category
        Message = $Message
    }
    
    if ($ExtraData) {
        $logEntry.ExtraData = $ExtraData
    }
    
    $logJson = $logEntry | ConvertTo-Json -Compress
    
    # Console output
    if ($script:LogConfig.ConsoleOutput) {
        $color = switch ($Level.ToUpper()) {
            "DEBUG" { "Gray" }
            "INFO" { "White" }
            "WARNING" { "Yellow" }
            "ERROR" { "Red" }
            default { "White" }
        }
        
        Write-Host "[$timestamp] [$($Level.ToUpper())] $Message" -ForegroundColor $color
    }
    
    # File output
    if ($script:LogConfig.LogToFile) {
        $logFile = Join-Path $script:LogConfig.LogFilePath $script:LogConfig.LogFileName
        try {
            Add-Content -Path $logFile -Value $logJson -Encoding UTF8
        }
        catch {
            Write-Host "[ERROR] Failed to write to log file: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Convenience functions for each log level
function Write-DebugLog {
    param([string]$Message, [string]$Category = "Debug", [hashtable]$ExtraData = $null)
    Write-Log -Level "DEBUG" -Message $Message -Category $Category -ExtraData $ExtraData
}

function Write-InfoLog {
    param([string]$Message, [string]$Category = "Info", [hashtable]$ExtraData = $null)
    Write-Log -Level "INFO" -Message $Message -Category $Category -ExtraData $ExtraData
}

function Write-WarningLog {
    param([string]$Message, [string]$Category = "Warning", [hashtable]$ExtraData = $null)
    Write-Log -Level "WARNING" -Message $Message -Category $Category -ExtraData $ExtraData
}

function Write-ErrorLog {
    param([string]$Message, [string]$Category = "Error", [hashtable]$ExtraData = $null)
    Write-Log -Level "ERROR" -Message $Message -Category $Category -ExtraData $ExtraData
}

# Performance logging
function Measure-Performance {
    param(
        [string]$OperationName,
        [scriptblock]$ScriptBlock,
        [string]$Category = "Performance"
    )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        $result = & $ScriptBlock
        $stopwatch.Stop()
        
        Write-InfoLog -Message "Operation '$OperationName' completed in $($stopwatch.Elapsed.TotalMilliseconds)ms" -Category $Category -ExtraData @{
            Operation = $OperationName
            DurationMs = $stopwatch.Elapsed.TotalMilliseconds
            Success = $true
        }
        
        return $result
    }
    catch {
        $stopwatch.Stop()
        
        Write-ErrorLog -Message "Operation '$OperationName' failed after $($stopwatch.Elapsed.TotalMilliseconds)ms: $($_.Exception.Message)" -Category $Category -ExtraData @{
            Operation = $OperationName
            DurationMs = $stopwatch.Elapsed.TotalMilliseconds
            Success = $false
            Error = $_.Exception.Message
        }
        
        throw
    }
}

# Export functions
Export-ModuleMember -Function Initialize-Logging, Write-DebugLog, Write-InfoLog, Write-WarningLog, Write-ErrorLog, Measure-Performance, Should-Log, Get-LogLevelValue