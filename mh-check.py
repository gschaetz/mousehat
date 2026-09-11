#!/usr/bin/env python3
"""mh-check — show packages and macOS defaults installed but not tracked in your settings."""
import json
import os
import platform
import plistlib
import re
import subprocess
import sys
from pathlib import Path

HELP = """\
mh-check — show packages and macOS defaults installed but not tracked

Usage:
  mh-check [options]

Options:
  -h, --help  Show this help

Settings directory is read from $DESKTOP_SETTINGS_DIR or the path
saved by mh-apply on last run (~/.config/mousehat/settings_dir).

Checks:
  macOS  — brew formulae (brew leaves), casks, taps vs macos-brew.yml
         — osx_defaults vs macos-configure-os-settings.yml, using
           known-defaults.yml as the catalog of settings mh-check knows how
           to import — <SETTINGS_DIR>/known-defaults.yml if you have one,
           else the bundled ansible/macos-configure-os-settings/known-defaults.yml
  Linux  — apt packages, snaps vs linux-packages.yml
  WSL    — apt packages, snaps vs wsl-packages.yml

Output:
  + item      installed/set but not in config (you'll be asked to add it)
  - item      in config but not installed/set (will be applied on next mh-apply)
  ~ item      tracked value differs from the live system (you'll be asked to update it)

Examples:
  mh-check                             # check drift on current machine
  DESKTOP_SETTINGS_DIR=~/cfg mh-check  # use a specific settings directory
"""

REPO_ROOT = Path(__file__).resolve().parent
BUNDLED_CATALOG_YML = REPO_ROOT / "ansible" / "macos-configure-os-settings" / "known-defaults.yml"


def resolve_catalog_yml(settings_dir: Path) -> Path:
    """A settings-dir known-defaults.yml fully replaces the bundled catalog
    (no merging), mirroring how every other settings file in this project
    resolves against $DESKTOP_SETTINGS_DIR."""
    override = settings_dir / "known-defaults.yml"
    return override if override.exists() else BUNDLED_CATALOG_YML


def resolve_settings_dir() -> Path:
    settings_dir = os.environ.get("DESKTOP_SETTINGS_DIR")
    saved = Path.home() / ".config" / "mousehat" / "settings_dir"
    if not settings_dir and saved.is_file():
        settings_dir = saved.read_text().strip()
    if not settings_dir:
        print("Error: No settings directory found.")
        print("Run mousehat with -s first, or set DESKTOP_SETTINGS_DIR.")
        sys.exit(1)
    path = Path(settings_dir)
    if not path.is_dir():
        print(f"Error: Settings directory not found: {path}")
        sys.exit(1)
    return path


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
    print(f"\n  y adds the package to {yml.name} ({top_key}.{sub_key}); N/Enter skips it for now "
          "(it'll show up here again next run):")
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


def check_macos_packages(settings_dir):
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


# ── macOS osx_defaults ───────────────────────────────────────────────────────
_domain_cache = {}


def read_domain(domain):
    """Live values currently set for `domain`, as native Python types, via
    `defaults export` + plistlib (robust to type — unlike parsing `defaults
    read` text output). Memoized so each domain is exported once per run."""
    if domain not in _domain_cache:
        r = subprocess.run(["defaults", "export", domain, "-"], capture_output=True)
        try:
            _domain_cache[domain] = plistlib.loads(r.stdout) if r.stdout else {}
        except Exception:
            _domain_cache[domain] = {}
    return _domain_cache[domain]


def load_osx_defaults(path, query):
    """Flatten a domain -> key -> {type, value, state} hierarchy (loaded via
    `yq -o=json`) into a flat list of dicts with domain/key merged in."""
    out = subprocess.run(
        ["yq", "-o=json", query, str(path)],
        capture_output=True, text=True
    ).stdout
    data = json.loads(out) if out.strip() else {}
    if not isinstance(data, dict):
        return []
    return [
        {"domain": domain, "key": key, **settings}
        for domain, keys in data.items()
        for key, settings in keys.items()
    ]


MISSING = object()


def values_equal(type_, config_value, live_value):
    try:
        if type_ == "bool":
            return bool(config_value) == bool(live_value)
        if type_ == "int":
            return int(config_value) == int(live_value)
        if type_ == "float":
            return abs(float(config_value) - float(live_value)) < 1e-6
        if type_ == "array":
            return list(config_value) == list(live_value)
        if type_ == "dict":
            return dict(config_value) == dict(live_value)
        return str(config_value) == str(live_value)
    except (TypeError, ValueError):
        return False


def format_value(type_, value):
    if type_ == "bool":
        return "true" if value else "false"
    if type_ in ("int", "float"):
        return str(value)
    if type_ == "array":
        return "[" + ", ".join(f'"{v}"' for v in value) + "]"
    if type_ == "dict":
        # JSON object syntax is valid YAML flow-mapping syntax, and json.dumps
        # handles quoting/escaping for arbitrary keys/values (e.g. menu titles
        # with punctuation) far more safely than hand-rolled quoting would.
        return json.dumps(value)
    return f'"{value}"'


def yaml_insert_under_domain(path, top_key, domain, key, settings_dict):
    """Insert a new `key: {...}` line under an existing (or brand-new)
    `domain:` block beneath `top_key:`, touching only the affected lines."""
    lines = path.read_text().splitlines(keepends=True)

    top_idx = next(
        (i for i, l in enumerate(lines) if l.rstrip("\n") == f"{top_key}:" and indent_of(l) == 0),
        None,
    )
    if top_idx is None:
        raise ValueError(f"key '{top_key}:' not found")

    domain_idx = domain_indent = None
    top_key_end = len(lines)
    for i in range(top_idx + 1, len(lines)):
        stripped = lines[i].strip()
        ind = indent_of(lines[i])
        if stripped and not stripped.startswith("#") and ind == 0:
            top_key_end = i
            break
        if stripped == f"{domain}:":
            domain_idx, domain_indent = i, ind

    parts = []
    for k, v in settings_dict.items():
        if k == "value":
            parts.append(f"value: {format_value(settings_dict.get('type'), v)}")
        else:
            parts.append(f"{k}: {v}")
    settings_str = "{" + ", ".join(parts) + "}"

    if domain_idx is not None:
        item_indent = domain_indent + 4
        insert_idx = domain_idx + 1
        for i in range(domain_idx + 1, top_key_end):
            stripped = lines[i].strip()
            if not stripped:
                continue
            if indent_of(lines[i]) < item_indent:
                break
            insert_idx = i + 1
        pad = " " * item_indent
        lines[insert_idx:insert_idx] = [f"{pad}{key}: {settings_str}\n"]
    else:
        # No existing block for this domain — append a new one at the end
        # of the top_key section, matching the section's own indent.
        domain_indent = 4
        pad_domain = " " * domain_indent
        pad_key = " " * (domain_indent + 4)
        new_lines = [f"{pad_domain}{domain}:\n", f"{pad_key}{key}: {settings_str}\n"]
        lines[top_key_end:top_key_end] = new_lines

    path.write_text("".join(lines))


def yaml_update_domain_key(path, top_key, domain, key, type_, value):
    """Replace the `key: {...}` flow-mapping for an existing state:present
    entry under `domain:` beneath `top_key:`, leaving every other line
    untouched. Rebuilds the whole `{type, value, state}` mapping rather than
    regex-patching just the `value:` fragment, since a `dict`-typed value can
    itself contain `,`/`}` characters that a fragment-only substitution can't
    safely tell apart from the mapping's own delimiters."""
    lines = path.read_text().splitlines(keepends=True)

    top_idx = next(
        (i for i, l in enumerate(lines) if l.rstrip("\n") == f"{top_key}:" and indent_of(l) == 0),
        None,
    )
    if top_idx is None:
        raise ValueError(f"key '{top_key}:' not found")

    domain_idx = None
    top_key_end = len(lines)
    for i in range(top_idx + 1, len(lines)):
        stripped = lines[i].strip()
        ind = indent_of(lines[i])
        if stripped and not stripped.startswith("#") and ind == 0:
            top_key_end = i
            break
        if stripped == f"{domain}:":
            domain_idx = i

    if domain_idx is None:
        raise ValueError(f"domain '{domain}:' not found under '{top_key}:'")

    key_pattern = re.compile(r"^(\s*)" + re.escape(key) + r":\s*\{.*\}\s*$")
    for i in range(domain_idx + 1, top_key_end):
        m = key_pattern.match(lines[i].rstrip("\n"))
        if not m:
            continue
        indent = m.group(1)
        settings_str = f"{{type: {type_}, value: {format_value(type_, value)}, state: present}}"
        lines[i] = f"{indent}{key}: {settings_str}\n"
        path.write_text("".join(lines))
        return
    raise ValueError(f"key '{key}' not found under '{domain}:'")


def check_macos_defaults(settings_dir):
    yml = settings_dir / "macos-configure-os-settings.yml"
    if not yml.exists():
        print("macos-configure-os-settings.yml not found, skipping.")
        return
    catalog_yml = resolve_catalog_yml(settings_dir)
    if not catalog_yml.exists():
        print(f"{catalog_yml} not found, skipping known-settings import.")
        catalog = []
    else:
        catalog = load_osx_defaults(catalog_yml, ".")

    tracked = load_osx_defaults(yml, ".osx_defaults // {}")
    tracked_by_key = {(e["domain"], e["key"]): e for e in tracked}

    changed, not_applied, still_present = [], [], []
    for e in tracked:
        live = read_domain(e["domain"]).get(e["key"], MISSING)
        if e.get("state") == "present":
            if live is MISSING:
                not_applied.append(e)
            elif not values_equal(e.get("type"), e.get("value"), live):
                changed.append((e, live))
        elif e.get("state") == "absent":
            if live is not MISSING:
                still_present.append(e)

    new_known = []
    for c in catalog:
        if (c["domain"], c["key"]) in tracked_by_key:
            continue
        live = read_domain(c["domain"]).get(c["key"], MISSING)
        if live is not MISSING:
            new_known.append((c, live))

    print(f"\n── osx_defaults {'─' * 37}")
    if not (changed or not_applied or still_present or new_known):
        print("  All tracked settings match the live system.")

    if changed:
        print("  Changed (tracked value differs from live system):")
        for e, live in sorted(changed, key=lambda x: (x[0]["domain"], x[0]["key"])):
            print(f"    ~ {e['domain']}:{e['key']}  config={e.get('value')!r}  live={live!r}")
    if not_applied:
        print("  Not yet applied (tracked, not live — mh-apply will set it):")
        for e in sorted(not_applied, key=lambda x: (x["domain"], x["key"])):
            print(f"    - {e['domain']}:{e['key']}")
    if still_present:
        print("  Still present (state: absent in config, but still set live):")
        for e in sorted(still_present, key=lambda x: (x["domain"], x["key"])):
            print(f"    - {e['domain']}:{e['key']}")
    if new_known:
        print("  Known settings not tracked (found live, mousehat knows this one):")
        for c, live in sorted(new_known, key=lambda x: (x[0]["domain"], x[0]["key"])):
            print(f"    + {c['domain']}:{c['key']} = {live!r}")

    if changed:
        print(f"\n  y updates {yml.name} to the live value shown above; N/Enter leaves it tracked as-is:")
    for e, live in sorted(changed, key=lambda x: (x[0]["domain"], x[0]["key"])):
        if confirm(f"    Update '{e['domain']}:{e['key']}' in {yml.name} to match live value "
                   f"(config: {e.get('value')!r}, live: {live!r})?"):
            try:
                yaml_update_domain_key(yml, "osx_defaults", e["domain"], e["key"], e.get("type"), live)
                print(f"      updated {e['domain']}:{e['key']}")
            except ValueError as err:
                print(f"      failed to update {e['domain']}:{e['key']}: {err}")

    if new_known:
        print(f"\n  y tracks the setting in {yml.name} going forward; N/Enter skips it for now "
              "(it'll show up here again next run):")
    for c, live in sorted(new_known, key=lambda x: (x[0]["domain"], x[0]["key"])):
        if confirm(f"    Add '{c['domain']}:{c['key']}' = {live!r} to {yml.name} (osx_defaults)?"):
            try:
                yaml_insert_under_domain(
                    yml, "osx_defaults", c["domain"], c["key"],
                    {"type": c.get("type"), "value": live, "state": "present"},
                )
                print(f"      added {c['domain']}:{c['key']}")
            except ValueError as err:
                print(f"      failed to add {c['domain']}:{c['key']}: {err}")


def check_macos(settings_dir):
    check_macos_packages(settings_dir)
    check_macos_defaults(settings_dir)


# ── Linux / WSL ────────────────────────────────────────────────────────────────
def check_linux(settings_dir, yml_name, label):
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


def main():
    if len(sys.argv) > 1 and sys.argv[1] in ("-h", "--help"):
        print(HELP)
        return

    settings_dir = resolve_settings_dir()
    system = platform.system()
    is_wsl = "microsoft" in platform.uname().release.lower()

    if system == "Darwin":
        print(f"Checking macOS packages and defaults against: {settings_dir}")
        check_macos(settings_dir)
    elif is_wsl:
        print(f"Checking WSL packages against: {settings_dir}/wsl-packages.yml")
        check_linux(settings_dir, "wsl-packages.yml", "WSL")
    elif system == "Linux":
        print(f"Checking Linux packages against: {settings_dir}/linux-packages.yml")
        check_linux(settings_dir, "linux-packages.yml", "Linux")
    else:
        print(f"Unsupported platform: {system}")
        sys.exit(1)

    print()


if __name__ == "__main__":
    main()
