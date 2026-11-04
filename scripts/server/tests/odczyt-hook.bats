#!/usr/bin/env bats
# Hook PreToolUse odczyt-hook.sh: odczyt tylko w projekcie sesji, konfiguracji Claude i tmp Claude Code.

bats_require_minimum_version 1.5.0

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  T="$(cd "$BATS_TEST_TMPDIR" && pwd -P)"
  mkdir -p "$T/sh/wt/p/11/src" "$T/sh/wt/p/12" "$T/sh/projekty/p" "$T/sh/sh-system/plugin/skills" \
    "$T/dom/.claude/skills" "$T/dom/.ssh" "$T/obcy"
  ln -s "$T/obcy" "$T/sh/wt/p/11/link-obcy"
  export SH_DIR="$T/sh" HOME="$T/dom"
}

# odczyt PROJEKT NARZEDZIE JSON_WEJSCIA_NARZEDZIA [CWD]
odczyt() {
  jq -nc --arg n "$2" --argjson i "$3" --arg c "${4:-$1}" '{tool_name:$n, tool_input:$i, cwd:$c, session_id:"s-123"}' |
    CLAUDE_PROJECT_DIR="$1" "$REPO/scripts/server/odczyt-hook.sh"
}
decyzja() { printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision // "brak"'; }

@test "worker: wlasny worktree bez decyzji (zwykle reguly)" {
  W="$T/sh/wt/p/11"
  run odczyt "$W" Read "{\"file_path\":\"$W/src/a.ts\"}"
  [ "$status" -eq 0 ] && [ -z "$output" ]
  run odczyt "$W" Read '{"file_path":"src/a.ts"}' "$W/src"
  [ -z "$output" ]
  run odczyt "$W" Grep '{"pattern":"x"}'
  [ -z "$output" ]
  run odczyt "$W" Glob '{"pattern":"**/*.ts"}'
  [ -z "$output" ]
}

@test "worker: inny worktree, klon projektu i SH_DIR to deny" {
  W="$T/sh/wt/p/11"
  for p in "$T/sh/wt/p/12/a.ts" "$T/sh/projekty/p/docs/x.md" "$T/sh/stan/p.json" "$T/obcy/x"; do
    run odczyt "$W" Read "{\"file_path\":\"$p\"}"
    [ "$(decyzja)" = deny ]
  done
  run odczyt "$W" Grep "{\"pattern\":\"x\",\"path\":\"$T/sh/wt/p/12\"}"
  [ "$(decyzja)" = deny ]
  run odczyt "$W" Glob "{\"pattern\":\"$T/sh/projekty/**/*.md\"}"
  [ "$(decyzja)" = deny ]
}

@test "obejscia: .. i dowiazanie poza worktree to deny" {
  W="$T/sh/wt/p/11"
  run odczyt "$W" Read '{"file_path":"../12/a.ts"}'
  [ "$(decyzja)" = deny ]
  run odczyt "$W" Read "{\"file_path\":\"$W/nie-ma/../../12/a.ts\"}"
  [ "$(decyzja)" = deny ]
  run odczyt "$W" Read "{\"file_path\":\"$W/link-obcy/x\"}"
  [ "$(decyzja)" = deny ]
}

@test "konfiguracja Claude i skille SH: allow" {
  W="$T/sh/wt/p/11"
  for p in "$T/dom/.claude/settings.json" "~/.claude/skills/x/SKILL.md" "$T/sh/sh-system/plugin/skills/sh-worker/SKILL.md"; do
    run odczyt "$W" Read "{\"file_path\":\"$p\"}"
    [ "$(decyzja)" = allow ]
  done
  run odczyt "$W" Read '{"file_path":"~/.ssh/id_ed25519"}'
  [ "$(decyzja)" = deny ]
  run odczyt "$W" Read "{\"file_path\":\"$T/sh/sh-system/scripts/x.sh\"}"
  [ "$(decyzja)" = deny ]
}

@test "katalog tymczasowy: wlasna sesja allow, cudza deny" {
  run odczyt "$T/sh/wt/p/11" Read "{\"file_path\":\"/tmp/claude-$(id -u)/-x/s-123/scratchpad/body.md\"}"
  [ "$(decyzja)" = allow ]
  run odczyt "$T/sh/wt/p/11" Read "{\"file_path\":\"/tmp/claude-$(id -u)/-x/s-123/tasks/b1.output\"}"
  [ "$(decyzja)" = allow ]
  run odczyt "$T/sh/wt/p/11" Read "{\"file_path\":\"/tmp/claude-$(id -u)/-y/inna/scratchpad/body.md\"}"
  [ "$(decyzja)" = deny ]
}

@test "orkiestrator: caly SH_DIR, poza nim deny" {
  run odczyt "$T/sh" Read "{\"file_path\":\"$T/sh/wt/p/12/a.ts\"}"
  [ -z "$output" ]
  run odczyt "$T/sh" Read "{\"file_path\":\"$T/sh/projekty/p/docs/x.md\"}" "$T/sh/projekty/p"
  [ -z "$output" ]
  run odczyt "$T/sh" Read "{\"file_path\":\"$T/obcy/x\"}"
  [ "$(decyzja)" = deny ]
}

@test "inne narzedzia bez decyzji" {
  run odczyt "$T/sh/wt/p/11" Bash "{\"command\":\"cat $T/obcy/x\"}"
  [ "$status" -eq 0 ] && [ -z "$output" ]
}
