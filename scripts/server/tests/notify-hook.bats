#!/usr/bin/env bats
# Hook Notification notify-hook.sh: projekt i rola w treści, bez "czeka na Ciebie" u workera.

bats_require_minimum_version 1.5.0

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  T="$BATS_TEST_TMPDIR"
  mkdir -p "$T/sh/projekty/sh-dryrun" "$T/sh/projekty/inny" "$T/sh/wt/sh-dryrun/11/src" "$T/mock"
  cat >"$T/mock/notify" <<MOCK
#!/bin/sh
printf '%s|%s|%s\n' "\$1" "\$2" "\$3" >>"$T/notified"
[ ! -f "$T/notify-fail" ]
MOCK
  chmod +x "$T/mock/notify"
  export SH_DIR="$T/sh" SH_NOTIFY_CMD="$T/mock/notify" SH_NOTIFY=1
}

# hook TYP KATALOG [TRANSKRYPT]
hook() {
  jq -nc --arg c "$2" --arg t "${3:-}" '{cwd:$c, transcript_path:$t, hook_event_name:"Notification"}' |
    "$REPO/scripts/server/notify-hook.sh" "$1"
}

@test "worker: zgoda z projektem i numerem zadania" {
  run hook zgoda "$T/sh/wt/sh-dryrun/11"
  [ "$status" -eq 0 ]
  [ "$(cat "$T/notified")" = "default|Claude czeka na zgodę|sh-dryrun / worker #11" ]
}

@test "worker: czeka na Ciebie bez pushu, takze z podkatalogu" {
  run hook czeka "$T/sh/wt/sh-dryrun/11"
  [ "$status" -eq 0 ]
  run hook czeka "$T/sh/wt/sh-dryrun/11/src"
  [ "$status" -eq 0 ]
  [ ! -e "$T/notified" ]
}

@test "orkiestrator w katalogu projektu" {
  run hook czeka "$T/sh/projekty/sh-dryrun"
  [ "$status" -eq 0 ]
  [ "$(cat "$T/notified")" = "default|Claude czeka na Ciebie|sh-dryrun / orkiestrator" ]
}

@test "orkiestrator w SH_DIR: ostatni projekt z transkryptu" {
  printf '%s\n' '{"input":{"command":"shctl status show --projekt sh-dryrun"}}' \
    '{"input":{"command":"cd /x/projekty/inny && git status"}}' >"$T/t.jsonl"
  run hook zgoda "$T/sh" "$T/t.jsonl"
  [ "$status" -eq 0 ]
  [ "$(cat "$T/notified")" = "default|Claude czeka na zgodę|inny / orkiestrator" ]
}

@test "orkiestrator w SH_DIR: nieznany projekt z transkryptu daje SH" {
  printf '%s\n' '{"input":{"command":"shctl task list --projekt nie-ma-takiego"}}' >"$T/t.jsonl"
  run hook czeka "$T/sh" "$T/t.jsonl"
  [ "$(cat "$T/notified")" = "default|Claude czeka na Ciebie|SH / orkiestrator" ]
  rm "$T/notified"
  run hook czeka "$T/sh"
  [ "$(cat "$T/notified")" = "default|Claude czeka na Ciebie|SH / orkiestrator" ]
}

@test "poza SH_DIR: nazwa katalogu" {
  mkdir -p "$T/gdzies/repo"
  run hook czeka "$T/gdzies/repo"
  [ "$(cat "$T/notified")" = "default|Claude czeka na Ciebie|repo" ]
}

@test "bez SH_NOTIFY=1 nic nie wysyla" {
  SH_NOTIFY= run hook zgoda "$T/sh/projekty/sh-dryrun"
  [ "$status" -eq 0 ]
  [ ! -e "$T/notified" ]
}

@test "blad wysylki i zly argument nie psuja sesji (kod 0)" {
  touch "$T/notify-fail"
  run hook zgoda "$T/sh/projekty/sh-dryrun"
  [ "$status" -eq 0 ]
  run hook inne "$T/sh/projekty/sh-dryrun"
  [ "$status" -eq 0 ]
}
