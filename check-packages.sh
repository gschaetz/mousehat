#!/bin/bash
set -e

# Find settings dir: env var takes priority, then last-used path saved by runplay.sh
SETTINGS_DIR="${DESKTOP_SETTINGS_DIR}"
if [ -z "$SETTINGS_DIR" ] && [ -f ~/.config/mousehat/settings_dir ]; then
  SETTINGS_DIR="$(cat ~/.config/mousehat/settings_dir)"
fi
if [ -z "$SETTINGS_DIR" ]; then
  echo "Error: No settings directory found."
  echo "Run mousehat with -s first, or set DESKTOP_SETTINGS_DIR."
  exit 1
fi
if [ ! -d "$SETTINGS_DIR" ]; then
  echo "Error: Settings directory not found: $SETTINGS_DIR"
  exit 1
fi

python3 - "$SETTINGS_DIR" <<'EOF'
import sys, subprocess, json
from pathlib import Path

settings_dir = Path(sys.argv[1])

def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout.strip().splitlines()

def load_yaml_list(path, *keys):
    """Extract a list from a YAML file using yq, traversing nested keys."""
    expr = "." + ".".join(keys) + "[]"
    out = subprocess.run(
        ["yq", "-r", expr, str(path)],
        capture_output=True, text=True
    ).stdout.strip()
    return {line.strip() for line in out.splitlines() if line.strip() and line.strip() != "null"}

def load_yaml_list_field(path, *keys, field=None):
    """Extract a field from each item in a YAML list using yq."""
    expr = "." + ".".join(keys) + f'[].{field}'
    out = subprocess.run(
        ["yq", "-r", expr, str(path)],
        capture_output=True, text=True
    ).stdout.strip()
    return {line.strip() for line in out.splitlines() if line.strip() and line.strip() != "null"}

def formula_name(pkg):
    """Strip tap prefix from brew formula names (e.g. oven-sh/bun/bun -> bun)."""
    return pkg.split("/")[-1]

def print_report(section, untracked, missing):
    print(f"\n── {section} {'─' * (50 - len(section))}")
    if untracked:
        print("  Installed but not in config:")
        for p in sorted(untracked):
            print(f"    + {p}")
    else:
        print("  All installed packages are tracked.")
    if missing:
        print("  In config but not installed:")
        for p in sorted(missing):
            print(f"    - {p}")

# ── macOS ──────────────────────────────────────────────────────────────────────
def check_macos():
    yml = settings_dir / "macos-brew.yml"
    if not yml.exists():
        print("macos-brew.yml not found, skipping.")
        return

    # Formulae — use `brew leaves` for untracked (excludes auto-installed deps),
    # but check full install list for missing tracked packages
    tracked_raw = load_yaml_list(yml, "brew", "installed")
    tracked = {formula_name(p) for p in tracked_raw}
    leaves = {formula_name(p) for p in run(["brew", "leaves"])}
    all_installed = {formula_name(p) for p in run(["brew", "list", "--formula"])}
    print_report("brew formulae", leaves - tracked, tracked - all_installed)

    # Casks
    tracked_casks = load_yaml_list(yml, "brew_cask", "installed")
    installed_casks = set(run(["brew", "list", "--cask"]))
    print_report("brew casks", installed_casks - tracked_casks, tracked_casks - installed_casks)

    # Taps
    tracked_taps = load_yaml_list(yml, "tap", "installed")
    installed_taps = set(run(["brew", "tap"]))
    print_report("brew taps", installed_taps - tracked_taps, tracked_taps - installed_taps)

# ── Linux / WSL ────────────────────────────────────────────────────────────────
def check_linux(yml_name, label):
    yml = settings_dir / yml_name
    if not yml.exists():
        print(f"{yml_name} not found, skipping.")
        return

    # apt packages (manually installed only — excludes auto-installed deps)
    tracked_pkgs = load_yaml_list(yml, "packages", "installed")
    installed_pkgs = set(run(["apt-mark", "showmanual"]))
    print_report(f"{label} apt packages", installed_pkgs - tracked_pkgs, tracked_pkgs - installed_pkgs)

    # snaps
    tracked_snaps = load_yaml_list_field(yml, "snaps", "installed", field="name")
    snap_lines = run(["snap", "list"])
    installed_snaps = {line.split()[0] for line in snap_lines[1:] if line}  # skip header
    installed_snaps.discard("snapd")
    print_report(f"{label} snaps", installed_snaps - tracked_snaps, tracked_snaps - installed_snaps)

# ── Dispatch ───────────────────────────────────────────────────────────────────
import platform, os

system = platform.system()
is_wsl = "microsoft" in platform.uname().release.lower()

if system == "Darwin":
    print(f"Checking macOS packages against: {settings_dir}/macos-brew.yml")
    check_macos()
elif is_wsl:
    print(f"Checking WSL packages against: {settings_dir}/wsl-packages.yml")
    check_linux("wsl-packages.yml", "WSL")
elif system == "Linux":
    print(f"Checking Linux packages against: {settings_dir}/linux-packages.yml")
    check_linux("linux-packages.yml", "Linux")
else:
    print(f"Unsupported platform: {system}")
    sys.exit(1)

print()
EOF
