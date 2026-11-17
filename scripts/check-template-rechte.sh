#!/usr/bin/env bash
# Prueft die Deploy-Vorlagen auf den Rechte-Vertrag aus #3251:
#   1. kein aktives `chmod -R 755` mehr (es machte jede .env fuer alle lesbar),
#   2. jede Vorlage, die Rechte setzt, traegt den kanonischen Block geheim_schuetzen
#      WOERTLICH (templates/devops/scripts/geheim-schuetzen.sh),
#   3. der Block tut, was er verspricht (Wegwerf-Ordner, ohne root),
#   4. die Skripte der Workflows sind gueltiges Bash.
# Aufruf: scripts/check-template-rechte.sh   (Exit 0 = alles gut)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KANON="$ROOT/templates/devops/scripts/geheim-schuetzen.sh"
FEHLER=0
fail() { echo "FEHLER: $*" >&2; FEHLER=1; }
ok() { echo "ok: $*"; }

# --- 1. kein aktives chmod -R 755 -------------------------------------------------
if grep -rnE '^[^#]*chmod -R 755' "$ROOT/templates" >/dev/null; then
  grep -rnE '^[^#]*chmod -R 755' "$ROOT/templates" >&2
  fail "chmod -R 755 steht noch in den Vorlagen"
else
  ok "kein chmod -R 755 in templates/"
fi

# --- 2. Block woertlich in jeder Vorlage -----------------------------------------
block_aus() {  # Datei -> Block zwischen den Markern, Einrueckung der Markerzeile entfernt
  awk '
    /# >>> geheim_schuetzen \(#3251\)/ { match($0, /^ */); n = RLENGTH; drin = 1 }
    drin { print (length($0) > n ? substr($0, n + 1) : "") }
    /# <<< geheim_schuetzen/ { drin = 0 }
  ' "$1"
}
VORLAGEN=(
  templates/github/workflows/deploy.yml
  templates/github-php/workflows/deploy.yml
  templates/github-python/workflows/deploy.yml
  templates/devops/deploy.sh
  templates/devops/rollback.sh
)
for v in "${VORLAGEN[@]}"; do
  if diff <(block_aus "$ROOT/$v") "$KANON" >/dev/null; then
    ok "Block woertlich in $v"
  else
    diff <(block_aus "$ROOT/$v") "$KANON" >&2 || true
    fail "Block in $v weicht von $KANON ab"
  fi
done
for v in templates/devops/scripts/deploy-to-server.sh templates/devops/scripts/setup-server.sh; do
  if grep -qF '$(cat "$SCRIPT_DIR/geheim-schuetzen.sh")' "$ROOT/$v" && grep -q "geheim_schuetzen '\$DEPLOY_PATH'" "$ROOT/$v"; then
    ok "$v schickt den Block per ssh mit"
  else
    fail "$v ruft geheim_schuetzen nicht auf"
  fi
done

# --- 3. Verhalten ------------------------------------------------------------------
modus() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
D="$T/ziel"; mkdir -p "$D/node_modules/x" "$D/venv/lib" "$D/sub"
anlegen() { printf 'x\n' > "$D/$1"; chmod "$2" "$D/$1"; }
anlegen .env 755
anlegen .env.production 644
anlegen .env.example 644
anlegen dns_clients.json 755
anlegen sub/youtube-oauth-token.json 644
anlegen sub/youtube-cookies.txt 644
anlegen server.key 644
anlegen token-utils.js 644
anlegen node_modules/x/.env 644
anlegen venv/lib/secrets.txt 644
anlegen secrets.json 600
anlegen README.md 755
anlegen daten.txt 664
anlegen bild.png 600
chmod 777 "$D/sub"
mkdir -p "$D/geteilt"; chmod 2775 "$D/geteilt" 2>/dev/null || true
SETGID=""; [ -g "$D/geteilt" ] && SETGID=1

# shellcheck source=/dev/null
. "$KANON"
rechte_setzen "$D"
geheim_schuetzen "$D" >/dev/null

erwarte() {  # pfad modus
  local ist; ist="$(modus "$D/$1")"
  if [ "$ist" = "$2" ]; then ok "$1 -> $2"; else fail "$1 ist $ist, erwartet $2"; fi
}
erwarte .env 640
erwarte .env.production 640
erwarte dns_clients.json 640
erwarte sub/youtube-oauth-token.json 640
erwarte sub/youtube-cookies.txt 640
erwarte server.key 640
erwarte secrets.json 600            # nie weiter als vorher
erwarte .env.example 644            # Vorlage, kein Geheimnis
erwarte token-utils.js 644          # Quelltext, kein Geheimnis
erwarte node_modules/x/.env 644     # Abhaengigkeiten bleiben unberuehrt
erwarte venv/lib/secrets.txt 644
erwarte README.md 755               # ausfuehrbar blieb ausfuehrbar (X)
erwarte daten.txt 644               # Gruppe darf nicht mehr schreiben
erwarte sub 755
erwarte bild.png 644               # kein Geheimnis: lesbar wie bisher
if [ -z "$SETGID" ]; then echo "uebersprungen: setgid laesst sich hier nicht setzen"
elif [ -g "$D/geteilt" ]; then ok "setgid-Ordner behaelt setgid"; else fail "rechte_setzen hat setgid entfernt"; fi

# Scheitert das Schuetzen, muss der Lauf rot werden (chmod-Attrappe im PATH).
mkdir -p "$T/bin"; printf '#!/bin/sh\nexit 0\n' > "$T/bin/chmod"; chmod +x "$T/bin/chmod"
anlegen .env.neu 644
if ( PATH="$T/bin:$PATH" geheim_schuetzen "$D" >/dev/null 2>"$T/err" ); then
  fail "geheim_schuetzen meldete Erfolg, obwohl .env.neu weltlesbar blieb"
elif grep -q '.env.neu' "$T/err"; then
  ok "weltlesbar Gebliebenes macht den Lauf rot und wird genannt"
else
  fail "Fehlermeldung nennt .env.neu nicht"
fi
rm -f "$T/bin/chmod"; chmod 600 "$D/.env.neu"

# Dienstbenutzer: fremde Geheimnisdateien bekommen dessen Gruppe (chgrp-Attrappe).
printf '#!/bin/sh\necho "$@" >> "%s/chgrp.log"\n' "$T" > "$T/bin/chgrp"; chmod +x "$T/bin/chgrp"
DIENST="$(id -un nobody 2>/dev/null || true)"
if [ -n "$DIENST" ]; then
  ( PATH="$T/bin:$PATH" geheim_schuetzen "$D" "$DIENST" >/dev/null )
  if grep -qE "^$(id -gn "$DIENST") .*/ziel/\.env( |\$)" "$T/chgrp.log" 2>/dev/null \
     && ! grep -q 'node_modules' "$T/chgrp.log"; then
    ok "Dienstbenutzer $DIENST: Geheimnisdateien gehen an seine Gruppe, node_modules nicht"
  else
    cat "$T/chgrp.log" >&2 2>/dev/null || true
    fail "chgrp fuer den Dienstbenutzer fehlt oder trifft zu viel"
  fi
  : > "$T/chgrp.log"
  ( PATH="$T/bin:$PATH" geheim_schuetzen "$D" root >/dev/null )
  if [ -s "$T/chgrp.log" ]; then fail "root als Dienstbenutzer darf keine Gruppe aendern"; else ok "root: keine Gruppenaenderung"; fi
fi

# --- 4. Workflow-Skripte sind gueltiges Bash ---------------------------------------
for v in templates/github/workflows/deploy.yml templates/github-php/workflows/deploy.yml templates/github-python/workflows/deploy.yml; do
  awk '
    /^          script: \|/ { drin = 1; next }
    drin && /^      - name:/ { drin = 0 }
    drin && /^[^ ]/ { drin = 0 }
    drin { print (length($0) > 12 ? substr($0, 13) : "") }
  ' "$ROOT/$v" | sed -E 's/\{\{[A-Z_]+\}\}/X/g; s/\$\{\{[^}]*\}\}/X/g' > "$T/skript.sh"
  if bash -n "$T/skript.sh" 2>"$T/err"; then ok "bash -n $v"; else cat "$T/err" >&2; fail "bash -n $v"; fi
done
for v in templates/devops/deploy.sh templates/devops/rollback.sh templates/devops/scripts/deploy-to-server.sh \
         templates/devops/scripts/setup-server.sh templates/devops/scripts/geheim-schuetzen.sh; do
  if bash -n "$ROOT/$v" 2>"$T/err"; then ok "bash -n $v"; else cat "$T/err" >&2; fail "bash -n $v"; fi
done

[ "$FEHLER" -eq 0 ] && echo "Alle Pruefungen bestanden." || { echo "Pruefungen fehlgeschlagen." >&2; exit 1; }
