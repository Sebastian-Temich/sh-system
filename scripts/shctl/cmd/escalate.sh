# shctl escalate --dotyczy "#NR|ETAP" --powod --potrzebne [--opcje "A;B"] [--priorytet high]
# shctl escalate close E-NNN --odpowiedz "..."
# Stan eskalacji jest w jej frontmatterze: status, poprzedni_status, powiadomiono.
# shellcheck shell=bash

kat_esk() { echo "$ROOT/docs/07-realizacja/escalations"; }

kolejny_id() {
  local f n max=0
  for f in "$(kat_esk)"/E-[0-9]*.md; do
    [ -e "$f" ] || continue
    n="$(basename "$f" .md)"
    n="$((10#${n#E-}))"
    [ "$n" -le "$max" ] || max="$n"
  done
  printf 'E-%03d' $((max + 1))
}

# Otwarta eskalacja o tym samym celu i powodzie: powtórka jej dotyczy.
znajdz_otwarta() {
  local f
  for f in "$(kat_esk)"/E-[0-9]*.md; do
    [ -e "$f" ] || continue
    if [ "$(fm_get "$f" status)" = otwarta ] && [ "$(fm_get "$f" dotyczy)" = "$1" ] &&
      [ "$(fm_get "$f" powod)" = "$2" ]; then
      basename "$f" .md
      return 0
    fi
  done
}

ile_otwartych_dla() {
  local f n=0
  for f in "$(kat_esk)"/E-[0-9]*.md; do
    [ -e "$f" ] || continue
    if [ "$(basename "$f" .md)" != "$2" ] && [ "$(fm_get "$f" status)" = otwarta ] &&
      [ "$(fm_get "$f" dotyczy)" = "$1" ]; then n=$((n + 1)); fi
  done
  echo "$n"
}

odswiez_liste() {
  local f l=""
  for f in "$(kat_esk)"/E-[0-9]*.md; do
    [ -e "$f" ] || continue
    [ "$(fm_get "$f" status)" = otwarta ] || continue
    l="$l- $(basename "$f" .md) ($(fm_get "$f" dotyczy)): $(komorka "$(fm_get "$f" powod)")"$'\n'
  done
  ustaw_sekcje "$ST" "Otwarte eskalacje" "${l:-(brak)}"
}

status_z_etykiet() {
  gh issue view "$1" --repo "$2" --json labels \
    --jq '[.labels[].name | select(startswith("status:") and . != "status:escalated")][0] // ""'
}

utworz_plik() {
  local plik="$1" id="$2" dotyczy="$3" powod="$4" potrzebne="$5" opcje="$6" priorytet="$7" poprz="$8"
  local szablon="$ROOT/docs/_szablony/eskalacja.md" linia_celu lista="" o rest t
  [ -f "$szablon" ] || die "$E_BRAK" "brak docs/_szablony/eskalacja.md"
  case "$dotyczy" in
    \#*) linia_celu="Zadanie: $dotyczy" ;;
    *) linia_celu="Etap: $dotyczy" ;;
  esac
  mkdir -p "$(dirname "$plik")"
  t="$(komorka "$powod")"
  {
    printf -- '---\nid: %s\nstatus: otwarta\npowiadomiono: nie\n---\n\n' "$id"
    ID="$id" TYTUL="$t" DATA="$(dzis)" CEL="$linia_celu" POWOD="$t" awk '
      NR == 1 { l = $0; sub(/E-NNN/, ENVIRON["ID"], l); sub(/TYTUŁ/, "", l); print l ENVIRON["TYTUL"]; next }
      /^Data: / { print "Data: " ENVIRON["DATA"]; next }
      /^Zadanie: / { print ENVIRON["CEL"]; next }
      /^Powód: / { print "Powód: " ENVIRON["POWOD"]; next }
      { print }' "$szablon"
  } >"$plik"
  fm_set "$plik" dotyczy "$dotyczy"
  fm_set "$plik" powod "$powod"
  fm_set "$plik" priorytet "$priorytet"
  fm_set "$plik" poprzedni_status "$poprz"
  fm_set "$plik" data "$(dzis)"
  ustaw_sekcje "$plik" "Czego potrzeba od właściciela" "$potrzebne"
  if [ -n "$opcje" ]; then
    rest="$opcje;"
    while [ -n "$rest" ]; do
      o="${rest%%;*}"
      rest="${rest#*;}"
      [ -z "$o" ] || lista="$lista- $o"$'\n'
    done
    ustaw_sekcje "$plik" "Opcje i rekomendacja" "$lista"
  fi
}

otworz() {
  local dotyczy="" powod="" potrzebne="" opcje="" priorytet=high id plik poprz="" nr="" etap="" slug="" nowa=0 url=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --dotyczy) dotyczy="$(wartosc "$@")"; shift 2 ;;
      --powod) powod="$(wartosc "$@")"; shift 2 ;;
      --potrzebne) potrzebne="$(wartosc "$@")"; shift 2 ;;
      --opcje) opcje="$(wartosc "$@")"; shift 2 ;;
      --priorytet) priorytet="$(wartosc "$@")"; shift 2 ;;
      *) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
    esac
  done
  [ -n "$dotyczy" ] && [ -n "$powod" ] && [ -n "$potrzebne" ] ||
    die "$E_UZYCIE" "wymagane: --dotyczy, --powod, --potrzebne"
  case "$priorytet" in min | default | high | urgent) ;; *) die "$E_UZYCIE" "nieznany priorytet: $priorytet" ;; esac
  znajdz_projekt
  case "$dotyczy" in
    \#*)
      nr="${dotyczy#\#}"
      case "$nr" in "" | *[!0-9]*) die "$E_UZYCIE" "--dotyczy: niepoprawny numer issue: $dotyczy" ;; esac
      wymagaj gh
      slug="$(slug_repo)"
      [ -n "$slug" ] || die "$E_BRAK" "origin nie wskazuje repo GitHub"
      url="https://github.com/$slug/issues/$nr"
      ;;
    *)
      etap="$dotyczy"
      sprawdz_etap "$etap"
      ;;
  esac

  id="$(znajdz_otwarta "$dotyczy" "$powod")"
  if [ -z "$id" ]; then
    nowa=1
    id="$(kolejny_id)"
  fi
  plik="$(kat_esk)/$id.md"

  if [ "$DRY" -eq 0 ]; then
    ostrzez_gdy_nie_main
    if [ "$nowa" -eq 1 ]; then
      # Odczyt przed zapisem: nieistniejące issue nie zostawia pliku eskalacji.
      if [ -n "$nr" ]; then
        poprz="$(status_z_etykiet "$nr" "$slug")" || die "$E_WYKONANIE" "nie można odczytać issue #$nr"
        poprz="${poprz#status:}"
      else
        poprz="$(fm_get "$ROOT/docs/$etap/DoD.md" status)"
        [ "$poprz" != escalated ] || poprz=in-progress
      fi
      utworz_plik "$plik" "$id" "$dotyczy" "$powod" "$potrzebne" "$opcje" "$priorytet" "$poprz"
    fi
    if [ -n "$nr" ]; then
      poprz="$(fm_get "$plik" poprzedni_status)"
      if [ -n "$poprz" ] && [ "$poprz" != escalated ]; then
        gh issue edit "$nr" --repo "$slug" --add-label status:escalated --remove-label "status:$poprz" >/dev/null ||
          die "$E_WYKONANIE" "nie można ustawić etykiety na #$nr"
      else
        gh issue edit "$nr" --repo "$slug" --add-label status:escalated >/dev/null ||
          die "$E_WYKONANIE" "nie można ustawić etykiety na #$nr"
      fi
    else
      case "$(fm_get "$ROOT/docs/$etap/DoD.md" status)" in
        done | pominiety) uwaga "etap $etap jest zamknięty, status bez zmian" ;;
        *) zmien_status_etapu "$etap" escalated ;;
      esac
    fi
    odswiez_liste
    if [ "$(fm_get "$plik" powiadomiono)" != tak ]; then
      powiadom "$priorytet" "Eskalacja $id: $PROJEKT" "$dotyczy: $powod" "$url" warning ||
        die "$E_WYKONANIE" "$id zapisana, ale powiadomienie nie wyszło; ponów tę samą komendę"
      fm_set "$plik" powiadomiono tak
    fi
  fi

  if [ "$nowa" -eq 1 ]; then info "$id: eskalacja otwarta ($dotyczy)"; else info "$id: eskalacja już otwarta ($dotyczy)"; fi
  wynik_json "$(jq -nc --arg i "$id" --arg d "$dotyczy" --arg p "${plik#"$ROOT"/}" --argjson n "$nowa" \
    '{id:$i, dotyczy:$d, plik:$p, nowa:($n == 1)}')"
}

zamknij() {
  local id="" odp="" plik dotyczy poprz nr etap slug stara cel
  while [ $# -gt 0 ]; do
    case "$1" in
      --odpowiedz) odp="$(wartosc "$@")"; shift 2 ;;
      -*) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
      *)
        [ -z "$id" ] || die "$E_UZYCIE" "nadmiarowy argument: $1"
        id="$1"
        shift
        ;;
    esac
  done
  case "$id" in
    E-[0-9][0-9][0-9]*) ;;
    *) die "$E_UZYCIE" "użycie: shctl escalate close E-NNN --odpowiedz \"...\"" ;;
  esac
  case "${id#E-}" in *[!0-9]*) die "$E_UZYCIE" "niepoprawny numer: $id" ;; esac
  [ -n "$odp" ] || die "$E_UZYCIE" "wymagane: --odpowiedz"
  znajdz_projekt
  plik="$(kat_esk)/$id.md"
  [ -f "$plik" ] || die "$E_BRAK" "brak eskalacji $id"

  if [ "$(fm_get "$plik" status)" = zamknieta ]; then
    stara="$(czytaj_sekcje "$plik" "Rozstrzygnięcie")"
    [ "$stara" = "$odp" ] || die "$E_ODMOWA" "$id jest już zamknięta z inną odpowiedzią"
    info "$id: już zamknięta"
    wynik_json "$(jq -nc --arg i "$id" '{id:$i, zamknieta:true, zmiana:false}')"
    return 0
  fi

  dotyczy="$(fm_get "$plik" dotyczy)"
  poprz="$(fm_get "$plik" poprzedni_status)"
  if [ "$DRY" -eq 0 ]; then
    ostrzez_gdy_nie_main
    # Cel zdejmujemy tylko, gdy nie ma innej otwartej eskalacji na to samo.
    if [ "$(ile_otwartych_dla "$dotyczy" "$id")" -eq 0 ]; then
      case "$dotyczy" in
        \#*)
          nr="${dotyczy#\#}"
          wymagaj gh
          slug="$(slug_repo)"
          [ -n "$slug" ] || die "$E_BRAK" "origin nie wskazuje repo GitHub"
          if [ -n "$poprz" ]; then
            gh issue edit "$nr" --repo "$slug" --remove-label status:escalated --add-label "status:$poprz" >/dev/null ||
              die "$E_WYKONANIE" "nie można zmienić etykiet #$nr; eskalacja zostaje otwarta"
          else
            gh issue edit "$nr" --repo "$slug" --remove-label status:escalated >/dev/null ||
              die "$E_WYKONANIE" "nie można zmienić etykiet #$nr; eskalacja zostaje otwarta"
          fi
          ;;
        *)
          etap="$dotyczy"
          cel="${poprz:-in-progress}"
          if [ "$(fm_get "$ROOT/docs/$etap/DoD.md" status)" = escalated ]; then
            zmien_status_etapu "$etap" "$cel"
          fi
          ;;
      esac
    fi
    ustaw_sekcje "$plik" "Rozstrzygnięcie" "$odp"
    fm_set "$plik" status zamknieta
    fm_set "$plik" data_zamkniecia "$(dzis)"
    odswiez_liste
  fi
  info "$id: zamknięta"
  wynik_json "$(jq -nc --arg i "$id" '{id:$i, zamknieta:true, zmiana:true}')"
}

komenda_main() {
  if [ "${1:-}" = close ]; then
    shift
    zamknij "$@"
  else
    otworz "$@"
  fi
}
