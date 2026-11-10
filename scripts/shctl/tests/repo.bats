#!/usr/bin/env bats
load helper

setup() { wspolny_setup; projekt_demo; }

@test "repo opis --dry-run: komenda do pokazania, bez zmian na GitHubie" {
  run --separate-stderr "$SHCTL" repo opis --opis "Sklep z kawą" --topics "nextjs, supabase" --website https://kawa.pl --dry-run --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.komenda <<<"$output")" = "gh repo edit test-owner/demo --description 'Sklep z kawą' --homepage https://kawa.pl --add-topic sh-projekt --add-topic nextjs --add-topic supabase" ]
  [ "$(jq -c .wynik.tematy <<<"$output")" = '["sh-projekt","nextjs","supabase"]' ]
  run --separate-stderr "$SHCTL" repo opis --opis "Sklep" --dry-run
  [[ "$output$stderr" == *"Komenda do pokazania właścicielowi: gh repo edit test-owner/demo --description Sklep --add-topic sh-projekt"* ]] || false
  ! grep -q '^repo edit' "$T/gh.calls" || false
}

@test "repo opis: wykonanie, temat sh-projekt zawsze" {
  run --separate-stderr "$SHCTL" repo opis --topics astro
  [ "$status" -eq 0 ]
  grep -qx 'repo edit test-owner/demo --add-topic sh-projekt --add-topic astro' "$T/gh.calls"
}

@test "repo opis: bledy uzycia" {
  run --separate-stderr "$SHCTL" repo opis
  [ "$status" -eq 2 ]
  run --separate-stderr "$SHCTL" repo opis --opis "$(printf 'x%.0s' $(seq 1 351))"
  [ "$status" -eq 2 ]
  run --separate-stderr "$SHCTL" repo opis --website http://kawa.pl
  [ "$status" -eq 2 ]
  run --separate-stderr "$SHCTL" repo opis --topics "Duze,Litery"
  [ "$status" -eq 2 ]
  run --separate-stderr "$SHCTL" repo inne
  [ "$status" -eq 2 ]
}
