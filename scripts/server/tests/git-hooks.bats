#!/usr/bin/env bats
# Globalny pre-push i delegowanie do hooków projektu, na lokalnym repo bare.

bats_require_minimum_version 1.5.0

KOMUNIKAT="Push na production wykonuje wyłącznie właściciel z własnego urządzenia"

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  HOOKI="$REPO/scripts/server/git-hooks"
  T="$BATS_TEST_TMPDIR"
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$T/gitconfig"
  git config --global core.hooksPath "$HOOKI"
  git config --global user.name test
  git config --global user.email test@example.com
  git config --global init.defaultBranch main

  git init -q --bare "$T/origin.git"
  git init -q "$T/repo"
  cd "$T/repo"
  git remote add origin "$T/origin.git"
  git commit -q --allow-empty -m start
}

ma_ref() {
  git --git-dir="$T/origin.git" show-ref --verify --quiet "$1"
}

# Sam `! polecenie` nie przerywa testu.
brak_ref() {
  if ma_ref "$1"; then
    return 1
  fi
}

# Hook projektu zapisuje wywołanie z argumentami i wejściem, a kod wyjścia bierze z $2.
hook_projektu() {
  mkdir -p "$(dirname "$1")"
  cat >"$1" <<MOCK
#!/bin/sh
echo "\$(basename "\$0") \$*" >>"$T/wywolania"
cat >>"$T/wejscie"
exit ${2:-0}
MOCK
  chmod +x "$1"
}

@test "push na main przechodzi" {
  run git push origin main
  [ "$status" -eq 0 ]
  ma_ref refs/heads/main
}

@test "push na production odrzucony" {
  git branch production
  run git push origin production
  [ "$status" -ne 0 ]
  [[ "$output" == *"$KOMUNIKAT"* ]]
  brak_ref refs/heads/production
}

@test "main:production i pelny ref odrzucone" {
  run git push origin main:production
  [ "$status" -ne 0 ]
  [[ "$output" == *"$KOMUNIKAT"* ]]
  run git push origin HEAD:refs/heads/production
  [ "$status" -ne 0 ]
  [[ "$output" == *"$KOMUNIKAT"* ]]
  brak_ref refs/heads/production
}

@test "--all z lokalna production odrzucone w calosci" {
  git branch production
  run git push origin --all
  [ "$status" -ne 0 ]
  brak_ref refs/heads/main
}

@test "usuniecie production odrzucone" {
  git push -q origin main
  git --git-dir="$T/origin.git" update-ref refs/heads/production refs/heads/main
  run git push origin :production
  [ "$status" -ne 0 ]
  ma_ref refs/heads/production
}

@test "podobne nazwy i tag production przechodza" {
  git branch production-test
  git branch task/production
  git tag production
  run git push origin production-test task/production refs/tags/production
  [ "$status" -eq 0 ]
  ma_ref refs/heads/production-test
  ma_ref refs/heads/task/production
  ma_ref refs/tags/production
}

@test "pre-push z .git/hooks dostaje argumenty i wejscie po sprawdzeniu" {
  hook_projektu .git/hooks/pre-push
  run git push origin main
  [ "$status" -eq 0 ]
  [ "$(cat "$T/wywolania")" = "pre-push origin $T/origin.git" ]
  grep -q '^refs/heads/main .* refs/heads/main ' "$T/wejscie"
}

@test "pre-push projektu nie uruchamia sie po odrzuceniu" {
  hook_projektu .git/hooks/pre-push
  run git push origin main:production
  [ "$status" -ne 0 ]
  [ ! -f "$T/wywolania" ]
}

@test "bledny pre-push projektu blokuje push" {
  hook_projektu .git/hooks/pre-push 3
  run git push origin main
  [ "$status" -ne 0 ]
  brak_ref refs/heads/main
}

@test "inne typy hookow z .git/hooks dzialaja" {
  hook_projektu .git/hooks/pre-commit 1
  run git commit --allow-empty -m nowy
  [ "$status" -ne 0 ]
  [ "$(cat "$T/wywolania")" = "pre-commit " ]
  rm .git/hooks/pre-commit
  hook_projektu .git/hooks/commit-msg 1
  run git commit --allow-empty -m nowy
  [ "$status" -ne 0 ]
  [[ "$(cat "$T/wywolania")" == *"commit-msg .git/COMMIT_EDITMSG"* ]]
  rm .git/hooks/commit-msg
  hook_projektu .git/hooks/post-commit
  run git commit --allow-empty -m nowy
  [ "$status" -eq 0 ]
  [[ "$(cat "$T/wywolania")" == *"post-commit"* ]]
}

@test "core.hooksPath zapisany w repo ma pierwszenstwo przed .git/hooks" {
  # Lokalne ustawienie wygrywa z globalnym, więc do hooka globalnego prowadzi tylko -c.
  hook_projektu .wlasne/pre-push
  hook_projektu .git/hooks/pre-push 1
  git config --local core.hooksPath .wlasne
  run git -c core.hooksPath="$HOOKI" push origin main
  [ "$status" -eq 0 ]
  [[ "$(cat "$T/wywolania")" == "pre-push origin"* ]]
  run git -c core.hooksPath="$HOOKI" push origin main:production
  [ "$status" -ne 0 ]
  [[ "$output" == *"$KOMUNIKAT"* ]]
}

@test "worktree uzywa hookow wspolnego katalogu" {
  hook_projektu .git/hooks/pre-commit
  git worktree add -q "$T/wt" -b task/1
  cd "$T/wt"
  run git commit --allow-empty -m nowy
  [ "$status" -eq 0 ]
  [ "$(cat "$T/wywolania")" = "pre-commit " ]
}

@test "repo bez hookow i bez katalogu hooks dziala" {
  rm -rf .git/hooks
  run git commit --allow-empty -m nowy
  [ "$status" -eq 0 ]
  run git push origin main
  [ "$status" -eq 0 ]
}

# Hook zapisuje znacznik i wejście, dzięki czemu widać kolejność i to, że obydwa dostały dane.
hook_znacznik() {
  mkdir -p "$(dirname "$1")"
  cat >"$1" <<MOCK
#!/bin/sh
echo "$2" >>"$T/kolejnosc"
cat >>"$T/wejscie-$2"
exit ${3:-0}
MOCK
  chmod +x "$1"
}

@test ".githooks: wykonywalny hook dziala" {
  hook_znacznik .githooks/pre-commit repo 1
  run git commit --allow-empty -m nowy
  [ "$status" -ne 0 ]
  [ "$(cat "$T/kolejnosc")" = repo ]
}

@test ".githooks: niewykonywalny plik i katalog pomijane" {
  hook_znacznik .githooks/pre-commit repo 1
  chmod -x .githooks/pre-commit
  mkdir .githooks/commit-msg
  run git commit --allow-empty -m nowy
  [ "$status" -eq 0 ]
  [ ! -f "$T/kolejnosc" ]
}

@test ".githooks i .git/hooks: oba w kolejnosci, z tym samym wejsciem" {
  hook_znacznik .git/hooks/pre-push git
  hook_znacznik .githooks/pre-push repo
  run git push origin main
  [ "$status" -eq 0 ]
  [ "$(tr '\n' ' ' <"$T/kolejnosc")" = "git repo " ]
  grep -q '^refs/heads/main ' "$T/wejscie-git"
  cmp "$T/wejscie-git" "$T/wejscie-repo"
}

@test "blad .git/hooks zatrzymuje .githooks i zwraca kod" {
  hook_znacznik .git/hooks/pre-commit git 3
  hook_znacznik .githooks/pre-commit repo
  run git commit --allow-empty -m nowy
  [ "$status" -ne 0 ]
  [ "$(cat "$T/kolejnosc")" = git ]
}

@test "blad .githooks blokuje push po udanym .git/hooks" {
  hook_znacznik .git/hooks/pre-push git
  hook_znacznik .githooks/pre-push repo 1
  run git push origin main
  [ "$status" -ne 0 ]
  brak_ref refs/heads/main
}

@test ".githooks nie omija blokady production" {
  hook_znacznik .githooks/pre-push repo
  run git push origin main:production
  [ "$status" -ne 0 ]
  [[ "$output" == *"$KOMUNIKAT"* ]]
  [ ! -f "$T/kolejnosc" ]
}

@test "core.hooksPath na .githooks nie uruchamia hooka dwa razy" {
  hook_znacznik .githooks/pre-commit repo
  git config --local core.hooksPath .githooks
  run git -c core.hooksPath="$HOOKI" commit --allow-empty -m nowy
  [ "$status" -eq 0 ]
  [ "$(cat "$T/kolejnosc")" = repo ]
}

@test "SH_BEZ_HOOKOW_REPO pomija .githooks, a .git/hooks zostaje" {
  hook_znacznik .git/hooks/pre-commit git
  hook_znacznik .githooks/pre-commit repo 1
  SH_BEZ_HOOKOW_REPO=1 run git commit --allow-empty -m nowy
  [ "$status" -eq 0 ]
  [ "$(cat "$T/kolejnosc")" = git ]
}

@test "worktree add: post-checkout z commita dziala, SH_BEZ_HOOKOW_REPO go wylacza" {
  hook_znacznik .githooks/post-checkout repo
  git add .githooks
  git commit -q -m hook
  git worktree add -q "$T/wt1" -b task/1
  [ "$(cat "$T/kolejnosc")" = repo ]
  rm "$T/kolejnosc"
  SH_BEZ_HOOKOW_REPO=1 git worktree add -q "$T/wt2" -b task/2
  [ ! -f "$T/kolejnosc" ]
}

@test "hooki sa wykonywalne, a zmieniajacych zachowanie gita nie ma" {
  for h in "$HOOKI"/*; do
    [ -x "$h" ]
  done
  [ ! -e "$HOOKI/push-to-checkout" ]
  [ ! -e "$HOOKI/proc-receive" ]
}
