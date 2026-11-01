# shctl stage start|review|done|skip|escalate ETAP [--notatka]
# shellcheck shell=bash

sprawdz_dod_po_zmianie() {
  local etap="$1" kopia wyj
  [ -f "$ROOT/scripts/check-dod.sh" ] || die "$E_BRAK" "brak scripts/check-dod.sh w projekcie"
  # Bieżący stan repo: tu działa też kontrola hooków, której kopia docs/ nie obejmuje.
  if ! wyj="$(bash "$ROOT/scripts/check-dod.sh" "$ROOT" 2>&1)"; then
    die "$E_ODMOWA" "check-dod odmówił: $wyj"
  fi
  # Stan po zmianie na kopii, bo --dry-run nie może ruszać plików projektu.
  kopia="$SHCTL_TMP/dod"
  mkdir -p "$kopia"
  cp -R "$ROOT/docs" "$kopia/docs"
  fm_set "$kopia/docs/$etap/DoD.md" status done
  if ! wyj="$(bash "$ROOT/scripts/check-dod.sh" "$kopia" 2>&1)"; then
    die "$E_ODMOWA" "check-dod odmówił: $wyj"
  fi
}

# Dozwolone przejścia; ten sam status to powtórka bez zmian.
docelowy_status() {
  local akcja="$1" obecny="$2" etap="$3"
  case "$akcja:$obecny" in
    start:todo | start:review | start:escalated | start:in-progress) echo in-progress ;;
    review:in-progress | review:review) echo review ;;
    done:review | done:done) echo done ;;
    skip:todo | skip:pominiety)
      etap_w_trybie "$etap" "$(tryb)" &&
        die "$E_ODMOWA" "etap $etap należy do trybu $(tryb), nie można go pominąć"
      echo pominiety
      ;;
    escalate:todo | escalate:in-progress | escalate:review | escalate:escalated) echo escalated ;;
    *) die "$E_ODMOWA" "stage $akcja niedozwolone dla $etap w statusie $obecny" ;;
  esac
}

komenda_main() {
  local akcja="" etap="" notatka="" obecny cel linia zmiana=0
  [ $# -gt 0 ] || die "$E_UZYCIE" "użycie: shctl stage start|review|done|skip|escalate ETAP [--notatka]"
  akcja="$1"
  shift
  case "$akcja" in
    start | review | done | skip | escalate) ;;
    *) die "$E_UZYCIE" "nieznana akcja stage: $akcja" ;;
  esac
  while [ $# -gt 0 ]; do
    case "$1" in
      --notatka) notatka="$(wartosc "$@")"; shift 2 ;;
      -*) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
      *)
        [ -z "$etap" ] || die "$E_UZYCIE" "nadmiarowy argument: $1"
        etap="$1"
        shift
        ;;
    esac
  done
  [ -n "$etap" ] || die "$E_UZYCIE" "brak ETAP"
  znajdz_projekt
  sprawdz_etap "$etap"

  obecny="$(fm_get "$ROOT/docs/$etap/DoD.md" status)"
  cel="$(docelowy_status "$akcja" "$obecny" "$etap")"
  [ "$akcja" != done ] || [ "$obecny" = done ] || sprawdz_dod_po_zmianie "$etap"
  [ "$cel" = "$obecny" ] || zmiana=1

  if [ "$DRY" -eq 0 ]; then
    ostrzez_gdy_nie_main
    [ "$zmiana" -eq 0 ] || zmien_status_etapu "$etap" "$cel"
    if [ "$zmiana" -eq 1 ] || [ -n "$notatka" ]; then
      linia="- $(dzis) \`$etap\`: $cel"
      [ -z "$notatka" ] || linia="$linia, $(komorka "$notatka")"
      dopisz_dziennik "$linia"
    fi
  fi

  info "$PROJEKT: $etap: $obecny -> $cel"
  wynik_json "$(jq -nc --arg p "$PROJEKT" --arg e "$etap" --arg o "$obecny" --arg c "$cel" \
    --argjson z "$zmiana" '{projekt:$p, etap:$e, poprzedni:$o, status:$c, zmiana:($z == 1)}')"
}
