#!/usr/bin/env bats
load helper

setup() { wspolny_setup; projekt_demo; }

@test "liczy zadania z GitHuba" {
  cat >"$T/issues.json" <<'JSON'
[{"state":"OPEN","stateReason":"","labels":[{"name":"status:review"}]},
 {"state":"OPEN","stateReason":"","labels":[]},
 {"state":"CLOSED","stateReason":"COMPLETED","labels":[]},
 {"state":"CLOSED","stateReason":"NOT_PLANNED","labels":[]}]
JSON
  run "$SHCTL" status show --json
  [ "$status" -eq 0 ]
  [ "$(jq -c '.wynik.zadania | [.todo,.review,.done,.anulowane]' <<<"$output")" = '[1,1,1,1]' ]
  [ "$(jq -r .wynik.zrodlo_zadan <<<"$output")" = github ]
}

@test "bez GitHuba bierze liczniki z Projekt.md" {
  run "$SHCTL" status show --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.zrodlo_zadan, .wynik.zadania.done' <<<"$output" | tr '\n' ' ')" = "Projekt.md 3 " ]
}

@test "pokazuje etap, eskalacje i wstrzymania" {
  "$SHCTL" stage start 04-plan
  "$SHCTL" escalate --dotyczy 04-plan --powod "spór" --potrzebne x
  printf '# Limity\n\n| Wykonawca | Do kiedy |\n|---|---|\n| claude | 18:00 |\n\n- codex do 20:00\n' >"$SH_DIR/limity.md"
  run "$SHCTL" status show
  [ "$status" -eq 0 ]
  [[ "$output" == *'`04-plan`: escalated'* ]] || false
  [[ "$output" == *"E-001 (04-plan): spór"* ]] || false
  [[ "$output" == *"| claude | 18:00 |"* ]] || false
  [[ "$output" == *"- codex do 20:00"* ]] || false
  [[ "$output" != *"Wykonawca"* ]] || false
}

@test "brak limity.md to brak wstrzyman" {
  run "$SHCTL" status show
  [[ "$output" == *"Wstrzymania: brak"* ]] || false
}

@test "samo status dziala jak show" {
  run "$SHCTL" status
  [ "$status" -eq 0 ]
}

@test "status show zaczyna od Gdzie jestesmy i Czeka na Ciebie z Projekt.md" {
  run "$SHCTL" status show
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | head -1)" = "Gdzie jesteśmy" ]
  [[ "$output" == *"- **Etap:** Realizacja"*"Czeka na Ciebie"*"1. E-001 (#2): klucz"* ]] || false
  run "$SHCTL" status show --json
  [ "$(jq -r '.wynik.czeka[0].wpisz' <<<"$output")" = "E-001: A" ]
  [[ "$(jq -r .wynik.gdzie <<<"$output")" == *"Realizacja"* ]] || false
}
