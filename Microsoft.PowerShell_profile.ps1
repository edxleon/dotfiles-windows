# ── Oh My Posh ────────────────────────────────────────────────────────────────
$env:POSH_GIT_ENABLED = $true
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $_ompTheme = "$env:USERPROFILE\.config\oh-my-posh\tokyo.omp.json"
    if (-not (Test-Path $_ompTheme)) {
        # Theme not yet installed — fall back to built-in tokyo theme
        $_ompTheme = 'tokyo'
    }
    oh-my-posh init pwsh --config $_ompTheme | Invoke-Expression
}

# ── Modules ───────────────────────────────────────────────────────────────────
if (Get-Module -ListAvailable Terminal-Icons)    { Import-Module Terminal-Icons }
if (Get-Module -ListAvailable posh-git)          { Import-Module posh-git }

# ── PSReadLine ────────────────────────────────────────────────────────────────
Import-Module PSReadLine

Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -PredictionViewStyle ListView

Set-PSReadLineOption -Colors @{
    Command          = '#7EC8E3'
    Parameter        = '#C3E88D'
    String           = '#C3E88D'
    Operator         = '#89DDFF'
    Variable         = '#F78C6C'
    Comment          = '#546E7A'
    Keyword          = '#C792EA'
    Error            = '#F07178'
    InlinePrediction = '#546E7A'
    Selection        = '#2D4F67'
}

Set-PSReadLineKeyHandler -Key Tab            -Function MenuComplete
Set-PSReadLineKeyHandler -Key UpArrow        -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow      -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Ctrl+d         -Function DeleteCharOrExit
Set-PSReadLineKeyHandler -Key Ctrl+f         -Function ForwardWord
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow  -Function BackwardWord
Set-PSReadLineKeyHandler -Key F7 -ScriptBlock {
    $pattern = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$pattern, [ref]$null)
    if ($pattern.Length -gt 0) { $pattern = [regex]::Escape($pattern) }
    $history = [System.Collections.Generic.List[string]]@(
        [System.Linq.Enumerable]::Reverse(
            [System.Collections.Generic.List[string]](@(Get-History).ForEach({ $_.CommandLine }))
        )
    )
    $history = $history | Where-Object { $_ -match $pattern } | Select-Object -Unique
    $command = $history | Out-GridView -Title 'Command History' -PassThru
    if ($command) {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert(($command -join "`n"))
    }
}

# ── CompletionPredictor ───────────────────────────────────────────────────────
if (Get-Module -ListAvailable CompletionPredictor) {
    Import-Module CompletionPredictor
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
} else {
    Set-PSReadLineOption -PredictionSource History
}

# ── PSFzf (Ctrl+T Dateisuche, Ctrl+R History) ────────────────────────────────
if (Get-Module -ListAvailable PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' `
                    -PSReadlineChordReverseHistory 'Ctrl+r'
}

# ── Zoxide (z — smarter cd) ───────────────────────────────────────────────────
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# ── bat (cat mit Syntax-Highlighting) ────────────────────────────────────────
if (Get-Command bat -ErrorAction SilentlyContinue) {
    Set-Alias cat bat
}

# ── eza (modernes ls) ─────────────────────────────────────────────────────────
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function ls  { eza --icons --group-directories-first @args }
    function ll  { eza -la --icons --group-directories-first --git @args }
    function lt  { eza --tree --icons -L 3 @args }
} else {
    Set-Alias ll Get-ChildItem
    Set-Alias la Get-ChildItem
}

# ── Git Shortcuts ─────────────────────────────────────────────────────────────
Set-Alias g git
function gs    { git status }
function glog  { git log --oneline --graph --decorate -20 }
function gpull { git pull --rebase }
function gpush { git push @args }
function gco   { git checkout @args }
function gcb   { git checkout -b @args }

# ── Docker ────────────────────────────────────────────────────────────────────
if (Get-Command docker -ErrorAction SilentlyContinue) {
    function dps    { docker ps @args }
    function dex    { docker exec -it @args }
    function dlogs  { docker logs -f @args }
    function dprune { docker system prune -af }
    function dimg   { docker images @args }
}

# ── Quality-of-life Utilities ─────────────────────────────────────────────────
Set-Alias np notepad
Set-Alias vi code

function which($cmd) { (Get-Command $cmd -ErrorAction SilentlyContinue).Source }
function touch($file) {
    if (Test-Path $file) { (Get-Item $file).LastWriteTime = Get-Date }
    else { New-Item -ItemType File $file | Out-Null }
}
function mkcd($dir) { New-Item -ItemType Directory -Path $dir -Force | Out-Null; Set-Location $dir }
function up($n = 1) { Set-Location (('../' * $n).TrimEnd('/')) }

# ── Environment ───────────────────────────────────────────────────────────────
$env:EDITOR = 'code'
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
