# github-python Templates — Python FastAPI auf arkserver

Workflows für Python-APIs (FastAPI, uvicorn, systemd) auf dem self-hosted Runner.

## Blueprint
Live-Vorlage: `apopovic77/finance-api`. Deploy-Muster identisch mit `conversation-api`, `person-api`, `settings-api`.

## Erzeugte Workflows
- `.github/workflows/deploy.yml` — Push auf `main` → SSH zum Server → `git fetch/reset` → venv rebuild → `systemctl restart <service>` → Health-Loop auf `http://127.0.0.1:<port><health>`.
- `.github/workflows/dev.yml` — Push auf `dev` oder PR auf `main` → venv + `pytest -q`.

Beide Jobs laufen auf `runs-on: [self-hosted, linux, arkserver]`. **Niemals** `ubuntu-latest` (Konto gesperrt).

## Platzhalter die `setup-devops.sh` ersetzt
- `{{MAIN_BRANCH}}`, `{{DEV_BRANCH}}` — Standard `main`/`dev`.
- `{{DEPLOY_PATH}}` — Serverpfad, z.B. `/var/www/finance-api`.
- `{{SERVICE_NAME}}` — systemd-Unit, z.B. `finance-api`.
- `{{SERVICE_PORT}}` — Backend-Port, z.B. `8063`.
- `{{SERVICE_USER}}`:`{{SERVICE_GROUP}}` — Default `alex:Developer` (Konvention arkserver).
- `{{PYTHON_VERSION}}` — Default `3.11` (muss serverseitig installiert sein).
- `{{HEALTH_PATH}}` — Default `/health`.
- `{{REQUIREMENTS_FILE}}` — Default `requirements.txt`.
- `{{REQUIREMENTS_DEV_FILE}}` — Default `requirements-dev.txt`.
- `{{REPO_SSH_URL}}` — Default `git@github.com:apopovic77/<projekt>.git`.

## Vorbereitung auf dem Server (einmalig, braucht sudo)
```bash
sudo install -d -o <user> -g <group> -m 2775 /var/www/<projekt>
# systemd-Unit aus deploy/<projekt>.service nach /etc/systemd/system/, enable+start
# nginx-vhost aus deploy/nginx-<projekt>.conf nach /etc/nginx/sites-available/, enable+reload
# certbot --nginx -d <projekt>.arkserver.arkturian.com
# DNS-A-Record via tools-api POST /api/v1/subdomain
```

Die Templates `deploy/<projekt>.service` und `deploy/nginx-<projekt>.conf` legt der Autor manuell im Repo an — Beispiele unter `apopovic77/finance-api/deploy/`.

## Repo-Secrets
Wie bei allen anderen Deploys:
- `DEPLOY_HOST` = `10.192.26.50`
- `DEPLOY_PORT` = `2224`
- `DEPLOY_USER` = `root`
- `DEPLOY_SSH_KEY` = `/root/.ssh/github_deploy_key` auf arkserver

Setzt der GitHub-Agent per IACP; nicht manuell nötig.

## Runner
`arkserver-runner-<owner>-<repo>` wird vom GitHub-Agent frisch aus Tarball registriert. **NIE** per rsync kopieren (bin/+externals/ sind absolute Symlinks).
