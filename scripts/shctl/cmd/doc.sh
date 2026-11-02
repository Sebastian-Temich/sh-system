# shctl doc new ETAP TYP [--tytul] [--rola] [--nr]
# shellcheck shell=bash

domyslna_rola() {
  case "$1" in
    00-intake | 01-brief | 02-design | 03-wymagania) echo intake ;;
    04-architektura | 05-plan) echo architekt ;;
    06-zadania) echo zadania ;;
    07-realizacja) echo worker ;;
    08-qa) echo qa ;;
    *) echo orkiestrator ;;
  esac
}

# Typy o stałym etapie. Pozostałe szablony trafiają do docs/ETAP/TYP.md.
etap_typu() {
  case "$1" in
    specyfikacja) echo 00-intake ;;
    adr | architektura) echo 04-architektura ;;
    plan) echo 05-plan ;;
    raport-zadania) echo 07-realizacja ;;
    raport-qa) echo 08-qa ;;
    wydanie-techniczna | wydanie-produktowa) echo wydanie ;;
  esac
}

nastepny_adr() {
  local f n max=0
  for f in "$1"/ADR-[0-9]*.md; do
    [ -e "$f" ] || continue
    n="$(basename "$f")"
    n="${n#ADR-}"
    n="${n%%[!0-9]*}"
    n=$((10#$n))
    [ "$n" -le "$max" ] || max="$n"
  done
  printf '%03d' $((max + 1))
}

komenda_main() {
  local etap="" typ="" tytul="" rola="" nr="" pozycyjne=0 szablon kat plik wzgl slug adr=""
  local tresc naglowek t
  [ "${1:-}" = new ] || die "$E_UZYCIE" "użycie: shctl doc new ETAP TYP [--tytul \"...\"]"
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --tytul) tytul="$(wartosc "$@")"; shift 2 ;;
      --rola) rola="$(wartosc "$@")"; shift 2 ;;
      --nr) nr="$(wartosc "$@")"; shift 2 ;;
      -*) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
      *)
        pozycyjne=$((pozycyjne + 1))
        case "$pozycyjne" in
          1) etap="$1" ;;
          2) typ="$1" ;;
          *) die "$E_UZYCIE" "nadmiarowy argument: $1" ;;
        esac
        shift
        ;;
    esac
  done
  [ -n "$etap" ] && [ -n "$typ" ] || die "$E_UZYCIE" "brak ETAP albo TYP"
  case "$typ" in
    eskalacja) die "$E_UZYCIE" "eskalacje tworzy shctl escalate" ;;
    decyzja) die "$E_UZYCIE" "decyzje dopisuje shctl decision add" ;;
    *[!a-z0-9-]* | "") die "$E_UZYCIE" "niepoprawny TYP: $typ" ;;
  esac
  znajdz_projekt
  sprawdz_etap "$etap"
  szablon="$ROOT/docs/_szablony/$typ.md"
  [ -f "$szablon" ] || die "$E_BRAK" "brak szablonu: docs/_szablony/$typ.md"
  if [ -n "$(etap_typu "$typ")" ] && [ "$(etap_typu "$typ")" != "$etap" ]; then
    die "$E_UZYCIE" "typ $typ należy do etapu $(etap_typu "$typ"), nie $etap"
  fi
  [ -n "$rola" ] || rola="$(domyslna_rola "$etap")"

  kat="$ROOT/docs/$etap"
  case "$typ" in
    adr)
      [ -n "$tytul" ] || die "$E_UZYCIE" "ADR wymaga --tytul"
      kat="$kat/adr"
      slug="$(odslugifikuj "$tytul")"
      [ -n "$slug" ] || die "$E_UZYCIE" "--tytul nie daje nazwy pliku"
      # Ten sam tytuł to ten sam ADR: powtórka zwraca istniejący plik i numer.
      for plik in "$kat"/ADR-[0-9]*-"$slug".md; do
        if [ -e "$plik" ]; then adr="$(basename "$plik" | cut -d- -f2)"; break; fi
      done
      if [ -z "$adr" ]; then
        adr="$(nastepny_adr "$kat")"
        plik="$kat/ADR-$adr-$slug.md"
      fi
      ;;
    raport-zadania)
      case "$nr" in
        "" | *[!0-9]*) die "$E_UZYCIE" "raport-zadania wymaga --nr NUMER_ISSUE" ;;
      esac
      plik="$kat/T-$nr.md"
      ;;
    raport-qa)
      # Jeden raport na kamień milowy: pierwsze słowo tytułu to MN (np. „M1 Szkielet” daje raport-M1.md).
      slug="${tytul%% *}"
      case "$slug" in
        M[0-9]*) case "${slug#M}" in *[!0-9]*) slug="" ;; esac ;;
        *) slug="" ;;
      esac
      [ -n "$slug" ] || die "$E_UZYCIE" "raport-qa wymaga --tytul zaczynającego się od kamienia MN, np. \"M1 Szkielet\""
      plik="$kat/raport-$slug.md"
      ;;
    wydanie-techniczna) plik="$kat/techniczna/techniczna.md" ;;
    wydanie-produktowa) plik="$kat/produktowa/produktowa.md" ;;
    *) plik="$kat/$typ.md" ;;
  esac
  wzgl="${plik#"$ROOT"/}"

  if [ -e "$plik" ]; then
    info "istnieje: $wzgl"
    wynik_json "$(jq -nc --arg s "$wzgl" --arg a "$adr" \
      '{plik:$s, utworzono:false} + (if $a != "" then {adr:("ADR-" + $a)} else {} end)')"
    return 0
  fi

  tresc="$(cat "$szablon")"
  naglowek="${tresc%%$'\n'*}"
  tresc="${tresc#"$naglowek"}"
  naglowek="${naglowek//NAZWA/$PROJEKT}"
  if [ -n "$tytul" ]; then
    t="$tytul"
    naglowek="${naglowek//KAMIEŃ MILOWY/$t}"
    naglowek="${naglowek//TYTUŁ/$t}"
  fi
  # Tylko nagłówek: „zastąpiona przez ADR-NNN” w treści to podpowiedź szablonu.
  [ -z "$adr" ] || naglowek="${naglowek//ADR-NNN/ADR-$adr}"
  [ -z "$nr" ] || naglowek="${naglowek//T-NR/T-$nr}"
  tresc="${tresc//RRRR-MM-DD/$(dzis)}"
  [ -z "$nr" ] || tresc="${tresc//Issue: #NR/Issue: #$nr}"
  if [ "$DRY" -eq 0 ]; then
    mkdir -p "$(dirname "$plik")"
    {
      printf -- '---\nprojekt: %s\netap: %s\ndata: "%s"\nrola: %s\n---\n\n' \
        "$PROJEKT" "$etap" "$(dzis)" "$rola"
      printf '%s%s\n' "$naglowek" "$tresc"
    } >"$plik"
  fi
  info "utworzono: $wzgl"
  wynik_json "$(jq -nc --arg s "$wzgl" --arg a "$adr" --arg r "$rola" \
    '{plik:$s, utworzono:true, rola:$r} + (if $a != "" then {adr:("ADR-" + $a)} else {} end)')"
}
