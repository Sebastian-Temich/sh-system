#!/usr/bin/env bash
# /Users/Shared/sh/bin/sh-start.sh - workspace herdr "sh": panel 1 orkiestrator, panel 2 powloka.
#
#   sh-start.sh               przygotowuje workspace i podlacza terminal (gdy jest TTY)
#   sh-start.sh --no-attach   tylko przygotowuje workspace
#   sh-start.sh --autostart   jak --no-attach, ale najpierw czeka na Docker Desktop i siec;
#                             przy fladze /Users/Shared/sh/stan/autostart.off konczy prace z kodem 0
#
# Idempotentny: niczego nie duplikuje. Po restarcie serwera herdr odtwarza uklad, ale nie
# procesy, dlatego orkiestrator jest uruchamiany ponownie tylko wtedy, gdy nie dziala.
#
# Kazde uruchomienie zaczyna sie wpisem "start" i konczy dokladnie jednym wpisem koncowym
# z kodem wyjscia: "gotowe: ... (kod 0)", "UWAGA: ... (kod 0)" albo "BLAD: ... (kod N)".
# BLAD podaje krok, w ktorym skrypt sie zatrzymal; kod 142 to przekroczony czas herdr.
set -Eeuo pipefail

SH_DIR="${SH_DIR:-/Users/Shared/sh}"
LOG_DIR="$SH_DIR/logs"
WS_LABEL=sh
ORCH_LABEL=orkiestrator
SHELL_LABEL=powloka
DOCKER_TIMEOUT=300
NETWORK_TIMEOUT=120
# Komunikat claude remote-control, gdy /Users/Shared/sh obsluguje juz inna instancja.
ALREADY_SERVED='This folder is already served by a terminal claude remote-control'
SERVED_WAIT_MS="${SH_SERVED_WAIT_MS:-8000}"
# Limit pojedynczego wywolania herdr; zawieszony serwer nie moze zatrzymac skryptu bez sladu.
HERDR_TIMEOUT="${SH_HERDR_TIMEOUT:-30}"

# Kontrola orkiestratora i PATH: scripts/server/lib/system.sh (wspolna z watchdogiem i doctorem).
# /Users/Shared/sh/bin/sh-start.sh to dowiazanie, wiec katalog repo bierzemy z celu dowiazania.
src="${BASH_SOURCE[0]}"
while [[ -L "$src" ]]; do
  dir="$(cd -P "$(dirname "$src")" && pwd)"
  src="$(readlink "$src")"
  [[ "$src" == /* ]] || src="$dir/$src"
done
# shellcheck source=lib/system.sh
. "$(cd -P "$(dirname "$src")" && pwd)/lib/system.sh"
unset src dir

MODE="${1:-attach}"
STEP='przygotowanie'
DONE_MSG=''
FAIL_MSG=''
FAIL_CMD=''
FAIL_LINE=''
SIGNAL=''
WARNINGS=()

log() { printf '%s sh-start: %s\n' "$(date '+%F %T')" "$*"; }
warn() { WARNINGS+=("$*"); log "UWAGA: $*"; }
# Wpis BLAD pisze on_exit, z krokiem i kodem.
die() { FAIL_MSG="$*"; exit 1; }

on_err() {
  [[ -z "$FAIL_CMD" ]] || return 0
  FAIL_LINE="$1"
  FAIL_CMD="$(printf '%s' "$2" | tr -s ' \t\n' '   ')"
}

on_signal() {
  SIGNAL="$1"
  exit "$2"
}

# Jedyny wpis koncowy kazdego przebiegu.
final_log() {
  local code="$1"
  if ((code != 0)); then
    if [[ -n "$SIGNAL" ]]; then
      log "BLAD: przerwano sygnalem $SIGNAL, krok: $STEP (kod $code)" >&2
    elif [[ -n "$FAIL_MSG" ]]; then
      log "BLAD: $FAIL_MSG, krok: $STEP (kod $code)" >&2
    elif ((code == 142)); then
      log "BLAD: herdr nie odpowiedzial w ${HERDR_TIMEOUT} s, krok: $STEP, linia ${FAIL_LINE:-?}: ${FAIL_CMD:-?} (kod $code)" >&2
    else
      log "BLAD: nieudane polecenie, krok: $STEP, linia ${FAIL_LINE:-?}: ${FAIL_CMD:-?} (kod $code)" >&2
    fi
  elif ((${#WARNINGS[@]} > 0)); then
    log "UWAGA: ${DONE_MSG:-zakonczono}; ostrzezen: ${#WARNINGS[@]}, ostatnie: ${WARNINGS[${#WARNINGS[@]} - 1]} (kod 0)"
  else
    log "gotowe: ${DONE_MSG:-zakonczono} (kod 0)"
  fi
}

on_exit() {
  local code=$?
  trap - ERR EXIT
  final_log "$code"
  exit "$code"
}

trap 'on_err "$LINENO" "$BASH_COMMAND"' ERR
trap on_exit EXIT
trap 'on_signal TERM 143' TERM
trap 'on_signal HUP 129' HUP
trap 'on_signal INT 130' INT

log "start: tryb $MODE, PID $$, rodzic: $(ps -o args= -p "$PPID" 2>/dev/null | cut -c1-80 || true)"

# claude remote-control jest serwerem sesji: kazda nowa sesja dziedziczy jego PATH. Panel
# herdr i launchd nie gwarantuja pelnego PATH, wiec skrypt sklada go sam (bez duplikatow)
# i przekazuje jawnie serwerowi herdr i orkiestratorowi. Kolejnosc: /Users/Shared/sh/bin, ~/.local/bin,
# biezacy PATH, katalogi narzedzi, na koncu ~/.softwarehouse/bin (nie przeslania naszych polecen).
build_path() {
  local out='' dir sw="$HOME/.softwarehouse/bin"
  local -a dirs
  IFS=: read -ra dirs <<<"$SH_DIR/bin:$HOME/.local/bin:${PATH:-}:/opt/homebrew/bin:/usr/local/bin:$HOME/.docker/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  for dir in "${dirs[@]}"; do
    [[ -n "$dir" && "$dir" != "$sw" && -d "$dir" && ":$out:" != *":$dir:"* ]] || continue
    out="${out:+$out:}$dir"
  done
  [[ ! -d "$sw" ]] || out="${out:+$out:}$sw"
  printf '%s' "$out"
}
PATH="$(build_path)"
export PATH

# SH_NOTIFY=1 wlacza hook Notification z ~/.claude/settings.json (push, gdy orkiestrator czeka).
# --permission-mode auto: kazda sesja tworzona przez remote-control startuje w trybie Auto
# (bez tego sesje z aplikacji startowaly w trybie default i pytaly o zgode).
ORCH_CMD="PATH='${PATH//\'/\'\\\'\'}' SH_NOTIFY=1 claude remote-control --name sh-orkiestrator --permission-mode auto"

# Tylko start przez launchd; recznie sh-start.sh dziala zawsze.
if [[ "$MODE" == --autostart && -e "$SH_DIR/stan/autostart.off" ]]; then
  log 'autostart wyłączony przez właściciela'
  DONE_MSG='autostart wyłączony, nic nie uruchamiam'
  exit 0
fi

HERDR_BIN="$(command -v herdr)" || die 'brak herdr w PATH'
command -v jq >/dev/null || die 'brak jq w PATH'
command -v perl >/dev/null || die 'brak perl w PATH'
mkdir -p "$LOG_DIR"

# Kazde wywolanie herdr z limitem czasu (SIGALRM, kod 142).
herdr() {
  perl -e 'alarm shift; exec @ARGV or die "exec $ARGV[0]: $!\n"' "$HERDR_TIMEOUT" "$HERDR_BIN" "$@"
}

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
  warn "Docker niegotowy po ${DOCKER_TIMEOUT} s, kontynuuje bez niego"
}

wait_network() {
  # Bez -f: kazda odpowiedz HTTP oznacza siec, a claude.ai odrzuca curla kodem 403.
  local i
  for ((i = 0; i < NETWORK_TIMEOUT / 5; i++)); do
    curl -sS -m 4 -o /dev/null https://api.anthropic.com 2>/dev/null && return 0
    sleep 5
  done
  warn "brak sieci po ${NETWORK_TIMEOUT} s"
}

ensure_server() {
  herdr workspace list >/dev/null 2>&1 && return 0
  log 'startuje serwer herdr'
  # Wlasna sesja (setsid): gdy sh-start.sh uruchamia job launchd bez AbandonProcessGroup
  # (watchdog), launchd po jego zakonczeniu zabija cala grupe procesow, a z nia serwer
  # i orkiestratora.
  nohup perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV or die "exec $ARGV[0]: $!\n"' \
    "$HERDR_BIN" server >>"$LOG_DIR/herdr-server.log" 2>&1 &
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
  orkiestrator_dziala "$ORCH_PANE"
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
  warn 'powloka nie zglosila gotowosci w 30 s, wysylam komende mimo to'
}

served_count() {
  herdr pane read "$ORCH_PANE" --source recent-unwrapped --lines 500 2>/dev/null |
    grep -cF "$ALREADY_SERVED" || true
}

ensure_orchestrator() {
  STEP='sprawdzanie dzialajacego orkiestratora'
  if orchestrator_running; then
    log "orkiestrator juz dziala w $ORCH_PANE"
    return 0
  fi
  local pid
  STEP='sprawdzanie drugiej instancji'
  pid="$(ork_pid_poza_panelem)"
  if [[ -n "$pid" ]]; then
    warn "$SH_DIR obsluguje juz claude remote-control (PID $pid) poza $ORCH_PANE, nie uruchamiam drugiej instancji"
    return 0
  fi
  STEP='czekanie na powloke panelu'
  wait_shell_ready
  local before after i
  before="$(served_count)"
  STEP='uruchamianie orkiestratora'
  log "uruchamiam orkiestratora w $ORCH_PANE"
  herdr pane run "$ORCH_PANE" "$ORCH_CMD" >/dev/null
  # Druga instancja konczy sie od razu tym komunikatem; startu nie ponawiamy.
  STEP='czekanie na start orkiestratora'
  for ((i = 0; i < SERVED_WAIT_MS / 500; i++)); do
    after="$(served_count)"
    if ((after > before)); then
      warn "$SH_DIR obsluguje juz inny terminal claude remote-control, nie uruchamiam drugiej instancji"
      return 0
    fi
    sleep 0.5
  done
  STEP='weryfikacja startu orkiestratora'
  if orchestrator_running; then
    log "orkiestrator dziala w $ORCH_PANE"
  else
    warn "po ${SERVED_WAIT_MS} ms nie widac procesu claude w $ORCH_PANE"
  fi
}

case "$MODE" in
  attach | --no-attach) ;;
  --autostart)
    STEP='czekanie na Docker'
    wait_docker
    STEP='czekanie na siec'
    wait_network
    ;;
  *) die "nieznana opcja: $MODE" ;;
esac

STEP='serwer herdr'
ensure_server
STEP='uklad workspace'
ensure_layout
ensure_orchestrator
DONE_MSG="workspace $WS_ID, orkiestrator $ORCH_PANE"

if [[ "$MODE" == attach && -t 0 && -t 1 && -z "${HERDR_ENV:-}" ]]; then
  STEP='podlaczanie terminala'
  herdr workspace focus "$WS_ID" >/dev/null
  # exec nie uruchamia pulapki EXIT, wiec wpis koncowy powstaje teraz.
  trap - ERR EXIT
  final_log 0
  exec "$HERDR_BIN"
fi
