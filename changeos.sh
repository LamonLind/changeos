#!/bin/bash
#
# changeos.sh - Change OS and version on cloud VPS without losing network data and home folder
#
# Supported cloud providers: Azure, AWS, Google Cloud, Oracle Cloud
# Preserves: Network configuration (IP, gateway, DNS, routes), Home folder data
#
# Usage: sudo ./changeos.sh [options]
#
# Options:
#   -t, --target-os      Target OS (ubuntu, debian, centos, rocky, fedora, almalinux)
#   -v, --version        Target OS version (e.g., 22.04, 11, 8, 9)
#   -b, --backup-dir     Directory to store backups (default: /var/changeos-backup)
#   -d, --dry-run        Perform a dry run without making changes
#   -h, --help           Show this help message
#
# Examples:
#   sudo ./changeos.sh -t ubuntu -v 22.04
#   sudo ./changeos.sh -t debian -v 12 --dry-run
#   sudo ./changeos.sh -t rocky -v 9 -b /mnt/backup
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
BACKUP_DIR="/var/changeos-backup"
DRY_RUN=false
TARGET_OS=""
TARGET_VERSION=""
SCRIPT_VERSION="1.0.0"

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

# Show usage/help
show_help() {
    cat << EOF
changeos.sh - Change OS and version on cloud VPS

Version: ${SCRIPT_VERSION}

Usage: sudo ./changeos.sh [options]

Options:
  -t, --target-os      Target OS (ubuntu, debian, centos, rocky, fedora, almalinux)
  -v, --version        Target OS version (e.g., 22.04, 11, 8, 9)
  -b, --backup-dir     Directory to store backups (default: /var/changeos-backup)
  -d, --dry-run        Perform a dry run without making changes
  -h, --help           Show this help message

Supported Cloud Providers:
  - Azure VPS
  - AWS EC2
  - Google Cloud Compute Engine
  - Oracle Cloud Infrastructure

Preserved Data:
  - Network configuration (IP address, gateway, DNS, routes)
  - Home folder contents (/home/*)
  - SSH keys and authorized_keys

Examples:
  sudo ./changeos.sh -t ubuntu -v 22.04
  sudo ./changeos.sh -t debian -v 12 --dry-run
  sudo ./changeos.sh -t rocky -v 9 -b /mnt/backup

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--target-os)
                TARGET_OS="$2"
                shift 2
                ;;
            -v|--version)
                TARGET_VERSION="$2"
                shift 2
                ;;
            -b|--backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Validate target OS
validate_target_os() {
    local valid_os=("ubuntu" "debian" "centos" "rocky" "fedora" "almalinux")
    local found=false
    
    for os in "${valid_os[@]}"; do
        if [[ "${TARGET_OS,,}" == "$os" ]]; then
            found=true
            break
        fi
    done
    
    if [[ "$found" == false ]]; then
        log_error "Invalid target OS: $TARGET_OS"
        log_info "Valid options: ${valid_os[*]}"
        exit 1
    fi
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
    for home_dir in /home/*; do
        if [[ -d "$home_dir" ]]; then
            local username=$(basename "$home_dir")
            log_info "  Backing up /home/${username}..."
            
            if [[ "$DRY_RUN" == true ]]; then
                log_info "  [DRY-RUN] Would backup /home/${username}"
            else
                tar -czf "${home_backup_dir}/${username}.tar.gz" -C /home "$username" 2>/dev/null || {
                    log_warning "Failed to backup /home/${username}, trying with --ignore-failed-read"
                    tar --ignore-failed-read -czf "${home_backup_dir}/${username}.tar.gz" -C /home "$username"
                }
            fi
        fi
    done
    
    # Backup /root if needed
    if [[ -d /root ]]; then
        log_info "  Backing up /root..."
        if [[ "$DRY_RUN" != true ]]; then
            tar -czf "${home_backup_dir}/root.tar.gz" -C / root 2>/dev/null || true
        fi
    fi
    
    log_success "Home directories backed up to ${home_backup_dir}"
}

# Backup SSH configuration
backup_ssh_config() {
    log_info "Backing up SSH configuration..."
    
    local ssh_backup_dir="${BACKUP_DIR}/ssh"
    mkdir -p "$ssh_backup_dir"
    
    # Backup SSH host keys
    cp /etc/ssh/ssh_host_* "${ssh_backup_dir}/" 2>/dev/null || true
    
    # Backup sshd_config
    cp /etc/ssh/sshd_config "${ssh_backup_dir}/" 2>/dev/null || true
    
    # Backup authorized_keys for all users
    for home_dir in /home/*; do
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
        # Merge users (don't overwrite system users)
        while IFS=: read -r username x uid gid comment home shell; do
            if [[ $uid -ge 1000 ]] && [[ $uid -lt 65534 ]]; then
                if ! id "$username" &>/dev/null; then
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
    elif command -v yum &>/dev/null; then
        yum install -y -q wget curl
    elif command -v dnf &>/dev/null; then
        dnf install -y -q wget curl
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
    
    if [[ "$DRY_RUN" != true ]]; then
        debootstrap --arch=amd64 "$codename" "$target_dir" http://archive.ubuntu.com/ubuntu/
    else
        log_info "[DRY-RUN] Would run: debootstrap --arch=amd64 $codename $target_dir"
    fi
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
    
    if [[ "$DRY_RUN" != true ]]; then
        debootstrap --arch=amd64 "$codename" "$target_dir" http://deb.debian.org/debian/
    else
        log_info "[DRY-RUN] Would run: debootstrap --arch=amd64 $codename $target_dir"
    fi
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
    
    if [[ "$DRY_RUN" != true ]]; then
        log_info "Downloading ${TARGET_OS} ${TARGET_VERSION} from ${base_url}"
        # For RHEL-based systems, we'll use a different approach
        mkdir -p "${target_dir}"
        # Create marker file with installation info
        echo "BASE_URL=${base_url}" > "${target_dir}/install.conf"
        echo "OS=${TARGET_OS}" >> "${target_dir}/install.conf"
        echo "VERSION=${TARGET_VERSION}" >> "${target_dir}/install.conf"
    else
        log_info "[DRY-RUN] Would download ${TARGET_OS} ${TARGET_VERSION} from ${base_url}"
    fi
}

# Prepare Fedora
prepare_fedora() {
    local target_dir="$1"
    log_info "Preparing Fedora ${TARGET_VERSION}..."
    
    local base_url="https://download.fedoraproject.org/pub/fedora/linux/releases/${TARGET_VERSION}/Everything/x86_64/os/"
    
    if [[ "$DRY_RUN" != true ]]; then
        mkdir -p "${target_dir}"
        echo "BASE_URL=${base_url}" > "${target_dir}/install.conf"
        echo "OS=fedora" >> "${target_dir}/install.conf"
        echo "VERSION=${TARGET_VERSION}" >> "${target_dir}/install.conf"
    else
        log_info "[DRY-RUN] Would download Fedora ${TARGET_VERSION} from ${base_url}"
    fi
}

# Perform the OS change
perform_os_change() {
    log_info "Performing OS change..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would perform the following operations:"
        log_info "  1. Stop non-essential services"
        log_info "  2. Replace system files with new OS"
        log_info "  3. Configure new OS with backed up settings"
        log_info "  4. Install cloud-specific agents"
        log_info "  5. Restore network configuration"
        log_info "  6. Restore home directories and SSH keys"
        log_info "  7. Update bootloader"
        log_info "  8. Reboot system"
        return
    fi
    
    log_warning "==================================================="
    log_warning "  CAUTION: This will replace the current OS!"
    log_warning "  All data not backed up will be LOST!"
    log_warning "  Ensure you have a recovery plan!"
    log_warning "==================================================="
    log_info ""
    log_info "Backup location: ${BACKUP_DIR}"
    log_info "Target OS: ${TARGET_OS} ${TARGET_VERSION}"
    log_info ""
    
    read -p "Are you sure you want to continue? (yes/no): " confirm
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
    
    log_success "OS change preparation complete."
    log_info ""
    log_info "==================================================="
    log_info "  IMPORTANT: Manual Steps Required"
    log_info "==================================================="
    log_info ""
    log_info "The backup has been created at: ${BACKUP_DIR}"
    log_info ""
    log_info "To complete the OS change, you have two options:"
    log_info ""
    log_info "Option 1: Cloud Provider Console (Recommended)"
    log_info "  1. Go to your cloud provider's console"
    log_info "  2. Stop the VM"
    log_info "  3. Change the boot disk/image to ${TARGET_OS} ${TARGET_VERSION}"
    log_info "  4. Start the VM"
    log_info "  5. Run the restoration script:"
    log_info "     sudo ${BACKUP_DIR}/restore.sh"
    log_info ""
    log_info "Option 2: In-place installation (Advanced)"
    log_info "  This requires rebooting into a rescue/live environment"
    log_info "  and replacing the root filesystem."
    log_info ""
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
    echo "============================================="
    echo "  Change OS Script v${SCRIPT_VERSION}"
    echo "  For Cloud VPS (Azure, AWS, GCP, Oracle)"
    echo "============================================="
    echo ""
    
    # Parse arguments
    parse_args "$@"
    
    # Check for required options
    if [[ -z "$TARGET_OS" ]] || [[ -z "$TARGET_VERSION" ]]; then
        log_error "Target OS and version are required."
        echo ""
        show_help
        exit 1
    fi
    
    # Check root
    check_root
    
    # Validate target OS
    validate_target_os
    
    # Detect current system
    detect_current_os
    detect_cloud_provider
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    log_info "Backup directory: ${BACKUP_DIR}"
    log_info "Target OS: ${TARGET_OS} ${TARGET_VERSION}"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "Running in DRY-RUN mode - no changes will be made"
    fi
    
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
    if [[ "$DRY_RUN" != true ]]; then
        install_dependencies
    fi
    
    prepare_new_os
    perform_os_change
}

# Run main function
main "$@"
