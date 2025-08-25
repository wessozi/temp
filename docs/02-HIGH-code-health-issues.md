# HIGH Priority Code Health Issues

**Priority: HIGH** - These issues impact maintainability, reliability, and professional code quality.

## 🔧 HIGH-01: Code Duplication - Write-Debug-Info Function

**Files:** All 5 modules + main script  
**Impact:** Maintenance nightmare, inconsistent behavior  
**Lines of Duplicated Code:** ~42 lines (7 lines × 6 files)

**Current Duplication:**
```powershell
# DUPLICATED in every file:
function Write-Debug-Info {
    param($Message, $Color = "Cyan")
    if ($DebugMode) {
        Write-Host "[DEBUG] $Message" -ForegroundColor $Color
    }
}
```

**Problems:**
- ❌ 6 identical functions across codebase
- ❌ Inconsistent debug formatting if one copy changes  
- ❌ Violates DRY (Don't Repeat Yourself) principle
- ❌ Maintenance burden when making debug improvements

**Implementable Fix:**

**Option A: Shared Debug Module**
```powershell
# Create: Modules/AnimeOrganizer.Common.psm1
param([bool]$DebugMode = $false)

function Write-Debug-Info {
    param($Message, $Color = "Cyan")
    if ($DebugMode) {
        Write-Host "[DEBUG] $Message" -ForegroundColor $Color
    }
}

Export-ModuleMember -Function Write-Debug-Info
```

**Option B: Main Script Debug Handler** (Recommended)
```powershell
# In main script:
function Initialize-DebugHandler {
    param([bool]$DebugEnabled)
    
    $script:DebugMode = $DebugEnabled
    
    # Create global debug function available to all modules
    $global:Write-AnimeDebug = {
        param($Message, $Color = "Cyan")
        if ($script:DebugMode) {
            Write-Host "[DEBUG] $Message" -ForegroundColor $Color
        }
    }
}

# In modules, replace Write-Debug-Info with:
& $global:Write-AnimeDebug "Your debug message" "Color"
```

**Implementation Steps:**
1. Choose Option B (simpler, less module complexity)
2. Create debug handler in main script
3. Replace all `Write-Debug-Info` calls with global handler
4. Remove duplicate functions from all modules
5. Test debug output consistency

---

## 🔧 HIGH-02: PowerShell Approved Verb Violations

**Files:** `FileParser.psm1`, `FileOperations.psm1`  
**Impact:** Professional standards, PowerShell ecosystem compatibility  

**Current Warnings:**
```
WARNING: The names of some imported commands from the module 'FileParser' include 
unapproved verbs that might make them less discoverable.
```

**Unapproved Functions:**
```powershell
# UNAPPROVED VERBS:
Find-VideoFiles       # 'Find' is unapproved
Parse-EpisodeNumber   # 'Parse' is unapproved  
Execute-FileOperations # 'Execute' is unapproved
```

**Implementable Fix:**
```powershell
# APPROVED VERB REPLACEMENTS:
Get-VideoFiles        # Find → Get (approved)
Get-EpisodeNumber     # Parse → Get (approved)  
Invoke-FileOperations # Execute → Invoke (approved)

# OR keep internal names, export with approved aliases:
Set-Alias -Name Get-VideoFiles -Value Find-VideoFiles
Export-ModuleMember -Function Find-VideoFiles -Alias Get-VideoFiles
```

**PowerShell Approved Verbs Reference:**
- ✅ **Get** - Retrieve data
- ✅ **Set** - Modify data  
- ✅ **Invoke** - Execute operations
- ✅ **Test** - Validate conditions
- ❌ **Find** - Use Get instead
- ❌ **Parse** - Use Get/ConvertFrom instead
- ❌ **Execute** - Use Invoke instead

**Implementation Steps:**
1. **Conservative Approach:** Add approved aliases, keep existing names
2. **Modern Approach:** Rename functions to use approved verbs
3. Update internal function calls if renamed
4. Update documentation with new names
5. Verify no warning messages remain

---

## 🔧 HIGH-03: Cross-Module Dependency Issues

**File:** `FileOperations.psm1:26`  
**Impact:** Tight coupling, circular dependency risk, testing complexity

**Current Problem:**
```powershell
# FileOperations.psm1 importing FileParser.psm1:
Import-Module "$PSScriptRoot\FileParser.psm1" -Force
```

**Issues:**
- ❌ FileOperations depends on FileParser
- ❌ Tight coupling between modules
- ❌ Makes unit testing FileOperations difficult
- ❌ Violates module independence principle
- ❌ Could create circular dependencies in future

**Current Dependency Chain:**
```
Main Script
├── FileOperations.psm1
│   └── FileParser.psm1 ← Cross-module dependency
├── FileParser.psm1
├── TheTVDB.psm1
├── UserInterface.psm1
└── NamingConvention.psm1
```

**Implementable Fix:**

**Option A: Parameter Injection**
```powershell
# Remove import from FileOperations.psm1
# Pass Get-SafeFileName as parameter instead:

function Write-OperationLog {
    param(
        [array]$Operations,
        [string]$WorkingDirectory,
        [string]$SeriesName,
        [scriptblock]$SafeFileNameFunction  # Inject dependency
    )
    
    $safeSeriesName = & $SafeFileNameFunction -FileName $SeriesName
    # ... rest of function
}

# In main script:
Write-OperationLog -Operations $ops -WorkingDirectory $dir -SeriesName $name -SafeFileNameFunction ${function:Get-SafeFileName}
```

**Option B: Duplicate Function** (Simpler)
```powershell
# Copy Get-SafeFileName to FileOperations.psm1
# Rename to avoid conflicts: Get-SafeLogFileName
function Get-SafeLogFileName {
    param($FileName)
    # Same implementation as Get-SafeFileName
    # Only for internal log file naming
}
```

**Recommended:** Option B for simplicity, Option A for proper architecture.

**Implementation Steps:**
1. Choose approach based on future extensibility needs
2. Remove Import-Module line from FileOperations.psm1
3. Implement chosen solution
4. Test module independence
5. Update documentation with module dependencies

---

## 🔧 HIGH-04: Error Handling Inconsistencies

**Files:** Multiple modules  
**Impact:** Unpredictable behavior, difficult debugging, poor user experience

**Inconsistent Error Patterns:**
```powershell
# TheTVDB.psm1 - Good pattern:
catch {
    Write-Host "[ERROR] Failed: $($_.Exception.Message)" -ForegroundColor Red
    return $null
}

# FileOperations.psm1 - Inconsistent pattern:
catch {
    Write-Warning "[WARNING] Failed to create rename log: $($_.Exception.Message)"
    # No return value handling
}

# UserInterface.psm1 - Mixed patterns:
# Some functions have try/catch, others don't
```

**Problems:**
- ❌ Inconsistent error message formats
- ❌ Mixed use of Write-Error, Write-Host, Write-Warning
- ❌ Inconsistent return value handling on errors
- ❌ Some functions don't handle errors at all

**Implementable Fix:**

**Standardized Error Handling Pattern:**
```powershell
# STANDARD PATTERN for all modules:
function Standard-FunctionTemplate {
    param([Parameter(Mandatory=$true)]$RequiredParam)
    
    try {
        # Validate inputs first
        if ([string]::IsNullOrWhiteSpace($RequiredParam)) {
            throw "Parameter cannot be null or empty: RequiredParam"
        }
        
        # Main function logic here
        $result = "Processed: $RequiredParam"
        
        # Success path
        Write-Debug-Info "Function completed successfully"
        return $result
    }
    catch [System.ArgumentException] {
        # Handle specific exception types
        Write-Host "[ERROR] Invalid argument: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
    catch {
        # Handle all other exceptions
        Write-Host "[ERROR] Function failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Debug-Info "Full exception: $($_.Exception)" "Red"
        return $null
    }
}
```

**Standardized Error Categories:**
- **[ERROR]** - Fatal errors, function cannot complete
- **[WARNING]** - Non-fatal issues, function continues with fallback
- **[INFO]** - Status updates, normal operation
- **[DEBUG]** - Detailed diagnostic information

**Implementation Steps:**
1. Audit all functions for error handling patterns
2. Create standard error handling template
3. Apply template to all public functions
4. Ensure consistent return value patterns (null on error)
5. Add input validation to all mandatory parameters
6. Test error scenarios for each function

---

## 🔧 HIGH-05: Network Operation Reliability Issues

**Files:** `TheTVDB.psm1` - All API functions  
**Impact:** Poor user experience, API abuse, reliability issues

**Current Problems:**
```powershell
# No timeout handling:
$response = Invoke-RestMethod -Uri "$BaseApiUrl/login" -Method POST

# No rate limiting:
foreach ($episode in $allEpisodes) {
    $episodeTranslation = Invoke-RestMethod -Uri "$BaseApiUrl/episodes/$($episode.id)/translations/eng"
    # Could hit rate limits with large episode counts
}

# No retry logic for temporary failures
# No progress indication for long operations
```

**Issues:**
- ❌ No HTTP timeout configuration
- ❌ No rate limiting protection  
- ❌ No retry logic for temporary network failures
- ❌ No progress indication for large series (100+ episodes)
- ❌ Could trigger TheTVDB rate limiting

**Implementable Fix:**
```powershell
function Invoke-TheTVDBRequest {
    param(
        [string]$Uri,
        [string]$Method = "GET", 
        [hashtable]$Headers,
        [object]$Body = $null,
        [int]$TimeoutSeconds = 30,
        [int]$RetryCount = 3,
        [int]$RetryDelaySeconds = 2
    )
    
    $attempt = 0
    do {
        try {
            $splat = @{
                Uri = $Uri
                Method = $Method
                Headers = $Headers
                TimeoutSec = $TimeoutSeconds
            }
            if ($Body) { $splat.Body = $Body }
            
            $response = Invoke-RestMethod @splat
            return $response
        }
        catch [System.Net.WebException] {
            $attempt++
            if ($attempt -le $RetryCount) {
                Write-Host "[WARNING] Network error, retrying in $RetryDelaySeconds seconds... (Attempt $attempt/$RetryCount)" -ForegroundColor Yellow
                Start-Sleep -Seconds $RetryDelaySeconds
            } else {
                throw
            }
        }
    } while ($attempt -le $RetryCount)
}

# Rate limiting protection:
function Start-RateLimitDelay {
    param([int]$DelayMs = 250)  # 4 requests per second max
    Start-Sleep -Milliseconds $DelayMs
}

# Progress indication for large operations:
function Get-SeriesEpisodesWithProgress {
    param($Token, $SeriesId)
    
    # Get total count first, then show progress
    $totalEpisodes = 0
    $processedEpisodes = 0
    
    foreach ($episode in $allEpisodes) {
        Write-Progress -Activity "Processing Episodes" -Status "Episode $($processedEpisodes + 1) of $totalEpisodes" -PercentComplete (($processedEpisodes / $totalEpisodes) * 100)
        
        # Process episode with rate limiting
        Start-RateLimitDelay
        # ... process episode
        
        $processedEpisodes++
    }
    
    Write-Progress -Activity "Processing Episodes" -Completed
}
```

**Implementation Steps:**
1. Create centralized `Invoke-TheTVDBRequest` helper
2. Replace all `Invoke-RestMethod` calls with helper
3. Add timeout configuration (default 30 seconds)
4. Implement retry logic for network failures
5. Add rate limiting delays (4 req/sec max)
6. Add progress bars for large operations (>20 episodes)
7. Test with poor network conditions

---

## Summary

**Total High Priority Issues:** 5  
**Estimated Fix Time:** 6-10 hours  
**Impact:** Significantly improved maintainability and reliability

**Priority Implementation Order:**
1. **Debug Function Duplication** (90 minutes) - Immediate maintenance improvement
2. **Error Handling Standardization** (120 minutes) - Better reliability
3. **PowerShell Verb Compliance** (45 minutes) - Professional standards
4. **Cross-Module Dependencies** (90 minutes) - Better architecture  
5. **Network Operation Reliability** (180 minutes) - Better user experience

All fixes maintain backward compatibility and significantly improve code quality.