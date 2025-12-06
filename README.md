# changeos

A shell script to change the OS and version on cloud VPS instances (Azure, AWS, Google Cloud, Oracle Cloud) without losing network configuration, IP address, and home folder data.

## Features

- **Interactive Menu**: Easy-to-use menu system for selecting OS and version
- **Multi-Cloud Support**: Works with Azure VPS, AWS EC2, Google Cloud Compute Engine, and Oracle Cloud Infrastructure
- **Network Preservation**: Backs up and restores IP address, gateway, DNS, and routing configuration
- **Home Folder Protection**: Preserves all data in `/home/*` directories
- **SSH Key Preservation**: Maintains SSH host keys and user authorized_keys
- **User Account Preservation**: Backs up user accounts, groups, and sudo configurations
- **Automatic Cloud Detection**: Detects the cloud provider automatically
- **Automatic Restoration**: Sets up automatic restoration after OS change
- **Restoration Script**: Generates a restoration script for easy recovery

## Supported Operating Systems

### Target OS Options
- **Debian** (10, 11, 12)
- **Ubuntu** (18.04, 20.04, 22.04, 24.04)
- **AlmaLinux** (8, 9)
- **Rocky Linux** (8, 9)
- **CentOS** (8-stream, 9-stream)
- **Fedora** (38, 39, 40)
- **Kali Linux** (rolling, 2024.1, 2023.4)

## Requirements

- Root/sudo access
- `curl` and `wget` installed
- Sufficient disk space for backups (typically 2x the size of `/home`)
- Active internet connection

## Installation

```bash
# Clone the repository
git clone https://github.com/LamonLind/changeos.git
cd changeos

# Make the script executable
chmod +x changeos.sh
```

## Usage

Simply run the script and follow the interactive menus:

```bash
sudo ./changeos.sh
```

### Interactive Menu Flow

1. **Select OS**: Choose from available operating systems
```
=============================================
       Change OS - Select Operating System
=============================================

Select OS:

  1. Debian
  2. Ubuntu
  3. AlmaLinux
  4. Rocky Linux
  5. CentOS
  6. Fedora
  7. Kali Linux

  0. Exit

Enter your choice [1-7]:
```

2. **Select Version**: Choose the version for your selected OS
```
=============================================
       Change OS - Select Version
=============================================

Selected OS: ubuntu

Select version:

  1. Ubuntu 24.04 LTS (Noble Numbat)
  2. Ubuntu 22.04 LTS (Jammy Jellyfish)
  3. Ubuntu 20.04 LTS (Focal Fossa)
  4. Ubuntu 18.04 LTS (Bionic Beaver)

  0. Go back

Enter your choice [1-4]:
```

3. **Confirm Selection**: Review and confirm your choice
4. **Backup**: Script automatically backs up your data
5. **Next Steps**: Follow instructions to complete OS change via cloud console

## How It Works

### Phase 1: Backup (Automatic)
1. **Network Configuration**: Captures IP addresses, gateway, DNS settings, and routing tables
2. **Home Directories**: Creates compressed archives of all home directories
3. **SSH Configuration**: Backs up host keys, sshd_config, and user SSH keys
4. **User Accounts**: Preserves passwd, shadow, group files, and sudo configurations

### Phase 2: OS Change (Via Cloud Console)
1. Stop the VM in your cloud provider's console
2. Change the boot disk/image to the target OS
3. Start the VM

### Phase 3: Restoration (Automatic)
Restoration runs automatically after OS change, or you can run manually:
```bash
sudo /var/changeos-backup/restore.sh
```

## Backup Structure

```
/var/changeos-backup/
├── network/
│   ├── ip_addr.txt           # IP address configuration
│   ├── ip_route.txt          # IPv4 routing table
│   ├── ip6_route.txt         # IPv6 routing table
│   ├── network.conf          # Primary interface and gateway
│   ├── resolv.conf           # DNS configuration
│   └── netplan/              # Netplan configurations (if applicable)
├── home/
│   ├── user1.tar.gz          # User home directory archives
│   ├── user2.tar.gz
│   └── root.tar.gz           # Root home directory
├── ssh/
│   ├── ssh_host_*            # SSH host keys
│   ├── sshd_config           # SSH daemon configuration
│   └── users/                # Per-user SSH configurations
├── users/
│   ├── passwd                # User accounts
│   ├── shadow                # Password hashes
│   ├── group                 # Group definitions
│   └── sudoers               # Sudo configuration
├── restore.sh                # Restoration script
├── install_auto_restore.sh   # Auto-restore service installer
├── install_cloud_agents.sh   # Cloud agent installer
└── changeos_report.txt       # Backup summary report
```

## Cloud Provider Specific Notes

### Azure
- The script backs up Azure Linux Agent (waagent) configurations
- After restoration, run: `sudo ./install_cloud_agents.sh azure`

### AWS
- Cloud-init configurations are preserved
- EC2 metadata service is used for provider detection

### Google Cloud
- Google Compute Engine agent configurations are backed up
- After restoration, run: `sudo ./install_cloud_agents.sh gcp`

### Oracle Cloud
- OCI hostname configurations are preserved
- Cloud-init is used for initial configuration

## Safety Features

- **Confirmation Prompt**: Requires explicit "yes" confirmation before OS change
- **Backup Verification**: Creates detailed report of all backed-up data
- **Restoration Script**: Automatically generated for easy recovery
- **Automatic Restoration**: Sets up systemd service for automatic restoration

## Troubleshooting

### Network not working after restoration
```bash
# Re-apply network configuration
sudo /var/changeos-backup/restore.sh

# Or manually configure
source /var/changeos-backup/network/network.conf
sudo ip addr add $IP_ADDRESS dev $PRIMARY_INTERFACE
sudo ip route add default via $GATEWAY
```

### SSH keys not recognized
```bash
# Restore SSH configuration
sudo cp /var/changeos-backup/ssh/ssh_host_* /etc/ssh/
sudo chmod 600 /etc/ssh/ssh_host_*_key
sudo systemctl restart sshd
```

### User cannot log in
```bash
# Check if user exists
grep username /var/changeos-backup/users/passwd

# Recreate user if needed
sudo useradd -m username
sudo cp -r /var/changeos-backup/ssh/users/username/.ssh /home/username/
sudo chown -R username:username /home/username/.ssh
```

### Automatic restoration didn't run
```bash
# Install the auto-restore service manually
sudo /var/changeos-backup/install_auto_restore.sh

# Or run restoration directly
sudo /var/changeos-backup/restore.sh
```

## Limitations

- **In-place OS change is not fully automatic**: The actual disk image change must be done through the cloud provider's console
- **Stateful applications**: Services like databases may require additional backup/restore procedures
- **Custom system configurations**: Modifications outside of /home may need manual restoration
- **Firewall rules**: Cloud provider firewall rules are preserved, but iptables/firewalld rules need separate backup

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is open source and available under the [MIT License](LICENSE).

## Disclaimer

**USE AT YOUR OWN RISK.** Always test in a non-production environment first. The authors are not responsible for any data loss or system damage that may occur from using this script. Always maintain separate backups of critical data.