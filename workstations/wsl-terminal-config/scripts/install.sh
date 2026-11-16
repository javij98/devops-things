#!/usr/bin/env bash
#
# install.sh - Automated installer for WSL Terminal Configuration
# Sets up Zsh, Oh My Zsh, Starship prompt, Windows Terminal profile & fonts.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

banner() {
    echo -e "${BOLD}======================================================${NC}"
    echo -e "${BOLD}  WSL Terminal Configuration Installer                ${NC}"
    echo -e "${BOLD}======================================================${NC}"
}

check_prerequisites() {
    info "Verifying base packages..."
    local missing_pkgs=()

    for cmd in curl tar git; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_pkgs+=("$cmd")
        fi
    done

    if ! command -v zsh &>/dev/null; then
        missing_pkgs+=("zsh")
    fi

    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        warn "Missing packages detected: ${missing_pkgs[*]}"
        info "Attempting installation via apt (sudo required)..."
        if command -v sudo &>/dev/null; then
            sudo apt update && sudo apt install -y "${missing_pkgs[@]}"
            success "Packages installed successfully."
        else
            error "sudo is not available. Please install manually: ${missing_pkgs[*]}"
            exit 1
        fi
    else
        success "All required base packages (curl, tar, git, zsh) are installed."
    fi
}

install_starship() {
    info "Setting up Starship prompt..."
    mkdir -p "${HOME}/.local/bin"

    if command -v starship &>/dev/null; then
        success "Starship is already installed: $(starship --version | head -n1)"
    else
        info "Downloading official Starship installer..."
        curl -fsSL https://starship.rs/install.sh -o /tmp/starship-install.sh
        sh /tmp/starship-install.sh --yes --bin-dir "${HOME}/.local/bin"
        success "Starship installed in ${HOME}/.local/bin/starship."
    fi

    export PATH="${HOME}/.local/bin:${PATH}"
}

apply_prompt_config() {
    info "Applying Starship prompt configuration..."
    mkdir -p "${HOME}/.config"
    cp "${CONFIG_DIR}/starship.toml" "${HOME}/.config/starship.toml"
    success "Prompt configuration copied to ~/.config/starship.toml"
}

setup_zsh_and_omz() {
    info "Setting up Oh My Zsh and ~/.zshrc..."

    # Install Oh My Zsh if not present
    if [ ! -d "${HOME}/.oh-my-zsh" ]; then
        info "Cloning Oh My Zsh repository..."
        git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "${HOME}/.oh-my-zsh"
        success "Oh My Zsh installed."
    else
        success "Oh My Zsh is already present at ~/.oh-my-zsh"
    fi

    # Backup existing .zshrc if present
    if [ -f "${HOME}/.zshrc" ]; then
        local ts
        ts="$(date +%Y%m%d_%H%M%S)"
        cp "${HOME}/.zshrc" "${HOME}/.zshrc.bak_${ts}"
        info "Backed up existing ~/.zshrc to ~/.zshrc.bak_${ts}"
    fi

    # Ensure .zshrc has correct configuration
    # Check if we should initialize from template or update existing
    if [ ! -f "${HOME}/.zshrc" ] || ! grep -q "oh-my-zsh.sh" "${HOME}/.zshrc" 2>/dev/null; then
        info "Generating base ~/.zshrc..."
        cat << 'EOF' > "${HOME}/.zshrc"
# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Minimal Starship theme setup: disable OMZ theme before sourcing OMZ
ZSH_THEME=""

# Plugins
plugins=(git)

source $ZSH/oh-my-zsh.sh

# User environment & PATH
export PATH="$HOME/.local/bin:$PATH"

# Import aliases from .bashrc if present and not already defined
if [ -f "$HOME/.bashrc" ]; then
    # Common tools & aliases
    [ -s "$HOME/.nvm/nvm.sh" ] && export NVM_DIR="$HOME/.nvm" && \. "$NVM_DIR/nvm.sh"
    [ -d "$HOME/.pyenv" ] && export PATH="$HOME/.pyenv/bin:$PATH" && eval "$(pyenv init - 2>/dev/null)" || true
fi

EOF
    fi

    # Ensure ZSH_THEME="" is set before oh-my-zsh.sh
    if grep -q "ZSH_THEME=" "${HOME}/.zshrc"; then
        sed -i 's/^ZSH_THEME=.*/ZSH_THEME=""/' "${HOME}/.zshrc"
    else
        sed -i '1i ZSH_THEME=""' "${HOME}/.zshrc"
    fi

    # Ensure PATH contains ~/.local/bin
    if ! grep -q 'PATH.*\.local/bin' "${HOME}/.zshrc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.zshrc"
    fi

    # Ensure starship init line is at the end
    if ! grep -q 'starship init zsh' "${HOME}/.zshrc"; then
        echo '' >> "${HOME}/.zshrc"
        echo '# Starship prompt initialization' >> "${HOME}/.zshrc"
        echo 'eval "$(starship init zsh)"' >> "${HOME}/.zshrc"
        success "Added Starship initialization to ~/.zshrc"
    else
        success "Starship initialization already present in ~/.zshrc"
    fi
}

download_nerd_fonts() {
    info "Checking Windows host Nerd Fonts..."

    # Detect Windows Downloads directory
    local win_user_dir=""
    for user_candidate in /mnt/c/Users/*; do
        local bname
        bname="$(basename "$user_candidate")"
        if [ -d "$user_candidate" ] && [ "$bname" != "Public" ] && [ "$bname" != "Default" ] && [ "$bname" != "All Users" ] && [ "$bname" != "Default User" ]; then
            if [ -d "$user_candidate/Downloads" ] && [ -w "$user_candidate/Downloads" ]; then
                win_user_dir="$user_candidate"
                break
            fi
        fi
    done

    if [ -z "$win_user_dir" ]; then
        warn "Could not automatically locate Windows user profile under /mnt/c/Users/."
        info "Fonts can be downloaded manually from: https://github.com/ryanoasis/nerd-fonts/releases/latest"
        return 0
    fi

    local target_font_dir="${win_user_dir}/Downloads/CascadiaCode-NerdFont"
    local win_fonts_dir="${win_user_dir}/AppData/Local/Microsoft/Windows/Fonts"

    # Check if fonts are already installed in Windows
    if [ -d "$win_fonts_dir" ] && ls "$win_fonts_dir"/CaskaydiaCoveNerdFontMono-*.ttf &>/dev/null; then
        success "CaskaydiaCove Nerd Font Mono is already installed in Windows Fonts directory."
        return 0
    fi

    mkdir -p "$target_font_dir"
    info "Downloading CascadiaCode Nerd Font v3.5.1 to Windows Downloads..."
    local tmp_archive="/tmp/CascadiaCode.tar.xz"
    curl -fsSL -o "$tmp_archive" "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/CascadiaCode.tar.xz"
    
    tar -xf "$tmp_archive" -C "$target_font_dir" \
        CaskaydiaCoveNerdFontMono-Regular.ttf \
        CaskaydiaCoveNerdFontMono-Bold.ttf \
        CaskaydiaCoveNerdFontMono-Italic.ttf \
        CaskaydiaCoveNerdFontMono-BoldItalic.ttf
    rm -f "$tmp_archive"

    success "Extracted 4 font files to: ${target_font_dir}"
    echo -e "  ${YELLOW}➔ ACTION REQUIRED ON WINDOWS:${NC}"
    echo -e "    1. Open folder: ${BOLD}Downloads\\CascadiaCode-NerdFont${NC}"
    echo -e "    2. Select all 4 .ttf files -> Right click -> ${BOLD}Install${NC} (or Install for all users)"
}

setup_windows_powershell() {
    info "Setting up Windows PowerShell integration..."
    local win_user_dir=""
    for user_candidate in /mnt/c/Users/*; do
        local bname
        bname="$(basename "$user_candidate")"
        if [ -d "$user_candidate" ] && [ "$bname" != "Public" ] && [ "$bname" != "Default" ] && [ "$bname" != "All Users" ] && [ "$bname" != "Default User" ]; then
            if [ -d "$user_candidate/Downloads" ] && [ -w "$user_candidate/Downloads" ]; then
                win_user_dir="$user_candidate"
                break
            fi
        fi
    done

    if [ -z "$win_user_dir" ]; then
        warn "Could not locate active Windows user folder for PowerShell synchronization."
        return 0
    fi

    # 1. Sync starship.toml to Windows .config
    mkdir -p "${win_user_dir}/.config"
    cp "${CONFIG_DIR}/starship.toml" "${win_user_dir}/.config/starship.toml"
    success "Synchronized prompt config to Windows: ${win_user_dir}/.config/starship.toml"

    # 2. Ensure starship.exe is available in Windows user bin
    mkdir -p "${win_user_dir}/bin"
    if [ ! -f "${win_user_dir}/bin/starship.exe" ]; then
        info "Downloading starship.exe for Windows..."
        local tmp_zip="/tmp/starship-windows.zip"
        if curl -fsSL -o "$tmp_zip" "https://github.com/starship/starship/releases/latest/download/starship-x86_64-pc-windows-msvc.zip"; then
            unzip -o "$tmp_zip" -d "${win_user_dir}/bin/" &>/dev/null
            rm -f "$tmp_zip"
            success "Installed starship.exe in ${win_user_dir}/bin/starship.exe"
        else
            warn "Could not download starship.exe automatically. Run 'winget install Starship.Starship' in PowerShell."
        fi
    else
        success "starship.exe already present in ${win_user_dir}/bin/starship.exe"
    fi

    # 3. Configure PowerShell profiles across standard Documents and OneDrive Documents
    local ps_dirs=(
        "${win_user_dir}/Documents/WindowsPowerShell"
        "${win_user_dir}/Documents/PowerShell"
    )
    for onedrive_candidate in "${win_user_dir}"/OneDrive*; do
        if [ -d "$onedrive_candidate" ]; then
            for doc_name in "Documentos" "Documents"; do
                if [ -d "$onedrive_candidate/$doc_name" ]; then
                    ps_dirs+=("$onedrive_candidate/$doc_name/WindowsPowerShell" "$onedrive_candidate/$doc_name/PowerShell")
                fi
            done
        fi
    done

    for pdir in "${ps_dirs[@]}"; do
        mkdir -p "$pdir"
        local pfile="${pdir}/Microsoft.PowerShell_profile.ps1"
        cat << 'EOF' > "$pfile"
# =====================================================================
# Windows PowerShell Profile - Catppuccin Mocha & Starship
# =====================================================================

# 1. UTF-8 Encoding for proper glyph rendering (, ╭─, ╰─)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 2. Path to Starship executable
$UserBin = "$HOME\bin"
if (Test-Path "$UserBin\starship.exe") {
    if ($env:PATH -notlike "*$UserBin*") {
        $env:PATH = "$UserBin;$env:PATH"
    }
}

# 3. Explicit config path for Starship
$env:STARSHIP_CONFIG = "$HOME\.config\starship.toml"

# 4. Initialize Starship Prompt
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

# 5. Syntax highlighting colors (Catppuccin Mocha)
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    try {
        Set-PSReadLineOption -Colors @{
            Command   = "`e[38;2;137;180;250m" # Blue (#89b4fa)
            Parameter = "`e[38;2;203;166;247m" # Mauve (#cba6f7)
            Operator  = "`e[38;2;137;220;235m" # Sky (#89dceb)
            Variable  = "`e[38;2;245;194;231m" # Pink (#f5c2e7)
            String    = "`e[38;2;166;227;161m" # Green (#a6e3a1)
            Number    = "`e[38;2;250;179;135m" # Peach (#fab387)
            Type      = "`e[38;2;249;226;175m" # Yellow (#f9e2af)
            Comment   = "`e[38;2;108;112;134m" # Overlay0 (#6c7086)
            Error     = "`e[38;2;243;139;168m" # Red (#f38ba8)
        }
    } catch {
        try {
            Set-PSReadLineOption -Colors @{
                Command   = 'Cyan'
                Parameter = 'Magenta'
                Operator  = 'DarkCyan'
                Variable  = 'Yellow'
                String    = 'Green'
                Number    = 'DarkYellow'
                Type      = 'DarkCyan'
                Comment   = 'DarkGray'
                Error     = 'Red'
            }
        } catch { }
    }
}

# 6. Aliases
Set-Alias -Name g -Value git -ErrorAction SilentlyContinue
Set-Alias -Name gs -Value git-status -ErrorAction SilentlyContinue
function git-status { git status }
EOF
        success "Configured Starship and Catppuccin in PowerShell profile: ${pfile}"
    done
}

configure_windows_terminal() {
    info "Configuring Windows Terminal appearance and color scheme..."
    if [ -f "${SCRIPT_DIR}/apply-windows-terminal-settings.py" ]; then
        python3 "${SCRIPT_DIR}/apply-windows-terminal-settings.py"
        success "Windows Terminal settings configured successfully."
    else
        warn "apply-windows-terminal-settings.py not found. Windows Terminal settings skipped."
    fi
}

check_default_shell() {
    local current_user
    current_user="$(id -un)"
    local user_shell
    user_shell="$(grep "^${current_user}:" /etc/passwd | cut -d: -f7)"
    local zsh_path
    zsh_path="$(command -v zsh || echo "/usr/bin/zsh")"

    if [ "$user_shell" != "$zsh_path" ]; then
        warn "Current default shell is '${user_shell}', not '${zsh_path}'."
        info "To set Zsh as your default shell, run:"
        echo -e "    ${BOLD}chsh -s $(command -v zsh)${NC}"
    else
        success "Default shell is already set to ${zsh_path}."
    fi
}

main() {
    banner
    check_prerequisites
    install_starship
    apply_prompt_config
    setup_zsh_and_omz
    download_nerd_fonts
    setup_windows_powershell
    configure_windows_terminal
    check_default_shell

    echo ""
    echo -e "${BOLD}======================================================${NC}"
    echo -e "${GREEN}${BOLD}  Installation Complete!                              ${NC}"
    echo -e "${BOLD}======================================================${NC}"
    echo -e "Next steps:"
    echo -e "  1. If you haven't yet, install the 4 fonts in Windows (from Downloads\\CascadiaCode-NerdFont)."
    echo -e "  2. Restart Windows Terminal so it reloads its fonts and theme."
    echo -e "  3. Open a new Ubuntu tab to enjoy your new terminal setup!"
}

main "$@"
