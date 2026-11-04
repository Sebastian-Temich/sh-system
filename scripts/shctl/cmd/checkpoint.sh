# shctl checkpoint ETAP|#NR [--opis "..."]
# Powiadomienie właściciela, że praca czeka na jego akceptację (proces-v1.md, „Autoryzacja i kamienie
# milowe”): specyfikacja (00-intake), architektura i plan (04-architektura), odbiór (wydanie) albo
# odbiór zadania trybu S (#NR). PR wynika z gałęzi stage/ETAP albo z zadania. Wymaga PASS review dla
# bieżącego commita PR. Jedno powiadomienie na commit: stan w /Users/Shared/sh/stan/checkpointy/NAZWA.
# Podniesienie trybu nie ma PR: idzie przez shctl escalate --akceptacja.
# shellcheck shell=bash

# shellcheck source=../lib/zadania.sh
. "$SHCTL_DIR/lib/zadania.sh"

CHECKPOINTY_ETAPOW="00-intake 04-architektura wydanie"

opis_celu() {
  case "$1" in
    00-intake) printf 'Specyfikacja' ;;
    04-architektura) printf 'Architektura i plan' ;;
    wydanie) printf 'Odbiór' ;;
    *) printf 'Odbiór zadania %s (tryb S)' "$1" ;;
  esac
}

komenda_main() {
  local cel="" opis="" nr="" pr prn prst head url rev werdykt stan_kat stan_plik wpis ponownie=0 tytul tresc
  while [ $# -gt 0 ]; do
    case "$1" in
      --opis) opis="$(wartosc "$@")"; shift 2 ;;
      --*) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
      *)
        [ -z "$cel" ] || die "$E_UZYCIE" "nadmiarowy argument: $1"
        cel="$1"
        shift
        ;;
    esac
  done
  [ -n "$cel" ] || die "$E_UZYCIE" "użycie: shctl checkpoint ETAP|#NR [--opis \"...\"] (ETAP: $CHECKPOINTY_ETAPOW)"
  case "$cel" in
    \#*)
      nr="$(numer "${cel#\#}")"
      cel="#$nr"
      ;;
    *)
      case " $CHECKPOINTY_ETAPOW " in
        *" $cel "*) ;;
        *) die "$E_UZYCIE" "etap $cel nie ma checkpointu właściciela (dozwolone: $CHECKPOINTY_ETAPOW albo #NR)" ;;
      esac
      ;;
  esac
  zadania_init

  if [ -n "$nr" ]; then
    pr="$(pr_zadania "$nr")"
    [ -n "$pr" ] || die "$E_ODMOWA" "zadanie #$nr nie ma PR"
  else
    pr="$(gh pr list --repo "$SLUG" --head "stage/$cel" --state open \
      --json number,state,headRefName,headRefOid,url 2>/dev/null)" ||
      die "$E_WYKONANIE" "gh pr list nie działa dla $SLUG"
    pr="$(jq -c 'max_by(.number) // empty' <<<"$pr")"
    [ -n "$pr" ] || die "$E_ODMOWA" "brak otwartego PR z gałęzi stage/$cel"
  fi
  prn="$(jq -r .number <<<"$pr")"
  prst="$(jq -r .state <<<"$pr")"
  head="$(jq -r .headRefOid <<<"$pr")"
  url="$(jq -r '.url // ""' <<<"$pr")"
  [ -n "$url" ] || url="https://github.com/$SLUG/pull/$prn"
  [ "$prst" = OPEN ] || die "$E_ODMOWA" "PR #$prn nie jest otwarty ($prst)"
  [ -n "$head" ] || die "$E_WYKONANIE" "nie można odczytać commita PR #$prn"

  # Właściciel akceptuje pracę po review: bez PASS dla bieżącego commita checkpointu nie ma.
  rev="$(review_dla_heada "$prn" "$head")"
  werdykt=""
  [ -z "$rev" ] || werdykt="$(jq -r '.werdykt // ""' <<<"$rev")"
  [ "$werdykt" = PASS ] || die "$E_ODMOWA" "PR #$prn nie ma PASS review dla commita ${head:0:7}; najpierw shctl review run $prn"

  stan_kat="$STAN/checkpointy"
  stan_plik="$stan_kat/$PROJEKT"
  wpis="$cel $head"
  if [ -f "$stan_plik" ] && grep -qxF "$wpis" "$stan_plik"; then ponownie=1; fi

  tytul="Czeka na Twoją akceptację: $PROJEKT / $cel"
  tresc="$(opis_celu "$cel"), PR #$prn"
  [ -z "$opis" ] || tresc="$tresc. $opis"

  if [ "$DRY" -eq 0 ] && [ "$ponownie" -eq 0 ]; then
    powiadom high "$tytul" "$tresc" "$url" white_check_mark ||
      die "$E_WYKONANIE" "powiadomienie nie wyszło; ponów tę samą komendę"
    mkdir -p "$stan_kat"
    printf '%s\n' "$wpis" >>"$stan_plik"
  fi

  if [ "$ponownie" -eq 1 ]; then
    info "$PROJEKT: $cel: powiadomienie dla PR #$prn (${head:0:7}) już wysłane"
  else
    info "$PROJEKT: $cel: czeka na akceptację właściciela, PR #$prn"
  fi
  wynik_json "$(jq -nc --arg p "$PROJEKT" --arg c "$cel" --argjson n "$prn" --arg h "$head" --arg u "$url" \
    --arg t "$tytul" --argjson r "$ponownie" \
    '{projekt:$p, cel:$c, pr:$n, head:$h, url:$u, tytul:$t, powiadomiono:($r == 0), ponownie:($r == 1)}')"
}
