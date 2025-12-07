# DevOps Tools & Scripts

Zentrale Sammlung von DevOps Scripts, Templates und Tools für alle Projekte.

## Struktur

```
devops-tools/
├── scripts/           # Utility scripts
│   ├── check-devops-repos.sh
│   ├── setup-new-server.sh
│   └── ...
├── templates/         # Config templates
│   ├── github-workflows/
│   ├── nginx/
│   └── systemd/
└── docs/             # Documentation
    └── deployment-guides/
```

## Scripts

### Repository Management

- **`check-devops-repos.sh`** - Scannt alle Repos mit .devops Implementation
- **`sync-devops-config.sh`** - Synced .devops configs über alle Repos

### Server Setup

- **`setup-new-server.sh`** - Automated server provisioning
- **`deploy-to-server.sh`** - Generic deployment script

### Monitoring

- **`health-check-all.sh`** - Health checks für alle Server
- **`backup-databases.sh`** - Database backup automation

## Usage

```bash
# Run scripts from github-starterpack directory
cd /Volumes/DatenAP/Code/github-starterpack
./devops-tools/scripts/check-devops-repos.sh

# Or run directly with full path
/Volumes/DatenAP/Code/github-starterpack/devops-tools/scripts/check-devops-repos.sh

# Add to PATH (optional)
export PATH="$PATH:/Volumes/DatenAP/Code/github-starterpack/devops-tools/scripts"
```

## Adding New Scripts

1. Create script in `scripts/` directory
2. Make executable: `chmod +x scripts/your-script.sh`
3. Add documentation to this README
4. Commit and push

## Templates

Templates für häufig verwendete Configs:

- **GitHub Actions workflows**
- **Nginx reverse proxy configs**
- **systemd service files**
- **.env file templates**

## Best Practices

- Scripts sollten idempotent sein (mehrfach ausführbar)
- Immer error handling (`set -e`)
- Colored output für bessere UX
- Confirmation prompts für destructive operations
- Logging für troubleshooting
