# shctl stage AKCJA ETAP [--notatka "..."]: jedna komenda etapu, AKCJA to start, review, iter, done
# albo escalate. Status i iteracja są we frontmatterze DoD.md na main; gałąź stage/ETAP go nie zmienia,
# więc PR etapu nie ma konfliktu z main. Pominięcie etapu: status pominiety i decyzja w DoD.md
# (shctl decision add); check-dod.sh odrzuca pominiety bez decyzji.
# shellcheck shell=bash

# shellcheck source=../lib/zadania.sh
. "$SHCTL_DIR/lib/zadania.sh"

# Dozwolone przejścia AKCJA:OBECNY -> CEL; ten sam status to powtórka bez zmian.
PRZEJSCIA="start:todo=in-progress start:review=in-progress start:escalated=in-progress
start:in-progress=in-progress review:in-progress=review review:review=review done:review=done done:done=done
escalate:todo=escalated escalate:in-progress=escalated escalate:review=escalated escalate:escalated=escalated"

# check-dod na bieżącym repo (tu działa też kontrola hooków) i na kopii docs/ ze statusem done,
# bo --dry-run nie może ruszać plików projektu.
sprawdz_dod_po_zmianie() {
  local kopia="$SHCTL_TMP/dod" r wyj
  [ -f "$ROOT/scripts/check-dod.sh" ] || die "$E_BRAK" "brak scripts/check-dod.sh w projekcie"
  mkdir -p "$kopia" && cp -R "$ROOT/docs" "$kopia/docs" && fm_set "$kopia/docs/$1/DoD.md" status done
  for r in "$ROOT" "$kopia"; do
    wyj="$(bash "$ROOT/scripts/check-dod.sh" "$r" 2>&1)" || die "$E_ODMOWA" "check-dod odmówił: $wyj"
  done
}

# Po FAIL review etapu: iteracja+1 i powrót do in-progress. Dokumenty (00, 04, 06) mają najwyżej
# jedną iterację poprawek (SH-lite F1), wydanie limit zadań; po limicie eskalacja. 08-qa bez review.
stage_iter() {
  local etap="$1" pr prn head stan obecna cel rev wyn esk zmiana=1 maks="$MAKS_ITERACJI"
  [ "$etap" != 08-qa ] || die "$E_ODMOWA" "08-qa: raport QA nie ma review etapu, więc nie ma iteracji (merge po zielonym CI)"
  case "$etap" in 00-intake | 04-* | 05-plan | 06-zadania) maks=2 ;; esac
  pr="$(gh pr list --repo "$SLUG" --head "stage/$etap" --state open --json number,headRefOid --jq '.[0] // empty' 2>/dev/null)" ||
    die "$E_WYKONANIE" "gh pr list nie działa dla $SLUG"
  [ -n "$pr" ] || die "$E_ODMOWA" "brak otwartego PR z gałęzi stage/$etap"
  prn="$(jq -r .number <<<"$pr")" head="$(jq -r .headRefOid <<<"$pr")" stan="$(stan_etapu "$etap")"
  obecna="$(fm_get "$ROOT/docs/$etap/DoD.md" iteracja)"
  case "$obecna" in "" | *[!0-9]*) obecna=0 ;; esac
  if [ "$(jq -r '.iter_review // ""' <<<"$stan")" = "$head" ]; then # powtórka dla tego samego review
    cel="$(jq -r .iter_cel <<<"$stan")"
    [ "$obecna" != "$cel" ] || zmiana=0
  else
    rev="$(review_dla_heada "$prn" "$head")"
    [ -n "$rev" ] || die "$E_ODMOWA" "brak wyniku shctl review run dla bieżącego commita PR #$prn"
    [ "$(jq -r .werdykt <<<"$rev")" = FAIL ] || die "$E_ODMOWA" "ostatnie review PR #$prn to PASS; iteracja tylko po FAIL"
    cel=$(( (obecna > 0 ? obecna : 1) + 1 ))
  fi
  if [ "$cel" -gt "$maks" ]; then
    info "$etap: FAIL w iteracji $maks, eskalacja"
    set -- escalate --projekt "$PROJEKT" --dotyczy "$etap" --powod "$maks iteracje review etapu bez PASS" \
      --potrzebne "decyzja: dalsze poprawki poza limitem, zmiana zakresu etapu albo inne rozwiązanie (PR #$prn)" --json
    [ "$DRY" -eq 0 ] || set -- "$@" --dry-run
    wyn="$("$SHCTL_DIR/shctl" "$@")" || die "$E_WYKONANIE" "shctl escalate nie powiódł się: $(jq -r '.blad // ""' <<<"$wyn" 2>/dev/null)"
    esk="$(jq -r '.wynik.id' <<<"$wyn")"
    stan_etapu_zapisz "$etap" "$(jq -nc --arg e "$esk" --arg h "$head" --argjson c "$cel" '{eskalacja:$e, iter_review:$h, iter_cel:$c}')"
    wynik_json "$(jq -nc --arg e "$etap" --argjson p "$prn" --argjson i "$maks" --arg k "$esk" '{etap:$e, pr:$p, iteracja:$i, eskalacja:$k, eskalowano:true}')"
    return 0
  fi
  if [ "$DRY" -eq 0 ]; then
    ostrzez_gdy_nie_main
    stan_etapu_zapisz "$etap" "$(jq -nc --arg h "$head" --argjson c "$cel" '{iter_review:$h, iter_cel:$c}')"
    yq -i --front-matter=process ".iteracja = $cel" "$ROOT/docs/$etap/DoD.md"
    case "$(fm_get "$ROOT/docs/$etap/DoD.md" status)" in review | in-progress) zmien_status_etapu "$etap" in-progress ;; esac
    dopisz_dziennik "- $(dzis) \`$etap\`: iteracja $cel (FAIL review PR #$prn)"
  fi
  info "$PROJEKT: $etap: iteracja $cel$([ "$zmiana" -eq 1 ] && echo ", status in-progress" || echo " już podbita")"
  wynik_json "$(jq -nc --arg e "$etap" --argjson p "$prn" --argjson c "$cel" --argjson z "$zmiana" '{etap:$e, pr:$p, iteracja:$c, eskalowano:false, zmiana:($z == 1)}')"
}

komenda_main() {
  local akcja="${1:-}" etap="" notatka="" obecny cel linia zmiana=0
  case "$akcja" in
    start | review | done | escalate | iter) shift ;;
    *) die "$E_UZYCIE" "użycie: shctl stage start|review|iter|done|escalate ETAP [--notatka \"...\"]" ;;
  esac
  while [ $# -gt 0 ]; do
    case "$1" in
      --notatka) notatka="$(wartosc "$@")"; shift 2 ;;
      -*) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
      *) [ -z "$etap" ] || die "$E_UZYCIE" "nadmiarowy argument: $1"; etap="$1"; shift ;;
    esac
  done
  [ -n "$etap" ] || die "$E_UZYCIE" "brak ETAP"
  if [ "$akcja" = iter ]; then
    [ -z "$notatka" ] || die "$E_UZYCIE" "stage iter nie przyjmuje --notatka"
    zadania_init && sprawdz_etap "$etap" && stage_iter "$etap"
    return 0
  fi
  znajdz_projekt
  sprawdz_etap "$etap"
  obecny="$(fm_get "$ROOT/docs/$etap/DoD.md" status)"
  cel="$(printf '%s\n' $PRZEJSCIA | sed -n "s/^$akcja:$obecny=//p")"
  [ -n "$cel" ] || die "$E_ODMOWA" "stage $akcja niedozwolone dla $etap w statusie $obecny"
  [ "$akcja" != done ] || [ "$obecny" = done ] || sprawdz_dod_po_zmianie "$etap"
  [ "$cel" = "$obecny" ] || zmiana=1
  if [ "$DRY" -eq 0 ] && { [ "$zmiana" -eq 1 ] || [ -n "$notatka" ]; }; then
    ostrzez_gdy_nie_main
    [ "$zmiana" -eq 0 ] || zmien_status_etapu "$etap" "$cel"
    linia="- $(dzis) \`$etap\`: $cel"
    dopisz_dziennik "$linia${notatka:+, $(komorka "$notatka")}"
  fi
  info "$PROJEKT: $etap: $obecny -> $cel"
  wynik_json "$(jq -nc --arg p "$PROJEKT" --arg e "$etap" --arg o "$obecny" --arg c "$cel" --argjson z "$zmiana" \
    '{projekt:$p, etap:$e, poprzedni:$o, status:$c, zmiana:($z == 1)}')"
}
