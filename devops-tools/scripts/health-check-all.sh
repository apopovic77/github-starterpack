#!/bin/bash
#
# Health Check All Servers
#
# Performs health checks on all configured servers
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Health Check - All Servers                       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}\n"

# Server configurations
declare -A SERVERS=(
  ["arkturian.com"]="https://api-storage.arkturian.com/health"
  ["oneal-api"]="https://api-oneal.arkturian.com/health"
  # Add more servers here
)

all_healthy=true

for server in "${!SERVERS[@]}"; do
  url="${SERVERS[$server]}"

  echo -n "Checking $server... "

  # Perform health check
  response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

  if [ "$response" = "200" ]; then
    echo -e "${GREEN}✅ Healthy${NC} (HTTP $response)"
  else
    echo -e "${RED}❌ Unhealthy${NC} (HTTP $response)"
    all_healthy=false
  fi
done

echo ""

if $all_healthy; then
  echo -e "${GREEN}✅ All servers healthy!${NC}"
  exit 0
else
  echo -e "${RED}❌ Some servers are unhealthy${NC}"
  exit 1
fi
