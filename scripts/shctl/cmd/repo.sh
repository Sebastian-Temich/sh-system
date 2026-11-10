# shctl repo opis [--opis "..."] [--topics "a,b"] [--website URL] [--dry-run]: tożsamość repo projektu
# na GitHubie (opis, tematy, strona). Wywołuje orkiestrator na checkpointach specyfikacji, planu i
# odbioru: najpierw --dry-run pokazuje właścicielowi dokładną komendę gh repo edit, po jego zgodzie ta
# sama komenda bez --dry-run. Temat sh-projekt jest zawsze. Opis do 350 znaków.
# shellcheck shell=bash

# shellcheck source=../lib/repo.sh
. "$SHCTL_DIR/lib/repo.sh"

komenda_main() {
  local sub="${1:-}" opis="" tematy="" strona="" slug tekst
  [ "$sub" = opis ] || die "$E_UZYCIE" "użycie: shctl repo opis [--opis \"...\"] [--topics \"a,b\"] [--website URL]"
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --opis) opis="$(wartosc "$@")"; shift 2 ;;
      --topics) tematy="$(wartosc "$@")"; shift 2 ;;
      --website) strona="$(wartosc "$@")"; shift 2 ;;
      *) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
    esac
  done
  [ -n "$opis$tematy$strona" ] || die "$E_UZYCIE" "podaj co najmniej jedno: --opis, --topics, --website"
  opis="$(komorka "$opis")"
  [ "${#opis}" -le 350 ] || die "$E_UZYCIE" "--opis ma ${#opis} znaków, GitHub przyjmuje do 350"
  case "$strona" in "" | https://*) ;; *) die "$E_UZYCIE" "--website musi zaczynać się od https://" ;; esac
  tematy="$(printf '%s' "$tematy" | tr -d ' ')"
  case ",$tematy," in *",sh-projekt,"*) ;; *) tematy="sh-projekt${tematy:+,$tematy}" ;; esac
  case "$tematy" in *[!a-z0-9,\ -]*) die "$E_UZYCIE" "--topics: małe litery, cyfry i -, rozdzielone przecinkami" ;; esac
  znajdz_projekt
  wymagaj gh
  slug="$(slug_repo)"
  [ -n "$slug" ] || die "$E_BRAK" "origin projektu $PROJEKT nie wskazuje repo GitHub"
  repo_edit_argumenty "$slug" "$opis" "$tematy" "$strona"
  tekst="$(repo_edit_tekst)"
  if [ "$DRY" -eq 1 ]; then
    info "Komenda do pokazania właścicielowi: $tekst"
  else
    "${REPO_EDIT[@]}" >/dev/null || die "$E_WYKONANIE" "gh repo edit $slug nieudane"
    info "$slug: zaktualizowano opis i tematy"
  fi
  wynik_json "$(jq -nc --arg r "$slug" --arg k "$tekst" --arg o "$opis" --arg t "$tematy" --arg w "$strona" \
    '{repo:$r, komenda:$k, opis:(if $o == "" then null else $o end), tematy:($t | split(",")), strona:(if $w == "" then null else $w end)}')"
}
