#!/usr/bin/env bats
# Format wyniku review z templates/review.md: shctl czyta komentarz pisany ręcznie (bez ukrytych danych).
load helper-zadania

setup() {
  zadania_setup
  zadanie_w_toku 12
  pr_workera 12 20
  HEAD20="$(jq -r '.[] | select(.number == 20) | .headRefOid' "$GH_ATRAPA/prs.json")"
}

# Komentarz do PR 20 z pliku.
skomentuj() {
  jq --rawfile b "$1" 'map(if .number == 20 then .comments += [{body: $b}] else . end)' "$GH_ATRAPA/prs.json" >"$T/x"
  mv "$T/x" "$GH_ATRAPA/prs.json"
}

przyklad() {
  awk '/<!-- przyklad:start -->/{w=1;next} /<!-- przyklad:end -->/{w=0} w' "$BATS_TEST_DIRNAME/../../../templates/review.md" |
    sed "s/0000000000000000000000000000000000000000/$HEAD20/" >"$T/kom.md"
}

@test "przyklad z templates/review.md: werdykt, zgloszenia, miejsca" {
  przyklad
  skomentuj "$T/kom.md"
  run --separate-stderr "$SHCTL" review run 20 --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ ! -s "$CODEX_ATRAPA/calls" ]
  [ "$(jq -r '.wynik.werdykt, .wynik.ponownie, (.wynik.zgloszenia | length), .wynik.blokujace' <<<"$output" | tr '\n' ' ')" = "FAIL true 3 2 " ]
  [ "$(jq -c '.wynik.zgloszenia[0] | [.waga, .plik, .linia]' <<<"$output")" = '["krytyczne","src/auth/login.ts",42]' ]
  [ "$(jq -c '.wynik.zgloszenia[1] | [.waga, .plik, .linia]' <<<"$output")" = '["istotne","src/auth/login.test.ts",0]' ]
  [ "$(jq -c '.wynik.zgloszenia[2] | [.waga, .plik, .opis]' <<<"$output")" = '["drobne","","nazwa `x` w `validate` mało czytelna."]' ]
  [[ "$(jq -r .wynik.podsumowanie <<<"$output")" == "Formularz działa"* ]] || false
  run --separate-stderr "$SHCTL" task iter 12 --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.iteracja <<<"$output")" = 2 ]
}

@test "reczne PASS z drobnymi: close merguje i przenosi drobne" {
  printf '## Review Codex: PASS\n\n<!-- shctl:review head=%s werdykt=PASS -->\nCommit `x`, model ręcznie, iteracja 1.\n\nW porządku.\n\n### Zgłoszenia\n\n- ⚪ drobne `src/a.ts:3`: literówka w komentarzu\n' "$HEAD20" >"$T/kom.md"
  skomentuj "$T/kom.md"
  run --separate-stderr "$SHCTL" task close 12 --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  grep -qF '| review PR #20 | literówka w komentarzu (`src/a.ts:3`) | otwarta |' docs/backlog-drobne.md
}

@test "werdykt liczony z wag: PASS w naglowku z 🟡 to FAIL" {
  printf '## Review Codex: PASS\n\n<!-- shctl:review head=%s werdykt=PASS -->\n\n### Zgłoszenia\n\n- 🟡 istotne: brak testu\nZwykły akapit, pomijany.\n' "$HEAD20" >"$T/kom.md"
  skomentuj "$T/kom.md"
  run --separate-stderr "$SHCTL" task close 12
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"jest: FAIL"* ]] || false
}

@test "Brak. to PASS bez zgloszen" {
  printf '## Review Codex: PASS\n\n<!-- shctl:review head=%s werdykt=PASS -->\n\nOK.\n\n### Zgłoszenia\n\nBrak.\n' "$HEAD20" >"$T/kom.md"
  skomentuj "$T/kom.md"
  run --separate-stderr "$SHCTL" review run 20 --json
  [ "$(jq -r '.wynik.werdykt, (.wynik.zgloszenia | length)' <<<"$output" | tr '\n' ' ')" = "PASS 0 " ]
}

@test "komentarz z review run bez ukrytych danych czyta sie tak samo" {
  wynik_codex FAIL '[{"waga":"istotne","plik":"src/a.ts","linia":4,"opis":"brak walidacji"},{"waga":"drobne","plik":"","linia":0,"opis":"nazwa"}]'
  run --separate-stderr "$SHCTL" review run 20 --json
  przed="$(jq -c '.wynik | {werdykt, zgloszenia, podsumowanie}' <<<"$output")"
  jq 'map(if .number == 20 then .comments |= map(.body |= (split("\n") | map(select(startswith("<!-- shctl:review-dane") | not)) | join("\n"))) else . end)' \
    "$GH_ATRAPA/prs.json" >"$T/x" && mv "$T/x" "$GH_ATRAPA/prs.json"
  ! komentarze 20 | grep -q 'review-dane' || false
  run --separate-stderr "$SHCTL" review run 20 --json
  [ "$(jq -r .wynik.ponownie <<<"$output")" = true ]
  [ "$(jq -c '.wynik | {werdykt, zgloszenia, podsumowanie}' <<<"$output")" = "$przed" ]
}
