#!/usr/bin/env bash
# scripts/ci/zakres.sh - zakres testów w GitHub Actions (oszczędność minut, docs/serwer.md, „CI i minuty GitHub Actions”).
#
# Wejście (zmienne środowiska, ustawia workflow):
#   ZDARZENIE      github.event_name
#   BAZA, GLOWA    SHA bazy i głowy PR (pull_request)
#   WZORCE_DOCS    wzorce case (spacją) plików bez testów, np. "docs/* *.md"
#   WZORCE_SKRYPTY wzorce plików, które wymagają testów skryptów (opcjonalnie)
#   WZORCE_BEZ_E2E wzorce plików, których zmiana nie wymaga E2E, np. "docs/* *.md scripts/*" (opcjonalnie;
#                  bez nich e2e = kod)
#   WZORCE_BAZA    wzorce plików bazy, których zmiana uruchamia testy bazy, np. "supabase/*" (opcjonalnie;
#                  bez nich baza=false na PR)
#   NOCNE_GODZINY  okno nocnego przebiegu: pełne testy tylko przy commitach z tylu godzin (26)
# Wyjście (GITHUB_OUTPUT albo stdout): kod=true|false, skrypty=true|false, e2e=true|false,
#   baza=true|false, powod=...
#   pull_request       kod: jakikolwiek plik spoza WZORCE_DOCS; skrypty: plik z WZORCE_SKRYPTY;
#                      e2e: plik spoza WZORCE_DOCS i WZORCE_BEZ_E2E (kod aplikacji); baza: plik z WZORCE_BAZA
#   push (main)        smoke: kod=skrypty=e2e=baza=false (pełne testy przeszły na PR)
#   schedule           kod=skrypty=e2e=baza=true, gdy na main były commity w oknie; inaczej false
#   workflow_dispatch  kod=skrypty=e2e=baza=true
# Błąd diffa albo nieznane zdarzenie: wszystko true (lepiej zapłacić minutę niż przepuścić błąd).
# e2e jest zawsze false, gdy w repo nie ma playwright.config.* (szablon, projekt bez UI), a baza, gdy nie ma
# supabase/config.toml (projekt bez bazy).
set -uo pipefail

WYJSCIE="${GITHUB_OUTPUT:-/dev/stdout}"
kod=true skrypty=true e2e=true baza=true powod=""

pasuje() {
  local plik="$1" w
  for w in $2; do
    # shellcheck disable=SC2254
    case "$plik" in $w) return 0 ;; esac
  done
  return 1
}

case "${ZDARZENIE:-}" in
  pull_request)
    if pliki="$(git diff --name-only "${BAZA:-}...${GLOWA:-}" 2>/dev/null)" && [ -n "${BAZA:-}" ]; then
      kod=false skrypty=false e2e=false baza=false
      set -f
      while IFS= read -r p; do
        [ -n "$p" ] || continue
        pasuje "$p" "${WZORCE_DOCS:-}" || kod=true
        pasuje "$p" "${WZORCE_DOCS:-} ${WZORCE_BEZ_E2E:-}" || e2e=true
        [ -z "${WZORCE_SKRYPTY:-}" ] || ! pasuje "$p" "$WZORCE_SKRYPTY" || skrypty=true
        [ -z "${WZORCE_BAZA:-}" ] || ! pasuje "$p" "$WZORCE_BAZA" || baza=true
      done <<<"$pliki"
      set +f
      [ -n "${WZORCE_SKRYPTY:-}" ] || skrypty="$kod"
      powod="PR: $(printf '%s\n' "$pliki" | grep -c .) plik(ów)"
    else
      powod="PR: brak diffa ${BAZA:-?}...${GLOWA:-?}, pełne testy"
    fi
    ;;
  push)
    kod=false skrypty=false e2e=false baza=false powod="push: smoke"
    ;;
  schedule)
    if [ -n "$(git log -1 --since="${NOCNE_GODZINY:-26} hours ago" --format=%H 2>/dev/null)" ]; then
      powod="nocny: commity w ostatnich ${NOCNE_GODZINY:-26} h"
    else
      kod=false skrypty=false e2e=false baza=false powod="nocny: brak commitów w ostatnich ${NOCNE_GODZINY:-26} h"
    fi
    ;;
  workflow_dispatch) powod="ręcznie: pełne testy" ;;
  *) powod="nieznane zdarzenie '${ZDARZENIE:-}': pełne testy" ;;
esac

if ! compgen -G "playwright.config.*" >/dev/null; then
  e2e=false
fi
[ -f supabase/config.toml ] || baza=false
printf 'kod=%s\nskrypty=%s\ne2e=%s\nbaza=%s\npowod=%s\n' "$kod" "$skrypty" "$e2e" "$baza" "$powod" >>"$WYJSCIE"
echo "zakres: kod=$kod skrypty=$skrypty e2e=$e2e baza=$baza ($powod)" >&2
