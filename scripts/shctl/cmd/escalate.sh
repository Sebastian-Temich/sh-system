# shctl escalate --dotyczy "#NR|ETAP" --powod --sytuacja --sprawdzono --potrzebne [--opcje "A;B"]
#   [--priorytet high] [--akceptacja] [--typ blokada|pytanie]
# --sytuacja i --sprawdzono są wymagane i niepuste: właściciel decyduje z samego pliku E-NNN.md, a puste
# sekcje „Sytuacja” i „Co już sprawdzono” (sh-dryrun, przebieg 6, E-001) zmuszały do dopytywania.
# --typ pytanie: pytanie workera o UX albo regułę biznesową (sh-worker nie zgaduje). Nie zmienia statusu
# issue ani etapu, nie zwalnia slotu (worker kontynuuje niezależne części), nie liczy się jako iteracja
# ani eskalacja w metryki.md; powiadomienie „Pytanie E-NNN: PROJEKT”, domyślny priorytet default.
# --akceptacja: decyzja do akceptacji właściciela (podniesienie trybu); powiadomienie ma tytuł
# „Czeka na Twoją akceptację: PROJEKT / podniesienie trybu” zamiast „Eskalacja E-NNN: PROJEKT”.
# shctl escalate close E-NNN --odpowiedz "..."
# Stan eskalacji jest w jej frontmatterze: status, poprzedni_status, powiadomiono.
# Wywołanie z worktree (worker, skill etapu) zapisuje w głównej kopii projektu na main, nigdy w
# worktree: jedna numeracja E-NNN dla projektu, commit robi orkiestrator. Eskalacja zadania zwalnia
# slot workera (panel dostaje etykietę eskalacja:NAZWA:NR).
# shellcheck shell=bash

# shellcheck source=../lib/zadania.sh
. "$SHCTL_DIR/lib/zadania.sh"

Z_WORKTREE=""

# Pliki eskalacji zawsze w głównej kopii projektu (katalog wspólnego .git), na gałęzi main.
uzyj_glownej_kopii() {
  local w g
  w="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$w" ] || return 0
  w="$(dirname "$w")"
  if [ "$w" != "$ROOT" ]; then
    [ -f "$w/docs/konfiguracja.md" ] || die "$E_BRAK" "brak głównej kopii projektu $w"
    Z_WORKTREE="$ROOT"
    ROOT="$w"
    KONFIG="$ROOT/docs/konfiguracja.md"
    ST="$(plik_projektu "$ROOT")"
    g="$(git -C "$ROOT" symbolic-ref --short -q HEAD 2>/dev/null || true)"
    [ "$g" = main ] || die "$E_ODMOWA" "główna kopia $ROOT jest na gałęzi ${g:-(odłączony HEAD)}, nie na main; eskalację zapisuje orkiestrator na main"
  fi
}

blokada_eskalacji() {
  [ "$DRY" -eq 0 ] || return 0
  zablokuj "$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)/shctl-escalate.lock"
}

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
      [ "$(fm_get "$f" dotyczy)" = "$1" ] && [ "$(fm_get "$f" typ)" != pytanie ]; then n=$((n + 1)); fi
  done
  echo "$n"
}

# Lista otwartych eskalacji i pytań jest w docs/Projekt.md („Czeka na Ciebie”, „Eskalacje i
# pytania”), który liczy sync-status.sh z plików E-NNN.md.
odswiez_liste() { odswiez_projekt || true; }

status_z_etykiet() {
  gh issue view "$1" --repo "$2" --json labels \
    --jq '[.labels[].name | select(startswith("status:") and . != "status:escalated")][0] // ""'
}

utworz_plik() {
  local plik="$1" id="$2" dotyczy="$3" powod="$4" potrzebne="$5" opcje="$6" priorytet="$7" poprz="$8" typ="$9"
  local sytuacja="${10}" sprawdzono="${11}"
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
  fm_set "$plik" typ "$typ"
  fm_set "$plik" dotyczy "$dotyczy"
  fm_set "$plik" powod "$powod"
  fm_set "$plik" priorytet "$priorytet"
  fm_set "$plik" poprzedni_status "$poprz"
  fm_set "$plik" data "$(dzis)"
  fm_set "$plik" otwarto "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  ustaw_sekcje "$plik" "Sytuacja" "$sytuacja"
  ustaw_sekcje "$plik" "Co już sprawdzono" "$sprawdzono"
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
  local dotyczy="" powod="" potrzebne="" opcje="" sytuacja="" sprawdzono="" priorytet="" typ=blokada id plik poprz="" nr="" etap="" slug="" nowa=0 url=""
  local akceptacja=0 tytul tresc
  while [ $# -gt 0 ]; do
    case "$1" in
      --dotyczy) dotyczy="$(wartosc "$@")"; shift 2 ;;
      --powod) powod="$(wartosc "$@")"; shift 2 ;;
      --potrzebne) potrzebne="$(wartosc "$@")"; shift 2 ;;
      --sytuacja) sytuacja="$(wartosc "$@")"; shift 2 ;;
      --sprawdzono) sprawdzono="$(wartosc "$@")"; shift 2 ;;
      --opcje) opcje="$(wartosc "$@")"; shift 2 ;;
      --priorytet) priorytet="$(wartosc "$@")"; shift 2 ;;
      --akceptacja) akceptacja=1; shift ;;
      --typ) typ="$(wartosc "$@")"; shift 2 ;;
      *) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
    esac
  done
  [ -n "$dotyczy" ] && [ -n "$powod" ] && [ -n "$potrzebne" ] ||
    die "$E_UZYCIE" "wymagane: --dotyczy, --powod, --sytuacja, --sprawdzono, --potrzebne"
  # Same spacje to też pusta sekcja: odmowa, zanim powstanie plik.
  [ -n "${sytuacja//[[:space:]]/}" ] ||
    die "$E_UZYCIE" "--sytuacja pusta: opisz stan (co robisz, co się dzieje, gdzie: plik, test, PR), sekcja „Sytuacja”"
  [ -n "${sprawdzono//[[:space:]]/}" ] ||
    die "$E_UZYCIE" "--sprawdzono puste: wypisz, co już sprawdzono lub próbowano i z jakim wynikiem, sekcja „Co już sprawdzono”"
  case "$typ" in blokada | pytanie) ;; *) die "$E_UZYCIE" "--typ: blokada albo pytanie, jest: $typ" ;; esac
  [ "$typ" = blokada ] || [ "$akceptacja" -eq 0 ] || die "$E_UZYCIE" "--akceptacja tylko z --typ blokada"
  if [ -z "$priorytet" ]; then
    if [ "$typ" = pytanie ]; then priorytet=default; else priorytet=high; fi
  fi
  case "$priorytet" in min | default | high | urgent) ;; *) die "$E_UZYCIE" "nieznany priorytet: $priorytet" ;; esac
  znajdz_projekt
  uzyj_glownej_kopii
  blokada_eskalacji
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
      if [ "$typ" = pytanie ]; then
        poprz=""
        if [ -n "$nr" ]; then
          status_z_etykiet "$nr" "$slug" >/dev/null || die "$E_WYKONANIE" "nie można odczytać issue #$nr"
        fi
      elif [ -n "$nr" ]; then
        poprz="$(status_z_etykiet "$nr" "$slug")" || die "$E_WYKONANIE" "nie można odczytać issue #$nr"
        poprz="${poprz#status:}"
      else
        poprz="$(fm_get "$ROOT/docs/$etap/DoD.md" status)"
        [ "$poprz" != escalated ] || poprz=in-progress
      fi
      utworz_plik "$plik" "$id" "$dotyczy" "$powod" "$potrzebne" "$opcje" "$priorytet" "$poprz" "$typ" "$sytuacja" "$sprawdzono"
    fi
    # Istniejąca eskalacja zachowuje swój typ (powtórka tej samej komendy).
    typ="$(fm_get "$plik" typ)"
    [ -n "$typ" ] || typ=blokada
    if [ "$typ" = pytanie ]; then
      :
    elif [ -n "$nr" ]; then
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
      tytul="Eskalacja $id: $PROJEKT"
      tresc="$dotyczy: $powod"
      if [ "$typ" = pytanie ]; then
        tytul="Pytanie $id: $PROJEKT"
      elif [ "$akceptacja" -eq 1 ]; then
        tytul="Czeka na Twoją akceptację: $PROJEKT / podniesienie trybu"
        tresc="$id, $tresc"
      fi
      powiadom "$priorytet" "$tytul" "$tresc" "$url" warning ||
        die "$E_WYKONANIE" "$id zapisana, ale powiadomienie nie wyszło; ponów tę samą komendę"
      fm_set "$plik" powiadomiono tak
    fi
  fi
  if [ -n "$nr" ] && [ "$typ" != pytanie ]; then
    SLOT_PANEL="$(zwolnij_slot "$nr")"
    [ -z "$SLOT_PANEL" ] || info "panel $SLOT_PANEL: etykieta $(etykieta_eskalacji "$nr"), slot workera wolny"
  fi

  if [ "$nowa" -eq 1 ]; then info "$id: eskalacja otwarta ($dotyczy, $typ)"; else info "$id: eskalacja już otwarta ($dotyczy)"; fi
  [ -z "$Z_WORKTREE" ] || info "zapisano w $ROOT (main), nie w worktree; commit robi orkiestrator"
  wynik_json "$(jq -nc --arg i "$id" --arg d "$dotyczy" --arg p "${plik#"$ROOT"/}" --argjson n "$nowa" \
    --arg k "$ROOT" --arg w "$Z_WORKTREE" --arg s "${SLOT_PANEL:-}" --arg t "$typ" \
    '{id:$i, typ:$t, dotyczy:$d, plik:$p, katalog:$k, z_worktree:($w != ""), nowa:($n == 1),
      slot_zwolniony:($s != ""), panel:(if $s == "" then null else $s end)}')"
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
  uzyj_glownej_kopii
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
    # Cel zdejmujemy tylko, gdy nie ma innej otwartej eskalacji na to samo. Pytanie celu nie zmieniało.
    if [ "$(fm_get "$plik" typ)" != pytanie ] && [ "$(ile_otwartych_dla "$dotyczy" "$id")" -eq 0 ]; then
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
