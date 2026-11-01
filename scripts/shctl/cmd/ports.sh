# shctl ports reserve|release|list [--zakres 55|56]
# Rejestr: tabela „Projekty Supabase” w ~/sh/porty.md. Blok ZZX21-ZZX29, ZZ to zakres.
# shellcheck shell=bash

# shellcheck source=../lib/porty.sh
. "$SHCTL_DIR/lib/porty.sh"

komenda_main() {
  local akcja="${1:-}" zakres=55 wiersz wynik
  case "$akcja" in
    reserve | release | list) shift ;;
    *) die "$E_UZYCIE" "użycie: shctl ports reserve|release|list" ;;
  esac
  while [ $# -gt 0 ]; do
    case "$1" in
      --zakres) zakres="$(wartosc "$@")"; shift 2 ;;
      *) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
    esac
  done
  case "$zakres" in 55 | 56) ;; *) die "$E_UZYCIE" "--zakres: dozwolone 55 albo 56" ;; esac
  wymagaj jq
  [ -f "$PORTY" ] || die "$E_BRAK" "brak $PORTY"

  case "$akcja" in
    list)
      wynik="$(porty_json)"
      if [ "$JSON" -eq 0 ]; then
        jq -r '.[] | "\(.x)\t\(.projekt)\t\(.api)\t\(.stan)"' <<<"$wynik"
      fi
      wynik_json "$wynik"
      ;;
    reserve)
      [ -n "$PROJEKT" ] || znajdz_projekt
      sprawdz_nazwe "$PROJEKT"
      wiersz="$(porty_rezerwuj "$PROJEKT" "$zakres")"
      if [ -z "$ROOT" ] && [ -d "$PROJEKTY/$PROJEKT" ]; then ROOT="$PROJEKTY/$PROJEKT"; fi
      if [ "$DRY" -eq 0 ] && [ -n "$ROOT" ]; then porty_do_configu "$ROOT" "$PROJEKT" "$(jq -r .baza <<<"$wiersz")"; fi
      info "$PROJEKT: blok $(jq -r .zakres <<<"$wiersz")"
      wynik_json "$wiersz"
      ;;
    release)
      [ -n "$PROJEKT" ] || znajdz_projekt
      sprawdz_nazwe "$PROJEKT"
      wynik="$(porty_zwolnij "$PROJEKT")"
      if [ "$wynik" = 1 ]; then info "$PROJEKT: blok zwolniony"; else info "$PROJEKT: brak rezerwacji, bez zmian"; fi
      wynik_json "$(jq -nc --arg p "$PROJEKT" --argjson z "$wynik" '{projekt:$p, zwolniono:($z == 1)}')"
      ;;
  esac
}
