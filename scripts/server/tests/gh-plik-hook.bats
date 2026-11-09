#!/usr/bin/env bats
# Hook PreToolUse gh-plik-hook.sh: pliki tresci gh (--body-file, -F, --notes-file) tylko z /Users/Shared/sh.

bats_require_minimum_version 1.5.0

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  T="$BATS_TEST_TMPDIR"
  mkdir -p "$T/sh/wt/p/12" "$T/dom/Documents"
  echo x >"$T/sh/wt/p/12/opis.md"
  echo tajne >"$T/dom/Documents/a.md"
  ln -s "$T/dom/Documents/a.md" "$T/sh/wt/p/12/link.md"
}

# gh_cmd KOMENDA [CWD]
gh_cmd() {
  jq -nc --arg c "$1" --arg d "${2:-$T/sh/wt/p/12}" '{tool_name:"Bash", tool_input:{command:$c}, cwd:$d, session_id:"s"}' |
    HOME="$T/dom" SH_DIR="$T/sh" "$REPO/scripts/server/gh-plik-hook.sh"
}
decyzja() { if [ -z "$output" ]; then echo brak; else printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision // "brak"'; fi; }

@test "pliki spoza /Users/Shared/sh: deny w kazdej formie i komendzie" {
  D="$T/dom/Documents/a.md"
  for c in "gh pr create --title t --body-file $D" "gh pr create --body-file=$D" "gh pr create -F $D" \
    "gh pr edit 3 --body-file '$D'" "gh pr comment 3 --body-file \"$D\"" "gh issue create -t x -F$D" \
    "gh issue comment 3 --body-file ~/Documents/a.md" "gh release create v1 --notes-file $D" \
    "gh release create v1 -F ../../../../dom/Documents/a.md" "gh pr comment 3 --body-file link.md" \
    "git status && gh pr comment 3 --body-file $D" "GH_PAGER= gh pr comment 3 --body-file $D" \
    "/usr/local/bin/gh pr comment 3 --body-file $D" "gh pr comment 3 --body-file /tmp/x.md"; do
    run gh_cmd "$c"
    [ "$status" -eq 0 ]
    [ "$(decyzja)" = deny ] || { echo "przeszlo: $c"; false; }
  done
}

@test "pliki w /Users/Shared/sh, stdin i komendy bez pliku: bez decyzji" {
  for c in "gh pr create --title t --body-file opis.md" "gh pr create --body-file $T/sh/wt/p/12/opis.md" \
    "gh pr comment 3 --body-file -" "gh pr view 3 --json body" "gh pr create --title t --body tresc" \
    "gh api repos/a/b -F x=1" "ls -F /tmp" "git log --oneline"; do
    run gh_cmd "$c"
    [ "$status" -eq 0 ]
    [ "$(decyzja)" = brak ] || { echo "zablokowane: $c => $output"; false; }
  done
}

@test "fail-closed: bledny JSON to kod 2" {
  run bash -c "printf 'nie json' | '$REPO/scripts/server/gh-plik-hook.sh'"
  [ "$status" -eq 2 ]
}
