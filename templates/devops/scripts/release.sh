#!/usr/bin/env bash

set -euo pipefail

# Resolve repository root relative to this script so it works anywhere.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
DEV_BRANCH="{{DEV_BRANCH}}"
MAIN_BRANCH="{{MAIN_BRANCH}}"
CHECKOUT_SCRIPT="$SCRIPT_DIR/checkout-branch.sh"
BUILD_SCRIPT="$SCRIPT_DIR/build-local.sh"

usage() {
  cat <<'USAGE'
Usage: release.sh [--no-build]

Fast-forwards {{MAIN_BRANCH}} from {{DEV_BRANCH}}, pushes to origin, and
triggers the GitHub Actions deployment workflow. By default the local build
script runs beforehand.

Options:
  --no-build   Skip running the local build before pushing
USAGE
}

run_build=true

for arg in "$@"; do
  case "$arg" in
    --no-build)
      run_build=false
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

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: working tree has uncommitted changes. Please commit or stash them first." >&2
  exit 1
fi

printf '\n==> Syncing %s branch\n' "$DEV_BRANCH"
"$CHECKOUT_SCRIPT" "$DEV_BRANCH"

git push origin "$DEV_BRANCH"

if [[ "$run_build" == true ]]; then
  printf '\n==> Running local production build\n'
  "$BUILD_SCRIPT"
fi

printf '\n==> Syncing %s branch\n' "$MAIN_BRANCH"
"$CHECKOUT_SCRIPT" "$MAIN_BRANCH"

printf '\n==> Fast-forwarding %s from %s\n' "$MAIN_BRANCH" "$DEV_BRANCH"
if ! git merge --ff-only "$DEV_BRANCH"; then
  echo "Error: $MAIN_BRANCH cannot fast-forward from $DEV_BRANCH. Resolve manually (likely $MAIN_BRANCH is ahead)." >&2
  exit 1
fi

git push origin "$MAIN_BRANCH"

# Rollt der Push wirklich aus? Diese Zeile behauptete es bedingungslos — und
# lag in jedem Projekt falsch, das den Push-Ausloeser abgeschaltet hat. Genau
# das ist bei tschepp-ar-web im Juli passiert (gleichzeitige Deploys hinter-
# liessen ein halb geschriebenes dist/), und seitdem meldete `devops release`
# monatelang Erfolg, ohne dass etwas ausgerollt wurde. Aufgefallen ist es erst,
# als zwei Agenten sich gegenseitig ueberschrieben (2026-08-11).
#
# Deshalb wird jetzt NACHGESEHEN statt behauptet. Die Vorlagen dieses
# Starterpacks tragen den Push-Ausloeser weiterhin — dort bleibt alles wie
# gehabt, und ein zusaetzlicher Anstoss waere sogar schaedlich: zwei Deploys
# auf denselben Commit sind wieder das halb geschriebene dist/.
DEPLOY_WORKFLOW="${DEPLOY_WORKFLOW:-.github/workflows/deploy.yml}"
DEPLOY_WORKFLOW_NAME="${DEPLOY_WORKFLOW_NAME:-Build & Deploy}"

push_loest_deploy_aus() {
  [ -f "$DEPLOY_WORKFLOW" ] || return 1
  # `on:`-Block bis zum naechsten Top-Level-Schluessel; enthaelt er `push:`,
  # startet der Push den Lauf selbst.
  awk '/^on:/{drin=1; next} /^[a-zA-Z]/{drin=0} drin' "$DEPLOY_WORKFLOW" \
    | grep -q '^[[:space:]]*push:'
}

if push_loest_deploy_aus; then
  printf '\n✅ Release pushed. Der Push startet den Deploy von %s.\n' "$MAIN_BRANCH"
elif command -v gh >/dev/null 2>&1; then
  printf '\n==> %s reagiert nicht auf Push — Deploy wird angestossen\n' "$DEPLOY_WORKFLOW"
  if gh workflow run "$DEPLOY_WORKFLOW_NAME" --ref "$MAIN_BRANCH"; then
    printf '\n✅ Release gepusht und Deploy angestossen (%s).\n' "$MAIN_BRANCH"
    printf '   Stand: gh run list --workflow "%s" --limit 1\n' "$DEPLOY_WORKFLOW_NAME"
  else
    printf '\n⚠️  Push ok, Deploy NICHT angestossen. Von Hand:\n' >&2
    printf '   gh workflow run "%s" --ref %s\n' "$DEPLOY_WORKFLOW_NAME" "$MAIN_BRANCH" >&2
  fi
else
  printf '\n⚠️  Release gepusht — aber NICHT ausgerollt.\n' >&2
  printf '   %s reagiert nicht auf Push, und `gh` fehlt. Von Hand:\n' "$DEPLOY_WORKFLOW" >&2
  printf '   gh workflow run "%s" --ref %s\n' "$DEPLOY_WORKFLOW_NAME" "$MAIN_BRANCH" >&2
fi

printf '\n==> Switching back to %s\n' "$DEV_BRANCH"
"$CHECKOUT_SCRIPT" "$DEV_BRANCH"
