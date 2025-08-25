# CRITICAL Security Vulnerabilities

**Priority: CRITICAL** - These issues pose immediate security risks and should be addressed first.

## 🚨 CRITICAL-01: Hardcoded API Key Exposure

**File:** `Organize-Anime.ps1:7`  
**Risk Level:** HIGH  
**Description:** TheTVDB API key is hardcoded in the source code.

```powershell
# VULNERABLE CODE:
[string]$ApiKey = "2cb4e65a-f9a9-46e4-98f9-2d44f55342db"
```

**Security Impact:**
- ✅ **Current Status:** Key is for free tier with basic rate limits
- ⚠️ **Risk:** If upgraded to paid subscription, exposes premium API access
- ⚠️ **Tracking:** API usage can be tracked to this specific key
- ⚠️ **Abuse:** Key could be extracted and used by others

**Implementable Fix:**
```powershell
# SECURE APPROACH:
param(
    [string]$ApiKey = (Get-Content "$PSScriptRoot\.apikey" -ErrorAction SilentlyContinue),
    [string]$DefaultApiKey = "2cb4e65a-f9a9-46e4-98f9-2d44f55342db"
)

# Use custom key if provided, otherwise fallback to default
$EffectiveApiKey = if ($ApiKey) { $ApiKey } else { $DefaultApiKey }
```

**Implementation Steps:**
1. Create optional `.apikey` file for custom keys
2. Add `.apikey` to `.gitignore` 
3. Update parameter logic to check for custom key first
4. Document custom API key setup in README

---

## 🚨 CRITICAL-02: Information Disclosure via Debug Mode

**Files:** All modules (`$DebugMode = $true`)  
**Risk Level:** MEDIUM-HIGH  
**Description:** Debug mode is hardcoded to `$true`, exposing sensitive information.

**Information Exposed:**
- API keys (first 8 characters): `[DEBUG] API Key: 2cb4e65a...`
- Internal file paths and operations
- API response data including metadata
- Series IDs and processing details

**Current Exposure Examples:**
```powershell
# TheTVDB.psm1:38
Write-Debug-Info "API Key: ${keyPreview}..." "Gray"

# TheTVDB.psm1:95  
Write-Debug-Info "Translation response: $($translationResponse | ConvertTo-Json -Depth 3)"
```

**Implementable Fix:**
```powershell
# MODULE-LEVEL FIX (apply to all modules):
# Replace hardcoded debug mode with parameter
param(
    [bool]$DebugMode = $false
)

# MAIN SCRIPT FIX:
param(
    [bool]$DebugMode = $false
)

# Pass debug mode to all modules
Import-Module "$ModulesPath\TheTVDB.psm1" -ArgumentList $DebugMode -Force
```

**Implementation Steps:**
1. Add `$DebugMode` parameter to main script
2. Add `$DebugMode` parameter to all module files  
3. Pass debug mode from main script to modules during import
4. Set default to `$false` for production use
5. Update documentation with debug mode usage

---

## 🚨 CRITICAL-03: Regex Denial of Service (ReDoS) Vulnerability

**File:** `FileParser.psm1:78-140`  
**Risk Level:** MEDIUM  
**Description:** Complex regex patterns could cause exponential backtracking with malicious filenames.

**Vulnerable Patterns:**
```powershell
# Potentially vulnerable patterns:
'^(.+?)\s*-\s*(\d+).*\..*$'                    # Line 83
'^(.+?)\s+(?:Episode|Ep|E)\s*(\d+).*\..*$'     # Line 84  
'^(.+?)\s+(\d{1,3})(?:\s+.*)?\..*$'            # Line 85
```

**Attack Vector:**
- Malicious filename: `"A" + "-" * 10000 + "1.mkv"`
- Could cause regex engine to hang with exponential backtracking

**Implementable Fix:**
```powershell
# SECURE PATTERNS with timeout and atomic grouping:
function Parse-EpisodeNumber {
    param($FileName, [int]$TimeoutMs = 1000)
    
    # Add regex timeout for all patterns
    try {
        $regexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        $timeout = [System.TimeSpan]::FromMilliseconds($TimeoutMs)
        
        foreach ($pattern in $patterns) {
            $regex = [System.Text.RegularExpressions.Regex]::new($pattern, $regexOptions, $timeout)
            $match = $regex.Match($FileName)
            if ($match.Success) {
                # Process match...
                return $result
            }
        }
    }
    catch [System.Text.RegularExpressions.RegexMatchTimeoutException] {
        Write-Warning "Regex timeout parsing filename: $FileName"
        return $null
    }
}
```

**Implementation Steps:**
1. Add regex timeout protection to `Parse-EpisodeNumber`
2. Replace complex patterns with more specific alternatives
3. Add filename length validation (e.g., max 255 characters)
4. Add unit tests with malicious filename patterns

---

## 🚨 CRITICAL-04: Path Traversal Risk in File Operations

**File:** `FileOperations.psm1:36`  
**Risk Level:** MEDIUM  
**Description:** Limited validation of working directory paths.

**Current Implementation:**
```powershell
$logPath = Join-Path $WorkingDirectory $logFileName
```

**Potential Risk:**
- If `$WorkingDirectory` contains `..` sequences
- Could potentially write logs outside intended directory

**Current Mitigation:** 
✅ Uses `Join-Path` (good)  
✅ Uses `-LiteralPath` in file operations (excellent)  
⚠️ No explicit path traversal validation

**Implementable Fix:**
```powershell
function Test-SafePath {
    param([string]$Path)
    
    # Resolve to absolute path and validate
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    
    # Ensure path doesn't contain traversal patterns  
    if ($Path -match '\.\.[\\/]' -or $resolvedPath -match '\.\.[\\/]') {
        throw "Path traversal detected: $Path"
    }
    
    return $resolvedPath
}

# Usage in FileOperations:
$safeWorkingDir = Test-SafePath -Path $WorkingDirectory
$logPath = Join-Path $safeWorkingDir $logFileName
```

**Implementation Steps:**
1. Create `Test-SafePath` validation function
2. Apply path validation to all user-provided paths
3. Add validation to working directory parameter
4. Document path security measures

---

## Summary

**Total Critical Issues:** 4  
**Estimated Fix Time:** 2-4 hours  
**Risk if Unaddressed:** Medium to High

**Priority Implementation Order:**
1. **Debug Mode Fix** (30 minutes) - Immediate information disclosure fix
2. **Path Traversal Protection** (45 minutes) - File system security
3. **API Key Security** (60 minutes) - Credential management  
4. **Regex DoS Protection** (90 minutes) - Input validation hardening

All fixes are backward-compatible and can be implemented without breaking existing functionality.