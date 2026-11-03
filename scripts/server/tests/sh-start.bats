#!/usr/bin/env bats
# Flaga autostart.off w sh-start.sh, na atrapach herdr i docker.

bats_require_minimum_version 1.5.0

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  T="$BATS_TEST_TMPDIR"
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
  [[ "$output" == *"autostart wyłączony przez właściciela"* ]]
  [ ! -f "$T/calls" ]
}

@test "--autostart bez flagi: startuje uslugi" {
  start --autostart
  [[ "$output" != *"autostart wyłączony"* ]]
  grep -q '^docker' "$T/calls"
  grep -q '^herdr' "$T/calls"
}

@test "reczne uruchomienie z flaga: dziala" {
  touch "$T/home/sh/stan/autostart.off"
  start --no-attach
  [[ "$output" != *"autostart wyłączony"* ]]
  grep -q '^herdr' "$T/calls"
}

@test "uruchomienie bez argumentu z flaga: dziala" {
  touch "$T/home/sh/stan/autostart.off"
  start
  [[ "$output" != *"autostart wyłączony"* ]]
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
  "pane process-info") echo '{"result":{"process_info":{"foreground_processes":[{"cmdline":"-zsh"}]}}}' ;;
  "pane read") cat "$T/pane" 2>/dev/null ;;
  "pane run") printf '%s\n' "\$4" >"$T/run_cmd"; cat "$T/run_output" >>"$T/pane" 2>/dev/null ;;
esac
exit 0
MOCK
  printf '#!/bin/sh\nexit 1\n' >"$T/mock/pgrep"
  chmod +x "$T/mock/herdr" "$T/mock/pgrep"
}

@test "orkiestrator dostaje jawny PATH z katalogami narzedzi" {
  mock_herdr
  mkdir -p "$T/home/.local/bin"
  HOME="$T/home" SH_SERVED_WAIT_MS=0 PATH="$T/mock:/usr/bin:/bin" run -- bash "$REPO/scripts/server/sh-start.sh" --no-attach
  [ "$status" -eq 0 ]
  grep -q "^PATH='[^']*$T/home/.local/bin[^']*' SH_NOTIFY=1 claude remote-control --name sh-orkiestrator\$" "$T/run_cmd"
  grep -q "^PATH='$T/mock:" "$T/run_cmd"
}

@test "komunikat already served: log, kod 0, bez ponownego startu" {
  mock_herdr
  echo "Error: This folder is already served by a terminal claude remote-control" >"$T/run_output"
  start --no-attach
  [ "$status" -eq 0 ]
  [[ "$output" == *"nie uruchamiam drugiej instancji"* ]]
  [ "$(grep -c '^herdr pane run' "$T/calls")" -eq 1 ]
}

@test "stary komunikat already served w panelu nie blokuje startu" {
  mock_herdr
  echo "This folder is already served by a terminal claude remote-control" >"$T/pane"
  HOME="$T/home" SH_SERVED_WAIT_MS=1000 PATH="$T/mock:$PATH" run -- bash "$REPO/scripts/server/sh-start.sh" --no-attach
  [ "$status" -eq 0 ]
  [[ "$output" != *"drugiej instancji"* ]]
  grep -q '^herdr pane run' "$T/calls"
}

@test "remote-control w ~/sh poza panelem: nie uruchamia drugiej instancji" {
  mock_herdr
  printf '#!/bin/sh\necho 4242\n' >"$T/mock/pgrep"
  printf '#!/bin/sh\necho p4242\necho n%s\n' "$T/home/sh" >"$T/mock/lsof"
  chmod +x "$T/mock/pgrep" "$T/mock/lsof"
  start --no-attach
  [ "$status" -eq 0 ]
  [[ "$output" == *"PID 4242"*"nie uruchamiam drugiej instancji"* ]]
  ! grep -q '^herdr pane run' "$T/calls"
}
