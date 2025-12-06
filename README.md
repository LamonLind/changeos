# changeos

A shell script to change the OS and version on cloud VPS instances (Azure, AWS, Google Cloud, Oracle Cloud) without losing network configuration, IP address, and home folder data.

## Features

- **Multi-Cloud Support**: Works with Azure VPS, AWS EC2, Google Cloud Compute Engine, and Oracle Cloud Infrastructure
- **Network Preservation**: Backs up and restores IP address, gateway, DNS, and routing configuration
- **Home Folder Protection**: Preserves all data in `/home/*` directories
- **SSH Key Preservation**: Maintains SSH host keys and user authorized_keys
- **User Account Preservation**: Backs up user accounts, groups, and sudo configurations
- **Automatic Cloud Detection**: Detects the cloud provider automatically
- **Dry-Run Mode**: Test the process without making any changes
- **Restoration Script**: Generates a restoration script for easy recovery

## Supported Operating Systems

### Source (Current) OS
- Ubuntu (18.04, 20.04, 22.04, 24.04)
- Debian (10, 11, 12)
- CentOS (8-stream, 9-stream)
- Rocky Linux (8, 9)
- AlmaLinux (8, 9)
- Fedora (38, 39, 40)

### Target (New) OS
- Ubuntu (18.04, 20.04, 22.04, 24.04)
- Debian (10, 11, 12)
- CentOS (8-stream, 9-stream)
- Rocky Linux (8, 9)
- AlmaLinux (8, 9)
- Fedora (38, 39, 40)

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

```bash
sudo ./changeos.sh [options]
```

### Options

| Option | Description |
|--------|-------------|
| `-t, --target-os` | Target OS (ubuntu, debian, centos, rocky, fedora, almalinux) |
| `-v, --version` | Target OS version (e.g., 22.04, 12, 9) |
| `-b, --backup-dir` | Directory to store backups (default: `/var/changeos-backup`) |
| `-d, --dry-run` | Perform a dry run without making changes |
| `-h, --help` | Show help message |

### Examples

```bash
# Change from current OS to Ubuntu 22.04
sudo ./changeos.sh -t ubuntu -v 22.04

# Change to Debian 12 with custom backup location
sudo ./changeos.sh -t debian -v 12 -b /mnt/backup

# Change to Rocky Linux 9 (dry-run mode)
sudo ./changeos.sh -t rocky -v 9 --dry-run

# Change to CentOS 9 Stream
sudo ./changeos.sh -t centos -v 9

# Change to AlmaLinux 9
sudo ./changeos.sh -t almalinux -v 9
```

## How It Works

### Phase 1: Backup (Automatic)
1. **Network Configuration**: Captures IP addresses, gateway, DNS settings, and routing tables
2. **Home Directories**: Creates compressed archives of all home directories
3. **SSH Configuration**: Backs up host keys, sshd_config, and user SSH keys
4. **User Accounts**: Preserves passwd, shadow, group files, and sudo configurations

### Phase 2: OS Change (Manual via Cloud Console)
1. Stop the VM in your cloud provider's console
2. Change the boot disk/image to the target OS
3. Start the VM

### Phase 3: Restoration (Semi-Automatic)
1. SSH into the new system
2. Run the restoration script: `sudo /var/changeos-backup/restore.sh`
3. Reboot to apply all changes

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

- **Dry-Run Mode**: Test without making changes using `-d` or `--dry-run`
- **Confirmation Prompt**: Requires explicit "yes" confirmation before OS change
- **Backup Verification**: Creates detailed report of all backed-up data
- **Restoration Script**: Automatically generated for easy recovery

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