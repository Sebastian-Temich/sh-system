#!/bin/bash
# /Users/Shared/sh/bin/przypomnienia.sh - przypomnienie ntfy, gdy coś czeka na właściciela dłużej niż
# próg (domyślnie 4 h), tylko w godzinach 8–22 czasu lokalnego. LaunchAgent
# pl.iskt.softwarehouse.przypomnienia co 15 minut.
#
# Źródło: frontmatter `czeka` w /Users/Shared/sh/projekty/*/docs/Projekt.md (lista JSON {co, od, wpisz},
# zapisuje ją scripts/sync-status.sh projektu przy każdej zmianie stanu). Jedna wiadomość na projekt;
# ta sama pozycja wraca najwcześniej po kolejnym progu. Stan: stan/przypomnienia.json, flaga
# stan/przypomnienia.off wyłącza przebiegi. Retro iskt-www: 10,8 h czekania w zleceniu M, 57 h w S.
#
# Zmienne (testy): SH_DIR, SH_NOTIFY_CMD, SH_PRZYPOMNIENIE_PROG (sekundy), SH_TERAZ (epoka),
# SH_GODZINA (0–23).
set -u
SH_DIR="${SH_DIR:-/Users/Shared/sh}"
NOTIFY="${SH_NOTIFY_CMD:-$SH_DIR/bin/notify.sh}"
PROG="${SH_PRZYPOMNIENIE_PROG:-14400}"
TERAZ="${SH_TERAZ:-$(date +%s)}"
GODZINA="${SH_GODZINA:-$(date +%H)}"
GODZINA=$((10#$GODZINA))
STAN="$SH_DIR/stan/przypomnienia.json"
LOG="$SH_DIR/logs/przypomnienia.log"

[ ! -e "$SH_DIR/stan/przypomnienia.off" ] || exit 0
[ "$GODZINA" -ge 8 ] && [ "$GODZINA" -lt 22 ] || exit 0
command -v jq >/dev/null || { echo "przypomnienia: brak jq" >&2; exit 1; }
mkdir -p "$SH_DIR/stan" "$SH_DIR/logs"
[ -s "$STAN" ] && jq -e . "$STAN" >/dev/null 2>&1 || echo '{}' >"$STAN"

# Lista czeka z frontmattera (jedna linia JSON); pusto, gdy brak.
czeka_z() {
  awk 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } index($0, "czeka: ") == 1 { print substr($0, 8); exit }' "$1"
}

nowy_stan='{}'
for plik in "$SH_DIR"/projekty/*/docs/Projekt.md; do
  [ -f "$plik" ] || continue
  projekt="$(basename "$(dirname "$(dirname "$plik")")")"
  lista="$(czeka_z "$plik")"
  [ -n "$lista" ] || continue
  # Pozycje starsze niż próg, z kluczem projekt|co; dla każdej czas ostatniego przypomnienia.
  wynik="$(jq -c --arg p "$projekt" --argjson t "$TERAZ" --argjson prog "$PROG" --slurpfile s "$STAN" '
    [ .[]? | select((.od // "") != "")
      | (.od | sub("\\.[0-9]+Z$"; "Z") | try fromdateiso8601 catch null) as $od | select($od != null)
      | {klucz: "\($p)|\(.co)", co, wpisz: (.wpisz // ""), godzin: ((($t - $od) / 3600) | floor), wiek: ($t - $od)}
      | select(.wiek >= $prog)
      | . + {ostatnio: ($s[0][.klucz] // 0)} ]' <<<"$lista" 2>/dev/null)" || continue
  [ -n "$wynik" ] && [ "$wynik" != "[]" ] || continue
  # Pozycje, które wciąż czekają, zostają w stanie (z dotychczasowym czasem przypomnienia).
  nowy_stan="$(jq -c --argjson w "$wynik" '. + ($w | map({(.klucz): .ostatnio}) | add // {})' <<<"$nowy_stan")"
  do_wyslania="$(jq -c --argjson t "$TERAZ" --argjson prog "$PROG" '[.[] | select(($t - .ostatnio) >= $prog)]' <<<"$wynik")"
  [ "$do_wyslania" != "[]" ] || continue
  najdluzej="$(jq -r 'map(.godzin) | max' <<<"$do_wyslania")"
  tresc="$(jq -r 'map("\(.co) (\(.godzin) h)" + (if .wpisz != "" then ". Wpisz: \(.wpisz)" else "" end)) | join("\n")' <<<"$do_wyslania")"
  if "$NOTIFY" default "Czeka na Ciebie od $najdluzej h: $projekt" "$tresc" "" hourglass >/dev/null 2>&1; then
    nowy_stan="$(jq -c --argjson w "$do_wyslania" --argjson t "$TERAZ" '. + ($w | map({(.klucz): $t}) | add)' <<<"$nowy_stan")"
    printf '%s %s: przypomnienie (%s pozycji)\n' "$(date '+%FT%T%z')" "$projekt" "$(jq length <<<"$do_wyslania")" >>"$LOG"
  else
    printf '%s %s: powiadomienie nie wyszło\n' "$(date '+%FT%T%z')" "$projekt" >>"$LOG"
  fi
done
printf '%s\n' "$nowy_stan" >"$STAN.tmp" && mv "$STAN.tmp" "$STAN"
exit 0
