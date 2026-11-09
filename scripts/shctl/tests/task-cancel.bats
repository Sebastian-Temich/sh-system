#!/usr/bin/env bats
# shctl task close --anuluj (dawniej task cancel): issue „not planned”, PR, worktree, gałąź, panele i stan zadania.
load helper-zadania

setup() {
  zadania_setup
  zadanie_w_toku 12
  pr_workera 12 20
}

@test "cancel: zamyka issue i PR, usuwa worktree, galaz, panel i wpis stanu" {
  echo niezacommitowane >"$SH_DIR/wt/demo/12/src/x.txt"
  run --separate-stderr "$SHCTL" task close 12 --anuluj --powod "zakres przeniesiony do #14" --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.pr, .wynik.pr_zamkniety, .wynik.zmiana' <<<"$output" | tr '\n' ' ')" = "20 true true " ]
  [ "$(jq -r '.[] | select(.number == 12) | .stateReason' "$GH_ATRAPA/issues.json")" = NOT_PLANNED ]
  [ "$(jq -r '.[] | select(.number == 20) | .state' "$GH_ATRAPA/prs.json")" = CLOSED ]
  grep -q '^pr close 20 .*--delete-branch' "$GH_ATRAPA/calls"
  grep -q 'zakres przeniesiony do #14' "$GH_ATRAPA/calls"
  [ ! -e "$SH_DIR/wt/demo/12" ]
  [ -z "$(git branch --list 'task/12*')" ]
  [ "$(etykiety_paneli)" = "" ]
  [ "$(jq -r '.zadania["12"] // "brak"' "$SH_DIR/stan/demo.json")" = brak ]
  [[ "$(etykiety 12)" != *"status:"* ]] || false
  run --separate-stderr "$SHCTL" task close 12 --anuluj --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.zmiana <<<"$output")" = false ]
}

@test "cancel: zwalnia slot, kolejne zadanie startuje" {
  issue 13 "Kolejne" "status:todo,runner:local,wykonawca:claude"
  run --separate-stderr "$SHCTL" task dispatch 13
  [ "$status" -eq 4 ]
  "$SHCTL" task close 12 --anuluj >/dev/null
  run --separate-stderr "$SHCTL" task dispatch 13
  [ "$status" -eq 0 ]
}

@test "cancel: scalony PR to odmowa" {
  jq 'map(if .number == 20 then .state = "MERGED" else . end)' "$GH_ATRAPA/prs.json" >"$T/x" && mv "$T/x" "$GH_ATRAPA/prs.json"
  run --separate-stderr "$SHCTL" task close 12 --anuluj
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"scalony PR #20"* ]] || false
  [ -d "$SH_DIR/wt/demo/12" ]
}

@test "cancel --dry-run niczego nie zmienia" {
  run --separate-stderr "$SHCTL" task close 12 --anuluj --dry-run --json
  [ "$status" -eq 0 ]
  [ -d "$SH_DIR/wt/demo/12" ]
  [ "$(stan_issue 12)" = OPEN ]
  ! grep -qE '^(pr close|issue close)' "$GH_ATRAPA/calls" || false
}

@test "cancel: stara nazwa task cancel dziala jako alias z ostrzezeniem" {
  run --separate-stderr "$SHCTL" task cancel 12 --powod "stary alias" --json
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"task cancel jest przestarzałe"*"task close NR --anuluj"* ]] || false
  [ "$(jq -r '.[] | select(.number == 12) | .stateReason' "$GH_ATRAPA/issues.json")" = NOT_PLANNED ]
}

@test "cancel: --anuluj poza task close to blad uzycia" {
  run --separate-stderr "$SHCTL" task dispatch 12 --anuluj
  [ "$status" -eq 2 ]
}
