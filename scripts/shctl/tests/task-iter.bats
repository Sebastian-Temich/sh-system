#!/usr/bin/env bats
load helper-zadania

setup() {
  zadania_setup
  zadanie_w_toku 12
  pr_workera 12 20
  wynik_codex FAIL '[{"waga":"krytyczne","plik":"a","linia":1,"opis":"sekret w kodzie"}]'
  "$SHCTL" review run 20 >/dev/null
}

wyslane() { grep -c 'Iteracja' "$HERDR_ATRAPA/run" || true; }

# Nowy commit workera po iteracji, potem kolejny FAIL.
kolejny_fail() {
  wt="$SH_DIR/wt/demo/12"
  echo "$1" >>"$wt/src/praca-12.txt"
  git -C "$wt" commit -qam "#12: poprawka $1"
  git -C "$wt" push -q origin HEAD "HEAD:refs/pull/20/head" --force
  jq --arg s "$(git -C "$wt" rev-parse HEAD)" 'map(if .number == 20 then .headRefOid = $s else . end)' "$GH_ATRAPA/prs.json" >"$T/x" && mv "$T/x" "$GH_ATRAPA/prs.json"
  "$SHCTL" review run 20 >/dev/null
}

@test "iter: po FAIL iter:2, status in-progress, polecenie do panelu workera" {
  run --separate-stderr "$SHCTL" task iter 12 --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.iteracja <<<"$output")" = 2 ]
  [ "$(etykiety 12)" = "iter:2,runner:local,status:in-progress,wykonawca:claude" ]
  [ "$(wyslane)" -eq 1 ]
  grep 'Iteracja 2/3' "$HERDR_ATRAPA/run" | grep -q 'popraw wyłącznie zgłoszenia'
  [ "$(cut -f1 <<<"$(grep Iteracja "$HERDR_ATRAPA/run")")" = "$(jq -r '.zadania["12"].panel' "$SH_DIR/stan/demo.json")" ]
}

@test "iter: powtorka dla tego samego review nie podbija licznika" {
  "$SHCTL" task iter 12 >/dev/null
  run --separate-stderr "$SHCTL" task iter 12 --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.iteracja, .wynik.zmiana' <<<"$output" | tr '\n' ' ')" = "2 false " ]
  [[ "$(etykiety 12)" == "iter:2,"* ]] || false
  [ "$(wyslane)" -eq 1 ]
}

@test "iter: FAIL w iteracji 3 to eskalacja" {
  "$SHCTL" task iter 12 >/dev/null
  kolejny_fail a
  "$SHCTL" task iter 12 >/dev/null
  [[ "$(etykiety 12)" == "iter:3,"* ]] || false
  kolejny_fail b
  run --separate-stderr "$SHCTL" task iter 12 --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.eskalowano, .wynik.eskalacja, .wynik.iteracja' <<<"$output" | tr '\n' ' ')" = "true E-001 3 " ]
  [ -f docs/07-realizacja/escalations/E-001.md ]
  [ "$(fm docs/07-realizacja/escalations/E-001.md dotyczy)" = "#12" ]
  [[ "$(etykiety 12)" == *"status:escalated"* ]] || false
  [[ "$(etykiety 12)" == "iter:3,"* ]] || false
  grep -q '^high Eskalacja E-001' "$T/notified"
  [ "$(wyslane)" -eq 2 ]
}

@test "iter: bez FAIL dla biezacego commita to odmowa" {
  kolejny_fail c
  wynik_codex PASS '[]'
  wt="$SH_DIR/wt/demo/12"
  echo d >>"$wt/src/praca-12.txt"
  git -C "$wt" commit -qam "#12: d"
  jq --arg s "$(git -C "$wt" rev-parse HEAD)" 'map(if .number == 20 then .headRefOid = $s else . end)' "$GH_ATRAPA/prs.json" >"$T/x" && mv "$T/x" "$GH_ATRAPA/prs.json"
  run --separate-stderr "$SHCTL" task iter 12
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"brak wyniku"* ]] || false
}

@test "iter: po PASS to odmowa" {
  jq 'map(.comments = [])' "$GH_ATRAPA/prs.json" >"$T/x" && mv "$T/x" "$GH_ATRAPA/prs.json"
  wynik_codex PASS '[]'
  "$SHCTL" review run 20 >/dev/null
  run --separate-stderr "$SHCTL" task iter 12
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"PASS"* ]] || false
}

@test "iter: brak panelu workera uruchamia claude z poleceniem iteracji" {
  jq 'map(select(.label != "worker:demo:12"))' "$HERDR_ATRAPA/panele.json" >"$T/x" && mv "$T/x" "$HERDR_ATRAPA/panele.json"
  run --separate-stderr "$SHCTL" task iter 12
  [ "$status" -eq 0 ]
  [ "$(etykiety_paneli)" = "worker:demo:12" ]
  tail -1 "$CLAUDE_ATRAPA/calls" | grep -q 'Iteracja 2/3 zadania #12'
}

@test "iter --dry-run nic nie zmienia" {
  run --separate-stderr "$SHCTL" task iter 12 --dry-run --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.iteracja <<<"$output")" = 2 ]
  [[ "$(etykiety 12)" == "iter:1,"* ]] || false
  [ "$(wyslane)" -eq 0 ]
}
