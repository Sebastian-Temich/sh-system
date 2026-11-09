# Środowisko testów task, review i reset-dryrun: projekt z prawdziwym gitem (zdalne repo lokalne pod
# adresem GitHuba), stanowe atrapy gh, herdr, codex, claude i df z katalogu atrapy/.
load helper

zadania_setup() {
  wspolny_setup
  export PATH="$BATS_TEST_DIRNAME/atrapy:$PATH"
  export GH_ATRAPA="$T/gh" HERDR_ATRAPA="$T/herdr" CODEX_ATRAPA="$T/codex" CLAUDE_ATRAPA="$T/claude"
  export CODEX_HOME="$T/codex-home" SH_SYSTEM_DIR="$T/sys" SHCTL_REVIEW_TIMEOUT=20 SH_CLAUDE_JSON="$T/claude.json"
  export SHCTL_MERGEABLE_PROBY=1 SHCTL_CI_PAUZA=0
  unset DF_GB SHCTL_DRYRUN_NAZWA
  mkdir -p "$GH_ATRAPA" "$HERDR_ATRAPA" "$CODEX_ATRAPA" "$CLAUDE_ATRAPA" "$CODEX_HOME"
  : >"$CLAUDE_ATRAPA/calls"
  : >"$CODEX_ATRAPA/calls"
  wynik_codex PASS '[]'
  R=test-owner/demo
  projekt_z_remote
  system_z_remote
}

# Szablon projektu z plikami potrzebnymi zadaniom; origin na zdalnym repo lokalnym.
projekt_z_remote() {
  local s="$T/szablon"
  git init -q "$s"
  szablon_projektu "$s"
  mkdir -p "$s/.claude/roles/worker" "$s/docs/06-zadania"
  echo '{}' >"$s/.claude/roles/worker/settings.json"
  printf '.env*\n!.env.example\n' >"$s/.gitignore"
  printf 'KLUCZ=\n' >"$s/.env.example"
  printf '# Zadania\n\n<!-- sync-status:start -->\n| Zadanie | Tytuł |\n|---|---|\n<!-- sync-status:end -->\n' >"$s/docs/06-zadania/index.md"
  printf '# Metryki\n\n| Zlecenie | Tryb | Czas | Zadania | Iteracje | Eskalacje | Uwagi |\n|---|---|---|---|---|---|---|\n' >"$s/docs/metryki.md"
  printf '# Backlog drobnych uwag\n\n| Data | Źródło | Uwaga | Stan |\n|---|---|---|---|\n' >"$s/docs/backlog-drobne.md"
  printf '# Changelog\n\nPlik wspólny.\n' >"$s/CHANGELOG.md"
  printf '#!/usr/bin/env bash\necho "$*" >>"${SYNC_LOG:-/dev/null}"\n' >"$s/scripts/sync-status.sh"
  chmod +x "$s/scripts/sync-status.sh"
  git -C "$s" add -A
  git -C "$s" commit -qm start
  git clone -q --bare "$s" "$T/remote.git"
  git config --global url."$T/remote.git".insteadOf https://github.com/test-owner/demo.git
  P="$SH_DIR/projekty/demo"
  git clone -q https://github.com/test-owner/demo.git "$P"
  printf 'SEKRET=testowy\n' >"$P/.env.local"
  export SYNC_LOG="$T/sync.calls"
  cd "$P"
}

system_z_remote() {
  local s="$T/sys-src"
  git init -q "$s"
  mkdir -p "$s/docs"
  printf '# sh-system\n' >"$s/README.md"
  git -C "$s" add -A
  git -C "$s" commit -qm start
  git clone -q --bare "$s" "$T/sys.git"
  git config --global url."$T/sys.git".insteadOf https://github.com/test-owner/sh-system.git
  git clone -q https://github.com/test-owner/sh-system.git "$SH_SYSTEM_DIR"
}

# Issue w atrapie GitHuba: issue NR "tytuł" "etykieta,etykieta" ["treść"]
issue() {
  local body="${4:-### Cel

Cel.

### Zależności

brak}"
  jq --arg r "$R" --argjson n "$1" --arg t "$2" --arg l "$3" --arg b "$body" \
    '. + [{repo:$r, number:$n, title:$t, body:$b, state:"OPEN", stateReason:null,
      labels:($l | split(",") | map(select(length > 0) | {name:.})), milestone:null,
      createdAt:"2026-11-01T10:00:00Z"}]' "$GH_ATRAPA/issues.json" 2>/dev/null >"$T/i.json" ||
    jq -n --arg r "$R" --argjson n "$1" --arg t "$2" --arg l "$3" --arg b "$body" \
      '[{repo:$r, number:$n, title:$t, body:$b, state:"OPEN", stateReason:null,
        labels:($l | split(",") | map(select(length > 0) | {name:.})), milestone:null,
        createdAt:"2026-11-01T10:00:00Z"}]' >"$T/i.json"
  mv "$T/i.json" "$GH_ATRAPA/issues.json"
  [ "$(cat "$GH_ATRAPA/licznik" 2>/dev/null || echo 0)" -ge "$1" ] || echo "$1" >"$GH_ATRAPA/licznik"
}

zamknij_issue() {
  jq --argjson n "$1" --arg s "${2:-COMPLETED}" 'map(if .number == $n then .state = "CLOSED" | .stateReason = $s else . end)' \
    "$GH_ATRAPA/issues.json" >"$T/i.json" && mv "$T/i.json" "$GH_ATRAPA/issues.json"
}

etykiety() { jq -r --argjson n "$1" '.[] | select(.number == $n) | [.labels[].name] | sort | join(",")' "$GH_ATRAPA/issues.json"; }
stan_issue() { jq -r --argjson n "$1" '.[] | select(.number == $n) | .state' "$GH_ATRAPA/issues.json"; }

# Panel w atrapie herdr: panel ID ETYKIETA [AGENT]
panel() {
  [ -f "$HERDR_ATRAPA/panele.json" ] || echo '[]' >"$HERDR_ATRAPA/panele.json"
  jq --arg p "$1" --arg l "$2" --arg a "${3:-}" --arg s "${4:-}" \
    '. + [{pane_id:$p, workspace_id:"w1", label:$l, agent:$a, agent_status:$s, cwd:"/tmp"}]' \
    "$HERDR_ATRAPA/panele.json" >"$T/p.json" && mv "$T/p.json" "$HERDR_ATRAPA/panele.json"
}
etykiety_paneli() { jq -r '[.[].label // ""] | join(" ")' "$HERDR_ATRAPA/panele.json" 2>/dev/null; }

wynik_codex() {
  jq -n --arg w "$1" --argjson z "$2" '{werdykt:$w, podsumowanie:"Podsumowanie review.", zgloszenia:$z}' >"$CODEX_ATRAPA/wynik.json"
}

# Praca workera: commit w worktree, push gałęzi, PR w atrapie (z refs/pull/N/head). pr_workera NR PR [CI]
pr_workera() {
  local nr="$1" prn="$2" ci="${3:-SUCCESS}" wt="$SH_DIR/wt/demo/$1" br sha
  br="$(git -C "$wt" symbolic-ref --short HEAD)"
  mkdir -p "$wt/docs/07-realizacja"
  cat >"$wt/docs/07-realizacja/T-$nr.md" <<MD
# Raport T-$nr: zadanie

## Co zrobiono

Kod.

## Decyzje

- Format daty → ISO 8601, bo prościej sortować
- Walidacja po stronie serwera

## Drobne uwagi

- Nazwa funkcji \`x\` mało czytelna
  do zmiany przy okazji

## Propozycje dla systemu

- shctl mógłby sam uruchamiać lint
MD
  printf 'praca %s\n' "$nr" >"$wt/src/praca-$nr.txt"
  git -C "$wt" add -A
  git -C "$wt" commit -qm "#$nr: praca"
  git -C "$wt" push -q origin "$br" "$br:refs/pull/$prn/head"
  sha="$(git -C "$wt" rev-parse HEAD)"
  jq --arg r "$R" --argjson n "$prn" --argjson i "$nr" --arg b "$br" --arg s "$sha" --arg c "$ci" \
    '. + [{repo:$r, number:$n, title:"Zadanie \($i)", state:"OPEN", headRefName:$b, headRefOid:$s,
      closingIssuesReferences:[{number:$i}], url:"https://github.com/\($r)/pull/\($n)",
      createdAt:"2026-11-01T10:00:00Z", comments:[], mergeable:"MERGEABLE",
      files:[{path:"docs/07-realizacja/T-\($i).md"}, {path:"src/praca-\($i).txt"}],
      statusCheckRollup:[{status:"COMPLETED", conclusion:$c}]}]' "$GH_ATRAPA/prs.json" 2>/dev/null >"$T/pr.json" ||
    jq -n --arg r "$R" --argjson n "$prn" --argjson i "$nr" --arg b "$br" --arg s "$sha" --arg c "$ci" \
      '[{repo:$r, number:$n, title:"Zadanie \($i)", state:"OPEN", headRefName:$b, headRefOid:$s,
        closingIssuesReferences:[{number:$i}], url:"https://github.com/\($r)/pull/\($n)",
        createdAt:"2026-11-01T10:00:00Z", comments:[], mergeable:"MERGEABLE",
      files:[{path:"docs/07-realizacja/T-\($i).md"}, {path:"src/praca-\($i).txt"}],
        statusCheckRollup:[{status:"COMPLETED", conclusion:$c}]}]' >"$T/pr.json"
  mv "$T/pr.json" "$GH_ATRAPA/prs.json"
  [ "$(cat "$GH_ATRAPA/licznik" 2>/dev/null || echo 0)" -ge "$prn" ] || echo "$prn" >"$GH_ATRAPA/licznik"
}

ustaw_ci() {
  jq --argjson n "$1" --arg c "$2" 'map(if .number == $n then .statusCheckRollup = [{status:"COMPLETED", conclusion:$c}] else . end)' \
    "$GH_ATRAPA/prs.json" >"$T/pr.json" && mv "$T/pr.json" "$GH_ATRAPA/prs.json"
}

komentarze() { jq -r --argjson n "$1" '.[] | select(.number == $n) | .comments[].body' "$GH_ATRAPA/prs.json"; }

# Zadanie gotowe do dispatchu i dispatch: zadanie_w_toku NR
zadanie_w_toku() {
  issue "$1" "Zadanie $1" "status:todo,runner:local,wykonawca:claude"
  "$SHCTL" task dispatch "$1" >/dev/null
}
