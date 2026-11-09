#!/bin/bash
# /Users/Shared/sh/bin/sh-watchdog.sh - strażnik orkiestratora (bez AI). LaunchAgent co 5 minut.
#
#   sh-watchdog.sh     jeden przebieg: kontrola orkiestratora
#
# Gdy w panelu orkiestratora nie działa claude remote-control z cwd $SH_DIR (lib/system.sh), uruchamia
# sh-start.sh --no-attach i wysyła ntfy „Orkiestrator uruchomiony ponownie”, a gdy nie wstanie,
# „Orkiestrator nie wstał po restarcie” (raz na serię). Flaga /Users/Shared/sh/stan/autostart.off
# wyłącza restart. Limitów subskrypcji strażnik nie śledzi (SH-lite F3b): wpisy w limity.md prowadzi
# właściciel albo orkiestrator.
#
# Zmienne (testy): SH_DIR, SH_NOTIFY_CMD, SH_WATCHDOG_WS (sh), SH_WATCHDOG_PAUZA (5, s między próbami
# notify), SH_START_CMD, SH_WATCHDOG_ORKIESTRATOR (1; 0 wyłącza kontrolę), SH_WATCHDOG_ORCH_CZEKAJ
# (15, s po restarcie). Napisany pod /bin/bash 3.2 z macOS.
set -o pipefail

SH_DIR="${SH_DIR:-/Users/Shared/sh}"
# Kontrola orkiestratora i PATH: scripts/server/lib/system.sh (wspólna z sh-start.sh i doctorem).
# /Users/Shared/sh/bin/sh-watchdog.sh to dowiązanie, więc katalog repo bierzemy z celu dowiązania.
src="${BASH_SOURCE[0]}"
while [ -L "$src" ]; do
  dir="$(cd -P "$(dirname "$src")" && pwd)"
  src="$(readlink "$src")"
  case "$src" in /*) ;; *) src="$dir/$src" ;; esac
done
# shellcheck source=lib/system.sh
. "$(cd -P "$(dirname "$src")" && pwd)/lib/system.sh"
unset src dir
sh_uzupelnij_path
LOG="$SH_DIR/logs/watchdog.log"
LOCK="$SH_DIR/stan/watchdog.lock"
NOTIFY="${SH_NOTIFY_CMD:-$SH_DIR/bin/notify.sh}"
WS_LABEL="${SH_WATCHDOG_WS:-sh}"
PAUZA="${SH_WATCHDOG_PAUZA:-5}"
SH_START="${SH_START_CMD:-$SH_DIR/bin/sh-start.sh}"
ORCH_PILNUJ="${SH_WATCHDOG_ORKIESTRATOR:-1}"
ORCH_CZEKAJ="${SH_WATCHDOG_ORCH_CZEKAJ:-15}"

mkdir -p "$SH_DIR/stan" "$SH_DIR/logs"

log() {
  local linia
  linia="$(date '+%F %T') $*"
  printf '%s\n' "$linia" >>"$LOG"
  [ ! -t 1 ] || printf '%s\n' "$linia"
}

# Rotacja: jeden poprzedni plik, limit 1 MB.
if [ -f "$LOG" ] && [ "$(wc -c <"$LOG")" -gt 1048576 ]; then
  mv -f "$LOG" "$LOG.1"
fi

powiadom() {
  local i
  for i in 1 2 3; do
    "$NOTIFY" "$1" "$2" "$3" >/dev/null 2>&1 && { log "powiadomienie: $3"; return 0; }
    [ "$i" -eq 3 ] || sleep "$PAUZA"
  done
  log "BLAD: powiadomienie nie wyszło po 3 próbach: $3"
  return 1
}

# --- Orkiestrator ---------------------------------------------------------------------------

# Orkiestrator: orkiestrator_dziala z lib/system.sh (panel „orkiestrator” w workspace $WS_LABEL,
# proces claude remote-control z cwd $SH_DIR).
ORK_WS="$WS_LABEL"

# Brak orkiestratora: sh-start.sh --no-attach i powiadomienie. Flaga autostart.off wyłącza
# także ten restart. Nieudany restart zgłaszany raz, do pierwszego udanego.
pilnuj_orkiestratora() {
  local blad="$SH_DIR/stan/orkiestrator-restart-blad" i obcy
  [ "$ORCH_PILNUJ" = 1 ] || return 0
  if [ -e "$SH_DIR/stan/autostart.off" ]; then
    orkiestrator_dziala || log "orkiestrator nie działa, restart wyłączony flagą autostart.off"
    return 0
  fi
  command -v herdr >/dev/null && command -v jq >/dev/null || {
    log "UWAGA: brak herdr albo jq w PATH, pomijam kontrolę orkiestratora"
    return 0
  }
  orkiestrator_dziala && { rm -f "$blad"; return 0; }
  # Instancja poza panelem blokuje start drugiej; restart nic by nie dał.
  obcy="$(ork_pid_poza_panelem)"
  if [ -n "$obcy" ]; then
    log "UWAGA: claude remote-control (PID $obcy) działa w $SH_DIR poza panelem orkiestratora, nie restartuję"
    return 0
  fi
  if [ ! -x "$SH_START" ]; then
    log "BLAD: orkiestrator nie działa, brak $SH_START"
    return 0
  fi
  log "orkiestrator nie działa, uruchamiam $SH_START --no-attach"
  "$SH_START" --no-attach >>"$SH_DIR/logs/sh-start.log" 2>&1 || log "UWAGA: $SH_START zakończył się błędem"
  for ((i = 0; i < ORCH_CZEKAJ; i++)); do
    orkiestrator_dziala && break
    sleep 1
  done
  if orkiestrator_dziala; then
    rm -f "$blad"
    log "orkiestrator uruchomiony ponownie"
    powiadom high "Orkiestrator" "Orkiestrator uruchomiony ponownie"
  else
    log "BLAD: orkiestrator nie wstał po restarcie (log: $SH_DIR/logs/sh-start.log)"
    [ -e "$blad" ] && return 0
    touch "$blad"
    powiadom urgent "Orkiestrator" "Orkiestrator nie wstał po restarcie, sprawdź /Users/Shared/sh/logs/sh-start.log"
  fi
}

# --- Przebieg -------------------------------------------------------------------------------

if ! mkdir "$LOCK" 2>/dev/null; then
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +10 2>/dev/null)" ]; then
    log "UWAGA: usuwam stary lock $LOCK"
    rmdir "$LOCK" 2>/dev/null
    mkdir "$LOCK" 2>/dev/null || { log "BLAD: nie mogę założyć $LOCK"; exit 1; }
  else
    log "poprzedni przebieg trwa, pomijam"
    exit 0
  fi
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

pilnuj_orkiestratora
