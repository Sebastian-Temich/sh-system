# Operacje na rejestrze /Users/Shared/sh/porty.md i supabase/config.toml.
# shellcheck shell=bash

# Wiersze tabeli „Projekty Supabase” bez nagłówka, z obciętymi polami, rozdzielone \t.
porty_wiersze() {
  awk -F'|' '
    /^## / { w = ($0 == "## Projekty Supabase") }
    w && /^\|/ && !/^\|---/ && !/^\| X / {
      linia = ""
      for (i = 2; i < NF; i++) { p = $i; gsub(/^[ \t]+|[ \t]+$/, "", p); linia = linia (i > 2 ? "\t" : "") p }
      print linia
    }' "$PORTY"
}

# Wynik: "ZZX", np. 551. Pierwszy blok z wolnym wierszem albo bez wiersza, z wolnymi portami.
porty_wolny_blok() {
  local zakres="$1" x etykieta zajete p n
  zajete="$(porty_wiersze | awk -F'\t' '$2 != "*wolny*" { print $1 }')"
  for x in 1 2 3 4 5 6 7 8 9; do
    etykieta="$x"
    [ "$zakres" = 55 ] || etykieta="$zakres:$x"
    printf '%s\n' "$zajete" | grep -qxF -- "$etykieta" && continue
    if command -v lsof >/dev/null; then
      n=0
      for p in 21 22 23 24 25 26 27 28 29; do
        if lsof -nP -iTCP:"$zakres$x$p" -sTCP:LISTEN >/dev/null 2>&1; then n=1; fi
      done
      if [ "$n" -eq 1 ]; then uwaga "blok $zakres${x}21 ma zajęty port, pomijam"; continue; fi
    fi
    printf '%s%s' "$zakres" "$x"
    return 0
  done
  return 1
}

porty_opis() {
  local p="$1" b="$2"
  jq -nc --arg p "$p" --arg b "$b" '{
    projekt:$p, baza:$b, zakres:($b + "21-" + $b + "29"),
    api:($b+"21"), db:($b+"22"), studio:($b+"23"), mail:($b+"24"), inspector:($b+"25"),
    dev:($b+"26"), analytics:($b+"27"), shadow:($b+"28"), pooler:($b+"29")}'
}

porty_baza_projektu() {
  porty_wiersze | awk -F'\t' -v p="$1" '$2 == p { print substr($4, 1, 3); exit }'
}

# Wstawia wiersz w miejsce „wolny” albo po ostatnim wierszu tabeli.
porty_zapisz_wiersz() {
  local etykieta="$1" wiersz="$2" nowy
  nowy="$(tmp_plik)"
  awk -F'|' -v e="$etykieta" -v wiersz="$wiersz" '
    function x(   p) { p = $2; gsub(/[ \t]/, "", p); return p }
    /^## / { w = ($0 == "## Projekty Supabase") }
    { linie[NR] = $0 }
    w && /^\|/ { ost = NR; if (x() == e) { cel = NR } }
    END {
      for (i = 1; i <= NR; i++) {
        if (i == cel) print wiersz
        else { print linie[i]; if (!cel && i == ost) print wiersz }
      }
    }' "$PORTY" >"$nowy"
  podmien_plik "$nowy" "$PORTY"
}

porty_rezerwuj() {
  local p="$1" zakres="$2" b x etykieta
  [ "$DRY" -eq 1 ] || zablokuj "$PORTY.lock"
  b="$(porty_baza_projektu "$p")"
  if [ -z "$b" ]; then
    b="$(porty_wolny_blok "$zakres")" || {
      # Podpowłoka $(...) nie ma pułapki EXIT, więc blokadę trzeba zdjąć przed die.
      [ "$DRY" -eq 1 ] || odblokuj "$PORTY.lock"
      [ "$zakres" = 55 ] && die "$E_ODMOWA" \
        "pula 55X21-55X29 wyczerpana: zwolnij blok archiwalny w porty.md (wiersz na *wolny*) albo użyj --zakres 56"
      die "$E_ODMOWA" "pula ${zakres}X21-${zakres}X29 wyczerpana"
    }
    x="${b#"$zakres"}"
    etykieta="$x"
    [ "$zakres" = 55 ] || etykieta="$zakres:$x"
    if [ "$DRY" -eq 0 ]; then
      porty_zapisz_wiersz "$etykieta" "| $etykieta | $p | \`/Users/Shared/sh/projekty/$p\` | ${b}21 | ${b}22 | ${b}23 | ${b}24 | ${b}27 | ${b}28 | ${b}29 | ${b}25 | zarezerwowany $(dzis) |"
    fi
  fi
  [ "$DRY" -eq 1 ] || odblokuj "$PORTY.lock"
  porty_opis "$p" "$b"
}

# Ustawia klucz w sekcji TOML. Brakujący klucz lub sekcję dopisuje.
toml_ustaw() {
  local plik="$1" sekcja="$2" klucz="$3" wart="$4" nowy
  nowy="$(tmp_plik)"
  awk -v s="[$sekcja]" -v k="$klucz" -v v="$wart" '
    function dopisz() { if (w && !z) { print k " = " v; z = 1 } }
    /^[ \t]*\[/ { dopisz(); t = $0; gsub(/[ \t]/, "", t); w = (t == s); if (w) b = 1 }
    w && $0 ~ ("^[ \t]*" k "[ \t]*=") { print k " = " v; z = 1; next }
    { print }
    END { dopisz(); if (!b) { print ""; print s; print k " = " v } }' "$plik" >"$nowy"
  podmien_plik "$nowy" "$plik"
}

# Wszystkie porty z tabeli w porty.md, także shadow_port i inspector_port.
porty_do_configu() {
  local root="$1" p="$2" b="$3" plik nowy
  plik="$root/supabase/config.toml"
  [ -f "$plik" ] || return 0
  nowy="$(tmp_plik)"
  if grep -q '^project_id[ ]*=' "$plik"; then
    sed -E "s/^project_id[ ]*=.*/project_id = \"$p\"/" "$plik" >"$nowy"
  else
    { printf 'project_id = "%s"\n' "$p"; cat "$plik"; } >"$nowy"
  fi
  podmien_plik "$nowy" "$plik"
  toml_ustaw "$plik" api port "${b}21"
  toml_ustaw "$plik" db port "${b}22"
  toml_ustaw "$plik" db shadow_port "${b}28"
  toml_ustaw "$plik" db.pooler port "${b}29"
  toml_ustaw "$plik" studio port "${b}23"
  toml_ustaw "$plik" inbucket port "${b}24"
  toml_ustaw "$plik" edge_runtime inspector_port "${b}25"
  toml_ustaw "$plik" analytics port "${b}27"
}
