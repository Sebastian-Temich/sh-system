#!/usr/bin/env bash
# ~/sh/bin/sh-start.sh - workspace herdr "sh": panel 1 orkiestrator, panel 2 powloka.
#
#   sh-start.sh               przygotowuje workspace i podlacza terminal (gdy jest TTY)
#   sh-start.sh --no-attach   tylko przygotowuje workspace
#   sh-start.sh --autostart   jak --no-attach, ale najpierw czeka na Docker Desktop i siec;
#                             przy fladze ~/sh/stan/autostart.off konczy prace z kodem 0
#
# Idempotentny: niczego nie duplikuje. Po restarcie serwera herdr odtwarza uklad, ale nie
# procesy, dlatego orkiestrator jest uruchamiany ponownie tylko wtedy, gdy nie dziala.
set -euo pipefail

SH_DIR="$HOME/sh"
LOG_DIR="$SH_DIR/logs"
WS_LABEL=sh
ORCH_LABEL=orkiestrator
SHELL_LABEL=powloka
ORCH_CMD='claude remote-control --name sh-orkiestrator'
DOCKER_TIMEOUT=300
NETWORK_TIMEOUT=120

MODE="${1:-attach}"
log() { printf '%s sh-start: %s\n' "$(date '+%F %T')" "$*"; }
die() { log "BLAD: $*" >&2; exit 1; }

# Tylko start przez launchd; recznie sh-start.sh dziala zawsze.
if [[ "$MODE" == --autostart && -e "$SH_DIR/stan/autostart.off" ]]; then
  log 'autostart wyłączony przez właściciela'
  exit 0
fi

command -v herdr >/dev/null || die 'brak herdr w PATH'
command -v jq >/dev/null || die 'brak jq w PATH'
mkdir -p "$LOG_DIR"

wait_docker() {
  docker info >/dev/null 2>&1 && return 0
  # AutoStart Docker Desktop jest wylaczony; samo uruchomienie nie zmienia jego ustawien.
  log 'uruchamiam Docker Desktop'
  open -ga Docker || log 'nie udalo sie uruchomic Docker Desktop'
  local i
  for ((i = 0; i < DOCKER_TIMEOUT / 5; i++)); do
    docker info >/dev/null 2>&1 && { log 'Docker gotowy'; return 0; }
    sleep 5
  done
  log "UWAGA: Docker niegotowy po ${DOCKER_TIMEOUT} s, kontynuuje bez niego"
}

wait_network() {
  # Bez -f: kazda odpowiedz HTTP oznacza siec, a claude.ai odrzuca curla kodem 403.
  local i
  for ((i = 0; i < NETWORK_TIMEOUT / 5; i++)); do
    curl -sS -m 4 -o /dev/null https://api.anthropic.com 2>/dev/null && return 0
    sleep 5
  done
  log "UWAGA: brak sieci po ${NETWORK_TIMEOUT} s"
}

ensure_server() {
  herdr workspace list >/dev/null 2>&1 && return 0
  log 'startuje serwer herdr'
  nohup herdr server >>"$LOG_DIR/herdr-server.log" 2>&1 &
  disown
  local i
  for ((i = 0; i < 40; i++)); do
    herdr workspace list >/dev/null 2>&1 && return 0
    sleep 0.5
  done
  die 'serwer herdr nie odpowiada'
}

pane_by_label() {
  herdr pane list --workspace "$1" |
    jq -r --arg l "$2" '[.result.panes[] | select(.label == $l)][0].pane_id // empty'
}

ensure_layout() {
  WS_ID="$(herdr workspace list |
    jq -r --arg l "$WS_LABEL" '[.result.workspaces[] | select(.label == $l)][0].workspace_id // empty')"

  if [[ -z "$WS_ID" ]]; then
    log "tworze workspace $WS_LABEL"
    local created
    created="$(herdr workspace create --cwd "$SH_DIR" --label "$WS_LABEL" --no-focus)"
    WS_ID="$(jq -r .result.workspace.workspace_id <<<"$created")"
    herdr pane rename "$(jq -r .result.root_pane.pane_id <<<"$created")" "$ORCH_LABEL" >/dev/null
  fi

  ORCH_PANE="$(pane_by_label "$WS_ID" "$ORCH_LABEL")"
  if [[ -z "$ORCH_PANE" ]]; then
    ORCH_PANE="$(herdr pane list --workspace "$WS_ID" | jq -r '.result.panes[0].pane_id')"
    herdr pane rename "$ORCH_PANE" "$ORCH_LABEL" >/dev/null
  fi

  if [[ -z "$(pane_by_label "$WS_ID" "$SHELL_LABEL")" ]]; then
    local new
    new="$(herdr pane split "$ORCH_PANE" --direction right --cwd "$SH_DIR" --no-focus |
      jq -r .result.pane.pane_id)"
    herdr pane rename "$new" "$SHELL_LABEL" >/dev/null
  fi
}

orchestrator_running() {
  herdr pane process-info --pane "$ORCH_PANE" |
    jq -e '[.result.process_info.foreground_processes[].cmdline] | any(test("(^|/)claude( |$)"))' >/dev/null
}

# Powloka jest gotowa, gdy zostal sam proces glowny (.zshrc odpala podprocesy).
wait_shell_ready() {
  local i n
  for ((i = 0; i < 60; i++)); do
    n="$(herdr pane process-info --pane "$ORCH_PANE" |
      jq '.result.process_info.foreground_processes | length')"
    [[ "$n" == 1 ]] && return 0
    sleep 0.5
  done
  log 'UWAGA: powloka nie zglosila gotowosci w 30 s, wysylam komende mimo to'
}

ensure_orchestrator() {
  if orchestrator_running; then
    log "orkiestrator juz dziala w $ORCH_PANE"
    return 0
  fi
  wait_shell_ready
  log "uruchamiam orkiestratora w $ORCH_PANE"
  herdr pane run "$ORCH_PANE" "$ORCH_CMD" >/dev/null
}

case "$MODE" in
  attach | --no-attach) ;;
  --autostart)
    wait_docker
    wait_network
    ;;
  *) die "nieznana opcja: $MODE" ;;
esac

ensure_server
ensure_layout
ensure_orchestrator
log "gotowe: workspace $WS_ID, orkiestrator $ORCH_PANE"

if [[ "$MODE" == attach && -t 0 && -t 1 && -z "${HERDR_ENV:-}" ]]; then
  herdr workspace focus "$WS_ID" >/dev/null
  exec herdr
fi
