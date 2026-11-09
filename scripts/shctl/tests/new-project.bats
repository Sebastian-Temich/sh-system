#!/usr/bin/env bats
load helper

setup() { wspolny_setup; szablon_nowy; }

nowy() { "$SHCTL" new-project demo --opis "Aplikacja testowa" "$@"; }
K() { echo "$SH_DIR/projekty/demo/$1"; }

@test "pelny przebieg na atrapie GitHuba" {
  run nowy --zlecenie "Treść zlecenia"
  [ "$status" -eq 0 ]
  grep -qx 'repo create test-owner/demo --public --description Aplikacja testowa' "$T/gh.calls"
  ! grep -q -- '--template' "$T/gh.calls" || false
  grep -q 'label create' "$T/gh.calls"
  grep -qx 'repo edit test-owner/demo --description Aplikacja testowa --add-topic sh-projekt --delete-branch-on-merge' "$T/gh.calls"
  grep -q '^api -X POST repos/test-owner/demo/rulesets --input ' "$T/gh.calls"
  grep -qxF "git --redact --no-banner $SH_DIR/projekty/demo" "$T/gitleaks.calls"
  [ "$(git -C "$T/remote.git" log --format=%s main | tail -1)" = "Projekt demo z sh-template-projekt@$(git -C "$T/szablon" rev-parse --short HEAD)" ]
  [ "$(git -C "$T/remote.git" rev-list --count main)" -eq 2 ]
  [ "$(head -1 "$(K README.md)")" = "# demo" ]
  grep -qx 'Aplikacja testowa' "$(K README.md)"
  [ "$(fm "$(K docs/konfiguracja.md)" tryb_procesu)" = M ]
  [ "$(fm "$(K docs/konfiguracja.md)" etap_wdrozenia)" = A ]
  [ "$(fm "$(K docs/konfiguracja.md)" data)" = "$(date +%F)" ]
  [ "$(fm "$(K docs/konfiguracja.md)" blok_portow)" = 55121-55129 ]
  grep -q '^| 1 | demo |' "$SH_DIR/porty.md"
  [ "$(fm "$(K docs/04-plan/DoD.md)" status)" = todo ]
  [ -f "$(K docs/Projekt.md)" ]
  grep -qx 'Treść zlecenia' "$(K docs/00-intake/zrodlo.md)"
  [[ "$output" == *"Synchronizację robi serwer co 5 minut"* ]] || false
  [ -z "$(git -C "$(K .)" status --porcelain)" ]
  [ "$(git -C "$T/remote.git" log -1 --format=%s main)" = "shctl: konfiguracja projektu demo (tryb M)" ]
}

@test "powtorka nic nie zmienia" {
  nowy --zlecenie "Zlecenie X"
  a="$(git -C "$(K .)" rev-parse HEAD)"
  run nowy --zlecenie "Zlecenie X"
  [ "$status" -eq 0 ]
  [ "$(git -C "$(K .)" rev-parse HEAD)" = "$a" ]
  [ "$(grep -c '^repo create' "$T/gh.calls")" -eq 1 ]
  [ "$(grep -c '^| . | demo' "$SH_DIR/porty.md")" -eq 1 ]
  [ "$(grep -c 'Zlecenie X' "$(K docs/00-intake/zrodlo.md)")" -eq 1 ]
}

@test "powtorka dokancza niewypchniety commit" {
  nowy
  git -C "$(K .)" commit -q --allow-empty -m lokalny
  run nowy
  [ "$status" -eq 0 ]
  [ "$(git -C "$T/remote.git" log -1 --format=%s main)" = lokalny ]
}

@test "powtorka nie zabiera cudzych zmian" {
  nowy
  echo x >"$(K docs/notatka.md)"
  echo y >>"$(K docs/konfiguracja.md)"
  a="$(git -C "$(K .)" rev-parse HEAD)"
  git -C "$(K .)" checkout -q docs/konfiguracja.md
  run nowy
  [ "$(git -C "$(K .)" rev-parse HEAD)" = "$a" ]
  [ -f "$(K docs/notatka.md)" ]
}

@test "klon w vaulcie ma tylko docs/, sciezka ze spacja" {
  run --separate-stderr nowy --json
  [ "$status" -eq 0 ]
  v="$SH_OBSIDIAN_DIR/demo"
  [ "$(jq -r .wynik.obsidian.katalog <<<"$output")" = "$v" ]
  [ -f "$v/docs/konfiguracja.md" ]
  [ -d "$T/Obsidian Vault/SH/Skrzynka/demo" ]
  [ "$(jq -r .wynik.obsidian.skrzynka.katalog <<<"$output")" = "$T/Obsidian Vault/SH/Skrzynka/demo" ]
  [ "$(jq -r .wynik.obsidian.skrzynka.utworzono <<<"$output")" = true ]
  [ ! -e "$v/src" ]
  [ ! -e "$v/scripts" ]
  [ ! -e "$v/README.md" ]
  [ "$(fm "$v/docs/konfiguracja.md" tryb_procesu)" = M ]
}

@test "koncowy komunikat wskazuje synchronizacje serwera, powtorka nie klonuje drugi raz" {
  run nowy
  [[ "$output" == *"Synchronizację robi serwer co 5 minut"* ]] || false
  run --separate-stderr nowy --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.obsidian.utworzono <<<"$output")" = false ]
}

@test "--dry-run nie zaklada klonu" {
  run --separate-stderr nowy --dry-run --json
  [ ! -e "$SH_OBSIDIAN_DIR" ]
  [ "$(jq -r .wynik.obsidian.utworzono <<<"$output")" = false ]
}

@test "sciezka z config, ze spacja; zmienna srodowiska wygrywa" {
  unset SH_OBSIDIAN_DIR
  mkdir -p "$HOME/.config/sh"
  printf '# komentarz\nSH_OBSIDIAN_DIR="%s"\n' "$T/Inny Vault" >"$HOME/.config/sh/config"
  run --separate-stderr nowy --dry-run --json
  [ "$(jq -r .wynik.obsidian.katalog <<<"$output")" = "$T/Inny Vault/demo" ]
  SH_OBSIDIAN_DIR="/ze srodowiska" run --separate-stderr nowy --dry-run --json
  [ "$(jq -r .wynik.obsidian.katalog <<<"$output")" = "/ze srodowiska/demo" ]
}

@test "config jest czytany jako dane, nie wykonywany" {
  unset SH_OBSIDIAN_DIR
  mkdir -p "$HOME/.config/sh"
  printf 'touch wykonano\nSH_OBSIDIAN_DIR="$(touch wykonano)"\n' >"$HOME/.config/sh/config"
  cd "$T"
  run --separate-stderr nowy --dry-run --json
  [ "$status" -eq 0 ]
  [ ! -e "$T/wykonano" ]
}

@test "bez konfiguracji projekt powstaje, klon pominiety z ostrzezeniem" {
  unset SH_OBSIDIAN_DIR
  run --separate-stderr nowy --json
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"pomijam klon"* ]] || false
  [ "$(jq -r .wynik.obsidian <<<"$output")" = null ]
}

@test "powtorka wlacza usuwanie galezi takze w istniejacym repo" {
  nowy
  : >"$T/gh.calls"
  run nowy
  [ "$status" -eq 0 ]
  grep -qx 'repo edit test-owner/demo --description Aplikacja testowa --add-topic sh-projekt --delete-branch-on-merge' "$T/gh.calls"
}

@test "--prywatny: repo prywatne i runner serwera w zmiennej SH_RUNS_ON" {
  run --separate-stderr nowy --prywatny
  [ "$status" -eq 0 ]
  grep -qx 'repo create test-owner/demo --private --description Aplikacja testowa' "$T/gh.calls"
  grep -qF 'variable set SH_RUNS_ON --repo test-owner/demo --body ["self-hosted","sh-imac"]' "$T/gh.calls"
  [[ "$stderr" == *"runner serwera"* ]] || false
}

@test "--opis wymagany i najwyzej 350 znakow" {
  run --separate-stderr "$SHCTL" new-project demo
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"--opis wymagany"* ]] || false
  run --separate-stderr "$SHCTL" new-project demo --opis "$(printf 'x%.0s' $(seq 1 351))"
  [ "$status" -eq 2 ]
  [ ! -s "$T/gh.calls" ]
}

@test "gitleaks znajduje sekret: push wstrzymany, kod 4" {
  : >"$T/gitleaks-sekret"
  run --separate-stderr nowy
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"gitleaks"* ]] || false
  [ -z "$(git -C "$T/remote.git" for-each-ref refs/heads)" ]
}

@test "ruleset zakladany raz na projekt" {
  nowy
  [ "$(grep -c '^api -X POST repos/test-owner/demo/rulesets' "$T/gh.calls")" -eq 1 ]
}

@test "tryb S: wszystkie etapy pominiete i ostrzezenie" {
  run --separate-stderr nowy --tryb S
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"zaczyna od M lub L"* ]] || false
  [ "$(fm "$(K docs/00-intake/DoD.md)" status)" = pominiety ]
  [ -f "$(K docs/Projekt.md)" ]
}

@test "zmiana trybu w istniejacym projekcie: odmowa" {
  nowy
  run --separate-stderr nowy --tryb S
  [ "$status" -eq 4 ]
}

@test "tryb L w etapie A: kod 2" {
  run --separate-stderr nowy --tryb L
  [ "$status" -eq 2 ]
}

@test "repo spoza szablonu: odmowa bez zmian" {
  printf '{"isEmpty":false,"repositoryTopics":[],"templateRepository":null}' >"$T/repo-istnieje"
  run --separate-stderr nowy
  [ "$status" -eq 4 ]
  [ ! -d "$(K .)" ]
}

@test "katalog innego repo: odmowa" {
  mkdir -p "$(K .)"
  run --separate-stderr nowy
  [ "$status" -eq 4 ]
}

@test "--dry-run: bez zapisu na GitHubie i na dysku" {
  cp "$SH_DIR/porty.md" "$T/p"
  run nowy --dry-run --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.repo, .wynik.porty, .dry_run' <<<"$output" | tr '\n' ' ')" = "test-owner/demo 55121-55129 true " ]
  [ "$(cut -d' ' -f1-2 "$T/gh.calls" | sort -u)" = "repo view" ]
  [ ! -d "$(K .)" ]
  cmp "$SH_DIR/porty.md" "$T/p"
}

@test "niepoprawna nazwa: kod 2" {
  run --separate-stderr "$SHCTL" new-project "../zla"
  [ "$status" -eq 2 ]
}

@test "blad autoryzacji gh to nie brak repo" {
  printf '#!/bin/sh\necho "HTTP 401" >&2\nexit 1\n' >"$T/mock/gh"
  run --separate-stderr nowy
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"401"* ]] || false
}
