# Mousehat

**[mousehat.dev](https://mousehat.dev)** — docs, getting started, and one-line install

An automated desktop provisioning system for Linux, macOS, and Windows WSL using Ansible. Mousehat automates the setup and configuration of your development environment, including package installation, desktop environment customization, and Docker-based application deployment.

## 🌟 Features

- **Multi-Platform Support**: Linux (Debian/Ubuntu/Arch), macOS, and Windows WSL 2
- **Desktop Environment Configuration**: GNOME and i3 desktop customization
- **Package Management**: Automated installation via apt, Homebrew, snap, and pacman
- **Docker Integration**: Deploy GUI and CLI applications in Docker containers
- **Customizable**: YAML-based configuration for easy personalization
- **Idempotent**: Safe to run multiple times

## 📋 Supported Platforms

| Platform | Versions | Desktop Environments |
|----------|----------|---------------------|
| **Linux** | Debian, Ubuntu, Arch Linux | GNOME 3, i3 |
| **macOS** | Mojave and later (Intel & Apple Silicon) | Native macOS |
| **Windows WSL** | WSL 2 (Ubuntu) | N/A |

## 🚀 Quick Start

### Prerequisites

#### Linux/WSL 2

1. Switch to root user:
   ```bash
   sudo su
   ```

2. Install required packages:
   ```bash
   apt-get update
   apt-get install -y sudo git ansible
   ```

3. Add your user to the sudo group:
   ```bash
   usermod -aG sudo <username>
   ```

4. Configure passwordless sudo by adding to `/etc/sudoers`:
   ```
   <username> ALL=(ALL) NOPASSWD: ALL
   ```

5. **Important**: Ensure Ansible version ≥ 2.7 for custom role support:
   ```bash
   ansible --version
   ```
   If needed, upgrade Ansible from official repositories.

#### macOS

1. Install Homebrew:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Install Ansible:
   ```bash
   brew install ansible
   ```

3. Configure passwordless sudo by editing `/etc/sudoers`:
   ```bash
   sudo visudo
   ```
   Add:
   ```
   <username> ALL=(ALL) NOPASSWD: ALL
   ```

#### VMware (Linux only)

For VMware virtual machines, install VMware Tools:
```bash
sudo apt-get install -y open-vm-tools open-vm-tools-desktop
sudo reboot
```

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/gschaetz/mousehat.git
   cd mousehat
   ```

2. Apply your configuration:

   **Linux (non-WSL):**
   ```bash
   ./mh-apply.sh
   ```

   **WSL:**
   ```bash
   ./mh-apply.sh -w
   ```

   **With custom settings:**
   ```bash
   ./mh-apply.sh -s /path/to/custom/settings
   ```

3. Reboot to apply all changes:
   ```bash
   sudo reboot
   ```

## ⚙️ Configuration

### Command Line Options

The `mh-apply.sh` script accepts the following options:

| Option | Description | Example |
|--------|-------------|---------|
| `-w` | Enable WSL mode | `./mh-apply.sh -w` |
| `-s <path>` | Custom settings directory | `./mh-apply.sh -s ~/my-config` |
| `-d <path>` | Custom desktop directory location | `./mh-apply.sh -d ~/Desktop` |
| `-p <path>` | Custom project directory | `./mh-apply.sh -p ~/projects` |
| `-v <level>` | Ansible verbosity (v, vv, vvv, vvvv) | `./mh-apply.sh -v vvv` |
| `-r <role>` | Run a specific role only | `./mh-apply.sh -r macos-homebrew` |
| `-K` | Prompt for sudo password | `./mh-apply.sh -K` |

### Running a Specific Role

Use the `-r` flag to run a single role instead of the full playbook:

```bash
./mh-apply.sh -r macos-homebrew
./mh-apply.sh -r macos-configure-os-settings
./mh-apply.sh -r docker-applications
./mh-apply.sh -r custom-roles
```

Available roles:

| Role | Platform |
|------|----------|
| `linux-packages` | Linux (including WSL) |
| `linux-install-docker` | Linux (non-WSL) |
| `linux-gnome-desktop-settings` | Linux (non-WSL) |
| `macos-homebrew` | macOS |
| `macos-configure-os-settings` | macOS |
| `docker-applications` | macOS, WSL, Linux (non-WSL) |
| `custom-roles` | All platforms |

### Checking for Untracked Packages

`mh-check.sh` compares your system's installed packages against your settings config and reports any drift — packages installed but not tracked, or tracked but not installed.

```bash
./mh-check.sh
```

The settings directory is remembered automatically after the first `mh-apply.sh -s` run. On macOS it checks brew formulae, casks, and taps. On Linux/WSL it checks apt (manually installed) and snap.

### Using Sample Configurations

The project includes sample configurations in `ansible/sample-desktop-setup/`. You can:

1. Use the provided samples as-is
2. Copy and modify them for your needs
3. Create your own from scratch

See [ansible/sample-desktop-setup/README.md](ansible/sample-desktop-setup/README.md) for configuration details.

## 📚 Documentation

- [Ansible Roles Documentation](ansible/README.md) - Detailed explanation of all roles and playbooks
- [Sample Configuration Guide](ansible/sample-desktop-setup/README.md) - How to customize your setup

## 🔧 Project Structure

```
mousehat/
├── mh-apply.sh                   # Apply configuration to the machine
├── mh-check.sh                   # Check for untracked/missing packages
├── ansible/
│   ├── provdesktop.yml           # Main playbook
│   ├── custom-roles/             # Custom Ansible roles
│   ├── docker-applications/      # Docker app deployment role
│   ├── linux-gnome-desktop-settings/  # GNOME configuration role
│   ├── linux-install-docker/     # Docker installation role
│   ├── linux-packages/           # Linux package management role
│   ├── macos-configure-os-settings/   # macOS settings role
│   ├── macos-homebrew/           # Homebrew management role
│   ├── wsl-packages/             # WSL-specific packages role
│   ├── sample-desktop-setup/     # Sample configurations
│   └── templates/                # Jinja2 templates
```

## 🐛 Troubleshooting

### Common Issues

**Ansible version too old:**
```bash
sudo apt-get update
sudo apt-get upgrade ansible
```

**First run fails on repository setup:**
This is expected when using the sample settings. Simply re-run the script:
```bash
./mh-apply.sh
```

**Custom role errors:**
Upgrade Ansible to version ≥ 2.7:
```bash
sudo apt-get upgrade ansible
# or on macOS
brew upgrade ansible
```

## 🛠️ Built With

- [Ansible](https://www.ansible.com/) - Automation framework
- [Docker](https://www.docker.com/) - Container platform
- [Homebrew](https://brew.sh/) - macOS package manager

## 📄 License

This project is licensed under the MIT License - see the [LICENSE.MD](LICENSE.MD) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## ✨ Acknowledgments

- Built with Ansible automation
- Inspired by the need for reproducible development environments
