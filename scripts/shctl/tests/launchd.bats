#!/usr/bin/env bats
# Start z launchd: minimalne środowisko (env -i, PATH=/usr/bin:/bin, bez terminala), jak w
# LaunchAgencie pl.iskt.softwarehouse.obsidian-sync. Narzędzia leżą w ~/.local/bin, konfiguracja
# w ~/.config/sh/config i ~/.gitconfig, a ~/sh to SH_DIR testu.
load helper

setup() {
  wspolny_setup
  szablon_remote
  "$SHCTL" obsidian link demo >/dev/null
  V="$SH_OBSIDIAN_DIR/demo"

  mkdir -p "$HOME/.local/bin" "$HOME/.config/sh"
  cp "$T/mock/gh" "$T/mock/notify" "$HOME/.local/bin/"
  ln -s "$(command -v jq)" "$HOME/.local/bin/jq"
  ln -s "$SH_DIR" "$HOME/sh"
  printf 'SH_OBSIDIAN_DIR="%s"\n' "$SH_OBSIDIAN_DIR" >"$HOME/.config/sh/config"
  # Bez GIT_CONFIG_GLOBAL git czyta ~/.gitconfig, jak pod launchd.
  cp "$T/gitconfig" "$HOME/.gitconfig"
}

# Środowisko LaunchAgenta, ale z PATH zawężonym do /usr/bin:/bin. GIT_CONFIG_NOSYSTEM: helper
# osxkeychain z systemowego gitconfig nie może sięgać do prawdziwego pęku kluczy.
jak_launchd() {
  env -i HOME="$HOME" PATH=/usr/bin:/bin LANG=pl_PL.UTF-8 GIT_CONFIG_NOSYSTEM=1 "$@"
}

@test "launchd: obsidian sync --agent z PATH=/usr/bin:/bin pobiera nowy commit" {
  git clone -q "$T/remote.git" "$T/inny"
  echo zdalny >>"$T/inny/docs/status.md"
  git -C "$T/inny" commit -qam zdalny
  git -C "$T/inny" push -q origin HEAD:main

  run jak_launchd "$SHCTL" obsidian sync --agent --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.klony[0].stan' <<<"$output")" = ok ]
  [ "$(git -C "$V" rev-parse HEAD)" = "$(git -C "$T/inny" rev-parse HEAD)" ]
  [ "$(jq -r '.problemy | length' "$SH_DIR/stan/obsidian-sync.json")" -eq 0 ]
}

# Przyczyna awarii z 2026-11-03: pod launchd git nie miał skąd wziąć tokenu (osxkeychain pusty,
# terminala brak), więc fetch kończył się „could not read Username”. git_gh bierze token z gh.
@test "launchd: git_gh dostaje token dla github.com z gh, bez terminala i bez ~/.gitconfig" {
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

@test "launchd: nieudany fetch zapisuje w logu przyczyne z git" {
  git -C "$V" remote set-url origin "$T/nie-ma.git"
  run jak_launchd "$SHCTL" obsidian sync --agent
  [ "$status" -eq 0 ]
  grep -q "POMINIĘTY $V: fetch z origin nieudany (.\+)" "$SH_DIR/logs/obsidian-sync.log"
}
