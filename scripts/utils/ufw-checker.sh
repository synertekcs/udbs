#!/bin/bash

# UFW Firewall Checker and Auto-Installer for Ultimate Docker Business Server

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Symbols
CHECK="✅"
CROSS="❌"
WARNING="⚠️ "
INFO="ℹ️ "
SHIELD="🛡️ "

# Logging functions
log_info() { echo -e "${BLUE}${INFO}${NC} $1"; }
log_success() { echo -e "${GREEN}${CHECK}${NC} $1"; }
log_warning() { echo -e "${YELLOW}${WARNING}${NC} $1"; }
log_error() { echo -e "${RED}${CROSS}${NC} $1"; }
log_shield() { echo -e "${BLUE}${SHIELD}${NC} $1"; }

# Get current SSH port
get_ssh_port() {
  local ssh_port
  ssh_port=$(grep -E "^Port\s+" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
  echo "${ssh_port:-22}"
}

# Check if port is in UFW rules
check_ufw_rule() {
  local port=$1
  if sudo ufw status numbered 2>/dev/null | grep -q "\[$port\]" || sudo ufw status numbered 2>/dev/null | grep -q " $port " || sudo ufw status numbered 2>/dev/null | grep -q " $port/"; then
    return 0
  else
    return 1
  fi
}

# Test dangerous ports
test_port_security() {
  local test_ports=(3306 5432 6379 27017 9999)
  local open_ports=()
  
  log_info "Testing port security..."
  
  for port in "${test_ports[@]}"; do
    if timeout 3 bash -c "</dev/tcp/localhost/$port" 2>/dev/null; then
      open_ports+=($port)
    fi
  done
  
  if [ ${#open_ports[@]} -eq 0 ]; then
    log_success "Dangerous ports properly blocked"
    return 0
  else
    log_error "Security risk: Open ports detected: ${open_ports[*]}"
    return 1
  fi
}

# Install UFW
install_ufw() {
  log_shield "Installing UFW firewall..."
  
  if ! sudo apt update >/dev/null 2>&1; then
    log_error "Failed to update package list"
    return 1
  fi
  
  if ! sudo apt install -y ufw >/dev/null 2>&1; then
    log_error "Failed to install UFW"
    return 1
  fi
  
  log_success "UFW installed successfully"
  return 0
}

# Configure UFW rules
configure_ufw() {
  local ssh_port=$1
  
  log_info "Configuring UFW rules..."
  
  sudo ufw --force reset >/dev/null 2>&1
  sudo ufw default deny incoming >/dev/null 2>&1
  sudo ufw default allow outgoing >/dev/null 2>&1
  
  if ! sudo ufw allow "$ssh_port" >/dev/null 2>&1; then
    log_error "Failed to add SSH rule for port $ssh_port"
    return 1
  fi
  log_success "SSH access preserved (port $ssh_port)"
  
  if ! sudo ufw allow 80 >/dev/null 2>&1; then
    log_error "Failed to add HTTP rule"
    return 1
  fi
  log_success "HTTP traffic allowed (port 80)"
  
  if ! sudo ufw allow 443 >/dev/null 2>&1; then
    log_error "Failed to add HTTPS rule"
    return 1
  fi
  log_success "HTTPS traffic allowed (port 443)"
  
  return 0
}

# Enable UFW
enable_ufw() {
  log_info "Activating UFW firewall..."
  
  if ! sudo ufw --force enable >/dev/null 2>&1; then
    log_error "Failed to enable UFW"
    return 1
  fi
  
  log_success "UFW firewall activated"
  return 0
}

# Show UFW status
show_ufw_status() {
  echo ""
  log_info "Current UFW status:"
  sudo ufw status numbered
  echo ""
}

# Ask user for confirmation
ask_user() {
  local prompt="$1"
  local default="${2:-Y}"
  
  if [[ "$default" == "Y" ]]; then
    read -p "$prompt [Y/n]: " response
    [[ -z "$response" || "$response" =~ ^[Yy] ]]
  else
    read -p "$prompt [y/N]: " response
    [[ "$response" =~ ^[Yy] ]]
  fi
}

# Main firewall check function
check_firewall() {
  local ssh_port
  local ufw_needs_install=false
  local ufw_needs_config=false
  
  echo ""
  log_shield "Checking Firewall Protection..."
  echo ""
  
  ssh_port=$(get_ssh_port)
  log_info "SSH running on port: $ssh_port"
  
  echo ""
  
  if ! command -v ufw >/dev/null 2>&1; then
    log_error "UFW not installed"
    ufw_needs_install=true
  else
    log_success "UFW installed"
    
    if ! sudo ufw status | grep -q "Status: active"; then
      log_error "UFW not enabled"
      ufw_needs_config=true
    else
      log_success "UFW active"
      
      local missing_rules=()
      
      if ! check_ufw_rule "$ssh_port"; then
        missing_rules+=("SSH:$ssh_port")
      fi
      
      if ! check_ufw_rule "80"; then
        missing_rules+=("HTTP:80")
      fi
      
      if ! check_ufw_rule "443"; then
        missing_rules+=("HTTPS:443")
      fi
      
      if [ ${#missing_rules[@]} -gt 0 ]; then
        log_warning "Missing UFW rules: ${missing_rules[*]}"
        ufw_needs_config=true
      else
        log_success "Required UFW rules present"
      fi
    fi
  fi
  
  echo ""
  if ! test_port_security; then
    log_warning "Some dangerous ports are open"
    ufw_needs_config=true
  fi
  
  echo ""
  if [[ "$ufw_needs_install" == true ]]; then
    log_error "SECURITY RISK: No firewall protection detected"
    echo ""
    log_shield "UFW INSTALLATION REQUIRED"
    echo ""
    echo "UFW will be configured with these rules:"
    echo "  ${CHECK} Allow SSH (port $ssh_port)"
    echo "  ${CHECK} Allow HTTP (port 80)"
    echo "  ${CHECK} Allow HTTPS (port 443)"
    echo "  ${CROSS} Deny all other incoming traffic"
    echo ""
    
    if ask_user "Install and configure UFW firewall?"; then
      echo ""
      if install_ufw && configure_ufw "$ssh_port" && enable_ufw; then
        echo ""
        log_success "Firewall successfully configured!"
        show_ufw_status
        return 0
      else
        log_error "Failed to configure firewall"
        return 1
      fi
    else
      echo ""
      log_error "UFW installation declined - SERVER REMAINS UNPROTECTED"
      log_warning "Manual firewall configuration required before proceeding"
      return 1
    fi
    
  elif [[ "$ufw_needs_config" == true ]]; then
    log_warning "UFW needs reconfiguration"
    echo ""
    
    if ask_user "Reconfigure UFW with proper rules?"; then
      echo ""
      if configure_ufw "$ssh_port" && enable_ufw; then
        echo ""
        log_success "Firewall successfully reconfigured!"
        show_ufw_status
        return 0
      else
        log_error "Failed to reconfigure firewall"
        return 1
      fi
    else
      log_warning "UFW configuration declined"
      return 1
    fi
  else
    log_success "Firewall properly configured"
    echo ""
    show_ufw_status
    return 0
  fi
}

# Main execution
main() {
  if [[ $EUID -eq 0 ]]; then
    log_error "This script should not be run as root"
    exit 1
  fi
  
  if ! sudo -n true 2>/dev/null; then
    log_error "This script requires sudo privileges"
    exit 1
  fi
  
  if check_firewall; then
    echo ""
    log_success "Firewall check completed successfully"
    exit 0
  else
    echo ""
    log_error "Firewall check failed"
    exit 1
  fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi