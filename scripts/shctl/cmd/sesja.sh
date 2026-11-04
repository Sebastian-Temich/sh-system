# shctl sesja start|stan|koniec [--przejmij]: która sesja orkiestratora prowadzi projekt (docs/shctl.md,
# „sesja”). Jedna sesja = jeden projekt; wpis .sesja w /Users/Shared/sh/stan/NAZWA.json odświeżają też
# komendy orkiestratora (task, review, pr, stage).
# shellcheck shell=bash

# shellcheck source=../lib/zadania.sh
. "$SHCTL_DIR/lib/zadania.sh"

komenda_main() {
  local akcja="${1:-}" przejmij=0 w s wynik zmiana=false
  case "$akcja" in
    start | stan | koniec) shift ;;
    *) die "$E_UZYCIE" "użycie: shctl sesja start|stan|koniec [--przejmij] --projekt NAZWA" ;;
  esac
  while [ $# -gt 0 ]; do
    case "$1" in
      --przejmij) przejmij=1; shift ;;
      *) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
    esac
  done
  zadania_init
  w="$(sesja_wpis)"
  s="$(sesja_ocen "$w")"
  case "$akcja" in
    start)
      [ "$s" != brak ] || die "$E_UZYCIE" "brak CLAUDE_CODE_SESSION_ID: sesja start działa tylko w sesji Claude Code"
      if [ "$s" = inna ] && [ "$przejmij" -eq 0 ]; then
        die "$E_ODMOWA" "projekt $PROJEKT prowadzi inna aktywna $(opis_sesji "$w"). Jedna sesja = jeden projekt: zakończ tamtą albo, za zgodą właściciela, shctl sesja start --przejmij"
      fi
      wynik="$(sesja_nowy_wpis "$( [ "$s" = moja ] && jq -r '.od // ""' <<<"$w")")"
      [ "$s" != inna ] || wynik="$(jq -c --argjson p "$w" '. + {przejeta_od:$p.id}' <<<"$wynik")"
      sesja_zapisz "$wynik"
      zmiana=true
      info "$PROJEKT: prowadzi ta sesja (${CLAUDE_CODE_SESSION_ID:0:8})$( [ "$s" = inna ] && echo ", przejęta od $(jq -r '.id[0:8]' <<<"$w")")"
      ;;
    stan)
      wynik="$w"
      case "$s" in
        moja) info "$PROJEKT: prowadzi ta sesja" ;;
        inna) info "$PROJEKT: prowadzi inna aktywna $(opis_sesji "$w")" ;;
        *) info "$PROJEKT: $( [ "$w" = null ] && echo "brak sesji" || echo "ostatnia $(opis_sesji "$w"), nieaktywna")" ;;
      esac
      ;;
    koniec)
      if [ "$s" = moja ]; then
        sesja_zapisz null
        zmiana=true
        info "$PROJEKT: sesja zwolniona"
      else
        info "$PROJEKT: ta sesja nie prowadzi projektu, bez zmian"
      fi
      wynik=null
      ;;
  esac
  wynik_json "$(jq -nc --arg p "$PROJEKT" --arg s "$s" --argjson w "${wynik:-null}" --argjson z "$zmiana" \
    '{projekt:$p, stan:$s, sesja:$w, zmiana:$z}')"
}
