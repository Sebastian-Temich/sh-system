#!/usr/bin/env bats
load helper

setup() { wspolny_setup; }

@test "reserve zajmuje wolny wiersz i jest idempotentne" {
  run "$SHCTL" ports reserve --projekt alfa --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.zakres, .wynik.shadow, .wynik.inspector, .wynik.dev' <<<"$output" | tr '\n' ' ')" = "55121-55129 55128 55125 55126 " ]
  grep -q '^| 1 | alfa | `~/sh/projekty/alfa` | 55121 | 55122 | 55123 | 55124 | 55127 | 55128 | 55129 | 55125 |' "$SH_DIR/porty.md"
  ! grep -q 'wolny' "$SH_DIR/porty.md"
  cp "$SH_DIR/porty.md" "$T/p"
  run "$SHCTL" ports reserve --projekt alfa --json
  [ "$(jq -r .wynik.baza <<<"$output")" = 551 ]
  cmp "$SH_DIR/porty.md" "$T/p"
}

@test "kolejny projekt dostaje nastepny blok w tabeli Supabase" {
  "$SHCTL" ports reserve --projekt alfa
  run "$SHCTL" ports reserve --projekt beta --json
  [ "$(jq -r .wynik.baza <<<"$output")" = 552 ]
  [ "$(awk '/^\| 2 \| beta/{print NR}' "$SH_DIR/porty.md")" -lt "$(awk '/Konflikt/{print NR}' "$SH_DIR/porty.md")" ]
}

@test "release zwalnia, ponowna rezerwacja wraca na ten blok" {
  "$SHCTL" ports reserve --projekt alfa
  "$SHCTL" ports reserve --projekt beta
  run "$SHCTL" ports release --projekt alfa --json
  [ "$(jq -r .wynik.zwolniono <<<"$output")" = true ]
  grep -q '^| 1 | \*wolny\* |' "$SH_DIR/porty.md"
  run "$SHCTL" ports release --projekt alfa --json
  [ "$(jq -r .wynik.zwolniono <<<"$output")" = false ]
  run "$SHCTL" ports reserve --projekt gamma --json
  [ "$(jq -r .wynik.baza <<<"$output")" = 551 ]
}

@test "wyczerpana pula: odmowa, potem --zakres 56" {
  for n in a b c d e f g h i; do "$SHCTL" ports reserve --projekt "$n"; done
  run --separate-stderr "$SHCTL" ports reserve --projekt j
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"zwolnij blok"* ]]
  [ ! -e "$SH_DIR/porty.md.lock" ]
  run "$SHCTL" ports reserve --projekt j --zakres 56 --json
  [ "$(jq -r .wynik.zakres <<<"$output")" = 56121-56129 ]
  grep -q '^| 56:1 | j |' "$SH_DIR/porty.md"
  "$SHCTL" ports release --projekt j
  grep -q '^| 56:1 | \*wolny\* |' "$SH_DIR/porty.md"
}

@test "zajety port: blok pominiety" {
  printf '#!/bin/sh\ncase "$*" in *55123*) exit 0;; esac\nexit 1\n' >"$T/mock/lsof"
  run --separate-stderr "$SHCTL" ports reserve --projekt alfa --json
  [ "$(jq -r .wynik.baza <<<"$output")" = 552 ]
}

@test "reserve ustawia wszystkie porty w config.toml" {
  projekt_demo
  mkdir supabase
  cat >supabase/config.toml <<'TOML'
project_id = "stary"

[api]
enabled = true
port = 54321

[db]
port = 54322
shadow_port = 54320

[db.pooler]
enabled = false
port = 54329

[studio]
port = 54323

[inbucket]
port = 54324

[analytics]
port = 54327
TOML
  run "$SHCTL" ports reserve
  [ "$status" -eq 0 ]
  c=supabase/config.toml
  grep -qx 'project_id = "demo"' $c
  [ "$(yq -p toml '.api.port' $c)" = 55121 ]
  [ "$(yq -p toml '.db.port' $c)" = 55122 ]
  [ "$(yq -p toml '.db.shadow_port' $c)" = 55128 ]
  [ "$(yq -p toml '.db.pooler.port' $c)" = 55129 ]
  [ "$(yq -p toml '.studio.port' $c)" = 55123 ]
  [ "$(yq -p toml '.inbucket.port' $c)" = 55124 ]
  [ "$(yq -p toml '.analytics.port' $c)" = 55127 ]
  [ "$(yq -p toml '.edge_runtime.inspector_port' $c)" = 55125 ]
  cp $c "$T/c"
  "$SHCTL" ports reserve
  cmp $c "$T/c"
}

@test "list podaje rezerwacje" {
  "$SHCTL" ports reserve --projekt alfa
  run "$SHCTL" ports list --json
  [ "$(jq -r '.wynik | map(select(.projekt == "alfa"))[0].api' <<<"$output")" = 55121 ]
  [ "$(jq -r '.wynik | length' <<<"$output")" -eq 2 ]
}

@test "--dry-run nie zmienia rejestru" {
  cp "$SH_DIR/porty.md" "$T/p"
  run "$SHCTL" ports reserve --projekt alfa --dry-run --json
  [ "$(jq -r .wynik.baza <<<"$output")" = 551 ]
  cmp "$SH_DIR/porty.md" "$T/p"
}

@test "brak porty.md: kod 3" {
  rm "$SH_DIR/porty.md"
  run --separate-stderr "$SHCTL" ports list
  [ "$status" -eq 3 ]
}
