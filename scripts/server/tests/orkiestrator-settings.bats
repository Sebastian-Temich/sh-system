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
    'Bash(git fetch *)' 'Bash(git -C /Users/Shared/sh/* status)' 'Bash(git -C /Users/Shared/sh/* log *)' 'Bash(git -C /Users/Shared/sh/* show *)'; do
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
  for r in 'Bash(git worktree add --no-track -b * /Users/Shared/sh/wt/*)' 'Bash(git worktree add --no-track -b * /Users/Shared/sh/wt-system/*)' \
    'Bash(git worktree remove /Users/Shared/sh/wt/*)' 'Bash(git worktree remove /Users/Shared/sh/wt-system/*)'; do
    allow "$r" || { echo "brak allow: $r"; false; }
  done
  ! allow 'Bash(git worktree remove *)' || false
  ! allow 'Bash(git worktree add *)' || false
  dozwolone 'git worktree add --no-track -b stage/04-plan /Users/Shared/sh/wt/x/stage-04-plan origin/main'
  ! dozwolone 'git worktree add --no-track -b x /tmp/y origin/main' || false
  pasuje 'git worktree add --no-track -b x /Users/Shared/sh/wt/../../../tmp/y origin/main'
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

@test "worktree dla istniejacej galezi (bez -b): allow w wt/ i wt-system/, poza sandboxem, bez --force i -B" {
  for r in 'Bash(git worktree add /Users/Shared/sh/wt/*)' 'Bash(git worktree add /Users/Shared/sh/wt-system/*)'; do
    allow "$r" || { echo "brak allow: $r"; false; }
  done
  dozwolone 'git worktree add /Users/Shared/sh/wt/app/stage-00-analiza stage/00-analiza'
  dozwolone 'git worktree add /Users/Shared/sh/wt-system/b1-adopt sh-lite/b1-adopt'
  ! dozwolone 'git worktree add /tmp/x stage/00-analiza' || false
  ! dozwolone 'git worktree add /Users/Shared/sh/projekty/x main' || false
  for k in 'git worktree add /Users/Shared/sh/wt/x/y main -f' 'git worktree add /Users/Shared/sh/wt/x/y --force main' \
    'git worktree add /Users/Shared/sh/wt/x/y -B main origin/main' 'git worktree add /Users/Shared/sh/wt/../projekty/x main' \
    'git -C /Users/Shared/sh/projekty/x worktree add /Users/Shared/sh/wt/x/y main -f'; do
    pasuje "$k" || { echo "przechodzi: $k"; false; }
  done
  for k in 'git worktree add /Users/Shared/sh/wt/app/stage-00-analiza stage/00-analiza' \
    'git worktree add --no-track -b task/5-x /Users/Shared/sh/wt/app/5 origin/main'; do
    ! pasuje "$k" || { echo "zablokowane: $k"; false; }
  done
  # Ta sama forma co z -b: wzorzec wyjątku sandboxa obejmuje obie.
  jq -e '.sandbox.excludedCommands | index("git worktree add *")' "$S" >/dev/null
}

@test "widocznosc repo tylko przez shctl adopt upublicznij: gh repo edit --visibility zabronione" {
  deny 'Bash(gh repo edit *--visibility*)'
  pasuje 'gh repo edit acme/app --visibility public --accept-visibility-change-consequences'
  dozwolone 'shctl adopt upublicznij --projekt app'
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

@test "sandbox: wlaczony, bez wyjscia poza sandbox; shctl, herdr, gh, git push|fetch|pull i notify.sh poza nim" {
  jq -e '.sandbox.enabled == true and .sandbox.allowUnsandboxedCommands == false' "$S" >/dev/null
  for c in "shctl *" "herdr *" "gh *" "git push *" "notify.sh *"; do
    jq -e --arg c "$c" '.sandbox.excludedCommands | index($c)' "$S" >/dev/null || { echo "brak excluded $c"; false; }
  done
  [ "$(jq -r '[.sandbox.excludedCommands[] | select(test("^(node|npx|pnpm|npm|python|uv|bash|cat|jq) "))] | length' "$S")" -eq 0 ]
  jq -e '.sandbox.network.allowedDomains | index("ntfy.sh") and index("api.github.com")' "$S" >/dev/null
}

@test "git poza sandboxem tylko do sieci i worktree; odczyt (diff, show, log, config, blame, grep) w sandboxie" {
  ! jq -e '.sandbox.excludedCommands | index("git *")' "$S" >/dev/null || false
  for c in "git push *" "git fetch *" "git pull *" "git worktree add *" "git worktree remove *"; do
    jq -e --arg c "$c" '.sandbox.excludedCommands | index($c)' "$S" >/dev/null || { echo "brak excluded $c"; false; }
  done
  [ "$(jq -r '[.sandbox.excludedCommands[] | select(test("^git (diff|show|log|config|blame|grep|commit|cat-file|hash-object|-C)"))] | length' "$S")" -eq 0 ]
}

@test "git czytajacy pliki spoza repo: --no-index, config -f, blame --contents, -C poza /Users/Shared/sh zabronione" {
  for k in 'git diff --no-index /Users/x/Documents/a /dev/null' 'git -C /Users/Shared/sh/projekty/x diff --no-index a b' \
    'git grep --no-index sekret /Users/x/Documents' 'git config -f /Users/x/Documents/a --list' \
    'git -C /Users/Shared/sh/projekty/x config --file a --list' 'git blame --contents /Users/x/Documents/a plik' \
    'git -C ~/Documents status' 'git -C /Users/sebastiant./Documents log' 'git -C /tmp/x status' \
    'git -C /private/tmp/x log' 'git -C ../.. status' 'git -C /Users/Shared/sh/../../../etc status'; do
    pasuje "$k" || { echo "przechodzi: $k"; false; }
  done
  ! dozwolone 'git -C /Users/Shared/inny status' || false
  for k in 'git -C /Users/Shared/sh/wt/x/12 log --oneline origin/main..HEAD' 'git -C /Users/Shared/sh/wt/x/12 diff origin/main...HEAD --stat'; do
    ! pasuje "$k" || { echo "zablokowane: $k"; false; }
    dozwolone "$k" || { echo "nie dozwolone: $k"; false; }
  done
}

@test "polecenia dla workera tylko przez shctl task polecenie, bez herdr agent prompt (SH-lite F10)" {
  [ "$(jq -r '[.permissions.allow[] | select(test("herdr agent prompt"))] | length' "$S")" -eq 0 ]
  ! dozwolone 'herdr agent prompt worker:demo:12 "popraw testy"' || false
  dozwolone 'shctl task polecenie 12 "popraw testy"'
  dozwolone '/Users/Shared/sh/bin/shctl task polecenie 12 "popraw testy" --projekt demo'
  ! pasuje 'shctl task polecenie 12 "popraw testy"' || false
  # Odczyt paneli zostaje (task wait i podglad pracy workera).
  dozwolone 'herdr agent read worker:demo:12'
  dozwolone 'herdr pane read p1'
}

@test "hook gh-plik-hook.sh na Bash: plik tresci gh tylko z /Users/Shared/sh (gh poza sandboxem)" {
  jq -e '.hooks.PreToolUse | any(.matcher == "Bash" and (.hooks[0].command == "/Users/Shared/sh/bin/gh-plik-hook.sh || exit 2"))' "$S" >/dev/null
}
