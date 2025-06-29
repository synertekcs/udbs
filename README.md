# Ultimate Docker Business Server

A production-ready, security-first Docker platform for deploying business applications with automatic SSL, reverse proxy, and a modular plugin system.

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/synertekcs/udbs.git
cd udbs

# Make scripts executable
chmod +x scripts/*.sh

# Run the setup script
./scripts/setup.sh
```

That's it! Your business server will be running with automatic SSL certificates and ready for plugin installation.

## ✨ Features

- **🔒 Security First**: UFW firewall, fail2ban, automatic security updates
- **🔐 Automatic SSL**: Let's Encrypt certificates with auto-renewal
- **🌐 Reverse Proxy**: Traefik with automatic service discovery
- **🔌 Plugin System**: Modular applications (mail servers, monitoring, etc.)
- **🛡️ Docker Security**: Socket proxy prevents direct Docker API access
- **📊 Monitoring**: Built-in logging and metrics collection
- **🔧 Easy Management**: Simple scripts for all operations

## 📋 Requirements

- **Operating System**: Ubuntu 20.04+ (other Linux distributions may work)
- **Hardware**: 2GB RAM minimum, 10GB disk space
- **Network**: Domain name pointing to your server
- **Access**: Non-root user with sudo privileges

## 🛡️ Security Prerequisites

The setup process validates and can automatically configure:

- ✅ Non-root user with sudo access
- ✅ UFW firewall with proper rules
- ✅ SSH key authentication
- ✅ Docker installation and permissions
- ✅ Optional: fail2ban, automatic updates

## 📖 Documentation

- **[Setup Guide](docs/SETUP.md)** - Detailed installation instructions
- **[Plugin Development](docs/PLUGIN_DEVELOPMENT.md)** - Create your own plugins
- **[Contributing](docs/CONTRIBUTING.md)** - Contribution guidelines
- **[Security Policy](docs/SECURITY.md)** - Security best practices

## 🔌 Available Plugins

The plugin ecosystem includes business applications such as:

- **Mail Servers**: Mailu, Mailcow
- **Monitoring**: Dozzle, Grafana, Prometheus
- **Networking**: UniFi Controller, Pi-hole
- **Storage**: Nextcloud, MinIO
- **Development**: GitLab, Jenkins, Portainer

*More plugins are added regularly by the community.*

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────┐
│   Internet      │────│   Traefik    │────│   Plugins   │
│                 │    │ Reverse Proxy│    │ (Business   │
└─────────────────┘    └──────────────┘    │ Apps)       │
                              │             └─────────────┘
                       ┌──────────────┐
                       │Socket Proxy  │
                       │(Secure API)  │
                       └──────────────┘
                              │
                       ┌──────────────┐
                       │   Docker     │
                       │   Engine     │
                       └──────────────┘
```

**Core Components:**
- **Traefik**: Automatic HTTPS, routing, and load balancing
- **Socket Proxy**: Secure Docker API access with minimal permissions
- **Plugin Network**: Isolated communication for business applications

## 🚀 Installation

### 1. Server Preparation

Ensure your server meets the security requirements:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Create non-root user (if needed)
sudo adduser yourusername
sudo usermod -aG sudo yourusername

# Set up SSH key authentication
# Configure UFW firewall
sudo ufw allow 22,80,443/tcp
sudo ufw --force enable
```

### 2. Quick Setup

```bash
# Clone and run setup
git clone https://github.com/synertekcs/udbs.git
cd udbs
chmod +x scripts/*.sh
./scripts/setup.sh
```

### 3. Access Your Services

After setup completes:

- **Your Domain**: `https://yourdomain.com`
- **Traefik Dashboard**: `https://traefik.yourdomain.com`
- **Credentials**: Saved in `secrets/` directory

## 🔌 Plugin Management

```bash
# List available plugins
./scripts/plugin list

# Install a plugin
./scripts/plugin install dozzle

# Enable/disable plugins
./scripts/plugin enable monitoring
./scripts/plugin disable old-app

# Update plugins
./scripts/plugin update
```

## 🔧 Management Commands

```bash
# View all services
docker compose ps

# View logs
docker compose logs -f

# Restart services
docker compose restart

# Stop all services
docker compose down

# Update core system
./scripts/update.sh

# Backup configuration
./scripts/backup.sh
```

## 🛠️ Development

### Creating Plugins

See [Plugin Development Guide](docs/PLUGIN_DEVELOPMENT.md) for detailed instructions.

Basic plugin structure:
```
plugins/available/myplugin/
├── plugin.yml          # Plugin metadata
├── docker-compose.yml  # Service definitions
├── .env.example        # Environment variables
└── README.md           # Documentation
```

### Contributing

We welcome contributions! Please see [CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📊 Monitoring

Built-in monitoring includes:

- **Traefik Dashboard**: Service status and metrics
- **Docker Logs**: Centralized logging via Docker
- **Health Checks**: Automatic service health monitoring
- **Optional**: Prometheus metrics, Grafana dashboards

## 🔐 Security

Security features include:

- **Firewall Protection**: UFW with restrictive rules
- **SSL/TLS**: Automatic certificates with secure defaults
- **Access Control**: Non-root containers, socket proxy
- **Updates**: Automatic security updates available
- **Monitoring**: fail2ban for intrusion prevention

See [Security Policy](docs/SECURITY.md) for more information.

## 🆘 Troubleshooting

### Common Issues

**DNS not pointing to server:**
```bash
# Check DNS resolution
dig yourdomain.com
nslookup yourdomain.com
```

**SSL certificate generation failed:**
```bash
# Check logs
docker compose logs traefik
# Ensure ports 80/443 are accessible
sudo ufw status
```

**Plugin not starting:**
```bash
# Check plugin logs
docker compose -f plugins/enabled/pluginname/docker-compose.yml logs
```

### Getting Help

- **Issues**: [GitHub Issues](https://github.com/synertekcs/udbs/issues)
- **Discussions**: [GitHub Discussions](https://github.com/synertekcs/udbs/discussions)
- **Security**: [Security Policy](docs/SECURITY.md)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Traefik](https://traefik.io/) - Amazing reverse proxy
- [Docker](https://docker.com/) - Containerization platform
- [Let's Encrypt](https://letsencrypt.org/) - Free SSL certificates
- [Tecnativa](https://github.com/Tecnativa/docker-socket-proxy) - Secure Docker socket proxy

## 🌟 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=synertekcs/udbs&type=Date)](https://star-history.com/#synertekcs/udbs&Date)

---

**Made with ❤️ for the business community**

*Ultimate Docker Business Server - Deploy. Secure. Scale.*