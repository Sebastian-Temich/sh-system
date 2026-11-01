#!/usr/bin/env bats
load helper

setup() {
  wspolny_setup
  for n in docker herdr codex claude bats; do printf '#!/bin/sh\nexit 0\n' >"$T/mock/$n"; done
  printf '#!/bin/sh\necho "status: running"\n' >"$T/mock/herdr"
  printf '#!/bin/sh\necho "{\\"loggedIn\\": true}"\n' >"$T/mock/claude"
  chmod +x "$T/mock/"*
  mkdir -p "$HOME/.config/sh"
  echo temat >"$HOME/.config/sh/ntfy-topic"
}

@test "wszystko dziala: kod 0, JSON z kontrolami" {
  run "$SHCTL" doctor --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.bledy <<<"$output")" -eq 0 ]
  jq -e '.wynik.kontrole | map(.nazwa) | index("logowanie claude")' <<<"$output"
}

@test "niezalogowany claude: kod 1 i wskazowka" {
  printf '#!/bin/sh\necho "{\\"loggedIn\\": false}"\n' >"$T/mock/claude"
  run --separate-stderr "$SHCTL" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"claude auth login"* ]] || false
}

@test "Docker nie odpowiada: kod 1" {
  printf '#!/bin/sh\nexit 1\n' >"$T/mock/docker"
  run --separate-stderr "$SHCTL" doctor --json
  [ "$status" -eq 1 ]
  [ "$(jq -r '.wynik.kontrole | map(select(.nazwa == "Docker"))[0].stan' <<<"$output")" = blad ]
}

@test "brak tematu ntfy: kod 1" {
  rm "$HOME/.config/sh/ntfy-topic"
  run --separate-stderr "$SHCTL" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"brak tematu"* ]] || false
}

@test "lokalny core.hooksPath to ostrzezenie, nie blad" {
  git config --global core.hooksPath /x/scripts/server/git-hooks
  projekt_demo
  git config --local core.hooksPath .husky
  cd "$T"
  run "$SHCTL" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"hooki demo"* ]] || false
  [[ "$output" == *"wyłącza globalny pre-push"* ]] || false
}

@test "bez --test-notify nie wysyla, z nim wysyla" {
  "$SHCTL" doctor
  [ ! -s "$T/notified" ]
  "$SHCTL" doctor --test-notify
  [ -s "$T/notified" ]
}

klon_vaulta() {
  szablon_remote
  "$SHCTL" obsidian link demo
}
ob_stan() { jq -r '.wynik.kontrole | map(select(.nazwa == "Obsidian demo"))[0] | .stan + ":" + .szczegoly' <<<"$output"; }

@test "czysty i aktualny klon w vaulcie" {
  klon_vaulta
  run --separate-stderr "$SHCTL" doctor --json
  [ "$(ob_stan)" = "ok:czysty i aktualny" ]
}

@test "niezacommitowana zmiana w klonie to uwaga" {
  klon_vaulta
  echo notatka >"$SH_OBSIDIAN_DIR/demo/docs/nowa.md"
  run --separate-stderr "$SHCTL" doctor --json
  [ "$status" -eq 0 ]
  [ "$(ob_stan)" = "uwaga:niezacommitowane zmiany: 1" ]
}

@test "klon za origin to uwaga, doctor niczego nie pobiera" {
  klon_vaulta
  git clone -q "$T/remote.git" "$T/obok"
  git -C "$T/obok" commit -q --allow-empty -m nowy
  git -C "$T/obok" push -q origin HEAD:main
  przed="$(git -C "$SH_OBSIDIAN_DIR/demo" rev-parse origin/main)"
  run --separate-stderr "$SHCTL" doctor --json
  [ "$(ob_stan)" = "uwaga:różni się od origin" ]
  [ "$(git -C "$SH_OBSIDIAN_DIR/demo" rev-parse origin/main)" = "$przed" ]
}
