# shctl obsidian link|unlink NAZWA: lekki klon docs/ w vaulcie Obsidiana (link zakłada też skrzynkę).
# shctl obsidian sync [--agent]: git pull --ff-only we wszystkich klonach vaulta (LaunchAgent co 5 minut).
# shellcheck shell=bash

# shellcheck source=../lib/obsidian.sh
. "$SHCTL_DIR/lib/obsidian.sh"

OBS_SYNC_STAN="$STAN/obsidian-sync.json"
OBS_SYNC_LOG="$SH_DIR/logs/obsidian-sync.log"
OBS_SYNC_OFF="$STAN/obsidian-sync.off"

sync_log() {
  mkdir -p "$(dirname "$OBS_SYNC_LOG")"
  printf '%s %s\n' "$(date '+%FT%T%z')" "$*" >>"$OBS_SYNC_LOG"
}

# Bez merge i resetu. Klon z problemem: wpis w logu; ten sam problem w dwóch kolejnych przebiegach
# daje jedno powiadomienie, ponowne dopiero po ustąpieniu i nawrocie.
obsidian_sync() {
  local agent=0 k w stan powod teraz wyniki poprz nowy ok=0 pom=0 zgl
  while [ $# -gt 0 ]; do
    case "$1" in
      --agent) agent=1; shift ;;
      -*) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
      *) die "$E_UZYCIE" "użycie: shctl obsidian sync [--agent]" ;;
    esac
  done
  wymagaj git jq
  obsidian_wymagaj
  if [ "$agent" -eq 1 ] && [ -e "$OBS_SYNC_OFF" ]; then
    info "synchronizacja wyłączona: $OBS_SYNC_OFF"
    wynik_json '{"wylaczona":true,"klony":[]}'
    return 0
  fi
  teraz="$(date '+%FT%T%z')"
  wyniki="$(tmp_plik)"
  if [ "$DRY" -eq 1 ]; then
    while IFS= read -r k; do
      [ -n "$k" ] || continue
      info "- git pull --ff-only: $k"
      jq -nc --arg k "$k" '{katalog:$k, stan:"dry-run", opis:""}' >>"$wyniki"
    done < <(obsidian_klony)
    wynik_json "$(jq -sc '{wylaczona:false, klony:., pominiete:0}' "$wyniki")"
    return 0
  fi
  mkdir -p "$STAN"
  zablokuj "$STAN/obsidian-sync.lock"
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    w="$(obsidian_sync_klon "$k")"
    stan="${w%%:*}"
    powod="${w#*:}"
    if [ "$stan" = ok ]; then
      ok=$((ok + 1))
      [ "$powod" = aktualny ] || sync_log "ok $k: $powod"
    else
      pom=$((pom + 1))
      sync_log "POMINIĘTY $k: $powod"
      [ "$agent" -eq 1 ] || uwaga "pominięty $k: $powod"
    fi
    info "$stan $k: $powod"
    jq -nc --arg k "$k" --arg s "$stan" --arg o "$powod" '{katalog:$k, stan:$s, opis:$o}' >>"$wyniki"
  done < <(obsidian_klony)

  poprz="$(jq -c . "$OBS_SYNC_STAN" 2>/dev/null || echo '{}')"
  nowy="$(jq -sc --argjson p "$poprz" --arg t "$teraz" --argjson e "$(date +%s)" '
    ($p.problemy // {}) as $pp
    | {ostatni_przebieg: $t,
       ostatnia_udana: (if all(.[]; .stan == "ok") then $t else ($p.ostatnia_udana // null) end),
       ostatnia_udana_epoch: (if all(.[]; .stan == "ok") then $e else ($p.ostatnia_udana_epoch // null) end),
       problemy: ([.[] | select(.stan != "ok") | {key: .katalog, value: {
          powod: .opis,
          od: ($pp[.katalog].od // $t),
          przebiegi: (($pp[.katalog].przebiegi // 0) + 1),
          zgloszone: ($pp[.katalog].zgloszone // false)}}] | from_entries)}' "$wyniki")"
  zgl="$(jq -r '.problemy | to_entries[] | select(.value.przebiegi >= 2 and (.value.zgloszone | not)) | "\(.key): \(.value.powod)"' <<<"$nowy")"
  if [ -n "$zgl" ]; then
    if "$SH_NOTIFY_CMD" default "Obsidian: klon bez synchronizacji" "$(printf '%s' "$zgl" | head -3 | sed "s#$(dirname "$SH_OBSIDIAN_DIR")/##")" >/dev/null 2>&1; then
      nowy="$(jq -c '.problemy |= with_entries(if .value.przebiegi >= 2 then .value.zgloszone = true else . end)' <<<"$nowy")"
      sync_log "powiadomienie: $(printf '%s' "$zgl" | paste -sd ';' -)"
    else
      uwaga "nie udało się wysłać powiadomienia"
    fi
  fi
  w="$(tmp_plik)"
  jq . <<<"$nowy" >"$w"
  podmien_plik "$w" "$OBS_SYNC_STAN"
  odblokuj "$STAN/obsidian-sync.lock"
  info "Obsidian sync: $ok ok, $pom pominiętych"
  wynik_json "$(jq -sc --argjson n "$pom" '{wylaczona:false, klony:., pominiete:$n}' "$wyniki")"
}

komenda_main() {
  local akcja="${1:-}" nazwa="" kat slug zal powod skr
  case "$akcja" in
    link | unlink) shift ;;
    sync) shift; obsidian_sync "$@"; return ;;
    *) die "$E_UZYCIE" "użycie: shctl obsidian link|unlink NAZWA | shctl obsidian sync [--agent]" ;;
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
      info "Synchronizację robi serwer co 5 minut (shctl obsidian sync); w Obsidianie nic nie włączasz."
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
