#!/usr/bin/env bats
# shctl obsidian sync: tylko git pull --ff-only, pominięcia z logiem, powiadomienie przy powtórce.
load helper

setup() {
  wspolny_setup
  szablon_remote
  V="$SH_OBSIDIAN_DIR/demo"
  "$SHCTL" obsidian link demo >/dev/null
  STANP="$SH_DIR/stan/obsidian-sync.json"
  SLOG="$SH_DIR/logs/obsidian-sync.log"
}

# Nowy commit w origin projektu demo.
zdalny_commit() {
  [ -d "$T/inny" ] || git clone -q "$T/remote.git" "$T/inny"
  echo "$1" >>"$T/inny/docs/status.md"
  git -C "$T/inny" commit -qam "zdalny $1"
  git -C "$T/inny" push -q origin HEAD:main
}

@test "aktualny klon: ok, zapisana ostatnia udana synchronizacja, bez powiadomienia" {
  run --separate-stderr "$SHCTL" obsidian sync --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.klony[0].stan' <<<"$output")" = ok ]
  [ "$(jq -r '.wynik.pominiete' <<<"$output")" -eq 0 ]
  [ "$(jq -r '.ostatnia_udana' "$STANP")" != null ]
  [ ! -s "$T/notified" ]
}

@test "nowy commit w origin: pull --ff-only" {
  zdalny_commit raz
  run "$SHCTL" obsidian sync
  [ "$status" -eq 0 ]
  grep -q raz "$V/docs/status.md"
  [ "$(git -C "$V" rev-parse HEAD)" = "$(git -C "$T/inny" rev-parse HEAD)" ]
  grep -q "ok $V" "$SLOG"
}

@test "lokalne zmiany: pominiety bez zmian, log; powiadomienie dopiero przy powtorce i tylko raz" {
  zdalny_commit raz
  echo lokalna >"$V/docs/notatka.md"
  przed="$(git -C "$V" rev-parse HEAD)"
  run --separate-stderr "$SHCTL" obsidian sync --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.klony[0].stan' <<<"$output")" = pominiety ]
  [ "$(git -C "$V" rev-parse HEAD)" = "$przed" ]
  [ -f "$V/docs/notatka.md" ]
  grep -q "POMINIĘTY $V: lokalne zmiany" "$SLOG"
  [ "$(jq -r '.ostatnia_udana' "$STANP")" = null ]
  [ ! -s "$T/notified" ]
  "$SHCTL" obsidian sync 2>/dev/null
  [ "$(wc -l <"$T/notified")" -eq 1 ]
  grep -q "Obsidian: klon bez synchronizacji" "$T/notified"
  "$SHCTL" obsidian sync 2>/dev/null
  [ "$(wc -l <"$T/notified")" -eq 1 ]
  [ "$(jq -r --arg k "$V" '.problemy[$k].przebiegi' "$STANP")" -eq 3 ]
}

@test "rozjechany z origin: bez merge i resetu" {
  zdalny_commit zdalny
  echo lokalny >>"$V/docs/status.md"
  git -C "$V" commit -qam lokalny
  lok="$(git -C "$V" rev-parse HEAD)"
  run --separate-stderr "$SHCTL" obsidian sync --json
  [ "$status" -eq 0 ]
  [[ "$(jq -r '.wynik.klony[0].opis' <<<"$output")" == "rozjechany z origin/main"* ]] || false
  [ "$(git -C "$V" rev-parse HEAD)" = "$lok" ]
  [ -z "$(git -C "$V" status --porcelain)" ]
}

@test "niewypchniety commit: pominiety" {
  echo lokalny >>"$V/docs/status.md"
  git -C "$V" commit -qam lokalny
  run --separate-stderr "$SHCTL" obsidian sync --json
  [[ "$(jq -r '.wynik.klony[0].opis' <<<"$output")" == "niewypchnięte commity: 1" ]] || false
}

@test "problem ustapil: znika ze stanu, nowa udana synchronizacja" {
  echo lokalna >"$V/docs/notatka.md"
  "$SHCTL" obsidian sync 2>/dev/null
  rm "$V/docs/notatka.md"
  "$SHCTL" obsidian sync
  [ "$(jq -r '.problemy | length' "$STANP")" -eq 0 ]
  [ "$(jq -r '.ostatnia_udana' "$STANP")" != null ]
}

@test "klon sh-system obok katalogu projektow tez jest synchronizowany" {
  s="$T/sys"
  git init -q "$s"
  mkdir -p "$s/docs"
  echo a >"$s/docs/proces.md"
  git -C "$s" add -A
  git -C "$s" commit -qm start
  git clone -q --bare "$s" "$T/sys.git"
  git config --global url."$T/sys.git".insteadOf https://github.com/test-owner/sh-system.git
  K="$(dirname "$SH_OBSIDIAN_DIR")/sh-system"
  git clone -q https://github.com/test-owner/sh-system.git "$K"
  git clone -q "$T/sys.git" "$T/sys-inny"
  echo b >>"$T/sys-inny/docs/proces.md"
  git -C "$T/sys-inny" commit -qam b
  git -C "$T/sys-inny" push -q origin HEAD:main
  run --separate-stderr "$SHCTL" obsidian sync --json
  [ "$status" -eq 0 ]
  jq -e --arg k "$K" '.wynik.klony | map(select(.katalog == $k and .stan == "ok")) | length == 1' <<<"$output"
  grep -q b "$K/docs/proces.md"
}

@test "flaga obsidian-sync.off: przebieg z agenta sie pomija, reczny dziala" {
  mkdir -p "$SH_DIR/stan"
  touch "$SH_DIR/stan/obsidian-sync.off"
  zdalny_commit raz
  run --separate-stderr "$SHCTL" obsidian sync --agent --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.wylaczona <<<"$output")" = true ]
  [ ! -f "$STANP" ]
  ! grep -q raz "$V/docs/status.md"
  "$SHCTL" obsidian sync
  grep -q raz "$V/docs/status.md"
}

@test "--dry-run niczego nie pobiera ani nie zapisuje" {
  zdalny_commit raz
  run "$SHCTL" obsidian sync --dry-run
  [ "$status" -eq 0 ]
  ! grep -q raz "$V/docs/status.md"
  [ ! -f "$STANP" ]
}

@test "agent: pominiecie tylko w logu, nie na stderr" {
  echo lokalna >"$V/docs/notatka.md"
  run --separate-stderr "$SHCTL" obsidian sync --agent
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  grep -q POMINIĘTY "$SLOG"
}

@test "skrzynka na materialy nie jest klonem: sync jej nie dotyka" {
  S="$T/Obsidian Vault/SH/Skrzynka/demo"
  [ -d "$S" ]
  printf 'x' >"$S/logo.png"
  run --separate-stderr "$SHCTL" obsidian sync --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '[.wynik.klony[].katalog] | map(select(contains("Skrzynka"))) | length' <<<"$output")" -eq 0 ]
  [ "$(jq -r .wynik.pominiete <<<"$output")" -eq 0 ]
  [ -f "$S/logo.png" ]
}
