#!/usr/bin/env bats
# Podręcznik właściciela: repo przechodzi, a nieistniejące komendy shctl i skille są wykrywane.
bats_require_minimum_version 1.5.0

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  K="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$K/docs" "$K/scripts"
  cp -R "$REPO/docs/podrecznik" "$K/docs/"
  cp "$REPO"/docs/*.md "$K/docs/"
  cp -R "$REPO/plugin" "$K/"
  cp -R "$REPO/scripts/shctl" "$REPO/scripts/server" "$K/scripts/"
  P="$K/docs/podrecznik"
}

sprawdz() { run --separate-stderr bash "$REPO/scripts/docs/sprawdz-podrecznik.sh" "$K"; }

@test "podrecznik w repo jest zgodny z kodem" {
  run --separate-stderr bash "$REPO/scripts/docs/sprawdz-podrecznik.sh"
  echo "$stderr"
  [ "$status" -eq 0 ]
  sprawdz
  [ "$status" -eq 0 ]
}

@test "nieznana komenda shctl" {
  echo 'Uruchom `shctl wdrozenie` na serwerze.' >>"$P/02-codzienna-praca.md"
  sprawdz
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"02-codzienna-praca.md:"*"nieznana komenda „shctl wdrozenie”"* ]] || false
}

@test "nieznana podkomenda shctl" {
  echo 'Potem `shctl task archive 12`.' >>"$P/02-codzienna-praca.md"
  sprawdz
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"nieznana podkomenda „shctl task archive”"* ]] || false
}

@test "znane podkomendy i komenda bez podkomendy z tekstem po nazwie" {
  {
    echo '`shctl obsidian link x`, `shctl stage done 04-architektura`, `shctl escalate close E-001`'
    echo '`shctl escalate --dotyczy "#1"`, `shctl stop-all --projekt x`, `shctl doctor`'
  } >>"$P/02-codzienna-praca.md"
  sprawdz
  echo "$stderr"
  [ "$status" -eq 0 ]
}

@test "nieznany skill sh-" {
  echo 'Skill `software-house:sh-wycena` liczy koszty.' >>"$P/01-start.md"
  sprawdz
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"nieznany skill „sh-wycena”"* ]] || false
}

@test "skrypty serwera, skille techniczne i nazwy spoza skilli sa dozwolone" {
  echo '`sh-start.sh`, `sh-watchdog`, repo `sh-system`, `sh-template-projekt`, `sh-test-RRRRMMDD`, `sh-kat-baza`' >>"$P/03-gdy-cos-nie-dziala.md"
  sprawdz
  echo "$stderr"
  [ "$status" -eq 0 ]
}

@test "linia z etap B jest pomijana" {
  {
    echo '- `shctl upgrade`: etap B (jeszcze niedostępne)'
    echo 'Skill `sh-retro` pojawi się w etapie B.'
  } >>"$P/03-gdy-cos-nie-dziala.md"
  sprawdz
  echo "$stderr"
  [ "$status" -eq 0 ]
}

@test "brak skilla roli w 01-start.md" {
  sed -i.bak 's/`sh-qa`/QA/g' "$P/01-start.md"
  sprawdz
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"01-start.md: brak skilla „sh-qa”"* ]] || false
}

@test "martwy wikilink i brak naglowka" {
  echo 'Zobacz [[proces-v1]] i [[01-start#Nie ma takiego]], a także [[proces]] i [[03-gdy-cos-nie-dziala#Logi]].' >>"$P/02-codzienna-praca.md"
  sprawdz
  echo "$stderr"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"martwy link „[[proces-v1]]”"* ]] || false
  [[ "$stderr" == *"brak nagłówka „Nie ma takiego”"* ]] || false
  [[ "$stderr" == *"2 błąd"* ]] || false
}

@test "brak katalogu podrecznika to blad uzycia" {
  rm -rf "$P"
  sprawdz
  [ "$status" -eq 2 ]
}
