#!/usr/bin/env bats
# shctl skrzynka przyjmij: materiały ze skrzynki w vaulcie do repo przez PR, po merge'u do _przeniesione/.
load helper-zadania

setup() {
  zadania_setup
  S="$T/Obsidian Vault/SH/Skrzynka/demo"
  mkdir -p "$S"
  printf 'PNG obraz' >"$S/logo.png"
}

przyjmij() { run --separate-stderr "$SHCTL" skrzynka przyjmij demo --json "$@"; }
zdalny() { git --git-dir "$T/remote.git" show "stage/00-intake:docs/00-intake/zrodla/$1"; }
odrzucone() { jq -r '.wynik.odrzucone[] | "\(.plik): \(.powod)"' <<<"$output"; }
dzien() { date +%Y%m%d; }

@test "pliki trafiaja na stage/00-intake i do PR, skrzynka bez zmian do merge'a" {
  mkdir -p "$S/teksty"
  printf '# O nas\n' >"$S/teksty/o-nas.md"
  printf 'x' >"$S/.DS_Store"
  przyjmij
  echo "$stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.stan <<<"$output")" = pr_otwarty ]
  [ "$(jq -r '.wynik.przyjete | sort | join(",")' <<<"$output")" = "logo.png,teksty/o-nas.md" ]
  [ "$(zdalny logo.png)" = "PNG obraz" ]
  [ "$(zdalny teksty/o-nas.md)" = "# O nas" ]
  ! zdalny .DS_Store 2>/dev/null || false
  [ "$(git --git-dir "$T/remote.git" ls-tree stage/00-intake docs/00-intake/zrodla/logo.png | cut -c1-6)" = 100644 ]
  n="$(jq -r .wynik.pr <<<"$output")"
  [ "$(jq -r --argjson n "$n" '.[] | select(.number == $n) | .headRefName' "$GH_ATRAPA/prs.json")" = stage/00-intake ]
  [ -f "$S/logo.png" ]
  [ -f "$SH_DIR/stan/skrzynka/demo.json" ]
  # Repo główne zostaje na main, bez zmian i bez lokalnej gałęzi etapu.
  [ "$(git -C "$P" symbolic-ref --short HEAD)" = main ]
  [ -z "$(git -C "$P" status --porcelain)" ]
  ! git -C "$P" rev-parse -q --verify refs/heads/stage/00-intake || false
  [ ! -e "$SH_DIR/wt/demo/skrzynka-00-intake" ]
}

@test "pliki wykonywalne, pakiety i dowiazania sa odrzucane i zostaja w skrzynce" {
  printf 'echo hej\n' >"$S/instaluj.sh"
  printf '\177ELF\002\001' >"$S/program"
  printf '\317\372\355\376' >"$S/narzedzie"
  printf 'MZ\220\000' >"$S/setup.dat"
  printf '#!/bin/sh\necho\n' >"$S/notatka.txt"
  mkdir -p "$S/Aplikacja.app/Contents/MacOS"
  printf 'x' >"$S/Aplikacja.app/Contents/MacOS/a"
  printf 'x' >"$S/Aplikacja.app/Contents/Info.plist"
  ln -s /etc/hosts "$S/hosts"
  przyjmij
  echo "$stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.przyjete | join(",")' <<<"$output")" = logo.png ]
  o="$(odrzucone)"
  [[ "$o" == *"instaluj.sh: plik wykonywalny (.sh)"* ]] || false
  [[ "$o" == *"program: plik wykonywalny (nagłówek ELF)"* ]] || false
  [[ "$o" == *"narzedzie: plik wykonywalny (nagłówek Mach-O)"* ]] || false
  [[ "$o" == *"setup.dat: plik wykonywalny (nagłówek PE)"* ]] || false
  [[ "$o" == *"notatka.txt: skrypt (nagłówek #!)"* ]] || false
  [[ "$o" == *"Aplikacja.app: pakiet aplikacji"* ]] || false
  [[ "$o" == *"hosts: dowiązanie symboliczne"* ]] || false
  [ "$(printf '%s\n' "$o" | grep -c 'Aplikacja.app')" -eq 1 ]
  [ -f "$S/instaluj.sh" ] && [ -f "$S/program" ]
  ! git --git-dir "$T/remote.git" show stage/00-intake:docs/00-intake/zrodla/instaluj.sh 2>/dev/null || false
}

@test "same odrzucone pliki: kod 4 bez PR" {
  rm "$S/logo.png"
  printf 'echo\n' >"$S/a.command"
  przyjmij
  [ "$status" -eq 4 ]
  [ "$(jq '[.[] | select(.headRefName == "stage/00-intake")] | length' "$GH_ATRAPA/prs.json" 2>/dev/null || echo 0)" -eq 0 ]
}

@test "ZIP: rozpakowany do folderu archiwum bez plikow wykonywalnych i smieci systemowych" {
  mkdir -p "$T/z/makiety/strony" "$T/z/__MACOSX"
  printf 'PNG strona' >"$T/z/makiety/strony/start.png"
  printf '<html></html>' >"$T/z/makiety/index.html"
  printf 'echo\n' >"$T/z/makiety/run.sh"
  printf 'x' >"$T/z/makiety/.DS_Store"
  printf 'x' >"$T/z/__MACOSX/._start.png"
  (cd "$T/z" && zip -qr "$S/makiety.zip" makiety __MACOSX)
  przyjmij
  echo "$stderr"
  [ "$status" -eq 0 ]
  [ "$(zdalny makiety/makiety/strony/start.png)" = "PNG strona" ]
  [ "$(zdalny makiety/makiety/index.html)" = "<html></html>" ]
  ! zdalny makiety/makiety/run.sh 2>/dev/null || false
  ! zdalny makiety/makiety/.DS_Store 2>/dev/null || false
  ! zdalny makiety.zip 2>/dev/null || false
  [[ "$(odrzucone)" == *"makiety.zip:makiety/run.sh: plik wykonywalny (.sh)"* ]] || false
  [[ "$(jq -r '.wynik.przyjete | join(",")' <<<"$output")" == *makiety.zip* ]] || false
}

@test "ZIP ze sciezka .. albo dowiazaniem jest odrzucany w calosci" {
  python3 -c '
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1], "w"); z.writestr("../poza.txt", "x"); z.writestr("ok.txt", "x"); z.close()
z = zipfile.ZipFile(sys.argv[2], "w"); z.writestr("/etc/abs.txt", "x"); z.close()' "$S/zly.zip" "$S/abs.zip"
  mkdir -p "$T/l" && printf 'x' >"$T/l/cel.txt" && ln -s cel.txt "$T/l/link"
  (cd "$T/l" && zip -qry "$S/link.zip" .)
  przyjmij
  echo "$stderr"
  [ "$status" -eq 0 ]
  o="$(odrzucone)"
  [[ "$o" == *"zly.zip: niebezpieczna ścieżka w archiwum: ../poza.txt"* ]] || false
  [[ "$o" == *"abs.zip: niebezpieczna ścieżka w archiwum: /etc/abs.txt"* ]] || false
  [[ "$o" == *"link.zip: dowiązanie symboliczne w archiwum"* ]] || false
  [ ! -e "$T/Obsidian Vault/SH/Skrzynka/poza.txt" ]
  [ ! -e "$SH_DIR/wt/demo/poza.txt" ]
  ! zdalny zly/ok.txt 2>/dev/null || false
}

@test "po merge'u przyjete pliki trafiaja do _przeniesione, zmienione zostaja" {
  printf 'tekst v1' >"$S/tekst.md"
  przyjmij
  n="$(jq -r .wynik.pr <<<"$output")"
  printf 'tekst v2' >"$S/tekst.md"
  gh pr merge "$n" --repo "$R" --squash
  przyjmij
  echo "$stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.przeniesione | join(",")' <<<"$output")" = logo.png ]
  [ "$(jq -r '.wynik.pozostawione[0].plik' <<<"$output")" = tekst.md ]
  [ -f "$S/_przeniesione/$(dzien)/logo.png" ]
  [ ! -e "$S/logo.png" ]
  # Zmieniony plik od razu wchodzi do nowego PR.
  [ "$(jq -r .wynik.stan <<<"$output")" = pr_otwarty ]
  [ "$(jq -r '.wynik.przyjete | join(",")' <<<"$output")" = tekst.md ]
  [ "$(jq -r .wynik.pr <<<"$output")" != "$n" ]
}

@test "po merge'u bez nowych plikow: przeniesiono, puste katalogi usuniete" {
  mkdir -p "$S/teksty"
  printf 'a' >"$S/teksty/a.md"
  przyjmij
  gh pr merge "$(jq -r .wynik.pr <<<"$output")" --repo "$R" --squash
  przyjmij
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.stan <<<"$output")" = przeniesiono ]
  [ -f "$S/_przeniesione/$(dzien)/teksty/a.md" ]
  [ ! -e "$S/teksty" ]
  [ ! -e "$SH_DIR/stan/skrzynka/demo.json" ]
  przyjmij
  [ "$(jq -r .wynik.stan <<<"$output")" = pusto ]
}

@test "otwarty PR: nowe pliki czekaja, PR zamkniety bez merge'a: kod 4" {
  przyjmij
  n="$(jq -r .wynik.pr <<<"$output")"
  printf 'nowy' >"$S/nowy.md"
  przyjmij
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.stan <<<"$output")" = czeka_na_merge ]
  [ "$(jq -r .wynik.pr <<<"$output")" = "$n" ]
  gh pr close "$n" --repo "$R"
  przyjmij
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"zamknięty bez merge'a"* ]] || false
  [ -f "$S/logo.png" ]
  [ ! -e "$SH_DIR/stan/skrzynka/demo.json" ]
}

@test "--etap wybiera katalog i galaz, zle wartosci to kod 2" {
  przyjmij --etap 04-plan/zrodla
  [ "$status" -eq 0 ]
  [ "$(git --git-dir "$T/remote.git" show stage/04-plan:docs/04-plan/zrodla/logo.png)" = "PNG obraz" ]
  for e in ../x 00-intake/../x /00-intake 99-nic/zrodla '00-intake/a b'; do
    run --separate-stderr "$SHCTL" skrzynka przyjmij demo --etap "$e"
    [ "$status" -eq 2 ]
  done
}

@test "brak skrzynki to kod 3, pusta skrzynka to stan pusto" {
  rm -rf "$S"
  przyjmij
  [ "$status" -eq 3 ]
  mkdir -p "$S"
  przyjmij
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.stan <<<"$output")" = pusto ]
}

@test "dry-run niczego nie wypycha i nie zapisuje stanu" {
  przyjmij --dry-run
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.stan <<<"$output")" = do_przyjecia ]
  ! git --git-dir "$T/remote.git" rev-parse -q --verify refs/heads/stage/00-intake || false
  [ ! -e "$SH_DIR/stan/skrzynka/demo.json" ]
}

@test "istniejaca zdalna galaz etapu dostaje nowy commit, a PR jest wspolny" {
  przyjmij
  n="$(jq -r .wynik.pr <<<"$output")"
  rm "$SH_DIR/stan/skrzynka/demo.json"
  printf 'drugi' >"$S/drugi.md"
  przyjmij
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.pr <<<"$output")" = "$n" ]
  [ "$(zdalny drugi.md)" = drugi ]
  [ "$(zdalny logo.png)" = "PNG obraz" ]
}
