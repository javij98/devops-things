#!/usr/bin/env bash
#
# verify.sh - Automated verification tests for WSL Terminal Configuration
# Checks all requirements: Zsh, Oh My Zsh, Starship, Windows Terminal & fonts.
#

set -uo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNINGS=0

pass() {
    echo -e "  ${GREEN}✔ [PASS]${NC} $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "  ${RED}✖ [FAIL]${NC} $1"
    FAILED=$((FAILED + 1))
}

warn() {
    echo -e "  ${YELLOW}⚠ [WARN]${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

section() {
    echo -e "\n${BOLD}${BLUE}=== $1 ===${NC}"
}

section "1. Zsh & Default Shell Verification"
if command -v zsh &>/dev/null; then
    ZSH_VER="$(zsh --version)"
    pass "Zsh is installed: ${ZSH_VER}"
else
    fail "Zsh binary not found in PATH."
fi

CURRENT_USER="$(id -un)"
USER_SHELL="$(grep "^${CURRENT_USER}:" /etc/passwd | cut -d: -f7)"
if [[ "$USER_SHELL" == *"zsh" ]]; then
    pass "Default login shell in /etc/passwd is Zsh: ${USER_SHELL}"
else
    warn "Default login shell in /etc/passwd is ${USER_SHELL} (expected zsh). Run: chsh -s \$(which zsh)"
fi

section "2. Starship Prompt Verification"
if command -v starship &>/dev/null || [ -x "${HOME}/.local/bin/starship" ]; then
    export PATH="${HOME}/.local/bin:${PATH}"
    STARSHIP_VER="$(starship --version | head -n1)"
    pass "Starship binary is installed: ${STARSHIP_VER}"
else
    fail "Starship binary not found in PATH or ~/.local/bin/starship."
fi

if [ -f "${HOME}/.config/starship.toml" ]; then
    if grep -q "directory" "${HOME}/.config/starship.toml" && grep -q "git_branch" "${HOME}/.config/starship.toml"; then
        pass "Starship configuration file ~/.config/starship.toml exists and contains expected modules."
    else
        warn "~/.config/starship.toml exists but may be missing custom format modules."
    fi
else
    fail "~/.config/starship.toml does not exist."
fi

section "3. Oh My Zsh & ~/.zshrc Verification"
if [ -d "${HOME}/.oh-my-zsh" ]; then
    pass "Oh My Zsh directory exists at ~/.oh-my-zsh."
else
    fail "Oh My Zsh directory not found at ~/.oh-my-zsh."
fi

if [ -f "${HOME}/.zshrc" ]; then
    pass "~/.zshrc file exists."
    
    if grep -q 'ZSH_THEME=""' "${HOME}/.zshrc"; then
        pass "ZSH_THEME is set to \"\" (required for Starship prompt)."
    else
        warn "ZSH_THEME is not explicitly set to empty string in ~/.zshrc."
    fi

    if grep -q 'starship init zsh' "${HOME}/.zshrc"; then
        pass "Starship initialization is configured in ~/.zshrc."
    else
        fail "Missing 'eval \"\$(starship init zsh)\"' in ~/.zshrc."
    fi

    if command -v zsh &>/dev/null; then
        if zsh -n "${HOME}/.zshrc" 2>&1; then
            pass "Syntax check on ~/.zshrc passed cleanly."
        else
            fail "Syntax error detected in ~/.zshrc."
        fi
    fi
else
    fail "~/.zshrc file does not exist."
fi

section "4. Windows Fonts Verification"
FONT_FOUND=false
for user_dir in /mnt/c/Users/*; do
    if [ -d "$user_dir/AppData/Local/Microsoft/Windows/Fonts" ]; then
        if ls "$user_dir/AppData/Local/Microsoft/Windows/Fonts"/CaskaydiaCoveNerdFontMono-*.ttf &>/dev/null; then
            pass "CaskaydiaCove Nerd Font Mono TTF files detected in Windows Fonts: $(ls "$user_dir/AppData/Local/Microsoft/Windows/Fonts"/CaskaydiaCoveNerdFontMono-*.ttf | wc -l) files found."
            FONT_FOUND=true
            break
        fi
    fi
done

if [ "$FONT_FOUND" = false ]; then
    # Check if at least downloaded
    DOWNLOADED=false
    for user_dir in /mnt/c/Users/*; do
        if [ -d "$user_dir/Downloads/CascadiaCode-NerdFont" ]; then
            if ls "$user_dir/Downloads/CascadiaCode-NerdFont"/CaskaydiaCoveNerdFontMono-*.ttf &>/dev/null; then
                warn "Fonts downloaded to $user_dir/Downloads/CascadiaCode-NerdFont, but not yet installed in Windows Fonts directory."
                DOWNLOADED=true
                break
            fi
        fi
    done
    if [ "$DOWNLOADED" = false ]; then
        fail "CaskaydiaCove Nerd Font files neither installed nor found in Downloads."
    fi
fi

section "5. Windows Terminal Configuration Verification"
WT_FOUND=false
for user_dir in /mnt/c/Users/*; do
    SETTINGS_FILE="$user_dir/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
    if [ -f "$SETTINGS_FILE" ]; then
        WT_FOUND=true
        if grep -q '"Catppuccin Mocha"' "$SETTINGS_FILE"; then
            pass "Catppuccin Mocha scheme found in Windows Terminal settings.json."
        else
            fail "Catppuccin Mocha scheme missing in Windows Terminal settings.json."
        fi

        if grep -q '"CaskaydiaCove Nerd Font Mono"' "$SETTINGS_FILE"; then
            pass "CaskaydiaCove Nerd Font Mono configured in Windows Terminal profile."
        else
            fail "CaskaydiaCove Nerd Font Mono not configured in Windows Terminal profile."
        fi
        break
    fi
done

if [ "$WT_FOUND" = false ]; then
    warn "Windows Terminal settings.json could not be inspected automatically."
fi

section "6. Starship Prompt Execution Test"
if command -v starship &>/dev/null && command -v zsh &>/dev/null; then
    PROMPT_OUT="$(TERM=xterm-256color zsh -i -c "starship prompt" 2>&1)"
    if [ $? -eq 0 ] && [ -n "$PROMPT_OUT" ]; then
        pass "Starship prompt successfully rendered in interactive Zsh."
    else
        fail "Failed to render Starship prompt in Zsh."
    fi
fi

echo -e "\n${BOLD}======================================================${NC}"
echo -e "${BOLD}  Verification Summary: ${GREEN}${PASSED} passed${NC}, ${RED}${FAILED} failed${NC}, ${YELLOW}${WARNINGS} warnings${NC}"
echo -e "${BOLD}======================================================${NC}"

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}All critical checks passed successfully!${NC}\n"
    exit 0
else
    echo -e "${RED}${BOLD}Some critical checks failed. Please review the output above.${NC}\n"
    exit 1
fi
