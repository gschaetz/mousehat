# Ansible Playbooks and Roles

This directory contains the Ansible automation code for Mousehat, including the main playbook, roles, and templates.

## Overview

The provisioning system uses a single main playbook (`provdesktop.yml`) that conditionally includes different roles based on the target operating system and configuration.

## Main Playbook

### `provdesktop.yml`

The main orchestration playbook that:
- Detects the operating system (Linux, macOS, WSL)
- Loads configuration from YAML files
- Executes appropriate roles for the platform
- Manages desktop applications and settings

### Variables

The playbook uses several environment variables that can be overridden:

| Variable | Default | Description |
|----------|---------|-------------|
| `HOME_DESKTOP_DIR` | `$HOME` | Location for .desktop directory |
| `DESKTOP_PROJECT_DIR` | Current directory | Project root path |
| `DESKTOP_SETTINGS_DIR` | `sample-desktop-setup/` | Configuration files location |

## Roles

### `linux-packages`

**Purpose**: Install and manage system packages on Linux systems (non-WSL)

**Platforms**: Debian/Ubuntu, Arch Linux

**Configuration File**: `linux-packages.yml`

**Features**:
- APT repository management (keys, URLs)
- Package installation/removal via apt
- Pacman package management for Arch
- Snap package support

**Example Configuration**:
```yaml
repositories:
  ansible:
    repository_url: ppa:ansible/ansible
packages:
  installed:
    - curl
    - git
    - vim
  uninstalled:
    - nano
snaps:
  installed:
    - name: code
      classic: true
```

### `wsl-packages`

**Purpose**: Install packages specifically for Windows WSL environments

**Platforms**: WSL 2 (Ubuntu)

**Configuration File**: `wsl-packages.yml`

**Features**:
- WSL-optimized package installation
- Handles WSL-specific requirements

### `linux-install-docker`

**Purpose**: Install and configure Docker on Linux systems

**Platforms**: Linux (non-WSL)

**Features**:
- Docker Engine installation
- Docker Compose setup
- User permissions configuration
- Service enablement

**Variables**:
- `non_root_user`: User to add to docker group

### `linux-gnome-desktop-settings`

**Purpose**: Configure GNOME desktop environment

**Platforms**: Linux with GNOME 3

**Configuration File**: `linux-gnome-settings.yml`

**Features**:
- GNOME Shell extension installation
- dconf/gsettings configuration
- Wallpaper and screensaver setup
- X11 configuration (.xinit, .xsession)
- Startup script creation

**Example Configuration**:
```yaml
gnome_extensions:
  dash-to-dock:
    extension_name: dash-to-dock@micxgx.gmail.com
    extension_url: https://github.com/micheleg/dash-to-dock/archive/master.zip
    download_type: archive

gnome:
  favorite-apps:
    setting: /org/gnome/shell/favorite-apps "['firefox.desktop', 'org.gnome.Terminal.desktop']"

gnome_background:
  desktop:
    type: background
    background_url: https://example.com/wallpaper.jpg
```

### `macos-homebrew`

**Purpose**: Manage Homebrew packages, taps, and casks

**Platforms**: macOS

**Configuration File**: `macos-brew.yml`

**Features**:
- Homebrew tap management
- Brew formula installation/removal
- Cask application management
- Automatic Homebrew updates

**Example Configuration**:
```yaml
tap:
  installed:
    - homebrew/cask-fonts
  not_installed: []

brew:
  installed:
    - git
    - ansible
    - node
  not_installed: []

brew_cask:
  installed:
    - visual-studio-code
    - docker
    - firefox
  not_installed: []
```

### `macos-configure-os-settings`

**Purpose**: Configure macOS system settings and Dock

**Platforms**: macOS

**Configuration File**: `macos-configure-os-settings.yml`

**Features**:
- Dock configuration (apps, folders, position)
- macOS defaults (plist settings)
- Application arrangement

**Example Configuration**:
```yaml
dock:
  persistent_apps:
    - name: Firefox
      path: /Applications/Firefox.app
      type: app
    - name: Downloads
      path: ~/Downloads
      type: folder
      folder_style: grid
      folder_sort: dateadded

osx_defaults:
  - domain: com.apple.dock
    key: autohide
    type: bool
    value: true
    state: present
  - domain: NSGlobalDomain
    key: AppleShowAllExtensions
    type: bool
    value: true
    state: present
```

### `docker-applications`

**Purpose**: Deploy Docker-based applications with desktop integration

**Platforms**: Linux (non-WSL), macOS (partial)

**Configuration File**: `docker-applications.yml`

**Features**:
- Docker and Docker Compose application deployment
- Desktop shortcut creation (Linux)
- Application menu integration (Linux)
- Persistent data directory management
- GUI application support (X11 forwarding)
- Security profile support (seccomp)

**Implementation Types**:
- `docker`: Single container applications
- `docker_compose`: Multi-container applications

**Example Configuration**:
```yaml
applications:
  firefox:
    implementation_type: docker
    docker_image: jess/firefox:latest
    docker_ports: ""
    docker_volumes: -v /:/host_drive
    docker_network: host
    gui_app: true
    app_persistent_dir: /home/user
    app_persistent_download_dir: /home/user/Downloads
    show_on_desktop: true
    menu_category: Network
    desktop_icon_download_url: https://example.com/firefox.png

  wordpress_compose:
    implementation_type: docker_compose
    gui_app: false
    compose_version: "version: '3'"
    compose_definition:
      services:
        db:
          image: mysql:5.7
          environment:
            MYSQL_ROOT_PASSWORD: password
```

**Docker Application Parameters**:

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `implementation_type` | Yes | - | `docker` or `docker_compose` |
| `docker_image` | Yes* | - | Docker image name |
| `docker_ports` | No | "" | Port mappings (-p format) |
| `docker_volumes` | No | "" | Volume mounts (-v format) |
| `gui_app` | No | true | Whether app has GUI |
| `docker_network` | No | host | Docker network mode |
| `container_home` | No | /home/user | Container home directory |
| `app_persistent_dir` | No | - | Directory to persist |
| `show_on_desktop` | No | false | Create desktop shortcut |
| `menu_category` | No | - | Application menu category |
| `desktop_icon_download_url` | No | - | Icon URL for desktop |
| `extra_docker_flags` | No | "" | Additional docker flags |
| `docker_sec_comp` | No | false | Use seccomp profile |

*Required for docker type, not for docker_compose

### `custom-roles`

**Purpose**: Execute user-defined custom Ansible tasks

**Configuration File**: `customroles.yml`

**Features**:
- Extensibility point for custom automation
- User-specific configuration tasks

## Templates

The `templates/` directory contains Jinja2 templates used by roles:

| Template | Purpose |
|----------|---------|
| `app-dockercompose.j2` | Docker Compose file generation |
| `app-start-docker.j2` | Docker application startup script (Linux) |
| `app-start-docker-macos.j2` | Docker application startup script (macOS) |
| `gnome-desktop-template.j2` | .desktop file for application shortcuts |
| `gnome-start-entry.j2` | GNOME autostart entry |
| `start-script-gnome.j2` | GNOME startup script |
| `xinit.j2` | X11 initialization file |
| `20-intel.j2` | Intel graphics X11 config |
| `90-touchpad.j2` | Touchpad X11 config |

## Running the Playbook

### Basic Usage

```bash
./runplay.sh
```

### With Custom Settings

```bash
./runplay.sh -s /path/to/settings
```

### WSL Mode

```bash
./runplay.sh -w
```

### Verbose Output

```bash
./runplay.sh -v vvv
```

### Combined Options

```bash
./runplay.sh -s ~/my-config -w -v vv
```

## Execution Flow

1. **Platform Detection**: Determines OS (Linux/macOS/WSL)
2. **Package Management**: Installs system packages
3. **Docker Setup**: Configures Docker (Linux non-WSL only)
4. **Desktop Configuration**: Applies desktop settings (Linux GNOME/i3 or macOS)
5. **Application Deployment**: Deploys Docker applications
6. **Custom Roles**: Executes user-defined tasks

## Conditional Execution

Roles execute based on conditions:

```yaml
when: ansible_system == 'Linux' and WSL_LINUX == 'FALSE'  # Linux non-WSL
when: ansible_system == 'Linux' and WSL_LINUX == 'TRUE'   # WSL only
when: ansible_system == 'Darwin'                           # macOS
```

## Directory Structure

```
ansible/
├── provdesktop.yml              # Main playbook
├── runplay.sh                   # Execution script
├── .gitignore
├── custom-roles/                # User custom roles
│   └── tasks/
│       └── main.yml
├── docker-applications/         # Docker app deployment
│   └── tasks/
│       └── main.yml
├── linux-gnome-desktop-settings/
│   └── tasks/
│       └── main.yml
├── linux-install-docker/
│   └── tasks/
│       └── main.yml
├── linux-packages/
│   └── tasks/
│       └── main.yml
├── macos-configure-os-settings/
│   └── tasks/
│       └── main.yml
├── macos-homebrew/
│   └── tasks/
│       └── main.yml
├── wsl-packages/
│   └── tasks/
│       └── main.yml
├── sample-desktop-setup/        # Sample configurations
│   └── *.yml
└── templates/                   # Jinja2 templates
    └── *.j2
```

## Troubleshooting

### Ansible Version Issues

Ensure Ansible ≥ 2.7:
```bash
ansible --version
```

### Permission Errors

Verify passwordless sudo is configured:
```bash
sudo visudo
```

Add: `<username> ALL=(ALL) NOPASSWD: ALL`

### Docker Permission Denied

Ensure user is in docker group:
```bash
sudo usermod -aG docker $USER
```
Then logout and login again.

### Desktop Icons Not Appearing (Linux)

Run after reboot:
```bash
gio set ~/Desktop/*.desktop "metadata::trusted" yes
```

## Advanced Customization

### Creating Custom Roles

1. Create role directory: `ansible/my-custom-role/tasks/`
2. Add `main.yml` with tasks
3. Reference in `customroles.yml`:
```yaml
custom_roles:
  - name: my-custom-role
    enabled: true
```

### Extending Existing Roles

1. Copy sample configuration from `sample-desktop-setup/`
2. Modify YAML files for your needs
3. Run with `-s` flag pointing to your config directory

## See Also

- [Sample Configuration Guide](sample-desktop-setup/README.md)
- [Main README](../README.MD)
