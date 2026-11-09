#!/usr/bin/env bats
# Lista dozwolonych orkiestratora: formy git -C są dozwolone tam, gdzie zwykłe, a każda reguła deny
# dla git ma odpowiednik z -C (inaczej `git -C KATALOG push --force` przeszedłby przez allow).

setup() { S="$BATS_TEST_DIRNAME/../orkiestrator-settings.json"; }

allow() { jq -e --arg r "$1" '.permissions.allow | index($r) != null' "$S" >/dev/null; }
deny() { jq -e --arg r "$1" '.permissions.deny | index($r) != null' "$S" >/dev/null; }

@test "poprawny JSON" {
  jq -e . "$S" >/dev/null
}

@test "git -C: commit i push na main bez pytania" {
  for r in 'Bash(git -C * status)' 'Bash(git -C * add *)' 'Bash(git -C * commit *)' 'Bash(git -C * push)' \
    'Bash(git -C * push *)' 'Bash(git -C * pull --ff-only*)'; do
    allow "$r" || { echo "brak allow: $r"; false; }
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

@test "worktree etapu: add i remove przez -C, bez --force; switch zabroniony takze bez -C" {
  for r in 'Bash(git -C * worktree add *)' 'Bash(git -C * worktree remove *)'; do
    allow "$r" || { echo "brak allow: $r"; false; }
  done
  pasuje 'git -C /Users/Shared/sh/projekty/x worktree remove --force /Users/Shared/sh/wt/x/stage-04-plan'
  pasuje 'git -C /Users/Shared/sh/projekty/x worktree remove /Users/Shared/sh/wt/x/stage-04-plan -f'
  pasuje 'git switch stage/04-plan'
  pasuje 'git -C /Users/Shared/sh/projekty/x switch task/12-a'
}
