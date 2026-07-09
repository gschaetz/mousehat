#!/usr/bin/env bash
set -euo pipefail

MOUSEHAT_DIR="$HOME/mousehat"
SETTINGS_DIR="$HOME/mousehat-settings"
GITHUB_API="https://api.github.com/repos/gschaetz/mousehat/releases/latest"
MOUSEHAT_REPO="https://github.com/gschaetz/mousehat.git"

###############################################################################
# Helpers
###############################################################################

info()    { printf '\033[0;34m==> %s\033[0m\n' "$*"; }
success() { printf '\033[0;32m✓ %s\033[0m\n' "$*"; }
warn()    { printf '\033[0;33m! %s\033[0m\n' "$*"; }
die()     { printf '\033[0;31mError: %s\033[0m\n' "$*" >&2; exit 1; }
ask()     { printf '\033[0;35m%s\033[0m ' "$*"; }

is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null
}

###############################################################################
# Step 1 — Prerequisites
###############################################################################

install_prereqs() {
    info "Checking prerequisites..."

    case "$OSTYPE" in
        darwin*)
            if ! command -v brew &>/dev/null; then
                info "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                # Add brew to PATH for Apple Silicon
                if [[ -f /opt/homebrew/bin/brew ]]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                fi
            fi

            for pkg in git ansible; do
                if ! command -v "$pkg" &>/dev/null; then
                    info "Installing $pkg..."
                    brew install "$pkg"
                fi
            done
            ;;

        linux*)
            if is_wsl; then
                info "Detected WSL environment"
            fi

            if ! sudo -n true 2>/dev/null; then
                warn "This script needs sudo access to install packages."
                sudo -v
            fi

            if ! command -v git &>/dev/null || ! command -v ansible &>/dev/null; then
                info "Installing git and ansible..."
                sudo apt-get update -qq
                sudo apt-get install -y git ansible
            fi
            ;;

        *)
            die "Unsupported OS: $OSTYPE"
            ;;
    esac

    # Verify Ansible version >= 2.7
    ANSIBLE_VERSION=$(ansible --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    ANSIBLE_MAJOR=$(echo "$ANSIBLE_VERSION" | cut -d. -f1)
    ANSIBLE_MINOR=$(echo "$ANSIBLE_VERSION" | cut -d. -f2)
    if [[ "$ANSIBLE_MAJOR" -lt 2 ]] || { [[ "$ANSIBLE_MAJOR" -eq 2 ]] && [[ "$ANSIBLE_MINOR" -lt 7 ]]; }; then
        die "Ansible 2.7+ is required (found $ANSIBLE_VERSION)"
    fi

    success "Prerequisites satisfied (Ansible $ANSIBLE_VERSION)"
}

###############################################################################
# Step 2 — Clone Mousehat at latest release
###############################################################################

clone_mousehat() {
    if [[ -d "$MOUSEHAT_DIR/.git" ]]; then
        info "Mousehat already present at $MOUSEHAT_DIR — skipping clone"
        return
    fi

    info "Finding latest Mousehat release..."
    LATEST=$(curl -fsSL "$GITHUB_API" 2>/dev/null | grep '"tag_name"' | cut -d'"' -f4)
    if [[ -z "$LATEST" ]]; then
        warn "Could not determine latest release — cloning main branch instead"
        LATEST="main"
        git clone --depth 1 "$MOUSEHAT_REPO" "$MOUSEHAT_DIR"
    else
        info "Cloning Mousehat $LATEST..."
        git clone --branch "$LATEST" --depth 1 "$MOUSEHAT_REPO" "$MOUSEHAT_DIR"
    fi

    success "Mousehat installed to $MOUSEHAT_DIR"
}

###############################################################################
# Step 3 — Settings directory
###############################################################################

setup_settings() {
    if [[ -d "$SETTINGS_DIR" ]]; then
        info "Settings directory already exists at $SETTINGS_DIR"
        return
    fi

    echo ""
    echo "Mousehat uses a settings directory — a folder of simple YAML files that"
    echo "list the apps and preferences you want on your machine."
    echo ""
    echo "How would you like to provide your settings?"
    echo "  1) I have a private git repo with my settings"
    echo "  2) Use the sample settings to get started (you can customise later)"
    echo ""
    ask "Enter 1 or 2:"
    read -r SETTINGS_CHOICE

    case "$SETTINGS_CHOICE" in
        1)
            clone_settings_repo
            ;;
        2)
            copy_sample_settings
            ;;
        *)
            warn "Unrecognised choice — using sample settings"
            copy_sample_settings
            ;;
    esac
}

clone_settings_repo() {
    echo ""
    ask "Settings repo URL (HTTPS, e.g. https://github.com/you/my-settings):"
    read -r REPO_URL

    echo ""
    echo "A Personal Access Token lets this script clone your private repository."
    echo "Create one at: https://github.com/settings/tokens (scope: repo)"
    echo "Or for GitLab: https://gitlab.com/-/user_settings/personal_access_tokens (scope: read_repository)"
    echo ""
    ask "Personal Access Token (leave blank if the repo is public):"
    read -rs PAT
    echo ""

    if [[ -n "$PAT" ]]; then
        # Embed token in URL: https://token@host/path
        AUTH_URL=$(echo "$REPO_URL" | sed "s|https://|https://$PAT@|")
    else
        AUTH_URL="$REPO_URL"
    fi

    info "Cloning settings repository..."
    git clone "$AUTH_URL" "$SETTINGS_DIR" || die "Failed to clone settings repo — check the URL and token"
    success "Settings cloned to $SETTINGS_DIR"
}

copy_sample_settings() {
    info "Copying sample settings to $SETTINGS_DIR..."
    cp -r "$MOUSEHAT_DIR/ansible/sample-desktop-setup" "$SETTINGS_DIR"
    success "Sample settings copied to $SETTINGS_DIR"
    echo ""
    echo "  Edit the YAML files in $SETTINGS_DIR to match your apps and preferences."
    echo "  Key files:"
    echo "    macos-brew.yml              — Homebrew taps, formulas, casks"
    echo "    macos-configure-os-settings.yml — Dock layout, macOS defaults"
    echo "    linux-packages.yml          — APT packages (Linux/WSL)"
    echo "    customroles.yml             — Custom roles for extra automation"
    echo ""
    ask "Press Enter to run Mousehat now (you can always re-run after editing)..."
    read -r _
}

###############################################################################
# Step 4 — Run Mousehat
###############################################################################

run_mousehat() {
    info "Running Mousehat..."
    cd "$MOUSEHAT_DIR"
    ./mh-apply.sh -s "$SETTINGS_DIR"
}

###############################################################################
# Step 5 — Next steps
###############################################################################

print_next_steps() {
    echo ""
    success "Mousehat setup complete!"
    echo ""
    echo "What's next:"
    echo "  • Edit your settings: $SETTINGS_DIR"
    echo "  • Re-apply anytime:   cd $MOUSEHAT_DIR && ./mh-apply.sh"
    echo "  • Check for drift:    cd $MOUSEHAT_DIR && ./mh-check.sh"
    echo "  • Docs:               https://mousehat.dev"
    echo ""
}

###############################################################################
# Main
###############################################################################

echo ""
echo "  Mousehat — automated machine setup"
echo "  https://mousehat.dev"
echo ""

install_prereqs
clone_mousehat
setup_settings
run_mousehat
print_next_steps
