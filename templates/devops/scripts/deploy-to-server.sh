#!/usr/bin/env bash

#############################################
# Deploy to Server Script
#
# Deploys application to a specific server target.
# Reads server configuration from .devops/servers/<name>.yaml
#############################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
SERVER_CONFIG=""
SERVER_NAME=""
SKIP_BUILD=false
SKIP_BACKUP=false

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVOPS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$DEVOPS_DIR/.." && pwd)"

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Deploy application to a specific server.

OPTIONS:
    --server NAME          Server name (reads .devops/servers/NAME.yaml)
    --config PATH         Direct path to server config YAML
    --skip-build          Skip local build step
    --skip-backup         Skip server backup
    -h, --help            Show this help message

EXAMPLES:
    $(basename "$0") --server arkserver
    $(basename "$0") --server production
    $(basename "$0") --server staging --skip-build

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --server)
            SERVER_NAME="$2"
            SERVER_CONFIG="$DEVOPS_DIR/servers/$2.yaml"
            shift 2
            ;;
        --config)
            SERVER_CONFIG="$2"
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Validation
if [ -z "$SERVER_CONFIG" ]; then
    echo -e "${RED}❌ Error: --server or --config required${NC}"
    usage
fi

if [ ! -f "$SERVER_CONFIG" ]; then
    echo -e "${RED}❌ Error: Server config not found: $SERVER_CONFIG${NC}"
    exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🚀 Deploy to Server${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Config: ${YELLOW}$SERVER_CONFIG${NC}"
echo ""

# Simple YAML parser
parse_yaml() {
    local file=$1
    local prefix=$2
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\):|\1|" \
         -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
         -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" "$file" |
    awk -F$fs '{
        indent = length($1)/2;
        vname[indent] = $2;
        for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=\"%s\"\n", "'$prefix'", vn, $2, $3);
        }
    }'
}

# Load configuration
echo -e "${YELLOW}📋 Loading server configuration...${NC}"
eval $(parse_yaml "$SERVER_CONFIG" "CFG_")

SERVER_HOST="${CFG_server_host:-}"
SERVER_USER="${CFG_server_user:-root}"
SERVER_TYPE="${CFG_server_type:-python-api}"
DEPLOY_PATH="${CFG_server_deploy_path:-}"
SERVICE_NAME="${CFG_service_name:-}"
BACKUP_ENABLED="${CFG_backup_enabled:-true}"
BACKUP_DIR="${CFG_backup_dir:-/var/backups}"
BACKUP_PREFIX="${CFG_backup_prefix:-$SERVICE_NAME}"

# Validate
if [ -z "$SERVER_HOST" ] || [ -z "$DEPLOY_PATH" ] || [ -z "$SERVICE_NAME" ]; then
    echo -e "${RED}❌ Error: Missing required config fields${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Configuration loaded${NC}"
echo -e "  Server: ${YELLOW}$SERVER_USER@$SERVER_HOST${NC}"
echo -e "  Deploy path: ${YELLOW}$DEPLOY_PATH${NC}"
echo -e "  Service: ${YELLOW}$SERVICE_NAME${NC}"
echo ""

# Check Git status
echo -e "${YELLOW}🔍 Checking Git status...${NC}"
cd "$REPO_ROOT"

if [ -d ".git" ]; then
    if [ -n "$(git status --porcelain)" ]; then
        echo -e "${YELLOW}⚠️  Warning: You have uncommitted changes${NC}"
        echo -e "${YELLOW}   Consider committing before deploying${NC}"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    echo -e "${GREEN}✅ Git status clean${NC}"
fi

# Build if needed (Node.js projects)
if [ "$SKIP_BUILD" = false ] && [ -f "$REPO_ROOT/package.json" ]; then
    echo -e "${YELLOW}🏗️  Building application...${NC}"
    cd "$REPO_ROOT"

    if [ -f "package-lock.json" ]; then
        npm ci
    else
        npm install
    fi

    npm run build

    if [ ! -d "dist" ]; then
        echo -e "${RED}❌ Build failed: dist directory not found${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ Build completed${NC}"
fi

# Create backup
if [ "$SKIP_BACKUP" = false ] && [ "$BACKUP_ENABLED" = "true" ]; then
    echo -e "${YELLOW}💾 Creating backup...${NC}"
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_PATH="$BACKUP_DIR/${BACKUP_PREFIX}-${TIMESTAMP}"

    if ssh "$SERVER_USER@$SERVER_HOST" "[ -d '$DEPLOY_PATH' ]" 2>/dev/null; then
        ssh "$SERVER_USER@$SERVER_HOST" bash << EOF
mkdir -p "$BACKUP_DIR"
cp -r "$DEPLOY_PATH" "$BACKUP_PATH"
EOF
        echo -e "${GREEN}✅ Backup created: $BACKUP_PATH${NC}"
    else
        echo -e "${YELLOW}⚠️  No existing deployment found, skipping backup${NC}"
    fi
fi

# Deploy files
echo -e "${YELLOW}🚢 Deploying files...${NC}"

if [ "$SERVER_TYPE" = "python-api" ]; then
    # Python API: rsync all files except venv
    rsync -az --delete \
        --exclude='venv' \
        --exclude='.git' \
        --exclude='__pycache__' \
        --exclude='*.pyc' \
        --exclude='node_modules' \
        --exclude='.env.local' \
        "$REPO_ROOT/" "$SERVER_USER@$SERVER_HOST:$DEPLOY_PATH/"

    # Update dependencies if requirements.txt changed
    echo -e "${YELLOW}📦 Updating Python dependencies...${NC}"
    ssh "$SERVER_USER@$SERVER_HOST" bash << EOF
cd "$DEPLOY_PATH"
if [ -f "venv/bin/pip" ]; then
    source venv/bin/activate
    pip install -r requirements.txt -q
fi
EOF

elif [ -d "$REPO_ROOT/dist" ]; then
    # Node.js: deploy dist folder
    rsync -az --delete \
        "$REPO_ROOT/dist/" "$SERVER_USER@$SERVER_HOST:$DEPLOY_PATH/"
else
    # Generic: deploy all
    rsync -az --delete \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='.env.local' \
        "$REPO_ROOT/" "$SERVER_USER@$SERVER_HOST:$DEPLOY_PATH/"
fi

echo -e "${GREEN}✅ Files deployed${NC}"

# Set permissions
echo -e "${YELLOW}🔒 Setting permissions...${NC}"
ssh "$SERVER_USER@$SERVER_HOST" "chown -R www-data:www-data '$DEPLOY_PATH' && chmod -R 755 '$DEPLOY_PATH'"

# Restart service
echo -e "${YELLOW}🔄 Restarting service...${NC}"
ssh "$SERVER_USER@$SERVER_HOST" "systemctl restart $SERVICE_NAME"

# Wait for service to start
sleep 3

# Health check
echo -e "${YELLOW}🏥 Running health check...${NC}"

if ssh "$SERVER_USER@$SERVER_HOST" "systemctl is-active --quiet $SERVICE_NAME"; then
    echo -e "${GREEN}✅ Service is running${NC}"
else
    echo -e "${RED}❌ Service failed to start${NC}"
    echo -e "${YELLOW}Check logs: ssh $SERVER_USER@$SERVER_HOST 'journalctl -u $SERVICE_NAME -n 50'${NC}"
    exit 1
fi

# Retention: prune old backups of THIS service on the server (prefix-scoped),
# keep the newest $BACKUP_KEEP. Runs only after the health check passed, so a
# failed deploy never deletes and rollback keeps generations to offer. Without
# this every deploy grows /var/backups unbounded — api-ai hit 37 generations
# = 13G and pushed arkturian to 98% disk (#214). The trailing `|| true` inside
# the remote shell guards the unmatched-glob case (ls exit 2 under pipefail).
BACKUP_KEEP="${CFG_backup_keep:-3}"
if [ "$BACKUP_ENABLED" = "true" ] && [ -n "$BACKUP_PREFIX" ]; then
    echo -e "${YELLOW}🧹 Pruning old backups (keeping newest $BACKUP_KEEP)...${NC}"
    ssh "$SERVER_USER@$SERVER_HOST" bash << EOF
ls -dt "$BACKUP_DIR/${BACKUP_PREFIX}-"* 2>/dev/null | tail -n +$((BACKUP_KEEP + 1)) | while read -r old_backup; do
    rm -rf "\$old_backup"
    echo "  pruned: \$old_backup"
done || true
EOF
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}📊 Summary:${NC}"
echo -e "  Server: ${YELLOW}$SERVER_USER@$SERVER_HOST${NC}"
echo -e "  Service: ${YELLOW}$SERVICE_NAME${NC}"
echo -e "  Status: ${GREEN}✅ Running${NC}"
if [ "$BACKUP_ENABLED" = "true" ] && [ "$SKIP_BACKUP" = false ]; then
    echo -e "  Backup: ${YELLOW}$BACKUP_PATH${NC}"
fi
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo -e "  • Check logs: ${BLUE}ssh $SERVER_USER@$SERVER_HOST 'journalctl -u $SERVICE_NAME -f'${NC}"
echo -e "  • Check status: ${BLUE}ssh $SERVER_USER@$SERVER_HOST 'systemctl status $SERVICE_NAME'${NC}"
if [ "$BACKUP_ENABLED" = "true" ]; then
    echo -e "  • Rollback: ${BLUE}./.devops/rollback.sh${NC}"
fi
echo ""
