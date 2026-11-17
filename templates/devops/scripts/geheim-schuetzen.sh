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
