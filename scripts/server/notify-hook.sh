#!/usr/bin/env bash
# /Users/Shared/sh/bin/notify-hook.sh - hook Notification Claude Code: push przez notify.sh.
#
#   notify-hook.sh <zgoda|czeka>     (JSON hooka na stdin)
#
#   zgoda  matcher permission_prompt: "Claude czeka na zgodę"
#   czeka  matcher idle_prompt: "Claude czeka na Ciebie", tylko orkiestrator (worker nie wysyła)
#
# Tresc pushu: "PROJEKT / ROLA", z katalogu sesji (pole cwd):
#   SH_DIR/wt/NAZWA/NR[/...]      -> "NAZWA / worker #NR"
#   SH_DIR/projekty/NAZWA[/...]   -> "NAZWA / orkiestrator"
#   SH_DIR (inny katalog w SH_DIR) -> "NAZWA / orkiestrator"; NAZWA z ostatniego "--projekt NAZWA"
#                                   albo "projekty/NAZWA" w koncowce transkryptu, inaczej "SH"
#   poza SH_DIR                   -> nazwa katalogu sesji
#
# Dziala tylko przy SH_NOTIFY=1 (ustawiaja je shctl task dispatch i sh-start.sh). Zawsze konczy sie
# kodem 0, zeby blad wysylki nie trafial do sesji. SH_DIR i SH_NOTIFY_CMD jak w shctl.
set -uo pipefail

[ "${SH_NOTIFY:-}" = 1 ] || exit 0

SH_DIR="${SH_DIR:-/Users/Shared/sh}"
NOTIFY="${SH_NOTIFY_CMD:-$SH_DIR/bin/notify.sh}"
NAZWA_RE='[A-Za-z0-9][A-Za-z0-9._-]*'

case "${1:-}" in
  zgoda) TYTUL='Claude czeka na zgodę' ;;
  czeka) TYTUL='Claude czeka na Ciebie' ;;
  *)
    echo 'uzycie: notify-hook.sh <zgoda|czeka>' >&2
    exit 0
    ;;
esac

WEJSCIE="$(cat)"
pole() { printf '%s' "$WEJSCIE" | jq -r --arg k "$1" '.[$k] // empty' 2>/dev/null; }

KAT="$(pole cwd)"
KAT="${KAT:-$PWD}"

# Ostatni projekt wskazany w koncowce transkryptu orkiestratora.
projekt_z_transkryptu() {
  local plik nazwa
  plik="$(pole transcript_path)"
  [ -n "$plik" ] && [ -r "$plik" ] || return 0
  nazwa="$(tail -c 200000 "$plik" 2>/dev/null |
    grep -oE -- "(--projekt[ =]|projekty/)$NAZWA_RE" | tail -1 | sed -E 's#^(--projekt[ =]|projekty/)##')"
  [ -n "$nazwa" ] && [ -d "$SH_DIR/projekty/$nazwa" ] && printf '%s' "$nazwa"
}

ROLA='' PROJEKT=''
case "$KAT/" in
  "$SH_DIR"/wt/*/*/*)
    reszta="${KAT#"$SH_DIR"/wt/}"
    PROJEKT="${reszta%%/*}"
    reszta="${reszta#*/}"
    ROLA="worker #${reszta%%/*}"
    ;;
  "$SH_DIR"/projekty/*/*)
    reszta="${KAT#"$SH_DIR"/projekty/}"
    PROJEKT="${reszta%%/*}"
    ROLA=orkiestrator
    ;;
  "$SH_DIR"/*)
    PROJEKT="$(projekt_z_transkryptu)"
    PROJEKT="${PROJEKT:-SH}"
    ROLA=orkiestrator
    ;;
esac

# Worker konczy kazda ture i czeka; orkiestrator sledzi go przez herdr, wiec push jest zbedny.
[ "${ROLA%% *}" = worker ] && [ "$1" = czeka ] && exit 0

if [ -n "$ROLA" ]; then
  TRESC="$PROJEKT / $ROLA"
else
  TRESC="$(basename "$KAT")"
fi

"$NOTIFY" default "$TYTUL" "$TRESC" >/dev/null 2>&1 || true
exit 0
