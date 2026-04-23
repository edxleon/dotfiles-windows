#Requires -Version 7.0
<#
.SYNOPSIS
    Bootstrap PowerShell dotfiles on a new machine.

.DESCRIPTION
    Installs Scoop, shell productivity tools, PowerShell modules, nvm + Node LTS,
    and sets up the PowerShell profile via symlink so that `git pull` auto-updates config.
    If WSL is available, also runs setup-wsl.sh inside Ubuntu automatically.

.PARAMETER Force
    Overwrite an existing $PROFILE symlink without prompting.

.PARAMETER SkipWsl
    Do not run the WSL setup even if WSL is available.

.EXAMPLE
    .\install.ps1
    .\install.ps1 -SkipWsl
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipWsl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Skip($msg) { Write-Host "    [--] $msg" -ForegroundColor DarkGray }

# ── 1. Scoop ──────────────────────────────────────────────────────────────────
Write-Step "Scoop"
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    Write-Ok "Scoop installed"
} else {
    Write-Skip "Scoop already present"
}

Write-Step "Scoop buckets"
foreach ($bucket in @('main', 'extras')) {
    $existing = (scoop bucket list 2>$null | Select-Object -Skip 2 | ForEach-Object { ($_ -split '\s+')[0] })
    if ($existing -notcontains $bucket) {
        scoop bucket add $bucket
        Write-Ok "Bucket '$bucket' added"
    } else {
        Write-Skip "Bucket '$bucket' already added"
    }
}

# ── 2. Shell tools ────────────────────────────────────────────────────────────
Write-Step "Shell tools (oh-my-posh, fzf, zoxide, bat, eza, ripgrep, fd)"
$shellTools = @(
    'oh-my-posh',
    'fzf',
    'zoxide',
    'bat',
    'eza',
    'ripgrep',
    'fd'
)
foreach ($tool in $shellTools) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        scoop install $tool
        Write-Ok "$tool installed"
    } else {
        Write-Skip "$tool already installed"
    }
}

# ── 3. Node.js LTS via nvm ────────────────────────────────────────────────────
Write-Step "Node.js LTS via nvm"
if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
    scoop install nvm
    Write-Ok "nvm installed"
} else {
    Write-Skip "nvm already installed"
}
if (Get-Command nvm -ErrorAction SilentlyContinue) {
    nvm install lts
    nvm use lts
    # Refresh PATH so npm is available in the current session
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path', 'User')
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        npm install -g pnpm
        Write-Ok "Node LTS + pnpm installed"
    } else {
        Write-Host "    [!!] pnpm not installed automatically — run manually:" -ForegroundColor Yellow
        Write-Host "         nvm use lts && npm install -g pnpm" -ForegroundColor Yellow
    }
}

# ── 4. PowerShell modules ─────────────────────────────────────────────────────
Write-Step "PowerShell modules"
$modules = @('PSFzf', 'Terminal-Icons', 'posh-git', 'CompletionPredictor')
foreach ($mod in $modules) {
    if (-not (Get-Module -ListAvailable $mod)) {
        Install-Module -Name $mod -Scope CurrentUser -Force -AllowClobber
        Write-Ok "Module '$mod' installed"
    } else {
        Write-Skip "Module '$mod' already installed"
    }
}

# ── 5. Oh-My-Posh theme ───────────────────────────────────────────────────────
Write-Step "Oh-My-Posh theme"
$themeDir  = "$env:USERPROFILE\.config\oh-my-posh"
$themeDest = "$themeDir\tokyo.omp.json"
$themeSrc  = Join-Path $RepoRoot 'themes\tokyo.omp.json'

if (-not (Test-Path $themeDir)) { New-Item -ItemType Directory -Path $themeDir -Force | Out-Null }
Copy-Item -Path $themeSrc -Destination $themeDest -Force
Write-Ok "Theme copied to $themeDest"

# ── 6. Profile symlink ────────────────────────────────────────────────────────
Write-Step "PowerShell profile symlink"
$profileSrc  = Join-Path $RepoRoot 'Microsoft.PowerShell_profile.ps1'
$profileDest = $PROFILE

$profileDir = Split-Path $profileDest
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }

if (Test-Path $profileDest) {
    $existing = Get-Item $profileDest
    if ($existing.LinkType -eq 'SymbolicLink' -and @($existing.Target) -contains $profileSrc) {
        Write-Skip "Symlink already points to repo profile"
    } elseif ($Force) {
        Remove-Item $profileDest -Force
        New-Item -ItemType SymbolicLink -Path $profileDest -Target $profileSrc | Out-Null
        Write-Ok "Symlink replaced: $profileDest -> $profileSrc"
    } else {
        $backup = "$profileDest.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Move-Item $profileDest $backup
        New-Item -ItemType SymbolicLink -Path $profileDest -Target $profileSrc | Out-Null
        Write-Ok "Old profile backed up to $backup"
        Write-Ok "Symlink created: $profileDest -> $profileSrc"
    }
} else {
    New-Item -ItemType SymbolicLink -Path $profileDest -Target $profileSrc | Out-Null
    Write-Ok "Symlink created: $profileDest -> $profileSrc"
}

# ── 7. WSL setup ──────────────────────────────────────────────────────────────
if (-not $SkipWsl) {
    Write-Step "WSL"
    $wslAvailable = $false
    try {
        $wslDistros = wsl --list --quiet 2>$null
        $wslAvailable = ($LASTEXITCODE -eq 0) -and ($wslDistros -match '\S')
    } catch { }

    if ($wslAvailable) {
        $wslScript = Join-Path $RepoRoot 'setup-wsl.sh'
        # wslpath expects a native Windows path (backslashes + drive letter)
        $wslPath   = (wsl wslpath -u $wslScript 2>$null).Trim()
        if (-not $wslPath) {
            # fallback: manual conversion C:\foo\bar -> /mnt/c/foo/bar
            $wslPath = '/mnt/' + ($wslScript[0].ToString().ToLower()) + ($wslScript.Substring(2) -replace '\\', '/')
        }
        Write-Ok "WSL detected — running setup-wsl.sh"
        wsl bash $wslPath
    } else {
        Write-Skip "WSL not available — skipping"
    }
}

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Done! Restart PowerShell to load the new profile." -ForegroundColor Green
Write-Host "To update later: git pull  (profile updates automatically via symlink)" -ForegroundColor DarkGray
