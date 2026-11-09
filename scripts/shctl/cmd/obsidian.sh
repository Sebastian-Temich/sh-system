# shctl obsidian link|unlink NAZWA: lekki klon docs/ w vaulcie Obsidiana (link zakłada też skrzynkę).
# Synchronizację klonów robi scripts/server/obsidian-sync.sh (LaunchAgent co 5 minut, git pull --ff-only).
# shellcheck shell=bash

# shellcheck source=../lib/obsidian.sh
. "$SHCTL_DIR/lib/obsidian.sh"

komenda_main() {
  local akcja="${1:-}" nazwa="" kat slug zal powod skr
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
      info "Synchronizację robi serwer co 5 minut (obsidian-sync.sh); w Obsidianie nic nie włączasz."
    else
      info "klon już istnieje: $kat"
    fi
    # Projekt założony przed skrzynką dostaje ją przy link.
    skr="$(skrzynka_utworz "$nazwa")"
    [ "$skr" = 0 ] || info "skrzynka na materiały: $(skrzynka_kat "$nazwa")"
    wynik_json "$(jq -nc --arg k "$kat" --argjson z "$zal" --arg s "$(skrzynka_kat "$nazwa")" --argjson sz "$skr" \
      '{katalog:$k, utworzono:($z == 1), skrzynka:{katalog:$s, utworzono:($sz == 1)}}')"
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
