#!/usr/bin/env bash
# Generuje docs/shctl.md z pomocy shctl: `shctl --help` i `shctl KOMENDA --help` dla każdej komendy
# z przeglądu (pierwsze słowo linii „  KOMENDA …”), w kolejności przeglądu. Źródło tekstu:
# scripts/shctl/pomoc/*.txt. Każda komenda bez pliku pomocy to błąd.
# Użycie: scripts/docs/shctl-md.sh [--sprawdz] [KATALOG_REPO]
#   bez opcji   zapisuje docs/shctl.md
#   --sprawdz   porównuje z docs/shctl.md (CI); różnica: kod 1 i diff na stderr
# Kody: 0 zgodny albo zapisany, 1 niezgodny albo brak pomocy komendy, 2 błędne użycie.
set -euo pipefail

SPRAWDZ=0
if [ "${1:-}" = "--sprawdz" ]; then
  SPRAWDZ=1
  shift
fi
REPO="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)}"
SHCTL="$REPO/scripts/shctl/shctl"
CEL="$REPO/docs/shctl.md"
[ -f "$SHCTL" ] || { echo "BŁĄD: brak $SHCTL" >&2; exit 2; }

przeglad="$(bash "$SHCTL" --help)" || { echo "BŁĄD: shctl --help nie działa" >&2; exit 1; }
komendy=""
while read -r kom _; do
  case " $komendy " in *" $kom "*) ;; *) komendy="${komendy:+$komendy }$kom" ;; esac
done < <(printf '%s\n' "$przeglad" | grep -E '^  [a-z]')

generuj() {
  local kom tekst
  printf '# shctl\n\n'
  printf '<!-- Plik generowany przez scripts/docs/shctl-md.sh z `shctl --help` i `shctl KOMENDA --help`.\n'
  printf '     Nie edytuj: zmień scripts/shctl/pomoc/*.txt i uruchom skrypt. CI sprawdza zgodność. -->\n\n'
  printf 'CLI z mechaniką procesu (`docs/proces.md`): agent decyduje i pisze treść, a `shctl` wykonuje\n'
  printf 'operacje na plikach, GitHubie i panelach herdr. Źródło: `scripts/shctl/` (`cmd/` komendy,\n'
  printf '`lib/`, `pomoc/` teksty pomocy, `tests/` bats). Symlink `/Users/Shared/sh/bin/shctl` zakłada\n'
  printf '`scripts/server/install.sh`. Zależności: bash 3.2+, gh, jq, yq (mikefarah), git, herdr.\n\n'
  printf 'Komendy: '
  local pierwsza=1
  for kom in $komendy; do
    [ "$pierwsza" -eq 1 ] || printf ', '
    printf '[%s](#%s)' "$kom" "$kom"
    pierwsza=0
  done
  printf '.\n\n## shctl --help\n\n```text\n%s\n```\n' "$przeglad"
  for kom in $komendy; do
    tekst="$(bash "$SHCTL" "$kom" --help)" || { echo "BŁĄD: shctl $kom --help nie działa" >&2; return 1; }
    printf '\n## %s\n\n```text\n%s\n```\n' "$kom" "$tekst"
  done
}

wynik="$(generuj)"
if [ "$SPRAWDZ" -eq 0 ]; then
  printf '%s\n' "$wynik" >"$CEL"
  echo "Zapisano $CEL ($(printf '%s\n' "$wynik" | wc -l | tr -d ' ') linii)"
  exit 0
fi
if [ -f "$CEL" ] && [ "$(cat "$CEL")" = "$wynik" ]; then
  echo "docs/shctl.md zgodny z pomocą shctl"
  exit 0
fi
echo "docs/shctl.md niezgodny z pomocą shctl: uruchom scripts/docs/shctl-md.sh i zacommituj wynik" >&2
# Plik tymczasowy zamiast <(...): w sandboxie Claude Code diff nie otwiera /dev/fd.
nowy="$(mktemp "${TMPDIR:-/tmp}/shctl-md.XXXXXX")"
printf '%s\n' "$wynik" >"$nowy"
stary="$CEL"
[ -f "$stary" ] || stary=/dev/null
diff "$stary" "$nowy" >&2 || true
rm -f "$nowy"
exit 1
