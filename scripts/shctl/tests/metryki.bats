#!/usr/bin/env bats
# shctl metryki serwer: load, swap, dysk i rdzenie z sysctl i df (atrapy), bez projektu.
load helper

setup() {
  wspolny_setup
  export PATH="$BATS_TEST_DIRNAME/atrapy:$PATH"
  unset SYSCTL_BLAD SYSCTL_LOAD SYSCTL_SWAP
  export DF_GB=18
  cd "$T"
}

@test "metryki serwer: jedna probka w JSON i tekst dla czlowieka" {
  run --separate-stderr "$SHCTL" metryki serwer --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -c '.wynik | [.load.m1, .load.m5, .load.m15, .swap.used_mb, .swap.total_mb, .dysk.wolne_gb, .rdzenie, .probki]' <<<"$output")" = "[1.5,2,2.5,3277.3,4096,18,4,1]" ]
  run --separate-stderr "$SHCTL" metryki serwer
  [ "$status" -eq 0 ]
  [[ "$stderr$output" == *"load 1.5 2 2.5 (rdzenie 4), swap 3277.3 z 4096 MB, wolne 18 GB"* ]] || false
}

@test "metryki serwer --probki: srednia i maksimum load 1 min" {
  run --separate-stderr "$SHCTL" metryki serwer --probki 3 --co 0 --json
  [ "$status" -eq 0 ]
  [ "$(jq -c '.wynik | [.probki, .load_m1.srednia, .load_m1.maks]' <<<"$output")" = "[3,1.5,1.5]" ]
  SYSCTL_SWAP=1.50G run --separate-stderr "$SHCTL" metryki serwer --json
  [ "$(jq -r .wynik.swap.used_mb <<<"$output")" = 1536 ]
}

@test "metryki serwer: bledy uzycia i zablokowany sysctl" {
  run --separate-stderr "$SHCTL" metryki serwer --probki 0
  [ "$status" -eq 2 ]
  run --separate-stderr "$SHCTL" metryki
  [ "$status" -eq 2 ]
  SYSCTL_BLAD=1 run --separate-stderr "$SHCTL" metryki serwer --json
  [ "$status" -eq 1 ]
  [[ "$(jq -r .blad <<<"$output")" == *"sysctl vm.loadavg nie działa"* ]] || false
}
