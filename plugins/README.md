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
