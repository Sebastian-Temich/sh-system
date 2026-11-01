#!/usr/bin/env bats
load helper

setup() { wspolny_setup; projekt_demo; }

@test "specyfikacja z frontmatterem" {
  run "$SHCTL" doc new 00-intake specyfikacja
  [ "$status" -eq 0 ]
  f=docs/00-intake/specyfikacja.md
  [ "$(fm $f projekt)" = demo ]
  [ "$(fm $f etap)" = 00-intake ]
  [ "$(fm $f data)" = "$(date +%F)" ]
  [ "$(fm $f rola)" = intake ]
  grep -qx '# Specyfikacja: demo' $f
}

@test "ADR dostaje kolejne numery, a powtorka zwraca ten sam plik" {
  run "$SHCTL" doc new 04-architektura adr --tytul "Wybór bazy żółć" --json
  [ "$(jq -r .wynik.adr <<<"$output")" = ADR-001 ]
  [ -f docs/04-architektura/adr/ADR-001-wybor-bazy-zolc.md ]
  grep -qx '# ADR-001: Wybór bazy żółć' docs/04-architektura/adr/ADR-001-wybor-bazy-zolc.md
  grep -q 'zastąpiona przez ADR-NNN' docs/04-architektura/adr/ADR-001-wybor-bazy-zolc.md
  run "$SHCTL" doc new 04-architektura adr --tytul "Auth" --json
  [ "$(jq -r .wynik.adr <<<"$output")" = ADR-002 ]
  run "$SHCTL" doc new 04-architektura adr --tytul "Wybór bazy żółć" --json
  [ "$(jq -r '.wynik.adr, .wynik.utworzono' <<<"$output" | tr '\n' ' ')" = "ADR-001 false " ]
}

@test "numer ADR 008 i 009 nie jest czytany osemkowo" {
  touch docs/04-architektura/adr/ADR-009-x.md
  run "$SHCTL" doc new 04-architektura adr --tytul "Kolejny" --json
  [ "$(jq -r .wynik.adr <<<"$output")" = ADR-010 ]
}

@test "ADR bez tytulu: kod 2" {
  run --separate-stderr "$SHCTL" doc new 04-architektura adr
  [ "$status" -eq 2 ]
}

@test "istniejacy dokument nie jest nadpisywany" {
  "$SHCTL" doc new 00-intake specyfikacja
  echo zmiana >>docs/00-intake/specyfikacja.md
  run "$SHCTL" doc new 00-intake specyfikacja
  [ "$status" -eq 0 ]
  grep -qx zmiana docs/00-intake/specyfikacja.md
}

@test "typ w zlym etapie: kod 2" {
  run --separate-stderr "$SHCTL" doc new 05-plan adr --tytul x
  [ "$status" -eq 2 ]
}

@test "brak szablonu: kod 3" {
  run --separate-stderr "$SHCTL" doc new 05-plan nieznany
  [ "$status" -eq 3 ]
}

@test "raport zadania wymaga numeru" {
  run --separate-stderr "$SHCTL" doc new 07-realizacja raport-zadania
  [ "$status" -eq 2 ]
  run "$SHCTL" doc new 07-realizacja raport-zadania --nr 12 --tytul Logowanie
  [ "$status" -eq 0 ]
  grep -qx '# Raport T-12: Logowanie' docs/07-realizacja/T-12.md
  grep -qx 'Issue: #12' docs/07-realizacja/T-12.md
}

@test "raport QA i dokumentacja techniczna trafiaja do swoich folderow" {
  "$SHCTL" doc new 08-qa raport-qa --tytul "Kamień 1"
  [ -f docs/08-qa/raport-qa-kamien-1.md ]
  grep -qx '# Raport QA: Kamień 1' docs/08-qa/raport-qa-kamien-1.md
  "$SHCTL" doc new wydanie wydanie-techniczna
  [ "$(fm docs/wydanie/techniczna/techniczna.md rola)" = orkiestrator ]
}

@test "--rola nadpisuje domyslna, --dry-run nie tworzy pliku" {
  run "$SHCTL" doc new 00-intake specyfikacja --rola architekt --dry-run --json
  [ "$(jq -r .wynik.rola <<<"$output")" = architekt ]
  [ ! -e docs/00-intake/specyfikacja.md ]
}

@test "eskalacji i decyzji nie tworzy doc new" {
  run --separate-stderr "$SHCTL" doc new 07-realizacja eskalacja
  [ "$status" -eq 2 ]
}
