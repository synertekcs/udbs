#!/bin/bash

# Ultimate Docker Business Server - Main Setup Script
# Orchestrates the complete server setup process

set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration files
ENV_FILE="$PROJECT_ROOT/.env"
ENV_EXAMPLE="$PROJECT_ROOT/.env.example"
DOCKER_COMPOSE_MAIN="$PROJECT_ROOT/docker-compose.yml"
DOCKER_COMPOSE_BOOTSTRAP="$PROJECT_ROOT/docker-compose.bootstrap.yml"

# Data directories
DATA_DIR="$PROJECT_ROOT/data"
CONFIG_DIR="$PROJECT_ROOT/config"
TRAEFIK_DIR="$CONFIG_DIR/traefik"
ACME_DIR="$DATA_DIR/acme"
SECRETS_DIR="$PROJECT_ROOT/secrets"

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
CERT="🔐"
DOCKER="🐳"

# Setup state tracking
SETUP_STATE_FILE="$DATA_DIR/.setup_state"

# Logging functions
log_header() { echo -e "\n${BOLD}${BLUE}$1${NC}"; }
log_section() { echo -e "\n${CYAN}${GEAR}${NC} ${BOLD}$1${NC}"; }
log_info() { echo -e "${BLUE}${INFO}${NC} $1"; }
log_success() { echo -e "${GREEN}${CHECK}${NC} $1"; }
log_warning() { echo -e "${YELLOW}${WARNING}${NC} $1"; }
log_error() { echo -e "${RED}${CROSS}${NC} $1"; }
log_docker() { echo -e "${BLUE}${DOCKER}${NC} $1"; }
log_cert() { echo -e "${PURPLE}${CERT}${NC} $1"; }

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

# Validate email format
validate_email() {
    local email="$1"
    [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]
}

# Validate domain format
validate_domain() {
    local domain="$1"
    [[ "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}$ ]]
}

# Test DNS resolution
test_dns_resolution() {
    local domain="$1"
    local server_ip
    
    # Get current server's public IP
    server_ip=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "unknown")
    
    if [[ "$server_ip" == "unknown" ]]; then
        log_warning "Could not determine server's public IP"
        return 1
    fi
    
    # Check if domain resolves to this server
    local resolved_ip
    resolved_ip=$(dig +short "$domain" 2>/dev/null | tail -n1)
    
    if [[ "$resolved_ip" == "$server_ip" ]]; then
        log_success "DNS correctly points to this server ($server_ip)"
        return 0
    else
        log_warning "DNS resolution issue:"
        log_info "  Domain $domain resolves to: ${resolved_ip:-'no result'}"
        log_info "  This server's IP: $server_ip"
        return 1
    fi
}

# Check port availability
check_port_availability() {
    local port="$1"
    local service="$2"
    
    if ss -tulpn | grep ":$port " >/dev/null 2>&1; then
        log_error "Port $port ($service) is already in use"
        return 1
    else
        log_success "Port $port ($service) available"
        return 0
    fi
}

# Create directory structure
create_directories() {
    log_section "Creating Directory Structure"
    
    local dirs=(
        "$DATA_DIR"
        "$CONFIG_DIR"
        "$TRAEFIK_DIR"
        "$ACME_DIR"
        "$SECRETS_DIR"
        "$PROJECT_ROOT/plugins/available"
        "$PROJECT_ROOT/plugins/enabled"
    )
    
    for dir in "${dirs[@]}"; do
        if mkdir -p "$dir"; then
            log_success "Created: $dir"
        else
            log_error "Failed to create: $dir"
            return 1
        fi
    done
    
    # Set secure permissions on secrets directory
    chmod 700 "$SECRETS_DIR"
    log_success "Set secure permissions on secrets directory"
    
    return 0
}

# Generate secure random strings
generate_secret() {
    openssl rand -hex 32
}

# Create Docker secrets
create_docker_secrets() {
    log_section "Creating Docker Secrets"
    
    # Traefik dashboard password
    local traefik_password
    traefik_password=$(generate_secret)
    echo "$traefik_password" > "$SECRETS_DIR/traefik_dashboard_password"
    
    # Socket proxy access token (future use)
    local socket_token
    socket_token=$(generate_secret)
    echo "$socket_token" > "$SECRETS_DIR/socket_proxy_token"
    
    # Set secure permissions
    chmod 600 "$SECRETS_DIR"/*
    
    log_success "Docker secrets created"
    log_info "Traefik dashboard password saved to secrets/"
    
    return 0
}

# Gather user configuration
gather_configuration() {
    log_section "Configuration Setup"
    
    # Domain configuration
    while true; do
        echo ""
        read -p "Enter your primary domain (e.g., yourbusiness.com): " DOMAIN
        
        if validate_domain "$DOMAIN"; then
            log_success "Domain format valid: $DOMAIN"
            break
        else
            log_error "Invalid domain format. Please try again."
        fi
    done
    
    # Email for Let's Encrypt
    while true; do
        echo ""
        read -p "Enter email for SSL certificates (Let's Encrypt): " EMAIL
        
        if validate_email "$EMAIL"; then
            log_success "Email format valid: $EMAIL"
            break
        else
            log_error "Invalid email format. Please try again."
        fi
    done
    
    # SSL Certificate method
    echo ""
    log_info "SSL Certificate Options:"
    echo "  [1] HTTP Challenge (Recommended - Simple setup)"
    echo "  [2] DNS Challenge (Advanced - Requires DNS provider API)"
    echo "  [3] Custom certificates (Enterprise - Bring your own)"
    echo ""
    
    while true; do
        read -p "Select certificate method [1]: " CERT_METHOD
        CERT_METHOD=${CERT_METHOD:-1}
        
        case "$CERT_METHOD" in
            1)
                CERT_RESOLVER="letsencrypt-http"
                log_success "HTTP Challenge selected"
                break
                ;;
            2)
                CERT_RESOLVER="letsencrypt-dns"
                log_success "DNS Challenge selected (will configure DNS provider)"
                # TODO: Add DNS provider configuration
                log_warning "DNS Challenge setup will be added in future version"
                log_info "Falling back to HTTP Challenge for now"
                CERT_RESOLVER="letsencrypt-http"
                break
                ;;
            3)
                CERT_RESOLVER="custom"
                log_success "Custom certificates selected"
                log_warning "Custom certificate setup will be added in future version"
                log_info "Falling back to HTTP Challenge for now"
                CERT_RESOLVER="letsencrypt-http"
                break
                ;;
            *)
                log_error "Invalid choice. Please select 1, 2, or 3."
                ;;
        esac
    done
    
    # Test DNS resolution
    echo ""
    log_info "Testing DNS resolution for $DOMAIN..."
    if ! test_dns_resolution "$DOMAIN"; then
        echo ""
        log_warning "DNS may not be properly configured"
        if ! ask_user "Continue anyway? (You can fix DNS and restart later)" "N"; then
            log_error "Setup cancelled. Please configure DNS and try again."
            exit 1
        fi
    fi
    
    return 0
}

# Create environment file
create_environment_file() {
    log_section "Creating Environment Configuration"
    
    cat > "$ENV_FILE" << EOF
# Ultimate Docker Business Server Configuration
# Generated on $(date)

# Domain Configuration
DOMAIN=$DOMAIN
EMAIL=$EMAIL

# SSL Configuration
CERT_RESOLVER=$CERT_RESOLVER

# Traefik Configuration
TRAEFIK_DASHBOARD_DOMAIN=traefik.$DOMAIN
TRAEFIK_LOG_LEVEL=INFO

# Socket Proxy Configuration
SOCKET_PROXY_LOG_LEVEL=info

# Network Configuration
TRAEFIK_NETWORK=traefik
SOCKET_PROXY_NETWORK=socket-proxy

# Data Paths
DATA_PATH=./data
CONFIG_PATH=./config
SECRETS_PATH=./secrets

# Let's Encrypt Configuration
ACME_EMAIL=$EMAIL
ACME_STORAGE=/etc/traefik/acme/acme.json

# Development/Staging
TRAEFIK_STAGING=${TRAEFIK_STAGING:-false}
EOF
    
    log_success "Environment file created: .env"
    
    # Create example file for reference
    cp "$ENV_FILE" "$ENV_EXAMPLE"
    log_success "Example file created: .env.example"
    
    return 0
}

# Create Traefik configuration
create_traefik_config() {
    log_section "Creating Traefik Configuration"
    
    # Main Traefik configuration
    cat > "$TRAEFIK_DIR/traefik.yml" << EOF
# Traefik Configuration for Ultimate Docker Business Server

# API and Dashboard
api:
  dashboard: true
  debug: false

# Entry Points
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entrypoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

# Certificate Resolvers
certificatesResolvers:
  letsencrypt-http:
    acme:
      email: $EMAIL
      storage: /etc/traefik/acme/acme.json
      httpChallenge:
        entryPoint: web
      # caServer: https://acme-staging-v02.api.letsencrypt.org/directory # Staging

# Providers
providers:
  docker:
    endpoint: "tcp://socket-proxy:2375"
    exposedByDefault: false
    network: traefik
  file:
    filename: /etc/traefik/dynamic.yml
    watch: true

# Logging
log:
  level: INFO
  
accessLog: {}

# Metrics (optional)
metrics:
  prometheus:
    buckets:
      - 0.1
      - 0.3
      - 1.2
      - 5.0
EOF
    
    # Dynamic configuration for dashboard
    cat > "$TRAEFIK_DIR/dynamic.yml" << EOF
# Dynamic Traefik Configuration

http:
  middlewares:
    dashboard-auth:
      basicAuth:
        usersFile: "/etc/traefik/dashboard-users"
    
    security-headers:
      headers:
        frameDeny: true
        sslRedirect: true
        browserXssFilter: true
        contentTypeNosniff: true
        forceSTSHeader: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000
        customRequestHeaders:
          X-Forwarded-Proto: "https"

  routers:
    traefik-dashboard:
      rule: "Host(\`traefik.$DOMAIN\`)"
      service: "api@internal"
      middlewares:
        - "dashboard-auth"
        - "security-headers"
      tls:
        certResolver: "$CERT_RESOLVER"

# TLS Configuration
tls:
  options:
    default:
      minVersion: "VersionTLS12"
      cipherSuites:
        - "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
        - "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305"
        - "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
EOF
    
    # Create dashboard users file (htpasswd format)
    local dashboard_password
    dashboard_password=$(cat "$SECRETS_DIR/traefik_dashboard_password")
    local dashboard_hash
    dashboard_hash=$(openssl passwd -apr1 "$dashboard_password")
    echo "admin:$dashboard_hash" > "$TRAEFIK_DIR/dashboard-users"
    
    # Create empty acme.json with correct permissions
    touch "$ACME_DIR/acme.json"
    chmod 600 "$ACME_DIR/acme.json"
    
    log_success "Traefik configuration created"
    log_info "Dashboard will be available at: https://traefik.$DOMAIN"
    log_info "Dashboard credentials: admin / [saved in secrets/]"
    
    return 0
}

# Create Docker Compose files
create_docker_compose_files() {
    log_section "Creating Docker Compose Files"
    
    # Bootstrap compose file (for certificate generation)
    cat > "$DOCKER_COMPOSE_BOOTSTRAP" << EOF
# Bootstrap Configuration for Certificate Generation
version: '3.8'

services:
  traefik-bootstrap:
    image: traefik:v3.0
    container_name: traefik-bootstrap
    ports:
      - "80:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./config/traefik:/etc/traefik:ro
      - ./data/acme:/etc/traefik/acme
    environment:
      - TRAEFIK_LOG_LEVEL=INFO
      - TRAEFIK_API=false
      - TRAEFIK_PROVIDERS_DOCKER=false
    command:
      - "--providers.file.filename=/etc/traefik/bootstrap.yml"
      - "--entrypoints.web.address=:80"
      - "--certificatesresolvers.$CERT_RESOLVER.acme.email=$EMAIL"
      - "--certificatesresolvers.$CERT_RESOLVER.acme.storage=/etc/traefik/acme/acme.json"
      - "--certificatesresolvers.$CERT_RESOLVER.acme.httpchallenge.entrypoint=web"
    networks:
      - bootstrap

networks:
  bootstrap:
    driver: bridge
EOF
    
    # Bootstrap Traefik config
    cat > "$TRAEFIK_DIR/bootstrap.yml" << EOF
# Bootstrap configuration for certificate generation only
http:
  routers:
    bootstrap-cert:
      rule: "Host(\`$DOMAIN\`) || Host(\`traefik.$DOMAIN\`)"
      service: "noop@internal"
      tls:
        certResolver: "$CERT_RESOLVER"
EOF
    
    # Main production compose file
    cat > "$DOCKER_COMPOSE_MAIN" << EOF
# Ultimate Docker Business Server - Main Configuration
version: '3.8'

services:
  # Socket Proxy - Secure Docker Socket Access
  socket-proxy:
    image: tecnativa/docker-socket-proxy:latest
    container_name: socket-proxy
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      # Traefik permissions
      CONTAINERS: 1
      SERVICES: 1
      NETWORKS: 1
      TASKS: 1
      # Deny dangerous permissions
      VOLUMES: 0
      IMAGES: 0
      INFO: 0
      BUILD: 0
      COMMIT: 0
      CONFIG: 0
      DISTRIBUTION: 0
      EXEC: 0
      GRPC: 0
      PLUGINS: 0
      POST: 0
      SECRETS: 0
      SESSION: 0
      SWARM: 0
      SYSTEM: 0
      VERSION: 0
    networks:
      - socket-proxy
    ports:
      - "127.0.0.1:2375:2375"  # Only accessible from localhost

  # Traefik Reverse Proxy
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    depends_on:
      - socket-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./config/traefik:/etc/traefik:ro
      - acme-data:/etc/traefik/acme
    environment:
      - TRAEFIK_LOG_LEVEL=\${TRAEFIK_LOG_LEVEL:-INFO}
    networks:
      - traefik
      - socket-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(\`traefik.\${DOMAIN}\`)"
      - "traefik.http.routers.traefik.tls.certresolver=\${CERT_RESOLVER}"
      - "traefik.http.routers.traefik.service=api@internal"
    healthcheck:
      test: ["CMD", "traefik", "healthcheck"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  traefik:
    name: traefik
    driver: bridge
  socket-proxy:
    name: socket-proxy
    driver: bridge
    internal: true

volumes:
  acme-data:
    driver: local
EOF
    
    log_success "Docker Compose files created"
    
    return 0
}

# Check port availability before starting
check_ports() {
    log_section "Checking Port Availability"
    
    local ports_ok=true
    
    if ! check_port_availability 80 "HTTP"; then
        ports_ok=false
    fi
    
    if ! check_port_availability 443 "HTTPS"; then
        ports_ok=false
    fi
    
    if [[ "$ports_ok" == false ]]; then
        log_error "Required ports are not available"
        log_info "Stop services using ports 80 and 443, then try again"
        return 1
    fi
    
    return 0
}

# Bootstrap certificates
bootstrap_certificates() {
    log_section "Bootstrap SSL Certificates"
    
    log_cert "Starting certificate generation process..."
    log_info "This may take a few minutes..."
    
    # Start bootstrap containers
    if ! docker compose -f "$DOCKER_COMPOSE_BOOTSTRAP" up -d; then
        log_error "Failed to start bootstrap containers"
        return 1
    fi
    
    log_docker "Bootstrap containers started"
    
    # Wait for certificate generation
    local max_attempts=60
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if [[ -s "$ACME_DIR/acme.json" ]] && grep -q "$DOMAIN" "$ACME_DIR/acme.json" 2>/dev/null; then
            log_success "SSL certificates generated successfully!"
            break
        fi
        
        ((attempt++))
        echo -n "."
        sleep 5
    done
    
    echo ""
    
    if [[ $attempt -eq $max_attempts ]]; then
        log_error "Certificate generation timed out"
        log_info "Check DNS configuration and try again"
        docker compose -f "$DOCKER_COMPOSE_BOOTSTRAP" logs
        docker compose -f "$DOCKER_COMPOSE_BOOTSTRAP" down
        return 1
    fi
    
    # Stop bootstrap containers
    log_docker "Stopping bootstrap containers..."
    docker compose -f "$DOCKER_COMPOSE_BOOTSTRAP" down
    
    log_success "Certificate bootstrap completed"
    
    return 0
}

# Start main services
start_main_services() {
    log_section "Starting Main Services"
    
    log_docker "Starting Ultimate Docker Business Server..."
    
    if ! docker compose -f "$DOCKER_COMPOSE_MAIN" up -d; then
        log_error "Failed to start main services"
        return 1
    fi
    
    log_success "Main services started successfully"
    
    # Wait for services to be healthy
    log_info "Waiting for services to be ready..."
    sleep 10
    
    # Check service status
    if docker compose -f "$DOCKER_COMPOSE_MAIN" ps | grep -q "unhealthy\|exited"; then
        log_warning "Some services may not be healthy"
        docker compose -f "$DOCKER_COMPOSE_MAIN" ps
    else
        log_success "All services are running"
    fi
    
    return 0
}

# Save setup state
save_setup_state() {
    cat > "$SETUP_STATE_FILE" << EOF
# Setup completion state
SETUP_COMPLETED=true
SETUP_DATE=$(date -Iseconds)
DOMAIN=$DOMAIN
EMAIL=$EMAIL
CERT_RESOLVER=$CERT_RESOLVER
VERSION=1.0.0
EOF
    
    log_success "Setup state saved"
}

# Show completion summary
show_completion_summary() {
    log_header "${ROCKET} Setup Complete!"
    
    echo ""
    log_success "Ultimate Docker Business Server is now running!"
    echo ""
    
    log_info "🌐 Your Services:"
    echo "  • Main domain: https://$DOMAIN"
    echo "  • Traefik dashboard: https://traefik.$DOMAIN"
    echo "    └─ Username: admin"
    echo "    └─ Password: (saved in secrets/traefik_dashboard_password)"
    echo ""
    
    log_info "📋 Next Steps:"
    echo "  1. Verify services are accessible"
    echo "  2. Install plugins: ./scripts/plugin list"
    echo "  3. Configure backups: ./scripts/backup.sh"
    echo "  4. Review security settings"
    echo ""
    
    log_info "🔧 Management Commands:"
    echo "  • View logs: docker compose logs -f"
    echo "  • Restart services: docker compose restart"
    echo "  • Stop services: docker compose down"
    echo "  • Update system: ./scripts/update.sh"
    echo ""
    
    local dashboard_password
    dashboard_password=$(cat "$SECRETS_DIR/traefik_dashboard_password" 2>/dev/null || echo "check secrets file")
    echo "🔐 Important: Save your dashboard password: $dashboard_password"
    echo ""
    
    log_success "Welcome to Ultimate Docker Business Server!"
}

# Cleanup on failure
cleanup_on_failure() {
    log_error "Setup failed. Cleaning up..."
    
    # Stop any running containers
    docker compose -f "$DOCKER_COMPOSE_BOOTSTRAP" down 2>/dev/null || true
    docker compose -f "$DOCKER_COMPOSE_MAIN" down 2>/dev/null || true
    
    # Remove setup state
    rm -f "$SETUP_STATE_FILE"
    
    log_info "Cleanup completed. You can run setup again after fixing issues."
}

# Check if already set up
check_existing_setup() {
    if [[ -f "$SETUP_STATE_FILE" ]]; then
        log_warning "Setup appears to have been run previously"
        
        if ask_user "Do you want to run setup again? (This will overwrite current configuration)" "N"; then
            log_info "Proceeding with fresh setup..."
            return 0
        else
            log_info "Setup cancelled. Use ./scripts/plugin to manage applications."
            exit 0
        fi
    fi
}

# Main setup function
main() {
    # Trap for cleanup on failure
    trap cleanup_on_failure ERR
    
    # Header
    log_header "${ROCKET} Ultimate Docker Business Server - Setup"
    log_info "Initializing your business server environment..."
    
    # Check for existing setup
    check_existing_setup
    
    # Run prerequisites check
    log_header "Step 1: Prerequisites Validation"
    if [[ -f "$SCRIPT_DIR/prerequisites.sh" ]]; then
        if ! "$SCRIPT_DIR/prerequisites.sh"; then
            log_error "Prerequisites check failed. Please resolve issues and try again."
            exit 1
        fi
    else
        log_warning "Prerequisites script not found. Proceeding anyway."
    fi
    
    # Gather configuration
    log_header "Step 2: Configuration"
    gather_configuration
    
    # Create directory structure
    log_header "Step 3: Infrastructure Setup"
    create_directories
    create_docker_secrets
    create_environment_file
    
    # Create configurations
    log_header "Step 4: Service Configuration"
    create_traefik_config
    create_docker_compose_files
    
    # Check ports and bootstrap
    log_header "Step 5: Service Deployment"
    check_ports
    
    if [[ "$CERT_RESOLVER" == "letsencrypt-http" ]]; then
        bootstrap_certificates
    fi
    
    start_main_services
    
    # Finalize setup
    log_header "Step 6: Finalization"
    save_setup_state
    
    # Show completion
    show_completion_summary
}

# Execute main function
main "$@"