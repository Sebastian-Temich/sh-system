#!/usr/bin/env bats
# Hook PreToolUse env-hook.sh: pliki .env (poza .env.example) zablokowane w kazdym katalogu.

bats_require_minimum_version 1.5.0

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
}

# hook NARZEDZIE JSON_WEJSCIA_NARZEDZIA
hook() {
  jq -nc --arg n "$1" --argjson i "$2" '{tool_name:$n, tool_input:$i, cwd:"/x", session_id:"s"}' |
    "$REPO/scripts/server/env-hook.sh"
}
decyzja() { printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision // "brak"'; }
bash_cmd() { hook Bash "$(jq -nc --arg c "$1" '{command:$c}')"; }

@test "Read/Edit/Write: kazdy wariant .env w kazdym katalogu to deny" {
  for p in .env .env.local .env.production .env.production.local .env.development .env.test \
    .env.staging .env.ci .env.backup .env.vault .env.keys .env.sample apps/web/.env \
    /Users/Shared/sh/wt/p/11/supabase/.env.local ./.env; do
    for n in Read Edit Write MultiEdit; do
      run hook "$n" "$(jq -nc --arg p "$p" '{file_path:$p}')"
      [ "$status" -eq 0 ]
      [ "$(decyzja)" = deny ] || { echo "przeszlo: $n $p"; false; }
    done
  done
}

@test "Read/Edit: .env.example i inne nazwy bez decyzji" {
  for p in .env.example apps/web/.env.example .envrc src/env.ts docs/.environment.md package.json; do
    for n in Read Edit Write; do
      run hook "$n" "$(jq -nc --arg p "$p" '{file_path:$p}')"
      [ "$status" -eq 0 ] && [ -z "$output" ] || { echo "decyzja dla $n $p: $output"; false; }
    done
  done
}

@test "Glob i Grep po plikach .env to deny, pattern Grepa to tresc" {
  run hook Glob '{"pattern":"**/.env*"}'
  [ "$(decyzja)" = deny ]
  run hook Glob '{"pattern":"apps/*/.env.local"}'
  [ "$(decyzja)" = deny ]
  run hook Grep '{"pattern":"KEY","path":"apps/web/.env.production"}'
  [ "$(decyzja)" = deny ]
  run hook Grep '{"pattern":"KEY","glob":".env*"}'
  [ "$(decyzja)" = deny ]
  run hook Grep '{"pattern":"\\.env\\.local","path":"src"}'
  [ -z "$output" ]
  run hook Glob '{"pattern":"**/.env.example"}'
  [ -z "$output" ]
}

@test "Bash: odwolanie do .env w dowolnej formie to deny" {
  for c in 'cat .env' 'cat ./.env' 'cat apps/web/.env' 'head -5 .env.local' 'cat .env.production' \
    'grep KEY .env.ci' 'cat .env*' 'ls -la .env.?*' 'cp .env.example .env.local' 'git add .env' \
    'pnpm dotenv -e .env.production -- next build' 'node --env-file=.env.local x.js' \
    'cat "apps/web/.env.staging"' "cat '.env.test'" 'wc -l <.env'; do
    run bash_cmd "$c"
    [ "$(decyzja)" = deny ] || { echo "przeszlo: $c"; false; }
  done
}

@test "Bash: .env.example i zwykle komendy bez decyzji" {
  for c in 'cat .env.example' 'git add .env.example apps/web/.env.example' 'git diff -- .env.example' \
    'pnpm test' 'cat .envrc' 'grep -rn process.env src' 'git commit -m "opis zmiennych w .env.example"'; do
    run bash_cmd "$c"
    [ "$status" -eq 0 ] && [ -z "$output" ] || { echo "decyzja dla $c: $output"; false; }
  done
}

@test "fail-closed: bledne wejscie to kod 2" {
  run bash -c 'printf "nie json" | "$1"' _ "$REPO/scripts/server/env-hook.sh"
  [ "$status" -eq 2 ]
  run bash -c 'printf "{}" | "$1"' _ "$REPO/scripts/server/env-hook.sh"
  [ "$status" -eq 2 ]
}
