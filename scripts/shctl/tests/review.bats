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
  grep -q 'Prompt tymczasowy' "$CODEX_ATRAPA/prompt"
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
