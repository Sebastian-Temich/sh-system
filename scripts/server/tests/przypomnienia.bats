#!/usr/bin/env bats
# Przypomnienia o czekaniu na właściciela (przypomnienia.sh) i tabela „Wszystkie projekty” w vaulcie
# (obsidian-sync.sh), na listach stan/czeka/PROJEKT.json (sync-status.sh), frontmatterze
# docs/Projekt.md i atrapie notify.

bats_require_minimum_version 1.5.0

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  T="$BATS_TEST_TMPDIR"
  export SH_DIR="$T/sh" SH_NOTIFY_CMD="$T/notify" SH_GODZINA=10
  # 2026-11-09T12:00:00Z
  export SH_TERAZ=1794225600
  mkdir -p "$SH_DIR/stan/czeka"
  printf '#!/bin/sh\nprintf "%%s|%%s|%%s\\n" "$1" "$2" "$3" >>"%s/notified"\n' "$T" >"$T/notify"
  chmod +x "$T/notify"
}

projekt() { printf '%s\n' "$2" >"$SH_DIR/stan/czeka/$1.json"; }

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

@test "pusta lista i brak katalogu czeka nie przeszkadzaja" {
  projekt pusty '[]'
  run przypomnij
  [ "$status" -eq 0 ]
  [ ! -e "$T/notified" ]
  rm -rf "$SH_DIR/stan/czeka"
  run przypomnij
  [ "$status" -eq 0 ]
  [ ! -e "$T/notified" ]
}

@test "nieczytelna lista w jednym przebiegu nie kasuje stanu: bez powtorki przed 4 h" {
  projekt sklep '[{"co":"E-001 (#2): klucz","od":"2026-11-09T06:00:00Z","wpisz":"E-001: A"}]'
  przypomnij
  [ "$(wc -l <"$T/notified" | tr -d ' ')" -eq 1 ]
  printf '[{"co":' >"$SH_DIR/stan/czeka/sklep.json"
  SH_TERAZ=$((SH_TERAZ + 900)) przypomnij
  [ "$(jq -r '."sklep|E-001 (#2): klucz"' "$SH_DIR/stan/przypomnienia.json")" = "$SH_TERAZ" ]
  projekt sklep '[{"co":"E-001 (#2): klucz","od":"2026-11-09T06:00:00Z","wpisz":"E-001: A"}]'
  SH_TERAZ=$((SH_TERAZ + 1800)) przypomnij
  [ "$(wc -l <"$T/notified" | tr -d ' ')" -eq 1 ]
}

@test "obsidian-sync: Wszystkie projekty.md, kolejnosc czeka, w toku, zakonczone, nastepny krok" {
  V="$T/Vault ze spacja/SH/Projekty"
  for n in alfa sklep stary zeta; do
    mkdir -p "$V/$n/docs"
    git init -q "$V/$n"
  done
  printf -- '---\nprojekt: alfa\ntryb: M\netap_opis: "Zakończony"\npostep_etapy: "5/5"\npostep_zadania: "3/3"\nczeka_na_ciebie: 0\neskalacje: 0\nnastepny_krok: "Brak, zlecenie zakończone"\n---\n' >"$V/alfa/docs/Projekt.md"
  printf -- '---\nprojekt: sklep\ntryb: M\netap_opis: "Realizacja, kamień M2"\npostep_etapy: "3/5"\npostep_zadania: "3/7"\nczeka_na_ciebie: 2\neskalacje: 2\nnastepny_krok: "Twoja odpowiedź: E-001 (#2): klucz"\n---\n' >"$V/sklep/docs/Projekt.md"
  printf -- '---\nprojekt: zeta\ntryb: M\netap_opis: "Plan"\npostep_etapy: "1/5"\npostep_zadania: "0/0"\nczeka_na_ciebie: 0\neskalacje: 0\nnastepny_krok: "Agent przygotowuje etap plan"\n---\n' >"$V/zeta/docs/Projekt.md"
  SH_OBSIDIAN_DIR="$V" run bash "$REPO/scripts/server/obsidian-sync.sh"
  [ "$status" -eq 0 ]
  W="$T/Vault ze spacja/SH/Wszystkie projekty.md"
  cat "$W"
  grep -qxF '| Projekt | Etap | Postęp | Czeka na Ciebie | Eskalacje | Następny krok | Widok |' "$W"
  [ "$(grep -o '^| [a-z]* |' "$W" | tr -d '| ' | paste -sd ' ' -)" = "sklep zeta alfa stary" ]
  grep -qxF '| sklep | Realizacja, kamień M2 | Etapy 3/5 · Zadania 3/7 | 2 | 2 | Twoja odpowiedź: E-001 (#2): klucz | [Projekt.md](<Projekty/sklep/docs/Projekt.md>) |' "$W"
  grep -qxF '| alfa | Zakończony | Etapy 5/5 · Zadania 3/3 | 0 | 0 | Brak, zlecenie zakończone | [Projekt.md](<Projekty/alfa/docs/Projekt.md>) |' "$W"
  grep -qxF '| stary | (brak docs/Projekt.md) | | | | | |' "$W"
  ! grep -q dataview "$W" || false
}
