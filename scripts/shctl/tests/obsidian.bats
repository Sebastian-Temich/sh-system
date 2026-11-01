#!/usr/bin/env bats
load helper

setup() { wspolny_setup; szablon_remote; V="$SH_OBSIDIAN_DIR/demo"; }

@test "link tworzy klon tylko z docs/ w katalogu ze spacja" {
  run "$SHCTL" obsidian link demo
  [ "$status" -eq 0 ]
  [[ "$output" == *"wystarczy włączyć Obsidian Git"* ]]
  [ -f "$V/docs/konfiguracja.md" ]
  [ ! -e "$V/src" ]
  [ ! -e "$V/README.md" ]
}

@test "link jest idempotentny" {
  "$SHCTL" obsidian link demo
  run --separate-stderr "$SHCTL" obsidian link demo --json
  [ "$(jq -r .wynik.utworzono <<<"$output")" = false ]
}

@test "link odmawia, gdy katalog nie jest klonem tego repo" {
  mkdir -p "$V"
  run --separate-stderr "$SHCTL" obsidian link demo
  [ "$status" -eq 4 ]
}

@test "link --dry-run nic nie tworzy" {
  run --separate-stderr "$SHCTL" obsidian link demo --dry-run --json
  [ "$(jq -r .wynik.utworzono <<<"$output")" = true ]
  [ ! -e "$V" ]
}

@test "unlink usuwa czysty klon, powtorka to sukces" {
  "$SHCTL" obsidian link demo
  run "$SHCTL" obsidian unlink demo
  [ "$status" -eq 0 ]
  [ ! -e "$V" ]
  run --separate-stderr "$SHCTL" obsidian unlink demo --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.usunieto <<<"$output")" = false ]
}

@test "unlink odmawia przy niezacommitowanej zmianie" {
  "$SHCTL" obsidian link demo
  echo x >>"$V/docs/status.md"
  run --separate-stderr "$SHCTL" obsidian unlink demo
  [ "$status" -eq 4 ]
  [ -f "$V/docs/status.md" ]
}

@test "unlink odmawia przy pliku nieskledzonym i niewypchnietym commicie" {
  "$SHCTL" obsidian link demo
  echo x >"$V/docs/nowa.md"
  run --separate-stderr "$SHCTL" obsidian unlink demo
  [ "$status" -eq 4 ]
  git -C "$V" add docs/nowa.md
  git -C "$V" commit -qm lokalny
  run --separate-stderr "$SHCTL" obsidian unlink demo
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"niewypchnięte"* ]]
}

@test "unlink nie usuwa katalogu, ktory nie jest klonem" {
  mkdir -p "$V"
  echo notatki >"$V/moje.md"
  run --separate-stderr "$SHCTL" obsidian unlink demo
  [ "$status" -eq 4 ]
  [ -f "$V/moje.md" ]
}

@test "unlink --dry-run zostawia klon" {
  "$SHCTL" obsidian link demo
  run "$SHCTL" obsidian unlink demo --dry-run
  [ "$status" -eq 0 ]
  [ -d "$V" ]
}

@test "bez SH_OBSIDIAN_DIR: kod 3" {
  unset SH_OBSIDIAN_DIR
  run --separate-stderr "$SHCTL" obsidian link demo
  [ "$status" -eq 3 ]
}

@test "zla nazwa: kod 2" {
  run --separate-stderr "$SHCTL" obsidian unlink ../x
  [ "$status" -eq 2 ]
}
