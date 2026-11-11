#!/usr/bin/env bats
load helper-zadania

setup() { zadania_setup; }

zal() { printf '### Cel\n\nx\n\n### Zależności\n\n%s\n\n### Typ\n\nfeature\n' "$1"; }
gotowe() { jq -r '[.wynik.gotowe[].nr] | join(",")' <<<"$output"; }

@test "ready: tylko todo ze spelnionymi zaleznosciami" {
  issue 1 "Gotowe" "status:todo"
  issue 2 "Zamknięta zależność" "status:todo" "$(zal '#5')"
  issue 3 "Otwarta zależność" "status:todo" "$(zal '#1')"
  issue 4 "W toku" "status:in-progress"
  issue 5 "Done" ""
  zamknij_issue 5
  issue 6 "Anulowana zależność" "status:todo" "$(zal '#7')"
  issue 7 "Anulowane" ""
  zamknij_issue 7 NOT_PLANNED
  run --separate-stderr "$SHCTL" task ready --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(gotowe)" = "1,2" ]
  [ "$(jq -r '.wynik.zablokowane[] | "\(.nr):\(.powody[0] | split(":")[0])"' <<<"$output" | tr '\n' ';')" = "3:zależność #1 otwarta;6:zależność #7 anulowana;" ]
  [ "$(jq -r .wynik.mozna_dispatch <<<"$output")" = true ]
}

@test "ready: globalny max_local liczy panele workerow wszystkich projektow, domyslnie 2" {
  issue 1 "Gotowe" "status:todo"
  sed -i.bak '/^max_local:/d' docs/konfiguracja.md
  panel w1:p5 worker:inny:4 claude
  panel w1:p6 review:demo:2 codex
  run --separate-stderr "$SHCTL" task ready --json
  [ "$(gotowe)" = "1" ]
  [ "$(jq -r '.wynik.sloty | [.max_local, .max_local_globalny, .max_local_projektu, .aktywne, .wolne] | join(" ")' <<<"$output")" = "2 2  1 1" ]
  panel w1:p7 worker:inny:5 claude
  run --separate-stderr "$SHCTL" task ready --json
  [ "$(gotowe)" = "" ]
  [[ "$(jq -r '.wynik.blokady[0].opis' <<<"$output")" == *"max_local=2"*"wszystkie projekty"* ]] || false
  printf -- '---\nmax_local: 3\n---\n' >"$SH_DIR/konfiguracja.md"
  run --separate-stderr "$SHCTL" task ready --json
  [ "$(gotowe)" = "1" ]
}

@test "ready: max_local projektu obniza limit i liczy tylko workerow projektu" {
  issue 1 "Gotowe" "status:todo"
  panel w1:p5 worker:demo:4 claude
  run --separate-stderr "$SHCTL" task ready --json
  [ "$(gotowe)" = "" ]
  [[ "$(jq -r '.wynik.blokady[0].opis' <<<"$output")" == *"projektu demo: 1 z max_local=1"* ]] || false
  [ "$(jq -r '.wynik.sloty | [.max_local, .max_local_projektu, .aktywne_projektu, .wolne] | join(" ")' <<<"$output")" = "1 1 1 0" ]
  # Wyższa wartość w projekcie nie podnosi limitu Maca.
  sed -i.bak 's/^max_local: 1/max_local: 5/' docs/konfiguracja.md
  printf -- '---\nmax_local: 1\n---\n' >"$SH_DIR/konfiguracja.md"
  run --separate-stderr "$SHCTL" task ready --json
  [ "$(gotowe)" = "" ]
  [ "$(jq -r .wynik.sloty.max_local <<<"$output")" = 1 ]
}

@test "ready: db:migracja maksymalnie jedna naraz w projekcie" {
  issue 1 "Migracja A" "status:todo,db:migracja"
  issue 2 "Migracja B" "status:todo,db:migracja"
  issue 3 "Zwykłe" "status:todo"
  run --separate-stderr "$SHCTL" task ready --json
  [ "$(gotowe)" = "1,3" ]
  [[ "$(jq -r '.wynik.zablokowane[0].powody[0]' <<<"$output")" == "db:migracja: w projekcie trwa #1" ]] || false
  issue 4 "Migracja w toku" "status:review,db:migracja"
  run --separate-stderr "$SHCTL" task ready --json
  [ "$(gotowe)" = "3" ]
}

@test "ready: wstrzymanie Claude w limity.md blokuje, samo Codexa nie" {
  issue 1 "Gotowe" "status:todo"
  printf '# Limity\n\n- codex: limit do 18:00\n' >"$SH_DIR/limity.md"
  run --separate-stderr "$SHCTL" task ready --json
  [ "$(gotowe)" = "1" ]
  printf '# Limity\n\n| Wykonawca | Do |\n|---|---|\n| claude | 2026-11-02 18:00 |\n' >"$SH_DIR/limity.md"
  run --separate-stderr "$SHCTL" task ready --json
  [ "$(gotowe)" = "" ]
  [ "$(jq -r '.wynik.blokady[0].rodzaj' <<<"$output")" = limit ]
  printf '# Limity\n\n- brak\n' >"$SH_DIR/limity.md"
  run --separate-stderr "$SHCTL" task ready --json
  [ "$(gotowe)" = "1" ]
}

@test "ready: brak miejsca blokuje i powiadamia raz dziennie" {
  issue 1 "Gotowe" "status:todo"
  DF_GB=14 run --separate-stderr "$SHCTL" task ready --json
  [ "$(gotowe)" = "" ]
  [ "$(jq -r '.wynik.blokady[0].rodzaj, .wynik.wolne_gb' <<<"$output" | tr '\n' ' ')" = "dysk 14 " ]
  DF_GB=14 "$SHCTL" task ready >/dev/null
  [ "$(grep -c 'Brak miejsca' "$T/notified")" -eq 1 ]
  DF_GB=30 "$SHCTL" task ready >/dev/null
  [ ! -e "$SH_DIR/stan/dysk-alarm" ]
  yq -i --front-matter=process '.min_wolne_gb = 40' docs/konfiguracja.md
  DF_GB=30 run --separate-stderr "$SHCTL" task ready --json
  [ "$(gotowe)" = "" ]
}

@test "ready: kolejka review max_review_queue zatrzymuje dispatch" {
  issue 1 "Gotowe" "status:todo"
  issue 2 "R1" "status:review"
  issue 3 "R2" "status:review"
  run --separate-stderr "$SHCTL" task ready --json
  [ "$(gotowe)" = "1" ]
  issue 4 "R3" "status:review"
  run --separate-stderr "$SHCTL" task ready --json
  [ "$(gotowe)" = "" ]
  [ "$(jq -r '.wynik.blokady[0].rodzaj, .wynik.kolejka_review.czeka' <<<"$output" | tr '\n' ' ')" = "kolejka_review 3 " ]
}

@test "ready: tekst dla czlowieka i serwer herdr niedostepny" {
  issue 1 "Gotowe" "status:todo"
  run --separate-stderr "$SHCTL" task ready
  [[ "$output" == *"Gotowe: #1 Gotowe"* ]] || false
  touch "$HERDR_ATRAPA/down"
  run --separate-stderr "$SHCTL" task ready
  [ "$status" -eq 3 ]
}

@test "ready --czekaj: czeka na wolny slot, bez petli po stronie orkiestratora" {
  issue 1 "Gotowe" "status:todo"
  panel w1:p5 worker:demo:4 claude
  # Slot zwalnia się w trakcie czekania (panel workera znika).
  ( sleep 2; jq 'map(select(.pane_id != "w1:p5"))' "$HERDR_ATRAPA/panele.json" >"$T/p.n" && mv "$T/p.n" "$HERDR_ATRAPA/panele.json" ) &
  SHCTL_READY_PAUZA=1 run --separate-stderr "$SHCTL" task ready --czekaj --timeout 30 --json
  wait
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(gotowe)" = "1" ]
  [ "$(jq -r '.wynik.limit_czasu' <<<"$output")" = false ]
  [ "$(jq -r '.wynik.czekano_s' <<<"$output")" -ge 1 ]
}

@test "ready --czekaj: limit czasu przy zajetym slocie, bez kandydatow wraca od razu" {
  issue 1 "Gotowe" "status:todo"
  panel w1:p5 worker:demo:4 claude
  SHCTL_READY_PAUZA=1 run --separate-stderr "$SHCTL" task ready --czekaj --timeout 2 --json
  [ "$(jq -r '.wynik.limit_czasu, .wynik.mozna_dispatch' <<<"$output" | tr '\n' ' ')" = "true false " ]
  zamknij_issue 1
  # Pauza 5 s: wynik bez czekania to czekano_s < 5 (sama ocena może przejść granicę sekundy).
  SHCTL_READY_PAUZA=5 run --separate-stderr "$SHCTL" task ready --czekaj --timeout 600 --json
  [ "$(jq -r '.wynik.limit_czasu' <<<"$output")" = false ]
  [ "$(jq -r '.wynik.czekano_s' <<<"$output")" -lt 5 ]
}

@test "ready i dispatch: niekompletna lista startowa wstrzymuje realizacje" {
  issue 1 "Gotowe" "status:todo"
  mkdir -p docs/00-intake
  printf '# Lista startowa\n\n```\n- [ ] w bloku kodu nie liczy sie\n```\n\n- [x] konto Vercel\n- [-] domena (nie dotyczy: alias)\n- [ ] klucz testowy Resend\n' >docs/00-intake/lista-startowa.md
  run --separate-stderr "$SHCTL" task ready --json
  [ "$(jq -r '.wynik.blokady[] | select(.rodzaj == "lista_startowa") | .opis' <<<"$output")" = "lista startowa: 1 pozycji bez potwierdzenia (docs/00-intake/lista-startowa.md)" ]
  run --separate-stderr "$SHCTL" task dispatch 1
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"lista startowa"* ]] || false
  sed -i.bak 's/- \[ \] klucz/- [x] klucz/' docs/00-intake/lista-startowa.md
  run --separate-stderr "$SHCTL" task ready --json
  [ "$(jq -r '[.wynik.blokady[] | select(.rodzaj == "lista_startowa")] | length' <<<"$output")" = 0 ]
  [ "$(gotowe)" = "1" ]
}

@test "ready: pola - [ ] w komentarzu HTML listy startowej nie blokuja (dryrun 5)" {
  issue 1 "Gotowe" "status:todo"
  mkdir -p docs/00-intake
  printf '# Lista startowa\n\n<!-- Przykład:\n- [ ] konto Vercel\n- [ ] klucz testowy\n-->\n<!-- - [ ] w jednej linii --> - [x] konto GitHub\n\n- [x] repo\n' >docs/00-intake/lista-startowa.md
  run --separate-stderr "$SHCTL" task ready --json
  echo "$output $stderr"
  [ "$(jq -r '[.wynik.blokady[] | select(.rodzaj == "lista_startowa")] | length' <<<"$output")" = 0 ]
  [ "$(gotowe)" = 1 ]
  # Pole poza komentarzem po komentarzu w tej samej linii nadal się liczy.
  printf '<!-- x --> - [ ] po komentarzu\n' >>docs/00-intake/lista-startowa.md
  run --separate-stderr "$SHCTL" task ready --json
  [[ "$(jq -r '.wynik.blokady[] | select(.rodzaj == "lista_startowa") | .opis' <<<"$output")" == "lista startowa: 1 pozycji"* ]] || false
}

@test "ready: zaleznosci tylko z pola strukturalnego, nie z notatek ani innych sekcji" {
  issue 1 "Otwarte" "status:todo"
  issue 2 "Notatka pod lista" "status:todo" "$(zal "brak

Uwaga: wcześniej #1, usunięte po decyzji E-001.")"
  issue 3 "Lista z notatka w linii" "status:todo" "$(zal "#5 (po #1)")"
  issue 4 "Wzmianka w celu" "status:todo" "### Cel

Jak w #1.

### Zależności

brak"
  issue 5 "Done" ""
  zamknij_issue 5
  run --separate-stderr "$SHCTL" task ready --json
  echo "$output $stderr"
  [ "$(gotowe | tr ',' '\n' | sort -n | paste -sd, -)" = "1,2,3,4" ]
}

@test "ready i deps: anulowana zaleznosc blokuje z propozycja, task deps --usun odblokowuje" {
  issue 7 "Anulowane" ""
  zamknij_issue 7 NOT_PLANNED
  issue 8 "Zależne" "status:todo" "$(zal "#7, #9")"
  issue 9 "Done" ""
  zamknij_issue 9
  run --separate-stderr "$SHCTL" task ready
  echo "$output $stderr"
  [[ "$output" == *"#8: zależność #7 anulowana: zadanie zablokowane; usuń zależność (shctl task deps 8 --usun #7) albo eskaluj"* ]] || false
  run --separate-stderr "$SHCTL" task deps 8 --json
  [ "$(jq -c .wynik.zaleznosci <<<"$output")" = "[7,9]" ]
  [ "$(jq -r .wynik.zmiana <<<"$output")" = false ]
  run --separate-stderr "$SHCTL" task deps "#8" --usun "#7" --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -c '.wynik | [.poprzednie, .zaleznosci, .zmiana]' <<<"$output")" = "[[7,9],[9],true]" ]
  body="$(jq -r '.[] | select(.number == 8) | .body' "$GH_ATRAPA/issues.json")"
  [[ "$body" == *"### Zależności"$'\n\n'"#9"$'\n\n'"### Typ"* ]] || false
  jq -r '.[] | select(.number == 8) | .comments[].body' "$GH_ATRAPA/issues.json" | grep -qF "Zależności: #9 (shctl task deps)."
  run --separate-stderr "$SHCTL" task ready --json
  [[ ",$(gotowe)," == *",8,"* ]] || false
  # Powtórka bez zmian; ostatnia zależność daje „brak”.
  run --separate-stderr "$SHCTL" task deps 8 --usun 7 --json
  [ "$(jq -r .wynik.zmiana <<<"$output")" = false ]
  "$SHCTL" task deps 8 --usun 9 >/dev/null
  body="$(jq -r '.[] | select(.number == 8) | .body' "$GH_ATRAPA/issues.json")"
  [[ "$body" == *"### Zależności"$'\n\n'"brak"$'\n\n'"### Typ"* ]] || false
}

@test "deps: --dodaj tworzy sekcje, gdy jej brak, i odrzuca zaleznosc od siebie" {
  issue 3 "Bez sekcji" "status:todo" "### Cel

x"
  issue 4 "Inne" "status:todo"
  run --separate-stderr "$SHCTL" task deps 3 --dodaj 3
  [ "$status" -eq 2 ]
  run --separate-stderr "$SHCTL" task deps 3 --dodaj 99
  [ "$status" -eq 3 ]
  run --separate-stderr "$SHCTL" task deps 3 --dodaj 4 --json
  echo "$output $stderr"
  [ "$(jq -c .wynik.zaleznosci <<<"$output")" = "[4]" ]
  run --separate-stderr "$SHCTL" task ready --json
  [ "$(jq -r '.wynik.zablokowane[] | select(.nr == 3) | .powody[0]' <<<"$output")" = "zależność #4 otwarta" ]
}

@test "ready: najpierw zadania na sciezce krytycznej (najdluzszy lancuch zaleznosci)" {
  issue 1 "Samodzielne" "status:todo"
  issue 2 "Krótki łańcuch" "status:todo"
  issue 3 "Długi łańcuch" "status:todo"
  issue 4 "Po #2" "status:todo" "$(zal '#2')"
  issue 5 "Po #3" "status:todo" "$(zal '#3')"
  issue 6 "Po #5" "status:todo" "$(zal '#5')"
  issue 7 "Po #6 i #4" "status:todo" "$(zal '#6, #4')"
  printf -- '---\nmax_local: 5\n---\n' >"$SH_DIR/konfiguracja.md"
  sed -i.bak 's/^max_local: 1/max_local: 5/' docs/konfiguracja.md
  run --separate-stderr "$SHCTL" task ready --json
  echo "$output $stderr"
  [ "$(gotowe)" = "3,2,1" ]
  [ "$(jq -r '[.wynik.gotowe[].sciezka] | join(",")' <<<"$output")" = "4,3,1" ]
}
