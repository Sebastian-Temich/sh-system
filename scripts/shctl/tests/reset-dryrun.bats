#!/usr/bin/env bats
load helper-zadania

setup() {
  zadania_setup
  export SHCTL_DRYRUN_NAZWA=demo
  printf -- '- {id: D1, tytul: Pierwsze, cel: c, kryteria: [k]}\n- {id: D2, tytul: Drugie, cel: c, kryteria: [k], zaleznosci: [D1]}\n' >zadania.yaml
  git add zadania.yaml && git commit -qm baseline && git tag baseline && git push -q origin main baseline
  "$SHCTL" task create --plik zadania.yaml >/dev/null
  git checkout -q -- . && git clean -fdq
  BASE="$(git rev-parse baseline)"
}

otwarte() { jq -r '[.[] | select(.state == "OPEN") | .number] | join(",")' "$GH_ATRAPA/issues.json"; }

@test "reset-dryrun: w stanie baseline nic nie robi" {
  run --separate-stderr "$SHCTL" reset-dryrun --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.zmiana <<<"$output")" = false ]
}

@test "reset-dryrun: zamyka PR, archiwizuje issue, main do baseline, odtwarza issue" {
  "$SHCTL" task dispatch 1 >/dev/null
  pr_workera 1 9
  echo zmiana >src/main.txt && git add -A && git commit -qm "po baseline" && git push -q origin main
  run --separate-stderr "$SHCTL" reset-dryrun --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.zamkniete_pr | join(",")' <<<"$output")" = 9 ]
  [ "$(jq -r '.[] | select(.number == 9) | .state' "$GH_ATRAPA/prs.json")" = CLOSED ]
  [ "$(jq -r '.[] | select(.number == 1) | .stateReason' "$GH_ATRAPA/issues.json")" = NOT_PLANNED ]
  jq -r '.[] | select(.number == 1) | .body' "$GH_ATRAPA/issues.json" | grep -q 'shctl:archiwum-id=D1'
  [ "$(git rev-parse main)" = "$BASE" ]
  [ "$(git -C "$T/remote.git" rev-parse main)" = "$BASE" ]
  [ ! -e "$SH_DIR/projekty/wt/1" ]
  [ -z "$(git branch --list 'task/*')" ]
  [ "$(etykiety_paneli)" = "" ]
  [ "$(otwarte)" = "10,11" ]
  [ "$(jq -r '.wynik.mapa.D1, .wynik.mapa.D2' <<<"$output" | tr '\n' ' ')" = "10 11 " ]
  [ "$(jq -r '.zadania | length' "$SH_DIR/stan/demo.json")" -eq 0 ]
  git checkout -q -- . && git clean -fdq
  run --separate-stderr "$SHCTL" reset-dryrun --json
  [ "$(jq -r .wynik.zmiana <<<"$output")" = false ]
}

@test "reset-dryrun: tylko projekt wzorcowy" {
  run --separate-stderr "$SHCTL" reset-dryrun --projekt inny
  [ "$status" -eq 4 ]
  unset SHCTL_DRYRUN_NAZWA
  run --separate-stderr "$SHCTL" reset-dryrun --projekt demo
  [ "$status" -eq 4 ]
}

@test "reset-dryrun: brak tagu baseline to kod 3" {
  git tag -d baseline >/dev/null
  git push -q origin :refs/tags/baseline
  echo x >>src/app.txt && git commit -qam x
  run --separate-stderr "$SHCTL" reset-dryrun
  [ "$status" -eq 3 ]
}

@test "reset-dryrun --dry-run niczego nie zmienia" {
  "$SHCTL" task dispatch 1 >/dev/null
  run --separate-stderr "$SHCTL" reset-dryrun --dry-run --json
  [ "$status" -eq 0 ]
  [ -d "$SH_DIR/projekty/wt/1" ]
  [ "$(otwarte)" = "1,2" ]
  ! grep -qE '^(pr close|issue close)' "$GH_ATRAPA/calls" || false
}
