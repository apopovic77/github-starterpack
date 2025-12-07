#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_ROOT="{{REPO_ROOT}}"
BUILD_COMMAND="{{BUILD_COMMAND}}"

usage() {
  cat <<'USAGE'
Usage: publish-npm.sh [--dry-run]

Publishes the NPM package to the registry.

Options:
  --dry-run   Run npm publish in dry-run mode (no actual publish)
USAGE
}

dry_run=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      dry_run=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage
      exit 1
      ;;
  esac
done

cd "$REPO_ROOT"

echo -e "${YELLOW}📦 Checking npm authentication...${NC}"
if ! npm whoami &>/dev/null; then
  echo -e "${RED}❌ Not logged in to npm. Run 'npm login' first.${NC}"
  exit 1
fi

echo -e "${YELLOW}🏗️  Building package...${NC}"
$BUILD_COMMAND

echo -e "${YELLOW}🧪 Running tests...${NC}"
npm test || echo -e "${YELLOW}⚠️  Tests failed or not configured${NC}"

echo -e "${YELLOW}📋 Package info:${NC}"
npm pack --dry-run

if [[ "$dry_run" == true ]]; then
  echo -e "${YELLOW}🔍 Dry run mode - not publishing${NC}"
  npm publish --dry-run --access public
  echo -e "${GREEN}✅ Dry run completed successfully${NC}"
else
  echo -e "${YELLOW}📤 Publishing to NPM...${NC}"
  npm publish --access public
  echo -e "${GREEN}✅ Package published successfully!${NC}"
  
  PACKAGE_NAME=$(node -p "require('./package.json').name")
  PACKAGE_VERSION=$(node -p "require('./package.json').version")
  echo -e "${GREEN}📦 Published: ${PACKAGE_NAME}@${PACKAGE_VERSION}${NC}"
fi

