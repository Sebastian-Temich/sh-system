#!/usr/bin/env bats
load helper

setup() { wspolny_setup; projekt_demo; }

dod() { echo "docs/$1/DoD.md"; }
zaznacz() { sed -i.bak 's/^- \[ \]/- [x]/' "$(dod "$1")"; rm -f "$(dod "$1").bak"; }

@test "start ustawia status, dziennik w historia.md i odswieza widok" {
  run "$SHCTL" stage start 04-plan --notatka "pierwsza"
  [ "$status" -eq 0 ]
  [ "$(fm "$(dod 04-plan)" status)" = in-progress ]
  grep -q -- '--repo test-owner/demo' "$T/sync.calls"
  grep -q '04-plan`: in-progress, pierwsza' docs/historia.md
  ! grep -qxF '(brak)' <(awk '/^## Dziennik etapów$/ { w = 1; next } w && /^(## |<!--)/ { exit } w' docs/historia.md) || false
  # Wpis ląduje przed blokiem generowanym, a blok zostaje.
  [ "$(grep -n '04-plan`: in-progress' docs/historia.md | cut -d: -f1)" -lt "$(grep -n 'historia:start' docs/historia.md | cut -d: -f1)" ]
  grep -qxF '<!-- historia:end -->' docs/historia.md
}

@test "projekt ze starym szablonem bez historia.md: dziennik dalej w Projekt.md" {
  rm docs/historia.md
  printf '\n## Dziennik etapów\n\n- 2026-11-01 `00-intake`: done\n' >>docs/Projekt.md
  run "$SHCTL" stage start 04-plan
  [ "$status" -eq 0 ]
  [ ! -e docs/historia.md ]
  grep -q '04-plan`: in-progress' docs/Projekt.md
}

@test "start jest idempotentny" {
  "$SHCTL" stage start 04-plan --notatka n
  cp docs/historia.md "$T/przed"
  run "$SHCTL" stage start 04-plan --notatka n --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.zmiana <<<"$output")" = false ]
  cmp docs/historia.md "$T/przed"
}

@test "kolejna notatka przy tym samym statusie trafia do dziennika" {
  "$SHCTL" stage start 04-plan
  "$SHCTL" stage start 04-plan --notatka "czeka na dostęp"
  grep -q 'czeka na dostęp' docs/historia.md
}

@test "--dry-run nic nie zmienia" {
  run "$SHCTL" stage start 04-plan --dry-run --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.status <<<"$output")" = in-progress ]
  [ -z "$(git status --porcelain)" ]
}

@test "review wymaga in-progress" {
  run --separate-stderr "$SHCTL" stage review 04-plan
  [ "$status" -eq 4 ]
}

@test "done odmawia przy brakach i zostawia status" {
  "$SHCTL" stage start 04-plan
  "$SHCTL" stage review 04-plan
  run --separate-stderr "$SHCTL" stage done 04-plan
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"check-dod"* ]] || false
  [ "$(fm "$(dod 04-plan)" status)" = review ]
}

@test "done przechodzi po zaznaczeniu pol" {
  "$SHCTL" stage start 04-plan
  "$SHCTL" stage review 04-plan
  zaznacz 04-plan
  run "$SHCTL" stage done 04-plan
  [ "$status" -eq 0 ]
  [ "$(fm "$(dod 04-plan)" status)" = done ]
  run "$SHCTL" stage done 04-plan
  [ "$status" -eq 0 ]
}

@test "done --dry-run sprawdza DoD bez zapisu" {
  "$SHCTL" stage start 04-plan
  "$SHCTL" stage review 04-plan
  run --separate-stderr "$SHCTL" stage done 04-plan --dry-run
  [ "$status" -eq 4 ]
  zaznacz 04-plan
  run "$SHCTL" stage done 04-plan --dry-run
  [ "$status" -eq 0 ]
  [ "$(fm "$(dod 04-plan)" status)" = review ]
}

@test "done odmawia, gdy check-dod pada na biezacym stanie repo" {
  "$SHCTL" stage start 04-plan
  "$SHCTL" stage review 04-plan
  zaznacz 04-plan
  printf '#!/bin/sh\n[ -d "$1/.git" ] && { echo hook >&2; exit 1; }\nexit 0\n' >scripts/check-dod.sh
  run --separate-stderr "$SHCTL" stage done 04-plan
  [ "$status" -eq 4 ]
}

@test "stage skip nie istnieje: pominiecie to status w DoD.md z decyzja" {
  run --separate-stderr "$SHCTL" stage skip 04-plan
  [ "$status" -eq 2 ]
}

@test "start pominietego etapu: odmowa" {
  yq -i --front-matter=process '.status = "pominiety" | .decyzja = "test"' "$(dod 04-plan)"
  run --separate-stderr "$SHCTL" stage start 04-plan
  [ "$status" -eq 4 ]
}

@test "etapy trybu L i DoD realizacji nie sa etapami shctl" {
  for e in 01-brief 02-design 03-wymagania 07-realizacja; do
    run --separate-stderr "$SHCTL" stage start "$e"
    [ "$status" -eq 2 ]
  done
}

@test "escalate i powrot przez start" {
  "$SHCTL" stage start 04-plan
  run "$SHCTL" stage escalate 04-plan
  [ "$status" -eq 0 ]
  [ "$(fm "$(dod 04-plan)" status)" = escalated ]
  "$SHCTL" stage start 04-plan
  [ "$(fm "$(dod 04-plan)" status)" = in-progress ]
}

@test "nieznany etap: kod 2" {
  run --separate-stderr "$SHCTL" stage start 99-nic
  [ "$status" -eq 2 ]
}

@test "poza main ostrzega" {
  git checkout -q -b stage/04-plan
  run --separate-stderr "$SHCTL" stage start 04-plan
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"pliki wspólne"* ]] || false
}

@test "frontmatter i tresc DoD bez innych zmian" {
  cp "$(dod 04-plan)" "$T/dod"
  "$SHCTL" stage start 04-plan
  run diff "$T/dod" "$(dod 04-plan)"
  [ "$(grep -c '^[<>]' <<<"$output")" -eq 2 ]
}

@test "projekt v1 (bez wersja_procesu): etapy 04-architektura i 05-plan, bez 04-plan" {
  sed -i.bak '/^wersja_procesu:/d' docs/konfiguracja.md && rm -f docs/konfiguracja.md.bak
  for e in 04-architektura 05-plan; do
    mkdir -p "docs/$e"
    sed "s/^etap: .*/etap: $e/" "$(dod 04-plan)" >"$(dod "$e")"
  done
  rm -r docs/04-plan
  run "$SHCTL" stage start 05-plan
  [ "$status" -eq 0 ]
  [ "$(fm "$(dod 05-plan)" status)" = in-progress ]
  run --separate-stderr "$SHCTL" stage start 04-plan
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"04-architektura 05-plan"* ]] || false
}

@test "nieznana wersja_procesu: kod 2" {
  sed -i.bak 's/^wersja_procesu: .*/wersja_procesu: 9/' docs/konfiguracja.md && rm -f docs/konfiguracja.md.bak
  run --separate-stderr "$SHCTL" stage start 04-plan
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"wersja_procesu='9'"* ]] || false
}
