# shctl status show: podsumowanie dla właściciela. Tylko odczyt. Tekst zaczyna się od „Gdzie jesteśmy”
# i „Czeka na Ciebie” z docs/Projekt.md (sync-status.sh), JSON ma je w polach gdzie i czeka (lista z
# czasem z stan/czeka/PROJEKT.json, zapisuje ją sync-status.sh).
# shellcheck shell=bash

zadania_z_github() {
  local slug
  command -v gh >/dev/null || return 1
  slug="$(slug_repo)"
  [ -n "$slug" ] || return 1
  gh issue list --repo "$slug" --state all --limit 1000 --json state,stateReason,labels 2>/dev/null |
    jq -c 'map(
      [.labels[].name] as $e
      | if .state == "CLOSED" then (if .stateReason == "NOT_PLANNED" then "anulowane" else "done" end)
        else first(("escalated", "blocked", "review", "in-progress", "todo")
          | select(("status:" + .) as $n | $e | index($n))) // "todo" end)
      | {todo: (map(select(. == "todo")) | length),
         in_progress: (map(select(. == "in-progress")) | length),
         review: (map(select(. == "review")) | length),
         blocked: (map(select(. == "blocked")) | length),
         escalated: (map(select(. == "escalated")) | length),
         done: (map(select(. == "done")) | length),
         anulowane: (map(select(. == "anulowane")) | length)}'
}

# Bez GitHuba: liczniki z kolumny Status tabeli w docs/06-zadania/index.md (sync-status.sh).
zadania_z_indeksu() {
  local f="$ROOT/docs/06-zadania/index.md"
  { [ -f "$f" ] && awk -F '|' '
      $0 == "<!-- sync-status:start -->" { w = 1; next }
      $0 == "<!-- sync-status:end -->" { w = 0 }
      w && /^\| #[0-9]/ { s = $4; gsub(/^ +| +$/, "", s); print s }' "$f" || true; } |
    jq -Rsc 'split("\n") | map(select(length > 0)) as $s
      | {todo: ($s | map(select(. == "todo")) | length),
         in_progress: ($s | map(select(. == "in-progress")) | length),
         review: ($s | map(select(. == "review")) | length),
         blocked: ($s | map(select(. == "blocked")) | length),
         escalated: ($s | map(select(. == "escalated")) | length),
         done: ($s | map(select(. == "done")) | length),
         anulowane: ($s | map(select(. == "anulowane")) | length)}'
}

komenda_main() {
  local zadania zrodlo=github esk etap wstrzym f gdzie czeka czeka_txt
  [ "${1:-}" != show ] || shift
  while [ $# -gt 0 ]; do opcja_wspolna "$@"; shift "$ZJEDZONE"; done
  znajdz_projekt
  [ -f "$ST" ] || die "$E_BRAK" "brak docs/Projekt.md (ani dawnego docs/status.md)"

  etap="$(opis_etapu)"
  zadania="$(zadania_z_github || true)"
  if [ -z "$zadania" ]; then
    zrodlo="06-zadania/index.md"
    zadania="$(zadania_z_indeksu)"
  fi

  esk='[]'
  for f in "$ROOT"/docs/07-realizacja/escalations/E-[0-9]*.md; do
    [ -e "$f" ] || continue
    [ "$(fm_get "$f" status)" = otwarta ] || continue
    esk="$(jq -c --arg i "$(basename "$f" .md)" --arg d "$(fm_get "$f" dotyczy)" --arg p "$(fm_get "$f" powod)" --arg t "$(fm_get "$f" typ)" \
      '. + [{id:$i, typ:(if $t == "" then "blokada" else $t end), dotyczy:$d, powod:$p}]' <<<"$esk")"
  done

  # Format limity.md: docs/shctl.md (wpisy właściciela albo orkiestratora); bierzemy pozycje listy i wiersze tabeli bez nagłówka.
  wstrzym='[]'
  if [ -f "$LIMITY" ]; then
    wstrzym="$(grep -E '^(- |\| )' "$LIMITY" | grep -vE '^\|[- |]*$' | awk '!/^\| / || n++' | jq -Rsc 'split("\n") | map(select(length > 0))' || true)"
    [ -n "$wstrzym" ] || wstrzym='[]'
  fi

  gdzie="$(czytaj_sekcje "$ST" "Gdzie jesteśmy")"
  czeka_txt="$(czytaj_sekcje "$ST" "Czeka na Ciebie")"
  czeka="$(jq -c 'if type == "array" then . else [] end' "$STAN/czeka/$PROJEKT.json" 2>/dev/null || echo '[]')"
  [ -n "$czeka" ] || czeka='[]'
  if [ "$JSON" -eq 0 ]; then
    if [ -n "$gdzie" ]; then
      echo "Gdzie jesteśmy"
      printf '%s\n' "$gdzie"
      echo
      echo "Czeka na Ciebie"
      printf '%s\n' "${czeka_txt:-Nic.}"
      echo
    fi
    echo "Projekt: $PROJEKT (tryb $(tryb), etap wdrożenia $(fm_get "$KONFIG" etap_wdrozenia))"
    echo "Etap:"
    printf '%s\n' "$etap" | sed 's/^/  /'
    jq -r --arg z "$zrodlo" '"Zadania (\($z)): todo \(.todo), w toku \(.in_progress), review \(.review), blocked \(.blocked), eskalacje \(.escalated), done \(.done), anulowane \(.anulowane)"' <<<"$zadania"
    jq -r 'if length == 0 then "Eskalacje: brak" else "Eskalacje:", (.[] | "  \(.id) (\(.dotyczy)): \(.powod)") end' <<<"$esk"
    jq -r 'if length == 0 then "Wstrzymania: brak" else "Wstrzymania:", (.[] | "  " + .) end' <<<"$wstrzym"
  fi
  wynik_json "$(jq -nc --arg p "$PROJEKT" --arg t "$(tryb)" --arg e "$etap" --arg z "$zrodlo" \
    --argjson d "$zadania" --argjson s "$esk" --argjson w "$wstrzym" --arg g "$gdzie" --argjson c "$czeka" \
    '{projekt:$p, tryb:$t, etap:$e, gdzie:$g, czeka:$c, zadania:$d, zrodlo_zadan:$z, eskalacje:$s, wstrzymania:$w}')"
}
