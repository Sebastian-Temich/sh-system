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
