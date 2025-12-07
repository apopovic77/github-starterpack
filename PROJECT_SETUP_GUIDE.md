# Projekt Setup Guide - DevOps Workflows

**Zweck:** Komplette Anleitung für KI-Assistenten zum Aufsetzen neuer Projekte mit vollständiger DevOps-Integration.

**Author:** Alex Popovic
**Version:** 1.1
**Datum:** 2025-11-28

---

## Übersicht

Dieses Dokument beschreibt wie neue Projekte aufgesetzt werden - vom ersten Commit bis zum automatischen Deployment.

### Server-Infrastruktur

- **arkturian.com** (Linode, Ubuntu) - Production Server für Web-Apps
- **arkserver.arkturian.com** (Debian, intern) - API Server & Services
- **Lokaler Mac** (`/Volumes/DatenAP/Code/`) - Development

### Unterstützte Projekt-Typen

1. **React Web-Apps** → Deployment zu arkturian.com oder arkserver
2. **Python FastAPI Services** → Deployment zu arkserver mit OpenAPI SDK Generation
3. **Node.js APIs** → Deployment zu arkturian.com
4. **PHP Apps** → Deployment zu arkturian.com

---

## 🔑 SSH Setup & Server Zugriff

### Server Verbindungen

**Direkte SSH Verbindungen:**
```bash
# Linode Production Server (Ubuntu)
ssh root@arkturian.com

# Interner Debian Server
ssh root@arkserver
# oder vollständig:
ssh root@arkserver.arkturian.com
```

### SSH Key Setup (Initial - falls noch nicht konfiguriert)

**1. SSH Key generieren (falls noch nicht vorhanden):**
```bash
# Auf lokalem Mac
cd ~/.ssh

# Prüfen ob Key existiert
ls -la id_rsa id_rsa.pub

# Falls nicht vorhanden, generieren:
ssh-keygen -t rsa -b 4096 -C "alex@popovic.dev"
# Enter drücken für default path (~/.ssh/id_rsa)
# Passwort optional (leer lassen für automatische Deployments)
```

**2. Public Key auf Server kopieren:**
```bash
# Für arkturian.com
ssh-copy-id root@arkturian.com
# Manuell falls ssh-copy-id nicht funktioniert:
cat ~/.ssh/id_rsa.pub | ssh root@arkturian.com "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"

# Für arkserver
ssh-copy-id root@arkserver
# oder manuell:
cat ~/.ssh/id_rsa.pub | ssh root@arkserver "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

**3. SSH Zugriff testen:**
```bash
# Sollte OHNE Passwort-Eingabe funktionieren
ssh root@arkturian.com "echo 'Connection successful'"
ssh root@arkserver "echo 'Connection successful'"
```

### SSH für GitHub Actions

**GitHub Actions braucht den PRIVATEN Key als Secret:**

```bash
# 1. Private Key anzeigen
cat ~/.ssh/id_rsa

# 2. Als GitHub Secret speichern (für jedes Repo)
cd /Volumes/DatenAP/Code/mein-projekt
gh secret set DEPLOY_SSH_KEY --body "$(cat ~/.ssh/id_rsa)"

# 3. Weitere Deployment Secrets
gh secret set DEPLOY_HOST --body "arkturian.com"
# oder für arkserver:
gh secret set DEPLOY_HOST --body "arkserver"

gh secret set DEPLOY_USER --body "root"
gh secret set DEPLOY_PORT --body "22"  # optional, default ist 22
```

### SSH Config (Optional - für Aliases)

**Erstelle/editiere `~/.ssh/config`:**
```bash
nano ~/.ssh/config
```

**Inhalt:**
```ssh-config
# Linode Production Server
Host arkturian
    HostName arkturian.com
    User root
    IdentityFile ~/.ssh/id_rsa
    ServerAliveInterval 60
    ServerAliveCountMax 3

# Interner Debian Server
Host arkserver
    HostName arkserver.arkturian.com
    User root
    IdentityFile ~/.ssh/id_rsa
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

**Dann kannst du verbinden mit:**
```bash
ssh arkturian    # statt ssh root@arkturian.com
ssh arkserver    # statt ssh root@arkserver
```

### SSH Key Permissions (Wichtig!)

**Korrekte Permissions auf lokalem Mac:**
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
chmod 644 ~/.ssh/config
```

**Korrekte Permissions auf Servern:**
```bash
# Auf arkturian.com
ssh root@arkturian.com
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

# Auf arkserver
ssh root@arkserver
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
```

### Troubleshooting SSH

**Problem: "Permission denied (publickey)"**
```bash
# 1. Verbose output für debugging
ssh -v root@arkturian.com

# 2. Prüfe ob Key geladen ist
ssh-add -l

# 3. Key manuell hinzufügen
ssh-add ~/.ssh/id_rsa

# 4. Prüfe authorized_keys auf Server
ssh root@arkturian.com "cat ~/.ssh/authorized_keys"
```

**Problem: "Host key verification failed"**
```bash
# Entferne alten Host Key
ssh-keygen -R arkturian.com
ssh-keygen -R arkserver

# Neue Verbindung (akzeptiere neuen fingerprint)
ssh root@arkturian.com
```

**Problem: GitHub Actions Deployment schlägt fehl**
```bash
# 1. Prüfe Secret
gh secret list

# 2. Secret neu setzen
gh secret set DEPLOY_SSH_KEY --body "$(cat ~/.ssh/id_rsa)"

# 3. Prüfe ob public key auf Server ist
ssh root@arkturian.com "cat ~/.ssh/authorized_keys | grep -F '$(cat ~/.ssh/id_rsa.pub)'"
```

### Server Access Verification

**Checklist - Das sollte alles funktionieren:**
```bash
# ✅ Lokaler SSH Zugriff (ohne Passwort)
ssh root@arkturian.com "hostname"
ssh root@arkserver "hostname"

# ✅ Rsync Test (wie bei Deployments)
echo "test" > /tmp/test.txt
rsync -avz /tmp/test.txt root@arkturian.com:/tmp/
ssh root@arkturian.com "cat /tmp/test.txt"

# ✅ GitHub Secret gesetzt
gh secret list | grep DEPLOY_SSH_KEY

# ✅ Public Key auf beiden Servern
ssh root@arkturian.com "cat ~/.ssh/authorized_keys"
ssh root@arkserver "cat ~/.ssh/authorized_keys"
```

---

## 🎯 Quick Reference: Neues Projekt erstellen

### Für KI-Assistenten

Wenn der User sagt **"Mach eine neue API"** oder **"Mach eine React App"**, folge diesem Workflow:

1. **Projekt-Typ identifizieren** (siehe Abschnitt unten)
2. **Repository erstellen** (GitHub)
3. **Basis-Projekt aufsetzen** (Boilerplate)
4. **DevOps installieren** (github-starterpack)
5. **Server-Config erstellen** (falls Multi-Server)
6. **GitHub Secrets konfigurieren**
7. **Initial Deploy testen**

---

## 1️⃣ React Web-App (Vite/React/TypeScript)

### Use Cases
- Admin Panels (admin.arkturian.com)
- Dashboards (dashboard.arkturian.com)
- Product Finder (productfinder.arkturian.com)
- 3D Presenters (3dPresenter2)

### Initial Setup

```bash
# 1. Projekt erstellen
cd /Volumes/DatenAP/Code
npm create vite@latest mein-projekt -- --template react-ts
cd mein-projekt

# 2. Dependencies installieren
npm install
npm install -D @types/node

# 3. Git initialisieren
git init
git branch -M main
git checkout -b dev

# 4. GitHub Repo erstellen
gh repo create apopovic77/mein-projekt --private --source=. --remote=origin

# 5. Initial commit
git add .
git commit -m "Initial commit: Vite React TypeScript project"
git push -u origin dev
git push origin main

# 6. DevOps installieren
/Volumes/DatenAP/Code/github-starterpack/scripts/setup-devops.sh \
  --target /Volumes/DatenAP/Code/mein-projekt \
  --project-name "Mein Projekt" \
  --site-url https://mein-projekt.arkturian.com \
  --deploy-path /var/www/mein-projekt.arkturian.com \
  --dev-branch dev \
  --main-branch main

# 7. DevOps Files committen
git add .devops .github/workflows devops
git commit -m "Add DevOps configuration

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
git push origin dev

# 8. GitHub Secrets konfigurieren
gh secret set DEPLOY_HOST --body "arkturian.com"
gh secret set DEPLOY_USER --body "root"
gh secret set DEPLOY_SSH_KEY --body "$(cat ~/.ssh/id_rsa)"
gh secret set DEPLOY_PORT --body "22"
```

### Build Configuration

**vite.config.ts:**
```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  base: '/',
  build: {
    outDir: 'dist',
    sourcemap: false,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
        },
      },
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
})
```

### Nginx Configuration (auf Server)

```nginx
# /etc/nginx/sites-available/mein-projekt.arkturian.com
server {
    listen 80;
    server_name mein-projekt.arkturian.com;

    root /var/www/mein-projekt.arkturian.com;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

### Development Workflow

```bash
# Lokal entwickeln
npm run dev

# Zu Dev pushen
./devops push "feature: neue komponente hinzugefügt"

# Release zu Production
./devops release
# → Triggert GitHub Actions
# → Build läuft
# → Deployed zu /var/www/mein-projekt.arkturian.com
# → Nginx serviert die App
```

---

## 2️⃣ Python FastAPI mit OpenAPI SDK Generation

### Use Cases
- Storage API (storage-api.arkserver.arkturian.com)
- O'Neal API (oneal-api.arkserver.arkturian.com)
- MCP Server (mcp.arkserver.arkturian.com)
- Tracking APIs
- Data Processing Services

### Initial Setup

```bash
# 1. Projekt erstellen
cd /Volumes/DatenAP/Code
mkdir mein-api
cd mein-api

# 2. Python Struktur
cat > main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="Mein API",
    description="API Description",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health():
    return {"status": "healthy"}

@app.get("/")
async def root():
    return {"message": "Mein API v1.0.0"}
EOF

# 3. Requirements erstellen
cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
pydantic==2.5.0
python-dotenv==1.0.0
EOF

# 4. .env Template
cat > .env.example << 'EOF'
HOST=0.0.0.0
PORT=8001
DATABASE_URL=sqlite:///./data.db
EOF

cp .env.example .env

# 5. Git initialisieren
git init
git branch -M main
git checkout -b dev

cat > .gitignore << 'EOF'
__pycache__/
*.py[cod]
*$py.class
.env
venv/
.venv/
*.sqlite
*.db
.DS_Store
dist/
sdk/
EOF

# 6. GitHub Repo erstellen
gh repo create apopovic77/mein-api --private --source=. --remote=origin

# 7. Initial commit
git add .
git commit -m "Initial commit: FastAPI project"
git push -u origin dev
git push origin main

# 8. DevOps installieren
/Volumes/DatenAP/Code/github-starterpack/scripts/setup-devops.sh \
  --target /Volumes/DatenAP/Code/mein-api \
  --project-name "Mein API" \
  --site-url https://mein-api.arkserver.arkturian.com \
  --deploy-path /var/www/mein-api \
  --dev-branch dev \
  --main-branch main \
  --build-command "echo 'No build needed for Python API'"
```

### Server Configuration (Multi-Server)

**Erstelle `.devops/servers/arkserver.yaml`:**

```yaml
server:
  name: "arkserver"
  type: "python-api"
  host: "arkserver.arkturian.com"
  user: "root"
  deploy_path: "/var/www/mein-api"

service:
  type: "systemd"
  name: "mein-api"
  port: 8001

nginx:
  enabled: true
  server_name: "mein-api.arkserver.arkturian.com"
  port: 80

environment:
  HOST: "0.0.0.0"
  PORT: "8001"
  DATABASE_URL: "sqlite:////var/www/mein-api/data.db"
  # Secrets via GitHub Actions oder manuell auf Server

python:
  version: "3.11"
  requirements: "requirements.txt"
  venv_path: "venv"
  main_file: "main.py"

backup:
  enabled: true
  dir: "/var/backups"
  prefix: "mein-api"
```

### OpenAPI SDK Generation & NPM Publishing

**1. OpenAPI Generator Workflow erstellen**

Erstelle `.github/workflows/generate-sdk.yml`:

```yaml
name: Generate & Publish TypeScript SDK

on:
  push:
    branches: [main]
    paths:
      - 'main.py'
      - 'routers/**/*.py'
      - 'models/**/*.py'
  workflow_dispatch:

jobs:
  generate-sdk:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install fastapi uvicorn

      - name: Generate OpenAPI spec
        run: |
          python -c "
          from main import app
          import json
          with open('openapi.json', 'w') as f:
              json.dump(app.openapi(), f, indent=2)
          "

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          registry-url: 'https://registry.npmjs.org'

      - name: Install OpenAPI Generator
        run: npm install -g @openapitools/openapi-generator-cli

      - name: Generate TypeScript SDK
        run: |
          openapi-generator-cli generate \
            -i openapi.json \
            -g typescript-fetch \
            -o sdk \
            --additional-properties=npmName=@apopovic77/mein-api-sdk,npmVersion=1.0.0,supportsES6=true

      - name: Build SDK
        run: |
          cd sdk
          npm install
          npm run build

      - name: Publish to NPM
        run: |
          cd sdk
          npm publish --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}

      - name: Commit generated SDK
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add openapi.json
          git commit -m "chore: update OpenAPI spec [skip ci]" || true
          git push || true
```

**2. NPM Token konfigurieren:**

```bash
# NPM Token erstellen auf npmjs.com
# Dann als Secret speichern:
gh secret set NPM_TOKEN --body "npm_xxxxxxxxxxxx"
```

**3. Package.json für SDK (Template):**

Die wird automatisch generiert, aber du kannst ein Template vorbereiten:

```json
{
  "name": "@apopovic77/mein-api-sdk",
  "version": "1.0.0",
  "description": "TypeScript SDK for Mein API",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc",
    "prepublishOnly": "npm run build"
  },
  "repository": {
    "type": "git",
    "url": "https://github.com/apopovic77/mein-api.git"
  },
  "keywords": ["api", "sdk", "typescript"],
  "author": "Alex Popovic",
  "license": "MIT"
}
```

### Development Workflow (Python API)

```bash
# Lokal entwickeln
python -m venv venv
source venv/bin/activate  # oder: . venv/bin/activate
pip install -r requirements.txt

# Server starten
uvicorn main:app --reload --host 0.0.0.0 --port 8001

# OpenAPI Docs testen
open http://localhost:8001/docs

# Zu Dev pushen
./devops push "feature: neue endpoint hinzugefügt"
# → GitHub Actions generiert SDK
# → Published zu NPM als @apopovic77/mein-api-sdk

# Release zu Production
./devops release
# → Deployed zu arkserver
# → Systemd service restart
# → Health check
```

### Server Setup (Initial)

```bash
# Auf arkserver (SSH)
ssh root@arkserver.arkturian.com

# Setup via DevOps script (lokal ausführen)
cd /Volumes/DatenAP/Code/mein-api
./.devops/scripts/setup-server.sh --server arkserver

# Was passiert:
# ✅ Python venv wird erstellt
# ✅ Dependencies installiert
# ✅ Systemd service erstellt: /etc/systemd/system/mein-api.service
# ✅ Nginx config: /etc/nginx/sites-available/mein-api.arkserver.arkturian.com
# ✅ Service gestartet
# ✅ Health check
```

### Systemd Service (automatisch erstellt)

```ini
# /etc/systemd/system/mein-api.service
[Unit]
Description=Mein API Service
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/mein-api
Environment="PATH=/var/www/mein-api/venv/bin"
Environment="HOST=0.0.0.0"
Environment="PORT=8001"
ExecStart=/var/www/mein-api/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8001
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### Nginx Proxy (automatisch erstellt)

```nginx
# /etc/nginx/sites-available/mein-api.arkserver.arkturian.com
server {
    listen 80;
    server_name mein-api.arkserver.arkturian.com;

    location / {
        proxy_pass http://localhost:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 3️⃣ Node.js API (Express/Fastify)

### Initial Setup

```bash
cd /Volumes/DatenAP/Code
mkdir mein-node-api
cd mein-node-api

npm init -y
npm install express cors dotenv
npm install -D typescript @types/node @types/express ts-node nodemon

# TypeScript config
npx tsc --init

# Gleicher Workflow wie React App
# DevOps Installation mit --build-command "npm run build"
```

---

## 4️⃣ PHP App (Laravel/WordPress/Plain PHP)

### Initial Setup

```bash
cd /Volumes/DatenAP/Code

# Für Laravel
composer create-project laravel/laravel mein-php-app

# Für WordPress
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress mein-php-app

cd mein-php-app

# DevOps installieren
/Volumes/DatenAP/Code/github-starterpack/scripts/setup-devops.sh \
  --target /Volumes/DatenAP/Code/mein-php-app \
  --project-name "Mein PHP App" \
  --site-url https://mein-php-app.arkturian.com \
  --deploy-path /var/www/mein-php-app.arkturian.com \
  --build-command "echo 'No build needed for PHP'"
```

---

## 📋 Checkliste: Neues Projekt Setup

### Für jeden Projekt-Typ

- [ ] Repository auf GitHub erstellen (private)
- [ ] Lokales Git Repo initialisieren (dev + main branches)
- [ ] Projekt-spezifische Dependencies installieren
- [ ] DevOps via setup-devops.sh installieren
- [ ] .devops und .github/workflows committen
- [ ] GitHub Secrets konfigurieren:
  - [ ] `DEPLOY_HOST`
  - [ ] `DEPLOY_USER`
  - [ ] `DEPLOY_SSH_KEY`
  - [ ] `DEPLOY_PORT` (optional)
- [ ] SSH Key auf Server autorisieren
- [ ] Initial deployment testen
- [ ] Health check verifizieren

### Zusätzlich für Python APIs mit SDK

- [ ] OpenAPI SDK Workflow erstellen (`.github/workflows/generate-sdk.yml`)
- [ ] NPM Token konfigurieren (`NPM_TOKEN` Secret)
- [ ] Package.json für SDK vorbereiten
- [ ] Ersten SDK Build testen
- [ ] NPM Package verifizieren (@apopovic77/package-name)

### Zusätzlich für Multi-Server Deployments

- [ ] Server Config YAML erstellen (`.devops/servers/servername.yaml`)
- [ ] setup-server.sh ausführen für initialen Setup
- [ ] cleanup-server.sh testen (Idempotenz)
- [ ] deploy-to-server.sh testen

---

## 🔧 Server Management Commands

### React/Node.js Apps

```bash
# Lokal
./devops build              # Build testen
./devops push "msg"         # Zu dev pushen
./devops release            # Deploy zu production

# Server (via SSH)
ssh root@arkturian.com
systemctl restart nginx
systemctl status nginx
```

### Python APIs

```bash
# Lokal
./devops push "msg"         # Zu dev pushen
./devops release            # Deploy zu production

# Server Management (lokal)
cd /Volumes/DatenAP/Code/mein-api
./.devops/scripts/setup-server.sh --server arkserver      # Initial setup
./.devops/scripts/deploy-to-server.sh --server arkserver  # Deploy
./.devops/scripts/cleanup-server.sh --server arkserver    # Remove

# Server (via SSH)
ssh root@arkserver.arkturian.com
systemctl status mein-api
systemctl restart mein-api
journalctl -u mein-api -f     # Logs folgen
```

---

## 🌐 Domain & DNS Setup

### Neue Subdomain hinzufügen

**Für arkturian.com (React Apps):**
```bash
# DNS A Record (bei Linode/Domain-Provider)
mein-projekt.arkturian.com → IP von arkturian.com

# Nginx auf Server
ssh root@arkturian.com
nano /etc/nginx/sites-available/mein-projekt.arkturian.com
ln -s /etc/nginx/sites-available/mein-projekt.arkturian.com /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
```

**Für arkserver.arkturian.com (Python APIs):**
```bash
# DNS A Record oder CNAME
mein-api.arkserver.arkturian.com → IP von arkserver

# Nginx wird automatisch konfiguriert via setup-server.sh
```

---

## 🔐 Secrets Management

### GitHub Secrets (Repository)

```bash
# Für jedes neue Repo
cd /Volumes/DatenAP/Code/mein-projekt

gh secret set DEPLOY_HOST --body "arkturian.com"
gh secret set DEPLOY_USER --body "root"
gh secret set DEPLOY_SSH_KEY --body "$(cat ~/.ssh/id_rsa)"
gh secret set DEPLOY_PORT --body "22"

# Für Python APIs mit SDK
gh secret set NPM_TOKEN --body "npm_xxxxxxxxxxxx"

# Für APIs mit Datenbanken
gh secret set DATABASE_URL --body "postgresql://..."
gh secret set OPENAI_API_KEY --body "sk-..."
```

### Environment Variables auf Server

**Option 1: Via .devops/servers/server.yaml** (Recommended)
```yaml
environment:
  DATABASE_URL: "sqlite:///./data.db"
  OPENAI_API_KEY: "{{SECRET}}"  # Wird auf Server manuell gesetzt
```

**Option 2: Direkt in systemd service**
```bash
ssh root@arkserver
systemctl edit mein-api

# Füge hinzu:
[Service]
Environment="SECRET_KEY=xxx"
```

---

## 📊 Monitoring & Health Checks

### Alle Projekte checken

```bash
cd /Volumes/DatenAP/Code/github-starterpack/devops-tools
./scripts/check-devops-repos.sh
./scripts/health-check-all.sh
```

### Single Project Health Check

```bash
# React Apps
curl https://mein-projekt.arkturian.com

# Python APIs
curl https://mein-api.arkserver.arkturian.com/health
curl https://mein-api.arkserver.arkturian.com/docs  # OpenAPI Docs
```

---

## 🚨 Troubleshooting

### Deployment Failed

```bash
# Check GitHub Actions
gh run list
gh run view [run-id]

# Check logs
gh run view [run-id] --log
```

### Service nicht erreichbar (Python API)

```bash
ssh root@arkserver

# Service status
systemctl status mein-api

# Logs
journalctl -u mein-api -n 50
journalctl -u mein-api -f

# Service neu starten
systemctl restart mein-api

# Nginx status
systemctl status nginx
nginx -t
```

### SDK Generation Failed

```bash
# OpenAPI spec lokal generieren
python -c "
from main import app
import json
with open('openapi.json', 'w') as f:
    json.dump(app.openapi(), f, indent=2)
"

# OpenAPI spec checken
cat openapi.json | jq

# SDK manuell generieren
npx @openapitools/openapi-generator-cli generate \
  -i openapi.json \
  -g typescript-fetch \
  -o sdk
```

---

## 🎯 KI Assistant Instructions

### Wenn User sagt: "Mach eine neue React App"

1. Frage nach Namen und Subdomain
2. Folge Abschnitt "1️⃣ React Web-App"
3. Erstelle Vite React TypeScript Projekt
4. Installiere DevOps
5. Erstelle Initial Commit
6. Push zu GitHub
7. Konfiguriere Secrets
8. Test deployment mit `./devops release`
9. Verifiziere: `curl https://[subdomain].arkturian.com`

### Wenn User sagt: "Mach eine neue Python API"

1. Frage nach Namen, Subdomain, und ob SDK gebraucht wird
2. Folge Abschnitt "2️⃣ Python FastAPI"
3. Erstelle FastAPI Projekt mit main.py
4. Installiere DevOps
5. Erstelle Server Config (`.devops/servers/arkserver.yaml`)
6. Falls SDK gewünscht: Erstelle SDK Workflow
7. Erstelle Initial Commit
8. Push zu GitHub
9. Konfiguriere Secrets (inkl. NPM_TOKEN falls SDK)
10. Setup Server: `./.devops/scripts/setup-server.sh --server arkserver`
11. Verifiziere: `curl https://[subdomain].arkserver.arkturian.com/health`
12. Falls SDK: Verifiziere NPM Package

### Wichtige Pfade

- **Repos:** `/Volumes/DatenAP/Code/`
- **Starterpack:** `/Volumes/DatenAP/Code/github-starterpack`
- **Setup Script:** `/Volumes/DatenAP/Code/github-starterpack/scripts/setup-devops.sh`

### Standard Werte

- **Dev Branch:** `dev`
- **Main Branch:** `main`
- **React Build:** `npm run build`
- **Python Build:** `echo 'No build needed'`
- **Node Version:** `20`
- **Python Version:** `3.11`

---

## 📚 Weitere Ressourcen

- **GitHub Starterpack README:** `/Volumes/DatenAP/Code/github-starterpack/README.md`
- **Multi-Server Plan:** `/Volumes/DatenAP/Code/github-starterpack/MULTI_SERVER_DEPLOYMENT_PLAN.md`
- **DevOps Tools:** `/Volumes/DatenAP/Code/github-starterpack/devops-tools/README.md`

---

**Version History:**
- v1.1 (2025-11-28): Added comprehensive SSH setup and troubleshooting section
- v1.0 (2025-11-28): Initial version mit React, Python API, SDK Generation

**Maintainer:** Alex Popovic (@apopovic77)
