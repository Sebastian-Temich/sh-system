# shctl obsidian link|unlink NAZWA: lekki klon docs/ w vaulcie Obsidiana.
# shellcheck shell=bash

# shellcheck source=../lib/obsidian.sh
. "$SHCTL_DIR/lib/obsidian.sh"

komenda_main() {
  local akcja="${1:-}" nazwa="" kat slug zal powod
  case "$akcja" in
    link | unlink) shift ;;
    *) die "$E_UZYCIE" "użycie: shctl obsidian link|unlink NAZWA" ;;
  esac
  while [ $# -gt 0 ]; do
    case "$1" in
      -*) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
      *)
        [ -z "$nazwa" ] || die "$E_UZYCIE" "nadmiarowy argument: $1"
        nazwa="$1"
        shift
        ;;
    esac
  done
  [ -n "$nazwa" ] || nazwa="$PROJEKT"
  [ -n "$nazwa" ] || die "$E_UZYCIE" "brak NAZWA"
  sprawdz_nazwe "$nazwa"
  PROJEKT="$nazwa"
  wymagaj git jq
  obsidian_wymagaj
  kat="$(obsidian_kat "$nazwa")"
  slug="$SH_GH_OWNER/$nazwa"

  if [ "$akcja" = link ]; then
    zal="$(obsidian_polacz "$nazwa")"
    if [ "$zal" = 1 ]; then
      info "klon docs/: $kat"
      info "W Obsidianie wystarczy włączyć Obsidian Git dla tego folderu."
    else
      info "klon już istnieje: $kat"
    fi
    wynik_json "$(jq -nc --arg k "$kat" --argjson z "$zal" '{katalog:$k, utworzono:($z == 1)}')"
    return 0
  fi

  if [ ! -e "$kat" ]; then
    info "brak klonu: $kat"
    wynik_json "$(jq -nc --arg k "$kat" '{katalog:$k, usunieto:false}')"
    return 0
  fi
  # Usuwamy wyłącznie klon tego repo, nigdy dowolny katalog vaulta.
  obsidian_czy_klon "$kat" "$slug" || die "$E_ODMOWA" "$kat nie jest klonem $slug; nie usuwam"
  powod="$(obsidian_przeszkoda "$kat")"
  [ -z "$powod" ] || die "$E_ODMOWA" "$kat: $powod; nie usuwam"
  [ "$DRY" -eq 1 ] || rm -rf "$kat"
  info "usunięto klon: $kat"
  wynik_json "$(jq -nc --arg k "$kat" '{katalog:$k, usunieto:true}')"
}
