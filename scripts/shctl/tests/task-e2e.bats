#!/usr/bin/env bats
# Pełny cykl zadania na prawdziwym GitHubie. Wyłącznie po wyraźnej zgodzie właściciela w danej
# rozmowie (docs/serwer.md, „Praca nad systemem”). Uruchomienie:
#   SHCTL_E2E=1 bats scripts/shctl/tests/task-e2e.bats
# Prawdziwe: repo z szablonu, issue, milestone, PR, CI, merge i Codex (review). Atrapy: herdr (wykonuje
# komendy od razu) i claude, a pracę workera wykonuje test. SHCTL_E2E_CODEX=atrapa zastępuje Codexa.
# Zakłada prywatne repo sh-test-RRRRMMDD-HHMM i przed utworzeniem dopisuje je do
# ~/sh/stan/do-usuniecia.md. Propozycje dla systemu są puste, więc test nie otwiera PR w sh-system.
bats_require_minimum_version 1.5.0

setup() {
  [ "${SHCTL_E2E:-}" = 1 ] || skip "wymaga SHCTL_E2E=1 i zgody właściciela"
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  SHCTL="$REPO/scripts/shctl/shctl"
  T="$BATS_TEST_TMPDIR"
  LISTA="$HOME/sh/stan/do-usuniecia.md"
  NAZWA="sh-test-$(date +%Y%m%d-%H%M)"
  SLUG="${SH_GH_OWNER:-Sebastian-Temich}/$NAZWA"
  export SH_DIR="$T/sh" SH_NOTIFY_CMD=/usr/bin/true SH_OBSIDIAN_DIR="$T/Obsidian" SH_SYSTEM_DIR="$T/brak-sh-system"
  export SH_CLAUDE_JSON="$T/claude.json"
  export HERDR_ATRAPA="$T/herdr" CLAUDE_ATRAPA="$T/claude" CODEX_ATRAPA="$T/codex"
  mkdir -p "$SH_DIR" "$T/bin" "$HERDR_ATRAPA" "$CLAUDE_ATRAPA" "$CODEX_ATRAPA"
  cp "$HOME/sh/porty.md" "$SH_DIR/porty.md"
  cp "$BATS_TEST_DIRNAME/atrapy/herdr" "$BATS_TEST_DIRNAME/atrapy/claude" "$T/bin/"
  if [ "${SHCTL_E2E_CODEX:-}" = atrapa ]; then
    cp "$BATS_TEST_DIRNAME/atrapy/codex" "$T/bin/"
    echo '{"werdykt":"PASS","podsumowanie":"atrapa","zgloszenia":[]}' >"$CODEX_ATRAPA/wynik.json"
  fi
  export PATH="$T/bin:$PATH"
}

dopisz_do_usuniecia() {
  mkdir -p "$(dirname "$LISTA")"
  [ -f "$LISTA" ] || printf '# Repo do usunięcia\n\n| Nazwa | Data | Po co |\n|---|---|---|\n' >"$LISTA"
  printf '| %s | %s | test task-e2e |\n' "$NAZWA" "$(date +%F)" >>"$LISTA"
}

czekaj_na_ci() {
  local i stan
  for i in $(seq 1 90); do
    stan="$(gh pr view "$1" --repo "$SLUG" --json statusCheckRollup --jq '
      (.statusCheckRollup // []) as $c
      | if ($c | length) == 0 then "brak"
        elif any($c[]; (.conclusion // .state // "") | IN("FAILURE", "ERROR", "CANCELLED", "TIMED_OUT")) then "fail"
        elif any($c[]; (.status // "") != "COMPLETED" and (.state // "") != "SUCCESS") then "pending"
        else "pass" end')"
    case "$stan" in pass) return 0 ;; fail) echo "CI: fail" >&2; return 1 ;; esac
    sleep 10
  done
  echo "CI: brak wyniku po 15 min ($stan)" >&2
  return 1
}

@test "task: create, dispatch, review run, close na GitHubie" {
  ! gh repo view "$SLUG" --json name >/dev/null 2>&1 || false
  dopisz_do_usuniecia
  run --separate-stderr "$SHCTL" new-project "$NAZWA" --opis "Test shctl task e2e" --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  P="$SH_DIR/projekty/$NAZWA"

  cat >"$T/zadania.yaml" <<'YAML'
zadania:
  - id: E1
    tytul: Plik powitania
    cel: Dodaj plik docs/powitanie.md z jednym zdaniem powitania.
    kryteria:
      - plik docs/powitanie.md istnieje i zawiera słowo Witaj
    pliki: [docs/powitanie.md]
    testy: grep -q Witaj docs/powitanie.md
    typ: docs
    milestone: E2E
YAML
  run --separate-stderr "$SHCTL" task create --projekt "$NAZWA" --plik "$T/zadania.yaml" --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  NR="$(jq -r .wynik.mapa.E1 <<<"$output")"
  [ "$(gh issue view "$NR" --repo "$SLUG" --json milestone --jq .milestone.title)" = E2E ]

  run --separate-stderr "$SHCTL" task dispatch "$NR" --projekt "$NAZWA" --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  WT="$(jq -r .wynik.worktree <<<"$output")"
  BR="$(jq -r .wynik.galaz <<<"$output")"
  grep -q "skillem sh-worker" "$CLAUDE_ATRAPA/calls"
  [ "$WT" = "$SH_DIR/wt/$NAZWA/$NR" ]
  [ "$(jq -r --arg p "$(cd "$P" && pwd -P)" '.projects[$p].hasTrustDialogAccepted' "$SH_CLAUDE_JSON")" = true ]
  [ "$(gh issue view "$NR" --repo "$SLUG" --json labels --jq '[.labels[].name] | index("status:in-progress") != null')" = true ]

  # Praca workera.
  printf 'Witaj w projekcie testowym.\n' >"$WT/docs/powitanie.md"
  mkdir -p "$WT/docs/07-realizacja"
  printf '# Raport T-%s: Plik powitania\n\nIssue: #%s\n\n## Co zrobiono\n\nDodano docs/powitanie.md.\n\n## Testy\n\n`grep -q Witaj docs/powitanie.md`\n\n## Decyzje\n\n- Treść powitania → jedno zdanie\n\n## Drobne uwagi\n\nBrak.\n\n## Propozycje dla systemu\n\nBrak.\n' \
    "$NR" "$NR" >"$WT/docs/07-realizacja/T-$NR.md"
  git -C "$WT" add -A
  git -C "$WT" commit -qm "#$NR: dodaj plik powitania"
  git -C "$WT" push -q -u origin "$BR"
  PR="$(gh pr create --repo "$SLUG" --head "$BR" --base main --title "#$NR: plik powitania" --body "Closes #$NR" | sed 's#.*/##')"
  czekaj_na_ci "$PR"

  run --separate-stderr "$SHCTL" review run "$PR" --projekt "$NAZWA" --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  WERDYKT="$(jq -r .wynik.werdykt <<<"$output")"
  gh pr view "$PR" --repo "$SLUG" --json comments --jq '.comments[].body' | grep -q "^## Review Codex: $WERDYKT"
  [ ! -e "$SH_DIR/wt/$NAZWA/review-$NR" ]
  if [ "$WERDYKT" != PASS ]; then
    run --separate-stderr "$SHCTL" task close "$NR" --projekt "$NAZWA"
    [ "$status" -eq 4 ]
    echo "Codex dał FAIL dla trywialnej zmiany; close poprawnie odmówił" >&2
    false
  fi

  run --separate-stderr "$SHCTL" task close "$NR" --projekt "$NAZWA" --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(gh pr view "$PR" --repo "$SLUG" --json state --jq .state)" = MERGED ]
  [ "$(gh issue view "$NR" --repo "$SLUG" --json state --jq .state)" = CLOSED ]
  [ -f "$P/docs/powitanie.md" ]
  grep -qF "| T-$NR | Treść powitania | jedno zdanie |" "$P/docs/decyzje.md"
  grep -q "^| #$NR Plik powitania " "$P/docs/metryki.md"
  grep -qF -- "- #$NR: Plik powitania (PR #$PR)" "$P/CHANGELOG.md"
  [ ! -e "$WT" ]

  run --separate-stderr "$SHCTL" task close "$NR" --projekt "$NAZWA" --json
  [ "$status" -eq 0 ]
}
