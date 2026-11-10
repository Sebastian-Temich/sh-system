#!/usr/bin/env bats
# docs/shctl.md generowany z pomocy shctl: repo jest zgodne, zmiana pomocy bez regeneracji to błąd.
bats_require_minimum_version 1.5.0

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  K="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$K/docs" "$K/scripts"
  cp "$REPO/docs/shctl.md" "$K/docs/"
  cp -R "$REPO/scripts/shctl" "$REPO/scripts/server" "$K/scripts/"
}

@test "docs/shctl.md w repo zgodny z pomoca" {
  run --separate-stderr bash "$REPO/scripts/docs/shctl-md.sh" --sprawdz
  echo "$stderr"
  [ "$status" -eq 0 ]
}

@test "zmiana pliku pomocy bez regeneracji: kod 1 z diffem" {
  echo "Nowe zdanie pomocy." >>"$K/scripts/shctl/pomoc/doctor.txt"
  run --separate-stderr bash "$REPO/scripts/docs/shctl-md.sh" --sprawdz "$K"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"niezgodny"* ]] || false
  [[ "$stderr" == *"Nowe zdanie pomocy."* ]] || false
}

@test "regeneracja zapisuje plik zgodny i kazda komenda ma sekcje" {
  echo "Nowe zdanie pomocy." >>"$K/scripts/shctl/pomoc/doctor.txt"
  run bash "$REPO/scripts/docs/shctl-md.sh" "$K"
  [ "$status" -eq 0 ]
  run bash "$REPO/scripts/docs/shctl-md.sh" --sprawdz "$K"
  [ "$status" -eq 0 ]
  for k in new-project stage task review sprzataj; do grep -q "^## $k\$" "$K/docs/shctl.md"; done
}

@test "komenda z przegladu bez pliku pomocy: blad" {
  rm "$K/scripts/shctl/pomoc/sprzataj.txt"
  run --separate-stderr bash "$REPO/scripts/docs/shctl-md.sh" --sprawdz "$K"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"sprzataj"* ]] || false
}
