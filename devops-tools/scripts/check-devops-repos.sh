#!/bin/bash
#
# Check DevOps Implementation Status
#
# Scans all repositories in /Volumes/DatenAP/Code for .devops directories
# and reports on their implementation status.
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        DevOps Implementation Status Report                    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

CODE_DIR="/Volumes/DatenAP/Code"
total_repos=0
with_devops=0
with_release=0
with_deploy=0
with_workflows=0

echo -e "${YELLOW}Scanning repositories in ${CODE_DIR}...${NC}\n"

for dir in "$CODE_DIR"/*/.devops; do
  if [ -d "$dir" ]; then
    repo_dir=$(dirname "$dir")
    repo=$(basename "$repo_dir")

    total_repos=$((total_repos + 1))
    with_devops=$((with_devops + 1))

    # Check for key files
    release="❌"
    deploy="❌"
    workflows="❌"

    if [ -f "$dir/scripts/release.sh" ]; then
      release="✅"
      with_release=$((with_release + 1))
    fi

    if [ -f "$dir/scripts/deploy.sh" ]; then
      deploy="✅"
      with_deploy=$((with_deploy + 1))
    fi

    if [ -d "$repo_dir/.github/workflows" ]; then
      workflows="✅"
      with_workflows=$((with_workflows + 1))
    fi

    echo -e "${GREEN}📦 $repo${NC}"
    echo "   Release: $release | Deploy: $deploy | GitHub Workflows: $workflows"

    # List available scripts
    if [ -d "$dir/scripts" ]; then
      script_count=$(ls -1 "$dir/scripts/" 2>/dev/null | wc -l | xargs)
      if [ "$script_count" -gt 0 ]; then
        echo -e "   ${BLUE}Scripts ($script_count):${NC}"
        ls -1 "$dir/scripts/" 2>/dev/null | sed 's/^/     - /'
      fi
    fi

    echo ""
  fi
done

# Summary
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                          SUMMARY                              ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Total repositories with .devops: $with_devops${NC}"
echo -e "  - With release.sh: $with_release"
echo -e "  - With deploy.sh: $with_deploy"
echo -e "  - With GitHub workflows: $with_workflows"
echo ""

# Calculate percentages
if [ $with_devops -gt 0 ]; then
  release_pct=$((with_release * 100 / with_devops))
  deploy_pct=$((with_deploy * 100 / with_devops))
  workflows_pct=$((with_workflows * 100 / with_devops))

  echo -e "${YELLOW}Implementation Coverage:${NC}"
  echo "  - Release scripts: ${release_pct}%"
  echo "  - Deploy scripts: ${deploy_pct}%"
  echo "  - CI/CD workflows: ${workflows_pct}%"
fi

echo ""
