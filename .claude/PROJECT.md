# GitHub Starterpack - DevOps Framework

**Repository:** github-starterpack
**Zweck:** Zentrales DevOps Framework für alle Projekte (React, Python, Node.js, PHP)
**Location:** `/Volumes/DatenAP/Code/github-starterpack`

---

## Was ist dieses Projekt?

Dies ist das **zentrale DevOps Framework** das für ALLE anderen Projekte verwendet wird.

Es enthält:
- Templates für `.devops/` und `.github/workflows/`
- Setup Scripts (`setup-devops.sh`)
- Multi-Server Deployment Scripts
- Cross-Project DevOps Tools
- Komplette Dokumentation

**Wichtig:** Änderungen hier betreffen ALLE Projekte die DevOps nutzen!

---

## Projekt-Struktur

```
github-starterpack/
├── scripts/
│   └── setup-devops.sh           # Main Installer
├── templates/
│   ├── devops/                   # .devops Templates
│   │   ├── scripts/
│   │   │   ├── setup-server.sh
│   │   │   ├── deploy-to-server.sh
│   │   │   ├── cleanup-server.sh
│   │   │   ├── build-local.sh
│   │   │   ├── release.sh
│   │   │   └── ...
│   │   ├── servers/
│   │   │   ├── example-python-api.yaml
│   │   │   └── README.md
│   │   ├── deploy.sh
│   │   ├── rollback.sh
│   │   └── *.md
│   ├── github/                   # GitHub Actions Templates
│   ├── github-npm/               # Node.js specific workflows
│   ├── github-php/               # PHP specific workflows
│   ├── github-test/              # Playwright test workflows
│   └── root/
│       └── devops                # Dispatcher script
├── devops-tools/                 # Cross-project utilities
│   ├── scripts/
│   │   ├── check-devops-repos.sh
│   │   ├── health-check-all.sh
│   │   └── sync-devops-config.sh
│   └── README.md
├── PROJECT_SETUP_GUIDE.md        # **HAUPT-DOKUMENTATION**
├── MULTI_SERVER_DEPLOYMENT_PLAN.md
├── README.md
└── .github/workflows/
    ├── ci.yml
    └── release.yml
```

---

## Wichtige Dateien

### 📚 Dokumentation
- **`PROJECT_SETUP_GUIDE.md`** - Komplette Anleitung für neue Projekte (React, Python, etc.)
- **`README.md`** - Framework Übersicht
- **`MULTI_SERVER_DEPLOYMENT_PLAN.md`** - Multi-Server Features

### 🔧 Scripts
- **`scripts/setup-devops.sh`** - Installer der Templates in Projekte kopiert

### 📋 Templates
- **`templates/devops/`** - Alle DevOps Scripts & Configs
- **`templates/github/`** - GitHub Actions Workflows
- **`templates/root/devops`** - Dispatcher Script

### 🛠️ DevOps Tools
- **`devops-tools/scripts/`** - Cross-project Management Tools

---

## Verwendung

### Template in neues Projekt installieren

```bash
# Von diesem Repo aus
cd /Volumes/DatenAP/Code/github-starterpack

# In ein Projekt installieren
./scripts/setup-devops.sh \
  --target /Volumes/DatenAP/Code/mein-projekt \
  --project-name "Mein Projekt" \
  --site-url https://mein-projekt.arkturian.com \
  --deploy-path /var/www/mein-projekt
```

### Templates updaten

```bash
# Änderungen in templates/ machen
cd /Volumes/DatenAP/Code/github-starterpack

# Edit templates...
nano templates/devops/scripts/deploy-to-server.sh

# In bestehendes Projekt re-applyen
./scripts/setup-devops.sh \
  --target /Volumes/DatenAP/Code/mein-projekt \
  --update
```

### DevOps Tools verwenden

```bash
cd /Volumes/DatenAP/Code/github-starterpack/devops-tools

# Check alle Repos
./scripts/check-devops-repos.sh

# Health check alle deployed Services
./scripts/health-check-all.sh

# Sync configs
./scripts/sync-devops-config.sh
```

---

## Workflow wenn Templates geändert werden

**Wichtig:** Änderungen hier müssen in alle Projekte propagiert werden!

1. **Template ändern**
   ```bash
   cd /Volumes/DatenAP/Code/github-starterpack
   nano templates/devops/scripts/deploy-to-server.sh
   ```

2. **Testen in einem Projekt**
   ```bash
   ./scripts/setup-devops.sh \
     --target /Volumes/DatenAP/Code/storage-api \
     --update

   cd /Volumes/DatenAP/Code/storage-api
   ./.devops/scripts/deploy-to-server.sh --server arkserver
   ```

3. **Wenn OK → Commit in starterpack**
   ```bash
   cd /Volumes/DatenAP/Code/github-starterpack
   git add templates/
   git commit -m "fix: improved deploy-to-server error handling"
   git push origin dev
   ```

4. **Rollout zu allen Projekten**
   ```bash
   # Liste aller Projekte mit DevOps
   ./devops-tools/scripts/check-devops-repos.sh

   # Für jedes Projekt:
   cd /Volumes/DatenAP/Code/projekt-name
   ./devops update
   ```

---

## Development Workflow (für dieses Repo selbst)

```bash
cd /Volumes/DatenAP/Code/github-starterpack

# Änderungen machen
# ...

# Committen
git add .
git commit -m "feature: neue template features"
git push origin main

# Testen in einem Projekt
cd /Volumes/DatenAP/Code/storage-api
./devops update
```

---

## Neue Features hinzufügen

### Neues DevOps Script hinzufügen

1. **Script in templates erstellen:**
   ```bash
   nano templates/devops/scripts/mein-neues-script.sh
   chmod +x templates/devops/scripts/mein-neues-script.sh
   ```

2. **setup-devops.sh updaten** (falls nötig)
   ```bash
   nano scripts/setup-devops.sh
   # Füge copy command hinzu
   ```

3. **Dokumentation updaten:**
   ```bash
   nano PROJECT_SETUP_GUIDE.md
   # Füge Usage hinzu
   ```

4. **Testen & Committen**

### Neue GitHub Workflow hinzufügen

1. **Workflow in templates erstellen:**
   ```bash
   nano templates/github/workflows/mein-workflow.yml
   ```

2. **setup-devops.sh updaten**
3. **In Projekt testen**
4. **Committen**

---

## Testing

### Test Setup in neues Projekt

```bash
# 1. Test Projekt erstellen
cd /tmp
mkdir test-project
cd test-project
git init

# 2. DevOps installieren
/Volumes/DatenAP/Code/github-starterpack/scripts/setup-devops.sh \
  --target $(pwd) \
  --project-name "Test Project" \
  --site-url https://test.example.com \
  --non-interactive

# 3. Verifizieren
ls -la .devops/
ls -la .github/workflows/
./devops help

# 4. Cleanup
cd /tmp
rm -rf test-project
```

### Test Multi-Server Deployment

```bash
# 1. Python API Setup testen
cd /Volumes/DatenAP/Code/storage-api

# 2. Cleanup
./.devops/scripts/cleanup-server.sh --server arkserver --force

# 3. Fresh Setup
./.devops/scripts/setup-server.sh --server arkserver

# 4. Health Check
curl http://arkserver:8001/health

# 5. Deploy testen
./.devops/scripts/deploy-to-server.sh --server arkserver
```

---

## Wichtige Konzepte

### Auto-Detection

setup-devops.sh erkennt automatisch:
- **Playwright:** `playwright.config.ts` vorhanden
- **PHP:** `composer.json` oder `*.php` files
- **Python:** `requirements.txt` + `main.py`
- **Node.js:** `package.json`

Entsprechend werden die richtigen Templates verwendet.

### Placeholder Replacement

setup-devops.sh ersetzt Placeholders:
- `{{PROJECT_NAME}}` → Projekt Name
- `{{SITE_URL}}` → Site URL
- `{{DEPLOY_PATH}}` → Deploy Path
- `{{BUILD_COMMAND}}` → Build Command
- etc.

### YAML-based Server Configs

Für Multi-Server Deployments:
```yaml
server:
  name: "arkserver"
  host: "arkserver"
  deploy_path: "/var/www/api"

service:
  type: "systemd"
  name: "api"
  port: 8001

python:
  version: "3.11"
  requirements: "requirements.txt"
```

---

## Rollout Plan für Updates

Wenn Templates geändert werden:

1. **High Priority** (sofort updaten):
   - storage-api
   - oneal-api
   - mcp-server

2. **Medium Priority** (diese Woche):
   - admin.arkturian.com
   - dashboard.arkturian.com

3. **Low Priority** (nächste Woche):
   - Andere Projekte

**Command für Rollout:**
```bash
cd /Volumes/DatenAP/Code/projekt-name
./devops update
git diff  # Review changes
git add .devops .github/workflows
git commit -m "chore: update devops scripts"
git push origin dev
```

---

## Troubleshooting

### Problem: setup-devops.sh schlägt fehl

```bash
# Debug Mode
bash -x scripts/setup-devops.sh --target /path/to/project
```

### Problem: Templates werden nicht kopiert

```bash
# Prüfe ob Templates existieren
ls -la templates/devops/
ls -la templates/github/

# Prüfe Permissions
chmod +x scripts/setup-devops.sh
chmod +x templates/devops/scripts/*.sh
```

### Problem: Projekt erkennt falschen Typ

```bash
# Override mit flags
./scripts/setup-devops.sh \
  --target /path/to/project \
  --build-command "npm run build" \
  --install-deps "npm ci"
```

---

## Wichtige Regeln für dieses Repo

1. **Niemals Breaking Changes** ohne Migration Path
2. **Immer Backward Compatible** - alte Projekte müssen weiterhin funktionieren
3. **Dokumentation updaten** bei jeder Änderung
4. **Testen in mindestens 2 Projekten** bevor rollout
5. **Version Bumps** in PROJECT_SETUP_GUIDE.md dokumentieren

---

## Nächste Features (Backlog)

- [ ] Docker Support
- [ ] Kubernetes Templates
- [ ] Automated Testing für Scripts
- [ ] Visual Studio Code Extensions Integration
- [ ] Automated Rollout Tool (update all repos at once)
- [ ] Health Monitoring Dashboard

---

**Letzte Aktualisierung:** 2025-11-28
**Maintainer:** Alex Popovic (@apopovic77)
