#!/bin/bash

# Ultimate Docker Business Server - Project Structure Creator
# This script creates the complete directory structure for the project

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Symbols
CHECK="✅"
INFO="ℹ️ "
FOLDER="📁"

# Project name
PROJECT_NAME="udbs"

# Get current directory or use provided argument
PROJECT_DIR="${1:-$PROJECT_NAME}"

echo -e "${BLUE}${FOLDER} Creating UDBS (Ultimate Docker Business Server) project structure...${NC}\n"

# Create main project directory
if [[ ! -d "$PROJECT_DIR" ]]; then
    mkdir -p "$PROJECT_DIR"
    echo -e "${GREEN}${CHECK}${NC} Created project directory: $PROJECT_DIR"
else
    echo -e "${YELLOW}${INFO}${NC} Project directory already exists: $PROJECT_DIR"
fi

cd "$PROJECT_DIR"

# Define directory structure
directories=(
    "scripts"
    "scripts/utils"
    "config"
    "config/traefik"
    "data"
    "data/acme"
    "secrets"
    "plugins"
    "plugins/available"
    "plugins/available/template"
    "plugins/available/template/scripts"
    "plugins/available/template/config"
    "plugins/available/template/docs"
    "plugins/enabled"
    "docs"
    "backups"
    "logs"
)

# Create directories
echo -e "\n${BLUE}Creating directories:${NC}"
for dir in "${directories[@]}"; do
    if mkdir -p "$dir" 2>/dev/null; then
        echo -e "${GREEN}${CHECK}${NC} $dir"
    else
        echo -e "${YELLOW}${INFO}${NC} $dir (already exists)"
    fi
done

# Create .gitkeep files for empty directories that should be tracked
gitkeep_dirs=(
    "data"
    "secrets"
    "plugins/available"
    "plugins/enabled"
    "config/traefik"
    "backups"
    "logs"
)

echo -e "\n${BLUE}Creating .gitkeep files:${NC}"
for dir in "${gitkeep_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        touch "$dir/.gitkeep"
        echo -e "${GREEN}${CHECK}${NC} $dir/.gitkeep"
    fi
done

# Set secure permissions on sensitive directories
echo -e "\n${BLUE}Setting secure permissions:${NC}"
chmod 700 secrets
echo -e "${GREEN}${CHECK}${NC} secrets/ (700 - owner only)"

chmod 755 scripts scripts/utils
echo -e "${GREEN}${CHECK}${NC} scripts/ (755 - executable)"

chmod 644 data/.gitkeep plugins/*/.gitkeep config/*/.gitkeep 2>/dev/null || true

# Create README files for important directories
echo -e "\n${BLUE}Creating directory README files:${NC}"

# Data directory README
cat > data/README.md << 'EOF'
# Data Directory

This directory contains persistent data for the Ultimate Docker Business Server.

## Structure

- `acme/` - SSL certificates from Let's Encrypt
- `traefik/` - Traefik configuration and state
- `plugins/` - Plugin-specific data volumes

## Backup

This directory should be included in regular backups as it contains:
- SSL certificates
- Application data
- Configuration state

## Security

- Files in this directory may contain sensitive information
- Ensure proper permissions (readable only by docker user)
- Do not commit actual data files to version control
EOF

# Secrets directory README
cat > secrets/README.md << 'EOF'
# Secrets Directory

This directory contains sensitive configuration data and passwords.

## Security Notice

⚠️ **IMPORTANT**: 
- Never commit files from this directory to version control
- This directory is in .gitignore for security
- Permissions are set to 700 (owner only)

## Contents

- `traefik_dashboard_password` - Traefik dashboard admin password
- `socket_proxy_token` - Socket proxy access token
- Plugin-specific secrets and API keys

## Usage

Secrets are mounted into containers as Docker secrets or environment variables.
EOF

# Config directory README
cat > config/README.md << 'EOF'
# Configuration Directory

This directory contains configuration files for core services.

## Structure

- `traefik/` - Traefik reverse proxy configuration
- Plugin-specific configuration files

## Notes

- Configuration files are generated during setup
- Some files may be created dynamically
- Template files are safe to commit, generated files may contain secrets
EOF

# Plugins directory README
cat > plugins/README.md << 'EOF'
# Plugins Directory

This directory contains the plugin system for Ultimate Docker Business Server.

## Structure

- `available/` - All available plugins
- `enabled/` - Symlinks to enabled plugins
- `template/` - Plugin development template

## Plugin Management

Use the plugin management script:
```bash
./scripts/plugin list
./scripts/plugin install <name>
./scripts/plugin enable <name>
./scripts/plugin disable <name>
```

## Development

See `available/template/` for plugin development guidelines.
EOF

echo -e "${GREEN}${CHECK}${NC} Directory README files created"

# Create initial placeholder files
echo -e "\n${BLUE}Creating placeholder files:${NC}"

# Create empty acme.json with correct permissions
touch data/acme/acme.json
chmod 600 data/acme/acme.json
echo -e "${GREEN}${CHECK}${NC} data/acme/acme.json (600 permissions)"

# Summary
echo -e "\n${GREEN}${CHECK} Project structure created successfully!${NC}"
echo -e "\n${BLUE}Next steps:${NC}"
echo "1. Copy your script files to scripts/"
echo "2. Copy configuration templates to appropriate directories"
echo "3. Initialize git repository:"
echo "   git init"
echo "   git add ."
echo "   git commit -m 'Initial project structure'"
echo ""
echo "4. Create GitHub repository and push:"
echo "   git branch develop"
echo "   git remote add origin https://github.com/yourusername/udbs.git"
echo "   git push -u origin main"
echo "   git push -u origin develop"
echo ""
echo -e "${YELLOW}${INFO}${NC} Don't forget to:"
echo "- Update README.md with your GitHub username"
echo "- Add your actual scripts to scripts/"
echo "- Create the plugin template files"
echo "- Set up your .env.example file"

# Display created structure
echo -e "\n${BLUE}Created structure:${NC}"
find . -type d | head -20 | sort
