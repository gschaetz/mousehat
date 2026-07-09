#!/bin/bash
verbosity="v"
WSL_LINUX="FALSE"
ASK_BECOME_PASS=""
ROLE_TAGS=""
FORCE=false

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'HELP'
mh-apply — apply your Mousehat settings to this machine

Usage:
  mh-apply [options]

Options:
  -s <path>   Path to your settings directory (saved after first use)
  -f          Force a full run even if settings are unchanged
  -r <role>   Run only a specific role (by tag)
  -w          Enable WSL mode
  -K          Prompt for sudo password (ansible --ask-become-pass)
  -p <path>   Override desktop project directory
  -d <path>   Override home desktop directory
  -v <level>  Ansible verbosity level (default: v)
  -h, --help  Show this help

Examples:
  mh-apply -s ~/my-settings    # first run, set settings directory
  mh-apply                     # subsequent runs, uses saved settings
  mh-apply -f                  # force full run even if nothing changed
  mh-apply -r macos-brew       # run only the macos-brew role
HELP
  exit 0
fi

while getopts ":p:s:d:v:r:wKf" opt; do
  case $opt in
    K)
      ASK_BECOME_PASS="--ask-become-pass"
      ;;
    w)
      echo "Setting wsl setup to true."
      WSL_LINUX="TRUE"
      ;;
    v)
      echo "verbosity being set to: $OPTARG"
      verbosity="$OPTARG"
      ;;
    p)
      echo "Using desktop directory: $OPTARG"
      export DESKTOP_PROJECT_DIR=$OPTARG
      ;;
    s)
      echo "Using desktop setting directory: $OPTARG"
      export DESKTOP_SETTINGS_DIR=$OPTARG
      ;;
    d)
      echo "Desktop location for .desktop: $OPTARG"
      export HOME_DESKTOP_DIR=$OPTARG
      ;;
    r)
      echo "Running only role: $OPTARG"
      ROLE_TAGS="--tags $OPTARG"
      ;;
    f)
      FORCE=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo $WSL_LINUX
      if [[ $OPTARG == "w" ]]; then
        continue
      else
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
      fi
      ;;
  esac
done

# Ensure git and ansible are present, installing them if this is a fresh machine
if [[ "$OSTYPE" == "darwin"* ]]; then
  if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  fi

  for pkg in git ansible; do
    if ! command -v "$pkg" &>/dev/null; then
      echo "Installing $pkg..."
      brew install "$pkg"
    fi
  done
elif [[ "$OSTYPE" == "linux"* ]]; then
  if ! command -v git &>/dev/null || ! command -v ansible &>/dev/null; then
    echo "Installing git and ansible..."
    sudo apt-get update -qq
    sudo apt-get install -y git ansible
  fi
fi

ANSIBLE_VERSION=$(ansible --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
ANSIBLE_MAJOR=$(echo "$ANSIBLE_VERSION" | cut -d. -f1)
ANSIBLE_MINOR=$(echo "$ANSIBLE_VERSION" | cut -d. -f2)
if [[ -z "$ANSIBLE_MAJOR" ]] || [[ "$ANSIBLE_MAJOR" -lt 2 ]] || { [[ "$ANSIBLE_MAJOR" -eq 2 ]] && [[ "$ANSIBLE_MINOR" -lt 7 ]]; }; then
  echo "Error: Ansible 2.7+ is required (found ${ANSIBLE_VERSION:-none})" >&2
  exit 1
fi

# Resolve the real script location, following symlinks — mh-apply is normally
# invoked via the /usr/local/bin symlink from an arbitrary directory, so
# ${BASH_SOURCE[0]} alone would point at /usr/local/bin, not this repo.
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_SOURCE" ]; do
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
  SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
  [[ "$SCRIPT_SOURCE" != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"

# Symlink all mh-* scripts into /usr/local/bin so they're available anywhere
for script in "$SCRIPT_DIR"/mh-*.sh; do
  cmd="/usr/local/bin/$(basename "${script%.sh}")"
  if [ ! -L "$cmd" ] || [ "$(readlink "$cmd")" != "$script" ]; then
    sudo ln -sf "$script" "$cmd"
    echo "Linked $(basename "$cmd") → $cmd"
  fi
done

# Fall back to previously saved settings dir if -s was not provided
if [ -z "$DESKTOP_SETTINGS_DIR" ] && [ -f ~/.config/mousehat/settings_dir ]; then
  export DESKTOP_SETTINGS_DIR="$(cat ~/.config/mousehat/settings_dir)"
  echo "Using saved settings directory: $DESKTOP_SETTINGS_DIR"
fi

# Persist settings dir for future runs
if [ -n "$DESKTOP_SETTINGS_DIR" ]; then
  mkdir -p ~/.config/mousehat
  echo "$DESKTOP_SETTINGS_DIR" > ~/.config/mousehat/settings_dir
fi

# No settings dir at all — require -s on first run
if [ -z "$DESKTOP_SETTINGS_DIR" ]; then
  echo "Error: No settings directory found. Use -s on first run to set it." >&2
  echo "  ./mh-apply.sh -s /path/to/settings" >&2
  exit 1
fi

# Skip if settings haven't changed since last successful run
CHECKSUM_FILE=~/.config/mousehat/settings.md5
if [[ "$OSTYPE" == "darwin"* ]]; then
  CURRENT_MD5=$(find "$DESKTOP_SETTINGS_DIR" \( -name "*.yml" -o -name "*.yaml" \) | sort | xargs md5 -q | md5 -q)
else
  CURRENT_MD5=$(find "$DESKTOP_SETTINGS_DIR" \( -name "*.yml" -o -name "*.yaml" \) | sort | xargs md5sum | md5sum | cut -d' ' -f1)
fi

if [[ "$FORCE" != "true" ]] && [ -f "$CHECKSUM_FILE" ] && [ "$CURRENT_MD5" = "$(cat $CHECKSUM_FILE)" ]; then
  echo "Settings unchanged since last run. Use -f to force."
  exit 0
fi

# Run from the mousehat repo dir so the relative playbook path below, and
# Ansible's own $PWD-based project_home lookup, resolve correctly no matter
# where mh-apply was invoked from.
cd "$SCRIPT_DIR" || exit 1

ansible-playbook $ASK_BECOME_PASS -$verbosity -i "localhost," -c local ansible/provdesktop.yml --extra-vars "WSL_LINUX=$WSL_LINUX" $ROLE_TAGS

if [ $? -eq 0 ]; then
  echo "$CURRENT_MD5" > "$CHECKSUM_FILE"
fi
