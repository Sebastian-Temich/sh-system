#!/usr/bin/env bats
load helper-zadania

setup() {
  zadania_setup
  issue 12 "Zadanie" "status:todo" "$(printf '### Cel\n\nx\n\n### Komenda testów\n\n```sh\ntest -f src/app.txt\n```\n\n### Typ\n\nfeature\n')"
  "$SHCTL" task dispatch 12 >/dev/null
  WT12="$SH_DIR/wt/demo/12"
}

@test "resume-check: zmiany, roznica z main i testy z issue" {
  echo zmiana >"$WT12/src/nowy.txt"
  printf 'nowy main\n' >"$P/src/main.txt"
  git -C "$P" add -A && git -C "$P" commit -qm main && git -C "$P" push -q origin main
  run --separate-stderr "$SHCTL" task resume-check 12 --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.git.niezacommitowane | join(",")' <<<"$output")" = "?? src/nowy.txt" ]
  [ "$(jq -r '.wynik.git.za_main, .wynik.git.przed_main' <<<"$output" | tr '\n' ' ')" = "1 0 " ]
  [ "$(jq -r '.wynik.testy.komenda, .wynik.testy.wynik' <<<"$output" | tr '\n' ' ')" = "test -f src/app.txt pass " ]
  [ "$(jq -r '.wynik.sugestia, .wynik.iteracja' <<<"$output" | tr '\n' ' ')" = "rebase i kontynuuj 1 " ]
  [ "$(jq -r '.wynik.panel.label' <<<"$output")" = "worker:demo:12" ]
}

@test "resume-check: nieudane testy i --testy" {
  run --separate-stderr "$SHCTL" task resume-check 12 --testy "false" --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.testy.wynik, .wynik.testy.kod' <<<"$output" | tr '\n' ' ')" = "fail 1 " ]
  [ "$(jq -r .wynik.sugestia <<<"$output")" = kontynuuj ]
}

@test "resume-check: nie zmienia etykiet ani iteracji" {
  before="$(etykiety 12)"
  : >"$GH_ATRAPA/calls"
  run --separate-stderr "$SHCTL" task resume-check 12 --bez-testow --json
  [ "$status" -eq 0 ]
  [ "$(etykiety 12)" = "$before" ]
  ! grep -q 'issue edit' "$GH_ATRAPA/calls" || false
  [ "$(jq -r .wynik.testy.wynik <<<"$output")" = pominiete ]
}

@test "resume-check: bez worktree sugeruje iteracje od nowa" {
  git worktree remove --force "$WT12"
  run --separate-stderr "$SHCTL" task resume-check 12 --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.worktree_istnieje, .wynik.sugestia' <<<"$output" | tr '\n' ' ')" = "false iteracja od nowa " ]
}
