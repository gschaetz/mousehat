#!/bin/bash
set -e

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'HELP'
mh-check — show packages installed but not tracked in your settings

Usage:
  mh-check [options]

Options:
  -h, --help  Show this help

Settings directory is read from $DESKTOP_SETTINGS_DIR or the path
saved by mh-apply on last run (~/.config/mousehat/settings_dir).

Checks:
  macOS  — brew formulae (brew leaves), casks, taps vs macos-brew.yml
  Linux  — apt packages, snaps vs linux-packages.yml
  WSL    — apt packages, snaps vs wsl-packages.yml

Output:
  + package   installed but not in config (you'll be asked to add it)
  - package   in config but not installed (will be installed on next mh-apply)

For each "+" package, you'll be prompted to add it to your config file.

Examples:
  mh-check                         # check drift on current machine
  DESKTOP_SETTINGS_DIR=~/cfg mh-check  # use a specific settings directory
HELP
  exit 0
fi

# Find settings dir: env var takes priority, then last-used path saved by mh-apply
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

TMP_PY="$(mktemp)"
trap 'rm -f "$TMP_PY"' EXIT
cat > "$TMP_PY" <<'EOF'
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

def confirm(prompt):
    try:
        return input(f"{prompt} [y/N] ").strip().lower() in ("y", "yes")
    except EOFError:
        return False

def indent_of(line):
    return len(line) - len(line.lstrip(" "))

def yaml_insert(path, top_key, sub_key, item):
    """Append `item` to the `top_key.sub_key` list, editing only that list's
    lines so the rest of the file's formatting is left untouched (unlike
    `yq -i`, which reformats the whole document)."""
    lines = path.read_text().splitlines(keepends=True)

    top_idx = next(
        (i for i, l in enumerate(lines) if l.rstrip("\n") == f"{top_key}:" and indent_of(l) == 0),
        None,
    )
    if top_idx is None:
        raise ValueError(f"key '{top_key}:' not found")

    sub_idx = sub_indent = None
    for i in range(top_idx + 1, len(lines)):
        stripped = lines[i].strip()
        ind = indent_of(lines[i])
        if stripped and ind == 0:
            break
        if stripped == f"{sub_key}:":
            sub_idx, sub_indent = i, ind
            break
    if sub_idx is None:
        raise ValueError(f"key '{sub_key}:' not found under '{top_key}:'")

    item_indent = sub_indent + 4
    insert_idx = sub_idx + 1
    for i in range(sub_idx + 1, len(lines)):
        stripped = lines[i].strip()
        if not stripped:
            continue
        if indent_of(lines[i]) < item_indent:
            break
        insert_idx = i + 1

    pad = " " * item_indent
    if isinstance(item, dict):
        new_lines = [f"{pad}- name: {item['name']}\n"]
        new_lines += [f"{pad}  {k}: {'true' if v is True else 'false' if v is False else v}\n"
                      for k, v in item.items() if k != "name"]
    else:
        new_lines = [f"{pad}- {item}\n"]

    lines[insert_idx:insert_idx] = new_lines
    path.write_text("".join(lines))

def offer_add(yml, keys, untracked, snap=False):
    """Prompt to add each untracked package to the given YAML list."""
    if not untracked:
        return
    top_key, sub_key = keys
    for pkg in sorted(untracked):
        if not confirm(f"    Add '{pkg}' to {yml.name} ({top_key}.{sub_key})?"):
            continue
        item = {"name": pkg, "classic": False} if snap else pkg
        try:
            yaml_insert(yml, top_key, sub_key, item)
            print(f"      added {pkg}")
        except ValueError as e:
            print(f"      failed to add {pkg}: {e}")

# ── macOS ──────────────────────────────────────────────────────────────────────
# Installed directly by ansible roles (not user config) — see docker-applications
# and macos-configure-os-settings roles. Excluded from drift so mh-check doesn't
# flag them as "untracked" every run.
ROLE_MANAGED_FORMULAE = {"dockutil", "socat"}
ROLE_MANAGED_CASKS = {"xquartz"}

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
    untracked = leaves - tracked - ROLE_MANAGED_FORMULAE
    print_report("brew formulae", untracked, tracked - all_installed)
    offer_add(yml, ("brew", "installed"), untracked)

    # Casks
    tracked_casks = load_yaml_list(yml, "brew_cask", "installed")
    installed_casks = set(run(["brew", "list", "--cask"]))
    untracked_casks = installed_casks - tracked_casks - ROLE_MANAGED_CASKS
    print_report("brew casks", untracked_casks, tracked_casks - installed_casks)
    offer_add(yml, ("brew_cask", "installed"), untracked_casks)

    # Taps
    tracked_taps = load_yaml_list(yml, "tap", "installed")
    installed_taps = set(run(["brew", "tap"]))
    untracked_taps = installed_taps - tracked_taps
    print_report("brew taps", untracked_taps, tracked_taps - installed_taps)
    offer_add(yml, ("tap", "installed"), untracked_taps)

# ── Linux / WSL ────────────────────────────────────────────────────────────────
def check_linux(yml_name, label):
    yml = settings_dir / yml_name
    if not yml.exists():
        print(f"{yml_name} not found, skipping.")
        return

    # apt packages (manually installed only — excludes auto-installed deps)
    tracked_pkgs = load_yaml_list(yml, "packages", "installed")
    installed_pkgs = set(run(["apt-mark", "showmanual"]))
    untracked_pkgs = installed_pkgs - tracked_pkgs
    print_report(f"{label} apt packages", untracked_pkgs, tracked_pkgs - installed_pkgs)
    offer_add(yml, ("packages", "installed"), untracked_pkgs)

    # snaps
    tracked_snaps = load_yaml_list_field(yml, "snaps", "installed", field="name")
    snap_lines = run(["snap", "list"])
    installed_snaps = {line.split()[0] for line in snap_lines[1:] if line}  # skip header
    installed_snaps.discard("snapd")
    untracked_snaps = installed_snaps - tracked_snaps
    print_report(f"{label} snaps", untracked_snaps, tracked_snaps - installed_snaps)
    offer_add(yml, ("snaps", "installed"), untracked_snaps, snap=True)

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

python3 "$TMP_PY" "$SETTINGS_DIR"
