#!/usr/bin/env bats
# Start z launchd: minimalne środowisko (env -i, PATH=/usr/bin:/bin, bez terminala), jak w
# LaunchAgencie pl.iskt.softwarehouse.obsidian-sync (scripts/server/obsidian-sync.sh). Narzędzia leżą w ~/.local/bin, konfiguracja
# w ~/.config/sh/config i ~/.gitconfig, a SH_DIR podaje plista (EnvironmentVariables), tu jak_launchd.
load helper

setup() {
  wspolny_setup
  szablon_remote
  "$SHCTL" obsidian link demo >/dev/null
  V="$SH_OBSIDIAN_DIR/demo"

  mkdir -p "$HOME/.local/bin" "$HOME/.config/sh"
  cp "$T/mock/gh" "$T/mock/notify" "$HOME/.local/bin/"
  ln -s "$(command -v jq)" "$HOME/.local/bin/jq"
  printf 'SH_OBSIDIAN_DIR="%s"\n' "$SH_OBSIDIAN_DIR" >"$HOME/.config/sh/config"
  # Bez GIT_CONFIG_GLOBAL git czyta ~/.gitconfig, jak pod launchd.
  cp "$T/gitconfig" "$HOME/.gitconfig"
}

# Środowisko LaunchAgenta, ale z PATH zawężonym do /usr/bin:/bin. GIT_CONFIG_NOSYSTEM: helper
# osxkeychain z systemowego gitconfig nie może sięgać do prawdziwego pęku kluczy.
jak_launchd() {
  env -i HOME="$HOME" SH_DIR="$SH_DIR" PATH=/usr/bin:/bin LANG=pl_PL.UTF-8 GIT_CONFIG_NOSYSTEM=1 "$@"
}

@test "launchd: obsidian-sync.sh z PATH=/usr/bin:/bin pobiera nowy commit" {
  git clone -q "$T/remote.git" "$T/inny"
  echo zdalny >>"$T/inny/docs/Projekt.md"
  git -C "$T/inny" commit -qam zdalny
  git -C "$T/inny" push -q origin HEAD:main

  run jak_launchd /bin/bash "$REPO/scripts/server/obsidian-sync.sh"
  [ "$status" -eq 0 ]
  [ "$(git -C "$V" rev-parse HEAD)" = "$(git -C "$T/inny" rev-parse HEAD)" ]
  [ ! -s "$SH_DIR/logs/obsidian-sync.log" ]
}

# Przyczyna awarii z 2026-11-03: pod launchd git nie miał skąd wziąć tokenu (osxkeychain pusty,
# terminala brak), więc fetch kończył się „could not read Username”. git_gh bierze token z gh.
@test "launchd: git_gh dostaje token dla github.com z gh, bez terminala i bez ~/.gitconfig" {
  # Runner Ubuntu ma gh w /usr/bin: przesłoniłby atrapę z ~/.local/bin. Na macOS /usr/bin nie ma gh.
  [ ! -x /usr/bin/gh ] && [ ! -x /bin/gh ] || skip "gh w /usr/bin przesłania atrapę (runner CI)"
  rm "$HOME/.gitconfig"
  run jak_launchd bash -c '
    SHCTL_DIR="$1"
    . "$SHCTL_DIR/lib/common.sh"
    printf "protocol=https\nhost=github.com\n\n" | git_gh -t 20 credential fill' _ "$REPO/scripts/shctl"
  [ "$status" -eq 0 ]
  [[ "$output" == *"password=atrapa"* ]] || false
  grep -qx 'auth git-credential get' "$T/gh.calls"
}

@test "launchd: zwykly git bez helpera konczy sie bledem zamiast czekac na haslo" {
  rm "$HOME/.gitconfig"
  run jak_launchd bash -c 'printf "protocol=https\nhost=github.com\n\n" | GIT_TERMINAL_PROMPT=0 git credential fill'
  [ "$status" -ne 0 ]
}

@test "launchd: nieudany pull zapisuje w logu przyczyne z git, flaga wylacza przebieg" {
  git -C "$V" remote set-url origin "$T/nie-ma.git"
  run jak_launchd /bin/bash "$REPO/scripts/server/obsidian-sync.sh"
  [ "$status" -eq 0 ]
  grep -q "POMINIĘTY $V: .\+" "$SH_DIR/logs/obsidian-sync.log"
  : >"$SH_DIR/logs/obsidian-sync.log"
  mkdir -p "$SH_DIR/stan"
  touch "$SH_DIR/stan/obsidian-sync.off"
  run jak_launchd /bin/bash "$REPO/scripts/server/obsidian-sync.sh"
  [ ! -s "$SH_DIR/logs/obsidian-sync.log" ]
}
