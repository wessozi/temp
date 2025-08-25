# AnimeOrganizer.ErrorHandling.psm1 - Enhanced Error Recovery System
# Phase 3: Enhanced Features - Error Recovery Implementation

# Import logging functions with fallbacks
function Write-LogFallback {
    param([string]$Level, [string]$Message)
    
    if (Get-Command -Name "Write-${Level}Log" -ErrorAction SilentlyContinue) {
        & "Write-${Level}Log" -Message $Message -Category "ErrorHandling"
    } else {
        Write-Host "[$($Level.ToUpper())] $Message" -ForegroundColor $(switch ($Level) {
            "Error" { "Red" }
            "Warning" { "Yellow" }
            "Info" { "White" }
            "Debug" { "Gray" }
            default { "White" }
        })
    }
}

# Define logging functions with fallbacks
function Write-ErrorFallback { param([string]$Message) Write-LogFallback -Level "Error" -Message $Message }
function Write-WarningFallback { param([string]$Message) Write-LogFallback -Level "Warning" -Message $Message }
function Write-InfoFallback { param([string]$Message) Write-LogFallback -Level "Info" -Message $Message }
function Write-DebugFallback { param([string]$Message) Write-LogFallback -Level "Debug" -Message $Message }

# Error recovery configuration
$script:ErrorConfig = @{
    MaxRetryAttempts = 3
    RetryDelayMs = 1000
    EnableRollback = $true
    SafeMode = $false
}

# Initialize error handling
function Initialize-ErrorHandling {
    param(
        [int]$MaxRetryAttempts = 3,
        [int]$RetryDelayMs = 1000,
        [bool]$EnableRollback = $true,
        [bool]$SafeMode = $false
    )
    
    $script:ErrorConfig.MaxRetryAttempts = $MaxRetryAttempts
    $script:ErrorConfig.RetryDelayMs = $RetryDelayMs
    $script:ErrorConfig.EnableRollback = $EnableRollback
    $script:ErrorConfig.SafeMode = $SafeMode
}

# Operation tracking for rollback
$script:OperationStack = [System.Collections.Stack]::new()

# Safe execution with retry logic
function Invoke-SafeOperation {
    param(
        [string]$OperationName,
        [scriptblock]$Operation,
        [scriptblock]$RollbackOperation = $null,
        [int]$MaxRetries = $script:ErrorConfig.MaxRetryAttempts,
        [int]$RetryDelayMs = $script:ErrorConfig.RetryDelayMs
    )
    
    $attempt = 0
    $lastError = $null
    
    while ($attempt -le $MaxRetries) {
        $attempt++
        
        try {
            if ($attempt -gt 1) {
                Write-InfoFallback "Retry attempt $attempt of $MaxRetries for operation: $OperationName"
                Start-Sleep -Milliseconds $RetryDelayMs
            }
            
            # Track operation for potential rollback
            if ($script:ErrorConfig.EnableRollback -and $RollbackOperation) {
                $operationId = [Guid]::NewGuid().ToString()
                $script:OperationStack.Push(@{
                    Id = $operationId
                    Name = $OperationName
                    Rollback = $RollbackOperation
                    Timestamp = Get-Date
                })
                Write-DebugFallback "Tracked operation for rollback: $OperationName (ID: $operationId)"
            }
            
            # Execute the operation
            $result = & $Operation
            
            # Operation succeeded, remove from rollback stack
            if ($script:ErrorConfig.EnableRollback -and $RollbackOperation) {
                $script:OperationStack.Pop() | Out-Null
            }
            
            return $result
        }
        catch {
            $lastError = $_.Exception
            Write-ErrorFallback "Operation '$OperationName' failed on attempt $($attempt): $($_.Exception.Message)"
            
            if ($attempt -eq $MaxRetries) {
                Write-ErrorFallback "Maximum retry attempts ($MaxRetries) exceeded for operation: $OperationName"
                
                # Execute rollback if enabled
                if ($script:ErrorConfig.EnableRollback) {
                    Write-WarningFallback "Initiating rollback for failed operation: $OperationName"
                    Invoke-RollbackOperations
                }
                
                throw $lastError
            }
        }
    }
}

# Rollback all tracked operations
function Invoke-RollbackOperations {
    $rollbackCount = 0
    
    Write-InfoFallback "Starting rollback of $($script:OperationStack.Count) operations"
    
    while ($script:OperationStack.Count -gt 0) {
        $operation = $script:OperationStack.Pop()
        $rollbackCount++
        
        try {
            Write-InfoFallback "Rolling back operation: $($operation.Name)"
            & $operation.Rollback
            Write-InfoFallback "Successfully rolled back: $($operation.Name)"
        }
        catch {
            Write-ErrorFallback "Failed to rollback operation '$($operation.Name)': $($_.Exception.Message)"
            # Continue with other rollbacks even if one fails
        }
    }
    
    Write-InfoFallback "Rollback completed. $rollbackCount operations rolled back."
}

# Clear operation stack without rollback
function Clear-OperationStack {
    $count = $script:OperationStack.Count
    $script:OperationStack.Clear()
    Write-InfoFallback "Cleared operation stack ($count operations)"
}

# Safe file operations with rollback support
function Invoke-SafeFileOperation {
    param(
        [string]$OperationName,
        [scriptblock]$FileOperation,
        [string]$SourcePath,
        [string]$DestinationPath = $null
    )
    
    $backupPath = $null
    
    # Create backup if source file exists and rollback is enabled
    if ($script:ErrorConfig.EnableRollback -and (Test-Path -LiteralPath $SourcePath)) {
        $backupDir = [System.IO.Path]::Combine($env:TEMP, "AnimeOrganizerBackups")
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }
        
        $backupPath = [System.IO.Path]::Combine($backupDir, "$(Get-Date -Format 'yyyyMMdd-HHmmss')-$(Split-Path $SourcePath -Leaf)")
        Copy-Item -LiteralPath $SourcePath -Destination $backupPath -Force
        
        Write-DebugFallback "Created backup of '$SourcePath' at '$backupPath'"
    }
    
    # Rollback operation: restore from backup if exists
    $rollbackOperation = {
        if ($backupPath -and (Test-Path -LiteralPath $backupPath)) {
            Write-InfoFallback "Restoring file from backup: $SourcePath"
            Copy-Item -LiteralPath $backupPath -Destination $SourcePath -Force
            Remove-Item -LiteralPath $backupPath -Force
        }
        elseif ($DestinationPath -and (Test-Path -LiteralPath $DestinationPath)) {
            Write-InfoFallback "Cleaning up destination file: $DestinationPath"
            Remove-Item -LiteralPath $DestinationPath -Force
        }
    }
    
    # Execute the file operation with retry and rollback support
    return Invoke-SafeOperation -OperationName $OperationName -Operation $FileOperation -RollbackOperation $rollbackOperation
}

# API call with retry logic
function Invoke-SafeApiCall {
    param(
        [string]$ApiName,
        [scriptblock]$ApiCall,
        [int]$MaxRetries = $script:ErrorConfig.MaxRetryAttempts
    )
    
    return Invoke-SafeOperation -OperationName "API: $ApiName" -Operation $ApiCall -MaxRetries $MaxRetries
}

# Export functions
Export-ModuleMember -Function Initialize-ErrorHandling, Invoke-SafeOperation, Invoke-SafeFileOperation, Invoke-SafeApiCall, Invoke-RollbackOperations, Clear-OperationStack