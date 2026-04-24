#Requires -Version 7.0
<#
.SYNOPSIS
    Bootstrap PowerShell dotfiles on a new machine.

.DESCRIPTION
    Installs Scoop, shell productivity tools, PowerShell modules, nvm + Node LTS,
    and sets up the PowerShell profile so that `git pull` auto-updates config.
    Works without administrator rights — uses a dot-source wrapper if symlinks
    are not available.
    If WSL is detected, you will be asked whether to run setup-wsl.sh as well.

.PARAMETER Force
    Overwrite an existing $PROFILE entry without prompting.

.EXAMPLE
    .\install.ps1
    .\install.ps1 -Force
#>
[CmdletBinding()]
param(
    [switch]$Force
)

# ── UTF-8 Encoding (verhindert ? statt ae/oe/ue/ss) ───────────────────────────
if ($host.Name -eq 'ConsoleHost') {
    chcp 65001 | Out-Null
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding           = [System.Text.Encoding]::UTF8
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Skip($msg) { Write-Host "    [--] $msg" -ForegroundColor DarkGray }

function New-ProfileLink($src, $dest) {
    try {
        New-Item -ItemType SymbolicLink -Path $dest -Target $src -ErrorAction Stop | Out-Null
        Write-Ok "Symlink erstellt: $dest -> $src"
    } catch {
        # Kein Admin / kein Developer Mode: Dot-Source-Wrapper schreiben.
        # Updates wirken trotzdem automatisch via git pull.
        Set-Content -Path $dest -Value ". `"$src`"" -Encoding UTF8
        Write-Ok "Wrapper-Profil erstellt: $dest"
        Write-Host "    [i] Kein Symlink moeglich (kein Admin/Developer Mode) — dot-source Wrapper verwendet" -ForegroundColor DarkGray
    }
}

# ── 1. Scoop ──────────────────────────────────────────────────────────────────
Write-Step "Scoop"
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    Write-Ok "Scoop installiert"
} else {
    Write-Skip "Scoop bereits vorhanden"
}

# ── 2. Scoop buckets ──────────────────────────────────────────────────────────
Write-Step "Scoop buckets"
foreach ($bucket in @('main', 'extras')) {
    scoop bucket add $bucket 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Bucket '$bucket' hinzugefuegt"
    } else {
        Write-Skip "Bucket '$bucket' bereits vorhanden"
    }
}

# ── 3. Shell tools ────────────────────────────────────────────────────────────
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
        try {
            scoop install $tool
            Write-Ok "$tool installiert"
        } catch {
            Write-Host "    [!!] $tool konnte nicht installiert werden: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Skip "$tool bereits vorhanden"
    }
}

# ── 4. Node.js LTS via nvm ────────────────────────────────────────────────────
Write-Step "Node.js LTS via nvm"
if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
    scoop install nvm
    Write-Ok "nvm installiert"
} else {
    Write-Skip "nvm bereits vorhanden"
}
if (Get-Command nvm -ErrorAction SilentlyContinue) {
    nvm install lts
    nvm use lts
    # PATH fuer aktuelle Session aktualisieren (null-sicher)
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') ?? ''
    $userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')   ?? ''
    $env:Path    = $machinePath + ';' + $userPath
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        npm install -g pnpm
        Write-Ok "Node LTS + pnpm installiert"
    } else {
        Write-Host "    [!!] pnpm nicht automatisch installiert — manuell nachholen:" -ForegroundColor Yellow
        Write-Host "         nvm use lts && npm install -g pnpm" -ForegroundColor Yellow
    }
}

# ── 5. PowerShell modules ─────────────────────────────────────────────────────
Write-Step "PowerShell Module"
$modules = @('PSFzf', 'Terminal-Icons', 'posh-git', 'CompletionPredictor')
foreach ($mod in $modules) {
    if (-not (Get-Module -ListAvailable $mod)) {
        Install-Module -Name $mod -Scope CurrentUser -Force -AllowClobber
        Write-Ok "Modul '$mod' installiert"
    } else {
        Write-Skip "Modul '$mod' bereits vorhanden"
    }
}

# ── 6. Oh-My-Posh theme ───────────────────────────────────────────────────────
Write-Step "Oh-My-Posh Theme"
$themeDir  = "$env:USERPROFILE\.config\oh-my-posh"
$themeDest = "$themeDir\tokyo.omp.json"
$themeSrc  = Join-Path $RepoRoot 'themes\tokyo.omp.json'

if (-not (Test-Path $themeDir)) { New-Item -ItemType Directory -Path $themeDir -Force | Out-Null }
Copy-Item -Path $themeSrc -Destination $themeDest -Force
Write-Ok "Theme kopiert nach $themeDest"

# ── 7. Profile symlink / wrapper ──────────────────────────────────────────────
Write-Step "PowerShell Profil"
$profileSrc  = Join-Path $RepoRoot 'Microsoft.PowerShell_profile.ps1'
$profileDest = $PROFILE

$profileDir = Split-Path $profileDest
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }

if (Test-Path $profileDest) {
    $existing = Get-Item $profileDest
    if ($existing.LinkType -eq 'SymbolicLink' -and @($existing.Target) -contains $profileSrc) {
        Write-Skip "Symlink zeigt bereits auf Repo-Profil"
    } elseif ($Force) {
        Remove-Item $profileDest -Force
        New-ProfileLink $profileSrc $profileDest
    } else {
        $backup = "$profileDest.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Move-Item $profileDest $backup
        Write-Ok "Altes Profil gesichert: $backup"
        New-ProfileLink $profileSrc $profileDest
    }
} else {
    New-ProfileLink $profileSrc $profileDest
}

# ── 8. WSL setup (optional) ───────────────────────────────────────────────────
Write-Step "WSL"
$wslAvailable = $false
try {
    $wslDistros   = wsl --list --quiet 2>$null
    $wslAvailable = ($LASTEXITCODE -eq 0) -and ($wslDistros -match '\S')
} catch { }

if ($wslAvailable) {
    $answer = Read-Host "    WSL-Distribution erkannt. WSL-Setup jetzt ausfuehren? [J/n]"
    if ($answer -eq '' -or $answer -match '^[JjYy]') {
        $wslScript = Join-Path $RepoRoot 'setup-wsl.sh'
        $wslPath   = (wsl wslpath -u $wslScript 2>$null).Trim()
        if (-not $wslPath) {
            $wslPath = '/mnt/' + ($wslScript[0].ToString().ToLower()) + ($wslScript.Substring(2) -replace '\\', '/')
        }
        wsl bash $wslPath
    } else {
        Write-Skip "WSL-Setup uebersprungen — manuell: wsl bash setup-wsl.sh"
    }
} else {
    Write-Skip "WSL nicht verfuegbar"
}

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Fertig! PowerShell neu starten um das neue Profil zu laden." -ForegroundColor Green
Write-Host "Spaeter aktualisieren: git pull  (Profil-Aenderungen wirken automatisch)" -ForegroundColor DarkGray
