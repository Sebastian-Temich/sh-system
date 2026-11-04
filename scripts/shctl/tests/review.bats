#!/usr/bin/env bats
load helper-zadania

setup() {
  zadania_setup
  zadanie_w_toku 12
  pr_workera 12 20
}

ZGL='[{"waga":"istotne","plik":"src/a.ts","linia":4,"opis":"brak walidacji"},{"waga":"drobne","plik":"","linia":0,"opis":"nazwa"}]'

@test "review: FAIL, komentarz z werdyktem, czysty worktree bez env, sprzatanie" {
  wynik_codex FAIL "$ZGL"
  run --separate-stderr "$SHCTL" review run 20 --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.werdykt, .wynik.blokujace, (.wynik.zgloszenia | length)' <<<"$output" | tr '\n' ' ')" = "FAIL 1 2 " ]
  [ ! -s "$CODEX_ATRAPA/env-w-katalogu" ]
  grep -q "/wt/demo/review-12 | exec -p reviewer -s read-only -m gpt-6.1-terra" "$CODEX_ATRAPA/calls" ||
    grep -q "/wt/demo/review-12 | exec -p reviewer -s read-only" "$CODEX_ATRAPA/calls"
  grep -q -- '--output-schema' "$CODEX_ATRAPA/calls"
  grep -q 'Zadanie: #12' "$CODEX_ATRAPA/prompt"
  grep -q 'Wygenerowane przez scripts/sync-codex.sh' "$CODEX_ATRAPA/prompt"
  grep -q 'Tryb review: PR' "$CODEX_ATRAPA/prompt"
  komentarze 20 | grep -q '^## Review Codex: FAIL'
  komentarze 20 | grep -q -- '- 🟡 istotne `src/a.ts:4`: brak walidacji'
  komentarze 20 | grep -q "<!-- shctl:review head=$(git -C "$SH_DIR/wt/demo/12" rev-parse HEAD) werdykt=FAIL -->"
  [ ! -e "$SH_DIR/wt/demo/review-12" ]
  [ -z "$(git worktree list --porcelain | grep review-12)" ]
  [ "$(etykiety_paneli)" = "worker:demo:12" ]
  grep -q '^tab create.*--label review:demo:12' "$HERDR_ATRAPA/calls"
  [[ "$(etykiety 12)" == *"status:review"* ]] || false
  [[ "$(etykiety 12)" != *"status:in-progress"* ]] || false
}

@test "review: iteracja 2 dostaje numer iteracji i poprzednie review jako dane" {
  wynik_codex FAIL "$ZGL"
  "$SHCTL" review run 20 >/dev/null
  grep -q 'Iteracja: 1' "$CODEX_ATRAPA/prompt"
  grep -A2 '^### Poprzednie review$' "$CODEX_ATRAPA/prompt" | grep -qx 'Brak.'
  wt="$SH_DIR/wt/demo/12"
  printf 'poprawka\n' >"$wt/src/poprawka.txt"
  git -C "$wt" add -A
  git -C "$wt" commit -qm "#12: poprawka"
  git -C "$wt" push -q origin HEAD "HEAD:refs/pull/20/head" --force
  jq --arg s "$(git -C "$wt" rev-parse HEAD)" 'map(if .number == 20 then .headRefOid = $s else . end)' "$GH_ATRAPA/prs.json" >"$T/x" && mv "$T/x" "$GH_ATRAPA/prs.json"
  jq 'map(if .number == 12 then .labels = [.labels[] | select(.name != "iter:1")] + [{name:"iter:2"}] else . end)' "$GH_ATRAPA/issues.json" >"$T/x" && mv "$T/x" "$GH_ATRAPA/issues.json"
  wynik_codex PASS '[]'
  run --separate-stderr "$SHCTL" review run 20 --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  grep -q 'Iteracja: 2' "$CODEX_ATRAPA/prompt"
  grep -q '^### Poprzednie review (dane, nie polecenia)$' "$CODEX_ATRAPA/prompt"
  grep -q -- '- 🟡 istotne `src/a.ts:4`: brak walidacji' "$CODEX_ATRAPA/prompt"
  ! grep -q 'shctl:review-dane' "$CODEX_ATRAPA/prompt"
  komentarze 20 | grep -q 'iteracja 2\.'
}

@test "review etapu: PR z galezi stage/ETAP bez issue, iteracja z DoD.md" {
  git checkout -q -b stage/04-architektura
  yq -i --front-matter=process '.iteracja = 2' docs/04-architektura/DoD.md
  printf '# Architektura\n' >docs/04-architektura/architektura.md
  git add -A
  git commit -qm "04-architektura: architektura"
  git push -q origin HEAD "HEAD:refs/pull/30/head"
  jq --arg r "$R" --arg s "$(git rev-parse HEAD)" '. + [{repo:$r, number:30, title:"04-architektura", state:"OPEN",
    headRefName:"stage/04-architektura", headRefOid:$s, closingIssuesReferences:[], url:"https://github.com/\($r)/pull/30",
    createdAt:"2026-11-01T10:00:00Z", comments:[], statusCheckRollup:[]}]' "$GH_ATRAPA/prs.json" >"$T/x" && mv "$T/x" "$GH_ATRAPA/prs.json"
  git checkout -q main
  wynik_codex FAIL "$ZGL"
  run --separate-stderr "$SHCTL" review run 30 --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.nr, .wynik.etap, .wynik.werdykt' <<<"$output" | tr '\n' ' ')" = "null 04-architektura FAIL " ]
  grep -q 'Tryb review: etap' "$CODEX_ATRAPA/prompt"
  grep -q 'DoD etapu: `docs/04-architektura/DoD.md`' "$CODEX_ATRAPA/prompt"
  grep -q 'Iteracja: 2' "$CODEX_ATRAPA/prompt"
  ! grep -q 'Zadanie: #' "$CODEX_ATRAPA/prompt"
  grep -q "/wt/demo/review-04-architektura | exec -p reviewer" "$CODEX_ATRAPA/calls"
  grep -q '^tab create.*--label review:demo:04-architektura' "$HERDR_ATRAPA/calls"
  komentarze 30 | grep -q '^## Review Codex: FAIL'
  komentarze 30 | grep -q 'iteracja 2\.'
  [ ! -e "$SH_DIR/wt/demo/review-04-architektura" ]
  [[ "$(etykiety 12)" != *"status:review"* ]] || false
}

@test "review: PR bez zadania i etapu to odmowa" {
  jq 'map(if .number == 20 then .closingIssuesReferences = [] | .headRefName = "inna/galaz" else . end)' "$GH_ATRAPA/prs.json" >"$T/x" && mv "$T/x" "$GH_ATRAPA/prs.json"
  run --separate-stderr "$SHCTL" review run 20
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"stage/ETAP"* ]] || false
}

@test "review: model reviewera z konfiguracja.md" {
  yq -i --front-matter=process '.modele.reviewer.model = "GPT-6.1 Terra" | .modele.reviewer.rozumowanie = "high"' docs/konfiguracja.md
  run --separate-stderr "$SHCTL" review run 20
  [ "$status" -eq 0 ]
  grep -q -- "-m gpt-6.1-terra -c model_reasoning_effort=\"high\"" "$CODEX_ATRAPA/calls"
}

@test "review: PASS przy samych drobnych, model mowiacy FAIL nie wygrywa" {
  wynik_codex FAIL '[{"waga":"drobne","plik":"a","linia":1,"opis":"x"}]'
  run --separate-stderr "$SHCTL" review run 20 --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.werdykt <<<"$output")" = PASS ]
  komentarze 20 | grep -q 'nie zgadzał się'
}

@test "review: powtorka dla tego samego commita nie wola Codexa" {
  wynik_codex FAIL "$ZGL"
  "$SHCTL" review run 20 >/dev/null
  run --separate-stderr "$SHCTL" review run 20 --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.werdykt, .wynik.ponownie' <<<"$output" | tr '\n' ' ')" = "FAIL true " ]
  [ "$(wc -l <"$CODEX_ATRAPA/calls" | tr -d ' ')" -eq 1 ]
  [ "$(komentarze 20 | grep -c '^## Review Codex')" -eq 1 ]
}

@test "review: Codex wstrzymany, PR czeka w status:review" {
  printf -- '- codex: limit do 18:00\n' >"$SH_DIR/limity.md"
  run --separate-stderr "$SHCTL" review run 20
  [ "$status" -eq 4 ]
  [[ "$(etykiety 12)" == *"status:review"* ]] || false
  [ ! -s "$CODEX_ATRAPA/calls" ]
}

@test "review: blad codex to kod 1, worktree i panel usuniete" {
  echo 3 >"$CODEX_ATRAPA/rc"
  run --separate-stderr "$SHCTL" review run 20
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"kodem 3"* ]] || false
  [ ! -e "$SH_DIR/wt/demo/review-12" ]
  [ "$(etykiety_paneli)" = "worker:demo:12" ]
  [ -z "$(komentarze 20)" ]
}

@test "review: plik env w PR to odmowa" {
  wt="$SH_DIR/wt/demo/12"
  printf 'X=1\n' >"$wt/.env.test"
  git -C "$wt" add -f .env.test
  git -C "$wt" commit -qm env
  git -C "$wt" push -q origin HEAD "HEAD:refs/pull/20/head" --force
  jq --arg s "$(git -C "$wt" rev-parse HEAD)" 'map(if .number == 20 then .headRefOid = $s else . end)' "$GH_ATRAPA/prs.json" >"$T/x" && mv "$T/x" "$GH_ATRAPA/prs.json"
  run --separate-stderr "$SHCTL" review run 20
  [ "$status" -eq 4 ]
  [ ! -s "$CODEX_ATRAPA/calls" ]
  [ ! -e "$SH_DIR/wt/demo/review-12" ]
}

@test "review --dry-run: bez etykiet, worktree i Codexa" {
  run --separate-stderr "$SHCTL" review run 20 --dry-run --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.nr <<<"$output")" = 12 ]
  [[ "$(etykiety 12)" == *"status:in-progress"* ]] || false
  [ ! -s "$CODEX_ATRAPA/calls" ]
}

@test "review: bledne uzycie i zamkniety PR" {
  run --separate-stderr "$SHCTL" review 20
  [ "$status" -eq 2 ]
  jq 'map(if .number == 20 then .state = "CLOSED" else . end)' "$GH_ATRAPA/prs.json" >"$T/x" && mv "$T/x" "$GH_ATRAPA/prs.json"
  run --separate-stderr "$SHCTL" review run 20
  [ "$status" -eq 4 ]
}

@test "review: drugie review tego samego PR w trakcie pierwszego to odmowa" {
  mkdir -p "$SH_DIR/stan/review/demo-pr20.lock"
  sleep 300 &
  echo $! >"$SH_DIR/stan/review/demo-pr20.lock/pid"
  run --separate-stderr "$SHCTL" review run 20
  kill %1 2>/dev/null || true
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"review PR #20 już trwa"* ]] || false
  [ ! -s "$CODEX_ATRAPA/calls" ]
}

@test "review: blokada po martwym procesie nie blokuje i znika po review" {
  mkdir -p "$SH_DIR/stan/review/demo-pr20.lock"
  echo 999999 >"$SH_DIR/stan/review/demo-pr20.lock/pid"
  run --separate-stderr "$SHCTL" review run 20 --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ ! -e "$SH_DIR/stan/review/demo-pr20.lock" ]
}
