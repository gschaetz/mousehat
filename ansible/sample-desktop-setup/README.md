# Sample Desktop Setup Configurations

This directory contains sample configuration files for Mousehat. These files define what packages, applications, and settings will be installed and configured on your system.

## Overview

Each YAML file corresponds to a specific Ansible role and defines the configuration for that role. You can use these sample files as-is, modify them, or create your own custom configurations.

## Configuration Files

### Linux Configuration Files

#### `linux-packages.yml`

Manages system packages on Linux (Debian/Ubuntu/Arch) systems.

**Structure**:
```yaml
repositories:           # APT repositories to add
  <repo_name>:
    repository_url: <ppa_url or deb line>
    url: <gpg key url>           # Optional
    keyserver_url: <keyserver>   # Optional
    keyserver_id: <key_id>       # Optional

snaps:                 # Snap packages
  installed:
    - name: <package>
      classic: <true|false>
  uninstalled:
    - name: <package>
      classic: <true|false>

packages:              # APT/Pacman packages
  installed:
    - <package1>
    - <package2>
  uninstalled:
    - <package3>
```

**Example**:
```yaml
repositories:
  microsoft:
    url: https://packages.microsoft.com/keys/microsoft.asc
    repository_url: deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main

snaps:
  installed:
    - name: code
      classic: true
    - name: slack
      classic: false

packages:
  installed:
    - curl
    - git
    - vim
    - docker-compose
    - awscli
  uninstalled:
    - nano
```

#### `linux-gnome-settings.yml`

Configures GNOME desktop environment settings.

**Structure**:
```yaml
gnome_extensions:      # GNOME Shell extensions
  <extension_name>:
    download_type: <archive|git>
    extension_name: <full_extension_id>
    extension_url: <download_url>

gnome:                 # Gnome settings (dconf)
  <setting_name>:
    setting: <dconf_path> <value>

gnome_background:      # Desktop/screensaver backgrounds
  <background_name>:
    type: <background|screensaver>
    background_url: <image_url>

x11_config:            # X11 configuration
  user_x11_config_files: <true|false>
```

**Example**:
```yaml
gnome_extensions:
  dashtodock:
    download_type: archive
    extension_name: dash-to-dock@micxgx.gmail.com
    extension_url: https://extensions.gnome.org/extension-data/...

gnome:
  dock_position:
    setting: /org/gnome/shell/extensions/dash-to-dock/dock-position "'BOTTOM'"
  favorite_apps:
    setting: /org/gnome/shell/favorite-apps '["firefox.desktop", "code.desktop"]'
  touchpad:
    setting: /org/gnome/desktop/peripherals/touchpad/tap-to-click true

gnome_background:
  desktop_background:
    type: background
    background_url: https://example.com/wallpaper.jpg

x11_config:
  user_x11_config_files: false
```

**Common dconf Settings**:
- `/org/gnome/shell/favorite-apps` - Pinned applications
- `/org/gnome/desktop/background/show-desktop-icons` - Show desktop icons
- `/org/gnome/shell/enabled-extensions` - Enabled extensions list
- `/org/gnome/desktop/wm/preferences/button-layout` - Window button layout
- `/org/gnome/desktop/peripherals/touchpad/tap-to-click` - Touchpad tap

#### `linux-docker-applications.yml`

Defines Docker-based applications for Linux (non-WSL).

**Structure**:
```yaml
applications:
  <app_name>:
    implementation_type: <docker|docker_compose>
    
    # For docker type:
    docker_image: <image:tag>
    docker_ports: <port_mappings>
    docker_volumes: <volume_mounts>
    docker_network: <network_mode>
    gui_app: <true|false>
    
    # For docker_compose type:
    compose_version: <version_string>
    compose_network: <network_name>
    compose_definition: <compose_yaml>
    
    # Optional for both:
    container_home: <path>
    app_persistent_dir: <container_path>
    app_persistent_download_dir: <container_path>
    show_on_desktop: <true|false>
    menu_category: <category>
    desktop_name: <name>
    desktop_icon: <filename.png>
    desktop_icon_download_url: <url>
    extra_docker_flags: <flags>
    docker_sec_comp: <true|false>
    docker_sec_comp_download_url: <url>
    docker_entrypoint: <entrypoint>
    docker_entrypoint_command: <command>
```

**Example**:
```yaml
applications:
  firefox:
    implementation_type: docker
    docker_image: jess/firefox:latest
    docker_volumes: -v /:/host_drive
    docker_network: host
    gui_app: true
    app_persistent_dir: /home/user
    app_persistent_download_dir: /home/user/Downloads
    show_on_desktop: true
    menu_category: Network
    desktop_icon_download_url: https://upload.wikimedia.org/wikipedia/commons/a/a0/Firefox_logo.png
    extra_docker_flags: --cpus 2

  wordpress:
    implementation_type: docker_compose
    gui_app: false
    compose_version: "version: '3'"
    compose_network: wordpress-net
    compose_definition:
      services:
        db:
          image: mysql:5.7
          volumes:
            - db_data:/var/lib/mysql
          environment:
            MYSQL_ROOT_PASSWORD: wordpress
            MYSQL_DATABASE: wordpress
        wordpress:
          depends_on:
            - db
          image: wordpress:latest
          ports:
            - "8080:80"
          environment:
            WORDPRESS_DB_HOST: db:3306
            WORDPRESS_DB_PASSWORD: wordpress
```

**Application Categories** (for `menu_category`):
- AudioVideo
- Development
- Education
- Game
- Graphics
- Network
- Office
- Settings
- System
- Utility

#### `wsl-packages.yml`

Manages packages specifically for WSL environments.

**Structure**: Same as `linux-packages.yml`

**Note**: Typically includes lighter packages suitable for WSL without GUI components.

### macOS Configuration Files

#### `macos-brew.yml`

Manages Homebrew taps, formulas, and casks.

**Structure**:
```yaml
tap:
  installed:
    - <tap_name>
  not_installed:
    - <tap_name>

brew:
  installed:
    - <formula_name>
  not_installed:
    - <formula_name>

brew_cask:
  installed:
    - <cask_name>
  not_installed:
    - <cask_name>
```

**Example**:
```yaml
tap:
  installed:
    - homebrew/cask-fonts
    - homebrew/cask-versions

brew:
  installed:
    - dockutil      # Required for dock management
    - socat         # Required for GUI Docker apps
    - git
    - node
    - python
    - ansible

brew_cask:
  installed:
    - visual-studio-code
    - docker
    - firefox
    - google-chrome
    - slack
    - 1password
```

**Important Brews**:
- `dockutil` - **Required** for dock configuration
- `socat` - **Required** for GUI Docker applications

#### `macos-configure-os-settings.yml`

Configures macOS system settings and Dock.

**Structure**:
```yaml
dock:
  persistent_apps:
    - name: <app_name>
      path: <app_path>
      pos: <position>
      type: <app|folder>
      # For folders:
      folder_style: <grid|fan|list|auto>
      folder_sort: <name|dateadded|datemodified|datecreated|kind>
  
  other_apps:
    - name: <app_name>
      path: <app_path>
      pos: <position>
      type: <app|folder>

osx_defaults:
  - domain: <domain>
    key: <key>
    type: <string|bool|int|float|array|dict>
    value: <value>
    state: <present|absent>
```

**Example**:
```yaml
dock:
  persistent_apps:
    - name: Safari
      path: "/Applications/Safari.app"
      pos: 1
      type: app
    
    - name: Downloads
      path: "~/Downloads"
      pos: 10
      type: folder
      folder_style: grid
      folder_sort: dateadded

osx_defaults:
  # Enable autohide for dock
  - domain: com.apple.dock
    key: autohide
    type: bool
    value: true
    state: present
  
  # Show all file extensions
  - domain: NSGlobalDomain
    key: AppleShowAllExtensions
    type: bool
    value: true
    state: present
  
  # Disable natural scrolling
  - domain: NSGlobalDomain
    key: com.apple.swipescrolldirection
    type: bool
    value: false
    state: present
```

**Common osx_defaults**:

| Setting | Domain | Key | Type | Description |
|---------|--------|-----|------|-------------|
| Dock autohide | com.apple.dock | autohide | bool | Auto-hide dock |
| Dock position | com.apple.dock | orientation | string | left/bottom/right |
| Show extensions | NSGlobalDomain | AppleShowAllExtensions | bool | Show file extensions |
| Natural scroll | NSGlobalDomain | com.apple.swipescrolldirection | bool | Natural scrolling |
| Key repeat rate | NSGlobalDomain | KeyRepeat | int | Key repeat speed |
| Expand save panel | NSGlobalDomain | NSNavPanelExpandedStateForSaveMode | bool | Expanded save dialog |

### Cross-Platform Configuration Files

#### `docker-applications.yml`

General Docker applications (works on both Linux and macOS).

**Structure**: Same as `linux-docker-applications.yml`

**Note**: 
- macOS GUI apps require `socat` installed via Homebrew
- Linux-specific features (desktop icons, menu entries) won't work on macOS

#### `customroles.yml`

Defines custom Ansible roles to execute.

**Structure**:
```yaml
custom_roles:
  - name: <role_name>
    enabled: <true|false>
```

**Example**:
```yaml
custom_roles:
  - name: my-custom-setup
    enabled: true
  - name: experimental-role
    enabled: false
```

## Creating Custom Configurations

### Method 1: Copy and Modify Samples

1. Copy the entire `sample-desktop-setup` directory:
   ```bash
   cp -r ansible/sample-desktop-setup ~/my-config
   ```

2. Modify the YAML files in `~/my-config/`

3. Run with custom settings:
   ```bash
   cd ansible
   ./runplay.sh -s ~/my-config
   ```

### Method 2: Create from Scratch

1. Create a new directory:
   ```bash
   mkdir ~/my-config
   ```

2. Create only the configuration files you need:
   - For Linux: `linux-packages.yml`, `linux-gnome-settings.yml`, `docker-applications.yml`
   - For macOS: `macos-brew.yml`, `macos-configure-os-settings.yml`, `docker-applications.yml`
   - For WSL: `wsl-packages.yml`

3. Run with your settings:
   ```bash
   cd ansible
   ./runplay.sh -s ~/my-config
   ```

### Method 3: Minimal Configuration

You can create configurations with only the sections you need:

**Minimal `linux-packages.yml`**:
```yaml
---
packages:
  installed:
    - git
    - vim
    - curl
```

**Minimal `macos-brew.yml`**:
```yaml
---
brew:
  installed:
    - git
    - vim
```

## Tips and Best Practices

### General Tips

1. **Start Small**: Begin with sample configurations and gradually customize
2. **Comments**: Add comments to remember why you made specific choices
3. **Version Control**: Keep your custom configurations in git
4. **Test First**: Test configurations in a VM before applying to your main system

### Package Management

1. **Essential First**: Install essential packages before optional ones
2. **Repository Order**: Add repositories before packages that depend on them
3. **Remove Carefully**: Be cautious when removing packages (check dependencies)

### Docker Applications

1. **Persistent Data**: Always specify `app_persistent_dir` for apps that save data
2. **Port Conflicts**: Check for port conflicts between applications
3. **Resource Limits**: Use `extra_docker_flags` to limit CPU/memory for resource-intensive apps
4. **Network Mode**: Use `bridge` network for isolated apps, `host` for simplicity

### Desktop Settings

1. **Backup First**: Backup existing settings before applying new ones
2. **Extensions**: Test GNOME extensions individually
3. **Icons**: Use high-quality PNG icons (at least 256x256)
4. **Paths**: Use absolute paths for reliability

### macOS Specific

1. **Dock Apps**: Verify application paths exist before adding to dock
2. **Defaults**: Test `osx_defaults` values manually first using `defaults write`
3. **Restart Required**: Many macOS settings require logout/restart
4. **Rosetta**: Don't forget Rosetta for Apple Silicon Macs

## Environment Variables

You can override default locations using environment variables:

```bash
export DESKTOP_SETTINGS_DIR=~/my-config
export HOME_DESKTOP_DIR=~/Documents
export DESKTOP_PROJECT_DIR=~/projects/mousehat
./runplay.sh
```

Or use command-line flags:

```bash
./runplay.sh -s ~/my-config -d ~/Documents -p ~/projects/mousehat
```

## Troubleshooting

### Configuration Not Loading

- Check YAML syntax: `ansible-playbook --syntax-check provdesktop.yml`
- Verify file paths are correct
- Ensure files have `.yml` extension

### Package Installation Fails

- Check repository URLs are accessible
- Verify package names are correct for your OS version
- Check available disk space

### Docker Application Issues

- Verify Docker is installed and running
- Check image names are correct
- Ensure ports are not already in use
- For GUI apps on Linux, verify X11 is configured

### GNOME Settings Not Applied

- Verify dconf paths are correct for your GNOME version
- Check extension URLs are still valid
- Ensure GNOME Shell is restarted after changes

## Example Configurations

### Minimal Developer Setup (Linux)

```yaml
# linux-packages.yml
packages:
  installed:
    - git
    - vim
    - docker.io
    - docker-compose
    - curl
    - build-essential
```

### Complete macOS Developer Setup

```yaml
# macos-brew.yml
tap:
  installed:
    - homebrew/cask-fonts

brew:
  installed:
    - dockutil
    - git
    - node
    - python
    - docker
    - kubectl

brew_cask:
  installed:
    - visual-studio-code
    - docker
    - iterm2
    - google-chrome
```

### Docker-Heavy Configuration

```yaml
# docker-applications.yml
applications:
  postgres:
    implementation_type: docker
    docker_image: postgres:14
    docker_ports: -p 5432:5432
    docker_volumes: -v postgres-data:/var/lib/postgresql/data
    gui_app: false
    
  vscode-server:
    implementation_type: docker
    docker_image: codercom/code-server:latest
    docker_ports: -p 8080:8080
    gui_app: false
    app_persistent_dir: /home/coder
```

## See Also

- [Ansible Roles Documentation](../README.md)
- [Main README](../../README.MD)
