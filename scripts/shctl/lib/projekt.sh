# Funkcje projektu: katalog, frontmatter, etapy, widok docs/Projekt.md (dawniej docs/status.md).
# shellcheck shell=bash

# Etapy z DoD.md (tryb M). Tryb L z osobnymi etapami jest odłożony (proces-v1.md). Stan realizacji
# jest w issue, więc 07-realizacja nie ma DoD (katalog zostaje na raporty i eskalacje).
# Zestaw zależy od wersja_procesu w docs/konfiguracja.md projektu: 2 (SH-lite F3a) ma jeden etap
# 04-plan, a brak pola (wersja 1, projekty sprzed migracji) osobne 04-architektura i 05-plan.
ETAPY_V1="00-intake 04-architektura 05-plan 06-zadania 08-qa wydanie"
ETAPY_V2="00-intake 04-plan 06-zadania 08-qa wydanie"
ETAPY="$ETAPY_V2"
WERSJA_PROCESU=2

# Ustawia WERSJA_PROCESU i ETAPY z KONFIG.
ustal_etapy() {
  WERSJA_PROCESU="$(yq --front-matter=extract '.wersja_procesu // 1' "$KONFIG" 2>/dev/null || echo 1)"
  case "$WERSJA_PROCESU" in
    1) ETAPY="$ETAPY_V1" ;;
    2) ETAPY="$ETAPY_V2" ;;
    *) die "$E_UZYCIE" "$KONFIG: wersja_procesu='$WERSJA_PROCESU', dozwolone 1 albo 2" ;;
  esac
}

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
  ST="$(plik_projektu "$ROOT")"
  [ -f "$KONFIG" ] || die "$E_BRAK" "brak $KONFIG"
  wymagaj yq jq git
  ustal_etapy
}

# Widok projektu: docs/Projekt.md (SH-lite F5). Projekt przed pierwszą synchronizacją nowym
# sync-status.sh ma jeszcze docs/status.md; wtedy shctl czyta i pisze stary plik.
plik_projektu() {
  if [ -f "$1/docs/Projekt.md" ] || [ ! -f "$1/docs/status.md" ]; then
    printf '%s' "$1/docs/Projekt.md"
  else
    printf '%s' "$1/docs/status.md"
  fi
}

# Historia projektu: docs/historia.md („Punkt przekazania”, „Dziennik etapów”, lista zadań). Projekt
# z szablonem sprzed historii (sync-status.sh jej nie generuje) trzyma dziennik dalej w ST.
plik_historii() {
  local r="${1:-${ROOT_G:-$ROOT}}"
  if [ -f "$r/docs/historia.md" ] || ! grep -qxF '## Dziennik etapów' "$(plik_projektu "$r")" 2>/dev/null; then
    printf '%s' "$r/docs/historia.md"
  else
    plik_projektu "$r"
  fi
}

# Odświeża docs/Projekt.md, docs/historia.md i 06-zadania/index.md przez scripts/sync-status.sh projektu po każdej zmianie
# stanu (etap, eskalacja, zadanie). Na main głównej kopii; bez commita (robi go orkiestrator). Błąd
# (np. brak sieci) to ostrzeżenie: stan w plikach DoD, eskalacjach i issue jest prawdziwy, a widok
# dogoni go przy następnej zmianie.
odswiez_projekt() {
  local r="${ROOT_G:-$ROOT}" s slug
  [ "$DRY" -eq 0 ] || return 0
  s="$r/scripts/sync-status.sh"
  [ -f "$s" ] || return 1
  slug="${SLUG:-$(ROOT="$r" slug_repo)}"
  if [ -n "$slug" ]; then
    (cd "$r" && bash "$s" --repo "$slug" >/dev/null) || { uwaga "scripts/sync-status.sh zakończył się błędem"; return 1; }
  else
    (cd "$r" && bash "$s" >/dev/null) || { uwaga "scripts/sync-status.sh zakończył się błędem"; return 1; }
  fi
  ST="$(plik_projektu "$r")"
}

fm_get() { yq --front-matter=extract ".$2 // \"\"" "$1"; }

# fm_set PLIK KLUCZ WARTOŚĆ: wartość zawsze jako tekst, bez interpretacji przez yq.
fm_set() {
  FM_V="$3" yq -i --front-matter=process ".$2 = strenv(FM_V)" "$1"
}

tryb() { fm_get "$KONFIG" tryb_procesu; }

# Tryb S nie ma etapów DoD; w trybie M należą do niego wszystkie etapy z ETAPY.
etap_w_trybie() { [ "$2" != S ]; }

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
    pomin && (/^## / || /^<!-- [a-z-]+:start -->$/) { pomin = 0 }
    !pomin { print }
    END { if (!bylo) { print ""; print naglowek; wstaw() } }' "$plik" |
    awk 'NR == 1 { p = $0; next } { print p; p = $0 } END { if (p != "") print p }' >"$nowy"
  podmien_plik "$nowy" "$plik"
}

# Treść sekcji bez pustych linii na brzegach (do następnego ## albo znacznika bloku generowanego).
czytaj_sekcje() {
  awk -v naglowek="## $2" '
    $0 == naglowek { w = 1; next }
    w && (/^## / || /^<!-- [a-z-]+:(start|end) -->$/) { exit }
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

# Etap jest w widoku projektu („Gdzie jesteśmy”), który liczy sync-status.sh z DoD.md.
odswiez_etap() { odswiez_projekt || true; }

# Wpis do „Dziennik etapów” w docs/historia.md; ten sam wpis nie powtarza się, „(brak)” znika.
dopisz_dziennik() {
  local linia="$1" obecne h
  h="$(plik_historii "$ROOT")"
  [ -f "$h" ] || printf '# Historia projektu\n\n## Punkt przekazania\n\n(brak)\n\n## Dziennik etapów\n\n(brak)\n' >"$h"
  obecne="$(czytaj_sekcje "$h" "Dziennik etapów" | grep -vxF '(brak)' || true)"
  [ -z "$(printf '%s\n' "$obecne" | grep -xF -- "$linia" || true)" ] || return 0
  ustaw_sekcje "$h" "Dziennik etapów" "${obecne:+$obecne
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
