#!/usr/bin/env bats
# shctl task polecenie NR "tekst": orkiestrator wysyła polecenie workerowi przez shctl, nie przez
# herdr agent prompt (ten nie zna etykiet worker:PROJEKT:NR, sh-dryrun przebieg 6). Komenda sama
# znajduje panel, a task wait po poleceniu czeka na nową turę.
load helper-zadania

setup() {
  zadania_setup
  export SHCTL_WAIT_PAUZA=0 SHCTL_WAIT_KROK=1
  zadanie_w_toku 12
}

stan_json() { jq -r --arg k "$1" '.zadania["12"][$k]' "$SH_DIR/stan/demo.json"; }
panel_12() { jq -r '[.[] | select(.label == "worker:demo:12")][0].pane_id' "$HERDR_ATRAPA/panele.json"; }

@test "polecenie: panel znaleziony po etykiecie, tekst trafia do panelu, stan z nowym czasem polecenia" {
  jq '.zadania["12"].tura = true | .zadania["12"].polecenie = "2026-01-01T00:00:00Z"' "$SH_DIR/stan/demo.json" >"$T/s" &&
    mv "$T/s" "$SH_DIR/stan/demo.json"
  run --separate-stderr "$SHCTL" task polecenie 12 "zaktualizuj gałąź: gh pr update-branch, potem git pull" --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.panel <<<"$output")" = "$(panel_12)" ]
  [ "$(jq -r .wynik.nastepny_krok <<<"$output")" = "shctl task wait 12" ]
  grep -F "$(panel_12)" "$HERDR_ATRAPA/run" | grep -q 'Polecenie orkiestratora do zadania #12: zaktualizuj gałąź'
  [ "$(stan_json tura)" = false ]
  [[ "$(stan_json polecenie)" > 2026-01-01T00:00:00Z ]] || false
  ! grep -q '^agent prompt' "$HERDR_ATRAPA/calls" || false
}

@test "polecenie: task wait potem czeka na nowa ture, nie wraca od razu na idle" {
  jq 'map(if .label == "worker:demo:12" then .agent_status = "idle" else . end)' "$HERDR_ATRAPA/panele.json" >"$T/x" &&
    mv "$T/x" "$HERDR_ATRAPA/panele.json"
  "$SHCTL" task polecenie 12 "napraw CI" >/dev/null
  run --separate-stderr "$SHCTL" task wait 12 --timeout 2 --json
  [ "$(jq -r .wynik.stan <<<"$output")" = bez_tury ]
}

@test "polecenie: panel po eskalacji (etykieta eskalacja:) tez znaleziony" {
  jq 'map(if .label == "worker:demo:12" then .label = "eskalacja:demo:12" else . end)' "$HERDR_ATRAPA/panele.json" >"$T/x" &&
    mv "$T/x" "$HERDR_ATRAPA/panele.json"
  run --separate-stderr "$SHCTL" task polecenie 12 "dokończ raport" --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.panel <<<"$output")" = "$(jq -r '.[] | select(.label == "eskalacja:demo:12") | .pane_id' "$HERDR_ATRAPA/panele.json")" ]
}

@test "polecenie: bledy uzycia (brak tresci, pusta tresc, nadmiarowy argument)" {
  run --separate-stderr "$SHCTL" task polecenie 12
  [ "$status" -eq 2 ]
  run --separate-stderr "$SHCTL" task polecenie 12 "   "
  [ "$status" -eq 2 ]
  run --separate-stderr "$SHCTL" task polecenie 12 "a" "b"
  [ "$status" -eq 2 ]
}
