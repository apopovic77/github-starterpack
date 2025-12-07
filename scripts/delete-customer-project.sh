#!/usr/bin/env bash
#
# Delete a customer project (GitHub repo, CodePilot DB, Nginx config, files).
#
# Usage:
#   ./delete-customer-project.sh --project-name tscheppa-web --repo-name tscheppa-web --domain tscheppaschlucht.arkturian.com
#
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: delete-customer-project.sh --project-name <name> [options]

Options:
  --project-name <name>   Project name in DB (required)
  --repo-name <name>      GitHub repo name (default: project name)
  --repo-owner <owner>    GitHub owner/org (default: apopovic77)
  --domain <fqdn>         Domain to clean up (default: <project>.arkturian.com)
  --deploy-path <path>    Deploy path (default: /var/www/<domain>)
  --yes                   Skip confirmation prompt
  -h, --help              Show this help
USAGE
}

PROJECT_NAME=""
REPO_NAME=""
REPO_OWNER="apopovic77"
DOMAIN=""
DEPLOY_PATH=""
ASSUME_YES=false
DOMAIN_SUFFIX="arkturian.com"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name)
      PROJECT_NAME="${2:-}"
      shift 2
      ;;
    --repo-name)
      REPO_NAME="${2:-}"
      shift 2
      ;;
    --repo-owner)
      REPO_OWNER="${2:-}"
      shift 2
      ;;
    --domain)
      DOMAIN="${2:-}"
      shift 2
      ;;
    --deploy-path)
      DEPLOY_PATH="${2:-}"
      shift 2
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

REPO_NAME="${REPO_NAME:-$PROJECT_NAME}"
DOMAIN="${DOMAIN:-${PROJECT_NAME}.${DOMAIN_SUFFIX}}"
DEPLOY_PATH="${DEPLOY_PATH:-/var/www/${DOMAIN}}"
GITHUB_REPO="${REPO_OWNER}/${REPO_NAME}"

echo "Will DELETE:"
echo "  Project name: $PROJECT_NAME"
echo "  GitHub repo : $GITHUB_REPO"
echo "  Domain      : $DOMAIN"
echo "  Deploy path : $DEPLOY_PATH"
echo "  Local path  : /var/code/${PROJECT_NAME}"

if [[ "$ASSUME_YES" == false ]]; then
  read -r -p "Type DELETE to confirm: " CONFIRM
  if [[ "$CONFIRM" != "DELETE" ]]; then
    echo "Aborted."
    exit 1
  fi
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

for cmd in gh psql; do
  require_cmd "$cmd"
done

echo "[1/5] GitHub repository..."
if gh repo view "$GITHUB_REPO" --json name >/dev/null 2>&1; then
  gh repo delete "$GITHUB_REPO" --yes
  echo "  ✓ Deleted repo"
else
  echo "  - Repo not found, skipping"
fi

echo "[2/5] CodePilot database entries..."
PROJECT_ID=$(PGPASSWORD=codepilot psql -h localhost -U codepilot -d codepilot -t -A -c "SELECT id FROM projects WHERE name='${PROJECT_NAME}' LIMIT 1;" 2>/dev/null || true)
if [[ -n "$PROJECT_ID" ]]; then
  PGPASSWORD=codepilot psql -h localhost -U codepilot -d codepilot -c "DELETE FROM project_members WHERE project_id=${PROJECT_ID};" >/dev/null 2>&1 || true
  PGPASSWORD=codepilot psql -h localhost -U codepilot -d codepilot -c "DELETE FROM change_requests WHERE project_id=${PROJECT_ID};" >/dev/null 2>&1 || true
  PGPASSWORD=codepilot psql -h localhost -U codepilot -d codepilot -c "DELETE FROM projects WHERE id=${PROJECT_ID};" >/dev/null 2>&1 || true
  echo "  ✓ Deleted project id ${PROJECT_ID}"
else
  echo "  - Project not found, skipping"
fi

echo "[3/5] Nginx config..."
if [[ -f "/etc/nginx/sites-available/${DOMAIN}" ]]; then
  sudo rm -f "/etc/nginx/sites-enabled/${DOMAIN}" "/etc/nginx/sites-available/${DOMAIN}"
  sudo nginx -t && sudo systemctl reload nginx
  echo "  ✓ Removed Nginx vhost"
else
  echo "  - No Nginx vhost, skipping"
fi

echo "[4/5] Server files..."
if [[ -d "$DEPLOY_PATH" ]]; then
  sudo rm -rf "$DEPLOY_PATH"
  echo "  ✓ Removed $DEPLOY_PATH"
else
  echo "  - Deploy path missing, skipping"
fi

echo "[5/5] Local project..."
if [[ -d "/var/code/${PROJECT_NAME}" ]]; then
  rm -rf "/var/code/${PROJECT_NAME}"
  echo "  ✓ Removed /var/code/${PROJECT_NAME}"
else
  echo "  - Local path missing, skipping"
fi

echo "Done."
