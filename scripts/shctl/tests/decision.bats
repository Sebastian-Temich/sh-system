#!/usr/bin/env bats
load helper

setup() { wspolny_setup; projekt_demo; }

dodaj() { "$SHCTL" decision add --co "Postgres" --dlaczego "RLS" --cofniecie "migracja" "$@"; }

@test "dopisuje wiersz tabeli" {
  run dodaj
  [ "$status" -eq 0 ]
  grep -qxF "| $(date +%F) | orkiestrator | Postgres | RLS. Cofnięcie: migracja |" docs/decyzje.md
}

@test "powtorka nie dubluje" {
  dodaj
  run dodaj --json
  [ "$(jq -r .wynik.dodano <<<"$output")" = false ]
  [ "$(grep -c Postgres docs/decyzje.md)" -eq 1 ]
}

@test "powtorka z innego dnia tez nie dubluje" {
  printf '| 2020-01-01 | orkiestrator | Postgres | RLS. Cofnięcie: migracja |\n' >>docs/decyzje.md
  dodaj
  [ "$(grep -c Postgres docs/decyzje.md)" -eq 1 ]
}

@test "kreska i nowa linia nie psuja tabeli" {
  run "$SHCTL" decision add --co "a|b" --dlaczego $'x\ny' --cofniecie z --rola T-3
  [ "$status" -eq 0 ]
  grep -qF '| T-3 | a\|b | x y. Cofnięcie: z |' docs/decyzje.md
}

@test "brak argumentu: kod 2" {
  run --separate-stderr "$SHCTL" decision add --co x
  [ "$status" -eq 2 ]
}

@test "--dry-run nie pisze" {
  run dodaj --dry-run
  [ -z "$(git status --porcelain)" ]
}
