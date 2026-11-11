#!/usr/bin/env bats
# shctl escalate dla zadania: zapis na main także z worktree, jedna numeracja, zwolnienie slotu.
load helper-zadania

setup() {
  zadania_setup
  zadanie_w_toku 12
}

esk() { "$SHCTL" escalate --dotyczy "#$1" --powod "$2" --sytuacja "stan testowy" --sprawdzono "nic poza testem" --potrzebne "decyzja" --json; }

@test "escalate z worktree: plik w glownej kopii na main, nie w worktree" {
  cd "$SH_DIR/wt/demo/12"
  run --separate-stderr esk 12 "sprzeczne kryteria"
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.id, .wynik.z_worktree' <<<"$output" | tr '\n' ' ')" = "E-001 true " ]
  [ -f "$P/docs/07-realizacja/escalations/E-001.md" ]
  [ ! -e "$SH_DIR/wt/demo/12/docs/07-realizacja/escalations/E-001.md" ]
  [ -z "$(git -C "$SH_DIR/wt/demo/12" status --porcelain)" ]
  grep -q -- '--repo' "$T/sync.calls"
  # Druga eskalacja z głównej kopii dostaje kolejny numer.
  cd "$P"
  issue 13 "Inne" "status:todo"
  run --separate-stderr esk 13 "brak klucza"
  [ "$(jq -r .wynik.id <<<"$output")" = E-002 ]
}

@test "escalate z worktree: glowna kopia poza main to odmowa" {
  git -C "$P" checkout -q -b inna
  cd "$SH_DIR/wt/demo/12"
  run --separate-stderr esk 12 "x"
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"nie na main"* ]] || false
}

@test "escalate zadania zwalnia slot, dispatch po rozstrzygnieciu wraca do panelu" {
  issue 13 "Kolejne" "status:todo,runner:local,wykonawca:claude"
  run --separate-stderr esk 12 "3 iteracje bez PASS"
  [ "$(jq -r .wynik.slot_zwolniony <<<"$output")" = true ]
  [ "$(etykiety_paneli)" = "eskalacja:demo:12" ]
  run --separate-stderr "$SHCTL" task dispatch 13
  [ "$status" -eq 0 ]
  "$SHCTL" escalate close E-001 --odpowiedz "kontynuuj" >/dev/null
  # Slot zajęty przez #13 (max_local projektu 1): powrót #12 czeka.
  run --separate-stderr "$SHCTL" task dispatch 12
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"max_local"* ]] || false
  "$SHCTL" task close 13 --anuluj >/dev/null
  run --separate-stderr "$SHCTL" task dispatch 12 --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(etykiety_paneli)" = "worker:demo:12" ]
  [ "$(jq -r .wynik.uruchomiono <<<"$output")" = false ]
}
