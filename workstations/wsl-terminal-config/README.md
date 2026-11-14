# WSL Terminal Configuration

A small, portable visual setup for **Windows Terminal + WSL Ubuntu + Zsh**. It keeps the prompt deliberately minimal: current directory, Git branch/status, and the prompt character only.

## What this config includes

- Starship prompt with a restrained two-line Catppuccin Mocha style.
- Current directory plus Git branch and working-tree status.
- CaskaydiaCove Nerd Font Mono, required for the branch glyph.
- Catppuccin Mocha Windows Terminal color scheme.
- Profile-level font size, spacing, cursor, tab accent, and subtle acrylic transparency.

It does **not** add Kubernetes, cloud, Terraform, Node/Python version, or command-duration prompt modules. No font binaries, personal `.zshrc`, full Windows Terminal settings file, profile GUIDs, aliases, or credentials are stored here.

Verified with WSL Ubuntu 24.04, Zsh 5.9, Starship 1.27.0, and Nerd Fonts `v3.5.1`.

## Files

- `starship.toml` — portable Starship prompt configuration.
- `zsh/omz-theme-setting.zsh` — the Oh My Zsh theme setting to use before loading Oh My Zsh.
- `zsh/starship-init.zsh` — the Starship initialization line to add at the end of `.zshrc`.
- `windows-terminal/catppuccin-mocha.json` — the color-scheme object to merge into Windows Terminal's `schemes` array.
- `windows-terminal/profile-appearance.json` — appearance properties to merge into the WSL profile object.

## Step-by-step installation

### 1. Get the configuration

Clone the `devops-things` repository using your normal GitHub access, then enter this directory:

```bash
cd devops-things/workstations/wsl-terminal-config
```

If you already have the repository, pull the latest version before continuing. Access to the repository is required if it is private.

### 2. Install the Nerd Font on Windows

The font must be installed on the **Windows host** because Windows Terminal renders the glyphs.

1. Download `CascadiaCode.tar.xz` from the [latest Nerd Fonts release](https://github.com/ryanoasis/nerd-fonts/releases/latest). The configuration was verified with release `v3.5.1`.
2. Extract the archive (for example, with 7-Zip).
3. Install these four font files for your Windows user: `CaskaydiaCoveNerdFontMono-Regular.ttf`, `CaskaydiaCoveNerdFontMono-Bold.ttf`, `CaskaydiaCoveNerdFontMono-Italic.ttf`, and `CaskaydiaCoveNerdFontMono-BoldItalic.ttf`.
4. In Windows Terminal, the font family name is **`CaskaydiaCove Nerd Font Mono`**.

Do not add the font binaries to this repository; download them from the upstream release when setting up another computer.

### 3. Install Starship in WSL

Run these commands in Ubuntu/WSL. Installing into `~/.local/bin` avoids needing a system-wide install:

```bash
mkdir -p "$HOME/.local/bin"
curl -fsSL https://starship.rs/install.sh -o /tmp/starship-install.sh
less /tmp/starship-install.sh
sh /tmp/starship-install.sh --yes --bin-dir "$HOME/.local/bin"
```

The script is downloaded from the official [Starship installation page](https://starship.rs/guide/); review it before running. If `less` is unavailable, open the file in your preferred text viewer. Ensure `~/.local/bin` is in your shell's `PATH`; add this line to `~/.zshrc` if needed:

```zsh
export PATH="$HOME/.local/bin:$PATH"
```

Verify the executable:

```bash
starship --version
```

### 4. Install the prompt configuration

From this directory, copy the config into Starship's standard location:

```bash
mkdir -p "$HOME/.config"
cp starship.toml "$HOME/.config/starship.toml"
```

The custom `format` names only `directory`, `git_branch`, `git_status`, and `character`; it intentionally avoids Starship's other context modules.

### 5. Enable Starship in Zsh

This setup assumes Zsh with Oh My Zsh. If they are not installed, install Zsh using your Linux distribution's package manager and follow the [official Oh My Zsh installation instructions](https://github.com/ohmyzsh/ohmyzsh/wiki).

1. In `~/.zshrc`, replace the existing `ZSH_THEME=...` assignment with the contents of `zsh/omz-theme-setting.zsh` (`ZSH_THEME=""`). Keep it **before** the line that loads Oh My Zsh.
2. Preserve your existing plugins and other aliases.
3. Add the contents of `zsh/starship-init.zsh` at the very end of `~/.zshrc`, after Oh My Zsh and any later prompt configuration.
4. Start a new Zsh session, or run `source ~/.zshrc`.

### 6. Apply the Windows Terminal colors and profile appearance

1. Open Windows Terminal settings with **Ctrl+,**, then choose **Open JSON file**.
2. In the top-level `schemes` array, add the complete object from `windows-terminal/catppuccin-mocha.json`. Keep any existing schemes and ensure the commas are valid.
3. In `profiles.list`, find the Ubuntu profile that launches WSL on your machine. Profile GUIDs differ between computers; do not copy a GUID from another installation.
4. Merge the properties from `windows-terminal/profile-appearance.json` into that profile object. Do not replace the whole settings file or put these settings in `profiles.defaults` unless you want the appearance applied to every profile.
5. Save the file. Open a new WSL tab; if Windows Terminal was already running when the font was installed, close and reopen Windows Terminal so it can enumerate the new font. There is no need to restart WSL.

The checked-in appearance fragment is valid JSON, but it is intentionally a set of profile properties rather than a complete Windows Terminal `settings.json` file.

### 7. Verify

Open a new WSL/Zsh session and run:

```bash
starship --version
starship prompt
```

Inside a Git repository, the prompt should show its directory, branch, and any working-tree status. Outside a Git repository, it should show only the directory and prompt character. The branch icon should render correctly when the Windows Terminal profile uses the specified Nerd Font family.

## Updating

Pull changes to this directory and repeat the relevant copy/merge steps. To update Starship or the font, use their upstream release/install pages rather than committing binaries here.

## Upstream projects

- [Starship](https://github.com/starship/starship) — prompt engine and official installer.
- [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) — patched Cascadia/Caskaydia font files.
- [Catppuccin for Windows Terminal](https://github.com/catppuccin/windows-terminal) — Mocha color palette.
