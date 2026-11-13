#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_ROOT="$SCRIPT_DIR/../templates"

default() {
  local var_name="$1"
  local default_value="$2"
  local current_value="${!var_name:-}"
  if [[ -z "$current_value" ]]; then
    printf -v "$var_name" '%s' "$default_value"
  fi
}

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}

usage() {
  cat <<'USAGE'
Usage: setup-devops.sh --target <path> [options]

Copies the DevOps starter templates into the target project and applies
placeholder substitutions.

Options:
  --target <path>        Project directory to receive the templates (required)
  --project-name <name>  Friendly project name (defaults to basename of target)
  --repo-root <path>     Absolute repository path used in scripts (defaults to target)
  --deploy-path <path>   Deployment directory on server (default /var/www/<slug>)
  --site-url <url>       Public site URL (used in docs)
  --dev-branch <name>    Integration branch (default dev)
  --main-branch <name>   Production branch (default main)
  --install-deps <cmd>   Command to install dependencies (default "npm ci --production=false")
  --build-command <cmd>  Command to build the app (default "npm run build")
  --node-version <ver>   Node.js version for workflows (default 18)
  --web-user <user>      Web server user for chown (default www-data)
  --web-group <group>    Web server group for chown (default www-data)
  --backup-prefix <str>  Prefix for backups (default derived from project slug)

Python (used when PROJECT_TYPE=python; auto-detected via requirements.txt):
  --python-version <v>   Python interpreter version (default 3.11)
  --service-name <n>     systemd unit name (default project slug)
  --service-port <p>     Backend port on 127.0.0.1 (required for python)
  --service-user <u>     systemd User= (default alex)
  --service-group <g>    chown group on deploy path (default Developer)
  --health-path <p>      Health endpoint path (default /health)
  --requirements-file <f>      pip -r file for prod (default requirements.txt)
  --requirements-dev-file <f>  pip -r file for CI/tests (default requirements-dev.txt)
  --repo-ssh-url <url>   git remote on server (default git@github.com:apopovic77/<slug>.git)

  --non-interactive      Fail if required values missing instead of prompting
  --update               Re-apply templates using stored configuration
  -h, --help             Show this help message
USAGE
}

TARGET=""
PROJECT_NAME=""
REPO_ROOT=""
DEPLOY_PATH=""
SITE_URL=""
DEV_BRANCH="dev"
MAIN_BRANCH="main"
INSTALL_DEPS_COMMAND="npm ci --production=false"
BUILD_COMMAND="npm run build"
NODE_VERSION="18"
WEB_USER="www-data"
WEB_GROUP="www-data"
BACKUP_PREFIX=""
NON_INTERACTIVE=false
UPDATE=false
STARTER_PATH=""
# Python-only defaults (used when PROJECT_TYPE=python)
PYTHON_VERSION="3.11"
SERVICE_NAME=""
SERVICE_PORT=""
SERVICE_USER="alex"
SERVICE_GROUP="Developer"
HEALTH_PATH="/health"
REQUIREMENTS_FILE="requirements.txt"
REQUIREMENTS_DEV_FILE="requirements-dev.txt"
REPO_SSH_URL=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --project-name)
      PROJECT_NAME="${2:-}"
      shift 2
      ;;
    --repo-root)
      REPO_ROOT="${2:-}"
      shift 2
      ;;
    --deploy-path)
      DEPLOY_PATH="${2:-}"
      shift 2
      ;;
    --site-url)
      SITE_URL="${2:-}"
      shift 2
      ;;
    --dev-branch)
      DEV_BRANCH="${2:-}"
      shift 2
      ;;
    --main-branch)
      MAIN_BRANCH="${2:-}"
      shift 2
      ;;
    --install-deps)
      INSTALL_DEPS_COMMAND="${2:-}"
      shift 2
      ;;
    --build-command)
      BUILD_COMMAND="${2:-}"
      shift 2
      ;;
    --node-version)
      NODE_VERSION="${2:-}"
      shift 2
      ;;
    --web-user)
      WEB_USER="${2:-}"
      shift 2
      ;;
    --web-group)
      WEB_GROUP="${2:-}"
      shift 2
      ;;
    --backup-prefix)
      BACKUP_PREFIX="${2:-}"
      shift 2
      ;;
    --python-version)
      PYTHON_VERSION="${2:-}"
      shift 2
      ;;
    --service-name)
      SERVICE_NAME="${2:-}"
      shift 2
      ;;
    --service-port)
      SERVICE_PORT="${2:-}"
      shift 2
      ;;
    --service-user)
      SERVICE_USER="${2:-}"
      shift 2
      ;;
    --service-group)
      SERVICE_GROUP="${2:-}"
      shift 2
      ;;
    --health-path)
      HEALTH_PATH="${2:-}"
      shift 2
      ;;
    --requirements-file)
      REQUIREMENTS_FILE="${2:-}"
      shift 2
      ;;
    --requirements-dev-file)
      REQUIREMENTS_DEV_FILE="${2:-}"
      shift 2
      ;;
    --repo-ssh-url)
      REPO_SSH_URL="${2:-}"
      shift 2
      ;;
    --non-interactive)
      NON_INTERACTIVE=true
      shift
      ;;
    --update)
      UPDATE=true
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

if [[ -z "$TARGET" ]]; then
  echo "Error: --target is required." >&2
  usage
  exit 1
fi

if [[ ! -d "$TARGET" ]]; then
  echo "Error: target directory '$TARGET' does not exist." >&2
  exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"
CONFIG_PATH="$TARGET/.devops/starter-config.json"

# Auto-detect project type
PROJECT_TYPE=""
if [[ -f "$TARGET/playwright.config.ts" ]] || [[ -f "$TARGET/playwright.config.js" ]]; then
  PROJECT_TYPE="test"
  echo "📦 Detected: Playwright test project"
  if [[ "$UPDATE" == false ]]; then
    # Only override defaults on fresh install, not update
    INSTALL_DEPS_COMMAND="npm ci"
    BUILD_COMMAND="npm test"
    NODE_VERSION="18"
  fi
elif [[ -f "$TARGET/composer.json" ]] || ls "$TARGET"/*.php &>/dev/null; then
  PROJECT_TYPE="php"
  echo "📦 Detected: PHP project"
  if [[ "$UPDATE" == false ]]; then
    # Only override defaults on fresh install, not update
    INSTALL_DEPS_COMMAND="echo '✅ PHP project - no npm dependencies'"
    BUILD_COMMAND="echo '✅ No build needed for PHP application'"
    NODE_VERSION="n/a"
  fi
elif [[ -f "$TARGET/requirements.txt" ]] || [[ -f "$TARGET/pyproject.toml" ]]; then
  PROJECT_TYPE="python"
  echo "📦 Detected: Python project (FastAPI/uvicorn + systemd + arkserver)"
  if [[ "$UPDATE" == false ]]; then
    # Only override defaults on fresh install, not update
    INSTALL_DEPS_COMMAND="echo '✅ Python project - venv handled by deploy workflow'"
    BUILD_COMMAND="echo '✅ No build step for Python application'"
    NODE_VERSION="n/a"
    WEB_USER="$SERVICE_USER"
    WEB_GROUP="$SERVICE_GROUP"
  fi
elif [[ -f "$TARGET/package.json" ]]; then
  # Check if it's an NPM package (has "main" or "types" in package.json)
  if grep -q '"main"\|"types"\|"exports"' "$TARGET/package.json" 2>/dev/null; then
    PROJECT_TYPE="npm"
    echo "📦 Detected: NPM package project"
    if [[ "$UPDATE" == false ]]; then
      INSTALL_DEPS_COMMAND="npm ci"
      BUILD_COMMAND="npm run build"
      NODE_VERSION="20"
    fi
  else
    PROJECT_TYPE="node"
    echo "📦 Detected: Node.js application"
  fi
else
  echo "⚠️  Could not auto-detect project type. Assuming Node.js defaults."
  PROJECT_TYPE="node"
fi

if [[ "$UPDATE" == true ]]; then
  if [[ ! -f "$CONFIG_PATH" ]]; then
    echo "Error: --update requires existing configuration at $CONFIG_PATH" >&2
    exit 1
  fi
  tmpfile=$(mktemp)
  python3 - "$CONFIG_PATH" "$tmpfile" <<'PY'
import json, shlex, sys
cfg_path, out_path = sys.argv[1], sys.argv[2]
data = json.load(open(cfg_path))
with open(out_path, "w") as fh:
    for key, value in data.items():
        if isinstance(value, bool):
            value = "true" if value else "false"
        fh.write(f'if [[ -z "${{{key}:-}}" ]]; then {key}={shlex.quote(str(value))}; fi\n')
PY
  # shellcheck disable=SC1090
  source "$tmpfile"
  rm -f "$tmpfile"
  NON_INTERACTIVE=true
fi

if [[ -z "$STARTER_PATH" ]]; then
  STARTER_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

# STARTER_PATH guards:
# - Reject ephemeral paths (/tmp, scratchpad): update-devops.sh later resolves
#   from this value; a /tmp path is gone after reboot and leaves the repo
#   unable to self-update.
# - If the canonical arkserver clone exists at /var/code/github-starterpack and
#   the current STARTER_PATH is NOT it, suggest it. Non-interactive run keeps
#   the current path but prints a warning so the operator sees it in logs.
CANONICAL_STARTER_PATH="/var/code/github-starterpack"

case "$STARTER_PATH" in
  /tmp/*|/private/tmp/*|/var/folders/*)
    echo "⚠️  STARTER_PATH is in a temp location: $STARTER_PATH" >&2
    echo "    update-devops.sh will write this path into .devops/starter-config.json" >&2
    echo "    and templates/devops/scripts/update-devops.sh (DEFAULT_STARTER_PATH)." >&2
    echo "    A temp path breaks later self-updates once the directory is gone." >&2
    if [[ -x "$CANONICAL_STARTER_PATH/scripts/setup-devops.sh" ]]; then
      echo "    Canonical starter pack is available at $CANONICAL_STARTER_PATH." >&2
      if [[ "$NON_INTERACTIVE" == false ]]; then
        read -rp "Use $CANONICAL_STARTER_PATH instead? [Y/n]: " _starter_choice
        if [[ -z "$_starter_choice" ]] || [[ "${_starter_choice,,}" =~ ^y ]]; then
          STARTER_PATH="$CANONICAL_STARTER_PATH"
          echo "✅ STARTER_PATH set to $STARTER_PATH"
        fi
      else
        echo "    Pass --starter-path $CANONICAL_STARTER_PATH to use the canonical copy." >&2
      fi
    else
      echo "    Pass --starter-path to point at a durable clone." >&2
    fi
    ;;
esac

# Warn if the starter clone we're reading from is behind its remote.
if [[ -d "$STARTER_PATH/.git" ]]; then
  _starter_git_status=$(git -C "$STARTER_PATH" status -sb 2>/dev/null | head -1 || true)
  case "$_starter_git_status" in
    *behind*)
      echo "⚠️  Starter pack clone at $STARTER_PATH is behind its remote:" >&2
      echo "    $_starter_git_status" >&2
      echo "    Templates may be stale. Run 'git -C $STARTER_PATH pull' before rerunning setup-devops.sh." >&2
      ;;
  esac
fi

default PROJECT_NAME "$(basename "$TARGET")"
default REPO_ROOT "$TARGET"
PROJECT_SLUG="$(slugify "$PROJECT_NAME")"
default BACKUP_PREFIX "$PROJECT_SLUG"
default DEPLOY_PATH "/var/www/$PROJECT_SLUG"
default SITE_URL "https://example.com"
# Python defaults depending on slug
default SERVICE_NAME "$PROJECT_SLUG"
default REPO_SSH_URL "git@github.com:apopovic77/$PROJECT_SLUG.git"

if [[ "$NON_INTERACTIVE" == false ]]; then
  read -rp "Project name [$PROJECT_NAME]: " input && [[ -n "$input" ]] && PROJECT_NAME="$input"
  read -rp "Repository root [$REPO_ROOT]: " input && [[ -n "$input" ]] && REPO_ROOT="$input"
  read -rp "Deploy path [$DEPLOY_PATH]: " input && [[ -n "$input" ]] && DEPLOY_PATH="$input"
  read -rp "Site URL [$SITE_URL]: " input && [[ -n "$input" ]] && SITE_URL="$input"
  read -rp "Dev branch [$DEV_BRANCH]: " input && [[ -n "$input" ]] && DEV_BRANCH="$input"
  read -rp "Main branch [$MAIN_BRANCH]: " input && [[ -n "$input" ]] && MAIN_BRANCH="$input"
  read -rp "Install deps command [$INSTALL_DEPS_COMMAND]: " input && [[ -n "$input" ]] && INSTALL_DEPS_COMMAND="$input"
  read -rp "Build command [$BUILD_COMMAND]: " input && [[ -n "$input" ]] && BUILD_COMMAND="$input"
  read -rp "Node version [$NODE_VERSION]: " input && [[ -n "$input" ]] && NODE_VERSION="$input"
  read -rp "Web user [$WEB_USER]: " input && [[ -n "$input" ]] && WEB_USER="$input"
  read -rp "Web group [$WEB_GROUP]: " input && [[ -n "$input" ]] && WEB_GROUP="$input"
  read -rp "Backup prefix [$BACKUP_PREFIX]: " input && [[ -n "$input" ]] && BACKUP_PREFIX="$input"
  read -rp "Starter pack path [$STARTER_PATH]: " input && [[ -n "$input" ]] && STARTER_PATH="$input"
  if [[ "$PROJECT_TYPE" == "python" ]]; then
    read -rp "Python version [$PYTHON_VERSION]: " input && [[ -n "$input" ]] && PYTHON_VERSION="$input"
    read -rp "systemd service name [$SERVICE_NAME]: " input && [[ -n "$input" ]] && SERVICE_NAME="$input"
    read -rp "Backend port on 127.0.0.1 [$SERVICE_PORT]: " input && [[ -n "$input" ]] && SERVICE_PORT="$input"
    read -rp "Service user [$SERVICE_USER]: " input && [[ -n "$input" ]] && SERVICE_USER="$input"
    read -rp "Service group [$SERVICE_GROUP]: " input && [[ -n "$input" ]] && SERVICE_GROUP="$input"
    read -rp "Health path [$HEALTH_PATH]: " input && [[ -n "$input" ]] && HEALTH_PATH="$input"
    read -rp "requirements file [$REQUIREMENTS_FILE]: " input && [[ -n "$input" ]] && REQUIREMENTS_FILE="$input"
    read -rp "requirements-dev file [$REQUIREMENTS_DEV_FILE]: " input && [[ -n "$input" ]] && REQUIREMENTS_DEV_FILE="$input"
    read -rp "Repository SSH URL [$REPO_SSH_URL]: " input && [[ -n "$input" ]] && REPO_SSH_URL="$input"
  fi
fi

for var in PROJECT_NAME REPO_ROOT DEPLOY_PATH DEV_BRANCH MAIN_BRANCH INSTALL_DEPS_COMMAND BUILD_COMMAND NODE_VERSION WEB_USER WEB_GROUP BACKUP_PREFIX; do
  if [[ -z "${!var}" ]]; then
    echo "Error: $var is required." >&2
    exit 1
  fi
done

if [[ "$PROJECT_TYPE" == "python" ]]; then
  for var in PYTHON_VERSION SERVICE_NAME SERVICE_PORT SERVICE_USER SERVICE_GROUP HEALTH_PATH REQUIREMENTS_FILE REQUIREMENTS_DEV_FILE REPO_SSH_URL; do
    if [[ -z "${!var}" ]]; then
      echo "Error: $var is required for Python projects." >&2
      exit 1
    fi
  done
fi

mkdir -p "$TARGET/.devops" "$TARGET/.github/workflows"

tar -C "$TEMPLATE_ROOT/devops" -cf - . | tar -C "$TARGET/.devops" -xf -

# Use project-type-specific templates if detected
if [[ "$PROJECT_TYPE" == "test" ]] && [[ -d "$TEMPLATE_ROOT/github-test/workflows" ]]; then
  echo "📦 Using Playwright test-optimized GitHub Actions workflows"
  tar -C "$TEMPLATE_ROOT/github-test/workflows" -cf - . | tar -C "$TARGET/.github/workflows" -xf -
elif [[ "$PROJECT_TYPE" == "php" ]] && [[ -d "$TEMPLATE_ROOT/github-php/workflows" ]]; then
  echo "📦 Using PHP-optimized GitHub Actions workflows"
  tar -C "$TEMPLATE_ROOT/github-php/workflows" -cf - . | tar -C "$TARGET/.github/workflows" -xf -
elif [[ "$PROJECT_TYPE" == "npm" ]] && [[ -d "$TEMPLATE_ROOT/github-npm/workflows" ]]; then
  echo "📦 Using NPM package-optimized GitHub Actions workflows"
  tar -C "$TEMPLATE_ROOT/github-npm/workflows" -cf - . | tar -C "$TARGET/.github/workflows" -xf -
  # Also copy NPM-specific devops scripts
  if [[ -d "$TEMPLATE_ROOT/devops-npm/scripts" ]]; then
    tar -C "$TEMPLATE_ROOT/devops-npm/scripts" -cf - . | tar -C "$TARGET/.devops/scripts" -xf -
  fi
elif [[ "$PROJECT_TYPE" == "python" ]] && [[ -d "$TEMPLATE_ROOT/github-python/workflows" ]]; then
  echo "📦 Using Python FastAPI (self-hosted arkserver) GitHub Actions workflows"
  tar -C "$TEMPLATE_ROOT/github-python/workflows" -cf - . | tar -C "$TARGET/.github/workflows" -xf -
else
  tar -C "$TEMPLATE_ROOT/github/workflows" -cf - . | tar -C "$TARGET/.github/workflows" -xf -
fi

if [[ -d "$TEMPLATE_ROOT/root" ]]; then
  tar -C "$TEMPLATE_ROOT/root" -cf - . | tar -C "$TARGET" -xf -
fi

mapfile -t FILES < <(find "$TARGET/.devops" "$TARGET/.github/workflows" -type f)

export PROJECT_NAME PROJECT_SLUG PROJECT_TYPE REPO_ROOT DEPLOY_PATH SITE_URL DEV_BRANCH MAIN_BRANCH INSTALL_DEPS_COMMAND BUILD_COMMAND NODE_VERSION WEB_USER WEB_GROUP BACKUP_PREFIX STARTER_PATH
export PYTHON_VERSION SERVICE_NAME SERVICE_PORT SERVICE_USER SERVICE_GROUP HEALTH_PATH REQUIREMENTS_FILE REQUIREMENTS_DEV_FILE REPO_SSH_URL

PLACEHOLDERS_JSON=$(python3 - <<'PY'
import json, os
print(json.dumps({
  "PROJECT_NAME": os.environ["PROJECT_NAME"],
  "PROJECT_SLUG": os.environ["PROJECT_SLUG"],
  "PROJECT_TYPE": os.environ.get("PROJECT_TYPE", "node"),
  "REPO_ROOT": os.environ["REPO_ROOT"],
  "DEPLOY_PATH": os.environ["DEPLOY_PATH"],
  "SITE_URL": os.environ["SITE_URL"],
  "DEV_BRANCH": os.environ["DEV_BRANCH"],
  "MAIN_BRANCH": os.environ["MAIN_BRANCH"],
  "INSTALL_DEPS_COMMAND": os.environ["INSTALL_DEPS_COMMAND"],
  "BUILD_COMMAND": os.environ["BUILD_COMMAND"],
  "NODE_VERSION": os.environ["NODE_VERSION"],
  "WEB_USER": os.environ["WEB_USER"],
  "WEB_GROUP": os.environ["WEB_GROUP"],
  "BACKUP_PREFIX": os.environ["BACKUP_PREFIX"],
  "STARTER_PATH": os.environ["STARTER_PATH"],
  "PYTHON_VERSION": os.environ.get("PYTHON_VERSION", "3.11"),
  "SERVICE_NAME": os.environ.get("SERVICE_NAME", ""),
  "SERVICE_PORT": os.environ.get("SERVICE_PORT", ""),
  "SERVICE_USER": os.environ.get("SERVICE_USER", "alex"),
  "SERVICE_GROUP": os.environ.get("SERVICE_GROUP", "Developer"),
  "HEALTH_PATH": os.environ.get("HEALTH_PATH", "/health"),
  "REQUIREMENTS_FILE": os.environ.get("REQUIREMENTS_FILE", "requirements.txt"),
  "REQUIREMENTS_DEV_FILE": os.environ.get("REQUIREMENTS_DEV_FILE", "requirements-dev.txt"),
  "REPO_SSH_URL": os.environ.get("REPO_SSH_URL", "")
}))
PY
)

export PLACEHOLDERS_JSON PROJECT_NAME PROJECT_SLUG PROJECT_TYPE REPO_ROOT DEPLOY_PATH SITE_URL DEV_BRANCH MAIN_BRANCH INSTALL_DEPS_COMMAND BUILD_COMMAND NODE_VERSION WEB_USER WEB_GROUP BACKUP_PREFIX STARTER_PATH

python3 - "$PLACEHOLDERS_JSON" "${FILES[@]}" <<'PY'
import json
import sys
from pathlib import Path

mapping = json.loads(sys.argv[1])
for file_path in sys.argv[2:]:
    path = Path(file_path)
    try:
        text = path.read_text()
    except UnicodeDecodeError:
        continue
    for key, value in mapping.items():
        text = text.replace(f"{{{{{key}}}}}", value)
    path.write_text(text)
PY

find "$TARGET/.devops" -type f -name '*.sh' -exec chmod +x {} +
if [[ -f "$TARGET/devops" ]]; then
  chmod +x "$TARGET/devops"
fi

mkdir -p "$(dirname "$CONFIG_PATH")"
python3 - "$CONFIG_PATH" <<'PY'
import json, os, sys
config_path = sys.argv[1]
data = json.loads(os.environ["PLACEHOLDERS_JSON"])
with open(config_path, "w") as fh:
    json.dump(data, fh, indent=2, sort_keys=True)
PY

cat <<EOF
✅ DevOps templates installed into $TARGET

Next steps:
  1. Commit the generated files (.devops/, .github/workflows/).
  2. Configure GitHub secrets: DEPLOY_HOST, DEPLOY_USER, DEPLOY_SSH_KEY, optional DEPLOY_PORT.
  3. Authorise the SSH key on the deployment server.
  4. Run .devops/scripts/build-local.sh to verify the build.
  5. Push to $DEV_BRANCH and run .devops/scripts/release.sh when ready.
EOF
