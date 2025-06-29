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
