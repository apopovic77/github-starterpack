#!/usr/bin/env bash
#
# Customer project bootstrapper.
# Can run locally on the target host (arkturian.com) or via SSH from another machine.
#
# Example (remote):
#   ./setup-customer-project.sh --project-name demo1 --customer-email info@demo1.com --host arkturian.com
#
set -euo pipefail

ORIGINAL_ARGS=("$@")

usage() {
  cat <<'USAGE'
Usage: setup-customer-project.sh --project-name <name> [options]

Create a new customer project from the shared template, wire it to GitHub,
provision CodePilot DB entries, configure Nginx/SSL, build, and deploy.

Options:
  --project-name <name>         Project slug (required; used for repo + domain prefix)
  --customer-email <email>      Optional customer login email (creates/updates user)
  --customer-name <name>        Display name for the customer (default: project name)
  --repo-owner <owner>          GitHub org/user for the repo (default: apopovic77)
  --domain-suffix <suffix>      Domain suffix (default: arkturian.com)
  --projects-root <path>        Base path to create project locally (default: /var/code)
  --deploy-base <path>          Base path for deployed site (default: /var/www)
  --template-dir <path>         Path to customer template (default: /var/code/customer-template)
  --db-host <host>              Postgres host (default: localhost)
  --db-name <name>              Postgres DB name (default: codepilot)
  --db-user <user>              Postgres user (default: codepilot)
  --db-password <pw>            Postgres password (default: codepilot)
  --admin-user-id <id>          CodePilot user id to set as project owner (default: 4)
  --token-source-project-id <id>Project id to reuse encrypted GitHub token from (default: 10)
  --ssh-user <user>             SSH user when --host is set (default: root)
  --host <hostname>             If set, re-executes this script on the remote host via SSH
  --skip-certbot                Do not request an SSL certificate
  --public                      Create GitHub repo as public (default: private)
  --yes                         Skip confirmation prompt
  -h, --help                    Show this help
USAGE
}

PROJECT_NAME=""
CUSTOMER_EMAIL=""
CUSTOMER_NAME=""
REPO_OWNER="apopovic77"
DOMAIN_SUFFIX="arkturian.com"
PROJECTS_ROOT="/var/code"
DEPLOY_BASE="/var/www"
TEMPLATE_DIR="/var/code/customer-template"
DB_HOST="localhost"
DB_NAME="codepilot"
DB_USER="codepilot"
DB_PASSWORD="codepilot"
ADMIN_USER_ID="4"
TOKEN_SOURCE_PROJECT_ID="10"
SSH_HOST=""
SSH_USER="root"
SKIP_CERTBOT=false
GH_VISIBILITY="private"
ASSUME_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name)
      PROJECT_NAME="${2:-}"
      shift 2
      ;;
    --customer-email)
      CUSTOMER_EMAIL="${2:-}"
      shift 2
      ;;
    --customer-name)
      CUSTOMER_NAME="${2:-}"
      shift 2
      ;;
    --repo-owner)
      REPO_OWNER="${2:-}"
      shift 2
      ;;
    --domain-suffix)
      DOMAIN_SUFFIX="${2:-}"
      shift 2
      ;;
    --projects-root)
      PROJECTS_ROOT="${2:-}"
      shift 2
      ;;
    --deploy-base)
      DEPLOY_BASE="${2:-}"
      shift 2
      ;;
    --template-dir)
      TEMPLATE_DIR="${2:-}"
      shift 2
      ;;
    --db-host)
      DB_HOST="${2:-}"
      shift 2
      ;;
    --db-name)
      DB_NAME="${2:-}"
      shift 2
      ;;
    --db-user)
      DB_USER="${2:-}"
      shift 2
      ;;
    --db-password)
      DB_PASSWORD="${2:-}"
      shift 2
      ;;
    --admin-user-id)
      ADMIN_USER_ID="${2:-}"
      shift 2
      ;;
    --token-source-project-id)
      TOKEN_SOURCE_PROJECT_ID="${2:-}"
      shift 2
      ;;
    --ssh-user)
      SSH_USER="${2:-}"
      shift 2
      ;;
    --host)
      SSH_HOST="${2:-}"
      shift 2
      ;;
    --skip-certbot)
      SKIP_CERTBOT=true
      shift
      ;;
    --public)
      GH_VISIBILITY="public"
      shift
      ;;
    --yes)
      ASSUME_YES=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$PROJECT_NAME" ]]; then
  echo "Error: --project-name is required." >&2
  usage
  exit 1
fi

# If a host is provided and we're not already remote, re-run over SSH.
if [[ -n "$SSH_HOST" && "${RUN_REMOTE:-0}" != "1" ]]; then
  ARGS_ESCAPED=$(printf '%q ' "${ORIGINAL_ARGS[@]}")
  echo "Executing on ${SSH_USER}@${SSH_HOST} ..."
  ssh "${SSH_USER}@${SSH_HOST}" "RUN_REMOTE=1 bash -s -- ${ARGS_ESCAPED}" < "$0"
  exit $?
fi

CUSTOMER_NAME="${CUSTOMER_NAME:-$PROJECT_NAME}"
DOMAIN="${PROJECT_NAME}.${DOMAIN_SUFFIX}"
PROJECT_DIR="${PROJECTS_ROOT%/}/${PROJECT_NAME}"
DEPLOY_PATH="${DEPLOY_BASE%/}/${DOMAIN}"
GITHUB_REPO="${REPO_OWNER}/${PROJECT_NAME}"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

confirm() {
  if [[ "$ASSUME_YES" == true ]]; then
    return 0
  fi
  read -r -p "Proceed? (y/N) " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

run_psql() {
  local sql="$1"
  PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -q -c "$sql"
}

log() {
  echo "[$(date +%H:%M:%S)] $*"
}

echo "Configuration:"
echo "  Project:        $PROJECT_NAME"
echo "  Domain:         $DOMAIN"
echo "  Deploy path:    $DEPLOY_PATH"
echo "  Projects root:  $PROJECTS_ROOT"
echo "  Template dir:   $TEMPLATE_DIR"
echo "  GitHub:         $GITHUB_REPO (${GH_VISIBILITY})"
echo "  DB:             ${DB_USER}@${DB_HOST}/${DB_NAME}"
if [[ -n "$CUSTOMER_EMAIL" ]]; then
  echo "  Customer user:  ${CUSTOMER_EMAIL} (${CUSTOMER_NAME})"
fi

if ! confirm; then
  echo "Aborted."
  exit 1
fi

log "Running locally on $(hostname)"

for cmd in git gh psql npm rsync perl openssl python3 nginx; do
  require_cmd "$cmd"
done
if [[ "$SKIP_CERTBOT" == false ]]; then
  require_cmd certbot
fi

# Ensure bcrypt is available for password hashing
if ! python3 - <<'PY' >/dev/null 2>&1
import importlib.util, sys
sys.exit(0 if importlib.util.find_spec("bcrypt") else 1)
PY
then
  echo "Python module 'bcrypt' is required (pip install bcrypt)" >&2
  exit 1
fi

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "Template directory not found: $TEMPLATE_DIR" >&2
  exit 1
fi

# Ensure GH is authenticated
if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not authenticated. Run 'gh auth login' first." >&2
  exit 1
fi

# Check DB connectivity
run_psql "SELECT 1;" >/dev/null

if [[ -d "$PROJECT_DIR" ]]; then
  echo "Target directory already exists: $PROJECT_DIR" >&2
  exit 1
fi

log "Cloning template into $PROJECT_DIR"
mkdir -p "$PROJECT_DIR"
rsync -a --delete \
  --exclude '.git' \
  --exclude 'node_modules' \
  --exclude 'dist' \
  "$TEMPLATE_DIR"/ "$PROJECT_DIR"/

cd "$PROJECT_DIR"
rm -f setup-customer.sh
git init >/dev/null
git checkout -b dev >/dev/null 2>&1 || git branch -M dev

if [[ -f package.json ]]; then
  perl -0pi -e 's/"name": "customer-template"/"name": "react-'"${PROJECT_NAME}"'"/' package.json
fi

log "Creating CodePilot project records"
ENCRYPTED_TOKEN="$(run_psql "SELECT github_token_encrypted FROM projects WHERE id = ${TOKEN_SOURCE_PROJECT_ID} LIMIT 1;" | tr -d '[:space:]')"
if [[ -z "$ENCRYPTED_TOKEN" ]]; then
  echo "Failed to fetch encrypted GitHub token from project ${TOKEN_SOURCE_PROJECT_ID}" >&2
  exit 1
fi

PROJECT_ID="$(run_psql "INSERT INTO projects (name, repo_url, github_owner, github_repo, default_branch, github_token_encrypted, local_path, created_at) VALUES ('${PROJECT_NAME}', 'https://github.com/${GITHUB_REPO}', '${REPO_OWNER}', '${PROJECT_NAME}', 'main', '${ENCRYPTED_TOKEN}', '${PROJECT_DIR}', NOW()) RETURNING id;" | tr -d '[:space:]')"
if [[ -z "$PROJECT_ID" ]]; then
  echo "Failed to create project in database" >&2
  exit 1
fi

run_psql "INSERT INTO project_members (user_id, project_id, role, created_at) VALUES (${ADMIN_USER_ID}, ${PROJECT_ID}, 'owner', NOW()) ON CONFLICT DO NOTHING;" >/dev/null

PASSWORD_MSG=""
if [[ -n "$CUSTOMER_EMAIL" ]]; then
  PASSWORD="$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 12)"
  HASH="$(PW="${PASSWORD}" python3 - <<'PY'
import bcrypt, os
password = os.environ["PW"].encode()
print(bcrypt.hashpw(password, bcrypt.gensalt()).decode())
PY
)"
  USER_ID="$(run_psql "INSERT INTO users (email, name, password_hash, role, is_active, created_at) VALUES ('${CUSTOMER_EMAIL}', '${CUSTOMER_NAME}', '${HASH}', 'CUSTOMER', true, NOW()) ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name RETURNING id;" | tr -d '[:space:]')"
  run_psql "INSERT INTO project_members (user_id, project_id, role, created_at) VALUES (${USER_ID}, ${PROJECT_ID}, 'member', NOW()) ON CONFLICT DO NOTHING;" >/dev/null
  PASSWORD_MSG="Customer login ${CUSTOMER_EMAIL} / ${PASSWORD}"
fi

if [[ -f src/App.tsx ]]; then
  perl -0pi -e "s/const PROJECT_ID = \\d+/const PROJECT_ID = ${PROJECT_ID}/" src/App.tsx
fi

log "Creating GitHub repository ${GITHUB_REPO}"
if gh repo view "$GITHUB_REPO" --json name >/dev/null 2>&1; then
  echo "Repo already exists, skipping creation."
else
  gh repo create "$GITHUB_REPO" --"$GH_VISIBILITY" --description "${PROJECT_NAME} customer project" >/dev/null
fi

git add -A
git commit -m "feat: initial ${PROJECT_NAME} setup" >/dev/null
git remote add origin "https://github.com/${GITHUB_REPO}.git" 2>/dev/null || git remote set-url origin "https://github.com/${GITHUB_REPO}.git"
git push -u origin dev >/dev/null
git checkout -B main >/dev/null
git push -u origin main >/dev/null
gh repo edit "$GITHUB_REPO" --default-branch main >/dev/null
git checkout dev >/dev/null

log "Configuring GitHub secrets"
SSH_KEY_CONTENT="$(cat ~/.ssh/github_deploy_key 2>/dev/null || cat ~/.ssh/id_rsa 2>/dev/null || true)"
if [[ -z "$SSH_KEY_CONTENT" ]]; then
  echo "Warning: could not find deploy SSH key (~/.ssh/github_deploy_key or ~/.ssh/id_rsa). Repo secrets will miss DEPLOY_SSH_KEY." >&2
fi
gh secret set DEPLOY_HOST --repo "$GITHUB_REPO" --body "$DOMAIN_SUFFIX" >/dev/null
gh secret set DEPLOY_USER --repo "$GITHUB_REPO" --body "$SSH_USER" >/dev/null
if [[ -n "$SSH_KEY_CONTENT" ]]; then
  gh secret set DEPLOY_SSH_KEY --repo "$GITHUB_REPO" --body "$SSH_KEY_CONTENT" >/dev/null
fi
gh secret set DEPLOY_PORT --repo "$GITHUB_REPO" --body "22" >/dev/null
gh secret set DEPLOY_PATH --repo "$GITHUB_REPO" --body "$DEPLOY_PATH" >/dev/null
gh secret set NPM_TOKEN --repo "$GITHUB_REPO" --body "$(gh auth token)" >/dev/null

log "Setting up Nginx for ${DOMAIN}"
sudo mkdir -p "$DEPLOY_PATH"
sudo bash -c "cat > /etc/nginx/sites-available/${DOMAIN} <<'NGINX'
server {
    listen 80;
    server_name ${DOMAIN};

    root ${DEPLOY_PATH};
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)\$ {
        expires 1y;
        add_header Cache-Control \"public, immutable\";
    }
}
NGINX"
sudo ln -sf "/etc/nginx/sites-available/${DOMAIN}" "/etc/nginx/sites-enabled/${DOMAIN}"
sudo nginx -t
sudo systemctl reload nginx

if [[ "$SKIP_CERTBOT" == false ]]; then
  sudo certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos --email "alex@arkturian.com" --redirect || true
fi

log "Installing dependencies and building"
npm ci --silent
npm run build --if-present >/dev/null

log "Deploying to ${DEPLOY_PATH}"
if [[ ! -d dist ]]; then
  echo "Build output directory dist/ not found" >&2
  exit 1
fi
sudo rsync -a dist/ "${DEPLOY_PATH}/"

git checkout main >/dev/null
git push origin main >/dev/null
git checkout dev >/dev/null

echo ""
echo "Customer project ready!"
echo "  URL:        https://${DOMAIN}"
echo "  Repo:       https://github.com/${GITHUB_REPO}"
echo "  Project ID: ${PROJECT_ID}"
echo "  Local:      ${PROJECT_DIR}"
if [[ -n "$PASSWORD_MSG" ]]; then
  echo "  ${PASSWORD_MSG}"
fi
