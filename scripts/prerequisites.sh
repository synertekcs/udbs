#!/bin/bash

# Ultimate Docker Business Server - Prerequisites Checker
# Comprehensive security validation and auto-hardening script

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors and symbols
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Symbols
CHECK="✅"
CROSS="❌"
WARNING="⚠️ "
INFO="ℹ️ "
SHIELD="🛡️ "
PACKAGE="📦"
ROCKET="🚀"
GEAR="⚙️ "

# Counters
CRITICAL_PASSED=0
CRITICAL_FAILED=0
WARNING_COUNT=0
ENHANCEMENT_AVAILABLE=0

# Arrays for tracking
CRITICAL_ISSUES=()
WARNING_ISSUES=()
AVAILABLE_ENHANCEMENTS=()

# Logging functions
log_header() { echo -e "\n${BOLD}${BLUE}$1${NC}"; }
log_section() { echo -e "\n${CYAN}${GEAR}${NC} ${BOLD}$1${NC}"; }
log_info() { echo -e "${BLUE}${INFO}${NC} $1"; }
log_success() { echo -e "${GREEN}${CHECK}${NC} $1"; }
log_warning() { echo -e "${YELLOW}${WARNING}${NC} $1"; }
log_error() { echo -e "${RED}${CROSS}${NC} $1"; }
log_critical() { echo -e "${RED}${CROSS} CRITICAL:${NC} $1"; }
log_shield() { echo -e "${PURPLE}${SHIELD}${NC} $1"; }

# User interaction
ask_user() {
    local prompt="$1"
    local default="${2:-Y}"
    
    if [[ "$default" == "Y" ]]; then
        read -p "$(echo -e "${prompt} [Y/n]: ")" response
        [[ -z "$response" || "$response" =~ ^[Yy] ]]
    else
        read -p "$(echo -e "${prompt} [y/N]: ")" response
        [[ "$response" =~ ^[Yy] ]]
    fi
}

# Multi-choice selection
select_options() {
    local -n options_ref=$1
    local -n selected_ref=$2
    local prompt="$3"
    
    echo -e "\n${prompt}"
    echo "Select options to install:"
    
    for i in "${!options_ref[@]}"; do
        local checked="✓"
        [[ "${selected_ref[$i]:-1}" == "0" ]] && checked="✗"
        echo "[$((i+1))] $checked ${options_ref[$i]}"
    done
    
    echo "[a] all  [n] none  [Enter] continue with selection"
    
    while true; do
        read -p "Choice: " choice
        case "$choice" in
            [1-9])
                local idx=$((choice-1))
                if [[ $idx -lt ${#options_ref[@]} ]]; then
                    selected_ref[$idx]=$((1 - ${selected_ref[$idx]:-1}))
                    # Redraw options
                    echo -e "\033[${#options_ref[@]}A\033[J"
                    for i in "${!options_ref[@]}"; do
                        local checked="✓"
                        [[ "${selected_ref[$i]:-1}" == "0" ]] && checked="✗"
                        echo "[$((i+1))] $checked ${options_ref[$i]}"
                    done
                    echo "[a] all  [n] none  [Enter] continue with selection"
                fi
                ;;
            [aA])
                for i in "${!options_ref[@]}"; do
                    selected_ref[$i]=1
                done
                break
                ;;
            [nN])
                for i in "${!options_ref[@]}"; do
                    selected_ref[$i]=0
                done
                break
                ;;
            "")
                break
                ;;
            *)
                echo "Invalid choice. Try again."
                ;;
        esac
    done
}

# Check if running as root
check_user_security() {
    log_section "User Security Validation"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_critical "Running as root user"
        CRITICAL_ISSUES+=("Script running as root - security risk")
        CRITICAL_FAILED=$((CRITICAL_FAILED + 1))
        return 1
    else
        log_success "Running as non-root user"
        CRITICAL_PASSED=$((CRITICAL_PASSED + 1))
    fi
    
    # Check sudo access
    if sudo -v 2>/dev/null; then
        log_success "User has sudo privileges"
        CRITICAL_PASSED=$((CRITICAL_PASSED + 1))
    else
        log_critical "User lacks sudo privileges"
        CRITICAL_ISSUES+=("Current user cannot execute sudo commands")
        CRITICAL_FAILED=$((CRITICAL_FAILED + 1))
        return 1
    fi
    
    # Check SSH configuration
    check_ssh_security
    
    return 0
}

# SSH security checks
check_ssh_security() {
    local ssh_config="/etc/ssh/sshd_config"
    
    # Check if root login is disabled
    if grep -q "^PermitRootLogin no" "$ssh_config" 2>/dev/null; then
        log_success "SSH root login disabled"
        ((CRITICAL_PASSED++))
    elif grep -q "^PermitRootLogin" "$ssh_config" 2>/dev/null; then
        local root_setting=$(grep "^PermitRootLogin" "$ssh_config" | awk '{print $2}')
        log_warning "SSH root login setting: $root_setting (should be 'no')"
        WARNING_ISSUES+=("SSH root login not disabled")
        WARNING_COUNT=$((WARNING_COUNT + 1))
    else
        log_warning "SSH root login setting not explicitly configured"
        WARNING_ISSUES+=("SSH root login setting unclear")
        WARNING_COUNT=$((WARNING_COUNT + 1))
    fi
    
    # Check SSH key authentication
    if grep -q "^PubkeyAuthentication yes" "$ssh_config" 2>/dev/null; then
        log_success "SSH key authentication enabled"
        CRITICAL_PASSED=$((CRITICAL_PASSED + 1))
    else
        log_warning "SSH key authentication not explicitly enabled"
        WARNING_ISSUES+=("SSH key authentication not confirmed")
        WARNING_COUNT=$((WARNING_COUNT + 1))
    fi
    
    # Check password authentication
    if grep -q "^PasswordAuthentication no" "$ssh_config" 2>/dev/null; then
        log_success "SSH password authentication disabled"
    else
        log_warning "SSH password authentication may be enabled"
        AVAILABLE_ENHANCEMENTS+=("Disable SSH password authentication")
        ENHANCEMENT_AVAILABLE=$((ENHANCEMENT_AVAILABLE + 1))
    fi
    
    return 0
}

# Docker installation and access checks
check_docker() {
    log_section "Docker Environment Validation"
    
    # Check if Docker is installed
    if command -v docker >/dev/null 2>&1; then
        log_success "Docker installed"
        ((CRITICAL_PASSED++))
    else
        log_critical "Docker not installed"
        CRITICAL_ISSUES+=("Docker not found - install Docker first")
        ((CRITICAL_FAILED++))
        return 1
    fi
    
    # Check if Docker Compose is available
    if docker compose version >/dev/null 2>&1; then
        log_success "Docker Compose V2 available"
        ((CRITICAL_PASSED++))
    elif command -v docker-compose >/dev/null 2>&1; then
        log_warning "Docker Compose V1 detected (V2 recommended)"
        WARNING_ISSUES+=("Using older Docker Compose version")
        ((WARNING_COUNT++))
    else
        log_critical "Docker Compose not available"
        CRITICAL_ISSUES+=("Docker Compose not found")
        ((CRITICAL_FAILED++))
        return 1
    fi
    
    # Check Docker daemon access
    if docker info >/dev/null 2>&1; then
        log_success "Docker daemon accessible"
        ((CRITICAL_PASSED++))
    else
        log_critical "Cannot access Docker daemon"
        CRITICAL_ISSUES+=("Docker daemon not accessible - check permissions")
        ((CRITICAL_FAILED++))
        return 1
    fi
    
    # Check if user is in docker group
    if groups "$USER" | grep -q docker; then
        log_success "User in docker group"
    else
        log_warning "User not in docker group"
        AVAILABLE_ENHANCEMENTS+=("Add user to docker group")
        ((ENHANCEMENT_AVAILABLE++))
    fi
    
    return 0
}

# System resource checks
check_system_resources() {
    log_section "System Resources"
    
    # Check disk space
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    
    if [[ $available_gb -gt 10 ]]; then
        log_success "Sufficient disk space (${available_gb}GB available)"
    elif [[ $available_gb -gt 5 ]]; then
        log_warning "Limited disk space (${available_gb}GB available)"
        WARNING_ISSUES+=("Low disk space - consider cleanup")
        ((WARNING_COUNT++))
    else
        log_error "Insufficient disk space (${available_gb}GB available)"
        CRITICAL_ISSUES+=("Insufficient disk space - need at least 5GB")
        ((CRITICAL_FAILED++))
    fi
    
    # Check memory
    local total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_gb=$((total_mem / 1024 / 1024))
    
    if [[ $total_gb -gt 1 ]]; then
        log_success "Sufficient memory (${total_gb}GB total)"
    else
        log_warning "Limited memory (${total_gb}GB total)"
        WARNING_ISSUES+=("Low memory - some applications may need more RAM")
        ((WARNING_COUNT++))
    fi
}

# Network and firewall validation
check_firewall() {
    log_section "Firewall Protection"
    
    # Source the UFW checker if available
    if [[ -f "$SCRIPT_DIR/utils/ufw-checker.sh" ]]; then
        source "$SCRIPT_DIR/utils/ufw-checker.sh"
        if check_firewall; then
            log_success "Firewall properly configured"
            ((CRITICAL_PASSED++))
            return 0
        else
            log_critical "Firewall configuration failed"
            CRITICAL_ISSUES+=("Firewall not properly configured")
            ((CRITICAL_FAILED++))
            return 1
        fi
    else
        # Inline basic UFW check
        if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
            log_success "UFW firewall active"
            ((CRITICAL_PASSED++))
        else
            log_critical "UFW firewall not active"
            CRITICAL_ISSUES+=("UFW firewall must be configured")
            ((CRITICAL_FAILED++))
            return 1
        fi
    fi
}

# Security enhancement installations
install_fail2ban() {
    log_info "Installing fail2ban..."
    
    if apt update >/dev/null 2>&1 && apt install -y fail2ban >/dev/null 2>&1; then
        # Configure SSH jail
        cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 1800
EOF
        
        systemctl enable fail2ban >/dev/null 2>&1
        systemctl restart fail2ban >/dev/null 2>&1
        
        log_success "fail2ban installed and configured"
        return 0
    else
        log_error "Failed to install fail2ban"
        return 1
    fi
}

install_unattended_upgrades() {
    log_info "Configuring automatic security updates..."
    
    if apt install -y unattended-upgrades >/dev/null 2>&1; then
        # Configure for security updates only
        cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
        
        # Configure to only install security updates
        cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
        
        log_success "Automatic security updates configured"
        return 0
    else
        log_error "Failed to configure automatic updates"
        return 1
    fi
}

configure_ssh_hardening() {
    log_info "Applying additional SSH hardening..."
    
    # Backup current config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)
    
    # Apply hardening settings
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#*UsePAM.*/UsePAM no/' /etc/ssh/sshd_config
    
    # Test SSH config
    if sshd -t; then
        systemctl reload sshd
        log_success "SSH hardening applied"
        log_warning "Password authentication now disabled - ensure SSH keys work!"
        return 0
    else
        log_error "SSH configuration error - reverting changes"
        cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config
        return 1
    fi
}

add_user_to_docker_group() {
    log_info "Adding user to docker group..."
    
    if usermod -aG docker "$USER"; then
        log_success "User added to docker group"
        log_warning "You may need to log out and back in for changes to take effect"
        return 0
    else
        log_error "Failed to add user to docker group"
        return 1
    fi
}

# Security enhancements menu
offer_security_enhancements() {
    log_header "Security Enhancements Available"
    
    local enhancements=()
    local selections=()
    
    # Check what's available and not already installed
    if ! systemctl is-active --quiet fail2ban 2>/dev/null; then
        enhancements+=("fail2ban (SSH brute force protection)")
        selections+=(1)
    fi
    
    if ! dpkg -l | grep -q unattended-upgrades || ! [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
        enhancements+=("Automatic security updates")
        selections+=(1)
    fi
    
    if ! grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
        enhancements+=("SSH hardening (disable password authentication)")
        selections+=(0)  # Default to off for safety
    fi
    
    if ! groups "$USER" | grep -q docker; then
        enhancements+=("Add user to docker group")
        selections+=(1)
    fi
    
    if [[ ${#enhancements[@]} -eq 0 ]]; then
        log_success "All security enhancements already applied"
        return 0
    fi
    
    echo ""
    log_shield "SECURITY ENHANCEMENTS AVAILABLE:"
    echo ""
    
    for i in "${!enhancements[@]}"; do
        local enhancement="${enhancements[$i]}"
        local desc=""
        case "$enhancement" in
            *"fail2ban"*)
                desc="Automatically blocks IPs after failed login attempts"
                ;;
            *"security updates"*)
                desc="Keeps system updated with security patches"
                ;;
            *"SSH hardening"*)
                desc="Disable password authentication completely"
                ;;
            *"docker group"*)
                desc="Allows running Docker without sudo"
                ;;
        esac
        
        local num=$((i + 1))
        echo "$num) $enhancement"
        if [[ -n "$desc" ]]; then
            echo "   └─ $desc"
        fi
        echo ""
    done
    
    if ask_user "Install security enhancements?"; then
        echo ""
        select_options enhancements selections "Select which enhancements to install:"
        
        echo ""
        log_shield "Installing selected security enhancements..."
        
        local idx=0
        for enhancement in "${enhancements[@]}"; do
            if [[ ${selections[$idx]:-0} -eq 1 ]]; then
                case "$enhancement" in
                    *"fail2ban"*)
                        install_fail2ban || log_error "Failed to install fail2ban"
                        ;;
                    *"security updates"*)
                        install_unattended_upgrades || log_error "Failed to configure automatic updates"
                        ;;
                    *"SSH hardening"*)
                        configure_ssh_hardening || log_error "Failed to apply SSH hardening"
                        ;;
                    *"docker group"*)
                        add_user_to_docker_group || log_error "Failed to add user to docker group"
                        ;;
                esac
            fi
            ((idx++))
        done
    fi
}

# Final summary
show_summary() {
    log_header "Prerequisites Summary"
    
    echo ""
    if [[ $CRITICAL_FAILED -eq 0 ]]; then
        log_success "All critical requirements passed (${CRITICAL_PASSED}/${CRITICAL_PASSED})"
    else
        log_error "Critical requirements failed (${CRITICAL_FAILED} issues)"
        echo ""
        log_error "Critical Issues Found:"
        for issue in "${CRITICAL_ISSUES[@]}"; do
            echo "  ${CROSS} $issue"
        done
    fi
    
    if [[ $WARNING_COUNT -gt 0 ]]; then
        echo ""
        log_warning "Warnings (${WARNING_COUNT} items):"
        for warning in "${WARNING_ISSUES[@]}"; do
            echo "  ${WARNING} $warning"
        done
    fi
    
    echo ""
    if [[ $CRITICAL_FAILED -eq 0 ]]; then
        log_success "Server ready for Ultimate Docker Business Server setup!"
        echo ""
        log_info "Next steps:"
        echo "  1. Run: ./scripts/setup.sh"
        echo "  2. Configure your domain and SSL certificates"
        echo "  3. Install desired plugins"
        return 0
    else
        log_error "Prerequisites not met - resolve critical issues before proceeding"
        echo ""
        log_info "Common solutions:"
        echo "  • Install Docker: curl -fsSL https://get.docker.com | sh"
        echo "  • Add user to sudo: usermod -aG sudo \$USER"
        echo "  • Configure SSH key authentication"
        echo "  • Install and configure UFW firewall"
        return 1
    fi
}

# Main execution
main() {
    # Header
    log_header "${ROCKET} Ultimate Docker Business Server - Prerequisites Check"
    log_info "Validating server security and requirements..."
    
    # Run all checks
    check_user_security
    check_docker  
    check_system_resources
    check_firewall
    
    # Offer security enhancements
    offer_security_enhancements
    
    # Show final summary
    show_summary
}

# Execute main function
main "$@"