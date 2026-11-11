#!/usr/bin/env bash
# Sprawdza plugin software-house: manifest, marketplace i zgodność każdego SKILL.md z kontraktem
# plugin/skills/_kontrakt.md (skille ról i skille techniczne w plugin/skills/techniczne/). Kody: 0 zgodne, 1 niezgodności (lista na stderr), 2 błędne użycie.
# Użycie: scripts/plugin/sprawdz-skille.sh [KATALOG_REPO]
set -euo pipefail

REPO="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)}"
[ -d "$REPO/plugin/skills" ] || { echo "BŁĄD: brak $REPO/plugin/skills" >&2; exit 2; }
command -v jq >/dev/null || { echo "BŁĄD: brak jq" >&2; exit 2; }

KONTRAKT="$REPO/plugin/skills/_kontrakt.md"
SEKCJE='Rola i granice
Wejście
Wyjście
Komendy shctl
Procedura
Tryby
DoD
Kryteria review
Eskalacja
Zasady wspólne
Przykład'
TRYBY='### Tryb S
### Tryb M
### Tryb L i etap B'
ZDANIE_WEJSCIA='Czytasz TYLKO te pliki i źródła.'
POLE_REVIEW='- [ ] Review PASS (zaznacza reviewer, nie ten skill)'
bledy=0

blad() {
  printf 'BŁĄD: %s\n' "$*" >&2
  bledy=$((bledy + 1))
}

blok_zasad() { awk '/<!-- zasady-wspolne:start -->/{w=1} w{print} /<!-- zasady-wspolne:end -->/{w=0}' "$1"; }
frontmatter() { awk 'NR == 1 && $0 == "---" { w = 1; next } w && $0 == "---" { exit } w' "$1"; }
pole() { frontmatter "$1" | sed -n "s/^$2: *//p" | head -1; }
# Treść sekcji „## NAZWA” do następnej „## ”.
# Wynik sekcji trafia do grep -q przez <<<, nie potokiem: przy pipefail grep -q kończący się po
# pierwszym trafieniu daje awk SIGPIPE na długiej sekcji i fałszywy błąd.
sekcja() { awk -v n="## $2" '$0 == n { w = 1; next } w && /^## / { exit } w' "$1"; }

# --- manifest i marketplace -----------------------------------------------------------------------
PJ="$REPO/plugin/.claude-plugin/plugin.json"
MJ="$REPO/.claude-plugin/marketplace.json"
if ! jq -e '.name | type == "string" and test("^[a-z0-9]+(-[a-z0-9]+)*$")' "$PJ" >/dev/null 2>&1; then
  blad "$PJ: brak poprawnego name (kebab-case)"
fi
if ! jq -e '(.name | type == "string") and (.owner.name | type == "string") and (.plugins | type == "array")' "$MJ" >/dev/null 2>&1; then
  blad "$MJ: wymagane name, owner.name i plugins"
else
  nazwa="$(jq -r .name "$PJ" 2>/dev/null || true)"
  wpis="$(jq -c --arg n "$nazwa" '.plugins[] | select(.name == $n)' "$MJ")"
  if [ -z "$wpis" ]; then
    blad "$MJ: brak wpisu dla pluginu $nazwa (nazwa wpisu musi być równa nazwie z plugin.json)"
  else
    zrodlo="$(jq -r .source <<<"$wpis")"
    case "$zrodlo" in
      ./*) [ -d "$REPO/$zrodlo/.claude-plugin" ] || blad "$MJ: source $zrodlo nie wskazuje katalogu pluginu" ;;
      *) blad "$MJ: source musi być ścieżką względną ./..." ;;
    esac
    case "$zrodlo" in *..*) blad "$MJ: source nie może zawierać .." ;; esac
  fi
fi

# --- kontrakt ---------------------------------------------------------------------------------------
[ -f "$KONTRAKT" ] || { blad "brak $KONTRAKT"; exit 1; }
WZOR_ZASAD="$(blok_zasad "$KONTRAKT")"
[ -n "$WZOR_ZASAD" ] || blad "$KONTRAKT: brak bloku zasady-wspolne"
KOMENDY="$(bash "$REPO/scripts/shctl/shctl" --help | awk '/^  [a-z]/ { print $1 }' | sort -u)"

ile=0
for f in "$REPO"/plugin/skills/*/SKILL.md; do
  [ -e "$f" ] || continue
  ile=$((ile + 1))
  kat="$(basename "$(dirname "$f")")"
  wz="plugin/skills/$kat/SKILL.md"

  # Frontmatter.
  [ "$(head -1 "$f")" = "---" ] || { blad "$wz: brak frontmattera"; continue; }
  name="$(pole "$f" name)"
  opis="$(pole "$f" description)"
  [ "$name" = "$kat" ] || blad "$wz: name '$name' różne od nazwy katalogu '$kat'"
  [ -n "$opis" ] || blad "$wz: brak description"
  case "$opis" in *"<"* | *">"*) blad "$wz: description nie może zawierać < ani >" ;; esac
  [ "${#opis}" -le 1536 ] || blad "$wz: description dłuższy niż 1536 znaków"
  blokady="$(pole "$f" disable-model-invocation)/$(pole "$f" user-invocable)"
  printf '%s' "$name" | grep -qE '^sh-[a-z0-9]+(-[a-z0-9]+)*$' || blad "$wz: name ma postać sh-ROLA"
  printf '%s' "$opis" | grep -q 'Użyj, gdy' || blad "$wz: description bez triggerów „Użyj, gdy …”"
  [ "$blokady" != "true/false" ] || blad "$wz: skill zablokowany (usuń disable-model-invocation i user-invocable)"

  # Sekcje w kolejności, bez dodatkowych.
  jest="$(grep '^## ' "$f" | sed 's/^## //')"
  [ "$jest" = "$SEKCJE" ] || blad "$wz: sekcje ## inne niż w kontrakcie: $(printf '%s' "$jest" | paste -sd '|' -)"

  tryby="$(sekcja "$f" Tryby | grep '^### ' || true)"
  [ "$tryby" = "$TRYBY" ] || blad "$wz: Tryby muszą mieć ### Tryb S, ### Tryb M, ### Tryb L i etap B"

  grep -qF "$ZDANIE_WEJSCIA" <<<"$(sekcja "$f" "Wejście")" || blad "$wz: Wejście bez zdania „$ZDANIE_WEJSCIA”"
  grep -q '^- `' <<<"$(sekcja "$f" "Wejście")" || blad "$wz: Wejście bez listy ścieżek w backtickach"
  grep -q '^- `' <<<"$(sekcja "$f" "Wyjście")" || blad "$wz: Wyjście bez listy ścieżek w backtickach"
  grep -qE '^[0-9]+\. ' <<<"$(sekcja "$f" "Procedura")" || blad "$wz: Procedura bez kroków numerowanych"
  # Wynik bez review (raport QA, SH-lite F1) ma pole „nie dotyczy” z powodem zamiast pola review.
  grep -qxF -- "$POLE_REVIEW" <<<"$(sekcja "$f" "DoD")" ||
    grep -qE '^- \[-\] Review PASS \(nie dotyczy: [^)]+\)$' <<<"$(sekcja "$f" "DoD")" ||
    blad "$wz: DoD bez pola „$POLE_REVIEW”"
  grep -q '🔴' <<<"$(sekcja "$f" "Kryteria review")" || blad "$wz: Kryteria review bez wag 🔴🟡⚪"
  grep -q 'shctl escalate' <<<"$(sekcja "$f" "Eskalacja")" || blad "$wz: Eskalacja bez wywołania shctl escalate"

  # Komendy shctl: każde wywołanie w bloku kodu to istniejąca podkomenda, albo „Brak.”.
  wyw="$(sekcja "$f" "Komendy shctl" | awk '/^```/ { w = !w; next } w && /^shctl / { print $2 }')"
  if [ -z "$wyw" ]; then
    grep -q '^Brak\.' <<<"$(sekcja "$f" "Komendy shctl")" || blad "$wz: Komendy shctl bez wywołań i bez „Brak.”"
  fi
  for k in $wyw; do
    grep -qx -- "$k" <<<"$KOMENDY" || blad "$wz: nieznana komenda shctl: $k"
  done

  # Wywołania w blokach kodu (linie z \ na końcu sklejone): escalate z wymaganymi --sytuacja i
  # --sprawdzono (shctl odmawia bez nich), polecenie dla workera przez shctl task polecenie, nie herdr
  # agent prompt (nie zna etykiet worker:NAZWA:NR; sh-dryrun, przebieg 6).
  kod="$(awk '/^```/ { w = !w; next } w { if (sub(/\\$/, "")) { b = b $0; next } print b $0; b = "" }' "$f")"
  while IFS= read -r l; do
    case "$l" in
      *"shctl escalate --dotyczy"*)
        case "$l" in *--sytuacja*--sprawdzono* | *--sprawdzono*--sytuacja*) ;;
          *) blad "$wz: shctl escalate bez --sytuacja i --sprawdzono: ${l:0:80}" ;; esac ;;
    esac
    case "$l" in *"herdr agent prompt"*) blad "$wz: herdr agent prompt w bloku kodu (użyj shctl task polecenie NR)" ;; esac
  done <<<"$kod"

  [ "$(blok_zasad "$f")" = "$WZOR_ZASAD" ] || blad "$wz: blok Zasady wspólne różni się od kontraktu"
  grep -q '<!-- zasady-wspolne:start -->' <<<"$(sekcja "$f" "Zasady wspólne")" || blad "$wz: blok zasad poza sekcją Zasady wspólne"
done
[ "$ile" -gt 0 ] || blad "brak skilli w plugin/skills/*/SKILL.md"

# --- skille techniczne (kontrakt: „Skille techniczne”) ------------------------------------------------
SEKCJE_TECH='Zakres
Lista kontrolna
Weryfikacja: lokalnie i w CI
Przykłady
Błędy z naszych projektów'
MAKS_LINII_TECH=150
ile_tech=0
for f in "$REPO"/plugin/skills/techniczne/*/SKILL.md; do
  [ -e "$f" ] || continue
  ile_tech=$((ile_tech + 1))
  kat="$(basename "$(dirname "$f")")"
  wz="plugin/skills/techniczne/$kat/SKILL.md"

  [ "$(head -1 "$f")" = "---" ] || { blad "$wz: brak frontmattera"; continue; }
  name="$(pole "$f" name)"
  opis="$(pole "$f" description)"
  [ "$name" = "$kat" ] || blad "$wz: name '$name' różne od nazwy katalogu '$kat'"
  printf '%s' "$name" | grep -qE '^sh-[a-z0-9]+(-[a-z0-9]+)*$' || blad "$wz: name ma postać sh-NAZWA"
  [ -n "$opis" ] || blad "$wz: brak description"
  case "$opis" in *"<"* | *">"*) blad "$wz: description nie może zawierać < ani >" ;; esac
  [ "${#opis}" -le 1536 ] || blad "$wz: description dłuższy niż 1536 znaków"
  printf '%s' "$opis" | grep -q 'Użyj, gdy' || blad "$wz: description bez triggerów „Użyj, gdy …”"
  [ ! -e "$REPO/plugin/skills/$kat" ] || blad "$wz: nazwa zajęta przez plugin/skills/$kat (skill roli)"

  linie="$(wc -l <"$f" | tr -d ' ')"
  [ "$linie" -le "$MAKS_LINII_TECH" ] || blad "$wz: $linie linii, limit $MAKS_LINII_TECH"

  jest="$(grep '^## ' "$f" | sed 's/^## //')"
  [ "$jest" = "$SEKCJE_TECH" ] || blad "$wz: sekcje ## inne niż w kontrakcie skilli technicznych: $(printf '%s' "$jest" | paste -sd '|' -)"

  lk="$(sekcja "$f" "Lista kontrolna")"
  grep -qE '^[0-9]+\. ' <<<"$lk" || blad "$wz: Lista kontrolna bez punktów numerowanych"
  bez_wagi="$(grep -E '^[0-9]+\. ' <<<"$lk" | grep -vE '^[0-9]+\. (🔴|🟡|⚪) ' || true)"
  [ -z "$bez_wagi" ] || blad "$wz: punkty Listy kontrolnej bez wagi 🔴🟡⚪ na początku: $(printf '%s' "$bez_wagi" | cut -c1-40 | paste -sd '|' -)"

  wer="$(sekcja "$f" "Weryfikacja: lokalnie i w CI")"
  grep -qF -- '--log-failed' <<<"$wer" || blad "$wz: Weryfikacja bez odczytu CI przez gh run view RUN --log-failed"
  grep -qE '[^[:space:]]' <<<"$(sekcja "$f" "Przykłady")" || blad "$wz: pusta sekcja Przykłady"
  grep -q '^- ' <<<"$(sekcja "$f" "Błędy z naszych projektów")" || blad "$wz: Błędy z naszych projektów bez listy przypadków"

  # Bloki ```sh: jedna prosta komenda na linię (sandbox, CLAUDE.md).
  zlozone="$(awk '/^```sh$/ { w = 1; next } /^```/ { w = 0 } w' "$f" | grep -E '&&|\|\||;|\||>|^[A-Z_]+=' || true)"
  [ -z "$zlozone" ] || blad "$wz: blok sh z komendą złożoną (&&, ||, ;, |, >, zmienna przed komendą): $(printf '%s' "$zlozone" | head -1)"

  # Skill zewnętrzny: adnotacja źródła i wersji.
  if grep -q '<!-- źródło:' "$f"; then
    grep -qE '^<!-- źródło: [^ ]+, wersja: [0-9a-f]{7,40}, skopiowano: [0-9]{4}-[0-9]{2}-[0-9]{2}, licencja: [^>]+ -->$' "$f" ||
      blad "$wz: adnotacja źródła w złym formacie (źródło, wersja SHA, skopiowano RRRR-MM-DD, licencja)"
  fi
done

# Bazowe z mapy warstw muszą istnieć, inaczej każdy dispatch kończy się ostrzeżeniem.
WARSTWY="$REPO/plugin/warstwy-skilli.yaml"
if [ -f "$WARSTWY" ] && command -v yq >/dev/null; then
  for n in $(yq -r '.bazowe[]?' "$WARSTWY"); do
    [ -f "$REPO/plugin/skills/techniczne/$n/SKILL.md" ] || [ -f "$REPO/plugin/skills/$n/SKILL.md" ] ||
      blad "$WARSTWY: skill bazowy $n nie istnieje"
  done
fi

if [ "$bledy" -gt 0 ]; then
  echo "sprawdz-skille: $bledy niezgodności" >&2
  exit 1
fi
echo "sprawdz-skille: $ile skill(i) zgodne z kontraktem, $ile_tech skill(i) techniczne zgodne"
