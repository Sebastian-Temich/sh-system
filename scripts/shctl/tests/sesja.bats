#!/usr/bin/env bats
# shctl sesja: jedna sesja orkiestratora prowadzi projekt; wpis .sesja w stanie projektu.
load helper-zadania

setup() {
  zadania_setup
  sleep 300 &
  ZYWY=$!
}

teardown() { kill "$ZYWY" 2>/dev/null || true; wait "$ZYWY" 2>/dev/null || true; }

jako() { CLAUDE_CODE_SESSION_ID="$1" CLAUDE_PID="$2" "$SHCTL" "${@:3}"; }
wpis() { jq -r ".sesja.$1 // \"\"" "$SH_DIR/stan/demo.json"; }

@test "sesja start: zapis sesji w stanie projektu, powtorka tej samej sesji ok" {
  run --separate-stderr jako aaaa1111 "$ZYWY" sesja start --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(wpis id)" = aaaa1111 ]
  [ "$(wpis pid)" = "$ZYWY" ]
  run --separate-stderr jako aaaa1111 "$ZYWY" sesja start --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.stan <<<"$output")" = moja ]
}

@test "sesja start: druga aktywna sesja to odmowa, --przejmij przejmuje" {
  jako aaaa1111 "$ZYWY" sesja start >/dev/null
  run --separate-stderr jako bbbb2222 99999 sesja start
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"prowadzi inna aktywna sesja aaaa1111"* ]] || false
  [ "$(wpis id)" = aaaa1111 ]
  run --separate-stderr jako bbbb2222 99999 sesja start --przejmij --json
  [ "$status" -eq 0 ]
  [ "$(wpis id)" = bbbb2222 ]
  [ "$(wpis przejeta_od)" = aaaa1111 ]
}

@test "sesja: wpis starszy niz 30 min albo martwy proces nie blokuje" {
  jako aaaa1111 "$ZYWY" sesja start >/dev/null
  jq '.sesja.ostatnio = "2026-01-01T00:00:00Z"' "$SH_DIR/stan/demo.json" >"$T/x" && mv "$T/x" "$SH_DIR/stan/demo.json"
  run --separate-stderr jako bbbb2222 99999 sesja start
  [ "$status" -eq 0 ]
  jako cccc3333 999998 sesja start --przejmij >/dev/null
  run --separate-stderr jako dddd4444 99999 sesja start
  [ "$status" -eq 0 ]
}

@test "sesja: ten sam proces po /clear (nowe id) to ta sama sesja" {
  jako aaaa1111 "$ZYWY" sesja start >/dev/null
  run --separate-stderr jako eeee5555 "$ZYWY" sesja start --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.stan <<<"$output")" = moja ]
}

@test "komendy orkiestratora odswiezaja wpis i ostrzegaja przy innej aktywnej sesji" {
  run --separate-stderr jako aaaa1111 "$ZYWY" task ready
  [ "$status" -eq 0 ]
  [ "$(wpis id)" = aaaa1111 ]
  run --separate-stderr jako bbbb2222 99999 task ready
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"UWAGA: projekt demo prowadzi inna aktywna sesja aaaa1111"* ]] || false
  [ "$(wpis id)" = aaaa1111 ]
}

@test "sesja koniec zwalnia projekt; poza sesja Claude komendy nie zapisuja wpisu" {
  "$SHCTL" task ready >/dev/null
  [ "$(jq -r '.sesja // "brak"' "$SH_DIR/stan/demo.json" 2>/dev/null || echo brak)" = brak ]
  jako aaaa1111 "$ZYWY" sesja start >/dev/null
  jako aaaa1111 "$ZYWY" sesja koniec >/dev/null
  [ "$(jq -r '.sesja // "brak"' "$SH_DIR/stan/demo.json")" = brak ]
  run --separate-stderr "$SHCTL" sesja start
  [ "$status" -eq 2 ]
}
