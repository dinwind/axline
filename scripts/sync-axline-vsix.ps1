# Sync the Axline built-in extension (.vsix) from the AuthNexus share link.
#
# Called before compiling/packaging to ensure the embedded Axline extension is
# the latest published version. Flow:
#   1. Query the public AuthNexus share API for the latest release metadata
#      (version, fileHash) - no login required.
#   2. Compare against the local .vsix (by sha256).
#   3. If outdated/missing, download and replace the local .vsix.
#   4. Optionally update product.json (version + sha256) so the build embeds
#      the matching artifact.
#   5. Patch the extension/package.json inside the vsix to add Axlines-specific
#      menu contributions (accountsContext and globalActivity) so that the
#      Axline settings/account buttons appear in the activity-bar bottom menus
#      when running as a built-in extension under AxLines (no sidebar toolbar).
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\sync-axline-vsix.ps1
#   powershell ... -UpdateProductJson   (also keep product.json axline.axline entry in sync)
#
param(
    [string]$Token        = "-HHiPJNkc_BlXmwGMY-ZxPbu6Oh5LLWy",
    [string]$VsixPath     = "",                                # defaults to <repo>\scripts\axline.vsix
    [switch]$UpdateProductJson,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# --- Paths ---------------------------------------------------------------
$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot     = Split-Path -Parent $ScriptDir
if (-not $VsixPath) {
    $VsixPath = Join-Path $ScriptDir "axline.vsix"
}
$VsixPath     = [System.IO.Path]::GetFullPath($VsixPath)
$ProductJson  = Join-Path $RepoRoot "product.json"

# --- Constants ------------------------------------------------------------
$BaseUrl      = "https://auth.mtsilicon.com/api/public/releases/share"
$MetaUrl      = "$BaseUrl/$Token"
$DownloadUrl  = "$BaseUrl/$Token/download"
$ExtensionKey = "axline.axline"   # matches the name field in product.json builtInExtensions

function Write-Step($msg) { Write-Host "[axline-vsix] $msg" }

# Pure .NET SHA256 (no dependency on the Get-FileHash cmdlet, which is not
# guaranteed to auto-load under the constrained PSModulePath used by build.bat).
function Get-Sha256 {
    param([string]$Path)
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            return ([System.BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLower()
        }
        finally {
            $sha.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

# --- 1. Fetch latest metadata --------------------------------------------
Write-Step "Fetching latest release metadata from AuthNexus..."
try {
    $meta = Invoke-RestMethod -Uri $MetaUrl -Headers @{ Accept = "application/json" } -Method Get
}
catch {
    Write-Host "[ERROR] Failed to query $MetaUrl : $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

if (-not $meta -or -not $meta.version) {
    Write-Host "[ERROR] Share link returned no version. The link may be revoked or invalid." -ForegroundColor Red
    exit 1
}

$latestVersion = [string]$meta.version
$latestHash    = [string]$meta.fileHash
$fileName      = if ($meta.fileDisplayName) { [string]$meta.fileDisplayName } else { "axline.vsix" }
$fileSize      = [string]$meta.fileSize

Write-Step ("Latest  : {0}  (sha256={1}, {2} bytes, file={3})" -f $latestVersion, $latestHash, $fileSize, $fileName)

# --- 2. Compare local vsix ------------------------------------------------
$localHash = $null
if (Test-Path $VsixPath) {
    $localHash = Get-Sha256 -Path $VsixPath
    Write-Step ("Local   : sha256={0}  ({1})" -f $localHash, $VsixPath)
}
else {
    Write-Step "Local   : missing  ($VsixPath)"
}

$needsDownload = $Force -or (-not $localHash) -or ($localHash -ne $latestHash.ToLower())

if (-not $needsDownload) {
    Write-Step "Up to date - nothing to do."
    exit 0
}

# --- 3. Download and replace ----------------------------------------------
if ($Force) {
    Write-Step "Forced refresh. Downloading .vsix..."
}
elseif ($localHash) {
    Write-Step "Update available (hash differs). Downloading new .vsix..."
}
else {
    Write-Step "No local .vsix. Downloading..."
}

$tmp = "$VsixPath.tmp"
try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $tmp -UseBasicParsing
}
catch {
    Write-Host "[ERROR] Download failed: $($_.Exception.Message)" -ForegroundColor Red
    if (Test-Path $tmp) { Remove-Item $tmp -Force }
    exit 1
}

# Verify downloaded hash matches the published fileHash before replacing the local file.
$dlHash = Get-Sha256 -Path $tmp
if ($dlHash -ne $latestHash.ToLower()) {
    Write-Host "[ERROR] Downloaded file sha256 mismatch (expected $latestHash, got $dlHash). Aborting without replacing." -ForegroundColor Red
    Remove-Item $tmp -Force
    exit 1
}

if (Test-Path $VsixPath) { Remove-Item $VsixPath -Force }
Move-Item $tmp $VsixPath
Write-Step ("Saved   : {0} ({1} bytes)" -f $VsixPath, (Get-Item $VsixPath).Length)

# --- 4. Patch the vsix-internal package.json ---------------------------------
# Inject accountsContext and globalActivity menu contributions so that the
# Axline settings/account/feedback/report commands appear in the VS Code
# activity-bar bottom menus when Axline runs as a built-in extension without
# a sidebar toolbar.
function Patch-VsixPackageJson {
    param([string]$VsixFilePath)

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $vsixAbs = [System.IO.Path]::GetFullPath($VsixFilePath)
    $tmpPath = "$vsixAbs.patched.tmp"

    $pkgJsonPath = "extension/package.json"
    $pkgContent   = $null

    # Read the original package.json from inside the vsix.
    $zipIn  = [System.IO.Compression.ZipFile]::OpenRead($vsixAbs)
    try {
        $entry = $zipIn.GetEntry($pkgJsonPath)
        if (-not $entry) {
            Write-Host "[WARN] $pkgJsonPath not found inside vsix — skipping menu patch." -ForegroundColor Yellow
            return
        }
        $stream = $entry.Open()
        try {
            $reader = [System.IO.StreamReader]::new($stream)
            $pkgContent = $reader.ReadToEnd()
            $reader.Dispose()
        }
        finally { $stream.Dispose() }
    }
    finally { $zipIn.Dispose() }

    # Check whether the menus are already present (idempotent).
    if ($pkgContent -match '"accountsContext"' -and $pkgContent -match '"globalActivity"') {
        Write-Step "package.json inside vsix already has menu patches — skipped."
        return
    }

    # Locate the `"menus"` block inside the contributes object.
    # We insert new entries before the closing `]` of the "view/title" array so
    # they appear as a separate menu key after the existing view/title block.
    # Alternatively we append after the closing `]` of the last menu entry.
    #
    # Strategy: find the `"menus" : {` block, then find the closing `}` of the
    # whole menus object.  Insert new keys just before that closing brace.
    $menusMatch = [regex]::Match($pkgContent, '("menus"\s*:\s*\{)')
    if (-not $menusMatch.Success) {
        Write-Host "[WARN] 'menus' key not found in vsix package.json — skipping menu patch." -ForegroundColor Yellow
        return
    }

    # Find the matching closing brace for the menus object.
    $braceCount = 0
    $started    = $false
    $menusEnd   = -1
    for ($i = $menusMatch.Index; $i -lt $pkgContent.Length; $i++) {
        $ch = $pkgContent[$i]
        if ($ch -eq '{') { $braceCount++; $started = $true }
        elseif ($ch -eq '}') {
            $braceCount--
            if ($started -and $braceCount -eq 0) {
                $menusEnd = $i
                break
            }
        }
    }

    if ($menusEnd -lt 0) {
        Write-Host "[WARN] Could not locate closing brace of 'menus' object — skipping menu patch." -ForegroundColor Yellow
        return
    }

    # Build the new menu entries to inject.
    $accountsContextMenus = @'
,
        "accountsContext": [
            {
                "command": "axline.accountButtonClicked",
                "group": "1_accounts@1"
            },
            {
                "command": "axline.openFeedback",
                "group": "1_accounts@2"
            }
        ],
        "globalActivity": [
            {
                "command": "axline.settingsButtonClicked",
                "group": "0_settings@1"
            },
            {
                "command": "axline.reportIssue",
                "group": "0_settings@2"
            }
        ]
'@

    # Insert the new entries before the closing brace of the menus object.
    $patchedContent = $pkgContent.Substring(0, $menusEnd) + $accountsContextMenus + $pkgContent.Substring($menusEnd)

    # Validate JSON round-trip.
    try {
        $null = $patchedContent | ConvertFrom-Json
    }
    catch {
        Write-Host "[ERROR] Patched package.json is not valid JSON — skipping vsix modification." -ForegroundColor Red
        return
    }

    # Write patched vsix.
    $outZip = [System.IO.Compression.ZipFile]::Open($tmpPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $zipIn = [System.IO.Compression.ZipFile]::OpenRead($vsixAbs)
        try {
            foreach ($entry in $zipIn.Entries) {
                if ($entry.FullName -eq $pkgJsonPath) {
                    $newEntry = $outZip.CreateEntry($pkgJsonPath, [System.IO.Compression.CompressionLevel]::Optimal)
                    $s = $newEntry.Open()
                    try {
                        $w = [System.IO.StreamWriter]::new($s, [System.Text.UTF8Encoding]::new($false))
                        $w.Write($patchedContent)
                        $w.Flush()
                        $w.Dispose()
                    }
                    finally { if ($s) { $s.Dispose() } }
                }
                else {
                    # Copy all other entries verbatim.
                    $newEntry = $outZip.CreateEntry($entry.FullName, [System.IO.Compression.CompressionLevel]::Optimal)
                    $src = $entry.Open()
                    try {
                        $dst = $newEntry.Open()
                        try { $src.CopyTo($dst) }
                        finally { if ($dst) { $dst.Dispose() } }
                    }
                    finally { if ($src) { $src.Dispose() } }
                }
            }
        }
        finally { $zipIn.Dispose() }
    }
    catch {
        $outZip.Dispose()
        if (Test-Path $tmpPath) { Remove-Item $tmpPath -Force }
        throw
    }
    $outZip.Dispose()

    # Replace original with patched version.
    Remove-Item $vsixAbs -Force
    Move-Item $tmpPath $vsixAbs
    Write-Step "Injected accountsContext & globalActivity into vsix package.json."
}

# Only patch if we actually downloaded a fresh vsix.
if ($needsDownload) {
    Patch-VsixPackageJson -VsixFilePath $VsixPath
}

# --- 5. Update product.json (after patch) -----------------------------------
# The patch changes vsix sha256, so this must run AFTER patching.
if ($UpdateProductJson) {
    $effectiveHash = Get-Sha256 -Path $VsixPath

    if (-not (Test-Path $ProductJson)) {
        Write-Host "[ERROR] product.json not found: $ProductJson" -ForegroundColor Red
        exit 1
    }

    $raw = [System.IO.File]::ReadAllText($ProductJson)

    $nameEsc = [regex]::Escape($ExtensionKey)
    $namePattern = '"name"\s*:\s*"' + $nameEsc + '"'
    $nameMatch  = [regex]::Match($raw, $namePattern)
    if (-not $nameMatch.Success) {
        Write-Host "[ERROR] product.json has no builtInExtensions entry named '$ExtensionKey'." -ForegroundColor Red
        exit 1
    }

    $blockStart = $raw.LastIndexOf('{', $nameMatch.Index)
    $blockEnd = $raw.IndexOf('}', $nameMatch.Index)
    $block = $raw.Substring($blockStart, $blockEnd - $blockStart + 1)

    $changed = $false

    if ($block -notmatch ('"version"\s*:\s*"' + [regex]::Escape($latestVersion) + '"')) {
        $newBlock = [regex]::Replace($block, '("version"\s*:\s*")[^"]*(")', ('${1}' + $latestVersion + '${2}'))
        if ($newBlock -ne $block) { $block = $newBlock; $changed = $true
            Write-Step "product.json version: -> $latestVersion" }
    }

    $wantHash = $effectiveHash.ToLower()
    if ($block -notmatch ('"sha256"\s*:\s*"' + [regex]::Escape($wantHash) + '"')) {
        $newBlock = [regex]::Replace($block, '("sha256"\s*:\s*")[^"]*(")', ('${1}' + $wantHash + '${2}'))
        if ($newBlock -ne $block) { $block = $newBlock; $changed = $true
            Write-Step "product.json sha256 : -> $wantHash" }
    }

    if ($changed) {
        $raw = $raw.Remove($blockStart, $blockEnd - $blockStart + 1).Insert($blockStart, $block)
        [System.IO.File]::WriteAllText($ProductJson, $raw)
        Write-Step "product.json updated."
    }
    else {
        Write-Step "product.json already in sync."
    }
}

Write-Step "Done."
exit 0