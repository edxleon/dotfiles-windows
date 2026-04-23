#!/usr/bin/env bash
# WSL Ubuntu setup — mirrors the PowerShell dotfiles environment
set -euo pipefail

DEVOPS=false
for arg in "$@"; do [[ "$arg" == "--devops" ]] && DEVOPS=true; done

step() { echo -e "\n\033[36m==> $1\033[0m"; }
ok()   { echo -e "    \033[32m[OK]\033[0m $1"; }
skip() { echo -e "    \033[90m[--]\033[0m $1"; }

# ── System update ─────────────────────────────────────────────────────────────
step "System packages"
sudo apt update -qq && sudo apt upgrade -y -qq
sudo apt install -y -qq curl wget git unzip build-essential zsh

# ── Zsh + Oh My Zsh ───────────────────────────────────────────────────────────
step "Zsh + Oh My Zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "Oh My Zsh installed"
else
    skip "Oh My Zsh already installed"
fi

# ── Starship prompt ───────────────────────────────────────────────────────────
step "Starship prompt"
if ! command -v starship &>/dev/null; then
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
    ok "Starship installed"
else
    skip "Starship already installed"
fi

# Starship config — Tokyo Night style to match Oh-My-Posh theme
mkdir -p "$HOME/.config"
cat > "$HOME/.config/starship.toml" << 'TOML'
format = """
$os$username$directory$git_branch$git_status$fill$nodejs$python$time
$character"""

[os]
disabled = false
style = "bg:#7aa2f7 fg:#1a1b26"
format = "[$symbol]($style)"
[os.symbols]
Ubuntu = " "
Windows = " "

[username]
show_always = true
style_user = "bg:#73daca fg:#1a1b26"
style_root = "bg:#f7768e fg:#1a1b26"
format = "[ $user ]($style)"

[directory]
style = "bg:#1a1b26 fg:#c0caf5"
format = "[  $path ]($style)"
truncation_length = 3
truncate_to_repo = false

[git_branch]
style = "bg:#bb9af7 fg:#1a1b26"
format = "[ $symbol$branch ]($style)"
symbol = " "

[git_status]
style = "bg:#e0af68 fg:#1a1b26"
format = "[$all_status$ahead_behind]($style)"

[fill]
symbol = " "

[nodejs]
style = "fg:#9ece6a"
format = "[ $symbol$version ]($style)"

[python]
style = "fg:#e0af68"
format = "[ $symbol$version ]($style)"

[time]
disabled = false
style = "fg:#565f89"
format = "[ $time ]($style)"
time_format = "%H:%M"

[character]
success_symbol = "[ ](bold blue)"
error_symbol = "[ ](bold red)"
TOML
ok "Starship config written"

# ── Productivity tools ────────────────────────────────────────────────────────
step "Productivity tools (fzf, zoxide, bat, eza, ripgrep, fd)"

# fzf
if ! command -v fzf &>/dev/null; then
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf" 2>/dev/null
    "$HOME/.fzf/install" --all --no-update-rc
    ok "fzf installed"
else
    skip "fzf already installed"
fi

# zoxide
if ! command -v zoxide &>/dev/null; then
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    ok "zoxide installed"
else
    skip "zoxide already installed"
fi

# bat (batcat in Ubuntu)
if ! command -v bat &>/dev/null && ! command -v batcat &>/dev/null; then
    sudo apt install -y -qq bat
    ok "bat installed"
else
    skip "bat already installed"
fi
mkdir -p "$HOME/.local/bin"
if [ -f /usr/bin/batcat ] && [ ! -f "$HOME/.local/bin/bat" ]; then
    ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
    ok "bat symlink created"
fi

# eza
if ! command -v eza &>/dev/null; then
    sudo apt install -y -qq gpg
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
        | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
        | sudo tee /etc/apt/sources.list.d/gierens.list > /dev/null
    sudo apt update -qq && sudo apt install -y -qq eza
    ok "eza installed"
else
    skip "eza already installed"
fi

# ripgrep + fd
for pkg in ripgrep fd-find; do
    if ! dpkg -l "$pkg" &>/dev/null; then
        sudo apt install -y -qq "$pkg"
        ok "$pkg installed"
    else
        skip "$pkg already installed"
    fi
done
# fd alias (fd-find ships as fdfind)
if command -v fdfind &>/dev/null && [ ! -f "$HOME/.local/bin/fd" ]; then
    ln -sf "$(which fdfind)" "$HOME/.local/bin/fd"
    ok "fd symlink created"
fi

# ── nvm + Node LTS ────────────────────────────────────────────────────────────
step "nvm + Node LTS"
if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    ok "nvm installed"
else
    skip "nvm already installed"
fi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
if ! command -v node &>/dev/null; then
    nvm install --lts
    npm install -g pnpm
    ok "Node LTS + pnpm installed"
else
    skip "Node $(node --version) already installed"
fi

# ── DevOps tools ──────────────────────────────────────────────────────────────
if [ "$DEVOPS" = true ]; then
    step "DevOps tools (kubectl, helm, k9s, Azure CLI)"

    # kubectl
    if ! command -v kubectl &>/dev/null; then
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key \
            | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' \
            | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
        sudo apt update -qq && sudo apt install -y -qq kubectl
        ok "kubectl installed"
    else
        skip "kubectl already installed"
    fi

    # helm
    if ! command -v helm &>/dev/null; then
        curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        ok "helm installed"
    else
        skip "helm already installed"
    fi

    # k9s
    if ! command -v k9s &>/dev/null; then
        K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
        curl -fsSL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" \
            | sudo tar -xz -C /usr/local/bin k9s
        ok "k9s installed"
    else
        skip "k9s already installed"
    fi

    # Azure CLI
    if ! command -v az &>/dev/null; then
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
        ok "Azure CLI installed"
    else
        skip "Azure CLI already installed"
    fi
fi

# ── .zshrc ────────────────────────────────────────────────────────────────────
step ".zshrc configuration"
ZSHRC="$HOME/.zshrc"

# Backup existing if not managed by us
if [ -f "$ZSHRC" ] && ! grep -q "# managed by dotfiles-windows" "$ZSHRC" 2>/dev/null; then
    cp "$ZSHRC" "${ZSHRC}.backup-$(date +%Y%m%d-%H%M%S)"
    ok ".zshrc backed up"
fi

cat > "$ZSHRC" << 'ZSHRC_CONTENT'
# managed by dotfiles-windows

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""  # using starship instead
plugins=(git z fzf)
source $ZSH/oh-my-zsh.sh

# ── Starship ──────────────────────────────────────────────────────────────────
eval "$(starship init zsh)"

# ── Zoxide ────────────────────────────────────────────────────────────────────
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi

# ── fzf ───────────────────────────────────────────────────────────────────────
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# ── nvm ───────────────────────────────────────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# ── PATH ──────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# ── bat ───────────────────────────────────────────────────────────────────────
if command -v bat &>/dev/null; then
    alias cat='bat'
fi

# ── eza ───────────────────────────────────────────────────────────────────────
if command -v eza &>/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -la --icons --group-directories-first --git'
    alias lt='eza --tree --icons -L 3'
fi

# ── ripgrep / fd ──────────────────────────────────────────────────────────────
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    alias fd='fdfind'
fi

# ── Git ───────────────────────────────────────────────────────────────────────
alias g='git'
alias gs='git status'
alias glog='git log --oneline --graph --decorate -20'
alias gpull='git pull --rebase'
alias gpush='git push'
alias gco='git checkout'
alias gcb='git checkout -b'

# ── Kubernetes ────────────────────────────────────────────────────────────────
if command -v kubectl &>/dev/null; then
    source <(kubectl completion zsh)
    alias k='kubectl'
    alias kctx='kubectl config get-contexts'
    alias kpods='kubectl get pods -A'
    kns() { kubectl config set-context --current --namespace=$1; }
    klogs() { kubectl logs -f $1; }
fi

if command -v helm &>/dev/null; then
    source <(helm completion zsh)
fi

# ── Docker ────────────────────────────────────────────────────────────────────
if command -v docker &>/dev/null; then
    alias dps='docker ps'
    alias dex='docker exec -it'
    alias dlogs='docker logs -f'
    alias dprune='docker system prune -af'
    alias dimg='docker images'
fi

# ── Azure CLI ─────────────────────────────────────────────────────────────────
if command -v az &>/dev/null; then
    alias azlogin='az login --use-device-code'
    alias azsub='az account list --output table'
    alias azrg='az group list --output table'
    azset() { az account set --subscription "$1"; }
fi

# ── Editor ────────────────────────────────────────────────────────────────────
export EDITOR='code'
ZSHRC_CONTENT

ok ".zshrc written"

# ── Change default shell to zsh ───────────────────────────────────────────────
step "Default shell"
if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s "$(which zsh)"
    ok "Default shell changed to zsh"
else
    skip "zsh already default shell"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo -e "\n\033[32mDone! Start a new shell or run: exec zsh\033[0m"
echo -e "\033[90mTo update later: git pull && bash setup-wsl.sh\033[0m"
