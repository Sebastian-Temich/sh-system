#!/usr/bin/env bats
# shctl skrzynka przyjmij: kopia do docs/00-intake/zrodla, commit, PR, merge po zielonym CI, pusta skrzynka.
load helper-zadania

setup() {
  zadania_setup
  S="$T/Obsidian Vault/SH/Skrzynka/demo"
  mkdir -p "$S/teksty"
  printf 'PNG obraz' >"$S/logo.png"
  printf '# O nas\n' >"$S/teksty/o-nas.md"
  printf 'x' >"$S/.DS_Store"
}

przyjmij() { run --separate-stderr "$SHCTL" skrzynka przyjmij demo --json "$@"; }
na_main() { git --git-dir "$T/remote.git" show "main:docs/00-intake/zrodla/$1"; }

@test "zielone CI: PR scalony, pliki na main, skrzynka pusta, bez worktree i galezi" {
  echo SUCCESS >"$GH_ATRAPA/ci-nowy-pr"
  przyjmij
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.stan, (.wynik.pliki | join(","))' <<<"$output" | tr '\n' ' ')" = "przyjeto logo.png,teksty/o-nas.md " ]
  [ "$(na_main logo.png)" = "PNG obraz" ]
  [ "$(na_main teksty/o-nas.md)" = "# O nas" ]
  ! na_main .DS_Store 2>/dev/null || false
  [ "$(jq -r '.[] | select(.headRefName | startswith("skrzynka/")) | .state' "$GH_ATRAPA/prs.json")" = MERGED ]
  [ ! -e "$S/logo.png" ] && [ ! -e "$S/teksty" ]
  [ -f "$S/.DS_Store" ]
  [ "$(git -C "$P" symbolic-ref --short HEAD)" = main ]
  [ -z "$(git -C "$P" for-each-ref 'refs/heads/skrzynka/*')" ]
  [ -z "$(ls "$SH_DIR/wt/demo" 2>/dev/null)" ]
}

@test "czerwone CI: kod 4, PR otwarty, skrzynka bez zmian" {
  echo FAILURE >"$GH_ATRAPA/ci-nowy-pr"
  przyjmij
  [ "$status" -eq 4 ]
  [[ "$(jq -r .blad <<<"$output")" == *"CI fail"* ]] || false
  [ -f "$S/logo.png" ]
  [ "$(jq -r '.[] | select(.headRefName | startswith("skrzynka/")) | .state' "$GH_ATRAPA/prs.json")" = OPEN ]
  [ -z "$(ls "$SH_DIR/wt/demo" 2>/dev/null)" ]
}

@test "pusta skrzynka i dry-run niczego nie wypychaja; brak skrzynki to kod 3" {
  przyjmij --dry-run
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.stan <<<"$output")" = do_przyjecia ]
  [ ! -s "$GH_ATRAPA/prs.json" ] || [ "$(jq length "$GH_ATRAPA/prs.json")" -eq 0 ]
  rm -rf "$S"/*
  przyjmij
  [ "$(jq -r .wynik.stan <<<"$output")" = pusto ]
  rm -rf "$S"
  przyjmij
  [ "$status" -eq 3 ]
}
