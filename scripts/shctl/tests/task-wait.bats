#!/usr/bin/env bats
# shctl task wait: limit czasu i stan panelu zamiast gołego herdr agent wait.
load helper-zadania

setup() {
  zadania_setup
  export SHCTL_WAIT_PAUZA=0 SHCTL_WAIT_KROK=1
  zadanie_w_toku 12
}

stan_agenta() { jq --arg s "$1" 'map(if .label == "worker:demo:12" then .agent_status = $s else . end)' "$HERDR_ATRAPA/panele.json" >"$T/x" && mv "$T/x" "$HERDR_ATRAPA/panele.json"; }

@test "wait: panel idle bez PR wraca od razu ze stanem idle, bez agent wait" {
  stan_agenta idle
  run --separate-stderr "$SHCTL" task wait 12 --timeout 600 --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.stan, .wynik.limit_czasu' <<<"$output" | tr '\n' ' ')" = "idle false " ]
  ! grep -q '^agent wait' "$HERDR_ATRAPA/calls" || false
}

@test "wait: PR z raportem to gotowe niezaleznie od stanu panelu" {
  stan_agenta working
  pr_workera 12 20
  run --separate-stderr "$SHCTL" task wait 12 --json
  [ "$(jq -r '.wynik.stan, .wynik.pr, .wynik.raport' <<<"$output" | tr '\n' ' ')" = "gotowe 20 true " ]
  [ "$(jq -r .wynik.nastepny_krok <<<"$output")" = "shctl pr check 20 --czekaj" ]
}

@test "wait: pracujacy agent do limitu czasu" {
  stan_agenta working
  run --separate-stderr "$SHCTL" task wait 12 --timeout 2 --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.stan, .wynik.limit_czasu' <<<"$output" | tr '\n' ' ')" = "pracuje true " ]
  grep -q '^agent wait w1:p11 --timeout 1000' "$HERDR_ATRAPA/calls"
}

@test "wait: agent konczy prace w trakcie czekania" {
  stan_agenta working
  echo blocked >"$HERDR_ATRAPA/po-wait"
  run --separate-stderr "$SHCTL" task wait 12 --timeout 30 --json
  [ "$(jq -r .wynik.stan <<<"$output")" = blocked ]
}

@test "wait: panel bez agenta i brak panelu" {
  jq 'map(if .label == "worker:demo:12" then .agent = "" else . end)' "$HERDR_ATRAPA/panele.json" >"$T/x" && mv "$T/x" "$HERDR_ATRAPA/panele.json"
  run --separate-stderr "$SHCTL" task wait 12 --json
  [ "$(jq -r .wynik.stan <<<"$output")" = brak_agenta ]
  echo '[]' >"$HERDR_ATRAPA/panele.json"
  run --separate-stderr "$SHCTL" task wait 12 --json
  [ "$(jq -r .wynik.stan <<<"$output")" = brak_panelu ]
}
