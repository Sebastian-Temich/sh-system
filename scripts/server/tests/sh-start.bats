#!/usr/bin/env bats
# Flaga autostart.off w sh-start.sh, na atrapach herdr i docker.

bats_require_minimum_version 1.5.0

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  T="$BATS_TEST_TMPDIR"
  # Testy nie mogą sięgać do prawdziwego /Users/Shared/sh.
  export SH_DIR="$T/home/sh"
  mkdir -p "$T/home/sh/stan" "$T/mock"
  for cmd in herdr docker; do
    cat >"$T/mock/$cmd" <<MOCK
#!/bin/sh
echo "$cmd \$*" >>"$T/calls"
[ "$cmd" = docker ]
MOCK
    chmod +x "$T/mock/$cmd"
  done
}

start() {
  HOME="$T/home" PATH="$T/mock:$PATH" run -- bash "$REPO/scripts/server/sh-start.sh" "$@"
}

@test "plista uruchamia sh-start.sh z --autostart" {
  grep -q 'sh-start.sh" --autostart' "$REPO/scripts/server/pl.iskt.softwarehouse.sh-start.plist"
}

@test "--autostart z flaga: kod 0, wpis w logu, zadnych uslug" {
  touch "$T/home/sh/stan/autostart.off"
  start --autostart
  [ "$status" -eq 0 ]
  [[ "$output" == *"autostart wyłączony przez właściciela"* ]] || false
  [ ! -f "$T/calls" ]
}

@test "--autostart bez flagi: startuje uslugi" {
  start --autostart
  [[ "$output" != *"autostart wyłączony"* ]] || false
  grep -q '^docker' "$T/calls"
  grep -q '^herdr' "$T/calls"
}

@test "reczne uruchomienie z flaga: dziala" {
  touch "$T/home/sh/stan/autostart.off"
  start --no-attach
  [[ "$output" != *"autostart wyłączony"* ]] || false
  grep -q '^herdr' "$T/calls"
}

@test "uruchomienie bez argumentu z flaga: dziala" {
  touch "$T/home/sh/stan/autostart.off"
  start
  [[ "$output" != *"autostart wyłączony"* ]] || false
  grep -q '^herdr' "$T/calls"
}

# Atrapa herdr z workspace "sh" i dwoma panelami; pusty panel orkiestratora (sama powloka).
# $T/pane - wyjscie panelu, $T/run_output - to, co dopisze uruchomiona komenda.
mock_herdr() {
  cat >"$T/mock/herdr" <<MOCK
#!/bin/sh
echo "herdr \$*" >>"$T/calls"
case "\$1 \$2" in
  "workspace list") echo '{"result":{"workspaces":[{"label":"sh","workspace_id":"w1"}]}}' ;;
  "pane list") echo '{"result":{"panes":[{"label":"orkiestrator","pane_id":"w1:p1"},{"label":"powloka","pane_id":"w1:p2"}]}}' ;;
  "pane process-info")
    [ ! -f "$T/pi_fail" ] || exit 3
    [ ! -f "$T/pi_hang" ] || exec sleep 30
    if [ -f "$T/run_cmd" ] && [ ! -f "$T/run_output" ]; then
      echo '{"result":{"process_info":{"foreground_processes":[{"argv":["-zsh"],"cmdline":"-zsh","cwd":"$T/home/sh","pid":11},{"argv":["claude","remote-control","--name","sh-orkiestrator"],"cmdline":"claude remote-control --name sh-orkiestrator","cwd":"$T/home/sh","pid":4243}]}}}'
    else
      echo '{"result":{"process_info":{"foreground_processes":[{"argv":["-zsh"],"cmdline":"-zsh","cwd":"$T/home/sh","pid":11}]}}}'
    fi ;;
  "pane read") cat "$T/pane" 2>/dev/null ;;
  "pane run") printf '%s\n' "\$4" >"$T/run_cmd"; cat "$T/run_output" >>"$T/pane" 2>/dev/null ;;
esac
exit 0
MOCK
  # Poza panelem nie działa żaden claude remote-control.
  printf '#!/bin/sh\nexit 0\n' >"$T/mock/ps"
  chmod +x "$T/mock/herdr" "$T/mock/ps"
}

@test "orkiestrator dostaje jawny PATH: nasze katalogi pierwsze, .softwarehouse ostatni" {
  mock_herdr
  mkdir -p "$T/home/.local/bin" "$T/home/sh/bin" "$T/home/.softwarehouse/bin"
  HOME="$T/home" SH_SERVED_WAIT_MS=0 PATH="$T/home/.softwarehouse/bin:$T/mock:/usr/bin:/bin" \
    run -- bash "$REPO/scripts/server/sh-start.sh" --no-attach
  [ "$status" -eq 0 ]
  grep -q "^PATH='$T/home/sh/bin:$T/home/.local/bin:$T/mock:[^']*:$T/home/.softwarehouse/bin' claude remote-control --name sh-orkiestrator --permission-mode auto\$" "$T/run_cmd"
  [ "$(grep -o "$T/home/.softwarehouse/bin" "$T/run_cmd" | wc -l | tr -d ' ')" -eq 1 ]
}

@test "komunikat already served: log, kod 0, bez ponownego startu" {
  mock_herdr
  echo "Error: This folder is already served by a terminal claude remote-control" >"$T/run_output"
  start --no-attach
  [ "$status" -eq 0 ]
  [[ "$output" == *"nie uruchamiam drugiej instancji"* ]] || false
  [ "$(grep -c '^herdr pane run' "$T/calls")" -eq 1 ]
}

@test "stary komunikat already served w panelu nie blokuje startu" {
  mock_herdr
  echo "This folder is already served by a terminal claude remote-control" >"$T/pane"
  HOME="$T/home" SH_SERVED_WAIT_MS=1000 PATH="$T/mock:$PATH" run -- bash "$REPO/scripts/server/sh-start.sh" --no-attach
  [ "$status" -eq 0 ]
  [[ "$output" != *"drugiej instancji"* ]] || false
  grep -q '^herdr pane run' "$T/calls"
}

@test "remote-control w /Users/Shared/sh poza panelem: nie uruchamia drugiej instancji" {
  mock_herdr
  printf '#!/bin/sh\necho " 4242 claude remote-control --name sh-orkiestrator"\n' >"$T/mock/ps"
  printf '#!/bin/sh\necho p4242\necho n%s\n' "$T/home/sh" >"$T/mock/lsof"
  chmod +x "$T/mock/ps" "$T/mock/lsof"
  start --no-attach
  [ "$status" -eq 0 ]
  [[ "$output" == *"PID 4242"*"nie uruchamiam drugiej instancji"* ]] || false
  ! grep -q '^herdr pane run' "$T/calls"
}

# Ostatnia linia wyjscia to jedyny wpis koncowy przebiegu.
last_line() { printf '%s\n' "$output" | tail -n 1; }
final_count() { printf '%s\n' "$output" | grep -cE 'sh-start: (gotowe|UWAGA|BLAD): .*\(kod [0-9]+\)$' || true; }

@test "udany start: start na poczatku, gotowe z kodem 0 na koncu" {
  mock_herdr
  HOME="$T/home" SH_SERVED_WAIT_MS=0 PATH="$T/mock:$PATH" run -- bash "$REPO/scripts/server/sh-start.sh" --no-attach
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | head -n 1 | grep -q 'sh-start: start: tryb --no-attach, PID '
  [[ "$(last_line)" == *"sh-start: gotowe: workspace w1, orkiestrator w1:p1 (kod 0)" ]] || false
  [ "$(final_count)" -eq 1 ]
}

@test "orkiestrator nie wstal po starcie: wpis koncowy UWAGA z kodem 0" {
  mock_herdr
  : >"$T/run_output"
  HOME="$T/home" SH_SERVED_WAIT_MS=0 PATH="$T/mock:$PATH" run -- bash "$REPO/scripts/server/sh-start.sh" --no-attach
  [ "$status" -eq 0 ]
  [[ "$(last_line)" == *"sh-start: UWAGA: workspace w1, orkiestrator w1:p1; ostrzezen: 1, ostatnie: po 0 ms nie widac procesu claude w w1:p1 (kod 0)" ]] || false
}

@test "druga instancja: wpis koncowy UWAGA z kodem 0" {
  mock_herdr
  echo "Error: This folder is already served by a terminal claude remote-control" >"$T/run_output"
  start --no-attach
  [ "$status" -eq 0 ]
  [[ "$(last_line)" == *"sh-start: UWAGA: "*"nie uruchamiam drugiej instancji (kod 0)" ]] || false
  [ "$(final_count)" -eq 1 ]
}

@test "autostart wylaczony: wpis koncowy gotowe z kodem 0" {
  touch "$T/home/sh/stan/autostart.off"
  start --autostart
  [ "$status" -eq 0 ]
  [[ "$(last_line)" == *"sh-start: gotowe: autostart wyłączony, nic nie uruchamiam (kod 0)" ]] || false
}

@test "nieznana opcja: BLAD z krokiem i kodem 1" {
  start --cos
  [ "$status" -eq 1 ]
  [[ "$(last_line)" == *"sh-start: BLAD: nieznana opcja: --cos, krok: przygotowanie (kod 1)" ]] || false
  [ "$(final_count)" -eq 1 ]
}

@test "herdr zwraca blad przy sprawdzaniu panelu: BLAD z krokiem, linia i kodem" {
  mock_herdr
  touch "$T/pi_fail"
  start --no-attach
  [ "$status" -ne 0 ]
  [ "$status" -eq 3 ]
  [[ "$(last_line)" == *"sh-start: BLAD: nieudane polecenie, krok: czekanie na powloke panelu, linia "*"herdr pane process-info"*"(kod 3)" ]] || false
  [ "$(final_count)" -eq 1 ]
}

@test "zawieszony herdr: BLAD z kodem 142 zamiast cichego zawieszenia" {
  mock_herdr
  touch "$T/pi_hang"
  HOME="$T/home" SH_HERDR_TIMEOUT=1 PATH="$T/mock:$PATH" run -- bash "$REPO/scripts/server/sh-start.sh" --no-attach
  [ "$status" -eq 142 ]
  [[ "$(last_line)" == *"sh-start: BLAD: herdr nie odpowiedzial w 1 s, krok: czekanie na powloke panelu, linia "*"(kod 142)" ]] || false
  [ "$(final_count)" -eq 1 ]
}

@test "SIGTERM w trakcie czekania: BLAD z sygnalem, krokiem i kodem 143" {
  mock_herdr
  HOME="$T/home" SH_SERVED_WAIT_MS=20000 PATH="$T/mock:$PATH" \
    bash "$REPO/scripts/server/sh-start.sh" --no-attach >"$T/out" 2>&1 &
  local pid=$! i
  for ((i = 0; i < 50; i++)); do grep -q 'uruchamiam orkiestratora' "$T/out" && break; sleep 0.2; done
  kill -TERM "$pid"
  local rc=0
  wait "$pid" || rc=$?
  [ "$rc" -eq 143 ]
  [[ "$(tail -n 1 "$T/out")" == *"sh-start: BLAD: przerwano sygnalem TERM, krok: "*" (kod 143)" ]] || false
  grep -qE "krok: (uruchamianie orkiestratora|czekanie na start orkiestratora) \\(kod 143\\)$" "$T/out"
}

# Agenty, ktore uruchamiaja sh-start.sh, nie moga zabijac grupy procesow po swoim zakonczeniu.
abandon_pg() {
  grep -A1 '<key>AbandonProcessGroup</key>' "$REPO/scripts/server/$1" | grep -q '<true/>'
}

@test "plisty sh-start i watchdog maja AbandonProcessGroup" {
  abandon_pg pl.iskt.softwarehouse.sh-start.plist
  abandon_pg pl.iskt.softwarehouse.sh-watchdog.plist
}

@test "obsidian-sync bez AbandonProcessGroup: launchd sprzata po przebiegu" {
  ! abandon_pg pl.iskt.softwarehouse.obsidian-sync.plist
}

@test "serwer herdr startuje we wlasnej sesji (setsid)" {
  grep -q "POSIX::setsid(); exec @ARGV" "$REPO/scripts/server/sh-start.sh"
  grep -q '"$HERDR_BIN" server' "$REPO/scripts/server/sh-start.sh"
}

# launchd (agent sh-start i strażnik) daje minimalne środowisko. herdr i jq leżą w ~/.local/bin;
# sh-start.sh musi je znaleźć i rozpoznać działającego orkiestratora tą samą kontrolą co doctor.
@test "launchd: PATH=/usr/bin:/bin, orkiestrator w panelu juz dziala, bez drugiego startu" {
  mock_herdr
  : >"$T/run_cmd"
  mkdir -p "$T/home/.local/bin"
  cp "$T/mock/herdr" "$T/mock/ps" "$T/home/.local/bin/"
  ln -s "$(command -v jq)" "$T/home/.local/bin/jq"
  run env -i HOME="$T/home" SH_DIR="$SH_DIR" PATH=/usr/bin:/bin bash "$REPO/scripts/server/sh-start.sh" --no-attach
  [ "$status" -eq 0 ]
  [[ "$output" == *"orkiestrator juz dziala w w1:p1"* ]] || false
  [[ "$(last_line)" == *"sh-start: gotowe: workspace w1, orkiestrator w1:p1 (kod 0)" ]] || false
  ! grep -q '^herdr pane run' "$T/calls"
}
