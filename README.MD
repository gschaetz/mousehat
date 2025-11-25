# Mousehat

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

3. For Apple Silicon Macs, install Rosetta 2:
   ```bash
   softwareupdate --install-rosetta
   ```

4. Configure passwordless sudo by editing `/etc/sudoers`:
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
   cd mousehat/ansible
   ```

2. Run the provisioning script:

   **Linux (non-WSL):**
   ```bash
   ./runplay.sh
   ```

   **WSL:**
   ```bash
   ./runplay.sh -w
   ```

   **With custom settings:**
   ```bash
   ./runplay.sh -s /path/to/custom/settings
   ```

3. Reboot to apply all changes:
   ```bash
   sudo reboot
   ```

## ⚙️ Configuration

### Command Line Options

The `runplay.sh` script accepts the following options:

| Option | Description | Example |
|--------|-------------|---------|
| `-w` | Enable WSL mode | `./runplay.sh -w` |
| `-s <path>` | Custom settings directory | `./runplay.sh -s ~/my-config` |
| `-d <path>` | Custom desktop directory location | `./runplay.sh -d ~/Desktop` |
| `-p <path>` | Custom project directory | `./runplay.sh -p ~/projects` |
| `-v <level>` | Ansible verbosity (v, vv, vvv, vvvv) | `./runplay.sh -v vvv` |

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
├── ansible/
│   ├── provdesktop.yml           # Main playbook
│   ├── runplay.sh                # Execution script
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
./runplay.sh
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
