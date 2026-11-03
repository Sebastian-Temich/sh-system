#!/usr/bin/env bats
# shctl checkpoint: powiadomienie o akceptacji po PASS review, jedno na commit PR.
load helper-zadania

setup() { zadania_setup; }

# PR w atrapie: pr_atrapa NR GAŁĄŹ HEAD [ZAMYKANE_ISSUE]
pr_atrapa() {
  [ -f "$GH_ATRAPA/prs.json" ] || echo "[]" >"$GH_ATRAPA/prs.json"
  jq --arg r "$R" --argjson n "$1" --arg b "$2" --arg h "$3" --arg i "${4:-}" \
    '. + [{repo:$r, number:$n, title:"PR \($n)", state:"OPEN", headRefName:$b, headRefOid:$h,
      closingIssuesReferences:(if $i == "" then [] else [{number:($i | tonumber)}] end),
      url:"https://github.com/\($r)/pull/\($n)", createdAt:"2026-11-01T10:00:00Z", comments:[],
      statusCheckRollup:[{status:"COMPLETED", conclusion:"SUCCESS"}]}]' "$GH_ATRAPA/prs.json" >"$T/p.json"
  mv "$T/p.json" "$GH_ATRAPA/prs.json"
}

# Komentarz review w formacie templates/review.md: review NR HEAD PASS|FAIL
review() {
  local b
  b="## Review Codex: $3

<!-- shctl:review head=$2 werdykt=$3 -->
Commit \`${2:0:7}\`, iteracja 1.

Podsumowanie.

### Zgłoszenia

"
  if [ "$3" = FAIL ]; then b="$b- 🟡 istotne \`docs/a.md\`: brak sekcji"; else b="${b}Brak."; fi
  jq --argjson n "$1" --arg b "$b" 'map(if .number == $n then .comments += [{body:$b}] else . end)' \
    "$GH_ATRAPA/prs.json" >"$T/p.json"
  mv "$T/p.json" "$GH_ATRAPA/prs.json"
}

@test "etap po PASS: powiadomienie high z linkiem do PR" {
  pr_atrapa 5 stage/00-intake aaaa111
  review 5 aaaa111 PASS
  run --separate-stderr "$SHCTL" checkpoint 00-intake --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.pr <<<"$output")" = 5 ]
  [ "$(jq -r .wynik.powiadomiono <<<"$output")" = true ]
  grep -qx 'high Czeka na Twoją akceptację: demo / 00-intake Specyfikacja, PR #5 https://github.com/test-owner/demo/pull/5 white_check_mark' "$T/notified"
}

@test "opis trafia do tresci" {
  pr_atrapa 6 stage/04-architektura bbbb222
  review 6 bbbb222 PASS
  run "$SHCTL" checkpoint 04-architektura --opis "4 kamienie, Resend darmowy"
  [ "$status" -eq 0 ]
  grep -q '^high Czeka na Twoją akceptację: demo / 04-architektura Architektura i plan, PR #6. 4 kamienie, Resend darmowy ' "$T/notified"
}

@test "powtorka dla tego samego commita nie wysyla drugi raz, nowy commit wysyla" {
  pr_atrapa 7 stage/wydanie cccc333
  review 7 cccc333 PASS
  "$SHCTL" checkpoint wydanie
  run --separate-stderr "$SHCTL" checkpoint wydanie --json
  [ "$(jq -r .wynik.ponownie <<<"$output")" = true ]
  [ "$(wc -l <"$T/notified" | tr -d ' ')" -eq 1 ]
  jq 'map(if .number == 7 then .headRefOid = "dddd444" else . end)' "$GH_ATRAPA/prs.json" >"$T/p.json"
  mv "$T/p.json" "$GH_ATRAPA/prs.json"
  review 7 dddd444 PASS
  run "$SHCTL" checkpoint wydanie
  [ "$status" -eq 0 ]
  [ "$(wc -l <"$T/notified" | tr -d ' ')" -eq 2 ]
}

@test "odbior zadania S: PR z zadania" {
  issue 20 "Link w stopce" "status:review,tryb:S"
  pr_atrapa 21 task/20-link-w-stopce eeee555 20
  review 21 eeee555 PASS
  run --separate-stderr "$SHCTL" checkpoint "#20" --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.cel <<<"$output")" = "#20" ]
  grep -q '^high Czeka na Twoją akceptację: demo / #20 Odbiór zadania #20 (tryb S), PR #21 ' "$T/notified"
}

@test "bez PASS dla biezacego commita: odmowa bez powiadomienia" {
  pr_atrapa 8 stage/00-intake ffff666
  review 8 ffff666 FAIL
  run --separate-stderr "$SHCTL" checkpoint 00-intake
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"nie ma PASS"* ]] || false
  pr_atrapa 9 stage/04-architektura 1111aaa
  review 9 0000old PASS
  run --separate-stderr "$SHCTL" checkpoint 04-architektura
  [ "$status" -eq 4 ]
  [ ! -s "$T/notified" ]
}

@test "brak PR i etap bez checkpointu" {
  run --separate-stderr "$SHCTL" checkpoint 00-intake
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"brak otwartego PR z gałęzi stage/00-intake"* ]] || false
  run --separate-stderr "$SHCTL" checkpoint 06-zadania
  [ "$status" -eq 2 ]
}

@test "nieudane powiadomienie: kod 1, ponowienie wysyla" {
  pr_atrapa 5 stage/00-intake aaaa111
  review 5 aaaa111 PASS
  touch "$T/notify-fail"
  run --separate-stderr "$SHCTL" checkpoint 00-intake
  [ "$status" -eq 1 ]
  rm "$T/notify-fail"
  run "$SHCTL" checkpoint 00-intake
  [ "$status" -eq 0 ]
  [ "$(wc -l <"$T/notified" | tr -d ' ')" -eq 2 ]
}

@test "dry-run nie powiadamia i nie zapisuje stanu" {
  pr_atrapa 5 stage/00-intake aaaa111
  review 5 aaaa111 PASS
  run "$SHCTL" checkpoint 00-intake --dry-run
  [ "$status" -eq 0 ]
  [ ! -s "$T/notified" ]
  [ ! -e "$SH_DIR/stan/checkpointy/demo" ]
}
