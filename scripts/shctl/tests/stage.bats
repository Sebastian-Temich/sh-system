#!/usr/bin/env bats
load helper

setup() { wspolny_setup; projekt_demo; }

dod() { echo "docs/$1/DoD.md"; }
zaznacz() { sed -i.bak 's/^- \[ \]/- [x]/' "$(dod "$1")"; rm -f "$(dod "$1").bak"; }

@test "start ustawia status i status.md" {
  run "$SHCTL" stage start 04-architektura --notatka "pierwsza"
  [ "$status" -eq 0 ]
  [ "$(fm "$(dod 04-architektura)" status)" = in-progress ]
  grep -q '`04-architektura`: in-progress$' docs/status.md
  grep -q '04-architektura`: in-progress, pierwsza' docs/status.md
}

@test "start jest idempotentny" {
  "$SHCTL" stage start 05-plan --notatka n
  cp docs/status.md "$T/przed"
  run "$SHCTL" stage start 05-plan --notatka n --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.zmiana <<<"$output")" = false ]
  cmp docs/status.md "$T/przed"
}

@test "kolejna notatka przy tym samym statusie trafia do dziennika" {
  "$SHCTL" stage start 05-plan
  "$SHCTL" stage start 05-plan --notatka "czeka na dostęp"
  grep -q 'czeka na dostęp' docs/status.md
}

@test "--dry-run nic nie zmienia" {
  run "$SHCTL" stage start 05-plan --dry-run --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.status <<<"$output")" = in-progress ]
  [ -z "$(git status --porcelain)" ]
}

@test "review wymaga in-progress" {
  run --separate-stderr "$SHCTL" stage review 05-plan
  [ "$status" -eq 4 ]
}

@test "done odmawia przy brakach i zostawia status" {
  "$SHCTL" stage start 05-plan
  "$SHCTL" stage review 05-plan
  run --separate-stderr "$SHCTL" stage done 05-plan
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"check-dod"* ]] || false
  [ "$(fm "$(dod 05-plan)" status)" = review ]
}

@test "done przechodzi po zaznaczeniu pol" {
  "$SHCTL" stage start 05-plan
  "$SHCTL" stage review 05-plan
  zaznacz 05-plan
  run "$SHCTL" stage done 05-plan
  [ "$status" -eq 0 ]
  [ "$(fm "$(dod 05-plan)" status)" = done ]
  run "$SHCTL" stage done 05-plan
  [ "$status" -eq 0 ]
}

@test "done --dry-run sprawdza DoD bez zapisu" {
  "$SHCTL" stage start 05-plan
  "$SHCTL" stage review 05-plan
  run --separate-stderr "$SHCTL" stage done 05-plan --dry-run
  [ "$status" -eq 4 ]
  zaznacz 05-plan
  run "$SHCTL" stage done 05-plan --dry-run
  [ "$status" -eq 0 ]
  [ "$(fm "$(dod 05-plan)" status)" = review ]
}

@test "done odmawia, gdy check-dod pada na biezacym stanie repo" {
  "$SHCTL" stage start 05-plan
  "$SHCTL" stage review 05-plan
  zaznacz 05-plan
  printf '#!/bin/sh\n[ -d "$1/.git" ] && { echo hook >&2; exit 1; }\nexit 0\n' >scripts/check-dod.sh
  run --separate-stderr "$SHCTL" stage done 05-plan
  [ "$status" -eq 4 ]
}

@test "skip etapu z trybu M bez notatki: odmowa" {
  run --separate-stderr "$SHCTL" stage skip 04-architektura
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"pominięcie wymaga --notatka"* ]] || false
  [ "$(fm "$(dod 04-architektura)" status)" = todo ]
}

@test "skip etapu z trybu M z notatka: uzasadnienie w DoD.md i dzienniku" {
  run --separate-stderr "$SHCTL" stage skip 04-architektura --notatka "biblioteka bez architektury: jeden moduł"
  [ "$status" -eq 0 ]
  [ "$(fm "$(dod 04-architektura)" status)" = pominiety ]
  [ "$(fm "$(dod 04-architektura)" uzasadnienie_pominiecia)" = "biblioteka bez architektury: jeden moduł" ]
  grep -qF '`04-architektura`: pominiety, biblioteka bez architektury: jeden moduł' docs/status.md
}

@test "skip etapu spoza trybu M" {
  run "$SHCTL" stage skip 02-design
  [ "$status" -eq 0 ]
  [ "$(fm "$(dod 02-design)" status)" = pominiety ]
}

@test "start pominietego etapu: odmowa" {
  "$SHCTL" stage skip 02-design
  run --separate-stderr "$SHCTL" stage start 02-design
  [ "$status" -eq 4 ]
}

@test "escalate i powrot przez start" {
  "$SHCTL" stage start 05-plan
  run "$SHCTL" stage escalate 05-plan
  [ "$status" -eq 0 ]
  [ "$(fm "$(dod 05-plan)" status)" = escalated ]
  "$SHCTL" stage start 05-plan
  [ "$(fm "$(dod 05-plan)" status)" = in-progress ]
}

@test "nieznany etap: kod 2" {
  run --separate-stderr "$SHCTL" stage start 99-nic
  [ "$status" -eq 2 ]
}

@test "poza main ostrzega" {
  git checkout -q -b stage/05-plan
  run --separate-stderr "$SHCTL" stage start 05-plan
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"pliki wspólne"* ]] || false
}

@test "frontmatter i tresc DoD bez innych zmian" {
  cp "$(dod 05-plan)" "$T/dod"
  "$SHCTL" stage start 05-plan
  run diff "$T/dod" "$(dod 05-plan)"
  [ "$(grep -c '^[<>]' <<<"$output")" -eq 2 ]
}
