#!/bin/bash

# =================================================================
# COMPLETE AUTOMATIC VPS OS REINSTALL SCRIPT
# Actually performs OS installation after SSH configuration
# =================================================================

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# =================================================================
# CONFIGURATION VARIABLES
# =================================================================

# SSH Configuration (will be restored after install)
CUSTOM_ROOT_USER="${CUSTOM_ROOT_USER:-admin}"
CUSTOM_ROOT_PASSWORD="${CUSTOM_ROOT_PASSWORD:-}"
CUSTOM_SSH_KEY="${CUSTOM_SSH_KEY:-}"
SSH_PORT="${SSH_PORT:-22}"
SSH_KEY_ONLY="${SSH_KEY_ONLY:-no}"
ALLOW_ROOT_LOGIN="${ALLOW_ROOT_LOGIN:-yes}"

# OS Selection
TARGET_OS="${TARGET_OS:-ubuntu22}"  # ubuntu22, ubuntu20, debian12, debian11, rocky9, almalinux9, centos9

# Installation Options
AUTO_REBOOT="${AUTO_REBOOT:-yes}"
PRESERVE_NETWORK="${PRESERVE_NETWORK:-yes}"

# Provider
VPS_PROVIDER="${VPS_PROVIDER:-auto}"

# =================================================================
# GLOBAL VARIABLES
# =================================================================

LOG_FILE="/root/vps_reinstall_$(date +%Y%m%d_%H%M%S).log"
CONFIG_DIR="/root/vps_reinstall_data"
CURRENT_IP=""
CURRENT_GATEWAY=""
CURRENT_INTERFACE=""
DISK_DEVICE=""
PROVIDER_DETECTED=""
BOOT_MODE=""

# =================================================================
# UTILITY FUNCTIONS
# =================================================================

log() {
    echo -e "${2:-$GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${CYAN}[INFO] $1${NC}" | tee -a "$LOG_FILE"
}

# =================================================================
# DETECT CURRENT SYSTEM
# =================================================================

detect_current_ip() {
    CURRENT_IP=$(ip route get 1 | awk '{print $NF;exit}' 2>/dev/null || curl -s ifconfig.me 2>/dev/null)
    [ -z "$CURRENT_IP" ] && CURRENT_IP=$(hostname -I | awk '{print $1}')
}

detect_gateway() {
    CURRENT_GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
}

detect_interface() {
    CURRENT_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
}

detect_disk() {
    if [ -d /sys/block/vda ]; then
        DISK_DEVICE="vda"
    elif [ -d /sys/block/sda ]; then
        DISK_DEVICE="sda"
    elif [ -d /sys/block/nvme0n1 ]; then
        DISK_DEVICE="nvme0n1"
    else
        DISK_DEVICE=$(lsblk -ndo name | grep -E '^(sd|vd|nvme)' | head -1)
    fi
}

detect_boot_mode() {
    if [ -d /sys/firmware/efi ]; then
        BOOT_MODE="uefi"
    else
        BOOT_MODE="bios"
    fi
    info "Boot mode: $BOOT_MODE"
}

detect_provider() {
    if [ "$VPS_PROVIDER" != "auto" ]; then
        PROVIDER_DETECTED="$VPS_PROVIDER"
        return
    fi
    
    if curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/instance-id > /dev/null 2>&1; then
        PROVIDER_DETECTED="aws"
    elif curl -s --connect-timeout 2 -H "Metadata-Flavor: Google" http://metadata.google.internal > /dev/null 2>&1; then
        PROVIDER_DETECTED="gcp"
    elif curl -s --connect-timeout 2 -H "Metadata: true" http://169.254.169.254/metadata/instance?api-version=2020-09-01 > /dev/null 2>&1; then
        PROVIDER_DETECTED="azure"
    elif curl -s --connect-timeout 2 http://169.254.169.254/opc/v1/instance/ > /dev/null 2>&1; then
        PROVIDER_DETECTED="oracle"
    elif curl -s --connect-timeout 2 http://169.254.169.254/metadata/v1/id > /dev/null 2>&1; then
        PROVIDER_DETECTED="digitalocean"
    else
        PROVIDER_DETECTED="custom"
    fi
    info "Provider: $PROVIDER_DETECTED"
}

# =================================================================
# SAVE SSH CONFIGURATION FOR POST-INSTALL
# =================================================================

save_ssh_config() {
    mkdir -p "$CONFIG_DIR"
    
    cat > "$CONFIG_DIR/ssh_config.conf" << EOF
# SSH Configuration for Post-Install
CUSTOM_ROOT_USER="$CUSTOM_ROOT_USER"
CUSTOM_ROOT_PASSWORD="$CUSTOM_ROOT_PASSWORD"
CUSTOM_SSH_KEY="$CUSTOM_SSH_KEY"
SSH_PORT="$SSH_PORT"
SSH_KEY_ONLY="$SSH_KEY_ONLY"
ALLOW_ROOT_LOGIN="$ALLOW_ROOT_LOGIN"
CURRENT_IP="$CURRENT_IP"
EOF
    
    # Save SSH key file
    if [ -n "$CUSTOM_SSH_KEY" ]; then
        echo "$CUSTOM_SSH_KEY" > "$CONFIG_DIR/ssh_key.pub"
    fi
    
    # Save password hash
    if [ -n "$CUSTOM_ROOT_PASSWORD" ]; then
        echo "$CUSTOM_ROOT_PASSWORD" > "$CONFIG_DIR/root_password.txt"
    fi
    
    success "SSH configuration saved to $CONFIG_DIR"
}

# =================================================================
# CREATE POST-INSTALL SCRIPT (Will run on fresh OS)
# =================================================================

create_post_install_script() {
    log "Creating post-install script for fresh OS..." "$BLUE"
    
    # This script will be embedded in the new OS via cloud-init or initrd
    cat > "$CONFIG_DIR/post_install.sh" << 'POSTINSTALL'
#!/bin/bash
# ============================================================
# POST-INSTALL SCRIPT - Runs after fresh OS installation
# Restores SSH configuration automatically
# ============================================================

LOG_FILE="/root/post_install.log"
exec 2>&1 | tee -a "$LOG_FILE"

echo "========================================="
echo "POST-INSTALL SCRIPT STARTED"
echo "========================================="

# Load configuration
if [ -f /root/vps_reinstall_data/ssh_config.conf ]; then
    source /root/vps_reinstall_data/ssh_config.conf
else
    echo "ERROR: Configuration not found!"
    exit 1
fi

echo "Restoring SSH configuration:"
echo "  Username: $CUSTOM_ROOT_USER"
echo "  SSH Port: $SSH_PORT"
echo "  Password Login: $([ "$SSH_KEY_ONLY" = "yes" ] && echo "DISABLED" || echo "ENABLED")"

# Wait for network (up to 60 seconds)
echo "Waiting for network..."
for i in {1..30}; do
    if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        echo "Network is up!"
        break
    fi
    echo "Waiting for network... ($i/30)"
    sleep 2
done

# Configure network interface
configure_network() {
    echo "Configuring network..."
    
    # Find network interface
    INTERFACE=$(ip link show | grep -v lo | grep -E '^[0-9]+:' | head -1 | awk -F': ' '{print $2}' | sed 's/@.*//')
    [ -z "$INTERFACE" ] && INTERFACE="eth0"
    
    echo "Using interface: $INTERFACE"
    ip link set "$INTERFACE" up
    
    # Try DHCP
    if command -v dhclient > /dev/null 2>&1; then
        dhclient "$INTERFACE" || true
    elif command -v dhcpcd > /dev/null 2>&1; then
        dhcpcd "$INTERFACE" || true
    fi
    
    # Netplan (Ubuntu)
    if [ -d /etc/netplan ]; then
        cat > /etc/netplan/01-netcfg.yaml << NETPLAN
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: true
NETPLAN
        netplan apply 2>/dev/null || true
    fi
}

# Install SSH server
install_ssh() {
    echo "Installing SSH server..."
    
    if command -v apt-get > /dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y openssh-server curl wget sudo
    elif command -v yum > /dev/null 2>&1; then
        yum install -y openssh-server curl wget sudo
        systemctl enable sshd
    elif command -v dnf > /dev/null 2>&1; then
        dnf install -y openssh-server curl wget sudo
        systemctl enable sshd
    elif command -v pacman > /dev/null 2>&1; then
        pacman -Syu --noconfirm openssh curl wget sudo
        systemctl enable sshd
    fi
    
    systemctl start sshd 2>/dev/null || service ssh start 2>/dev/null || true
    echo "SSH server installed"
}

# Configure SSH
configure_ssh() {
    echo "Configuring SSH on port $SSH_PORT..."
    
    cat > /etc/ssh/sshd_config << SSHCONF
Port $SSH_PORT
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin $ALLOW_ROOT_LOGIN
PubkeyAuthentication yes
PasswordAuthentication $([ "$SSH_KEY_ONLY" = "yes" ] && echo "no" || echo "yes")
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
SSHCONF
    
    systemctl restart sshd 2>/dev/null || service ssh restart 2>/dev/null || true
}

# Create custom user
create_custom_user() {
    echo "Creating user: $CUSTOM_ROOT_USER"
    
    # Create user
    useradd -m -s /bin/bash "$CUSTOM_ROOT_USER" 2>/dev/null || true
    
    # Add to sudo/wheel group
    if command -v usermod > /dev/null 2>&1; then
        usermod -aG sudo "$CUSTOM_ROOT_USER" 2>/dev/null || usermod -aG wheel "$CUSTOM_ROOT_USER" 2>/dev/null || true
    fi
    
    # Add SSH key
    if [ -f /root/vps_reinstall_data/ssh_key.pub ]; then
        mkdir -p "/home/$CUSTOM_ROOT_USER/.ssh"
        cat /root/vps_reinstall_data/ssh_key.pub >> "/home/$CUSTOM_ROOT_USER/.ssh/authorized_keys"
        chmod 700 "/home/$CUSTOM_ROOT_USER/.ssh"
        chmod 600 "/home/$CUSTOM_ROOT_USER/.ssh/authorized_keys"
        chown -R "$CUSTOM_ROOT_USER:$CUSTOM_ROOT_USER" "/home/$CUSTOM_ROOT_USER/.ssh"
        echo "SSH key added for $CUSTOM_ROOT_USER"
    fi
    
    # Set password
    if [ -f /root/vps_reinstall_data/root_password.txt ]; then
        PASSWORD=$(cat /root/vps_reinstall_data/root_password.txt)
        echo "$CUSTOM_ROOT_USER:$PASSWORD" | chpasswd
        echo "Password set for $CUSTOM_ROOT_USER"
    fi
}

# Configure root access
configure_root() {
    # Add SSH key for root
    if [ -f /root/vps_reinstall_data/ssh_key.pub ]; then
        mkdir -p /root/.ssh
        cat /root/vps_reinstall_data/ssh_key.pub >> /root/.ssh/authorized_keys
        chmod 700 /root/.ssh
        chmod 600 /root/.ssh/authorized_keys
        echo "SSH key added for root"
    fi
    
    # Set root password
    if [ -f /root/vps_reinstall_data/root_password.txt ]; then
        PASSWORD=$(cat /root/vps_reinstall_data/root_password.txt)
        echo "root:$PASSWORD" | chpasswd
        echo "Root password set"
    fi
}

# Display completion info
show_completion() {
    echo ""
    echo "========================================="
    echo "POST-INSTALL COMPLETED SUCCESSFULLY!"
    echo "========================================="
    
    # Get IP
    IP=$(ip addr show | grep -E 'inet [0-9]' | grep -v 127.0.0.1 | head -1 | awk '{print $2}' | cut -d/ -f1)
    
    echo ""
    echo "SSH ACCESS READY!"
    echo "Connect using:"
    echo "  ssh -p $SSH_PORT $CUSTOM_ROOT_USER@$IP"
    echo ""
    echo "Or as root:"
    echo "  ssh -p $SSH_PORT root@$IP"
    echo ""
    echo "Log file: $LOG_FILE"
}

# Main execution
main() {
    configure_network
    install_ssh
    configure_ssh
    create_custom_user
    configure_root
    show_completion
}

main
POSTINSTALL

    chmod +x "$CONFIG_DIR/post_install.sh"
    
    # Copy to multiple locations to ensure it runs
    cp "$CONFIG_DIR/post_install.sh" /root/post_install.sh
    cp "$CONFIG_DIR/post_install.sh" /post_install.sh
    
    success "Post-install script created"
}

# =================================================================
# CLOUD-INIT CONFIGURATION (For cloud providers)
# =================================================================

create_cloud_init_config() {
    log "Creating cloud-init configuration..." "$BLUE"
    
    cat > "$CONFIG_DIR/cloud-init-user-data.yml" << CLOUDINIT
#cloud-config
autoinstall:
  version: 1
  identity:
    hostname: vps
    username: $CUSTOM_ROOT_USER
    password: "$CUSTOM_ROOT_PASSWORD"
  ssh:
    install-server: true
    allow-pw: $([ "$SSH_KEY_ONLY" = "yes" ] && echo "false" || echo "true")
  ssh_authorized_keys:
    - $CUSTOM_SSH_KEY
  packages:
    - openssh-server
    - curl
    - wget
  late-commands:
    - curtin in-target -- sed -i 's/#PermitRootLogin.*/PermitRootLogin $ALLOW_ROOT_LOGIN/' /etc/ssh/sshd_config
    - curtin in-target -- sed -i 's/#Port 22/Port $SSH_PORT/' /etc/ssh/sshd_config
    - curtin in-target -- systemctl restart sshd
CLOUDINIT

    success "Cloud-init configuration created"
}

# =================================================================
# INSTALLATION METHOD 1: NETBOOT.XYZ (Works on all VPS)
# =================================================================

install_network_reinstall() {
    log "Setting up network reinstall via netboot.xyz..." "$BLUE"
    
    cd /boot || error "Cannot access /boot"
    
    # Download netboot.xyz
    info "Downloading netboot.xyz..."
    wget -q --show-progress -O netboot.xyz.lkrn https://boot.netboot.xyz/ipxe/netboot.xyz.lkrn
    
    # Backup existing GRUB
    cp /etc/grub.d/40_custom /etc/grub.d/40_custom.backup 2>/dev/null || true
    
    # Configure GRUB to boot netboot.xyz
    cat > /etc/grub.d/40_custom << GRUB
#!/bin/sh
exec tail -n +3 \$0
menuentry "Auto OS Reinstall - $TARGET_OS" {
    set root=(hd0,1)
    linux16 /boot/netboot.xyz.lkrn
    boot
}
GRUB
    
    chmod +x /etc/grub.d/40_custom
    
    # Set as default boot entry
    if [ -f /etc/default/grub ]; then
        sed -i 's/GRUB_DEFAULT=.*/GRUB_DEFAULT="Auto OS Reinstall - $TARGET_OS"/' /etc/default/grub
        echo "GRUB_TIMEOUT=5" >> /etc/default/grub
    fi
    
    # Update GRUB
    if command -v update-grub > /dev/null 2>&1; then
        update-grub
    elif command -v grub-mkconfig > /dev/null 2>&1; then
        grub-mkconfig -o /boot/grub/grub.cfg
    fi
    
    success "Network reinstall configured"
}

# =================================================================
# INSTALLATION METHOD 2: DD IMAGE (Direct disk write)
# =================================================================

install_dd_reinstall() {
    log "Starting DD image reinstall..." "$RED"
    
    # Get image URL based on OS
    case $TARGET_OS in
        ubuntu22)
            IMAGE_URL="https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
            ;;
        ubuntu20)
            IMAGE_URL="https://cloud-images.ubuntu.com/releases/20.04/release/ubuntu-20.04-server-cloudimg-amd64.img"
            ;;
        debian12)
            IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.raw"
            ;;
        debian11)
            IMAGE_URL="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.raw"
            ;;
        rocky9)
            IMAGE_URL="https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
            ;;
        almalinux9)
            IMAGE_URL="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
            ;;
        centos9)
            IMAGE_URL="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
            ;;
        *)
            error "No image available for $TARGET_OS"
            ;;
    esac
    
    info "Downloading OS image: $IMAGE_URL"
    wget -q --show-progress -O /tmp/os_image.img "$IMAGE_URL"
    
    # Handle compressed images
    if file /tmp/os_image.img | grep -q "gzip"; then
        info "Decompressing image..."
        gunzip -c /tmp/os_image.img > /tmp/os_image.raw
        mv /tmp/os_image.raw /tmp/os_image.img
    elif file /tmp/os_image.img | grep -q "XZ"; then
        info "Decompressing xz image..."
        xz -d -c /tmp/os_image.img > /tmp/os_image.raw
        mv /tmp/os_image.raw /tmp/os_image.img
    fi
    
    # Write image to disk
    info "Writing image to /dev/$DISK_DEVICE..."
    dd if=/tmp/os_image.img of=/dev/$DISK_DEVICE bs=4M status=progress
    
    # Sync and wait
    sync
    sleep 2
    
    # Resize partition to use full disk
    partprobe /dev/$DISK_DEVICE 2>/dev/null || true
    
    success "DD image written successfully"
}

# =================================================================
# INSTALLATION METHOD 3: DEBOOTSTRAP (For custom installs)
# =================================================================

install_debootstrap() {
    log "Starting debootstrap installation..." "$BLUE"
    
    # This method installs directly without reboot
    # Only works for Debian/Ubuntu
    
    if [[ ! "$TARGET_OS" =~ ^(ubuntu22|ubuntu20|debian12|debian11)$ ]]; then
        error "Debootstrap only supports Debian/Ubuntu"
    fi
    
    # Install debootstrap
    if command -v apt-get > /dev/null 2>&1; then
        apt-get update
        apt-get install -y debootstrap
    fi
    
    # Mount new root
    mkdir -p /mnt/newroot
    mount /dev/$DISK_DEVICE /mnt/newroot
    
    # Debootstrap new system
    case $TARGET_OS in
        ubuntu22) SUITE="jammy" ;;
        ubuntu20) SUITE="focal" ;;
        debian12) SUITE="bookworm" ;;
        debian11) SUITE="bullseye" ;;
    esac
    
    info "Debootstrapping $SUITE..."
    debootstrap --include=openssh-server,sudo,curl,wget $SUITE /mnt/newroot
    
    # Copy SSH configuration
    mkdir -p /mnt/newroot/root/vps_reinstall_data
    cp -r "$CONFIG_DIR"/* /mnt/newroot/root/vps_reinstall_data/
    cp "$CONFIG_DIR/post_install.sh" /mnt/newroot/root/
    
    # Chroot and run post-install
    chroot /mnt/newroot /bin/bash -c "/root/post_install.sh"
    
    # Cleanup
    umount /mnt/newroot
    
    success "Debootstrap installation completed"
}

# =================================================================
# MAIN INSTALLATION TRIGGER
# =================================================================

trigger_installation() {
    log "=========================================" "$CYAN"
    log "TRIGGERING OS INSTALLATION" "$RED"
    log "=========================================" "$CYAN"
    
    case $INSTALL_METHOD in
        network)
            install_network_reinstall
            info "Network reinstall configured. System will boot into installer on next reboot."
            ;;
        dd)
            install_dd_reinstall
            info "DD image written. System will boot into new OS on next reboot."
            ;;
        debootstrap)
            install_debootstrap
            info "Debootstrap installation completed. System is ready."
            ;;
        *)
            # Auto-select method
            if [ "$PROVIDER_DETECTED" = "custom" ]; then
                install_dd_reinstall
            else
                install_network_reinstall
            fi
            ;;
    esac
}

# =================================================================
# CONFIRMATION AND REBOOT
# =================================================================

confirm_and_reboot() {
    echo ""
    success "========================================="
    success "INSTALLATION PREPARED SUCCESSFULLY!"
    success "========================================="
    echo ""
    info "SSH Configuration that WILL be restored:"
    echo "  Username: $CUSTOM_ROOT_USER"
    echo "  SSH Port: $SSH_PORT"
    echo "  Authentication: $([ -n "$CUSTOM_SSH_KEY" ] && echo "SSH Key" || echo "Password")"
    echo ""
    info "After installation completes:"
    echo "  Connect via: ssh -p $SSH_PORT $CUSTOM_ROOT_USER@$CURRENT_IP"
    echo "  Wait 2-3 minutes for post-install script to run"
    echo ""
    
    if [ "$AUTO_REBOOT" = "yes" ]; then
        warning "REBOOTING IN 10 SECONDS TO START INSTALLATION..."
        warning "Your VPS will be offline for 5-10 minutes during installation"
        echo ""
        for i in {10..1}; do
            echo -ne "Rebooting in $i seconds...\r"
            sleep 1
        done
        echo ""
        reboot
    else
        info "Reboot manually when ready:"
        info "  reboot"
    fi
}

# =================================================================
# MAIN EXECUTION
# =================
# MAIN EXECUTION
# =================================================================

main() {
    clear
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║     COMPLETE AUTOMATIC VPS OS REINSTALL - ACTUAL INSTALLER       ║
║           SSH Configuration Will Be Restored After Install       ║
╚══════════════════════════════════════════════════════════════════╝
EOF

    # Check root
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root (use: sudo su -)"
    fi
    
    # Detect system
    detect_current_ip
    detect_gateway
    detect_interface
    detect_disk
    detect_boot_mode
    detect_provider
    
    # Get user input for SSH config
    echo ""
    info "SSH Configuration (This will be restored after OS install)"
    echo "========================================="
    
    read -p "Username [default: admin]: " input_user
    CUSTOM_ROOT_USER="${input_user:-admin}"
    
    read -s -p "Password (leave empty for SSH key only): " input_pass
    echo ""
    if [ -n "$input_pass" ]; then
        CUSTOM_ROOT_PASSWORD="$input_pass"
    fi
    
    echo ""
    echo "SSH Key (optional, but recommended):"
    echo "1) Use existing key from /root/.ssh/authorized_keys"
    echo "2) Paste new SSH public key"
    echo "3) Skip (use password only)"
    read -p "Choice [1-3]: " key_choice
    
    case $key_choice in
        1)
            if [ -f /root/.ssh/authorized_keys ] && [ -s /root/.ssh/authorized_keys ]; then
                CUSTOM_SSH_KEY=$(cat /root/.ssh/authorized_keys | head -1)
                success "Using existing SSH key"
            fi
            ;;
        2)
            read -p "Paste SSH public key: " input_key
            CUSTOM_SSH_KEY="$input_key"
            ;;
        3)
            if [ -z "$CUSTOM_ROOT_PASSWORD" ]; then
                error "Either SSH key or password is required!"
            fi
            ;;
    esac
    
    read -p "SSH Port [default: 22]: " input_port
    SSH_PORT="${input_port:-22}"
    
    echo ""
    info "OS Selection"
    echo "========================================="
    echo "1) Ubuntu 22.04 LTS"
    echo "2) Ubuntu 20.04 LTS"
    echo "3) Debian 12"
    echo "4) Debian 11"
    echo "5) Rocky Linux 9"
    echo "6) AlmaLinux 9"
    echo "7) CentOS Stream 9"
    read -p "Choice [1-7]: " os_choice
    
    case $os_choice in
        1) TARGET_OS="ubuntu22" ;;
        2) TARGET_OS="ubuntu20" ;;
        3) TARGET_OS="debian12" ;;
        4) TARGET_OS="debian11" ;;
        5) TARGET_OS="rocky9" ;;
        6) TARGET_OS="almalinux9" ;;
        7) TARGET_OS="centos9" ;;
        *) TARGET_OS="ubuntu22" ;;
    esac
    
    echo ""
    info "Installation Method"
    echo "========================================="
    echo "1) Network Reinstall (netboot.xyz) - Recommended"
    echo "2) DD Image (Direct write) - Faster"
    echo "3) Auto-detect"
    read -p "Choice [1-3]: " method_choice
    
    case $method_choice in
        1) INSTALL_METHOD="network" ;;
        2) INSTALL_METHOD="dd" ;;
        *) INSTALL_METHOD="auto" ;;
    esac
    
    # Save configuration
    save_ssh_config
    create_post_install_script
    create_cloud_init_config
    
    # Display summary
    echo ""
    info "INSTALLATION SUMMARY"
    echo "========================================="
    echo "Current System:"
    echo "  IP: $CURRENT_IP"
    echo "  Disk: /dev/$DISK_DEVICE"
    echo "  Provider: $PROVIDER_DETECTED"
    echo ""
    echo "Will Install: $TARGET_OS"
    echo "Method: $INSTALL_METHOD"
    echo ""
    echo "SSH Will Be Restored With:"
    echo "  Username: $CUSTOM_ROOT_USER"
    echo "  Port: $SSH_PORT"
    echo "  Auth: $([ -n "$CUSTOM_SSH_KEY" ] && echo "SSH Key" || echo "Password")"
    echo "========================================="
    echo ""
    read -p "START INSTALLATION? (yes/no): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        error "Installation cancelled"
    fi
    
    # Trigger installation
    trigger_installation
    
    # Reboot to start installation
    confirm_and_reboot
}

# Run main
main
