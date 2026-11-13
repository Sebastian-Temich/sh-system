#!/usr/bin/env bats
load helper

# Projekt demo z originem na lokalnym repo (insteadOf), zamkniętym cyklem M1 i dokumentami etapów.
setup() {
  wspolny_setup
  projekt_demo
  git init -q --bare "$T/remote.git"
  git config --global url."$T/remote.git".insteadOf https://github.com/test-owner/demo.git
  printf '# Specyfikacja\n' >docs/00-intake/specyfikacja.md
  mkdir -p docs/00-intake/funkcje docs/wydanie/techniczna
  printf '# W-01\n' >docs/00-intake/funkcje/W-01.md
  printf '# Plan\n' >docs/04-plan/plan.md
  printf '# ADR-001\n' >docs/04-plan/adr/ADR-001-baza.md
  printf '<!-- sync-status:start -->\n<!-- sync-status:end -->\n' >docs/06-zadania/index.md
  printf 'zadania: []\n' >docs/06-zadania/zadania.yaml
  printf '# Raport QA M1\n' >docs/08-qa/raport-M1.md
  printf '# Techniczna\n' >docs/wydanie/techniczna/README.md
  for e in $ETAPY; do
    sed -i.bak -e 's/^status: todo/status: done/' -e 's/^iteracja: 0/iteracja: 2/' -e 's/^- \[ \]/- [x]/' "docs/$e/DoD.md"
    rm -f "docs/$e/DoD.md.bak"
  done
  printf '# Historia projektu\n\n## Punkt przekazania\n\n(brak)\n\n## Dziennik etapów\n\n- %s `00-intake`: in-progress\n- %s `wydanie`: done\n\n<!-- historia:start -->\n## Wszystkie zadania zrobione (0)\n\nJeszcze nic.\n<!-- historia:end -->\n' \
    "$(date +%F)" "$(date +%F)" >docs/historia.md
  git add -A
  git commit -qm "cykl M1 zamknięty"
  git push -q origin main
  git push -q origin main:stage/00-intake main:stage/04-plan
  git branch -q stage/08-qa
  git fetch -q origin
  # PR gałęzi etapów: zmergowane (plik gh-pr-stage.json, domyślnie MERGED).
  cat >>"$T/mock/gh" <<MOCK
case "\$1 \$2" in
  "pr list") if [ -f "$T/gh-pr-stage.json" ]; then cat "$T/gh-pr-stage.json"; else echo '[{"number":3,"state":"MERGED"}]'; fi ;;
esac
MOCK
}

@test "odmowa, gdy etap cyklu nie jest zamkniety" {
  sed -i.bak 's/^status: done/status: review/' docs/08-qa/DoD.md
  rm -f docs/08-qa/DoD.md.bak
  git commit -qam "08-qa review"
  run --separate-stderr "$SHCTL" cykl new --nazwa M2-bezpieczenstwo
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"08-qa:review"* ]] || false
  [ ! -e docs/cykle ]
}

@test "cykl new archiwizuje etapy, zaklada swieze DoD i ustawia konfiguracje" {
  run "$SHCTL" cykl new --nazwa M2-bezpieczenstwo --od 2026-11-13T12:00:00Z --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.poprzedni <<<"$output")" = M1 ]
  [ "$(jq -r .wynik.archiwum <<<"$output")" = docs/cykle/M1 ]
  [ "$(jq -r '.wynik.galezie_usuniete | map(.galaz) | sort | join(",")' <<<"$output")" = "stage/00-intake,stage/04-plan,stage/08-qa" ]
  # Archiwum
  [ -f docs/cykle/M1/00-intake/specyfikacja.md ]
  [ -f docs/cykle/M1/00-intake/funkcje/W-01.md ]
  [ -f docs/cykle/M1/04-plan/plan.md ]
  [ -f docs/cykle/M1/06-zadania/zadania.yaml ]
  [ -f docs/cykle/M1/08-qa/raport-M1.md ]
  [ -f docs/cykle/M1/wydanie/techniczna/README.md ]
  [ "$(fm docs/cykle/M1/00-intake/DoD.md status)" = done ]
  [ "$(fm docs/cykle/M1/cykl.md do)" = 2026-11-13T12:00:00Z ]
  grep -qF '[04-plan/plan.md](04-plan/plan.md)' docs/cykle/M1/cykl.md
  # Zostają: ADR i tabela zadań
  [ -f docs/04-plan/adr/ADR-001-baza.md ]
  [ ! -e docs/cykle/M1/04-plan/adr ]
  [ -f docs/06-zadania/index.md ]
  [ ! -e docs/00-intake/specyfikacja.md ]
  [ -d docs/00-intake/funkcje ]
  [ -z "$(ls docs/00-intake/funkcje)" ]
  # Świeże DoD: wersja z pierwszego commita
  for e in $ETAPY; do
    [ "$(fm "docs/$e/DoD.md" status)" = todo ]
    [ "$(fm "docs/$e/DoD.md" iteracja)" = 0 ]
    grep -qxF -- '- [ ] punkt' "docs/$e/DoD.md"
  done
  # Konfiguracja
  [ "$(fm docs/konfiguracja.md cykl)" = M2-bezpieczenstwo ]
  [ "$(fm docs/konfiguracja.md cykl_od)" = 2026-11-13T12:00:00Z ]
  [ "$(fm docs/konfiguracja.md zlecenie_od)" = 2026-11-13T12:00:00Z ]
  grep -qxF 'Tekst.' docs/konfiguracja.md
  # Dziennik z nagłówkami cykli: wpisy M1 pod „### Cykl M1”
  dz="$(awk '/^## Dziennik etapów$/ { w = 1; next } w && /^(## |<!--)/ { exit } w' docs/historia.md)"
  [ "$(printf '%s\n' "$dz" | grep -n '^### Cykl M1$' | cut -d: -f1)" -lt "$(printf '%s\n' "$dz" | grep -n '00-intake`: in-progress' | cut -d: -f1)" ]
  printf '%s\n' "$dz" | grep -qxF '### Cykl M2-bezpieczenstwo'
  printf '%s\n' "$dz" | grep -q 'cykl `M2-bezpieczenstwo`: start (zlecenie_od 2026-11-13T12:00:00Z)'
  # Gałęzie
  [ -z "$(git ls-remote --heads origin 'stage/*')" ]
  ! git rev-parse -q --verify refs/heads/stage/08-qa >/dev/null || false
  grep -q -- '--repo test-owner/demo' "$T/sync.calls"
}

@test "powtorka z ta sama nazwa nic nie zmienia" {
  "$SHCTL" cykl new --nazwa M2-bezpieczenstwo >/dev/null 2>&1
  git add -A
  git commit -qm "cykl M2"
  run "$SHCTL" cykl new --nazwa M2-bezpieczenstwo --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.zmiana <<<"$output")" = false ]
  [ -z "$(git status --porcelain)" ]
}

@test "stage dziala na nowym cyklu, a dziennik nie myli wpisow z poprzednim cyklem" {
  "$SHCTL" cykl new --nazwa M2-bezpieczenstwo >/dev/null 2>&1
  run "$SHCTL" stage start 00-intake
  [ "$status" -eq 0 ]
  [ "$(fm docs/00-intake/DoD.md status)" = in-progress ]
  # Ten sam wpis co w M1 (ten sam dzień) trafia też pod nagłówek M2.
  [ "$(grep -c '00-intake`: in-progress' docs/historia.md)" -eq 2 ]
  [ "$(awk '/^### Cykl M2/ { w = 1 } w && /00-intake`: in-progress/' docs/historia.md | wc -l | tr -d ' ')" -eq 1 ]
  "$SHCTL" stage start 00-intake --notatka x >/dev/null
  "$SHCTL" stage start 00-intake --notatka x >/dev/null
  [ "$(grep -c '00-intake`: in-progress, x' docs/historia.md)" -eq 1 ]
}

@test "kolejny cykl archiwizuje poprzedni pod jego nazwa" {
  "$SHCTL" cykl new --nazwa M2-bezpieczenstwo --od 2026-11-13T12:00:00Z >/dev/null 2>&1
  for e in $ETAPY; do
    sed -i.bak -e 's/^status: todo/status: done/' "docs/$e/DoD.md"
    rm -f "docs/$e/DoD.md.bak"
  done
  printf '# Specyfikacja M2\n' >docs/00-intake/specyfikacja.md
  git add -A
  git commit -qm "cykl M2 zamknięty"
  run "$SHCTL" cykl new --nazwa M3-resend --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.poprzedni <<<"$output")" = M2-bezpieczenstwo ]
  grep -qxF '# Specyfikacja M2' docs/cykle/M2-bezpieczenstwo/00-intake/specyfikacja.md
  [ "$(fm docs/cykle/M2-bezpieczenstwo/cykl.md od)" = 2026-11-13T12:00:00Z ]
  [ "$(grep -c '^### Cykl M1$' docs/historia.md)" -eq 1 ]
  grep -qxF '### Cykl M3-resend' docs/historia.md
}

@test "--dry-run nic nie zmienia" {
  run "$SHCTL" cykl new --nazwa M2-bezpieczenstwo --dry-run --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.cykl <<<"$output")" = M2-bezpieczenstwo ]
  [ -z "$(git status --porcelain)" ]
  [ -n "$(git ls-remote --heads origin stage/00-intake)" ]
}

@test "odmowa przy otwartym PR etapu, niezacommitowanych zmianach i zlej nazwie" {
  echo '[{"number":9,"state":"OPEN"}]' >"$T/gh-pr-stage.json"
  run --separate-stderr "$SHCTL" cykl new --nazwa M2-x
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"otwarty PR"* ]] || false
  rm "$T/gh-pr-stage.json"
  echo zmiana >>docs/04-plan/plan.md
  run --separate-stderr "$SHCTL" cykl new --nazwa M2-x
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"niezacommitowane"* ]] || false
  git checkout -q docs/04-plan/plan.md
  run --separate-stderr "$SHCTL" cykl new --nazwa M1
  [ "$status" -eq 0 ]
  run --separate-stderr "$SHCTL" cykl new --nazwa "M2 x"
  [ "$status" -eq 2 ]
  run --separate-stderr "$SHCTL" cykl new --nazwa M2-x --od jutro
  [ "$status" -eq 2 ]
}

@test "zmieniony 06-zadania/index.md (sync-status w pracujacym projekcie) nie blokuje" {
  printf '<!-- sync-status:start -->\n| #20 |\n<!-- sync-status:end -->\n' >docs/06-zadania/index.md
  echo zmiana >>docs/Projekt.md
  run "$SHCTL" cykl new --nazwa M2-bezpieczenstwo --json
  [ "$status" -eq 0 ]
  grep -qF '| #20 |' docs/06-zadania/index.md
}

@test "tryb S: odmowa" {
  sed -i.bak 's/^tryb_procesu: M/tryb_procesu: S/' docs/konfiguracja.md
  rm -f docs/konfiguracja.md.bak
  git commit -qam S
  run --separate-stderr "$SHCTL" cykl new --nazwa M2-x
  [ "$status" -eq 4 ]
}
