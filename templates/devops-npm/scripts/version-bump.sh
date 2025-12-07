#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_ROOT="{{REPO_ROOT}}"

usage() {
  cat <<'USAGE'
Usage: version-bump.sh <major|minor|patch>

Bumps the package version and creates a git tag.

Examples:
  version-bump.sh patch   # 1.0.0 -> 1.0.1
  version-bump.sh minor   # 1.0.0 -> 1.1.0
  version-bump.sh major   # 1.0.0 -> 2.0.0
USAGE
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

bump_type="$1"

if [[ "$bump_type" != "major" && "$bump_type" != "minor" && "$bump_type" != "patch" ]]; then
  echo -e "${RED}❌ Invalid bump type: $bump_type${NC}"
  usage
  exit 1
fi

cd "$REPO_ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
  echo -e "${RED}❌ Working tree has uncommitted changes. Commit or stash them first.${NC}"
  exit 1
fi

echo -e "${YELLOW}📦 Current version:${NC}"
npm version --no-git-tag-version | grep -v "npm WARN"

echo -e "${YELLOW}⬆️  Bumping $bump_type version...${NC}"
NEW_VERSION=$(npm version $bump_type --no-git-tag-version)

echo -e "${GREEN}✅ Version bumped to: $NEW_VERSION${NC}"

echo -e "${YELLOW}📝 Committing version bump...${NC}"
git add package.json package-lock.json
git commit -m "chore: bump version to $NEW_VERSION"

echo -e "${YELLOW}🏷️  Creating git tag...${NC}"
git tag "$NEW_VERSION"

echo -e "${GREEN}✅ Version bump complete!${NC}"
echo -e "${YELLOW}Don't forget to push: git push && git push --tags${NC}"

