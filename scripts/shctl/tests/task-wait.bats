#!/usr/bin/env bats
# shctl task wait: limit czasu i stan panelu zamiast gołego herdr agent wait; po poleceniu czeka na
# nową turę (working -> idle albo nowy commit w PR po czasie polecenia).
load helper-zadania

setup() {
  zadania_setup
  export SHCTL_WAIT_PAUZA=0 SHCTL_WAIT_KROK=1
  zadanie_w_toku 12
}

stan_agenta() { jq --arg s "$1" 'map(if .label == "worker:demo:12" then .agent_status = $s else . end)' "$HERDR_ATRAPA/panele.json" >"$T/x" && mv "$T/x" "$HERDR_ATRAPA/panele.json"; }
stan_json() { jq -r --arg k "$1" '.zadania["12"][$k]' "$SH_DIR/stan/demo.json"; }

@test "wait: dispatch zapisuje czas polecenia i ture do podjecia" {
  [[ "$(stan_json polecenie)" == 20*Z ]] || false
  [ "$(stan_json tura)" = false ]
}

@test "wait: panel idle przed podjeciem polecenia nie konczy czekania (bez_tury)" {
  stan_agenta idle
  run --separate-stderr "$SHCTL" task wait 12 --timeout 2 --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.stan, .wynik.limit_czasu' <<<"$output" | tr '\n' ' ')" = "bez_tury true " ]
  ! grep -q '^agent wait' "$HERDR_ATRAPA/calls" || false
}

@test "wait: working, potem idle to koniec tury" {
  stan_agenta working
  echo idle >"$HERDR_ATRAPA/po-wait"
  run --separate-stderr "$SHCTL" task wait 12 --timeout 30 --json
  [ "$(jq -r .wynik.stan <<<"$output")" = idle ]
  [ "$(stan_json tura)" = true ]
}

@test "wait: tura zapamietana w stanie, kolejne wywolanie na idle wraca od razu" {
  stan_agenta working
  run --separate-stderr "$SHCTL" task wait 12 --timeout 1 --json
  [ "$(jq -r .wynik.stan <<<"$output")" = pracuje ]
  stan_agenta idle
  run --separate-stderr "$SHCTL" task wait 12 --timeout 600 --json
  [ "$(jq -r '.wynik.stan, .wynik.limit_czasu' <<<"$output" | tr '\n' ' ')" = "idle false " ]
}

@test "wait: PR z raportem i commitem po poleceniu to gotowe" {
  stan_agenta working
  pr_workera 12 20
  run --separate-stderr "$SHCTL" task wait 12 --json
  [ "$(jq -r '.wynik.stan, .wynik.pr, .wynik.raport, .wynik.nowy_commit' <<<"$output" | tr '\n' ' ')" = "gotowe 20 true true " ]
  [ "$(jq -r .wynik.nastepny_krok <<<"$output")" = "shctl pr check 20 --czekaj" ]
}

@test "wait: raport z poprzedniej iteracji (commit sprzed polecenia) nie jest gotowe" {
  PR_COMMIT_DATA=2026-01-01T00:00:00Z pr_workera 12 20
  stan_agenta idle
  run --separate-stderr "$SHCTL" task wait 12 --timeout 2 --json
  [ "$(jq -r '.wynik.stan, .wynik.raport, .wynik.nowy_commit' <<<"$output" | tr '\n' ' ')" = "bez_tury true false " ]
}

@test "wait: nowy commit po poleceniu bez raportu i agent idle to idle" {
  pr_workera 12 20
  jq 'map(.files = [{path:"src/praca-12.txt"}])' "$GH_ATRAPA/prs.json" >"$T/x" && mv "$T/x" "$GH_ATRAPA/prs.json"
  stan_agenta idle
  run --separate-stderr "$SHCTL" task wait 12 --timeout 600 --json
  [ "$(jq -r '.wynik.stan, .wynik.nowy_commit' <<<"$output" | tr '\n' ' ')" = "idle true " ]
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

@test "wait: iter zapisuje nowy czas polecenia i zeruje ture" {
  jq '.zadania["12"].tura = true | .zadania["12"].polecenie = "2026-01-01T00:00:00Z"' "$SH_DIR/stan/demo.json" >"$T/x" && mv "$T/x" "$SH_DIR/stan/demo.json"
  pr_workera 12 20
  wynik_codex FAIL '[{"waga":"istotne","plik":"src/a.ts","linia":1,"opis":"blad"}]'
  "$SHCTL" review run 20 >/dev/null
  run --separate-stderr "$SHCTL" task iter 12 --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(stan_json tura)" = false ]
  [ "$(stan_json polecenie)" != 2026-01-01T00:00:00Z ]
}
