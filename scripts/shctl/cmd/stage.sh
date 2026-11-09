# shctl stage start|review|done|escalate ETAP [--notatka]
# Pominięcie etapu: orkiestrator ustawia w DoD.md status pominiety i decyzja (shctl decision add);
# check-dod.sh odrzuca pominiety bez decyzji.
# shctl stage iter ETAP: po FAIL review etapu podbija iteracja i wraca do in-progress, oba pola na main.
# Gałąź stage/ETAP nie zmienia frontmattera DoD.md, więc PR etapu nie ma konfliktu z main.
# shellcheck shell=bash

# shellcheck source=../lib/zadania.sh
. "$SHCTL_DIR/lib/zadania.sh"

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
    escalate:todo | escalate:in-progress | escalate:review | escalate:escalated) echo escalated ;;
    *) die "$E_ODMOWA" "stage $akcja niedozwolone dla $etap w statusie $obecny" ;;
  esac
}

# Limit iteracji review etapu: dokumenty (00, 04, 05, 06) mają najwyżej jedną iterację poprawek, potem
# uwagi idą do decyzje.md (SH-lite F1); wydanie zostaje przy limicie zadań.
maks_iter_etapu() {
  case "$1" in
    00-intake | 04-architektura | 05-plan | 06-zadania) echo 2 ;;
    *) echo "$MAKS_ITERACJI" ;;
  esac
}

# Iteracja etapu z DoD.md na main; 0 (przed pierwszym review) liczy się jak 1.
stage_iter() {
  local etap="$1" pr prn head stan rev obecna cel wyn esk zmiana=1 st maks
  zadania_init
  sprawdz_etap "$etap"
  [ "$etap" != 08-qa ] || die "$E_ODMOWA" "08-qa: raport QA nie ma review etapu, więc nie ma iteracji (merge po zielonym CI)"
  maks="$(maks_iter_etapu "$etap")"
  pr="$(gh pr list --repo "$SLUG" --head "stage/$etap" --state open --json number,headRefOid --jq '.[0] // empty' 2>/dev/null)" ||
    die "$E_WYKONANIE" "gh pr list nie działa dla $SLUG"
  [ -n "$pr" ] || die "$E_ODMOWA" "brak otwartego PR z gałęzi stage/$etap"
  prn="$(jq -r .number <<<"$pr")"
  head="$(jq -r .headRefOid <<<"$pr")"
  stan="$(stan_etapu "$etap")"
  obecna="$(fm_get "$ROOT/docs/$etap/DoD.md" iteracja)"
  case "$obecna" in "" | *[!0-9]*) obecna=0 ;; esac

  # Powtórka dla tego samego review nie podbija licznika drugi raz.
  if [ "$(jq -r '.iter_review // ""' <<<"$stan")" = "$head" ]; then
    cel="$(jq -r .iter_cel <<<"$stan")"
    [ "$obecna" != "$cel" ] || zmiana=0
  else
    rev="$(review_dla_heada "$prn" "$head")"
    [ -n "$rev" ] || die "$E_ODMOWA" "brak wyniku shctl review run dla bieżącego commita PR #$prn"
    [ "$(jq -r .werdykt <<<"$rev")" = FAIL ] || die "$E_ODMOWA" "ostatnie review PR #$prn to PASS; iteracja tylko po FAIL"
    [ "$obecna" -gt 0 ] || obecna=1
    cel=$((obecna + 1))
  fi

  if [ "$cel" -gt "$maks" ]; then
    info "$etap: FAIL w iteracji $maks, eskalacja"
    set -- escalate --projekt "$PROJEKT" --dotyczy "$etap" --powod "$maks iteracje review etapu bez PASS" \
      --potrzebne "decyzja: dalsze poprawki poza limitem, zmiana zakresu etapu albo inne rozwiązanie (PR #$prn)" --json
    [ "$DRY" -eq 0 ] || set -- "$@" --dry-run
    wyn="$("$SHCTL_DIR/shctl" "$@")" || die "$E_WYKONANIE" "shctl escalate nie powiódł się: $(jq -r '.blad // ""' <<<"$wyn" 2>/dev/null)"
    esk="$(jq -r '.wynik.id' <<<"$wyn")"
    stan_etapu_zapisz "$etap" "$(jq -nc --arg e "$esk" --arg h "$head" --argjson c "$cel" '{eskalacja:$e, iter_review:$h, iter_cel:$c}')"
    wynik_json "$(jq -nc --arg e "$etap" --argjson p "$prn" --argjson i "$maks" --arg k "$esk" \
      '{etap:$e, pr:$p, iteracja:$i, eskalacja:$k, eskalowano:true}')"
    return 0
  fi

  if [ "$DRY" -eq 0 ]; then
    ostrzez_gdy_nie_main
    stan_etapu_zapisz "$etap" "$(jq -nc --arg h "$head" --argjson c "$cel" '{iter_review:$h, iter_cel:$c}')"
    yq -i --front-matter=process ".iteracja = $cel" "$ROOT/docs/$etap/DoD.md"
    st="$(fm_get "$ROOT/docs/$etap/DoD.md" status)"
    case "$st" in review | in-progress) zmien_status_etapu "$etap" in-progress ;; esac
    dopisz_dziennik "- $(dzis) \`$etap\`: iteracja $cel (FAIL review PR #$prn)"
  fi
  if [ "$zmiana" -eq 1 ]; then info "$PROJEKT: $etap: iteracja $cel, status in-progress"; else info "$PROJEKT: $etap: iteracja $cel już podbita"; fi
  wynik_json "$(jq -nc --arg e "$etap" --argjson p "$prn" --argjson c "$cel" --argjson z "$zmiana" \
    '{etap:$e, pr:$p, iteracja:$c, eskalowano:false, zmiana:($z == 1)}')"
}

komenda_main() {
  local akcja="" etap="" notatka="" obecny cel linia zmiana=0
  [ $# -gt 0 ] || die "$E_UZYCIE" "użycie: shctl stage start|review|done|escalate|iter ETAP [--notatka]"
  akcja="$1"
  shift
  case "$akcja" in
    start | review | done | escalate | iter) ;;
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
  if [ "$akcja" = iter ]; then
    [ -z "$notatka" ] || die "$E_UZYCIE" "stage iter nie przyjmuje --notatka"
    stage_iter "$etap"
    return 0
  fi
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
