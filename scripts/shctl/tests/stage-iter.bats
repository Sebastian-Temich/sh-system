#!/usr/bin/env bats
# shctl stage iter: iteracja i status etapu na main, bez zmian frontmattera na gałęzi stage/ETAP.
load helper-zadania

setup() {
  zadania_setup
  ZGL='[{"waga":"istotne","plik":"docs/wydanie/notatka.md","linia":3,"opis":"brak scenariusza"}]'
  "$SHCTL" stage start wydanie >/dev/null
  "$SHCTL" stage review wydanie >/dev/null
  git commit -qam "wydanie: review" && git push -q origin main
}

# PR etapu z nowym commitem na gałęzi stage/wydanie: pr_etapu NR_PR
pr_etapu() {
  git checkout -q -B stage/wydanie
  echo "raport $RANDOM" >>docs/wydanie/notatka.md
  git add -A && git commit -qm "wydanie: raport"
  git push -q -f origin HEAD "HEAD:refs/pull/$1/head"
  [ -f "$GH_ATRAPA/prs.json" ] || echo '[]' >"$GH_ATRAPA/prs.json"
  jq --arg r "$R" --argjson n "$1" --arg s "$(git rev-parse HEAD)" 'map(select(.number != $n)) + [{repo:$r, number:$n,
    title:"wydanie", state:"OPEN", headRefName:"stage/wydanie", headRefOid:$s, closingIssuesReferences:[],
    url:"https://github.com/\($r)/pull/\($n)", createdAt:"2026-11-01T10:00:00Z", comments:[], mergeable:"MERGEABLE",
    statusCheckRollup:[{status:"COMPLETED", conclusion:"SUCCESS"}]}]' "$GH_ATRAPA/prs.json" >"$T/x"
  mv "$T/x" "$GH_ATRAPA/prs.json"
  git checkout -q main
}

fail_review() { wynik_codex FAIL "$ZGL"; "$SHCTL" review run 30 >/dev/null; }

@test "stage iter: po FAIL iteracja 2 i in-progress na main, galaz bez zmian DoD" {
  pr_etapu 30
  fail_review
  run --separate-stderr "$SHCTL" stage iter wydanie --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.iteracja, .wynik.eskalowano' <<<"$output" | tr '\n' ' ')" = "2 false " ]
  [ "$(fm docs/wydanie/DoD.md iteracja)" = 2 ]
  [ "$(fm docs/wydanie/DoD.md status)" = in-progress ]
  grep -qF '`wydanie`: iteracja 2 (FAIL review PR #30)' docs/historia.md
  [ -z "$(git diff main stage/wydanie -- docs/wydanie/DoD.md | grep '^[-+]iteracja' || true)" ]
  # Powtórka dla tego samego review nie podbija licznika.
  run --separate-stderr "$SHCTL" stage iter wydanie --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.iteracja, .wynik.zmiana' <<<"$output" | tr '\n' ' ')" = "2 false " ]
}

@test "stage iter: review run czyta iteracje z main, merge PR etapu bez konfliktu" {
  pr_etapu 30
  fail_review
  "$SHCTL" stage iter wydanie >/dev/null
  "$SHCTL" stage review wydanie >/dev/null
  git commit -qam "orkiestrator: wydanie iteracja 2" && git push -q origin main
  pr_etapu 30
  wynik_codex PASS '[]'
  "$SHCTL" review run 30 >/dev/null
  grep -q 'Iteracja: 2' "$CODEX_ATRAPA/prompt"
  git merge -q --no-edit stage/wydanie
}

@test "stage iter: po FAIL w iteracji 3 eskalacja zamiast podbicia" {
  yq -i --front-matter=process '.iteracja = 3' docs/wydanie/DoD.md && git commit -qam iteracja
  pr_etapu 30
  fail_review
  run --separate-stderr "$SHCTL" stage iter wydanie --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.eskalowano, .wynik.eskalacja' <<<"$output" | tr '\n' ' ')" = "true E-001 " ]
  [ "$(fm docs/wydanie/DoD.md iteracja)" = 3 ]
  [ "$(fm docs/wydanie/DoD.md status)" = escalated ]
}

@test "stage iter: PASS albo brak review to odmowa" {
  pr_etapu 30
  run --separate-stderr "$SHCTL" stage iter wydanie
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"brak wyniku shctl review run"* ]] || false
  wynik_codex PASS '[]'
  "$SHCTL" review run 30 >/dev/null
  run --separate-stderr "$SHCTL" stage iter wydanie
  [ "$status" -eq 4 ]
  [ "$(fm docs/wydanie/DoD.md iteracja)" = 0 ]
}

@test "stage iter: brak PR etapu to odmowa" {
  run --separate-stderr "$SHCTL" stage iter wydanie
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"brak otwartego PR z gałęzi stage/wydanie"* ]] || false
}

# SH-lite F1: dokumenty etapu najwyżej z jedną iteracją poprawek, raport QA bez review etapu.
@test "stage iter: etap dokumentowy po FAIL w iteracji 2 eskaluje (bez iteracji 3)" {
  "$SHCTL" stage start 06-zadania >/dev/null
  "$SHCTL" stage review 06-zadania >/dev/null
  yq -i --front-matter=process '.iteracja = 2' docs/06-zadania/DoD.md
  git commit -qam "06-zadania: review, iteracja 2" && git push -q origin main
  git checkout -q -B stage/06-zadania
  echo "zadania $RANDOM" >>docs/06-zadania/notatka.md
  git add -A && git commit -qm "06-zadania: poprawki"
  git push -q -f origin HEAD "HEAD:refs/pull/31/head"
  [ -f "$GH_ATRAPA/prs.json" ] || echo '[]' >"$GH_ATRAPA/prs.json"
  jq --arg r "$R" --arg s "$(git rev-parse HEAD)" '. + [{repo:$r, number:31, title:"06-zadania", state:"OPEN",
    headRefName:"stage/06-zadania", headRefOid:$s, closingIssuesReferences:[], url:"https://github.com/\($r)/pull/31",
    createdAt:"2026-11-01T10:00:00Z", comments:[], mergeable:"MERGEABLE",
    statusCheckRollup:[{status:"COMPLETED", conclusion:"SUCCESS"}]}]' "$GH_ATRAPA/prs.json" >"$T/x"
  mv "$T/x" "$GH_ATRAPA/prs.json"
  git checkout -q main
  wynik_codex FAIL '[{"waga":"krytyczne","plik":"docs/06-zadania/zadania.yaml","linia":1,"opis":"sekret"}]'
  "$SHCTL" review run 31 >/dev/null
  run --separate-stderr "$SHCTL" stage iter 06-zadania --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.eskalowano, .wynik.iteracja' <<<"$output" | tr '\n' ' ')" = "true 2 " ]
  [ "$(fm docs/06-zadania/DoD.md status)" = escalated ]
}

@test "stage iter i review run: 08-qa bez review etapu to odmowa" {
  run --separate-stderr "$SHCTL" stage iter 08-qa
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"raport QA nie ma review etapu"* ]] || false
}
