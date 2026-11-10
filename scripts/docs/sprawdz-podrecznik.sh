#!/usr/bin/env bash
# Sprawdza podręcznik właściciela docs/podrecznik/*.md względem kodu:
#   - każda komenda „shctl KOMENDA [PODKOMENDA]” istnieje w `shctl --help`;
#   - każda nazwa sh-NAZWA to skill pluginu (plugin/skills/NAZWA albo plugin/skills/techniczne/NAZWA),
#     skrypt serwera (scripts/server/NAZWA.sh) albo jedna z nazw spoza skilli (NIE_SKILLE niżej);
#   - 01-start.md wymienia każdy skill roli (plugin/skills/sh-*) jako `sh-NAZWA`;
#   - każdy wikilink [[PLIK]] i [[PLIK#Nagłówek]] prowadzi do istniejącego pliku w docs/podrecznik/
#     albo docs/ i do istniejącego nagłówka.
# Komendy shctl opisuje docs/shctl.md, generowany z --help (scripts/docs/shctl-md.sh).
# Linie ze słowami „etap B” (także „etapu B”, „etapie B”) opisują funkcje zapowiedziane i są pomijane.
# W zwykłym tekście nazwę piszemy jako `shctl` (w backtickach); „shctl SŁOWO” bez nich to komenda.
# Użycie: scripts/docs/sprawdz-podrecznik.sh [KATALOG_REPO]
# Kody: 0 zgodny, 1 niezgodności (lista na stderr), 2 błędne użycie.
set -euo pipefail

REPO="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)}"
PODR="$REPO/docs/podrecznik"
SHCTL="$REPO/scripts/shctl/shctl"
[ -d "$PODR" ] || { echo "BŁĄD: brak $PODR" >&2; exit 2; }
[ -f "$SHCTL" ] || { echo "BŁĄD: brak $SHCTL" >&2; exit 2; }

# Nazwy sh-* w podręczniku, które nie są skillami ani skryptami serwera.
NIE_SKILLE=' sh-system sh-template-projekt sh-dryrun sh-test sh-projekt sh-ochrona-galezi sh-imac '
ETAP_B='etap(u|ie)? B'
bledy=0

blad() {
  echo "$1" >&2
  bledy=$((bledy + 1))
}

# Komendy z pomocy shctl: linie „  KOMENDA [PODKOMENDA|...] ...”. Podkomenda to drugie słowo z
# małych liter (np. „start|review|done”). KOMENDY: nazwy; PODK: „KOMENDA PODKOMENDA”; WYMAGA:
# komendy, których każda linia pomocy ma podkomendę.
pomoc="$(bash "$SHCTL" --help)" || { echo "BŁĄD: shctl --help nie działa" >&2; exit 2; }
KOMENDY=" "
PODK=" "
BEZ_PODK=" "
while read -r kom druga _; do
  case "$KOMENDY" in *" $kom "*) ;; *) KOMENDY="$KOMENDY$kom " ;; esac
  if printf '%s' "$druga" | grep -Eq '^[a-z][a-z|-]*$'; then
    for p in $(printf '%s' "$druga" | tr '|' ' '); do PODK="$PODK$kom:$p "; done
  else
    BEZ_PODK="$BEZ_PODK$kom "
  fi
done < <(printf '%s\n' "$pomoc" | grep -E '^  [a-z]')

ma_podk() { case "$PODK" in *" $1:"*) return 0 ;; esac; return 1; }

# Wszystkie trafienia jednym przejściem awk: „PLIK:LINIA:TRAFIENIE”, bez linii z „etap B”.
trafienia() {
  awk -v re="$1" -v pomin="$ETAP_B" '
    $0 ~ pomin { next }
    { s = $0
      while (match(s, re)) {
        print FILENAME ":" FNR ":" substr(s, RSTART, RLENGTH)
        s = substr(s, RSTART + RLENGTH)
      } }' "$PODR"/*.md
}

while IFS=: read -r plik nr tekst; do
  read -r _ kom pod <<<"$tekst"
  miejsce="${plik#"$REPO"/}:$nr"
  case "$KOMENDY" in
    *" $kom "*) ;;
    *) blad "$miejsce: nieznana komenda „shctl ${kom}”"; continue ;;
  esac
  [ -n "${pod:-}" ] && ma_podk "$kom" || continue
  case "$PODK" in *" ${kom}:${pod} "*) continue ;; esac
  # Komenda z formą bez podkomendy (np. escalate) może mieć po nazwie zwykły tekst.
  case "$BEZ_PODK" in *" $kom "*) continue ;; esac
  blad "$miejsce: nieznana podkomenda „shctl $kom ${pod}”"
done < <(trafienia 'shctl +[a-z][a-z-]*( +[a-z][a-z-]*)?')

while IFS=: read -r plik nr tekst; do
  sh="sh-${tekst#*sh-}"
  [ -f "$REPO/plugin/skills/$sh/SKILL.md" ] && continue
  [ -f "$REPO/plugin/skills/techniczne/$sh/SKILL.md" ] && continue
  [ -f "$REPO/scripts/server/$sh.sh" ] && continue
  case "$NIE_SKILLE" in *" $sh "*) continue ;; esac
  blad "${plik#"$REPO"/}:$nr: nieznany skill „${sh}”"
done < <(trafienia '(^|[^A-Za-z0-9_.-])sh-[a-z][a-z-]*[a-z]')

# Kompletność: każdy skill roli w 01-start.md.
for s in "$REPO"/plugin/skills/sh-*/SKILL.md; do
  [ -f "$s" ] || continue
  sk="$(basename "$(dirname "$s")")"
  grep -q "\`$sk\`" "$PODR/01-start.md" 2>/dev/null ||
    blad "docs/podrecznik/01-start.md: brak skilla „${sk}”"
done

# Wikilinki: [[PLIK]], [[PLIK#Nagłówek]], [[PLIK|tekst]]; PLIK w docs/podrecznik/ albo docs/.
while IFS=: read -r plik nr tekst; do
  cel="${tekst#\[\[}"
  cel="${cel%\]\]}"
  cel="${cel%%|*}"
  nazwa="${cel%%#*}"
  naglowek=""
  case "$cel" in *"#"*) naglowek="${cel#*#}" ;; esac
  if [ -z "$nazwa" ]; then
    docel="$plik"
  elif [ -f "$PODR/$nazwa.md" ]; then
    docel="$PODR/$nazwa.md"
  elif [ -f "$REPO/docs/$nazwa.md" ]; then
    docel="$REPO/docs/$nazwa.md"
  else
    blad "${plik#"$REPO"/}:$nr: martwy link „[[${cel}]]”"
    continue
  fi
  [ -z "$naglowek" ] && continue
  grep -Fxq "$naglowek" <<<"$(sed -n 's/^#\{1,6\} //p' "$docel")" ||
    blad "${plik#"$REPO"/}:$nr: brak nagłówka „${naglowek}” w ${docel#"$REPO"/}"
done < <(trafienia '[[][[][^]]+[]][]]')

if [ "$bledy" -gt 0 ]; then
  echo "Podręcznik niezgodny z kodem: $bledy błąd(ów)" >&2
  exit 1
fi
echo "Podręcznik zgodny z kodem: komendy shctl, skille i linki istnieją"
