#!/usr/bin/env bats
# Przypomnienia o czekaniu na właściciela (przypomnienia.sh) i tabela „Wszystkie projekty” w vaulcie
# (obsidian-sync.sh), na danych z docs/Projekt.md i atrapie notify.

bats_require_minimum_version 1.5.0

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  T="$BATS_TEST_TMPDIR"
  export SH_DIR="$T/sh" SH_NOTIFY_CMD="$T/notify" SH_GODZINA=10
  # 2026-11-09T12:00:00Z
  export SH_TERAZ=1794225600
  mkdir -p "$SH_DIR/projekty"
  printf '#!/bin/sh\nprintf "%%s|%%s|%%s\\n" "$1" "$2" "$3" >>"%s/notified"\n' "$T" >"$T/notify"
  chmod +x "$T/notify"
}

projekt() {
  mkdir -p "$SH_DIR/projekty/$1/docs"
  printf -- '---\nprojekt: %s\netap: realizacja\netap_opis: "Realizacja, kamień M2"\npostep: "3/7"\nczeka_na_ciebie: 2\neskalacje: 1\npytania: 1\nczeka: %s\n---\n\n# %s\n' \
    "$1" "$2" "$1" >"$SH_DIR/projekty/$1/docs/Projekt.md"
}

przypomnij() { bash "$REPO/scripts/server/przypomnienia.sh"; }

@test "pozycja czekajaca ponad 4 h: jedno powiadomienie z tekstem do wpisania" {
  projekt sklep '[{"co":"E-001 (#2): klucz Stripe","od":"2026-11-09T06:30:00Z","wpisz":"E-001: A"},{"co":"Lista startowa: Vercel","od":"2026-11-09T11:00:00Z","wpisz":"gotowe: Vercel"}]'
  run przypomnij
  [ "$status" -eq 0 ]
  [ "$(wc -l <"$T/notified" | tr -d ' ')" -eq 1 ]
  grep -q '^default|Czeka na Ciebie od 5 h: sklep|E-001 (#2): klucz Stripe (5 h). Wpisz: E-001: A$' "$T/notified"
  ! grep -q 'Vercel' "$T/notified" || false
}

@test "ta sama pozycja wraca dopiero po kolejnych 4 h" {
  projekt sklep '[{"co":"E-001 (#2): klucz","od":"2026-11-09T06:00:00Z","wpisz":"E-001: A"}]'
  przypomnij
  SH_TERAZ=$((SH_TERAZ + 3600)) przypomnij
  [ "$(wc -l <"$T/notified" | tr -d ' ')" -eq 1 ]
  SH_TERAZ=$((SH_TERAZ + 14400)) przypomnij
  [ "$(wc -l <"$T/notified" | tr -d ' ')" -eq 2 ]
}

@test "poza godzinami 8-22 i przy fladze off bez powiadomien" {
  projekt sklep '[{"co":"E-001","od":"2026-11-09T01:00:00Z","wpisz":"E-001: A"}]'
  SH_GODZINA=22 przypomnij
  SH_GODZINA=7 przypomnij
  [ ! -e "$T/notified" ]
  mkdir -p "$SH_DIR/stan" && : >"$SH_DIR/stan/przypomnienia.off"
  przypomnij
  [ ! -e "$T/notified" ]
}

@test "pusta lista i projekt bez Projekt.md nie przeszkadzaja" {
  projekt pusty '[]'
  mkdir -p "$SH_DIR/projekty/stary/docs" && : >"$SH_DIR/projekty/stary/docs/status.md"
  run przypomnij
  [ "$status" -eq 0 ]
  [ ! -e "$T/notified" ]
}

@test "obsidian-sync: Wszystkie projekty.md z tabela i linkami do Projekt.md" {
  V="$T/Vault ze spacja/SH/Projekty"
  for n in sklep stary; do
    mkdir -p "$V/$n/docs"
    git init -q "$V/$n"
  done
  printf -- '---\netap_opis: "Realizacja, kamień M2"\npostep: "3/7"\nczeka_na_ciebie: 2\neskalacje: 1\npytania: 1\n---\n' >"$V/sklep/docs/Projekt.md"
  SH_OBSIDIAN_DIR="$V" run bash "$REPO/scripts/server/obsidian-sync.sh"
  [ "$status" -eq 0 ]
  W="$T/Vault ze spacja/SH/Wszystkie projekty.md"
  cat "$W"
  grep -qxF '| sklep | Realizacja, kamień M2 | 3/7 | 2 | 1 + 1 pyt. | [Projekt.md](<Projekty/sklep/docs/Projekt.md>) |' "$W"
  grep -qxF '| stary | (brak docs/Projekt.md) | | | | |' "$W"
  ! grep -q dataview "$W" || false
}
