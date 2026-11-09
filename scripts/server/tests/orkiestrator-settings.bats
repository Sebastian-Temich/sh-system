#!/usr/bin/env bats
# Lista dozwolonych orkiestratora: formy git -C są dozwolone tam, gdzie zwykłe, a każda reguła deny
# dla git ma odpowiednik z -C (inaczej `git -C KATALOG push --force` przeszedłby przez allow).

setup() { S="$BATS_TEST_DIRNAME/../orkiestrator-settings.json"; }

allow() { jq -e --arg r "$1" '.permissions.allow | index($r) != null' "$S" >/dev/null; }
deny() { jq -e --arg r "$1" '.permissions.deny | index($r) != null' "$S" >/dev/null; }

@test "poprawny JSON" {
  jq -e . "$S" >/dev/null
}

@test "git: zapis i siec przez cd i zwykly git (sandbox nie wylacza git -C), -C tylko do odczytu" {
  for r in 'Bash(cd /Users/Shared/sh/*)' 'Bash(git add *)' 'Bash(git commit *)' 'Bash(git push)' 'Bash(git push *)' \
    'Bash(git fetch *)' 'Bash(git worktree add *)' 'Bash(git -C * status)' 'Bash(git -C * log *)' 'Bash(git -C * show *)'; do
    allow "$r" || { echo "brak allow: $r"; false; }
  done
  for r in 'Bash(git -C * add *)' 'Bash(git -C * commit *)' 'Bash(git -C * push *)' 'Bash(git -C * fetch *)' \
    'Bash(git -C * pull --ff-only*)' 'Bash(git -C * worktree add *)'; do
    ! allow "$r" || { echo "zbedne allow (nie dziala w sandboxie): $r"; false; }
  done
}

@test "kazda regula deny dla git ma odpowiednik z -C" {
  while IFS= read -r r; do
    deny "${r/Bash(git /Bash(git -C * }" || { echo "brak deny z -C dla: $r"; false; }
  done < <(jq -r '.permissions.deny[] | select(startswith("Bash(git ") and (startswith("Bash(git -C") | not)
    and (startswith("Bash(git * ") | not))' "$S")
}

@test "bez przelaczania galezi i usuwania galezi" {
  for r in 'Bash(git -C * switch *)' 'Bash(git -C * checkout *)' 'Bash(git checkout *)' 'Bash(git -C * branch -D*)' 'Bash(git branch -D*)'; do
    deny "$r" || { echo "brak deny: $r"; false; }
  done
  ! allow 'Bash(git switch *)' || false
}

@test "wymuszony push przez +refspec, --mirror i --prune zabronione, z -C i bez" {
  for r in 'Bash(git push +*)' 'Bash(git push * +*)' 'Bash(git -C * push +*)' 'Bash(git -C * push * +*)' \
    'Bash(git push --mirror*)' 'Bash(git push * --mirror*)' 'Bash(git -C * push * --mirror*)' \
    'Bash(git push --prune*)' 'Bash(git push * --prune*)' 'Bash(git -C * push * --prune*)'; do
    deny "$r" || { echo "brak deny: $r"; false; }
  done
}

@test "git -c zabronione, z -C i bez (core.sshCommand, core.hooksPath, aliasy)" {
  deny 'Bash(git -c *)'
  deny 'Bash(git -C * -c *)'
}

@test "--exec, --receive-pack, --upload-pack zabronione w kazdej komendzie git" {
  for r in 'Bash(git * --exec*)' 'Bash(git * --receive-pack*)' 'Bash(git * --upload-pack*)'; do
    deny "$r" || { echo "brak deny: $r"; false; }
  done
}

# Dopasowanie wzorców deny jak w Claude Code: * to dowolny ciąg, reszta dosłownie.
pasuje() {
  jq -e --arg k "$1" '[.permissions.deny[] | select(startswith("Bash(")) | ltrimstr("Bash(") | rtrimstr(")")
    | gsub("(?<z>[.+?^$()\\[\\]{}|\\\\])"; "\\\(.z)") | gsub("\\*"; ".*") | "^" + . + "$"]
    | any(.[]; . as $w | $k | test($w))' "$S" >/dev/null
}

@test "przyklady zablokowane i dozwolone" {
  for k in 'git push origin +main' 'git -C /Users/Shared/sh/projekty/x push origin +HEAD:main' 'git push +main' \
    'git push --mirror origin' 'git -C x push --prune origin' 'git -c core.hooksPath=/tmp/h commit -m x' \
    'git -C x -c core.sshCommand=evil fetch' 'git fetch --upload-pack=evil origin' 'git -C x push --receive-pack=evil' \
    'git -C x push --force origin main' 'git -C x checkout main'; do
    pasuje "$k" || { echo "przechodzi: $k"; false; }
  done
  for k in 'git -C /Users/Shared/sh/projekty/x push' 'git -C /Users/Shared/sh/projekty/x push origin main' \
    'git -C /Users/Shared/sh/projekty/x commit -m "orkiestrator: zamkniecie #12"' 'git -C x pull --ff-only'; do
    ! pasuje "$k" || { echo "zablokowane: $k"; false; }
  done
}

# Dopasowanie wzorców allow jak w Claude Code (do sprawdzenia zawężonej reguły worktree remove).
dozwolone() {
  jq -e --arg k "$1" '[.permissions.allow[] | select(startswith("Bash(")) | ltrimstr("Bash(") | rtrimstr(")")
    | gsub("(?<z>[.+?^$()\\[\\]{}|\\\\])"; "\\\(.z)") | gsub("\\*"; ".*") | "^" + . + "$"]
    | any(.[]; . as $w | $k | test($w))' "$S" >/dev/null
}

@test "worktree etapu: add i remove zwyklym git z katalogu projektu, bez --force; switch zabroniony" {
  for r in 'Bash(git worktree add *)' 'Bash(git worktree remove /Users/Shared/sh/wt/*)' \
    'Bash(git worktree remove /Users/Shared/sh/wt-system/*)'; do
    allow "$r" || { echo "brak allow: $r"; false; }
  done
  ! allow 'Bash(git worktree remove *)' || false
  dozwolone 'git worktree remove /Users/Shared/sh/wt/x/stage-04-plan'
  dozwolone 'git worktree remove /Users/Shared/sh/wt-system/f3b'
  ! dozwolone 'git worktree remove /Users/Shared/sh/projekty/x' || false
  ! dozwolone 'git worktree remove /tmp/inny' || false
  pasuje 'git worktree remove /Users/Shared/sh/wt/../projekty/x'
  allow 'Bash(shctl sprzataj)' && allow 'Bash(shctl sprzataj *)'
  pasuje 'git -C /Users/Shared/sh/projekty/x worktree remove --force /Users/Shared/sh/wt/x/stage-04-plan'
  pasuje 'git -C /Users/Shared/sh/projekty/x worktree remove /Users/Shared/sh/wt/x/stage-04-plan -f'
  pasuje 'git -C /Users/Shared/sh/projekty/x worktree remove -f /Users/Shared/sh/wt/x/stage-04-plan'
  pasuje 'git worktree remove --force /Users/Shared/sh/wt/x/stage-04-plan'
  pasuje 'git worktree remove -f /Users/Shared/sh/wt/x/stage-04-plan'
  pasuje 'git worktree remove /Users/Shared/sh/wt/x/stage-04-plan -f'
  pasuje 'git switch stage/04-plan'
  pasuje 'git -C /Users/Shared/sh/projekty/x switch task/12-a'
}

@test "reguly bez koncowego :* (Claude Code czyta je doslownie i ignoruje)" {
  [ "$(jq -r '[.permissions.allow[], .permissions.deny[]] | map(select(endswith(":*)"))) | length' "$S")" -eq 0 ]
}

@test "katalogi domowe poza zasiegiem, gh gist, release upload, --no-index i --exec-path zabronione" {
  for k in "~/Documents/**" "~/Desktop/**" "~/Downloads/**" "~/Library/Mobile Documents/**"; do
    deny "Read($k)" && deny "Edit($k)" || { echo "brak deny dla $k"; false; }
  done
  for k in 'gh gist create plik' 'gh release upload v1 plik' 'git diff --no-index a b' \
    'git --exec-path=/tmp/x status' 'git -C /Users/Shared/sh/projekty/x --exec-path=/tmp/x push'; do
    pasuje "$k" || { echo "przechodzi: $k"; false; }
  done
}

@test "sandbox: wlaczony, bez wyjscia poza sandbox; shctl, herdr, gh, git i notify.sh poza nim" {
  jq -e '.sandbox.enabled == true and .sandbox.allowUnsandboxedCommands == false' "$S" >/dev/null
  for c in "shctl *" "herdr *" "gh *" "git *" "notify.sh *"; do
    jq -e --arg c "$c" '.sandbox.excludedCommands | index($c)' "$S" >/dev/null || { echo "brak excluded $c"; false; }
  done
  [ "$(jq -r '[.sandbox.excludedCommands[] | select(test("^(node|npx|pnpm|npm|python|uv|bash|cat|jq) "))] | length' "$S")" -eq 0 ]
  jq -e '.sandbox.network.allowedDomains | index("ntfy.sh") and index("api.github.com")' "$S" >/dev/null
}
