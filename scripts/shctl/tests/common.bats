#!/usr/bin/env bats
load helper

setup() { wspolny_setup; }

@test "bez argumentow: kod 2" {
  run --separate-stderr "$SHCTL"
  [ "$status" -eq 2 ]
}

@test "nieznana komenda: kod 2" {
  run --separate-stderr "$SHCTL" nie-ma-takiej
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"nieznana komenda"* ]] || false
}

@test "dziala przez symlink i zapisuje log" {
  ln -s "$SHCTL" "$T/shctl-link"
  projekt_demo
  run "$T/shctl-link" stage start 00-intake
  [ "$status" -eq 0 ]
  grep -q 'rc=0 dry=0 projekt=demo stage start' "$SH_DIR/logs/shctl.log"
}

@test "--projekt dziala spoza katalogu projektu" {
  projekt_demo
  cd "$T"
  run "$SHCTL" status show --projekt demo
  [ "$status" -eq 0 ]
  [[ "$output" == *"Projekt: demo"* ]] || false
}

@test "poza projektem bez --projekt: kod 3" {
  cd "$T"
  run --separate-stderr "$SHCTL" status show
  [ "$status" -eq 3 ]
}

@test "--projekt z ../ jest odrzucone" {
  run --separate-stderr "$SHCTL" status show --projekt ../x
  [ "$status" -eq 2 ]
}

@test "--json przy bledzie daje jeden dokument z kodem" {
  cd "$T"
  run --separate-stderr "$SHCTL" status show --json
  [ "$status" -eq 3 ]
  [ "$(jq -r '.ok, .kod' <<<"$output" | tr '\n' ' ')" = "false 3 " ]
  [[ "$(jq -r .blad <<<"$output")" == *"katalog projektu"* ]] || false
}

@test "--json przy bledzie w podpowloce tez ma tresc" {
  projekt_demo
  run --separate-stderr "$SHCTL" stage done 00-intake --json
  [ "$status" -eq 4 ]
  [[ "$(jq -r .blad <<<"$output")" == *"niedozwolone"* ]] || false
}

@test "worktree: projekt to nazwa repo glownego" {
  projekt_demo
  git worktree add -q "$T/wt-1" -b task/1
  cd "$T/wt-1"
  run "$SHCTL" status show --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.projekt <<<"$output")" = demo ]
}
