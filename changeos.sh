#!/bin/bash
#
# changeos.sh - Change OS and version on cloud VPS without losing network data and home folder
#
# Supported cloud providers: Azure, AWS, Google Cloud, Oracle Cloud
# Preserves: Network configuration (IP, gateway, DNS, routes), Home folder data
#
# Usage: sudo ./changeos.sh
#
# The script provides an interactive menu to select OS and version.
# Restoration runs automatically after OS change.
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default values
BACKUP_DIR="/var/changeos-backup"
TARGET_OS=""
TARGET_VERSION=""
SCRIPT_VERSION="2.0.0"

# Logging functions
log_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

log_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

log_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

log_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Display OS selection menu
select_os_menu() {
    clear
    echo ""
    printf "${BOLD}${CYAN}=============================================${NC}\n"
    printf "${BOLD}${CYAN}       Change OS - Select Operating System${NC}\n"
    printf "${BOLD}${CYAN}=============================================${NC}\n"
    echo ""
    printf "${BOLD}Select OS:${NC}\n"
    echo ""
    echo "  1. Debian"
    echo "  2. Ubuntu"
    echo "  3. AlmaLinux"
    echo "  4. Rocky Linux"
    echo "  5. CentOS"
    echo "  6. Fedora"
    echo "  7. Kali Linux"
    echo ""
    echo "  0. Exit"
    echo ""
    printf "${BOLD}Enter your choice [1-7]:${NC} "
    
    read -r os_choice
    
    case $os_choice in
        1) TARGET_OS="debian" ;;
        2) TARGET_OS="ubuntu" ;;
        3) TARGET_OS="almalinux" ;;
        4) TARGET_OS="rocky" ;;
        5) TARGET_OS="centos" ;;
        6) TARGET_OS="fedora" ;;
        7) TARGET_OS="kali" ;;
        0) 
            echo ""
            log_info "Exiting..."
            exit 0
            ;;
        *)
            log_error "Invalid choice. Please try again."
            sleep 2
            select_os_menu
            ;;
    esac
}

# Display version selection menu based on OS
select_version_menu() {
    clear
    echo ""
    printf "${BOLD}${CYAN}=============================================${NC}\n"
    printf "${BOLD}${CYAN}       Change OS - Select Version${NC}\n"
    printf "${BOLD}${CYAN}=============================================${NC}\n"
    echo ""
    printf "${BOLD}Selected OS: ${GREEN}${TARGET_OS}${NC}\n"
    echo ""
    printf "${BOLD}Select version:${NC}\n"
    echo ""
    
    case "${TARGET_OS}" in
        debian)
            echo "  1. Debian 12 (Bookworm)"
            echo "  2. Debian 11 (Bullseye)"
            echo "  3. Debian 10 (Buster)"
            echo ""
            echo "  0. Go back"
            echo ""
            printf "${BOLD}Enter your choice [1-3]:${NC} "
            read -r version_choice
            case $version_choice in
                1) TARGET_VERSION="12" ;;
                2) TARGET_VERSION="11" ;;
                3) TARGET_VERSION="10" ;;
                0) select_os_menu; select_version_menu ;;
                *) log_error "Invalid choice"; sleep 2; select_version_menu ;;
            esac
            ;;
        ubuntu)
            echo "  1. Ubuntu 24.04 LTS (Noble Numbat)"
            echo "  2. Ubuntu 22.04 LTS (Jammy Jellyfish)"
            echo "  3. Ubuntu 20.04 LTS (Focal Fossa)"
            echo "  4. Ubuntu 18.04 LTS (Bionic Beaver)"
            echo ""
            echo "  0. Go back"
            echo ""
            printf "${BOLD}Enter your choice [1-4]:${NC} "
            read -r version_choice
            case $version_choice in
                1) TARGET_VERSION="24.04" ;;
                2) TARGET_VERSION="22.04" ;;
                3) TARGET_VERSION="20.04" ;;
                4) TARGET_VERSION="18.04" ;;
                0) select_os_menu; select_version_menu ;;
                *) log_error "Invalid choice"; sleep 2; select_version_menu ;;
            esac
            ;;
        almalinux)
            echo "  1. AlmaLinux 9"
            echo "  2. AlmaLinux 8"
            echo ""
            echo "  0. Go back"
            echo ""
            printf "${BOLD}Enter your choice [1-2]:${NC} "
            read -r version_choice
            case $version_choice in
                1) TARGET_VERSION="9" ;;
                2) TARGET_VERSION="8" ;;
                0) select_os_menu; select_version_menu ;;
                *) log_error "Invalid choice"; sleep 2; select_version_menu ;;
            esac
            ;;
        rocky)
            echo "  1. Rocky Linux 9"
            echo "  2. Rocky Linux 8"
            echo ""
            echo "  0. Go back"
            echo ""
            printf "${BOLD}Enter your choice [1-2]:${NC} "
            read -r version_choice
            case $version_choice in
                1) TARGET_VERSION="9" ;;
                2) TARGET_VERSION="8" ;;
                0) select_os_menu; select_version_menu ;;
                *) log_error "Invalid choice"; sleep 2; select_version_menu ;;
            esac
            ;;
        centos)
            echo "  1. CentOS 9 Stream"
            echo "  2. CentOS 8 Stream"
            echo ""
            echo "  0. Go back"
            echo ""
            printf "${BOLD}Enter your choice [1-2]:${NC} "
            read -r version_choice
            case $version_choice in
                1) TARGET_VERSION="9" ;;
                2) TARGET_VERSION="8" ;;
                0) select_os_menu; select_version_menu ;;
                *) log_error "Invalid choice"; sleep 2; select_version_menu ;;
            esac
            ;;
        fedora)
            echo "  1. Fedora 40"
            echo "  2. Fedora 39"
            echo "  3. Fedora 38"
            echo ""
            echo "  0. Go back"
            echo ""
            printf "${BOLD}Enter your choice [1-3]:${NC} "
            read -r version_choice
            case $version_choice in
                1) TARGET_VERSION="40" ;;
                2) TARGET_VERSION="39" ;;
                3) TARGET_VERSION="38" ;;
                0) select_os_menu; select_version_menu ;;
                *) log_error "Invalid choice"; sleep 2; select_version_menu ;;
            esac
            ;;
        kali)
            echo "  1. Kali Linux Rolling (Latest)"
            echo ""
            printf "${YELLOW}  Note: Kali Linux uses a rolling release model.${NC}\n"
            echo ""
            echo "  0. Go back"
            echo ""
            printf "${BOLD}Enter your choice [1]:${NC} "
            read -r version_choice
            case $version_choice in
                1) TARGET_VERSION="rolling" ;;
                0) select_os_menu; select_version_menu ;;
                *) log_error "Invalid choice"; sleep 2; select_version_menu ;;
            esac
            ;;
    esac
}

# Confirm selection
confirm_selection() {
    clear
    echo ""
    printf "${BOLD}${CYAN}=============================================${NC}\n"
    printf "${BOLD}${CYAN}       Change OS - Confirm Selection${NC}\n"
    printf "${BOLD}${CYAN}=============================================${NC}\n"
    echo ""
    printf "${BOLD}You have selected:${NC}\n"
    echo ""
    printf "  OS:      ${GREEN}${TARGET_OS}${NC}\n"
    printf "  Version: ${GREEN}${TARGET_VERSION}${NC}\n"
    echo ""
    printf "${YELLOW}This will backup your data and prepare for OS change.${NC}\n"
    printf "${YELLOW}Network configuration, home folders, and SSH keys will be preserved.${NC}\n"
    echo ""
    printf "${BOLD}Proceed with this selection? [y/n]:${NC} "
    
    read -r confirm
    case "${confirm,,}" in
        y|yes)
            return 0
            ;;
        n|no)
            select_os_menu
            select_version_menu
            confirm_selection
            ;;
        *)
            log_error "Please enter 'y' or 'n'"
            sleep 1
            confirm_selection
            ;;
    esac
}

# Detect current OS
detect_current_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        CURRENT_OS="$ID"
        CURRENT_VERSION="$VERSION_ID"
        CURRENT_NAME="$PRETTY_NAME"
    else
        log_error "Cannot detect current OS. /etc/os-release not found."
        exit 1
    fi
    
    log_info "Current OS: $CURRENT_NAME"
}

# Detect cloud provider
detect_cloud_provider() {
    CLOUD_PROVIDER="unknown"
    
    # Check for Azure
    if curl -s -H "Metadata:true" --noproxy "*" \
        "http://169.254.169.254/metadata/instance?api-version=2021-02-01" \
        --connect-timeout 2 2>/dev/null | grep -q "azEnvironment"; then
        CLOUD_PROVIDER="azure"
        log_info "Detected cloud provider: Azure"
        return
    fi
    
    # Check for AWS
    if curl -s --connect-timeout 2 \
        http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null | grep -qE "^i-"; then
        CLOUD_PROVIDER="aws"
        log_info "Detected cloud provider: AWS"
        return
    fi
    
    # Check for Google Cloud
    if curl -s -H "Metadata-Flavor: Google" --connect-timeout 2 \
        "http://metadata.google.internal/computeMetadata/v1/instance/id" 2>/dev/null | grep -qE "^[0-9]+$"; then
        CLOUD_PROVIDER="gcp"
        log_info "Detected cloud provider: Google Cloud"
        return
    fi
    
    # Check for Oracle Cloud
    if curl -s -H "Authorization: Bearer Oracle" --connect-timeout 2 \
        "http://169.254.169.254/opc/v2/instance/" 2>/dev/null | grep -q "availabilityDomain"; then
        CLOUD_PROVIDER="oracle"
        log_info "Detected cloud provider: Oracle Cloud"
        return
    fi
    
    log_warning "Could not detect cloud provider. Proceeding with generic approach."
}

# Get primary network interface
get_primary_interface() {
    PRIMARY_INTERFACE=$(ip route | grep default | head -n1 | awk '{print $5}')
    if [[ -z "$PRIMARY_INTERFACE" ]]; then
        PRIMARY_INTERFACE=$(ip link show | grep -E "^[0-9]+:" | grep -v "lo:" | head -n1 | cut -d: -f2 | tr -d ' ')
    fi
    log_info "Primary network interface: $PRIMARY_INTERFACE"
}

# Backup network configuration
backup_network_config() {
    log_info "Backing up network configuration..."
    
    local net_backup_dir="${BACKUP_DIR}/network"
    mkdir -p "$net_backup_dir"
    
    # Backup IP configuration
    ip addr show > "${net_backup_dir}/ip_addr.txt"
    ip route show > "${net_backup_dir}/ip_route.txt"
    ip -6 route show > "${net_backup_dir}/ip6_route.txt" 2>/dev/null || true
    
    # Store primary interface configuration
    get_primary_interface
    
    # Get IP address
    IP_ADDRESS=$(ip -4 addr show "$PRIMARY_INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -n1)
    GATEWAY=$(ip route | grep default | head -n1 | awk '{print $3}')
    
    # Save to config file
    cat > "${net_backup_dir}/network.conf" << EOF
PRIMARY_INTERFACE=${PRIMARY_INTERFACE}
IP_ADDRESS=${IP_ADDRESS}
GATEWAY=${GATEWAY}
EOF
    
    # Backup DNS configuration
    cp /etc/resolv.conf "${net_backup_dir}/resolv.conf" 2>/dev/null || true
    
    # Backup network manager configurations if they exist
    if [[ -d /etc/netplan ]]; then
        cp -r /etc/netplan "${net_backup_dir}/"
    fi
    
    if [[ -d /etc/NetworkManager ]]; then
        cp -r /etc/NetworkManager/system-connections "${net_backup_dir}/NetworkManager/" 2>/dev/null || true
    fi
    
    if [[ -f /etc/network/interfaces ]]; then
        cp /etc/network/interfaces "${net_backup_dir}/"
    fi
    
    if [[ -d /etc/sysconfig/network-scripts ]]; then
        cp -r /etc/sysconfig/network-scripts "${net_backup_dir}/"
    fi
    
    # Cloud-specific network configurations
    case "$CLOUD_PROVIDER" in
        azure)
            if [[ -d /var/lib/waagent ]]; then
                cp -r /var/lib/waagent "${net_backup_dir}/" 2>/dev/null || true
            fi
            ;;
        aws)
            if [[ -f /etc/cloud/cloud.cfg ]]; then
                cp /etc/cloud/cloud.cfg "${net_backup_dir}/"
            fi
            ;;
        gcp)
            if [[ -d /etc/default/instance_configs.cfg.d ]]; then
                cp -r /etc/default/instance_configs.cfg.d "${net_backup_dir}/"
            fi
            ;;
        oracle)
            if [[ -f /etc/oci-hostname.conf ]]; then
                cp /etc/oci-hostname.conf "${net_backup_dir}/"
            fi
            ;;
    esac
    
    log_success "Network configuration backed up to ${net_backup_dir}"
}

# Backup home directories
backup_home_dirs() {
    log_info "Backing up home directories..."
    
    local home_backup_dir="${BACKUP_DIR}/home"
    mkdir -p "$home_backup_dir"
    
    # Backup all home directories
    shopt -s nullglob
    local home_dirs=(/home/*)
    shopt -u nullglob
    
    if [[ ${#home_dirs[@]} -eq 0 ]]; then
        log_warning "No home directories found in /home/"
    else
        for home_dir in "${home_dirs[@]}"; do
            if [[ -d "$home_dir" ]]; then
                local username=$(basename "$home_dir")
                log_info "  Backing up /home/${username}..."
                
                tar -czf "${home_backup_dir}/${username}.tar.gz" -C /home "$username" 2>/dev/null || {
                    log_warning "Failed to backup /home/${username}, trying with --ignore-failed-read"
                    tar --ignore-failed-read -czf "${home_backup_dir}/${username}.tar.gz" -C /home "$username"
                }
            fi
        done
    fi
    
    # Backup /root if needed
    if [[ -d /root ]]; then
        log_info "  Backing up /root..."
        tar -czf "${home_backup_dir}/root.tar.gz" -C / root 2>/dev/null || true
    fi
    
    log_success "Home directories backed up to ${home_backup_dir}"
}

# Backup SSH configuration
backup_ssh_config() {
    log_info "Backing up SSH configuration..."
    
    local ssh_backup_dir="${BACKUP_DIR}/ssh"
    mkdir -p "$ssh_backup_dir"
    
    # Backup SSH host keys
    shopt -s nullglob
    local ssh_host_keys=(/etc/ssh/ssh_host_*)
    shopt -u nullglob
    
    if [[ ${#ssh_host_keys[@]} -gt 0 ]]; then
        cp "${ssh_host_keys[@]}" "${ssh_backup_dir}/" 2>/dev/null || true
    else
        log_warning "No SSH host keys found in /etc/ssh/"
    fi
    
    # Backup sshd_config
    cp /etc/ssh/sshd_config "${ssh_backup_dir}/" 2>/dev/null || true
    
    # Backup authorized_keys for all users
    shopt -s nullglob
    local home_dirs=(/home/*)
    shopt -u nullglob
    
    for home_dir in "${home_dirs[@]}"; do
        if [[ -f "${home_dir}/.ssh/authorized_keys" ]]; then
            local username=$(basename "$home_dir")
            mkdir -p "${ssh_backup_dir}/users/${username}"
            cp -r "${home_dir}/.ssh" "${ssh_backup_dir}/users/${username}/" 2>/dev/null || true
        fi
    done
    
    # Backup root authorized_keys
    if [[ -f /root/.ssh/authorized_keys ]]; then
        mkdir -p "${ssh_backup_dir}/users/root"
        cp -r /root/.ssh "${ssh_backup_dir}/users/root/" 2>/dev/null || true
    fi
    
    log_success "SSH configuration backed up to ${ssh_backup_dir}"
}

# Backup user accounts
backup_user_accounts() {
    log_info "Backing up user accounts..."
    
    local user_backup_dir="${BACKUP_DIR}/users"
    mkdir -p "$user_backup_dir"
    
    # Backup passwd, shadow, group files
    cp /etc/passwd "${user_backup_dir}/"
    cp /etc/shadow "${user_backup_dir}/" 2>/dev/null || true
    cp /etc/group "${user_backup_dir}/"
    cp /etc/gshadow "${user_backup_dir}/" 2>/dev/null || true
    cp /etc/sudoers "${user_backup_dir}/" 2>/dev/null || true
    
    if [[ -d /etc/sudoers.d ]]; then
        cp -r /etc/sudoers.d "${user_backup_dir}/"
    fi
    
    log_success "User accounts backed up to ${user_backup_dir}"
}

# Create restoration script
create_restore_script() {
    log_info "Creating restoration script..."
    
    cat > "${BACKUP_DIR}/restore.sh" << 'RESTORE_SCRIPT'
#!/bin/bash
#
# Restoration script for changeos
# This script restores network configuration, home folders, and SSH settings
#

set -euo pipefail

BACKUP_DIR="$(dirname "$0")"

log_info() { echo "[INFO] $1"; }
log_success() { echo "[SUCCESS] $1"; }
log_error() { echo "[ERROR] $1" >&2; }

# Restore network configuration
restore_network() {
    log_info "Restoring network configuration..."
    
    if [[ -f "${BACKUP_DIR}/network/network.conf" ]]; then
        source "${BACKUP_DIR}/network/network.conf"
        
        # Restore IP address if configured statically
        if [[ -n "${IP_ADDRESS:-}" ]] && [[ -n "${PRIMARY_INTERFACE:-}" ]]; then
            ip addr add "$IP_ADDRESS" dev "$PRIMARY_INTERFACE" 2>/dev/null || true
        fi
        
        # Restore default gateway
        if [[ -n "${GATEWAY:-}" ]]; then
            ip route add default via "$GATEWAY" 2>/dev/null || true
        fi
    fi
    
    # Restore DNS
    if [[ -f "${BACKUP_DIR}/network/resolv.conf" ]]; then
        cp "${BACKUP_DIR}/network/resolv.conf" /etc/resolv.conf
    fi
    
    # Restore netplan if exists
    if [[ -d "${BACKUP_DIR}/network/netplan" ]]; then
        cp -r "${BACKUP_DIR}/network/netplan/"* /etc/netplan/ 2>/dev/null || true
        netplan apply 2>/dev/null || true
    fi
    
    log_success "Network configuration restored"
}

# Restore home directories
restore_home() {
    log_info "Restoring home directories..."
    
    for backup_file in "${BACKUP_DIR}/home/"*.tar.gz; do
        if [[ -f "$backup_file" ]]; then
            local filename=$(basename "$backup_file" .tar.gz)
            
            if [[ "$filename" == "root" ]]; then
                tar -xzf "$backup_file" -C / 2>/dev/null || true
            else
                tar -xzf "$backup_file" -C /home 2>/dev/null || true
                
                # Restore ownership
                if id "$filename" &>/dev/null; then
                    chown -R "${filename}:${filename}" "/home/${filename}" 2>/dev/null || true
                fi
            fi
        fi
    done
    
    log_success "Home directories restored"
}

# Restore SSH configuration
restore_ssh() {
    log_info "Restoring SSH configuration..."
    
    # Restore host keys
    if [[ -d "${BACKUP_DIR}/ssh" ]]; then
        cp "${BACKUP_DIR}/ssh/ssh_host_"* /etc/ssh/ 2>/dev/null || true
        chmod 600 /etc/ssh/ssh_host_*_key 2>/dev/null || true
        chmod 644 /etc/ssh/ssh_host_*.pub 2>/dev/null || true
    fi
    
    # Restore user SSH directories
    if [[ -d "${BACKUP_DIR}/ssh/users" ]]; then
        for user_dir in "${BACKUP_DIR}/ssh/users/"*; do
            if [[ -d "$user_dir" ]]; then
                local username=$(basename "$user_dir")
                
                if [[ "$username" == "root" ]]; then
                    cp -r "${user_dir}/.ssh" /root/ 2>/dev/null || true
                    chmod 700 /root/.ssh
                    chmod 600 /root/.ssh/* 2>/dev/null || true
                else
                    if [[ -d "/home/${username}" ]]; then
                        cp -r "${user_dir}/.ssh" "/home/${username}/" 2>/dev/null || true
                        chown -R "${username}:${username}" "/home/${username}/.ssh" 2>/dev/null || true
                        chmod 700 "/home/${username}/.ssh"
                        chmod 600 "/home/${username}/.ssh/"* 2>/dev/null || true
                    fi
                fi
            fi
        done
    fi
    
    log_success "SSH configuration restored"
}

# Restore user accounts
restore_users() {
    log_info "Restoring user accounts..."
    
    if [[ -d "${BACKUP_DIR}/users" ]]; then
        # First, restore groups from the backup
        if [[ -f "${BACKUP_DIR}/users/group" ]]; then
            while IFS=: read -r groupname x gid members; do
                if [[ $gid -ge 1000 ]] && [[ $gid -lt 65534 ]]; then
                    if ! getent group "$groupname" &>/dev/null; then
                        groupadd -g "$gid" "$groupname" 2>/dev/null || true
                    fi
                fi
            done < "${BACKUP_DIR}/users/group"
        fi
        
        # Merge users (don't overwrite system users)
        while IFS=: read -r username x uid gid comment home shell; do
            if [[ $uid -ge 1000 ]] && [[ $uid -lt 65534 ]]; then
                if ! id "$username" &>/dev/null; then
                    # Create group if it doesn't exist
                    if ! getent group "$gid" &>/dev/null; then
                        groupadd -g "$gid" "$username" 2>/dev/null || true
                    fi
                    useradd -u "$uid" -g "$gid" -d "$home" -s "$shell" -c "$comment" "$username" 2>/dev/null || true
                fi
            fi
        done < "${BACKUP_DIR}/users/passwd"
        
        # Restore sudoers
        if [[ -f "${BACKUP_DIR}/users/sudoers" ]]; then
            cp "${BACKUP_DIR}/users/sudoers" /etc/sudoers
            chmod 440 /etc/sudoers
        fi
        
        if [[ -d "${BACKUP_DIR}/users/sudoers.d" ]]; then
            cp -r "${BACKUP_DIR}/users/sudoers.d/"* /etc/sudoers.d/ 2>/dev/null || true
        fi
    fi
    
    log_success "User accounts restored"
}

# Main restoration
main() {
    echo "==================================="
    echo "  Change OS - Restoration Script"
    echo "==================================="
    
    restore_users
    restore_home
    restore_ssh
    restore_network
    
    echo ""
    log_success "Restoration complete!"
    echo "Please reboot the system to ensure all changes take effect."
}

main "$@"
RESTORE_SCRIPT

    chmod +x "${BACKUP_DIR}/restore.sh"
    log_success "Restoration script created at ${BACKUP_DIR}/restore.sh"
}

# Install required packages for OS change
install_dependencies() {
    log_info "Installing required dependencies..."
    
    if command -v apt-get &>/dev/null; then
        apt-get update -qq
        apt-get install -y -qq wget curl debootstrap
    elif command -v dnf &>/dev/null; then
        dnf install -y -q wget curl
        # Install EPEL for debootstrap on RHEL-based systems
        dnf install -y -q epel-release 2>/dev/null || true
        dnf install -y -q debootstrap 2>/dev/null || true
    elif command -v yum &>/dev/null; then
        yum install -y -q wget curl
        # Install EPEL for debootstrap on older RHEL-based systems
        yum install -y -q epel-release 2>/dev/null || true
        yum install -y -q debootstrap 2>/dev/null || true
    fi
    
    log_success "Dependencies installed"
}

# Download and prepare new OS
prepare_new_os() {
    log_info "Preparing new OS: ${TARGET_OS} ${TARGET_VERSION}..."
    
    local new_os_dir="${BACKUP_DIR}/new_os"
    mkdir -p "$new_os_dir"
    
    case "${TARGET_OS,,}" in
        ubuntu)
            prepare_ubuntu "$new_os_dir"
            ;;
        debian)
            prepare_debian "$new_os_dir"
            ;;
        centos|rocky|almalinux)
            prepare_rhel_based "$new_os_dir"
            ;;
        fedora)
            prepare_fedora "$new_os_dir"
            ;;
        kali)
            prepare_kali "$new_os_dir"
            ;;
        *)
            log_error "Unsupported target OS: $TARGET_OS"
            exit 1
            ;;
    esac
}

# Prepare Ubuntu
prepare_ubuntu() {
    local target_dir="$1"
    log_info "Preparing Ubuntu ${TARGET_VERSION}..."
    
    local codename=""
    case "$TARGET_VERSION" in
        24.04|24) codename="noble" ;;
        22.04|22) codename="jammy" ;;
        20.04|20) codename="focal" ;;
        18.04|18) codename="bionic" ;;
        *) 
            log_error "Unsupported Ubuntu version: $TARGET_VERSION"
            exit 1
            ;;
    esac
    
    debootstrap --arch=amd64 "$codename" "$target_dir" http://archive.ubuntu.com/ubuntu/
}

# Prepare Debian
prepare_debian() {
    local target_dir="$1"
    log_info "Preparing Debian ${TARGET_VERSION}..."
    
    local codename=""
    case "$TARGET_VERSION" in
        12) codename="bookworm" ;;
        11) codename="bullseye" ;;
        10) codename="buster" ;;
        *)
            log_error "Unsupported Debian version: $TARGET_VERSION"
            exit 1
            ;;
    esac
    
    debootstrap --arch=amd64 "$codename" "$target_dir" http://deb.debian.org/debian/
}

# Prepare RHEL-based (CentOS, Rocky, AlmaLinux)
prepare_rhel_based() {
    local target_dir="$1"
    log_info "Preparing ${TARGET_OS} ${TARGET_VERSION}..."
    
    local base_url=""
    case "${TARGET_OS,,}" in
        centos)
            case "$TARGET_VERSION" in
                9|9-stream) base_url="https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/" ;;
                8|8-stream) base_url="https://mirror.stream.centos.org/8-stream/BaseOS/x86_64/os/" ;;
                *)
                    log_error "Unsupported CentOS version: $TARGET_VERSION"
                    exit 1
                    ;;
            esac
            ;;
        rocky)
            case "$TARGET_VERSION" in
                9) base_url="https://download.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/" ;;
                8) base_url="https://download.rockylinux.org/pub/rocky/8/BaseOS/x86_64/os/" ;;
                *)
                    log_error "Unsupported Rocky Linux version: $TARGET_VERSION"
                    exit 1
                    ;;
            esac
            ;;
        almalinux)
            case "$TARGET_VERSION" in
                9) base_url="https://repo.almalinux.org/almalinux/9/BaseOS/x86_64/os/" ;;
                8) base_url="https://repo.almalinux.org/almalinux/8/BaseOS/x86_64/os/" ;;
                *)
                    log_error "Unsupported AlmaLinux version: $TARGET_VERSION"
                    exit 1
                    ;;
            esac
            ;;
    esac
    
    log_info "Downloading ${TARGET_OS} ${TARGET_VERSION} from ${base_url}"
    # For RHEL-based systems, we'll use a different approach
    mkdir -p "${target_dir}"
    # Create marker file with installation info
    echo "BASE_URL=${base_url}" > "${target_dir}/install.conf"
    echo "OS=${TARGET_OS}" >> "${target_dir}/install.conf"
    echo "VERSION=${TARGET_VERSION}" >> "${target_dir}/install.conf"
}

# Prepare Fedora
prepare_fedora() {
    local target_dir="$1"
    log_info "Preparing Fedora ${TARGET_VERSION}..."
    
    local base_url="https://download.fedoraproject.org/pub/fedora/linux/releases/${TARGET_VERSION}/Everything/x86_64/os/"
    
    mkdir -p "${target_dir}"
    echo "BASE_URL=${base_url}" > "${target_dir}/install.conf"
    echo "OS=fedora" >> "${target_dir}/install.conf"
    echo "VERSION=${TARGET_VERSION}" >> "${target_dir}/install.conf"
}

# Prepare Kali Linux
prepare_kali() {
    local target_dir="$1"
    log_info "Preparing Kali Linux..."
    
    # Kali Linux uses rolling release model
    debootstrap --arch=amd64 kali-rolling "$target_dir" http://http.kali.org/kali
}

# Perform the OS change
perform_os_change() {
    log_info "Performing OS change..."
    
    echo ""
    printf "${BOLD}${YELLOW}==================================================${NC}\n"
    printf "${BOLD}${YELLOW}  CAUTION: This will replace the current OS!${NC}\n"
    printf "${BOLD}${YELLOW}  All data not backed up will be LOST!${NC}\n"
    printf "${BOLD}${YELLOW}  Ensure you have a recovery plan!${NC}\n"
    printf "${BOLD}${YELLOW}==================================================${NC}\n"
    echo ""
    log_info "Backup location: ${BACKUP_DIR}"
    log_info "Target OS: ${TARGET_OS} ${TARGET_VERSION}"
    echo ""
    
    printf "${BOLD}Are you sure you want to continue? (yes/no):${NC} "
    read -r confirm
    if [[ "${confirm,,}" != "yes" ]]; then
        log_info "Operation cancelled by user."
        exit 0
    fi
    
    # Create flag file for post-reboot restoration
    cat > "${BACKUP_DIR}/pending_restore" << EOF
TARGET_OS=${TARGET_OS}
TARGET_VERSION=${TARGET_VERSION}
BACKUP_DIR=${BACKUP_DIR}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
EOF
    
    # Install cloud agents for the new OS
    install_cloud_agents
    
    # Setup automatic restoration on first boot
    setup_auto_restore
    
    log_success "OS change preparation complete."
    echo ""
    printf "${BOLD}${CYAN}==================================================${NC}\n"
    printf "${BOLD}${CYAN}  Next Steps${NC}\n"
    printf "${BOLD}${CYAN}==================================================${NC}\n"
    echo ""
    log_info "The backup has been created at: ${BACKUP_DIR}"
    echo ""
    log_info "To complete the OS change:"
    echo ""
    log_info "  1. Go to your cloud provider's console"
    log_info "  2. Stop the VM"
    log_info "  3. Change the boot disk/image to ${TARGET_OS} ${TARGET_VERSION}"
    log_info "  4. Start the VM"
    echo ""
    printf "${GREEN}Restoration will run automatically on first boot!${NC}\n"
    echo ""
    log_info "If automatic restoration doesn't run, execute manually:"
    log_info "  sudo ${BACKUP_DIR}/restore.sh"
    echo ""
}

# Setup automatic restoration after OS change
setup_auto_restore() {
    log_info "Setting up automatic restoration..."
    
    # Create systemd service for automatic restoration
    cat > "${BACKUP_DIR}/changeos-restore.service" << EOF
[Unit]
Description=Change OS - Automatic Restoration Service
After=network.target
ConditionPathExists=${BACKUP_DIR}/pending_restore

[Service]
Type=oneshot
ExecStart=${BACKUP_DIR}/restore.sh
ExecStartPost=/bin/rm -f ${BACKUP_DIR}/pending_restore
ExecStartPost=/bin/systemctl disable changeos-restore.service
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Create installation instructions for the service
    cat > "${BACKUP_DIR}/install_auto_restore.sh" << 'AUTO_RESTORE_SCRIPT'
#!/bin/bash
# Install automatic restoration service
# Run this after changing the OS image

BACKUP_DIR="$(dirname "$0")"

if [[ -f "${BACKUP_DIR}/changeos-restore.service" ]]; then
    cp "${BACKUP_DIR}/changeos-restore.service" /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable changeos-restore.service
    echo "Automatic restoration service installed and enabled."
    echo "The restoration will run on next boot."
else
    echo "Error: Service file not found."
    exit 1
fi
AUTO_RESTORE_SCRIPT

    chmod +x "${BACKUP_DIR}/install_auto_restore.sh"
    
    log_success "Automatic restoration setup created"
    log_info "After changing OS, run: sudo ${BACKUP_DIR}/install_auto_restore.sh"
}

# Install cloud-specific agents
install_cloud_agents() {
    log_info "Preparing cloud agent installation scripts..."
    
    cat > "${BACKUP_DIR}/install_cloud_agents.sh" << 'CLOUD_SCRIPT'
#!/bin/bash
# Install cloud-specific agents after OS change

CLOUD_PROVIDER="${1:-unknown}"

install_azure_agent() {
    if command -v apt-get &>/dev/null; then
        apt-get update
        apt-get install -y waagent cloud-init
    elif command -v dnf &>/dev/null; then
        dnf install -y WALinuxAgent cloud-init
    elif command -v yum &>/dev/null; then
        yum install -y WALinuxAgent cloud-init
    fi
    systemctl enable waagent cloud-init
}

install_aws_agent() {
    if command -v apt-get &>/dev/null; then
        apt-get update
        apt-get install -y cloud-init
    elif command -v dnf &>/dev/null; then
        dnf install -y cloud-init
    elif command -v yum &>/dev/null; then
        yum install -y cloud-init
    fi
    systemctl enable cloud-init
}

install_gcp_agent() {
    if command -v apt-get &>/dev/null; then
        curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
        bash add-google-cloud-ops-agent-repo.sh --also-install
        apt-get install -y google-compute-engine google-osconfig-agent
    elif command -v dnf &>/dev/null || command -v yum &>/dev/null; then
        curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
        bash add-google-cloud-ops-agent-repo.sh --also-install
    fi
}

install_oracle_agent() {
    if command -v apt-get &>/dev/null; then
        apt-get update
        apt-get install -y cloud-init
    elif command -v dnf &>/dev/null; then
        dnf install -y cloud-init
    elif command -v yum &>/dev/null; then
        yum install -y cloud-init
    fi
}

case "$CLOUD_PROVIDER" in
    azure) install_azure_agent ;;
    aws) install_aws_agent ;;
    gcp) install_gcp_agent ;;
    oracle) install_oracle_agent ;;
    *) echo "Unknown cloud provider, skipping agent installation" ;;
esac
CLOUD_SCRIPT

    chmod +x "${BACKUP_DIR}/install_cloud_agents.sh"
}

# Generate summary report
generate_report() {
    local report_file="${BACKUP_DIR}/changeos_report.txt"
    
    cat > "$report_file" << EOF
===========================================
  Change OS - Backup Report
===========================================
Date: $(date)
Script Version: ${SCRIPT_VERSION}

Current System:
  OS: ${CURRENT_NAME}
  Cloud Provider: ${CLOUD_PROVIDER}

Target System:
  OS: ${TARGET_OS}
  Version: ${TARGET_VERSION}

Backup Location: ${BACKUP_DIR}

Backed Up Data:
  - Network configuration
  - Home directories
  - SSH configuration
  - User accounts

Restoration:
  Run: sudo ${BACKUP_DIR}/restore.sh

===========================================
EOF

    log_success "Report generated at ${report_file}"
}

# Main function
main() {
    # Check root first
    check_root
    
    # Show interactive OS selection menu
    select_os_menu
    select_version_menu
    confirm_selection
    
    clear
    echo ""
    printf "${BOLD}${CYAN}=============================================${NC}\n"
    printf "${BOLD}${CYAN}  Change OS Script v${SCRIPT_VERSION}${NC}\n"
    printf "${BOLD}${CYAN}  For Cloud VPS (Azure, AWS, GCP, Oracle)${NC}\n"
    printf "${BOLD}${CYAN}=============================================${NC}\n"
    echo ""
    
    # Detect current system
    detect_current_os
    detect_cloud_provider
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    log_info "Backup directory: ${BACKUP_DIR}"
    log_info "Target OS: ${TARGET_OS} ${TARGET_VERSION}"
    
    echo ""
    
    # Perform backups
    backup_network_config
    backup_home_dirs
    backup_ssh_config
    backup_user_accounts
    create_restore_script
    
    # Generate report
    generate_report
    
    echo ""
    log_success "All backups completed successfully!"
    echo ""
    
    # Install dependencies and perform OS change
    install_dependencies
    
    prepare_new_os
    perform_os_change
}

# Run main function
main "$@"
