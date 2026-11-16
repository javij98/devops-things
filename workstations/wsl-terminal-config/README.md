# WSL Terminal Configuration

[![Language: Spanish](https://img.shields.io/badge/Language-Spanish-yellow.svg)](README.es.md)
[![Status: Verified](https://img.shields.io/badge/Status-Verified-brightgreen.svg)](#verification)

A portable, aesthetic visual setup for **Windows Terminal + WSL Ubuntu + Zsh**. It provides a clean, two-line **Catppuccin Mocha** terminal theme with a minimal Starship prompt (current directory, Git branch & status, and prompt character).

---

## Table of Contents

1. [Features](#features)
2. [What is Automated vs. What is Manual](#what-is-automated-vs-what-is-manual)
3. [Quick Start (Automated Installation)](#quick-start-automated-installation)
4. [Step-by-Step Manual Installation](#step-by-step-manual-installation)
   - [Step 1: Install Ubuntu / WSL Prerequisites](#step-1-install-ubuntu--wsl-prerequisites)
   - [Step 2: Install Nerd Font on Windows](#step-2-install-nerd-font-on-windows)
   - [Step 3: Install Starship Prompt](#step-3-install-starship-prompt)
   - [Step 4: Copy Prompt Configuration](#step-4-copy-prompt-configuration)
   - [Step 5: Setup Oh My Zsh and ~/.zshrc](#step-5-setup-oh-my-zsh-and-zshrc)
   - [Step 6: Configure Windows Terminal](#step-6-configure-windows-terminal)
   - [Step 7: Set Zsh as Default Shell](#step-7-set-zsh-as-default-shell)
5. [Verification & Automated Tests](#verification--automated-tests)
6. [Troubleshooting & FAQ](#troubleshooting--faq)
7. [Directory Structure](#directory-structure)

---

## Features

- **Prompt**: Two-line minimal Starship layout styled with Catppuccin Mocha colors.
- **Git Integration**: Fast Git branch name, glyph (``), and dirty/ahead/behind status indicators.
- **Typography**: CaskaydiaCove Nerd Font Mono (Cascadia Code patched with developer glyphs).
- **Windows Terminal**: Full Catppuccin Mocha color palette, modern bar cursor, padding, acrylic background blur (95% opacity), and custom tab accents.
- **Shell Compatibility**: Full Oh My Zsh support with safe migration of your existing `.bashrc` aliases and environment variables.

---

## What is Automated vs. What is Manual

Windows and WSL operate under distinct security and permission boundaries. Here is the exact breakdown:

| Step / Component | Automated via `scripts/install.sh`? | Manual Action Needed? | Notes & Permissions |
| :--- | :---: | :---: | :--- |
| **Prerequisites** (`zsh`, `curl`, `tar`, `git`) | **Yes** | Sudo password prompt | Prompts for your Ubuntu password if any package is missing. |
| **Starship CLI** | **Yes** | None | Installs cleanly to `~/.local/bin/starship` (no root required). |
| **Prompt Config** (`starship.toml`) | **Yes** | None | Deployed to `~/.config/starship.toml`. |
| **Oh My Zsh & `.zshrc`** | **Yes** | None | Clones OMZ, creates timestamped `.zshrc.bak`, configures `ZSH_THEME=""` and imports aliases. |
| **Download Nerd Fonts** | **Yes** | None | Downloads v3.5.1 and extracts to your Windows `Downloads\CascadiaCode-NerdFont` folder. |
| **Install Fonts on Windows** | **No** | **Yes (1-click)** | Windows security requires right-clicking the 4 `.ttf` files and choosing **Install**. |
| **Windows Terminal Settings** | **Yes** | None | Locates your Windows `settings.json`, backs it up, and merges the color scheme & profile appearance. |
| **Set Zsh as Default Shell** | **Guided** | **Yes (1 command)** | Run `chsh -s $(which zsh)` to switch your default login shell from bash to zsh. |
| **Terminal Reload** | **No** | **Yes** | Close and reopen Windows Terminal so DirectWrite detects the newly installed fonts. |

---

## Quick Start (Automated Installation)

If you are using WSL Ubuntu, you can run the automated installer directly from this folder:

```bash
cd workstations/wsl-terminal-config
./scripts/install.sh
```

The script will:
1. Verify base packages (`curl`, `tar`, `git`, `zsh`) and install any missing packages via `sudo apt`.
2. Install Starship to `~/.local/bin/starship`.
3. Copy `starship.toml` into `~/.config/starship.toml`.
4. Install Oh My Zsh and set up `~/.zshrc`.
5. Download and extract the 4 `CaskaydiaCove Nerd Font Mono` font files directly into your Windows `Downloads\CascadiaCode-NerdFont` directory.
6. Automatically locate and update your Windows Terminal `settings.json` with the Catppuccin Mocha scheme and profile appearance.

### Remaining manual actions after running the script:
1. **Install fonts in Windows**: Open File Explorer in Windows, navigate to `Downloads\CascadiaCode-NerdFont`, select the 4 `.ttf` files, right-click and click **Install**.
2. **Switch default shell** (if not already done):
   ```bash
   chsh -s $(which zsh)
   ```
3. **Restart Windows Terminal**: Close Windows Terminal completely and reopen it.

To verify your installation at any time, run:
```bash
./scripts/verify.sh
```

---

## Step-by-Step Manual Installation

If you prefer to perform every step by hand, or if you are setting up a machine with restricted script execution, follow these instructions:

### Step 1: Install Ubuntu / WSL Prerequisites

Open your WSL terminal and ensure the essential packages are present:

```bash
sudo apt update
sudo apt install -y zsh curl tar git
```

### Step 2: Install Nerd Font on Windows

Windows Terminal runs as a native Windows application, so the font glyphs must be installed on the **Windows host system**:

1. Download `CascadiaCode.tar.xz` from the [official Nerd Fonts release v3.5.1](https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/CascadiaCode.tar.xz).
2. Extract the archive (using 7-Zip or tar).
3. Select and install the following four font files:
   - `CaskaydiaCoveNerdFontMono-Regular.ttf`
   - `CaskaydiaCoveNerdFontMono-Bold.ttf`
   - `CaskaydiaCoveNerdFontMono-Italic.ttf`
   - `CaskaydiaCoveNerdFontMono-BoldItalic.ttf`
4. Right-click the selected files and click **Install** (or **Install for all users**).
5. The registered font family name recognized by Windows Terminal is: **`CaskaydiaCove Nerd Font Mono`**.

### Step 3: Install Starship Prompt

Run the official user-space installation command inside WSL:

```bash
mkdir -p "$HOME/.local/bin"
curl -fsSL https://starship.rs/install.sh -o /tmp/starship-install.sh
sh /tmp/starship-install.sh --yes --bin-dir "$HOME/.local/bin"
```

Ensure `~/.local/bin` is in your `PATH` by adding this line to your shell configuration if necessary:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Step 4: Copy Prompt Configuration

Copy the custom Starship configuration into Starship's canonical config folder:

```bash
mkdir -p "$HOME/.config"
cp starship.toml "$HOME/.config/starship.toml"
```

### Step 5: Setup Oh My Zsh and ~/.zshrc

1. If Oh My Zsh is not yet installed:
   ```bash
   git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
   ```

2. Configure `~/.zshrc`:
   - Set the Oh My Zsh theme to empty before loading OMZ (`zsh/omz-theme-setting.zsh`):
     ```zsh
     ZSH_THEME=""
     ```
   - Source Oh My Zsh:
     ```zsh
     source $ZSH/oh-my-zsh.sh
     ```
   - Add your existing environment variables, tools (`nvm`, `pyenv`, `kubeconfig`, SDKMAN), and aliases from `.bashrc`.
   - At the **very end** of `~/.zshrc`, add the Starship hook (`zsh/starship-init.zsh`):
     ```zsh
     eval "$(starship init zsh)"
     ```

### Step 6: Configure Windows Terminal

You can apply the configuration automatically with the included Python helper:

```bash
python3 scripts/apply-windows-terminal-settings.py
```

Or manually:
1. In Windows Terminal, press `Ctrl+,` and click **Open JSON file** (bottom left).
2. Under `"schemes": [ ... ]`, paste the color scheme object from [windows-terminal/catppuccin-mocha.json](windows-terminal/catppuccin-mocha.json).
3. Under `"profiles": { "list": [ ... ] }`, locate your Ubuntu profile (check `"name": "Ubuntu"` or your default profile GUID).
4. Merge the appearance properties from [windows-terminal/profile-appearance.json](windows-terminal/profile-appearance.json):
   ```json
   "colorScheme": "Catppuccin Mocha",
   "font": {
       "face": "CaskaydiaCove Nerd Font Mono",
       "size": 12.5
   },
   "padding": "12, 12, 12, 12",
   "cursorShape": "bar",
   "cursorColor": "#F5E0DC",
   "useAcrylic": true,
   "opacity": 95,
   "tabColor": "#89B4FA"
   ```
5. Save the file.

### Step 7: Set Zsh as Default Shell

Change your default login shell to Zsh:

```bash
chsh -s $(which zsh)
```

Close Windows Terminal and open a new window.

---

## Verification & Automated Tests

A dedicated test suite is provided in `scripts/verify.sh` to validate all aspects of your installation:

```bash
./scripts/verify.sh
```

The script verifies 13 critical checkpoints:
- [x] Zsh binary availability and version
- [x] Default user shell in `/etc/passwd`
- [x] Starship binary location and version
- [x] `~/.config/starship.toml` syntax and module presence
- [x] Oh My Zsh directory structure
- [x] `~/.zshrc` theme override (`ZSH_THEME=""`)
- [x] Starship initialization hook in `~/.zshrc`
- [x] Zsh syntax validation (`zsh -n ~/.zshrc`)
- [x] Installed `CaskaydiaCove Nerd Font Mono` TTF files on Windows
- [x] Catppuccin Mocha scheme in Windows Terminal `settings.json`
- [x] CaskaydiaCove font family assigned to Ubuntu profile
- [x] Interactive prompt rendering test with Git status glyphs

---

## Troubleshooting & FAQ

#### 1. The Git branch symbol shows up as a square `[?]` or broken character.
* **Cause**: Windows Terminal is not using the patched Nerd Font, or Windows Terminal was not restarted after font installation.
* **Fix**: Ensure you installed the 4 `.ttf` font files in Windows, and restart Windows Terminal completely. Check that Windows Terminal settings have `"face": "CaskaydiaCove Nerd Font Mono"`.

#### 2. Starship outputs `[ERROR] - (starship::print): Under a 'dumb' terminal`.
* **Cause**: Occurs only in non-interactive IDE output windows or subshells where `$TERM` defaults to `dumb`.
* **Fix**: Normal interactive shells in Windows Terminal automatically set `TERM=xterm-256color`. You can test it with `TERM=xterm-256color starship prompt`.

#### 3. Where is `settings.json` located on Windows?
* Standard Microsoft Store package:
  `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`
* In WSL, this corresponds to:
  `/mnt/c/Users/<YourWindowsUser>/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json`

---

## Directory Structure

```text
workstations/wsl-terminal-config/
├── README.md                              # This document (English)
├── README.es.md                           # Spanish documentation
├── starship.toml                          # Minimal Starship Catppuccin prompt configuration
├── scripts/
│   ├── install.sh                         # Automated end-to-end installer
│   ├── verify.sh                          # 13-point automated test suite
│   └── apply-windows-terminal-settings.py # Safe JSON merger with backup for Windows Terminal
├── windows-terminal/
│   ├── catppuccin-mocha.json              # Standalone color scheme JSON
│   └── profile-appearance.json            # Profile visual properties JSON
└── zsh/
    ├── omz-theme-setting.zsh              # Theme disable snippet for Oh My Zsh
    └── starship-init.zsh                  # Shell initialization snippet
```
