# shctl stop-all [--projekt NAZWA]: awaryjny stop (proces-v1.md, „Awaryjny stop”).
# Panele: worker:NAZWA:NR, review:NAZWA:NR, qa:NAZWA:NR, agent z katalogiem w projekty/NAZWA,
# orkiestrator:NAZWA oraz wspólny „orkiestrator”. Bez --projekt zatrzymuje wszystko.
# Z --projekt tylko ten projekt: wspólny orkiestrator obsługuje też inne projekty i zostaje.
# Panel „powloka” i panele bez agenta nie są ruszane. Worktree zostają. shctl nie wznawia sam.
# shellcheck shell=bash

wszystkie_panele() {
  local w
  herdr workspace list | jq -r '.result.workspaces[].workspace_id' | while IFS= read -r w; do
    herdr pane list --workspace "$w" | jq -c '.result.panes[]'
  done | jq -sc --arg r "$PROJEKTY/" '
    map(. + {
      kat: (.foreground_cwd // .cwd // ""),
      l: (.label // "")
    }
    | . + {
      rodzaj: (
        if .l == "orkiestrator" then "orkiestrator"
        elif (.l | test("^orkiestrator:")) then "orkiestrator"
        elif (.l | test("^(worker|review|qa):")) then "worker"
        elif .l != "powloka" and (.agent // "") != "" and (.kat | startswith($r)) then "worker"
        else "inny" end),
      projekt: (
        if (.l | test("^(worker|review|qa|orkiestrator):")) then (.l | split(":")[1])
        elif (.kat | startswith($r)) then (.kat | ltrimstr($r) | split("/")[0])
        else "" end)
    })
    | map(select(.rodzaj != "inny")
      | {pane_id, label: .l, cwd: .kat, agent: (.agent // ""), agent_status: (.agent_status // ""), rodzaj, projekt})'
}

stan_git() {
  local r="$1"
  if ! git -C "$r" rev-parse --git-dir >/dev/null 2>&1; then
    echo '{}'
    return
  fi
  jq -nc --arg g "$(git -C "$r" symbolic-ref --short -q HEAD || true)" \
    --arg h "$(git -C "$r" rev-parse HEAD 2>/dev/null || true)" \
    --argjson z "$(git -C "$r" status --porcelain | wc -l | tr -d ' ')" \
    --argjson w "$(git -C "$r" worktree list --porcelain | awk '/^worktree /{print substr($0, 10)}' | jq -Rsc 'split("\n") | map(select(length > 0))')" \
    '{galaz:$g, head:$h, niezacommitowane:$z, worktree:$w}'
}

zapisz_stan() {
  local p="$1" panele="$2" orch="$3" plik r git_j='{}' etap=""
  plik="$STAN/$p.json"
  r="$PROJEKTY/$p"
  # Powtórka po zamknięciu paneli nie może skasować listy tego, co działało.
  if [ "$(jq 'length' <<<"$panele")" -eq 0 ] && [ -f "$plik" ]; then
    info "$p: stan zachowany bez zmian ($plik)"
    return 1
  fi
  if [ -d "$r" ]; then git_j="$(stan_git "$r")"; fi
  if [ -f "$r/docs/konfiguracja.md" ] && command -v yq >/dev/null; then
    KONFIG="$r/docs/konfiguracja.md"
    ROOT="$r"
    etap="$(opis_etapu)"
  fi
  mkdir -p "$STAN"
  jq -n --arg p "$p" --arg t "$(date '+%FT%T%z')" --argjson k "$panele" --argjson g "$git_j" \
    --arg e "$etap" --argjson o "$orch" \
    '{projekt:$p, czas:$t, powod:"stop-all", panele:$k, orkiestrator_zatrzymany:($o == 1), etap:$e, git:$g}' >"$plik"
  return 0
}

komenda_main() {
  local panele wybrane teraz na_koncu lista p ile orch=0 bledy=0 zmiana=0 id wynik kolejnosc
  while [ $# -gt 0 ]; do opcja_wspolna "$@"; shift "$ZJEDZONE"; done
  wymagaj jq herdr
  [ -z "$PROJEKT" ] || sprawdz_nazwe "$PROJEKT"
  herdr workspace list >/dev/null 2>&1 || die "$E_BRAK" "serwer herdr nie odpowiada"

  panele="$(wszystkie_panele)"
  wybrane="$(jq -c --arg p "$PROJEKT" '
    if $p == "" then . else map(select(.projekt == $p)) end' <<<"$panele")"
  orch="$(jq 'any(.[]; .label == "orkiestrator") | if . then 1 else 0 end' <<<"$wybrane")"

  # Orkiestrator na końcu, a panel, z którego działa shctl, po nim: po jego zamknięciu
  # proces już nie żyje i pętla by nie doszła do kolejnych paneli.
  teraz="$(jq -c --arg s "${HERDR_PANE_ID:-}" 'map(select(.rodzaj == "worker" and .pane_id != $s))' <<<"$wybrane")"
  na_koncu="$(jq -c --arg s "${HERDR_PANE_ID:-}" '
    map(select(.rodzaj != "worker" or .pane_id == $s))
    | sort_by([.pane_id == $s, .label == "orkiestrator"])' <<<"$wybrane")"

  if [ -n "$PROJEKT" ]; then
    lista="$PROJEKT"
  else
    lista="$(
      { for p in "$PROJEKTY"/*/; do [ -e "$p.git" ] && basename "$p"; done
        jq -r '.[].projekt | select(. != "")' <<<"$wybrane"; } | sort -u
    )"
  fi

  if [ "$DRY" -eq 0 ]; then
    # Stan przed zatrzymaniem: nawet przerwany stop zostawia zapis.
    for p in $lista; do
      if zapisz_stan "$p" "$(jq -c --arg p "$p" 'map(select(.projekt == $p))' <<<"$wybrane")" "$orch"; then
        zmiana=1
      fi
    done
    for id in $(jq -r '.[].pane_id' <<<"$teraz"); do
      herdr pane close "$id" >/dev/null || { uwaga "nie zamknięto $id"; bledy=$((bledy + 1)); }
    done
    ile="$(jq 'length' <<<"$wybrane")"
    if [ "$zmiana" -eq 1 ] || [ "$ile" -gt 0 ]; then
      powiadom high "STOP" "shctl stop-all: zatrzymano paneli: $ile. Wznowienie: nowa sesja i „wznów”" "" octagonal_sign ||
        { uwaga "powiadomienie nie wyszło"; bledy=$((bledy + 1)); }
    fi
  fi

  wynik="$(jq -nc --argjson k "$wybrane" --argjson t "$teraz" --argjson n "$na_koncu" --arg l "$lista" --arg s "$STAN" \
    --arg w "${HERDR_PANE_ID:-}" '
    def opis: .pane_id + " " + (if .label == "" then "(bez etykiety)" else .label end)
      + (if .pane_id == $w then " (własny panel)" else "" end);
    ($l | split("\n") | map(select(length > 0) | $s + "/" + . + ".json")) as $pliki
    | {panele:$k, stan:$pliki, kolejnosc:(
        ($pliki | map("zapisz stan: " + .))
        + ($t | map("zamknij: " + opis))
        + ["powiadom: notify.sh high"]
        + ($n | map("zamknij na końcu: " + opis)))}')"
  if [ "$DRY" -eq 1 ]; then
    info "Kolejność:"
    jq -r '.kolejnosc | to_entries[] | "  \(.key + 1). \(.value)"' <<<"$wynik" | while IFS= read -r kolejnosc; do info "$kolejnosc"; done
  else
    info "Zatrzymano: $(jq -r 'map(.pane_id + " " + .label) | join(", ") | if . == "" then "nic" else . end' <<<"$wybrane")"
  fi
  wynik_json "$wynik"

  if [ "$DRY" -eq 0 ]; then
    zapisz_log stop
    for id in $(jq -r '.[].pane_id' <<<"$na_koncu"); do
      herdr pane close "$id" >/dev/null || { uwaga "nie zamknięto $id"; bledy=$((bledy + 1)); }
    done
  fi
  [ "$bledy" -eq 0 ] || exit "$E_WYKONANIE"
}
