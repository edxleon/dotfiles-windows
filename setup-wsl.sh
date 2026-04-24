#!/usr/bin/env bash
# WSL Ubuntu setup — mirrors the PowerShell dotfiles environment
set -euo pipefail

step() { echo -e "\n\033[36m==> $1\033[0m"; }
ok()   { echo -e "    \033[32m[OK]\033[0m $1"; }
skip() { echo -e "    \033[90m[--]\033[0m $1"; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# sudo-Verfuegbarkeit pruefen — alle apt-Operationen sind optional
HAVE_SUDO=false
if sudo -n true 2>/dev/null; then
    HAVE_SUDO=true
fi

apt_install() {
    if $HAVE_SUDO; then
        sudo apt install -y -qq "$@"
    else
        echo -e "    \033[33m[!!]\033[0m Kein sudo — ueberspringe: apt install $*"
        echo -e "         Manuell nachinstallieren: sudo apt install $*"
        return 0
    fi
}

# ── System update ─────────────────────────────────────────────────────────────
step "System packages"
if $HAVE_SUDO; then
    sudo apt update -qq && sudo apt upgrade -y -qq
else
    skip "apt update/upgrade uebersprungen (kein sudo)"
fi
apt_install curl wget git unzip build-essential zsh tmux vim python3-dev cmake

# ── Zsh + Oh My Zsh ───────────────────────────────────────────────────────────
step "Zsh + Oh My Zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "Oh My Zsh installiert"
else
    skip "Oh My Zsh bereits vorhanden"
fi

# ── Starship prompt ───────────────────────────────────────────────────────────
step "Starship prompt"
if ! command -v starship &>/dev/null; then
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
    ok "Starship installiert"
else
    skip "Starship bereits vorhanden"
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
ok "Starship config geschrieben"

# ── Productivity tools ────────────────────────────────────────────────────────
step "Productivity tools (fzf, zoxide, bat, eza, ripgrep, fd)"

# fzf
if ! command -v fzf &>/dev/null; then
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf" 2>/dev/null
    "$HOME/.fzf/install" --all --no-update-rc
    ok "fzf installiert"
else
    skip "fzf bereits vorhanden"
fi

# zoxide
if ! command -v zoxide &>/dev/null; then
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    ok "zoxide installiert"
else
    skip "zoxide bereits vorhanden"
fi

# bat (batcat in Ubuntu)
if ! command -v bat &>/dev/null && ! command -v batcat &>/dev/null; then
    apt_install bat
    ok "bat installiert"
else
    skip "bat bereits vorhanden"
fi
mkdir -p "$HOME/.local/bin"
if [ -f /usr/bin/batcat ] && [ ! -f "$HOME/.local/bin/bat" ]; then
    ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
    ok "bat symlink erstellt"
fi

# eza
if ! command -v eza &>/dev/null; then
    if $HAVE_SUDO; then
        apt_install gpg
        sudo mkdir -p /etc/apt/keyrings
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
            | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
            | sudo tee /etc/apt/sources.list.d/gierens.list > /dev/null
        sudo apt update -qq && apt_install eza
        ok "eza installiert"
    else
        echo -e "    \033[33m[!!]\033[0m Kein sudo — eza PPA-Installation uebersprungen"
        echo -e "         Manuell: sudo apt install gpg && (eza deb.asc Schritte)"
    fi
else
    skip "eza bereits vorhanden"
fi

# ripgrep + fd
for pkg in ripgrep fd-find; do
    if ! dpkg -l "$pkg" &>/dev/null; then
        apt_install "$pkg"
        ok "$pkg installiert"
    else
        skip "$pkg bereits vorhanden"
    fi
done
# fd alias (fd-find ships as fdfind)
if command -v fdfind &>/dev/null && [ ! -f "$HOME/.local/bin/fd" ]; then
    ln -sf "$(which fdfind)" "$HOME/.local/bin/fd"
    ok "fd symlink erstellt"
fi

# ── nvm + Node LTS ────────────────────────────────────────────────────────────
step "nvm + Node LTS"
if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    ok "nvm installiert"
else
    skip "nvm bereits vorhanden"
fi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
if ! command -v node &>/dev/null; then
    nvm install --lts
    npm install -g pnpm
    ok "Node LTS + pnpm installiert"
else
    skip "Node $(node --version) bereits vorhanden"
fi

# ── .zshrc ────────────────────────────────────────────────────────────────────
step ".zshrc Konfiguration"
ZSHRC="$HOME/.zshrc"

# Backup existing if not managed by us
if [ -f "$ZSHRC" ] && ! grep -q "# managed by dotfiles-windows" "$ZSHRC" 2>/dev/null; then
    cp "$ZSHRC" "${ZSHRC}.backup-$(date +%Y%m%d-%H%M%S)"
    ok ".zshrc gesichert"
fi

cat > "$ZSHRC" << 'ZSHRC_CONTENT'
# managed by dotfiles-windows

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""  # using starship instead
plugins=(git fzf)
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

# ── Docker ────────────────────────────────────────────────────────────────────
if command -v docker &>/dev/null; then
    alias dps='docker ps'
    alias dex='docker exec -it'
    alias dlogs='docker logs -f'
    alias dprune='docker system prune -af'
    alias dimg='docker images'
fi

# ── Editor ────────────────────────────────────────────────────────────────────
export EDITOR='code'
ZSHRC_CONTENT

ok ".zshrc geschrieben"

# ── tmux: tpm + config ────────────────────────────────────────────────────────
step "tmux (tpm + config)"
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    ok "tpm installiert"
else
    skip "tpm bereits vorhanden"
fi
ln -sf "$DOTFILES_DIR/configs/tmux.conf" "$HOME/.tmux.conf"
ok "~/.tmux.conf -> repo"
# Install plugins headlessly
if command -v tmux &>/dev/null && [ -f "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
    "$HOME/.tmux/plugins/tpm/bin/install_plugins" &>/dev/null
    ok "tmux plugins installiert"
fi

# ── vim: vim-plug + config ────────────────────────────────────────────────────
step "vim (vim-plug + config)"
if [ ! -f "$HOME/.vim/autoload/plug.vim" ]; then
    curl -fsSLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    ok "vim-plug installiert"
else
    skip "vim-plug bereits vorhanden"
fi
ln -sf "$DOTFILES_DIR/configs/vimrc" "$HOME/.vimrc"
mkdir -p "$HOME/.vim/undo"
ok "~/.vimrc -> repo"
vim +PlugInstall +qall &>/dev/null || true
ok "vim plugins installiert"

# YouCompleteMe requires compilation
YCM_DIR="$HOME/.vim/plugged/YouCompleteMe"
if [ -d "$YCM_DIR" ] && [ ! -f "$YCM_DIR/third_party/ycmd/ycm_core.so" ]; then
    python3 "$YCM_DIR/install.py" &>/dev/null && ok "YouCompleteMe kompiliert" \
        || echo "    [!!] YCM build fehlgeschlagen — manuell: python3 ~/.vim/plugged/YouCompleteMe/install.py"
fi

# ── Change default shell to zsh ───────────────────────────────────────────────
step "Standard-Shell"
if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s "$(which zsh)" || {
        echo "    [!!] chsh fehlgeschlagen — zsh manuell starten: exec zsh"
        echo "         oder 'exec zsh' in ~/.bashrc eintragen"
    }
    ok "Standard-Shell auf zsh gesetzt (Terminal neu starten)"
else
    skip "zsh bereits Standard-Shell"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo -e "\n\033[32mFertig! Neue Shell starten oder: exec zsh\033[0m"
echo -e "\033[90mSpaeter aktualisieren: git pull && bash setup-wsl.sh\033[0m"
