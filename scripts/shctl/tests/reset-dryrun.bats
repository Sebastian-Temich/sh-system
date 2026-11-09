#!/usr/bin/env bats
load helper-zadania

setup() {
  zadania_setup
  export SHCTL_DRYRUN_NAZWA=demo
  printf -- '- {id: D1, tytul: Pierwsze, cel: c, kryteria: [k]}\n- {id: D2, tytul: Drugie, cel: c, kryteria: [k], zaleznosci: [D1]}\n' >zadania.yaml
  git add zadania.yaml && git commit -qm baseline && git tag baseline && git push -q origin main baseline
  "$SHCTL" task create --plik zadania.yaml >/dev/null
  git checkout -q -- . && git clean -fdq
  BASE="$(git rev-parse baseline)"
}

otwarte() { jq -r '[.[] | select(.state == "OPEN") | .number] | join(",")' "$GH_ATRAPA/issues.json"; }

@test "reset-dryrun: w stanie baseline nic nie robi" {
  run --separate-stderr "$SHCTL" reset-dryrun --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.zmiana <<<"$output")" = false ]
}

@test "reset-dryrun: zamyka PR, archiwizuje issue, main do baseline, odtwarza issue" {
  "$SHCTL" task dispatch 1 >/dev/null
  pr_workera 1 9
  echo zmiana >src/main.txt && git add -A && git commit -qm "po baseline" && git push -q origin main
  run --separate-stderr "$SHCTL" reset-dryrun --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.zamkniete_pr | join(",")' <<<"$output")" = 9 ]
  [ "$(jq -r '.[] | select(.number == 9) | .state' "$GH_ATRAPA/prs.json")" = CLOSED ]
  [ "$(jq -r '.[] | select(.number == 1) | .stateReason' "$GH_ATRAPA/issues.json")" = NOT_PLANNED ]
  jq -r '.[] | select(.number == 1) | .body' "$GH_ATRAPA/issues.json" | grep -q 'shctl:archiwum-id=D1'
  [ "$(git rev-parse main^)" = "$BASE" ]
  git diff --quiet "$BASE" main -- . ':(exclude)docs/metryki.md' ':(exclude)docs/06-zadania/index.md' ':(exclude)docs/status.md'
  [ ! -e "$SH_DIR/wt/demo/1" ]
  [ -z "$(git branch --list 'task/*')" ]
  [ "$(etykiety_paneli)" = "" ]
  [ "$(otwarte)" = "10,11" ]
  [ "$(jq -r '.wynik.mapa.D1, .wynik.mapa.D2' <<<"$output" | tr '\n' ' ')" = "10 11 " ]
  [ "$(jq -r '.zadania | length' "$SH_DIR/stan/demo.json")" -eq 0 ]
  [ -z "$(git status --porcelain)" ]
  [ "$(git rev-parse main)" = "$(git -C "$T/remote.git" rev-parse main)" ]
  [ "$(git log -1 --format=%s main)" = "reset-dryrun: przebieg 1 od baseline ${BASE:0:7}" ]
  run --separate-stderr "$SHCTL" reset-dryrun --json
  [ "$(jq -r .wynik.zmiana <<<"$output")" = false ]
}

@test "reset-dryrun: archiwizuje znacznik w zamknietym issue, usuwa galezie stage/* i task/*" {
  zamknij_issue 1
  git branch stage/08-qa && git branch task/7-stare
  run --separate-stderr "$SHCTL" reset-dryrun --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.zarchiwizowane | join(",")' <<<"$output")" = "1,2" ]
  [ "$(jq -r '.wynik.zamkniete_issue | join(",")' <<<"$output")" = 2 ]
  jq -r '.[] | select(.number == 1) | .body' "$GH_ATRAPA/issues.json" | grep -q 'shctl:archiwum-id=D1'
  [ "$(jq -r '.wynik.mapa.D1, .wynik.mapa.D2' <<<"$output" | tr '\n' ' ')" = "3 4 " ]
  [ -z "$(git branch --list 'stage/*' 'task/*')" ]
}

@test "reset-dryrun: metryki przechodza przez reset, nowy przebieg dostaje wlasna tabele" {
  printf '\n## Przebieg dryrun 1 (2026-11-04)\n\n| Zlecenie | Tryb |\n|---|---|\n| #1 Pierwsze | M |\n\nWnioski przebiegu 1.\n' >>docs/metryki.md
  echo zmiana >src/main.txt
  git add -A && git commit -qm "przebieg 1" && git push -q origin main
  run --separate-stderr "$SHCTL" reset-dryrun --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.przebieg <<<"$output")" = 2 ]
  grep -q '^Wnioski przebiegu 1\.$' docs/metryki.md
  grep -q '^## Przebieg dryrun 2 ' docs/metryki.md
  [ "$(git -C "$T/remote.git" show main:docs/metryki.md | grep -c '^## Przebieg dryrun')" -eq 2 ]
  [ "$(tail -1 docs/metryki.md)" = '|---|---|---|---|---|---|---|' ]
}

@test "reset-dryrun: baseline z artefaktami przebiegu to odmowa" {
  mkdir -p docs/07-realizacja/escalations
  echo raport >docs/07-realizacja/T-1.md
  echo esk >docs/07-realizacja/escalations/E-001.md
  git add -A && git commit -qm artefakty && git tag -f baseline >/dev/null && git push -q -f origin main baseline
  run --separate-stderr "$SHCTL" reset-dryrun
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"docs/07-realizacja/T-1.md: plik przebiegu"* ]] || false
  [[ "$stderr" == *"E-001.md"* ]] || false
}

@test "reset-dryrun: klon w vaulcie Obsidiana odtworzony po force push" {
  "$SHCTL" obsidian link demo >/dev/null
  V="$SH_OBSIDIAN_DIR/demo"
  echo zmiana >src/main.txt && git add -A && git commit -qm "po baseline" && git push -q origin main
  git -C "$V" pull -q --ff-only
  run --separate-stderr "$SHCTL" reset-dryrun --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.obsidian <<<"$output")" = odtworzony ]
  [ "$(git -C "$V" rev-parse HEAD)" = "$(git -C "$T/remote.git" rev-parse main)" ]
  [ -f "$V/docs/metryki.md" ]
}

@test "reset-dryrun: klon z lokalnymi zmianami zostaje, reset konczy sie sukcesem" {
  "$SHCTL" obsidian link demo >/dev/null
  echo notatka >>"$SH_OBSIDIAN_DIR/demo/docs/metryki.md"
  echo zmiana >src/main.txt && git add -A && git commit -qm "po baseline" && git push -q origin main
  run --separate-stderr "$SHCTL" reset-dryrun --json
  [ "$status" -eq 0 ]
  [[ "$(jq -r .wynik.obsidian <<<"$output")" == "pominiety: "*"niezacommitowane zmiany" ]] || false
  grep -q notatka "$SH_OBSIDIAN_DIR/demo/docs/metryki.md"
}

@test "reset-dryrun: tylko projekt wzorcowy" {
  run --separate-stderr "$SHCTL" reset-dryrun --projekt inny
  [ "$status" -eq 4 ]
  unset SHCTL_DRYRUN_NAZWA
  run --separate-stderr "$SHCTL" reset-dryrun --projekt demo
  [ "$status" -eq 4 ]
}

@test "reset-dryrun: brak tagu baseline to kod 3" {
  git tag -d baseline >/dev/null
  git push -q origin :refs/tags/baseline
  echo x >>src/app.txt && git commit -qam x
  run --separate-stderr "$SHCTL" reset-dryrun
  [ "$status" -eq 3 ]
}

@test "reset-dryrun --dry-run niczego nie zmienia" {
  "$SHCTL" task dispatch 1 >/dev/null
  run --separate-stderr "$SHCTL" reset-dryrun --dry-run --json
  [ "$status" -eq 0 ]
  [ -d "$SH_DIR/wt/demo/1" ]
  [ "$(otwarte)" = "1,2" ]
  ! grep -qE '^(pr close|issue close)' "$GH_ATRAPA/calls" || false
}

@test "reset-dryrun: najnowszy tag baseline-RRRRMMDD albo baseline_tag z konfiguracji, bez przesuwania tagow" {
  # Nowszy baseline jako nowy tag (commit z późniejszą datą).
  echo nowy >src/baseline.txt && git add -A
  GIT_COMMITTER_DATE="2030-01-01T00:00:00Z" git commit -qm "nowy baseline"
  NOWY="$(git rev-parse HEAD)"
  git tag baseline-20300101 && git push -q origin main baseline-20300101
  echo zmiana >src/main.txt && git add -A && git commit -qm "po baseline" && git push -q origin main
  run --separate-stderr "$SHCTL" reset-dryrun --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.tag <<<"$output")" = baseline-20300101 ]
  [ "$(git rev-parse baseline)" = "$BASE" ]
  [ "$(git --git-dir "$T/remote.git" rev-parse refs/tags/baseline)" = "$BASE" ]
  # Wskazany w konfiguracji tag wygrywa z najnowszym.
  sed -i.bak 's/^tryb_procesu: M/tryb_procesu: M\nbaseline_tag: baseline/' docs/konfiguracja.md && rm -f docs/konfiguracja.md.bak
  run --separate-stderr "$SHCTL" reset-dryrun --dry-run --json
  [ "$(jq -r '.wynik.tag, .wynik.baseline' <<<"$output" | tr '\n' ' ')" = "baseline $BASE " ]
}
