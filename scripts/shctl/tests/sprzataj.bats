#!/usr/bin/env bats
# shctl sprzataj: worktree w wt-system/ i wt/ oraz lokalne gałęzie usuwane tylko po PR MERGED albo CLOSED.
load helper-zadania

setup() {
  zadania_setup
  SYS="$SH_DIR/sh-system"
  git clone -q https://github.com/test-owner/sh-system.git "$SYS"
  mkdir -p "$SH_DIR/wt-system" "$SH_DIR/wt/demo"
  [ -f "$GH_ATRAPA/prs.json" ] || echo "[]" >"$GH_ATRAPA/prs.json"
}

# pr_atrapa REPO GALAZ STAN [SHA]
pr_atrapa() {
  local n
  n=$(($(cat "$GH_ATRAPA/licznik" 2>/dev/null || echo 0) + 1))
  echo "$n" >"$GH_ATRAPA/licznik"
  jq --arg r "$1" --arg b "$2" --arg s "$3" --arg o "${4:-}" --argjson n "$n" \
    '. + [{repo:$r, number:$n, title:"x", state:$s, headRefName:$b, headRefOid:$o, closingIssuesReferences:[], comments:[]}]' \
    "$GH_ATRAPA/prs.json" >"$T/p.json" && mv "$T/p.json" "$GH_ATRAPA/prs.json"
}

# worktree REPO KATALOG GALAZ: gałąź z jednym commitem, wypchnięta.
worktree() {
  git -C "$1" worktree add -q -b "$3" "$2" origin/main
  echo "$3" >"$2/plik-$(basename "$3").txt"
  git -C "$2" add -A && git -C "$2" commit -qm "$3"
}

sha() { git -C "$1" rev-parse "refs/heads/$2"; }
sprzataj() { run --separate-stderr "$SHCTL" sprzataj --json "$@"; }

@test "sprzataj: MERGED i CLOSED usuniete, otwarte, brudne i bez PR zostaja" {
  worktree "$SYS" "$SH_DIR/wt-system/a" sh-lite-a
  pr_atrapa test-owner/sh-system sh-lite-a MERGED "$(sha "$SYS" sh-lite-a)"
  worktree "$SYS" "$SH_DIR/wt-system/b" sh-lite-b
  pr_atrapa test-owner/sh-system sh-lite-b OPEN "$(sha "$SYS" sh-lite-b)"
  worktree "$SYS" "$SH_DIR/wt-system/c" sh-lite-c
  pr_atrapa test-owner/sh-system sh-lite-c MERGED "$(sha "$SYS" sh-lite-c)"
  echo brud >>"$SH_DIR/wt-system/c/plik-sh-lite-c.txt"
  worktree "$P" "$SH_DIR/wt/demo/12" task/12-x
  pr_atrapa test-owner/demo task/12-x CLOSED "$(sha "$P" task/12-x)"
  worktree "$P" "$SH_DIR/wt/demo/13" task/13-y
  # Gałąź bez worktree po squash merge i gałąź z commitem spoza PR.
  git -C "$P" branch stage/04-plan origin/main
  pr_atrapa test-owner/demo stage/04-plan MERGED "$(sha "$P" stage/04-plan)"
  git -C "$P" branch task/14-z origin/main
  pr_atrapa test-owner/demo task/14-z MERGED "$(git -C "$P" rev-parse origin/main~0)"
  git -C "$P" commit-tree -p task/14-z -m lokalny "$(git -C "$P" rev-parse 'task/14-z^{tree}')" >"$T/sha"
  git -C "$P" update-ref refs/heads/task/14-z "$(cat "$T/sha")"

  sprzataj
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ ! -e "$SH_DIR/wt-system/a" ] && [ ! -e "$SH_DIR/wt/demo/12" ]
  [ -d "$SH_DIR/wt-system/b" ] && [ -d "$SH_DIR/wt-system/c" ] && [ -d "$SH_DIR/wt/demo/13" ]
  ! git -C "$SYS" rev-parse -q --verify refs/heads/sh-lite-a || false
  ! git -C "$P" rev-parse -q --verify refs/heads/task/12-x || false
  ! git -C "$P" rev-parse -q --verify refs/heads/stage/04-plan || false
  git -C "$P" rev-parse -q --verify refs/heads/task/14-z
  git -C "$SYS" rev-parse -q --verify refs/heads/sh-lite-c
  p="$(jq -r '.wynik.pominiete[] | "\(.co | split("/") | last)=\(.powod)"' <<<"$output" | sort | paste -sd ';' -)"
  [[ "$p" == *"b=PR gałęzi sh-lite-b: OPEN"* ]] || false
  [[ "$p" == *"c=niezacommitowane zmiany"* ]] || false
  [[ "$p" == *"13=PR gałęzi task/13-y: brak"* ]] || false
  [[ "$p" == *"14-z=lokalne commity spoza PR"* ]] || false
  [ "$(git -C "$P" symbolic-ref --short HEAD)" = main ]
}

@test "sprzataj: repo bez origin (sh-test) pominiete z ostrzezeniem, reszta posprzatana" {
  git init -q -b main "$SH_DIR/projekty/sh-test"
  git -C "$SH_DIR/projekty/sh-test" commit -q --allow-empty -m start
  git -C "$SH_DIR/projekty/sh-test" branch task/1-x
  git -C "$SH_DIR/projekty/sh-test" worktree add -q "$SH_DIR/wt/sh-test/1" task/1-x
  worktree "$SYS" "$SH_DIR/wt-system/a" sh-lite-a
  pr_atrapa test-owner/sh-system sh-lite-a MERGED "$(sha "$SYS" sh-lite-a)"

  sprzataj
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ ! -e "$SH_DIR/wt-system/a" ]
  ! git -C "$SYS" rev-parse -q --verify refs/heads/sh-lite-a || false
  [ -d "$SH_DIR/wt/sh-test/1" ]
  git -C "$SH_DIR/projekty/sh-test" rev-parse -q --verify refs/heads/task/1-x
  [ "$(jq -r '[.wynik.pominiete[] | select(.powod == "repo bez origin")] | length' <<<"$output")" -eq 2 ]
  run --separate-stderr "$SHCTL" sprzataj --dry-run
  [ "$status" -eq 0 ]
  [[ "$output$stderr" == *"pominięto $SH_DIR/projekty/sh-test: repo bez origin"* ]] || false
}

@test "sprzataj --dry-run niczego nie usuwa" {
  worktree "$SYS" "$SH_DIR/wt-system/a" sh-lite-a
  pr_atrapa test-owner/sh-system sh-lite-a MERGED "$(sha "$SYS" sh-lite-a)"
  sprzataj --dry-run
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.worktree | length' <<<"$output")" -eq 1 ]
  [ -d "$SH_DIR/wt-system/a" ]
  git -C "$SYS" rev-parse -q --verify refs/heads/sh-lite-a
}
