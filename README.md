# PowerShell Dotfiles

Portable PowerShell setup for Windows. Clone once, run the installer — done.

## Quick Start

```powershell
git clone https://github.com/edxleon/dotfiles-windows powershell-dotfiles
cd powershell-dotfiles
.\install.ps1
```

Restart PowerShell. That's it.

If WSL (Ubuntu) is installed, `setup-wsl.sh` runs automatically inside it.

## What Gets Installed

| Tool | Purpose |
|------|---------|
| [Oh-My-Posh](https://ohmyposh.dev) | Tokyo Night prompt |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder (`Ctrl+T` files, `Ctrl+R` history) |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smart `cd` — type `z <part-of-path>` |
| [bat](https://github.com/sharkdp/bat) | `cat` with syntax highlighting |
| [eza](https://github.com/eza-community/eza) | Modern `ls` with icons |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Fast `grep` (`rg`) |
| [fd](https://github.com/sharkdp/fd) | Fast `find` |
| PSFzf | fzf integration for PowerShell |
| Terminal-Icons | File icons in terminal |
| posh-git | Git status in prompt |
| CompletionPredictor | Smarter tab completions |

## Options

```powershell
.\install.ps1 -SkipWsl   # skip WSL setup
.\install.ps1 -Force     # overwrite existing profile symlink
```

## WSL Only

To run the WSL setup standalone (e.g. on a new distro):

```bash
bash setup-wsl.sh
```

## Updating

```powershell
git pull
```

The profile is a symlink into this repo — `git pull` applies immediately on the next shell start.

## Key Bindings

| Key | Action |
|-----|--------|
| `Ctrl+R` | Fuzzy history search |
| `Ctrl+T` | Fuzzy file picker |
| `F7` | Grid view history |
| `Tab` | Menu completion |
| `↑ / ↓` | History search (filtered by current input) |
| `Ctrl+F` | Jump forward one word |

## Aliases & Functions

| Command | Description |
|---------|-------------|
| `z <path>` | Smart jump (zoxide) |
| `ll` | `eza -la` with icons + git status |
| `lt` | Tree view (3 levels) |
| `cat` | bat with syntax highlighting |
| `gs` | `git status` |
| `glog` | Pretty git log |
| `gpull` | `git pull --rebase` |
| `gpush` | `git push` |
| `dps` | `docker ps` |
| `dprune` | Remove all stopped containers/images |
