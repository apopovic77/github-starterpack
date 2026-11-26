#!/usr/bin/env bash

#############################################
# Deployment Script
#
# Deploys the built application to the production server.
#############################################

set -euo pipefail

# >>> geheim_schuetzen (#3251)
# Bis 17.11.2026 stand hier `chmod -R 755`: das machte jede .env fuer alle Login-Nutzer
# lesbar (tools-api, deSEC-Token). Jetzt zwei Schritte:
#   rechte_setzen <ordner>   Ordner 755, Dateien lesbar und nur fuer den Eigentuemer
#                            schreibbar; Geheimnisdateien laesst dieser Schritt aus.
#   geheim_schuetzen <ordner> [dienstbenutzer]
#                            Geheimnisdateien nie fuer "andere", nie weiter als vorher
#                            (600 bleibt 600, 644/755 werden 640). Laeuft der Dienst unter
#                            einem anderen Benutzer als dem Eigentuemer (eventcrawler,
#                            contentapi ...), gib ihn mit: seine Dateien bekommen dann dessen
#                            Gruppe. Danach wird nachgeprueft; bleibt eine Datei weltlesbar,
#                            endet der Lauf mit Fehler.
# Kanonische Fassung: templates/devops/scripts/geheim-schuetzen.sh, Abgleich: scripts/check-template-rechte.sh
geheim_finden() {  # <ordner> [--ausser] [find-ausdruck ...]; --ausser = alle Dateien AUSSER Geheimnissen
  _gd="$1"; shift
  _gn=""
  if [ "${1:-}" = "--ausser" ]; then _gn="!"; shift; fi
  [ $# -gt 0 ] || set -- -print
  find "$_gd" \( -name node_modules -o -name venv -o -name .venv -o -name .git -o -name __pycache__ \) -prune -o \
    -type f $_gn \( \( -name '.env' -o -name '.env.*' -o -name '*.key' -o -name '*.pem' -o -name '*token*' \
      -o -name '*cookies*.txt' -o -name 'credentials*' -o -name 'secrets*' -o -name 'dns_clients.json' \) \
    ! -name '*.example' ! -name '*.sample' ! -name '*.template' \
    ! -name '*.py' ! -name '*.js' ! -name '*.mjs' ! -name '*.cjs' ! -name '*.ts' ! -name '*.map' \
    ! -name '*.css' ! -name '*.html' ! -name '*.md' \) "$@"
}
rechte_setzen() {
  [ -d "$1" ] || return 0
  find "$1" -type d -exec chmod u+rwx,go+rx,go-w {} +
  geheim_finden "$1" --ausser -exec chmod u+rw,go+r,go-w {} +
}
geheim_schuetzen() {
  [ -d "$1" ] || return 0
  if [ -n "${2:-}" ] && [ "$2" != root ] && id "$2" >/dev/null 2>&1; then
    geheim_finden "$1" ! -user "$2" -exec chgrp "$(id -gn "$2")" {} +
  fi
  geheim_finden "$1" -exec chmod u-x,g-wx,o-rwx {} +
  _go=$(geheim_finden "$1" -perm -004 -print)
  if [ -n "$_go" ]; then
    echo "FEHLER (#3251): Geheimnisdatei(en) weiter fuer alle lesbar:" >&2
    echo "$_go" >&2
    return 1
  fi
  echo "Geheimnisdateien geschuetzt: $1"
}
# <<< geheim_schuetzen

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_PATH="${REPO_PATH:-{{REPO_ROOT}}}"
DEPLOY_PATH="${DEPLOY_PATH:-{{DEPLOY_PATH}}}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups}"
BACKUP_PREFIX="${BACKUP_PREFIX:-{{BACKUP_PREFIX}}}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_PATH="$BACKUP_DIR/${BACKUP_PREFIX}-${TIMESTAMP}"

echo -e "${GREEN}🚀 Starting deployment process...${NC}"

echo -e "${YELLOW}📂 Navigating to repository...${NC}"
cd "$REPO_PATH"

echo -e "${YELLOW}⬇️  Pulling latest changes from {{MAIN_BRANCH}}...${NC}"
git fetch origin {{MAIN_BRANCH}}
git reset --hard origin/{{MAIN_BRANCH}}

echo -e "${YELLOW}📦 Installing dependencies...${NC}"
{{INSTALL_DEPS_COMMAND}}

echo -e "${YELLOW}🏗️  Building application...${NC}"
{{BUILD_COMMAND}}

if [ ! -d "$REPO_PATH/dist" ]; then
  echo -e "${RED}❌ Build failed: dist directory not found${NC}"
  exit 1
fi

if [ -d "$DEPLOY_PATH" ]; then
  echo -e "${YELLOW}💾 Creating backup...${NC}"
  mkdir -p "$BACKUP_DIR"
  cp -r "$DEPLOY_PATH" "$BACKUP_PATH"
  geheim_schuetzen "$BACKUP_PATH"
  echo -e "${GREEN}✅ Backup created: $BACKUP_PATH${NC}"
else
  echo -e "${YELLOW}⚠️  No existing deployment found, skipping backup${NC}"
fi

echo -e "${YELLOW}🚢 Deploying new build...${NC}"
mkdir -p "$DEPLOY_PATH"
# Schutz (#1245): leere oder fehlende dist/ + --delete leert das Ziel samt Laufzeitdaten.
if [ ! -d "$REPO_PATH/dist" ] || [ -z "$(ls -A "$REPO_PATH/dist")" ]; then
  echo -e "${RED}❌ ABBRUCH: $REPO_PATH/dist fehlt oder ist leer, rsync --delete wuerde $DEPLOY_PATH leeren.${NC}" >&2
  exit 1
fi
rsync -av --delete "$REPO_PATH/dist/" "$DEPLOY_PATH/"

echo -e "${YELLOW}🔒 Setting permissions...${NC}"
chown -R {{WEB_USER}}:{{WEB_GROUP}} "$DEPLOY_PATH"
# Ordner 755, Dateien lesbar ohne Schreibrecht fuer andere, Geheimnisse 640 (#3251: nicht mehr chmod -R 755)
rechte_setzen "$DEPLOY_PATH"
geheim_schuetzen "$DEPLOY_PATH"

echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo -e "${GREEN}📍 Deployed to: $DEPLOY_PATH${NC}"
echo -e "${GREEN}💾 Backup saved: $BACKUP_PATH${NC}"
echo -e "${GREEN}🕒 Timestamp: $TIMESTAMP${NC}"

# Retention: prune old backups of THIS project only (prefix-scoped), keep
# the newest $BACKUP_KEEP. Runs after the success message, so a failed
# deploy never deletes anything and rollback.sh always has generations to
# offer. Without this, every deploy grows /var/backups unbounded — api-ai
# reached 37 generations = 13G and pushed arkturian to 98% disk (#214).
# `|| true`: under `set -euo pipefail` an unmatched glob makes ls exit 2
# and would abort an otherwise-successful deploy.
BACKUP_KEEP="${BACKUP_KEEP:-3}"
if [ -n "$BACKUP_PREFIX" ] && [ -d "$BACKUP_DIR" ]; then
  echo -e "${YELLOW}🧹 Pruning old backups (keeping newest $BACKUP_KEEP)...${NC}"
  ls -dt "$BACKUP_DIR/${BACKUP_PREFIX}-"* 2>/dev/null | tail -n +$((BACKUP_KEEP + 1)) | while read -r old_backup; do
    rm -rf "$old_backup"
    echo -e "  pruned: $old_backup"
  done || true
fi

echo -e "\n${GREEN}📊 Deployment Summary:${NC}"
echo -e "  Repository: $REPO_PATH"
echo -e "  Deployment: $DEPLOY_PATH"
echo -e "  Backup: $BACKUP_PATH"
echo -e "  Files deployed:"
ls -lh "$DEPLOY_PATH" | tail -n +2
