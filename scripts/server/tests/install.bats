#!/usr/bin/env bats
# Test LaunchAgentow w install.sh na atrapach launchctl i notify.

bats_require_minimum_version 1.5.0

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  T="$BATS_TEST_TMPDIR"
  LABEL=pl.iskt.softwarehouse.sh-start
  PLIST="$T/agents/$LABEL.plist"
  mkdir -p "$T/sh" "$T/agents" "$T/mock"

  cat >"$T/mock/launchctl" <<MOCK
#!/bin/sh
echo "\$1" >>"$T/calls"
case "\$1" in
  print) [ -f "$T/loaded" ] ;;
  bootout) rm -f "$T/loaded" ;;
  bootstrap) [ ! -f "$T/fail" ] && touch "$T/loaded" ;;
esac
MOCK
  cat >"$T/mock/notify" <<MOCK
#!/bin/sh
echo "\$*" >>"$T/notified"
[ ! -f "$T/notify-fail" ]
MOCK
  chmod +x "$T/mock/launchctl" "$T/mock/notify"
  cp "$REPO/scripts/server/$LABEL.plist" "$PLIST"
  : >"$T/calls"
}

install() {
  PATH="$T/mock:$PATH" SH_DIR="$T/sh" SH_AGENTS="$T/agents" SH_NOTIFY_CMD="$T/mock/notify" \
    run --separate-stderr bash "$REPO/scripts/server/install.sh"
}

@test "zaladowany, plista bez zmian: tylko print" {
  touch "$T/loaded"
  install
  [ "$status" -eq 0 ]
  [ "$(cat "$T/calls")" = print ]
  [ ! -f "$T/notified" ]
}

@test "niezaladowany, plista bez zmian: bootstrap" {
  install
  [ "$status" -eq 0 ]
  [ "$(tr '\n' ' ' <"$T/calls")" = "print bootstrap " ]
  [ -f "$T/loaded" ]
  [ ! -f "$T/notified" ]
}

@test "blad bootstrap: kod bledu, komenda reczna, notify high" {
  touch "$T/fail"
  install
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"launchctl bootstrap gui/$(id -u) $PLIST"* ]]
  [[ "$(cat "$T/notified")" == high* ]]
}

@test "blad bootstrap i blad notify: nadal kod bledu" {
  touch "$T/fail" "$T/notify-fail"
  install
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"nie udalo sie wyslac"* ]]
}

@test "po bledzie bootstrap kolejne uruchomienie laduje agenta" {
  rm "$PLIST"
  touch "$T/fail"
  install
  [ "$status" -eq 1 ]
  rm "$T/fail"
  install
  [ "$status" -eq 0 ]
  [ -f "$T/loaded" ]
}

@test "zaladowany, plista zmieniona: bootout i bootstrap" {
  touch "$T/loaded"
  echo '<!-- x -->' >>"$PLIST"
  install
  [ "$status" -eq 0 ]
  [ "$(tr '\n' ' ' <"$T/calls")" = "bootout bootstrap " ]
  cmp "$REPO/scripts/server/$LABEL.plist" "$PLIST"
}
