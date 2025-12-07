# Multi-Server Deployment Plan

**Status:** ✅ Completed
**Created:** 2025-10-29
**Completed:** 2025-10-29
**Objective:** Erweitere github-starterpack für Multi-Server Deployments (arkserver, arkturian.com, weitere)

---

## 🎯 Ziele

1. **Multi-Server Support** - Deployment zu verschiedenen Servern (nicht nur ein fixer DEPLOY_PATH)
2. **Initial Server Setup** - Automatisiertes Server-Provisioning für neue Instanzen
3. **Wiederholbare Deployments** - Cleanup + Setup muss idempotent sein
4. **Zentrale Orchestrierung** - Ein Script um alle Services auf einmal zu deployen

---

## 📊 Status Quo Analysis

### ✅ Was bereits existiert

**github-starterpack Struktur:**
```
github-starterpack/
├── templates/devops/          # .devops Templates für Projekte
│   ├── deploy.sh              # Deployment Script (FEST verdrahtet zu einem Server)
│   ├── rollback.sh
│   ├── scripts/
│   │   ├── build-local.sh
│   │   ├── release.sh
│   │   └── ...
│   └── *.md                   # Dokumentation
├── devops-tools/              # Cross-project utilities
│   ├── scripts/
│   │   ├── check-devops-repos.sh
│   │   ├── health-check-all.sh
│   │   └── sync-devops-config.sh
│   └── README.md
├── scripts/
│   └── setup-devops.sh        # Installer für Templates
└── README.md
```

**Aktuelles Deployment-Modell:**
- `deploy.sh` deployed zu **einem festen Server** (via DEPLOY_PATH Placeholder)
- Konfiguration erfolgt beim Setup via `setup-devops.sh --deploy-path /var/www/...`
- GitHub Actions deployen automatisch zu diesem Server
- Funktioniert perfekt für **Single-Server Deployments**

### ❌ Was fehlt

1. **Multi-Server Configuration**
   - Keine Möglichkeit denselben Code zu mehreren Servern zu deployen
   - Keine Server-spezifischen Configs (.env, ports, domains)

2. **Initial Server Setup**
   - deploy.sh setzt voraus dass Server bereits konfiguriert ist
   - Keine Scripts für Python venv setup, systemd services, nginx configs

3. **Environment-Aware Deployments**
   - Keine Unterscheidung zwischen dev/staging/prod Servern
   - Keine Server-Registry

4. **Cleanup/Teardown**
   - Keine Scripts zum Entfernen von Deployments
   - Kann nicht testen ob Setup wirklich idempotent ist

---

## 🏗️ Architektur Design

### Multi-Server Configuration Model

Jedes Projekt bekommt Server-Configs in `.devops/servers/`:

```
project/.devops/
├── servers/
│   ├── arkturian.yaml         # arkturian.com (Linode)
│   ├── arkserver.yaml         # arkserver (intern)
│   ├── staging.yaml           # Optional staging server
│   └── README.md
├── scripts/
│   ├── deploy-to-server.sh    # NEU: Multi-server deploy
│   ├── setup-server.sh        # NEU: Initial server setup
│   ├── cleanup-server.sh      # NEU: Remove deployment
│   └── ... (existing scripts)
└── deploy.sh                  # Legacy: deployed zu default server
```

### Server Config Format (YAML)

```yaml
# .devops/servers/arkserver.yaml
server:
  name: "arkserver"
  type: "python-api"  # oder: node, php, static
  host: "arkserver"
  user: "root"
  deploy_path: "/var/www/storage-api"

service:
  type: "systemd"
  name: "storage-api"
  port: 8001

nginx:
  enabled: true
  server_name: "storage-api.arkserver.arkturian.com"
  port: 80

environment:
  DATABASE_URL: "sqlite:////var/www/storage-api/storage.db"
  OPENAI_API_KEY: "{{SECRET}}"
  HOST: "0.0.0.0"
  PORT: "8001"

python:
  version: "3.11"
  requirements: "requirements.txt"
  venv_path: "venv"

backup:
  enabled: true
  dir: "/var/backups"
  prefix: "storage-api"
```

---

## 🚀 Implementation Plan

### Phase 1: Core Multi-Server Scripts ✅ Priority

**1.1 Create `deploy-to-server.sh`**
```bash
# Usage: ./deploy-to-server.sh --server arkserver
# Reads .devops/servers/arkserver.yaml
# Deployes code zu diesem Server
```

**Features:**
- ✅ Lädt Server-Config aus YAML
- ✅ Baut Projekt (falls nötig)
- ✅ Erstellt Backup
- ✅ Rsync zu Server
- ✅ Restart Service
- ✅ Health Check

**1.2 Create `setup-server.sh`**
```bash
# Usage: ./setup-server.sh --server arkserver --initial
# Initial Server Provisioning
```

**Features:**
- ✅ Python venv setup
- ✅ Install dependencies
- ✅ Create systemd service
- ✅ Create nginx config
- ✅ Set permissions
- ✅ Enable & start services

**1.3 Create `cleanup-server.sh`**
```bash
# Usage: ./cleanup-server.sh --server arkserver
# Removes deployment completely
```

**Features:**
- ✅ Stop systemd service
- ✅ Disable service
- ✅ Remove nginx config
- ✅ Remove deploy directory
- ✅ Remove backups (optional)

---

### Phase 2: Templates & Installer Updates

**2.1 Update `templates/devops/` Structure**
```
templates/devops/
├── servers/
│   ├── example-python.yaml
│   ├── example-node.yaml
│   └── example-php.yaml
├── scripts/
│   ├── deploy-to-server.sh     # NEU
│   ├── setup-server.sh         # NEU
│   ├── cleanup-server.sh       # NEU
│   └── ... (existing)
└── ...
```

**2.2 Update `setup-devops.sh` Installer**
- ✅ Kopiert neue Scripts
- ✅ Fragt nach Primary Server (default: arkturian.com)
- ✅ Erstellt initiale Server-Config
- ✅ Legacy deploy.sh bleibt kompatibel

---

### Phase 3: Orchestration Scripts

**3.1 Create Stack Deployment Script**
```bash
# devops-tools/scripts/deploy-stack.sh
# Deployed mehrere Services auf einmal zu einem Server
```

**Example:**
```bash
./deploy-stack.sh \
  --server arkserver \
  --services storage-api,oneal-api,mcp-server
```

**3.2 Create Test Cycle Script**
```bash
# devops-tools/scripts/test-deployment-cycle.sh
# 1. Cleanup all
# 2. Setup all
# 3. Health check
# 4. Cleanup again
# 5. Setup again (test idempotency)
```

---

### Phase 4: Python API Server Templates

**4.1 Python Service Templates**

Neue Templates in `templates/`:
- `systemd/python-api.service.j2`
- `nginx/python-api.conf.j2`
- `scripts/setup-python-api.sh`

**4.2 Project Type Detection**

Update `setup-devops.sh`:
```bash
detect_project_type() {
  if [ -f "requirements.txt" ] && [ -f "main.py" ]; then
    echo "python-api"
  elif [ -f "package.json" ]; then
    echo "node"
  # ...
}
```

---

## 📝 Concrete Action Items

### Immediate (Today)

- [x] Create this plan document
- [ ] Create `deploy-to-server.sh` template
- [ ] Create `setup-server.sh` template
- [ ] Create `cleanup-server.sh` template
- [ ] Add YAML parsing (use yq or pure bash)
- [ ] Test with storage-api on arkserver

### Short-term (This Week)

- [ ] Update github-starterpack templates
- [ ] Test full deployment cycle
- [ ] Create documentation
- [ ] Deploy to arkserver (storage-api, oneal-api, mcp-server)

### Medium-term (Next Week)

- [ ] Rollout to all repos with .devops
- [ ] Update CI/CD workflows for multi-server
- [ ] Create health monitoring
- [ ] Implement automated testing

---

## 🎯 Test Cases

### Test 1: Fresh Server Setup
```bash
# Given: Fresh arkserver with nothing installed
cd /Volumes/DatenAP/Code/storage-api
./.devops/scripts/setup-server.sh --server arkserver --initial

# Expected:
# ✅ Python venv created
# ✅ Dependencies installed
# ✅ systemd service running
# ✅ nginx configured
# ✅ Health check passes
```

### Test 2: Deployment
```bash
# Given: Server is already set up
./.devops/scripts/deploy-to-server.sh --server arkserver

# Expected:
# ✅ Code deployed
# ✅ Service restarted
# ✅ Health check passes
```

### Test 3: Cleanup & Re-setup
```bash
# Cleanup
./.devops/scripts/cleanup-server.sh --server arkserver

# Verify removed
curl http://storage-api.arkserver.arkturian.com/health
# Expected: Connection refused

# Re-setup
./.devops/scripts/setup-server.sh --server arkserver --initial

# Verify works again
curl http://storage-api.arkserver.arkturian.com/health
# Expected: {"status":"healthy"}
```

### Test 4: Multi-Service Stack
```bash
cd /Volumes/DatenAP/Code/github-starterpack/devops-tools
./scripts/deploy-stack.sh \
  --server arkserver \
  --services storage-api,oneal-api,mcp-server

# Expected:
# ✅ All 3 services deployed
# ✅ All health checks pass
# ✅ Nginx configs created
```

---

## 📚 Documentation Updates

Update these files:
- [ ] `github-starterpack/README.md` - Add multi-server section
- [ ] `devops-tools/README.md` - Add new scripts
- [ ] `templates/devops/SETUP.md` - Multi-server setup guide
- [ ] New: `MULTI_SERVER_GUIDE.md` - Comprehensive guide

---

## 🔄 Migration Path for Existing Repos

### Option 1: Gradual Migration
1. Keep existing deploy.sh
2. Add new server configs
3. Test with new scripts
4. Migrate CI/CD when ready

### Option 2: Clean Migration
1. Run `./devops update` in each repo
2. Create server configs
3. Test manually
4. Update GitHub Actions

---

## 🚨 Breaking Changes

### None!
- Legacy deploy.sh bleibt kompatibel
- Neue Scripts sind optional
- Bestehende CI/CD workflows funktionieren weiter

---

## 📊 Affected Repositories

### Python APIs
- ✅ storage-api (Priority 1)
- ✅ mcp-server (Priority 1)
- ✅ oneal-api (Priority 1)
- api-ai
- artrack-api

### Node.js Apps
- admin.arkturian.com
- dashboard.arkturian.com
- share.arkturian.com
- productfinder
- 3dPresenter2

### PHP Apps
- artrack.arkturian.com

---

## 🎓 Learning & Notes

### Key Insights
1. **Idempotenz ist kritisch** - Scripts müssen mehrfach laufen können
2. **YAML > .env** - Strukturierte Configs sind besser wartbar
3. **Backup vor Cleanup** - Immer Backups vor destructive operations
4. **Health Checks** - Verify everything after deployment

### Technical Decisions
- **YAML Format**: Nutze `yq` für parsing (oder pure bash fallback)
- **Systemd**: Standard für Service Management
- **Nginx**: Standard für Reverse Proxy
- **Rsync**: Bewährt für File Transfer

---

## 🔗 Related Files

- `/Volumes/DatenAP/Code/github-starterpack/README.md` - Main documentation
- `/Volumes/DatenAP/Code/github-starterpack/devops-tools/README.md` - DevOps tools
- `/Volumes/DatenAP/Code/storage-api/.devops/` - Example deployment

---

## ✅ Success Criteria

Deployment gilt als erfolgreich wenn:

1. **Setup ist wiederholbar**
   ```bash
   ./cleanup-server.sh --server arkserver
   ./setup-server.sh --server arkserver
   # Works without errors
   ```

2. **Alle Services laufen**
   ```bash
   curl http://storage-api.arkserver.arkturian.com/health
   curl http://oneal-api.arkserver.arkturian.com/v1/ping
   curl http://mcp.arkserver.arkturian.com/health
   # All return success
   ```

3. **Deployment ist schnell**
   - Setup: < 5 Minuten
   - Deploy: < 2 Minuten
   - Cleanup: < 1 Minute

4. **CI/CD funktioniert**
   - GitHub Actions deployed automatisch
   - Multi-server workflows möglich

---

## 📅 Timeline

- **Week 1** (Today): Core scripts + testing
- **Week 2**: Rollout to all repos
- **Week 3**: Documentation + training
- **Week 4**: Monitoring + optimization

---

## ✅ Implementation Results

### Completed Tasks

1. ✅ **Core Scripts Created**
   - `setup-server.sh` - Initial server provisioning
   - `deploy-to-server.sh` - Deployment to specific server
   - `cleanup-server.sh` - Complete removal from server
   - All scripts made executable and copied to github-starterpack

2. ✅ **YAML Configuration System**
   - Server config format defined in `.devops/servers/*.yaml`
   - Environment variables properly injected into systemd services
   - Example configs created (example-python-api.yaml)

3. ✅ **storage-api Test Case**
   - arkserver.yaml config created with complete environment
   - Successfully tested cleanup → setup cycle (idempotent)
   - Service running: `http://arkserver:8001/health` ✅

4. ✅ **Requirements.txt Fixed**
   - Added missing dependencies: `databases`, `aiosqlite`, `aiofiles`, `piexif`, `passlib`, `python-dotenv`
   - All dependencies install cleanly

### Test Results (arkserver)

**Idempotency Test:**
```bash
# Test 1: Initial cleanup
./cleanup-server.sh --server arkserver --force
✅ Service stopped
✅ Service disabled
✅ Service file removed
✅ Nginx configuration removed
✅ Deployed files removed

# Test 2: Fresh setup
./setup-server.sh --server arkserver
✅ Configuration loaded
✅ Python environment ready
✅ Systemd service created and started
✅ Nginx configured
✅ Service is running
✅ HTTP health check passed

# Test 3: Second cleanup (idempotency check)
./cleanup-server.sh --server arkserver --force
✅ Service stopped
✅ Service disabled
✅ Service file removed
✅ Nginx configuration removed
✅ Deployed files removed

# Test 4: Second setup (idempotency check)
./setup-server.sh --server arkserver
✅ Configuration loaded
✅ Python environment ready
✅ Systemd service created and started
✅ Nginx configured
✅ Service is running
✅ HTTP health check passed
```

**Conclusion:** Scripts are fully idempotent and repeatable ✅

### Files Created

**github-starterpack/templates/devops/scripts/**
- `setup-server.sh` (290 lines)
- `deploy-to-server.sh` (278 lines)
- `cleanup-server.sh` (245 lines)

**github-starterpack/templates/devops/servers/**
- `example-python-api.yaml`
- `README.md`

**storage-api/.devops/servers/**
- `arkserver.yaml`

### Next Steps

1. **Rollout to other projects:**
   - Copy scripts to oneal-api
   - Copy scripts to mcp-server
   - Create server configs for each

2. **Documentation:**
   - Update github-starterpack README with multi-server feature
   - Add usage examples
   - Document YAML format

3. **CI/CD Integration:**
   - Update GitHub Actions workflows for multi-server support
   - Add deployment matrix for different environments

---

**Status:** Implementation complete, ready for rollout to other projects
