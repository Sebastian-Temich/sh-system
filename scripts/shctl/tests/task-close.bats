#!/usr/bin/env bats
load helper-zadania

setup() {
  zadania_setup
  zadanie_w_toku 12
  pr_workera 12 20
}

pass() {
  wynik_codex PASS '[{"waga":"drobne","plik":"src/a.ts","linia":3,"opis":"literówka w komentarzu"}]'
  "$SHCTL" review run 20 >/dev/null
}

@test "close: bez werdyktu PASS to odmowa, bez merge" {
  wynik_codex FAIL '[{"waga":"istotne","plik":"a","linia":1,"opis":"x"}]'
  "$SHCTL" review run 20 >/dev/null
  run --separate-stderr "$SHCTL" task close 12
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"nie ma werdyktu PASS"* ]] || false
  ! grep -q '^pr merge' "$GH_ATRAPA/calls" || false
  run --separate-stderr "$SHCTL" task close 12
  [ "$status" -eq 4 ]
}

@test "close: bez review to odmowa" {
  run --separate-stderr "$SHCTL" task close 12
  [ "$status" -eq 4 ]
}

@test "close: CI nie zielone to odmowa" {
  pass
  ustaw_ci 20 FAILURE
  run --separate-stderr "$SHCTL" task close 12
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"CI PR #20: fail"* ]] || false
  jq 'map(if .number == 20 then .statusCheckRollup = [{status:"IN_PROGRESS", conclusion:""}] else . end)' "$GH_ATRAPA/prs.json" >"$T/x" && mv "$T/x" "$GH_ATRAPA/prs.json"
  run --separate-stderr "$SHCTL" task close 12
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"pending"* ]] || false
}

@test "close: PASS dla starego commita nie wystarcza" {
  pass
  wt="$SH_DIR/wt/demo/12"
  echo x >>"$wt/src/praca-12.txt"
  git -C "$wt" commit -qam nowy
  git -C "$wt" push -q origin HEAD
  jq --arg s "$(git -C "$wt" rev-parse HEAD)" 'map(if .number == 20 then .headRefOid = $s else . end)' "$GH_ATRAPA/prs.json" >"$T/x" && mv "$T/x" "$GH_ATRAPA/prs.json"
  run --separate-stderr "$SHCTL" task close 12
  [ "$status" -eq 4 ]
}

@test "close: merge, pliki wspolne, metryki, CHANGELOG, propozycje, sprzatanie" {
  pass
  run --separate-stderr "$SHCTL" task close 12 --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  grep -q '^pr merge 20 --repo test-owner/demo --squash --match-head-commit' "$GH_ATRAPA/calls"
  [ -f docs/07-realizacja/T-12.md ]
  grep -qF '| T-12 | Format daty | ISO 8601, bo prościej sortować |' docs/decyzje.md
  grep -qF '| T-12 | - | Walidacja po stronie serwera |' docs/decyzje.md
  grep -qF '| T-12 | Nazwa funkcji `x` mało czytelna do zmiany przy okazji | otwarta |' docs/backlog-drobne.md
  grep -qF '| review PR #20 | literówka w komentarzu (`src/a.ts:3`) | otwarta |' docs/backlog-drobne.md
  grep -qE '^\| #12 Zadanie 12 \| M \| [0-9h ]*[0-9]+min \| 1 \| 1 \| 0 \| PR #20 \|$' docs/metryki.md
  [ "$(czytaj() { awk '/^## Niewydane/{w=1;next} w' CHANGELOG.md | grep .; }; czytaj)" = "- #12: Zadanie 12 (PR #20)" ]
  [ "$(jq -r '.wynik.propozycje' <<<"$output")" = "https://github.com/test-owner/sh-system/pull/21" ]
  git -C "$T/sys.git" show propozycje/demo-T-12:docs/propozycje.md | grep -q 'shctl mógłby sam uruchamiać lint'
  git -C "$T/sys.git" show propozycje/demo-T-12:docs/propozycje.md | grep -q '<!-- propozycje:demo:T-12 -->'
  [ -z "$(git -C "$SH_SYSTEM_DIR" status --porcelain)" ]
  [ ! -e "$SH_DIR/wt/demo/12" ]
  [ ! -e "$SH_DIR/wt/demo/sys-propozycje-demo-12" ]
  [ -z "$(git branch --list 'task/*')" ]
  [ "$(etykiety_paneli)" = "" ]
  [ "$(stan_issue 12)" = CLOSED ]
  [ "$(etykiety 12)" = "iter:1,runner:local,wykonawca:claude" ]
  [ "$(jq -r '.zadania | has("12")' "$SH_DIR/stan/demo.json")" = false ]
  grep -q -- "--repo $R" "$T/sync.calls"
}

@test "close: powtorka niczego nie dubluje" {
  pass
  "$SHCTL" task close 12 >/dev/null
  for f in docs/decyzje.md docs/backlog-drobne.md docs/metryki.md CHANGELOG.md; do cp "$f" "$T/$(basename "$f")"; done
  run --separate-stderr "$SHCTL" task close 12 --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  for f in docs/decyzje.md docs/backlog-drobne.md docs/metryki.md CHANGELOG.md; do cmp "$f" "$T/$(basename "$f")"; done
  [ "$(grep -c '^pr merge' "$GH_ATRAPA/calls")" -eq 1 ]
  [ "$(grep -c '^pr create' "$GH_ATRAPA/calls")" -eq 1 ]
}

@test "close: niezacommitowane zmiany w worktree to odmowa przed merge" {
  pass
  echo brud >"$SH_DIR/wt/demo/12/src/brud.txt"
  run --separate-stderr "$SHCTL" task close 12
  [ "$status" -eq 4 ]
  ! grep -q '^pr merge' "$GH_ATRAPA/calls" || false
}

@test "close: tylko z main" {
  pass
  git switch -q -c inna
  run --separate-stderr "$SHCTL" task close 12
  [ "$status" -eq 4 ]
}

@test "close --dry-run nie merguje i nie zmienia plikow" {
  pass
  run --separate-stderr "$SHCTL" task close 12 --dry-run --json
  [ "$status" -eq 0 ]
  ! grep -q '^pr merge' "$GH_ATRAPA/calls" || false
  [ -z "$(git status --porcelain)" ]
  [ -d "$SH_DIR/wt/demo/12" ]
}
