# Funkcje projektu: katalog, frontmatter, etapy, sekcje status.md.
# shellcheck shell=bash

ETAPY="00-intake 01-brief 02-design 03-wymagania 04-architektura 05-plan 06-zadania 07-realizacja 08-qa wydanie"
ETAPY_M="00-intake 04-architektura 05-plan 06-zadania 07-realizacja 08-qa wydanie"

ROOT=""
ST=""
KONFIG=""

# Ustawia PROJEKT i ROOT: z --projekt albo z bieżącego katalogu (także worktree).
znajdz_projekt() {
  local d wspolny
  if [ -n "$PROJEKT" ]; then
    sprawdz_nazwe "$PROJEKT"
    ROOT="$PROJEKTY/$PROJEKT"
    [ -d "$ROOT" ] || die "$E_BRAK" "brak projektu: $ROOT"
  else
    d="$PWD"
    while [ "$d" != "/" ] && [ ! -f "$d/docs/konfiguracja.md" ]; do d="$(dirname "$d")"; done
    [ -f "$d/docs/konfiguracja.md" ] ||
      die "$E_BRAK" "to nie jest katalog projektu; wejdź do projektu albo podaj --projekt NAZWA"
    ROOT="$d"
    wspolny="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [ -n "$wspolny" ]; then PROJEKT="$(basename "$(dirname "$wspolny")")"; else PROJEKT="$(basename "$ROOT")"; fi
  fi
  KONFIG="$ROOT/docs/konfiguracja.md"
  ST="$ROOT/docs/status.md"
  [ -f "$KONFIG" ] || die "$E_BRAK" "brak $KONFIG"
  wymagaj yq jq git
}

fm_get() { yq --front-matter=extract ".$2 // \"\"" "$1"; }

# fm_set PLIK KLUCZ WARTOŚĆ: wartość zawsze jako tekst, bez interpretacji przez yq.
fm_set() {
  FM_V="$3" yq -i --front-matter=process ".$2 = strenv(FM_V)" "$1"
}

tryb() { fm_get "$KONFIG" tryb_procesu; }

etap_w_trybie() {
  case "$2" in
    S) return 1 ;;
    L) return 0 ;;
    *) case " $ETAPY_M " in *" $1 "*) return 0 ;; *) return 1 ;; esac ;;
  esac
}

sprawdz_etap() {
  case " $ETAPY " in
    *" $1 "*) ;;
    *) die "$E_UZYCIE" "nieznany etap: '$1' (dozwolone: $ETAPY)" ;;
  esac
  [ -f "$ROOT/docs/$1/DoD.md" ] || die "$E_BRAK" "brak docs/$1/DoD.md"
}

# Pliki wspólne aktualizuje orkiestrator na main (proces-v1.md, „Pliki wspólne i konflikty”).
ostrzez_gdy_nie_main() {
  local g
  g="$(git -C "$ROOT" symbolic-ref --short -q HEAD 2>/dev/null || true)"
  [ -z "$g" ] || [ "$g" = main ] || uwaga "pliki wspólne zmienia się na main, a bieżąca gałąź to $g"
}

# Zastępuje treść sekcji „## NAZWA”; brakującą sekcję dopisuje na końcu pliku.
ustaw_sekcje() {
  local plik="$1" sekcja="$2" tresc="$3" nowy t
  t="$(tmp_plik)"
  printf '%s\n' "$tresc" >"$t"
  nowy="$(tmp_plik)"
  awk -v naglowek="## $sekcja" -v tresc="$t" '
    function wstaw(   l) {
      print ""
      while ((getline l < tresc) > 0) print l
      close(tresc)
      print ""
    }
    $0 == naglowek { print; wstaw(); pomin = 1; bylo = 1; next }
    pomin && /^## / { pomin = 0 }
    !pomin { print }
    END { if (!bylo) { print ""; print naglowek; wstaw() } }' "$plik" |
    awk 'NR == 1 { p = $0; next } { print p; p = $0 } END { if (p != "") print p }' >"$nowy"
  podmien_plik "$nowy" "$plik"
}

# Treść sekcji bez pustych linii na brzegach.
czytaj_sekcje() {
  awk -v naglowek="## $2" '
    $0 == naglowek { w = 1; next }
    w && /^## / { exit }
    w { print }' "$1" | sed '/./,$!d' | awk 'NF { for (; p > 0; p--) print ""; print; next } { p++ }'
}

# Etapy aktywne albo następny do rozpoczęcia. Stan wyliczany z DoD, więc powtórka nic nie zmienia.
opis_etapu() {
  local e s aktywne="" nastepny=""
  if [ "$(tryb)" = S ]; then
    echo "(tryb S: bez etapów, DoD to issue i checklista PR)"
    return
  fi
  for e in $ETAPY; do
    [ -f "$ROOT/docs/$e/DoD.md" ] || continue
    s="$(fm_get "$ROOT/docs/$e/DoD.md" status)"
    case "$s" in
      in-progress | review | escalated) aktywne="$aktywne- \`$e\`: $s"$'\n' ;;
      todo) [ -n "$nastepny" ] || nastepny="- \`$e\`: todo (następny)" ;;
    esac
  done
  if [ -n "$aktywne" ]; then
    printf '%s' "$aktywne"
  elif [ -n "$nastepny" ]; then
    echo "$nastepny"
  else
    echo "(wszystkie etapy zamknięte)"
  fi
}

odswiez_etap() { ustaw_sekcje "$ST" "Bieżący etap" "$(opis_etapu)"; }

# Wpis do „Dziennik etapów”; ten sam wpis nie powtarza się.
dopisz_dziennik() {
  local linia="$1" obecne
  [ -z "$(czytaj_sekcje "$ST" "Dziennik etapów" | grep -xF -- "$linia" || true)" ] || return 0
  obecne="$(czytaj_sekcje "$ST" "Dziennik etapów")"
  ustaw_sekcje "$ST" "Dziennik etapów" "${obecne:+$obecne
}$linia"
}

zmien_status_etapu() {
  fm_set "$ROOT/docs/$1/DoD.md" status "$2"
  odswiez_etap
}

# OWNER/REPO z origin; pusto, gdy origin nie wskazuje GitHuba.
slug_repo() {
  local u
  u="$(git -C "$ROOT" config --get remote.origin.url || true)"
  printf '%s\n' "$u" | sed -nE 's#^(https://github\.com/|git@github\.com:)([^/]+/[^/]+)$#\2#p' | sed 's/\.git$//'
}

# Zamiany bajtowe, żeby wynik nie zależał od locale.
odslugifikuj() {
  printf '%s' "$1" | LC_ALL=C sed -e 's/ą/a/g;s/ć/c/g;s/ę/e/g;s/ł/l/g;s/ń/n/g;s/ó/o/g;s/ś/s/g;s/ź/z/g;s/ż/z/g' \
    -e 's/Ą/a/g;s/Ć/c/g;s/Ę/e/g;s/Ł/l/g;s/Ń/n/g;s/Ó/o/g;s/Ś/s/g;s/Ź/z/g;s/Ż/z/g' |
    LC_ALL=C tr 'A-Z' 'a-z' | LC_ALL=C sed -E 's/[^a-z0-9]+/-/g;s/^-+//;s/-+$//' | cut -c1-60 | sed -E 's/-+$//'
}
