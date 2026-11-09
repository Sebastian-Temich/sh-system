#!/usr/bin/env bats
# Strażnik orkiestratora sh-watchdog.sh na atrapach herdr, sh-start i notify.

bats_require_minimum_version 1.5.0

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  T="$BATS_TEST_TMPDIR"
  export TZ=Europe/Warsaw
  mkdir -p "$T/sh" "$T/mock" "$T/panele"

  # herdr: workspace "sh" (w1), panele z $T/panele/<id>.txt, etykieta z $T/panele/<id>.label.
  cat >"$T/mock/herdr" <<MOCK
#!/bin/bash
[ -f "$T/herdr-off" ] && exit 1
case "\$1 \$2" in
  "workspace list") echo '{"result":{"workspaces":[{"workspace_id":"w1","label":"sh"}]}}' ;;
  "pane list")
    for f in "$T"/panele/*.txt; do
      [ -e "\$f" ] || continue
      id="\$(basename "\$f" .txt)"
      jq -nc --arg i "\${id/_/:}" --arg l "\$(cat "$T/panele/\$id.label" 2>/dev/null)" '{pane_id:\$i, label:\$l}'
    done | jq -sc '{result:{panes:.}}' ;;
  "pane read") cat "$T/panele/\${3/:/_}.txt" ;;
  "pane process-info")
    if [ -f "$T/orch-dziala" ]; then
      echo '{"result":{"process_info":{"foreground_processes":[{"argv":["claude","remote-control","--name","sh-orkiestrator"],"cwd":"$T/sh","pid":777}]}}}'
    else
      echo '{"result":{"process_info":{"foreground_processes":[{"argv":["-zsh"],"cwd":"$T/sh","pid":11}]}}}'
    fi ;;
  *) exit 2 ;;
esac
MOCK
  cat >"$T/mock/notify" <<MOCK
#!/bin/sh
printf '%s|%s|%s\n' "\$1" "\$2" "\$3" >>"$T/notified"
[ ! -f "$T/notify-fail" ]
MOCK
  chmod +x "$T/mock/herdr" "$T/mock/notify"
}

# 2026-11-02 14:00 w Warszawie (CET, UTC+1).
TERAZ_14=1793624400

straznik() {
  PATH="$T/mock:$PATH" SH_DIR="$T/sh" SH_NOTIFY_CMD="$T/mock/notify" SH_WATCHDOG_PAUZA=0 \
    SH_WATCHDOG_ORKIESTRATOR="${ORKIESTRATOR:-0}" SH_START_CMD="$T/mock/sh-start" SH_WATCHDOG_ORCH_CZEKAJ=2 \
    SH_WATCHDOG_TERAZ="${1:-$TERAZ_14}" run bash "$REPO/scripts/server/sh-watchdog.sh"
}

panel() { # id etykieta tekst
  printf '%s\n' "$3" >"$T/panele/${1/:/_}.txt"
  printf '%s' "$2" >"$T/panele/${1/:/_}.label"
}

powiadomienia() { cat "$T/notified" 2>/dev/null | wc -l | tr -d ' '; }

@test "plista: co 5 minut, /bin/bash, skrypt z /Users/Shared/sh/bin" {
  local p="$REPO/scripts/server/pl.iskt.softwarehouse.sh-watchdog.plist"
  grep -A1 StartInterval "$p" | grep -q '<integer>300</integer>'
  grep -q '<string>/bin/bash</string>' "$p"
  grep -q 'sh/bin/sh-watchdog.sh</string>' "$p"
}

@test "bez skanu limitow: panele nieczytane, limity.md nietkniete" {
  panel w1:p2 worker "You've hit your 5-hour limit · resets 7pm"
  printf '# Limity\n\n- reczny wpis\n' >"$T/sh/limity.md"
  cp "$T/sh/limity.md" "$T/limity.przed"
  straznik
  [ "$status" -eq 0 ]
  cmp "$T/sh/limity.md" "$T/limity.przed"
  [ "$(powiadomienia)" -eq 0 ]
  [ ! -e "$T/sh/stan/watchdog-widziane.txt" ]
  [ ! -d "$T/sh/stan/watchdog.lock" ]
}

# --- Orkiestrator: panel w1:p1 „orkiestrator” w atrapie herdr; $T/orch-dziala = w panelu działa
# claude remote-control z cwd $T/sh. $T/orch-obcy = taki proces działa poza panelem (ps, lsof). ---

atrapy_orkiestratora() {
  : >"$T/panele/w1_p1.txt"
  echo orkiestrator >"$T/panele/w1_p1.label"
  printf '#!/bin/sh\n[ -f "%s/orch-obcy" ] && echo " 4242 claude remote-control"\nexit 0\n' "$T" >"$T/mock/ps"
  printf '#!/bin/sh\necho p4242\necho n%s/sh\n' "$T" >"$T/mock/lsof"
  # sh-start: zapisuje wywołanie; bez $T/start-psuje „uruchamia” orkiestratora.
  printf '#!/bin/sh\necho "$*" >>"%s/start-calls"\n[ -f "%s/start-psuje" ] || touch "%s/orch-dziala"\n' "$T" "$T" "$T" >"$T/mock/sh-start"
  chmod +x "$T/mock/ps" "$T/mock/lsof" "$T/mock/sh-start"
  mkdir -p "$T/sh/logs" "$T/sh/stan"
}

@test "orkiestrator dziala: bez restartu i powiadomien" {
  atrapy_orkiestratora
  touch "$T/orch-dziala"
  ORKIESTRATOR=1 straznik
  [ "$status" -eq 0 ]
  [ ! -f "$T/start-calls" ]
  [ "$(powiadomienia)" -eq 0 ]
}

@test "brak orkiestratora: sh-start --no-attach i powiadomienie" {
  atrapy_orkiestratora
  ORKIESTRATOR=1 straznik
  [ "$status" -eq 0 ]
  [ "$(cat "$T/start-calls")" = "--no-attach" ]
  grep -q '^high|Orkiestrator|Orkiestrator uruchomiony ponownie$' "$T/notified"
  grep -q 'orkiestrator uruchomiony ponownie' "$T/sh/logs/watchdog.log"
}

@test "nieudany restart: jedno pilne powiadomienie na serie" {
  atrapy_orkiestratora
  touch "$T/start-psuje"
  ORKIESTRATOR=1 straznik
  ORKIESTRATOR=1 straznik
  [ "$(wc -l <"$T/start-calls" | tr -d ' ')" -eq 2 ]
  [ "$(powiadomienia)" -eq 1 ]
  grep -q '^urgent|Orkiestrator|Orkiestrator nie wstał' "$T/notified"
}

@test "flaga autostart.off: bez restartu" {
  atrapy_orkiestratora
  touch "$T/sh/stan/autostart.off"
  ORKIESTRATOR=1 straznik
  [ ! -f "$T/start-calls" ]
  [ "$(powiadomienia)" -eq 0 ]
  grep -q 'restart wyłączony flagą autostart.off' "$T/sh/logs/watchdog.log"
}

@test "claude remote-control poza panelem: bez restartu, wpis w logu" {
  atrapy_orkiestratora
  touch "$T/orch-obcy"
  ORKIESTRATOR=1 straznik
  [ "$status" -eq 0 ]
  [ ! -f "$T/start-calls" ]
  [ "$(powiadomienia)" -eq 0 ]
  grep -q 'PID 4242) działa w .* poza panelem orkiestratora, nie restartuję' "$T/sh/logs/watchdog.log"
}

@test "minimalne srodowisko launchd (PATH=/usr/bin:/bin): herdr z ~/.local/bin, orkiestrator widoczny" {
  atrapy_orkiestratora
  touch "$T/orch-dziala"
  mkdir -p "$T/home/.local/bin"
  cp "$T/mock/herdr" "$T/mock/sh-start" "$T/home/.local/bin/"
  ln -s "$(command -v jq)" "$T/home/.local/bin/jq"
  run env -i HOME="$T/home" PATH=/usr/bin:/bin SH_DIR="$T/sh" SH_NOTIFY_CMD="$T/mock/notify" \
    SH_WATCHDOG_PAUZA=0 SH_START_CMD="$T/home/.local/bin/sh-start" SH_WATCHDOG_TERAZ="$TERAZ_14" \
    bash "$REPO/scripts/server/sh-watchdog.sh"
  [ "$status" -eq 0 ]
  [ ! -f "$T/start-calls" ]
  ! grep -q 'brak herdr albo jq' "$T/sh/logs/watchdog.log" || false
}
