#!/usr/bin/env bats
load helper-zadania

setup() { zadania_setup; }

WT() { echo "$SH_DIR/wt/demo/$1"; }

@test "dispatch: worktree na galezi z transliteracja, env, panel, claude, etykiety, stan" {
  issue 12 "Zażółć gęślą jaźń: Łódź" "status:todo,runner:local,wykonawca:claude"
  yq -i --front-matter=process '.env_files = ["config/dev.json"]' docs/konfiguracja.md
  mkdir -p config
  echo '{"k":1}' >config/dev.json
  run --separate-stderr "$SHCTL" task dispatch 12 --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(git -C "$(WT 12)" symbolic-ref --short HEAD)" = task/12-zazolc-gesla-jazn-lodz ]
  cmp .env.local "$(WT 12)/.env.local"
  cmp config/dev.json "$(WT 12)/config/dev.json"
  [ "$(jq -r '.wynik.env | join(",")' <<<"$output")" = ".env.local,config/dev.json" ]
  [ "$(etykiety_paneli)" = "worker:demo:12" ]
  grep -q "/wt/demo/12 | SH_NOTIFY=1 | --settings .claude/roles/worker/settings.json --model opus Zrealizuj issue #12 skillem sh-worker." "$CLAUDE_ATRAPA/calls"
  [ "$(etykiety 12)" = "iter:1,runner:local,status:in-progress,wykonawca:claude" ]
  [ "$(jq -r '.zadania["12"] | .label, .galaz, .uruchomiono' "$SH_DIR/stan/demo.json" | tr '\n' ' ')" = "worker:demo:12 task/12-zazolc-gesla-jazn-lodz true " ]
  jq -e '.zadania["12"].panel | startswith("w1:p")' "$SH_DIR/stan/demo.json"
  [ "$(jq -r .wynik.zaufanie_dopisane <<<"$output")" = true ]
  [ "$(jq -r --arg p "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")" '.projects[$p].hasTrustDialogAccepted' "$SH_CLAUDE_JSON")" = true ]
}

@test "dispatch: zaufanie dopisane do istniejacego ~/.claude.json bez utraty innych pol" {
  issue 12 "Zadanie" "status:todo"
  echo '{"numStartups":5,"projects":{"/inny":{"x":1}}}' >"$SH_CLAUDE_JSON"
  run --separate-stderr "$SHCTL" task dispatch 12 --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.numStartups, .projects["/inny"].x, ([.projects[] | select(.hasTrustDialogAccepted)] | length)' "$SH_CLAUDE_JSON" | tr '\n' ' ')" = "5 1 1 " ]
  [ "$(ls -l "$SH_CLAUDE_JSON" | cut -c1-10)" = "-rw-------" ]
  run --separate-stderr "$SHCTL" task dispatch 12 --json
  [ "$(jq -r .wynik.zaufanie_dopisane <<<"$output")" = false ]
}

@test "dispatch: uszkodzony ~/.claude.json to blad, plik nietkniety" {
  issue 12 "Zadanie" "status:todo"
  echo 'nie json' >"$SH_CLAUDE_JSON"
  run --separate-stderr "$SHCTL" task dispatch 12
  [ "$status" -eq 1 ]
  [ "$(cat "$SH_CLAUDE_JSON")" = "nie json" ]
}

@test "dispatch: powtorka nie dubluje panelu ani startu claude" {
  issue 12 "Zadanie" "status:todo"
  "$SHCTL" task dispatch 12
  run --separate-stderr "$SHCTL" task dispatch 12 --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.zmiana <<<"$output")" = false ]
  [ "$(wc -l <"$CLAUDE_ATRAPA/calls" | tr -d ' ')" -eq 1 ]
  [ "$(grep -c '^tab create' "$HERDR_ATRAPA/calls")" -eq 1 ]
}

@test "dispatch: niespelniona zaleznosc to odmowa" {
  issue 3 "Baza" "status:in-progress"
  issue 12 "Zadanie" "status:todo" "$(printf '### Zależności\n\n#3\n')"
  run --separate-stderr "$SHCTL" task dispatch 12
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"zależność #3 otwarta"* ]] || false
  [ ! -e "$(WT 12)" ]
}

@test "dispatch: globalny max_local liczony z workerow wszystkich projektow" {
  panel w1:p5 worker:inny:4 claude
  panel w1:p6 worker:inny:5 claude
  issue 12 "Zadanie" "status:todo"
  run --separate-stderr "$SHCTL" task dispatch 12
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"max_local=2"* ]] || false
  [ ! -s "$CLAUDE_ATRAPA/calls" ]
}

@test "dispatch: brak miejsca na dysku blokuje i powiadamia" {
  issue 12 "Zadanie" "status:todo"
  DF_GB=10 run --separate-stderr "$SHCTL" task dispatch 12
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"wolne 10 GB"* ]] || false
  grep -q '^high Brak miejsca' "$T/notified"
}

@test "dispatch: status inny niz todo to odmowa" {
  issue 12 "Zadanie" "status:review"
  run --separate-stderr "$SHCTL" task dispatch 12
  [ "$status" -eq 4 ]
}

@test "dispatch: katalog worktree zajety przez inny projekt to odmowa" {
  issue 12 "Zadanie" "status:todo"
  git init -q "$(WT 12)"
  run --separate-stderr "$SHCTL" task dispatch 12
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"nie jest worktree projektu demo"* ]] || false
}

@test "dispatch: env_files poza projektem to blad uzycia" {
  issue 12 "Zadanie" "status:todo"
  yq -i --front-matter=process '.env_files = ["../sekret"]' docs/konfiguracja.md
  run --separate-stderr "$SHCTL" task dispatch 12
  [ "$status" -eq 2 ]
}

@test "dispatch --dry-run niczego nie zmienia" {
  issue 12 "Zadanie" "status:todo"
  run --separate-stderr "$SHCTL" task dispatch 12 --dry-run --json
  [ "$status" -eq 0 ]
  [ ! -e "$(WT 12)" ]
  [ ! -s "$CLAUDE_ATRAPA/calls" ]
  [ "$(etykiety 12)" = "status:todo" ]
  ! grep -q 'issue edit' "$GH_ATRAPA/calls" || false
  [ ! -e "$SH_DIR/stan/demo.json" ]
  [ ! -e "$SH_CLAUDE_JSON" ]
}

@test "dispatch z worktree: projekt z biezacego katalogu worktree" {
  issue 12 "Zadanie" "status:todo"
  issue 13 "Drugie" "status:todo"
  "$SHCTL" task dispatch 12
  cd "$(WT 12)"
  sed -i.bak 's/^max_local: 1/max_local: 2/' "$P/docs/konfiguracja.md"
  run --separate-stderr "$SHCTL" task dispatch 13
  echo "$stderr"
  [ "$status" -eq 0 ]
  [ -d "$(WT 13)" ]
}

@test "stop-all zachowuje mape zadan" {
  issue 12 "Zadanie" "status:todo"
  "$SHCTL" task dispatch 12
  run --separate-stderr "$SHCTL" stop-all --projekt demo
  [ "$status" -eq 0 ]
  [ "$(jq -r '.powod, .zadania["12"].label' "$SH_DIR/stan/demo.json" | tr '\n' ' ')" = "stop-all worker:demo:12 " ]
}

@test "dispatch: warstwy skilli bazowe+kategoria+stack+zadanie+projekt, brakujacy skill pominiety" {
  export SH_SKILLE_PLUGINU="$T/plugin-skille" SH_WARSTWY_SKILLI="$T/warstwy.yaml"
  mkdir -p "$SH_SKILLE_PLUGINU/sh-baza" "$SH_SKILLE_PLUGINU/sh-kat-frontend" "$SH_SKILLE_PLUGINU/sh-stack-nextjs"
  for s in sh-baza sh-kat-frontend sh-stack-nextjs; do echo "# $s" >"$SH_SKILLE_PLUGINU/$s/SKILL.md"; done
  printf 'bazowe: [sh-baza]\nkategoria:\n  frontend: [sh-kat-frontend]\nstack: {}\n' >"$SH_WARSTWY_SKILLI"
  mkdir -p .claude/skills/projekt-ui
  echo "# projekt-ui" >.claude/skills/projekt-ui/SKILL.md
  git add .claude/skills && git commit -qm "skill projektu" && git push -q origin main
  w="$(jq -nc '{kategoria:"frontend", stack:["nextjs","supabase"], skille:["sh-dodatkowy"]}' | base64 | tr -d '\n')"
  issue 12 "Strona" "status:todo" "$(printf '### Cel\n\nx\n\n<!-- shctl:warstwy %s -->\n' "$w")"
  run --separate-stderr "$SHCTL" task dispatch 12 --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.skille | join(",")' <<<"$output")" = "sh-baza,sh-kat-frontend,sh-stack-nextjs,projekt-ui" ]
  [ "$(jq -r '.wynik.skille_brak | join(",")' <<<"$output")" = "sh-stack-supabase,sh-dodatkowy" ]
  [[ "$stderr" == *"brak skilla sh-stack-supabase"* ]] || false
  grep -q "Zrealizuj issue #12 skillem sh-worker. Przed pracą wczytaj skille: sh-baza, sh-kat-frontend, sh-stack-nextjs, projekt-ui." "$CLAUDE_ATRAPA/calls"
}

@test "dispatch: issue bez warstw i projekt bez skilli to polecenie bez listy" {
  export SH_SKILLE_PLUGINU="$T/pusto" SH_WARSTWY_SKILLI="$T/brak.yaml"
  issue 12 "Zadanie" "status:todo"
  run --separate-stderr "$SHCTL" task dispatch 12 --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.skille | length' <<<"$output")" -eq 0 ]
  grep -q "Zrealizuj issue #12 skillem sh-worker.$" "$CLAUDE_ATRAPA/calls"
}
