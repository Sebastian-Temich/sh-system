#!/usr/bin/env bats
# Pomoc shctl: każda komenda z przeglądu ma `shctl KOMENDA --help` (pomoc/KOMENDA.txt), --help nie
# wykonuje komendy i nie pisze logu.
load helper

setup() { wspolny_setup; }

komendy() { "$SHCTL" --help | grep -E '^  [a-z]' | awk '{print $1}' | sort -u; }

@test "shctl --help: przeglad z kodem 0, bez argumentow ten sam tekst na stderr i kod 2" {
  run "$SHCTL" --help
  [ "$status" -eq 0 ]
  [[ "$output" == "Użycie: shctl KOMENDA"* ]] || false
  run --separate-stderr "$SHCTL"
  [ "$status" -eq 2 ]
  [[ "$stderr" == "Użycie: shctl KOMENDA"* ]] || false
}

@test "kazda komenda z przegladu ma --help z linia Użycie" {
  n=0
  for k in $(komendy); do
    run "$SHCTL" "$k" --help
    echo "$k: $output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"shctl $k"* ]] || false
    n=$((n + 1))
  done
  [ "$n" -ge 16 ]
}

@test "--help po podkomendzie i argumentach nie wykonuje komendy i nie pisze logu" {
  projekt_demo
  run "$SHCTL" stage done 00-intake --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"stage iter ETAP"* ]] || false
  grep -q '^status: todo' docs/00-intake/DoD.md
  [ ! -s "$SH_DIR/logs/shctl.log" ]
}

@test "brak pliku pomocy: kod 3" {
  mkdir -p "$T/kopia"
  cp -R "$REPO/scripts/shctl" "$REPO/scripts/server" "$T/kopia/"
  rm "$T/kopia/shctl/pomoc/repo.txt"
  run --separate-stderr "$T/kopia/shctl/shctl" repo --help
  [ "$status" -eq 3 ]
  [[ "$stderr" == *"pomoc/repo.txt"* ]] || false
}
