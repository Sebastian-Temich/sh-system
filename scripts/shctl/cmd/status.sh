# shctl status show: podsumowanie dla właściciela. Tylko odczyt.
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

zadania_ze_statusu() {
  yq --front-matter=extract -o=json '{
    "todo": .zadania_todo, "in_progress": .zadania_in_progress, "review": .zadania_review,
    "blocked": .zadania_blocked, "escalated": .zadania_escalated, "done": .zadania_done,
    "anulowane": .zadania_anulowane}' "$ST" | jq -c .
}

komenda_main() {
  local zadania zrodlo=github esk etap wstrzym f
  [ "${1:-}" != show ] || shift
  while [ $# -gt 0 ]; do opcja_wspolna "$@"; shift "$ZJEDZONE"; done
  znajdz_projekt
  [ -f "$ST" ] || die "$E_BRAK" "brak docs/status.md"

  etap="$(opis_etapu)"
  zadania="$(zadania_z_github || true)"
  if [ -z "$zadania" ]; then
    zrodlo=status.md
    zadania="$(zadania_ze_statusu)"
  fi

  esk='[]'
  for f in "$ROOT"/docs/07-realizacja/escalations/E-[0-9]*.md; do
    [ -e "$f" ] || continue
    [ "$(fm_get "$f" status)" = otwarta ] || continue
    esk="$(jq -c --arg i "$(basename "$f" .md)" --arg d "$(fm_get "$f" dotyczy)" --arg p "$(fm_get "$f" powod)" \
      '. + [{id:$i, dotyczy:$d, powod:$p}]' <<<"$esk")"
  done

  # Format limity.md: docs/shctl.md (wpisy właściciela albo orkiestratora); bierzemy pozycje listy i wiersze tabeli bez nagłówka.
  wstrzym='[]'
  if [ -f "$LIMITY" ]; then
    wstrzym="$(grep -E '^(- |\| )' "$LIMITY" | grep -vE '^\|[- |]*$' | awk '!/^\| / || n++' | jq -Rsc 'split("\n") | map(select(length > 0))' || true)"
    [ -n "$wstrzym" ] || wstrzym='[]'
  fi

  if [ "$JSON" -eq 0 ]; then
    echo "Projekt: $PROJEKT (tryb $(tryb), etap wdrożenia $(fm_get "$KONFIG" etap_wdrozenia))"
    echo "Etap:"
    printf '%s\n' "$etap" | sed 's/^/  /'
    jq -r --arg z "$zrodlo" '"Zadania (\($z)): todo \(.todo), w toku \(.in_progress), review \(.review), blocked \(.blocked), eskalacje \(.escalated), done \(.done), anulowane \(.anulowane)"' <<<"$zadania"
    jq -r 'if length == 0 then "Eskalacje: brak" else "Eskalacje:", (.[] | "  \(.id) (\(.dotyczy)): \(.powod)") end' <<<"$esk"
    jq -r 'if length == 0 then "Wstrzymania: brak" else "Wstrzymania:", (.[] | "  " + .) end' <<<"$wstrzym"
  fi
  wynik_json "$(jq -nc --arg p "$PROJEKT" --arg t "$(tryb)" --arg e "$etap" --arg z "$zrodlo" \
    --argjson d "$zadania" --argjson s "$esk" --argjson w "$wstrzym" \
    '{projekt:$p, tryb:$t, etap:$e, zadania:$d, zrodlo_zadan:$z, eskalacje:$s, wstrzymania:$w}')"
}
