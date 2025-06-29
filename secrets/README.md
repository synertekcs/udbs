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
