#!/usr/bin/env bats
# shctl stage iter: iteracja i status etapu na main, bez zmian frontmattera na gałęzi stage/ETAP.
load helper-zadania

setup() {
  zadania_setup
  ZGL='[{"waga":"istotne","plik":"docs/08-qa/raport-M1.md","linia":3,"opis":"brak scenariusza"}]'
  "$SHCTL" stage start 08-qa >/dev/null
  "$SHCTL" stage review 08-qa >/dev/null
  git commit -qam "08-qa: review" && git push -q origin main
}

# PR etapu z nowym commitem na gałęzi stage/08-qa: pr_etapu NR_PR
pr_etapu() {
  git checkout -q -B stage/08-qa
  echo "raport $RANDOM" >>docs/08-qa/raport-M1.md
  git add -A && git commit -qm "08-qa: raport"
  git push -q -f origin HEAD "HEAD:refs/pull/$1/head"
  [ -f "$GH_ATRAPA/prs.json" ] || echo '[]' >"$GH_ATRAPA/prs.json"
  jq --arg r "$R" --argjson n "$1" --arg s "$(git rev-parse HEAD)" 'map(select(.number != $n)) + [{repo:$r, number:$n,
    title:"08-qa", state:"OPEN", headRefName:"stage/08-qa", headRefOid:$s, closingIssuesReferences:[],
    url:"https://github.com/\($r)/pull/\($n)", createdAt:"2026-11-01T10:00:00Z", comments:[], mergeable:"MERGEABLE",
    statusCheckRollup:[{status:"COMPLETED", conclusion:"SUCCESS"}]}]' "$GH_ATRAPA/prs.json" >"$T/x"
  mv "$T/x" "$GH_ATRAPA/prs.json"
  git checkout -q main
}

fail_review() { wynik_codex FAIL "$ZGL"; "$SHCTL" review run 30 >/dev/null; }

@test "stage iter: po FAIL iteracja 2 i in-progress na main, galaz bez zmian DoD" {
  pr_etapu 30
  fail_review
  run --separate-stderr "$SHCTL" stage iter 08-qa --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.iteracja, .wynik.eskalowano' <<<"$output" | tr '\n' ' ')" = "2 false " ]
  [ "$(fm docs/08-qa/DoD.md iteracja)" = 2 ]
  [ "$(fm docs/08-qa/DoD.md status)" = in-progress ]
  grep -qF '`08-qa`: iteracja 2 (FAIL review PR #30)' docs/status.md
  [ -z "$(git diff main stage/08-qa -- docs/08-qa/DoD.md | grep '^[-+]iteracja' || true)" ]
  # Powtórka dla tego samego review nie podbija licznika.
  run --separate-stderr "$SHCTL" stage iter 08-qa --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.iteracja, .wynik.zmiana' <<<"$output" | tr '\n' ' ')" = "2 false " ]
}

@test "stage iter: review run czyta iteracje z main, merge PR etapu bez konfliktu" {
  pr_etapu 30
  fail_review
  "$SHCTL" stage iter 08-qa >/dev/null
  "$SHCTL" stage review 08-qa >/dev/null
  git commit -qam "orkiestrator: 08-qa iteracja 2" && git push -q origin main
  pr_etapu 30
  wynik_codex PASS '[]'
  "$SHCTL" review run 30 >/dev/null
  grep -q 'Iteracja: 2' "$CODEX_ATRAPA/prompt"
  git merge -q --no-edit stage/08-qa
}

@test "stage iter: po FAIL w iteracji 3 eskalacja zamiast podbicia" {
  yq -i --front-matter=process '.iteracja = 3' docs/08-qa/DoD.md && git commit -qam iteracja
  pr_etapu 30
  fail_review
  run --separate-stderr "$SHCTL" stage iter 08-qa --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.eskalowano, .wynik.eskalacja' <<<"$output" | tr '\n' ' ')" = "true E-001 " ]
  [ "$(fm docs/08-qa/DoD.md iteracja)" = 3 ]
  [ "$(fm docs/08-qa/DoD.md status)" = escalated ]
}

@test "stage iter: PASS albo brak review to odmowa" {
  pr_etapu 30
  run --separate-stderr "$SHCTL" stage iter 08-qa
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"brak wyniku shctl review run"* ]] || false
  wynik_codex PASS '[]'
  "$SHCTL" review run 30 >/dev/null
  run --separate-stderr "$SHCTL" stage iter 08-qa
  [ "$status" -eq 4 ]
  [ "$(fm docs/08-qa/DoD.md iteracja)" = 0 ]
}

@test "stage iter: brak PR etapu to odmowa" {
  run --separate-stderr "$SHCTL" stage iter 08-qa
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"brak otwartego PR z gałęzi stage/08-qa"* ]] || false
}
