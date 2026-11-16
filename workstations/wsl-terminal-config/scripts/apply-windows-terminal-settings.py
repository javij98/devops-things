#!/usr/bin/env python3
"""
apply-windows-terminal-settings.py

Safely applies Catppuccin Mocha color scheme and profile appearance
to Windows Terminal settings.json from WSL.
Creates a timestamped backup before any modifications.
"""

import glob
import json
import os
import sys
from datetime import datetime
from pathlib import Path


def find_settings_files() -> list[Path]:
    results = []
    users_dir = Path("/mnt/c/Users")
    if not users_dir.is_dir():
        return results

    candidates = [
        d for d in users_dir.iterdir()
        if d.is_dir() and d.name not in ("All Users", "Default", "Default User", "Public")
    ]
    for user_dir in candidates:
        local_app_data = user_dir / "AppData" / "Local"
        patterns = [
            local_app_data / "Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json",
            local_app_data / "Packages/Microsoft.WindowsTerminalPreview_*/LocalState/settings.json",
            local_app_data / "Microsoft/Windows Terminal/settings.json",
        ]
        for pattern in patterns:
            for match in glob.glob(str(pattern)):
                path = Path(match)
                if path.is_file() and path not in results:
                    results.append(path)
    return results


def apply_settings(settings_file: Path, scheme_file: Path, appearance_file: Path) -> bool:
    print(f"[*] Processing Windows Terminal configuration: {settings_file}")
    
    with open(scheme_file, "r", encoding="utf-8") as f:
        scheme_data = json.load(f)

    with open(appearance_file, "r", encoding="utf-8") as f:
        appearance_data = json.load(f)

    with open(settings_file, "r", encoding="utf-8") as f:
        try:
            settings = json.load(f)
        except Exception as exc:
            print(f"[!] Error reading JSON from {settings_file}: {exc}", file=sys.stderr)
            return False

    # Create backup
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = settings_file.with_name(f"settings.json.bak_{timestamp}")
    with open(backup_path, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=4)
    print(f"[+] Backup created at: {backup_path}")

    # 1. Add/Update scheme
    schemes = settings.setdefault("schemes", [])
    scheme_name = scheme_data.get("name", "Catppuccin Mocha")
    existing_idx = next((i for i, s in enumerate(schemes) if isinstance(s, dict) and s.get("name") == scheme_name), -1)
    if existing_idx >= 0:
        schemes[existing_idx] = scheme_data
        print(f"[+] Updated scheme: {scheme_name}")
    else:
        schemes.append(scheme_data)
        print(f"[+] Added scheme: {scheme_name}")

    # 2. Update Ubuntu / WSL profile in profiles.list
    profiles_list = settings.get("profiles", {}).get("list", [])
    default_guid = settings.get("defaultProfile")
    target_profiles = []

    for profile in profiles_list:
        if not isinstance(profile, dict):
            continue
        # Check by default profile GUID, Ubuntu name, or WSL source
        source = profile.get("source", "")
        name = profile.get("name", "").lower()
        guid = profile.get("guid", "")
        
        is_ubuntu_or_wsl = (
            guid == default_guid
            or "ubuntu" in name
            or "wsl" in source.lower()
            or "canonical" in source.lower()
        )
        if is_ubuntu_or_wsl and not profile.get("hidden", False):
            target_profiles.append(profile)

    if not target_profiles:
        print("[!] No visible Ubuntu/WSL profile found in profiles.list. Merging into default profile or first profile.")
        if profiles_list:
            target_profiles.append(profiles_list[0])

    for target in target_profiles:
        target.update(appearance_data)
        print(f"[+] Applied appearance to profile '{target.get('name')}' (GUID: {target.get('guid')})")

    # Save changes
    with open(settings_file, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=4)
    print(f"[+] Successfully saved updated settings to {settings_file}")
    return True


def main() -> int:
    base_dir = Path(__file__).resolve().parent.parent
    scheme_file = base_dir / "windows-terminal" / "catppuccin-mocha.json"
    appearance_file = base_dir / "windows-terminal" / "profile-appearance.json"

    if not scheme_file.is_file() or not appearance_file.is_file():
        print(f"[!] Required files not found in {base_dir / 'windows-terminal'}", file=sys.stderr)
        return 1

    custom_path = sys.argv[1] if len(sys.argv) > 1 else None
    if custom_path:
        settings_files = [Path(custom_path)]
    else:
        settings_files = find_settings_files()

    if not settings_files:
        print("[!] No Windows Terminal settings.json file located automatically.")
        print("    You can pass the absolute path as an argument to this script.")
        return 1

    success_all = True
    for sf in settings_files:
        if not apply_settings(sf, scheme_file, appearance_file):
            success_all = False

    return 0 if success_all else 1


if __name__ == "__main__":
    sys.exit(main())
