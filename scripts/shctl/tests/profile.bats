#!/usr/bin/env bats
# shctl profile update: profile ról z main szablonu do projektu (main i tag baseline).
load helper-zadania

setup() {
  zadania_setup
  git tag baseline && git push -q origin main baseline
  S="$T/tpl-src"
  git init -q -b main "$S"
  mkdir -p "$S/.claude/roles/worker"
  echo '{"nowy":"worker"}' >"$S/.claude/roles/worker/settings.json"
  git -C "$S" add -A && git -C "$S" commit -qm szablon
  git clone -q --bare "$S" "$T/tpl.git"
  git config --global url."$T/tpl.git".insteadOf https://github.com/test-owner/sh-template-projekt.git
  BASE="$(git rev-parse baseline)"
  MAIN="$(git rev-parse main)"
}

@test "profile update --dry-run: pokazuje zmiany, niczego nie zmienia" {
  run --separate-stderr "$SHCTL" profile update --baseline --dry-run --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.main.pliki | join(",")' <<<"$output")" = .claude/roles/worker/settings.json ]
  [ "$(jq -r '.wynik.baseline.pliki | join(",")' <<<"$output")" = .claude/roles/worker/settings.json ]
  [ "$(git rev-parse main)" = "$MAIN" ]
  [ "$(git -C "$T/remote.git" rev-parse baseline)" = "$BASE" ]
  [ "$(cat .claude/roles/worker/settings.json)" = '{}' ]
}

@test "profile update --baseline: commit na main, nowy baseline, stary w archiwum" {
  echo "po baseline" >src/main.txt && git add -A && git commit -qm "po baseline" && git push -q origin main
  run --separate-stderr "$SHCTL" profile update --baseline --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(git -C "$T/remote.git" show main:.claude/roles/worker/settings.json)" = '{"nowy":"worker"}' ]
  [ "$(git -C "$T/remote.git" log -1 --format=%s main)" = "profile ról z sh-template-projekt $(git -C "$T/tpl.git" rev-parse --short=7 main)" ]
  NB="$(git -C "$T/remote.git" rev-parse 'baseline^{commit}')"
  [ "$NB" != "$BASE" ]
  [ "$(git -C "$T/remote.git" rev-parse "$NB^")" = "$BASE" ]
  [ "$(git -C "$T/remote.git" show baseline:.claude/roles/worker/settings.json)" = '{"nowy":"worker"}' ]
  git -C "$T/remote.git" diff --quiet "$BASE" "$NB" -- . ':(exclude).claude/roles'
  A="$(jq -r .wynik.baseline.archiwum <<<"$output")"
  [ "$(git -C "$T/remote.git" rev-parse "$A^{commit}")" = "$BASE" ]
  [ -z "$(git status --porcelain)" ]
  [ "$(git symbolic-ref --short HEAD)" = main ]
  run --separate-stderr "$SHCTL" profile update --baseline --json
  [ "$(jq -r .wynik.zmiana <<<"$output")" = false ]
}

@test "profile update: bez --baseline tag zostaje" {
  run --separate-stderr "$SHCTL" profile update --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.baseline <<<"$output")" = null ]
  [ "$(git -C "$T/remote.git" rev-parse baseline)" = "$BASE" ]
  [ "$(git -C "$T/remote.git" show main:.claude/roles/worker/settings.json)" = '{"nowy":"worker"}' ]
}

@test "profile update: klon poza main to odmowa bez przelaczania" {
  git switch -q -c task/1-x
  run --separate-stderr "$SHCTL" profile update
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"nie przełącza gałęzi"* ]] || false
  [ "$(git symbolic-ref --short HEAD)" = task/1-x ]
}

@test "profile update: niezacommitowana zmiana profilu to odmowa" {
  echo '{"lokalnie":1}' >.claude/roles/worker/settings.json
  run --separate-stderr "$SHCTL" profile update
  [ "$status" -eq 4 ]
  [ "$(cat .claude/roles/worker/settings.json)" = '{"lokalnie":1}' ]
}

@test "profile: bledne uzycie" {
  run "$SHCTL" profile
  [ "$status" -eq 2 ]
}
