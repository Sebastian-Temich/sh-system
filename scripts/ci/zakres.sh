#!/usr/bin/env bash
# scripts/ci/zakres.sh - zakres testów w GitHub Actions (oszczędność minut, docs/serwer.md, „CI”).
#
# Wejście (zmienne środowiska, ustawia workflow):
#   ZDARZENIE      github.event_name
#   BAZA, GLOWA    SHA bazy i głowy PR (pull_request)
#   WZORCE_DOCS    wzorce case (spacją) plików bez testów, np. "docs/* *.md"
#   WZORCE_SKRYPTY wzorce plików, które wymagają testów skryptów (opcjonalnie)
#   NOCNE_GODZINY  okno nocnego przebiegu: pełne testy tylko przy commitach z tylu godzin (26)
# Wyjście (GITHUB_OUTPUT albo stdout): kod=true|false, skrypty=true|false, powod=...
#   pull_request       kod: jakikolwiek plik spoza WZORCE_DOCS; skrypty: plik z WZORCE_SKRYPTY
#   push (main)        smoke: kod=false, skrypty=false (pełne testy przeszły na PR)
#   schedule           kod=skrypty=true, gdy na main były commity w oknie; inaczej false
#   workflow_dispatch  kod=skrypty=true
# Błąd diffa albo nieznane zdarzenie: kod=skrypty=true (lepiej zapłacić minutę niż przepuścić błąd).
set -uo pipefail

WYJSCIE="${GITHUB_OUTPUT:-/dev/stdout}"
kod=true skrypty=true powod=""

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
      kod=false skrypty=false
      set -f
      while IFS= read -r p; do
        [ -n "$p" ] || continue
        pasuje "$p" "${WZORCE_DOCS:-}" || kod=true
        [ -z "${WZORCE_SKRYPTY:-}" ] || ! pasuje "$p" "$WZORCE_SKRYPTY" || skrypty=true
      done <<<"$pliki"
      set +f
      [ -n "${WZORCE_SKRYPTY:-}" ] || skrypty="$kod"
      powod="PR: $(printf '%s\n' "$pliki" | grep -c .) plik(ów)"
    else
      powod="PR: brak diffa ${BAZA:-?}...${GLOWA:-?}, pełne testy"
    fi
    ;;
  push)
    kod=false skrypty=false powod="push: smoke"
    ;;
  schedule)
    if [ -n "$(git log -1 --since="${NOCNE_GODZINY:-26} hours ago" --format=%H 2>/dev/null)" ]; then
      powod="nocny: commity w ostatnich ${NOCNE_GODZINY:-26} h"
    else
      kod=false skrypty=false powod="nocny: brak commitów w ostatnich ${NOCNE_GODZINY:-26} h"
    fi
    ;;
  workflow_dispatch) powod="ręcznie: pełne testy" ;;
  *) powod="nieznane zdarzenie '${ZDARZENIE:-}': pełne testy" ;;
esac

printf 'kod=%s\nskrypty=%s\npowod=%s\n' "$kod" "$skrypty" "$powod" >>"$WYJSCIE"
echo "zakres: kod=$kod skrypty=$skrypty ($powod)" >&2
