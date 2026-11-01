#!/usr/bin/env bats
load helper

setup() { wspolny_setup; projekt_demo; printf 'status:in-progress' >"$T/issue-etykieta"; }

E1=docs/07-realizacja/escalations/E-001.md
esk() { "$SHCTL" escalate --dotyczy "#7" --powod "brak klucza" --potrzebne "klucz API" "$@"; }

@test "issue: plik, etykieta, status.md, powiadomienie" {
  run esk --opcje "A;B"
  [ "$status" -eq 0 ]
  [ -f "$E1" ]
  [ "$(fm "$E1" status)" = otwarta ]
  grep -qx '# Eskalacja E-001: brak klucza' "$E1"
  grep -qx 'Zadanie: #7' "$E1"
  grep -qx -- '- A' "$E1"
  grep -qx 'klucz API' "$E1"
  grep -q 'issue edit 7 --repo test-owner/demo --add-label status:escalated --remove-label status:in-progress' "$T/gh.calls"
  grep -q 'E-001 (#7): brak klucza' docs/status.md
  grep -q '^high Eskalacja E-001: demo' "$T/notified"
}

@test "powtorka nie tworzy drugiej i nie powiadamia ponownie" {
  esk
  run esk --json
  [ "$(jq -r '.wynik.id, .wynik.nowa' <<<"$output" | tr '\n' ' ')" = "E-001 false " ]
  [ ! -e docs/07-realizacja/escalations/E-002.md ]
  [ "$(wc -l <"$T/notified" | tr -d ' ')" -eq 1 ]
}

@test "inny powod dostaje kolejny numer" {
  esk
  run "$SHCTL" escalate --dotyczy "#7" --powod "inny" --potrzebne x --json
  [ "$(jq -r .wynik.id <<<"$output")" = E-002 ]
}

@test "nieudane powiadomienie: kod 1, ponowienie wysyla" {
  touch "$T/notify-fail"
  run --separate-stderr esk
  [ "$status" -eq 1 ]
  rm "$T/notify-fail"
  : >"$T/notified"
  run esk
  [ "$status" -eq 0 ]
  [ "$(wc -l <"$T/notified" | tr -d ' ')" -eq 1 ]
}

@test "etap: status DoD i powrot po zamknieciu" {
  "$SHCTL" stage start 05-plan
  run "$SHCTL" escalate --dotyczy 05-plan --powod "sprzeczność" --potrzebne "decyzja"
  [ "$status" -eq 0 ]
  [ "$(fm docs/05-plan/DoD.md status)" = escalated ]
  grep -qx 'Etap: 05-plan' "$E1"
  run "$SHCTL" escalate close E-001 --odpowiedz "wariant A"
  [ "$status" -eq 0 ]
  [ "$(fm docs/05-plan/DoD.md status)" = in-progress ]
  [ "$(fm "$E1" status)" = zamknieta ]
  grep -qx 'wariant A' "$E1"
  grep -q '^(brak)$' docs/status.md
  ! grep -q 'E-001' docs/status.md || false
}

@test "close issue przywraca poprzedni status" {
  esk
  run "$SHCTL" escalate close E-001 --odpowiedz "OK"
  [ "$status" -eq 0 ]
  grep -q 'issue edit 7 --repo test-owner/demo --remove-label status:escalated --add-label status:in-progress' "$T/gh.calls"
}

@test "close przy drugiej otwartej eskalacji zostawia etykiete" {
  esk
  "$SHCTL" escalate --dotyczy "#7" --powod "drugi" --potrzebne x
  : >"$T/gh.calls"
  "$SHCTL" escalate close E-001 --odpowiedz OK
  ! grep -q 'issue edit' "$T/gh.calls" || false
}

@test "close jest idempotentny, inna odpowiedz to odmowa" {
  esk
  "$SHCTL" escalate close E-001 --odpowiedz "OK"
  run "$SHCTL" escalate close E-001 --odpowiedz "OK" --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.zmiana <<<"$output")" = false ]
  run --separate-stderr "$SHCTL" escalate close E-001 --odpowiedz "inna"
  [ "$status" -eq 4 ]
}

@test "blad gh przy close zostawia eskalacje otwarta" {
  esk
  touch "$T/gh-fail"
  run --separate-stderr "$SHCTL" escalate close E-001 --odpowiedz OK
  [ "$status" -eq 1 ]
  [ "$(fm "$E1" status)" = otwarta ]
}

@test "--dry-run nie dotyka GitHuba, plikow ani powiadomien" {
  run esk --dry-run --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.id <<<"$output")" = E-001 ]
  [ ! -s "$T/gh.calls" ]
  [ ! -s "$T/notified" ]
  [ -z "$(git status --porcelain)" ]
}

@test "bledne argumenty: kod 2" {
  run --separate-stderr "$SHCTL" escalate --dotyczy "#x" --powod a --potrzebne b
  [ "$status" -eq 2 ]
  run --separate-stderr "$SHCTL" escalate --dotyczy 05-plan --powod a --potrzebne b --priorytet zly
  [ "$status" -eq 2 ]
  run --separate-stderr "$SHCTL" escalate close E-1 --odpowiedz x
  [ "$status" -eq 2 ]
}

@test "close nieistniejacej: kod 3" {
  run --separate-stderr "$SHCTL" escalate close E-009 --odpowiedz x
  [ "$status" -eq 3 ]
}
