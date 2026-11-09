#!/usr/bin/env bats
# shctl pr check: konflikt z main przed czekaniem na CI, licznik nieudanych napraw CI zadania.
load helper-zadania

setup() {
  zadania_setup
  zadanie_w_toku 12
  pr_workera 12 20
}

ustaw_pr() { jq --argjson n "$1" "map(if .number == \$n then $2 else . end)" "$GH_ATRAPA/prs.json" >"$T/x" && mv "$T/x" "$GH_ATRAPA/prs.json"; }

@test "pr check: konflikt zgloszony wprost, bez czekania na CI" {
  ustaw_pr 20 '.mergeable = "CONFLICTING" | .statusCheckRollup = []'
  run --separate-stderr "$SHCTL" pr check 20 --czekaj --timeout 600 --json
  echo "$output $stderr"
  [ "$status" -eq 4 ]
  [[ "$(jq -r .blad <<<"$output")" == *"konflikt z main"*"CI nie wystartuje"* ]] || false
  [ "$(grep -c '^pr view 20' "$GH_ATRAPA/calls")" -le 3 ]
}

@test "pr check: zielone CI wskazuje review" {
  run --separate-stderr "$SHCTL" pr check 20 --czekaj --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.mergeable, .wynik.ci, .wynik.nr' <<<"$output" | tr '\n' ' ')" = "MERGEABLE pass 12 " ]
  [ "$(jq -r .wynik.nastepny_krok <<<"$output")" = "shctl review run 20" ]
}

@test "pr check: po 2 nieudanych naprawach CI limit, review albo eskalacja" {
  for h in a1 b2 c3; do
    ustaw_pr 20 ".headRefOid = \"$h\" | .statusCheckRollup = [{status:\"COMPLETED\", conclusion:\"FAILURE\"}]"
    run --separate-stderr "$SHCTL" pr check 20 --json
    [ "$status" -eq 0 ]
  done
  [ "$(jq -r '.wynik.ci, .wynik.czerwone_commity, .wynik.nieudane_naprawy_ci, .wynik.limit_napraw_ci' <<<"$output" | tr '\n' ' ')" = "fail 3 2 true " ]
  [[ "$(jq -r .wynik.nastepny_krok <<<"$output")" == "limit napraw CI"* ]] || false
  # Ten sam czerwony commit nie liczy się drugi raz.
  run --separate-stderr "$SHCTL" pr check 20 --json
  [ "$(jq -r .wynik.czerwone_commity <<<"$output")" = 3 ]
}

@test "pr check: jedna naprawa to jeszcze praca workera" {
  ustaw_pr 20 '.statusCheckRollup = [{status:"COMPLETED", conclusion:"FAILURE"}]'
  run --separate-stderr "$SHCTL" pr check 20 --json
  [ "$(jq -r '.wynik.limit_napraw_ci, .wynik.nieudane_naprawy_ci' <<<"$output" | tr '\n' ' ')" = "false 0 " ]
}

@test "pr check --czekaj: CI w toku do limitu czasu" {
  ustaw_pr 20 '.statusCheckRollup = [{status:"IN_PROGRESS", conclusion:null}]'
  run --separate-stderr "$SHCTL" pr check 20 --czekaj --timeout 0 --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.ci <<<"$output")" = pending ]
}

@test "task close: konflikt zamiast ogolnego bledu CI" {
  ustaw_pr 20 '.mergeable = "CONFLICTING" | .statusCheckRollup = []'
  run --separate-stderr "$SHCTL" task close 12
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"konflikt z main"* ]] || false
}

@test "pr check: commit zmieniajacy tylko raport nie jest proba naprawy CI" {
  wt="$SH_DIR/wt/demo/12"
  ustaw_pr 20 '.statusCheckRollup = [{status:"COMPLETED", conclusion:"FAILURE"}]'
  run --separate-stderr "$SHCTL" pr check 20 --json
  # Druga czerwona wersja: tylko raport.
  echo "dopisek" >>"$wt/docs/07-realizacja/T-12.md"
  git -C "$wt" commit -qam "raport"
  git -C "$wt" push -q origin HEAD
  h="$(git -C "$wt" rev-parse HEAD)"
  ustaw_pr 20 ".headRefOid = \"$h\""
  run --separate-stderr "$SHCTL" pr check 20 --json
  echo "$output $stderr"
  [ "$(jq -r '.wynik.czerwone_commity, .wynik.nieudane_naprawy_ci' <<<"$output" | tr '\n' ' ')" = "2 0 " ]
  # Trzecia: zmiana kodu, to pierwsza nieudana naprawa.
  echo "kod" >>"$wt/src/praca-12.txt"
  git -C "$wt" commit -qam "naprawa"
  git -C "$wt" push -q origin HEAD
  h="$(git -C "$wt" rev-parse HEAD)"
  ustaw_pr 20 ".headRefOid = \"$h\""
  run --separate-stderr "$SHCTL" pr check 20 --json
  [ "$(jq -r '.wynik.czerwone_commity, .wynik.nieudane_naprawy_ci, .wynik.limit_napraw_ci' <<<"$output" | tr '\n' ' ')" = "3 1 false " ]
}
