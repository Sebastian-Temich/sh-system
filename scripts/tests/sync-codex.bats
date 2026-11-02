#!/usr/bin/env bats
# scripts/sync-codex.sh: prompt Codexa generowany ze skilla sh-review.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  SYNC="$REPO/scripts/sync-codex.sh"
  T="$(mktemp -d)"
  mkdir -p "$T/plugin/skills/sh-review"
  printf -- '---\nname: sh-review\ndescription: x\n---\n\n# sh-review\n\n## Rola i granice\n\nTreść.\n' \
    >"$T/plugin/skills/sh-review/SKILL.md"
}

teardown() { rm -rf "$T"; }

@test "prompt w repo jest aktualny wzgledem skilla" {
  run "$SYNC" --check "$REPO"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "generuje prompt: wstep, tresc bez frontmattera, powtorka bez zmian" {
  run "$SYNC" "$T"
  [ "$status" -eq 0 ]
  head -1 "$T/codex/sh-review.md" | grep -q 'Wygenerowane przez scripts/sync-codex.sh'
  grep -q 'codex/sh-review.schema.json' "$T/codex/sh-review.md"
  grep -qx '# sh-review' "$T/codex/sh-review.md"
  grep -qx 'Treść.' "$T/codex/sh-review.md"
  ! grep -q '^name: sh-review' "$T/codex/sh-review.md"
  cp "$T/codex/sh-review.md" "$T/przed"
  "$SYNC" "$T" >/dev/null
  cmp -s "$T/przed" "$T/codex/sh-review.md"
  run "$SYNC" --check "$T"
  [ "$status" -eq 0 ]
}

@test "--check wykrywa zmiane skilla i brak promptu" {
  run "$SYNC" --check "$T"
  [ "$status" -eq 1 ]
  "$SYNC" "$T" >/dev/null
  printf 'Nowa linia.\n' >>"$T/plugin/skills/sh-review/SKILL.md"
  run "$SYNC" --check "$T"
  [ "$status" -eq 1 ]
  [[ "$output" == *"NIEAKTUALNE: codex/sh-review.md"* ]] || false
}

@test "bledne uzycie i brak skilla" {
  run "$SYNC" --zla
  [ "$status" -eq 2 ]
  rm "$T/plugin/skills/sh-review/SKILL.md"
  run "$SYNC" "$T"
  [ "$status" -eq 3 ]
}
