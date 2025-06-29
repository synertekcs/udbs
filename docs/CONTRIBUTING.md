# Contributing to Ultimate Docker Business Server

Thank you for your interest in contributing to Ultimate Docker Business Server! We welcome contributions from the community, whether it's bug reports, feature requests, documentation improvements, or new plugins.

## 🤝 How to Contribute

### Reporting Issues

1. **Check existing issues** first to avoid duplicates
2. **Use issue templates** when available
3. **Provide detailed information**:
   - Operating system and version
   - Docker version
   - Steps to reproduce
   - Expected vs actual behavior
   - Relevant logs or screenshots

### Suggesting Features

1. **Check the roadmap** and existing feature requests
2. **Open a discussion** before implementing large features
3. **Provide use cases** and business justification
4. **Consider backward compatibility**

### Code Contributions

1. **Fork the repository**
2. **Create a feature branch** from `develop`
3. **Make your changes** following our coding standards
4. **Test thoroughly** including edge cases
5. **Submit a pull request** with detailed description

## 🏗️ Development Setup

### Prerequisites

- Ubuntu 20.04+ (or compatible Linux distribution)
- Docker and Docker Compose
- Git
- Text editor or IDE

### Local Development Environment

```bash
# Clone your fork
git clone https://github.com/yourusername/ultimate-docker-business-server.git
cd ultimate-docker-business-server

# Set up development branch
git checkout develop
git pull origin develop

# Create feature branch
git checkout -b feature/your-feature-name

# Set up development environment
cp .env.example .env.dev
# Edit .env.dev with development settings

# Test the setup
./scripts/prerequisites.sh
./scripts/setup.sh
```

### Development Workflow

1. **Make changes** in your feature branch
2. **Test locally** using the development environment
3. **Run validation scripts** before committing
4. **Commit with clear messages** following conventional commits
5. **Push to your fork** and create a pull request

## 📝 Coding Standards

### Shell Scripts

- **Use bash shebang**: `#!/bin/bash`
- **Enable strict mode**: `set -euo pipefail`
- **Quote variables**: `"$variable"` not `$variable`
- **Use meaningful function names**
- **Add comments** for complex logic
- **Follow existing code style**

```bash
#!/bin/bash
set -euo pipefail

# Good example
check_docker_installation() {
    local docker_version
    
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker not installed"
        return 1
    fi
    
    docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    log_success "Docker ${docker_version} detected"
    
    return 0
}
```

### Docker Compose

- **Use version 3.8+**
- **Consistent indentation** (2 spaces)
- **Meaningful service names**
- **Resource limits** where appropriate
- **Health checks** for all services
- **Proper network isolation**

```yaml
# Good example
services:
  web-service:
    image: nginx:alpine
    container_name: ${SERVICE_NAME}-web
    restart: unless-stopped
    
    networks:
      - traefik
      - internal
    
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${SERVICE_NAME}.rule=Host(`${SERVICE_DOMAIN}`)"
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### Documentation

- **Use clear, concise language**
- **Include code examples**
- **Update relevant docs** with code changes
- **Use consistent formatting**
- **Test all examples**

## 🔌 Plugin Development

### Plugin Guidelines

1. **Follow plugin template** structure
2. **Complete plugin.yml** metadata
3. **Provide comprehensive README**
4. **Include environment examples**
5. **Implement health checks**
6. **Use semantic versioning**

### Plugin Requirements

- **Security**: Non-root containers, minimal privileges
- **Networking**: Use Traefik network for web services
- **Data**: Persistent volumes for data storage
- **Monitoring**: Health checks and metrics endpoints
- **Documentation**: Clear installation and usage instructions

### Plugin Submission Process

1. **Create plugin** following the template
2. **Test thoroughly** in development environment
3. **Submit pull request** to `plugins/available/`
4. **Respond to review** feedback promptly
5. **Maintain plugin** after acceptance

## 🧪 Testing

### Manual Testing

Before submitting:

1. **Fresh installation** test on clean system
2. **Upgrade scenarios** from previous versions
3. **Plugin installation** and removal
4. **Security validation** with prerequisites check
5. **Documentation accuracy** verification

### Automated Testing

We're working on automated testing. Future requirements:

- Unit tests for shell functions
- Integration tests for Docker Compose
- Security scanning for containers
- Documentation link checking

## 📋 Pull Request Guidelines

### Before Submitting

- [ ] **Code follows** project standards
- [ ] **Tests pass** (when available)
- [ ] **Documentation updated** if needed
- [ ] **CHANGELOG updated** for user-facing changes
- [ ] **No merge conflicts** with develop branch

### Pull Request Template

```markdown
## Description
Brief description of changes and motivation.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update
- [ ] Plugin addition

## Testing
- [ ] Tested on fresh Ubuntu installation
- [ ] Tested upgrade scenarios
- [ ] Tested with existing plugins
- [ ] Security validation completed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or clearly documented)
```

## 🏷️ Commit Message Format

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description

[optional body]

[optional footer]
```

### Examples

```bash
feat(plugins): add dozzle log viewer plugin
fix(traefik): resolve SSL certificate renewal issue
docs(readme): update installation instructions
chore(deps): update traefik to v3.0.1
```

### Types

- **feat**: New features
- **fix**: Bug fixes
- **docs**: Documentation changes
- **style**: Code style changes
- **refactor**: Code refactoring
- **test**: Adding or updating tests
- **chore**: Maintenance tasks

## 🚀 Release Process

### Versioning

We use [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Workflow

1. **Feature freeze** on develop branch
2. **Create release branch** from develop
3. **Final testing** and bug fixes
4. **Update version numbers** and changelog
5. **Merge to main** and tag release
6. **Deploy to production** environments

## 🛡️ Security

### Security Policy

- **Report vulnerabilities** privately via email
- **No public disclosure** until patch available
- **Security updates** get priority treatment
- **CVE tracking** for significant issues

### Secure Development

- **Input validation** for all user inputs
- **Secrets management** using Docker secrets
- **Minimal privileges** for all containers
- **Regular dependency** updates
- **Security scanning** of container images

## 📞 Getting Help

### Community Support

- **GitHub Discussions**: General questions and ideas
- **GitHub Issues**: Bug reports and feature requests
- **Discord/Slack**: Real-time community chat (if available)

### Maintainer Contact

- **Email**: maintainers@ultimate-docker-business-server.com
- **Response time**: Usually within 48 hours
- **Priority**: Security issues get immediate attention

## 🎯 Roadmap

### Current Priorities

1. **Plugin ecosystem** expansion
2. **Automated testing** implementation
3. **Monitoring improvements**
4. **Performance optimization**
5. **Documentation enhancement**

### Future Goals

- **Multi-architecture** support (ARM64)
- **Kubernetes** deployment option
- **Advanced monitoring** with alerting
- **Plugin marketplace** with ratings
- **Enterprise features** for larger deployments

## 🙏 Recognition

Contributors are recognized through:

- **Contributors list** in README
- **Release notes** acknowledgments
- **Special recognition** for significant contributions
- **Maintainer status** for consistent contributors

Thank you for contributing to Ultimate Docker Business Server! Together, we're building the best platform for business Docker deployments.

---

**Questions?** Feel free to ask in [GitHub Discussions](https://github.com/yourusername/ultimate-docker-business-server/discussions)!