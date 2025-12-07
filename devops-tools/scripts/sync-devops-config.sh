#!/bin/bash
#
# Sync DevOps Configuration
#
# Updates .devops configuration across all repositories from github-starterkit
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

STARTERKIT_DIR="/Volumes/DatenAP/Code/github-starterkit"
CODE_DIR="/Volumes/DatenAP/Code"

if [ ! -d "$STARTERKIT_DIR" ]; then
  echo -e "${RED}❌ github-starterkit not found at $STARTERKIT_DIR${NC}"
  exit 1
fi

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Sync DevOps Config from github-starterkit            ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}\n"

# Confirmation
read -p "$(echo -e ${YELLOW}This will update .devops configs in all repos. Continue? [y/N]${NC} ) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Aborted.${NC}"
    exit 1
fi

updated=0
skipped=0

for repo_dir in "$CODE_DIR"/*/.devops; do
  if [ -d "$repo_dir" ]; then
    repo=$(dirname "$repo_dir" | xargs basename)

    echo -e "${BLUE}Processing $repo...${NC}"

    # Copy core scripts
    if [ -d "$STARTERKIT_DIR/.devops/scripts" ]; then
      cp -r "$STARTERKIT_DIR/.devops/scripts" "$repo_dir/"
      echo -e "  ${GREEN}✅ Updated scripts${NC}"
      updated=$((updated + 1))
    else
      echo -e "  ${YELLOW}⚠️  No scripts to sync${NC}"
      skipped=$((skipped + 1))
    fi

    # Preserve custom scripts (don't overwrite)
    echo -e "  ${YELLOW}ℹ️  Custom scripts preserved${NC}"
  fi
done

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                      SYNC COMPLETE                            ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${GREEN}✅ Updated: $updated repositories${NC}"
echo -e "${YELLOW}⚠️  Skipped: $skipped repositories${NC}\n"
