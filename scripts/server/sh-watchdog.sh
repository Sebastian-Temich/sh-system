#!/bin/bash
# ~/sh/bin/sh-watchdog.sh - strażnik limitów subskrypcji (bez AI). LaunchAgent co 5 minut.
#
#   sh-watchdog.sh     jeden przebieg: odnowienia, skan paneli herdr, kontrola orkiestratora
#
# 1. Wiersze ~/sh/limity.md z godziną „Do” w przeszłości usuwa i wysyła „Limit X odnowiony”.
# 2. W panelach workspace „sh” czyta ostatnie linie i szuka wzorców z ~/sh/watchdog-wzorce.txt.
#    Nowy komunikat: wiersz w limity.md (format: docs/shctl.md) i powiadomienie „Limit X do HH:MM”.
# 3. Gdy w panelu orkiestratora nie działa claude remote-control z cwd $SH_DIR (lib/system.sh),
#    uruchamia sh-start.sh --no-attach
#    i wysyła „Orkiestrator uruchomiony ponownie” (flaga ~/sh/stan/autostart.off wyłącza restart).
# Etap A: strażnik nie wznawia pracy, robi to właściciel („wznów” do orkiestratora).
#
# Jedno powiadomienie na zdarzenie: aktywny wiersz wykonawcy wycisza kolejne komunikaty, a teksty
# już obsłużone pamięta ~/sh/stan/watchdog-widziane.txt (do 12 h od zniknięcia z paneli).
# Komunikat bez godziny dostaje szacunek teraz + 5 h.
#
# Zmienne (testy): SH_DIR, SH_NOTIFY_CMD, SH_WATCHDOG_WS (sh), SH_WATCHDOG_LINIE (40),
# SH_WATCHDOG_TERAZ (epoch), SH_WATCHDOG_PAUZA (5, s między próbami notify), SH_START_CMD,
# SH_WATCHDOG_ORKIESTRATOR (1; 0 wyłącza kontrolę), SH_WATCHDOG_ORCH_CZEKAJ (15, s po restarcie).
# Napisany pod /bin/bash 3.2 z macOS: bez tablic asocjacyjnych i ${x,,}.
# Bez -u: w bash 3.2 rozwinięcie pustej tablicy "${a[@]}" to błąd unbound variable.
set -o pipefail
shopt -s nocasematch

SH_DIR="${SH_DIR:-$HOME/sh}"

# Kontrola orkiestratora i PATH: scripts/server/lib/system.sh (wspólna z sh-start.sh i doctorem).
# ~/sh/bin/sh-watchdog.sh to dowiązanie, więc katalog repo bierzemy z celu dowiązania.
src="${BASH_SOURCE[0]}"
while [ -L "$src" ]; do
  dir="$(cd -P "$(dirname "$src")" && pwd)"
  src="$(readlink "$src")"
  case "$src" in /*) ;; *) src="$dir/$src" ;; esac
done
# shellcheck source=lib/system.sh
. "$(cd -P "$(dirname "$src")" && pwd)/lib/system.sh"
unset src dir
sh_uzupelnij_path
LIMITY="$SH_DIR/limity.md"
WZORCE="$SH_DIR/watchdog-wzorce.txt"
WIDZIANE="$SH_DIR/stan/watchdog-widziane.txt"
LOG="$SH_DIR/logs/watchdog.log"
LOCK="$SH_DIR/stan/watchdog.lock"
NOTIFY="${SH_NOTIFY_CMD:-$SH_DIR/bin/notify.sh}"
WS_LABEL="${SH_WATCHDOG_WS:-sh}"
LINIE="${SH_WATCHDOG_LINIE:-40}"
PAUZA="${SH_WATCHDOG_PAUZA:-5}"
TERAZ="${SH_WATCHDOG_TERAZ:-$(date +%s)}"
SH_START="${SH_START_CMD:-$SH_DIR/bin/sh-start.sh}"
ORCH_PILNUJ="${SH_WATCHDOG_ORKIESTRATOR:-1}"
ORCH_CZEKAJ="${SH_WATCHDOG_ORCH_CZEKAJ:-15}"
SZACUNEK=$((5 * 3600))
PAMIEC=$((12 * 3600))
NAGLOWEK='| Wykonawca | Od | Do | Źródło |'
SEPARATOR='|---|---|---|---|'

mkdir -p "$SH_DIR/stan" "$SH_DIR/logs"

log() {
  local linia
  linia="$(date '+%F %T') $*"
  printf '%s\n' "$linia" >>"$LOG"
  [ ! -t 1 ] || printf '%s\n' "$linia"
}

# Rotacja: jeden poprzedni plik, limit 1 MB.
if [ -f "$LOG" ] && [ "$(wc -c <"$LOG")" -gt 1048576 ]; then
  mv -f "$LOG" "$LOG.1"
fi

# --- Czas (BSD date na macOS, GNU date w CI) -----------------------------------------------

# "YYYY-MM-DD HH:MM" w czasie lokalnym (albo TZ) -> epoch.
epoch_z() {
  date -j -f '%Y-%m-%d %H:%M:%S' "$1:00" +%s 2>/dev/null || date -d "$1:00" +%s 2>/dev/null
}

# epoch, format -> tekst w czasie lokalnym.
data_z() {
  date -r "$1" "+$2" 2>/dev/null || date -d "@$1" "+$2"
}

# Godzina dla ludzi: HH:MM dziś, inaczej z datą.
godzina_ludzka() {
  if [ "$(data_z "$1" %F)" = "$(data_z "$TERAZ" %F)" ]; then
    data_z "$1" %H:%M
  else
    data_z "$1" '%Y-%m-%d %H:%M'
  fi
}

# Epoch odnowienia z tekstu komunikatu (od miejsca dopasowania). Pusto, gdy brak godziny.
czas_odnowienia() {
  local org="$1" t re rest suma=0 n jedn h m ap mies dzien rok strefa=""
  t="$(printf '%s' "$org" | tr 'A-Z' 'a-z')"

  # Starszy Claude: „...limit reached|1762106400”.
  re='\|([0-9]{10})'
  if [[ $t =~ $re ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi

  # Godzina zegarowa po słowie kluczowym, opcjonalnie z datą i strefą w nawiasie.
  re='(resets?|reset at|again at|until)[ :]+(at )?(.*)'
  if [[ $t =~ $re ]]; then
    rest="${BASH_REMATCH[3]}"
    re='^(((jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.? ([0-9]{1,2})(st|nd|rd|th)?,? *([0-9]{4})?,? *(at )?)?([0-9]{1,2})(:([0-9]{2}))? *(am|pm)?)'
    if [[ $rest =~ $re ]] && { [ -n "${BASH_REMATCH[11]}" ] || [ -n "${BASH_REMATCH[10]}" ]; }; then
      mies="${BASH_REMATCH[3]}" dzien="${BASH_REMATCH[4]}" rok="${BASH_REMATCH[6]}"
      h=$((10#${BASH_REMATCH[8]})) m=$((10#${BASH_REMATCH[10]:-0})) ap="${BASH_REMATCH[11]}"
      [ "$ap" != pm ] || [ "$h" -eq 12 ] || h=$((h + 12))
      [ "$ap" != am ] || [ "$h" -ne 12 ] || h=0
      if [ "$h" -le 23 ] && [ "$m" -le 59 ]; then
        re='\(([A-Za-z]+/[A-Za-z_]+)\)'
        if [[ $org =~ $re ]] && [ -e "/usr/share/zoneinfo/${BASH_REMATCH[1]}" ]; then
          strefa="${BASH_REMATCH[1]}"
        fi
        czas_zegarowy "$h" "$m" "$mies" "$dzien" "$rok" "$strefa"
        return
      fi
    fi
  fi

  # Względnie: „try again in 2 hours 5 minutes”, „resets in 3h 20m”.
  re='(^|[^a-z])in ([0-9].*)'
  if [[ $t =~ $re ]]; then
    rest="${BASH_REMATCH[2]}"
    re='^[ ,]*(and )?([0-9]+) ?(days?|d|hours?|hrs?|h|minutes?|mins?|m)([^a-z]|$)(.*)'
    while [[ $rest =~ $re ]]; do
      n=$((10#${BASH_REMATCH[2]})) jedn="${BASH_REMATCH[3]}" rest="${BASH_REMATCH[5]}"
      case "$jedn" in
        d*) suma=$((suma + n * 86400)) ;;
        h*) suma=$((suma + n * 3600)) ;;
        *) suma=$((suma + n * 60)) ;;
      esac
    done
    [ "$suma" -eq 0 ] || echo $((TERAZ + suma))
  fi
}

# h m [mies dzien rok strefa] -> epoch. Bez daty: dziś, a gdy minęło ponad godzinę, jutro.
# Godzina sprzed mniej niż godziny zostaje dzisiejsza (limit już odnowiony).
czas_zegarowy() {
  local h="$1" m="$2" mies="$3" dzien="$4" rok="$5" i nr=0 e hm
  STREFA="$6"
  hm="$(printf '%02d:%02d' "$h" "$m")"
  if [ -n "$mies" ]; then
    for i in jan feb mar apr may jun jul aug sep oct nov dec; do
      nr=$((nr + 1))
      [ "$i" != "$mies" ] || break
    done
    [ -n "$rok" ] || rok="$(data_z "$TERAZ" %Y)"
    e="$(w_strefie epoch_z "$(printf '%04d-%02d-%02d' "$rok" "$nr" "$dzien") $hm")"
    if [ -z "$5" ] && [ -n "$e" ] && [ "$e" -lt $((TERAZ - 86400)) ]; then
      e="$(w_strefie epoch_z "$(printf '%04d-%02d-%02d' $((rok + 1)) "$nr" "$dzien") $hm")"
    fi
  else
    e="$(w_strefie epoch_z "$(w_strefie data_z "$TERAZ" %F) $hm")"
    if [ -n "$e" ] && [ "$e" -lt $((TERAZ - 3600)) ]; then
      e="$(w_strefie epoch_z "$(w_strefie data_z $((TERAZ + 86400)) %F) $hm")"
    fi
  fi
  [ -z "$e" ] || echo "$e"
}

# Komenda w strefie z komunikatu (np. Europe/Warsaw); bez strefy w czasie lokalnym. Puste TZ
# oznaczałoby UTC, dlatego nie ustawiamy go wcale.
w_strefie() {
  if [ -n "$STREFA" ]; then TZ="$STREFA" "$@"; else "$@"; fi
}
STREFA=""

# --- Powiadomienia ------------------------------------------------------------------------

powiadom() {
  local i
  for i in 1 2 3; do
    "$NOTIFY" "$1" "$2" "$3" >/dev/null 2>&1 && { log "powiadomienie: $3"; return 0; }
    [ "$i" -eq 3 ] || sleep "$PAUZA"
  done
  log "BLAD: powiadomienie nie wyszło po 3 próbach: $3"
  return 1
}

# --- limity.md ------------------------------------------------------------------------------

# Wiersze strażnika w tablicach W_WYK, W_OD, W_DO, W_ZR; pozostałe wpisy (listy, inne tabele)
# zostają w INNE bez zmian, bo też są blokadą dla shctl.
W_WYK=() W_OD=() W_DO=() W_ZR=() INNE=()
ZMIANA=0

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  printf '%s' "${s%"${s##*[![:space:]]}"}"
}

wczytaj_limity() {
  local linia naglowek=1 reszta a b c d
  [ -f "$LIMITY" ] || return 0
  while IFS= read -r linia || [ -n "$linia" ]; do
    case "$linia" in
      '| '*)
        if [ "$naglowek" = 1 ]; then naglowek=0; continue; fi
        reszta="${linia#|}" reszta="${reszta%|}"
        IFS='|' read -r a b c d <<<"$reszta"
        if [ -n "$(trim "$a")" ] && [ -n "$(trim "$c")" ] && [[ $reszta != *'|'*'|'*'|'*'|'* ]] &&
          [ "$(trim "$a")" != brak ]; then
          W_WYK+=("$(trim "$a")") W_OD+=("$(trim "$b")") W_DO+=("$(trim "$c")") W_ZR+=("$(trim "$d")")
        else
          INNE+=("- $(trim "$reszta")")
        fi
        ;;
      '|'*) ;;
      '- '*) INNE+=("$linia") ;;
    esac
  done <"$LIMITY"
}

zapisz_limity() {
  local i tmp="$LIMITY.tmp.$$"
  {
    echo '# Limity'
    echo
    echo 'Plik prowadzi ~/sh/bin/sh-watchdog.sh, format: sh-system/docs/shctl.md. Wiersz znika po'
    echo 'odnowieniu limitu. Brak wierszy oznacza brak wstrzymań.'
    echo
    echo "$NAGLOWEK"
    echo "$SEPARATOR"
    for i in "${!W_WYK[@]}"; do
      echo "| ${W_WYK[$i]} | ${W_OD[$i]} | ${W_DO[$i]} | ${W_ZR[$i]} |"
    done
    if [ "${#INNE[@]}" -gt 0 ]; then
      echo
      printf '%s\n' "${INNE[@]}"
    fi
  } >"$tmp" && mv -f "$tmp" "$LIMITY"
}

usun_wiersz() {
  local i=$1 n
  n=$((${#W_WYK[@]} - 1))
  W_WYK=("${W_WYK[@]:0:i}" "${W_WYK[@]:i+1:n}")
  W_OD=("${W_OD[@]:0:i}" "${W_OD[@]:i+1:n}")
  W_DO=("${W_DO[@]:0:i}" "${W_DO[@]:i+1:n}")
  W_ZR=("${W_ZR[@]:0:i}" "${W_ZR[@]:i+1:n}")
}

odnowienia() {
  local i e
  i=$((${#W_WYK[@]} - 1))
  while [ "$i" -ge 0 ]; do
    e="$(epoch_z "${W_DO[$i]%% (*}")"
    if [ -n "$e" ] && [ "$e" -le "$TERAZ" ]; then
      log "odnowienie: ${W_WYK[$i]} (do ${W_DO[$i]}, ${W_ZR[$i]})"
      powiadom default "Limit ${W_WYK[$i]} odnowiony" "Limit ${W_WYK[$i]} odnowiony, możesz wznowić"
      usun_wiersz "$i"
      ZMIANA=1
    fi
    i=$((i - 1))
  done
}

# --- Skan paneli --------------------------------------------------------------------------

P_WYK=() P_RE=()
wczytaj_wzorce() {
  local linia wyk re
  if [ ! -f "$WZORCE" ]; then
    log "BLAD: brak $WZORCE (install.sh kopiuje go z repo)"
    return 1
  fi
  while IFS= read -r linia || [ -n "$linia" ]; do
    linia="$(trim "$linia")"
    case "$linia" in '' | '#'*) continue ;; esac
    wyk="${linia%%[[:space:]]*}"
    re="$(trim "${linia#"$wyk"}")"
    [ -n "$re" ] || { log "UWAGA: wzorzec bez wyrażenia: $linia"; continue; }
    P_WYK+=("$wyk") P_RE+=("$re")
  done <"$WZORCE"
  [ "${#P_WYK[@]}" -gt 0 ] || { log "BLAD: $WZORCE nie ma wzorców"; return 1; }
}

WIDZIANE_TERAZ=""
SKAN_OK=0

wiersz_wykonawcy() {
  local i
  for i in "${!W_WYK[@]}"; do
    [ "${W_WYK[$i]}" != "$1" ] || { echo "$i"; return 0; }
  done
  return 1
}

zgloszenie() {
  local wyk="$1" tekst="$2" zrodlo="$3" e szac="" i stary
  e="$(czas_odnowienia "$tekst")"
  if [ -z "$e" ]; then
    e=$((TERAZ + SZACUNEK))
    szac=" (szacunek)"
  fi
  if [ "$e" -le "$TERAZ" ]; then
    log "limit $wyk w $zrodlo już odnowiony ($(godzina_ludzka "$e")), pomijam"
    return
  fi
  if i="$(wiersz_wykonawcy "$wyk")"; then
    stary="$(epoch_z "${W_DO[$i]%% (*}")"
    if [ -z "$stary" ] || [ "$e" -le $((stary + 600)) ]; then
      log "limit $wyk w $zrodlo: już zapisany (do ${W_DO[$i]})"
      return
    fi
    log "limit $wyk przesunięty: ${W_DO[$i]} -> $(data_z "$e" '%Y-%m-%d %H:%M') ($zrodlo)"
    W_DO[$i]="$(data_z "$e" '%Y-%m-%d %H:%M')$szac" W_ZR[$i]="$zrodlo"
  else
    log "wykryto limit $wyk w $zrodlo, odnowienie $(data_z "$e" '%Y-%m-%d %H:%M')$szac"
    W_WYK+=("$wyk") W_OD+=("$(data_z "$TERAZ" '%Y-%m-%d %H:%M')")
    W_DO+=("$(data_z "$e" '%Y-%m-%d %H:%M')$szac") W_ZR+=("$zrodlo")
  fi
  ZMIANA=1
  powiadom high "Limit $wyk" "Limit $wyk do $(godzina_ludzka "$e")$szac. Po odnowieniu napisz orkiestratorowi: wznów"
}

skanuj_panel() {
  local id="$1" etykieta="$2" tekst linia j klucz zrodlo
  tekst="$(herdr pane read "$id" --source recent-unwrapped --lines "$LINIE" 2>/dev/null)" || {
    log "UWAGA: nie udało się odczytać panelu $id"
    SKAN_OK=0
    return
  }
  zrodlo="panel ${etykieta:-bez nazwy} ($id)"
  zrodlo="${zrodlo//|//}"
  while IFS= read -r linia; do
    for j in "${!P_RE[@]}"; do
      if [[ $linia =~ ${P_RE[$j]} ]]; then
        # Klucz: tekst od dopasowania do końca linii, więc echo w innym panelu (np. w grep) to
        # ten sam komunikat.
        klucz="${BASH_REMATCH[0]}${linia#*"${BASH_REMATCH[0]}"}"
        klucz="$(printf '%s' "${P_WYK[$j]}|$klucz" | tr -s '[:space:]' ' ')"
        klucz="$(trim "$klucz")"
        WIDZIANE_TERAZ="$WIDZIANE_TERAZ$klucz"$'\n'
        if ! grep -qxF -- "$klucz" "$WIDZIANE.klucze" 2>/dev/null &&
          ! printf '%s' "$WIDZIANE_NOWE" | grep -qxF -- "$klucz"; then
          WIDZIANE_NOWE="$WIDZIANE_NOWE$klucz"$'\n'
          zgloszenie "${P_WYK[$j]}" "${klucz#*|}" "$zrodlo"
        fi
        break
      fi
    done
  done <<<"$tekst"
}

WIDZIANE_NOWE=""
skanuj() {
  local ws panele id etykieta
  command -v herdr >/dev/null || { log "UWAGA: brak herdr w PATH, pomijam skan"; return; }
  command -v jq >/dev/null || { log "UWAGA: brak jq w PATH, pomijam skan"; return; }
  ws="$(herdr workspace list 2>/dev/null |
    jq -r --arg l "$WS_LABEL" '[.result.workspaces[] | select(.label == $l)][0].workspace_id // empty')" || ws=""
  if [ -z "$ws" ]; then
    log "UWAGA: serwer herdr nie odpowiada albo brak workspace $WS_LABEL, pomijam skan"
    return
  fi
  wczytaj_wzorce || return
  panele="$(herdr pane list --workspace "$ws" 2>/dev/null |
    jq -r '.result.panes[] | [.pane_id, (.label // "")] | @tsv')" || {
    log "UWAGA: nie udało się pobrać listy paneli $ws"
    return
  }
  # Klucze z poprzednich przebiegów do szybkiego grep.
  cut -f2- "$WIDZIANE" 2>/dev/null >"$WIDZIANE.klucze" || : >"$WIDZIANE.klucze"
  SKAN_OK=1
  N_PANELI=0
  while IFS=$'\t' read -r id etykieta; do
    [ -n "$id" ] || continue
    N_PANELI=$((N_PANELI + 1))
    skanuj_panel "$id" "$etykieta"
  done <<<"$panele"
  zapisz_widziane
  rm -f "$WIDZIANE.klucze"
}

# Widziane teraz dostają bieżący czas; niewidziane wypadają po PAMIEC. Przy nieudanym skanie
# nic nie wypada, żeby stary komunikat nie wrócił jako nowy.
zapisz_widziane() {
  local tmp="$WIDZIANE.tmp.$$" teraz_plik="$WIDZIANE.teraz.$$"
  touch "$WIDZIANE"
  printf '%s' "$WIDZIANE_TERAZ" >"$teraz_plik"
  awk -v teraz="$TERAZ" -v pamiec="$PAMIEC" -v ok="$SKAN_OK" '
    BEGIN { FS = OFS = "\t" }
    FILENAME == ARGV[1] { if ($0 != "") teraz_w[$0] = 1; next }
    $2 != "" { stary[$2] = $1 }
    END {
      for (k in teraz_w) print teraz, k
      for (k in stary) if (!(k in teraz_w) && (ok != 1 || teraz - stary[k] < pamiec)) print stary[k], k
    }' "$teraz_plik" "$WIDZIANE" >"$tmp" && mv -f "$tmp" "$WIDZIANE"
  rm -f "$teraz_plik" "$tmp"
}

# --- Orkiestrator ---------------------------------------------------------------------------

# Orkiestrator: orkiestrator_dziala z lib/system.sh (panel „orkiestrator” w workspace $WS_LABEL,
# proces claude remote-control z cwd $SH_DIR).
ORK_WS="$WS_LABEL"

# Brak orkiestratora: sh-start.sh --no-attach i powiadomienie. Flaga autostart.off wyłącza
# także ten restart. Nieudany restart zgłaszany raz, do pierwszego udanego.
pilnuj_orkiestratora() {
  local blad="$SH_DIR/stan/orkiestrator-restart-blad" i obcy
  [ "$ORCH_PILNUJ" = 1 ] || return 0
  if [ -e "$SH_DIR/stan/autostart.off" ]; then
    orkiestrator_dziala || log "orkiestrator nie działa, restart wyłączony flagą autostart.off"
    return 0
  fi
  command -v herdr >/dev/null && command -v jq >/dev/null || {
    log "UWAGA: brak herdr albo jq w PATH, pomijam kontrolę orkiestratora"
    return 0
  }
  orkiestrator_dziala && { rm -f "$blad"; return 0; }
  # Instancja poza panelem blokuje start drugiej; restart nic by nie dał.
  obcy="$(ork_pid_poza_panelem)"
  if [ -n "$obcy" ]; then
    log "UWAGA: claude remote-control (PID $obcy) działa w $SH_DIR poza panelem orkiestratora, nie restartuję"
    return 0
  fi
  if [ ! -x "$SH_START" ]; then
    log "BLAD: orkiestrator nie działa, brak $SH_START"
    return 0
  fi
  log "orkiestrator nie działa, uruchamiam $SH_START --no-attach"
  "$SH_START" --no-attach >>"$SH_DIR/logs/sh-start.log" 2>&1 || log "UWAGA: $SH_START zakończył się błędem"
  for ((i = 0; i < ORCH_CZEKAJ; i++)); do
    orkiestrator_dziala && break
    sleep 1
  done
  if orkiestrator_dziala; then
    rm -f "$blad"
    log "orkiestrator uruchomiony ponownie"
    powiadom high "Orkiestrator" "Orkiestrator uruchomiony ponownie"
  else
    log "BLAD: orkiestrator nie wstał po restarcie (log: $SH_DIR/logs/sh-start.log)"
    [ -e "$blad" ] && return 0
    touch "$blad"
    powiadom urgent "Orkiestrator" "Orkiestrator nie wstał po restarcie, sprawdź ~/sh/logs/sh-start.log"
  fi
}

# --- Przebieg -------------------------------------------------------------------------------

if ! mkdir "$LOCK" 2>/dev/null; then
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +10 2>/dev/null)" ]; then
    log "UWAGA: usuwam stary lock $LOCK"
    rmdir "$LOCK" 2>/dev/null
    mkdir "$LOCK" 2>/dev/null || { log "BLAD: nie mogę założyć $LOCK"; exit 1; }
  else
    log "poprzedni przebieg trwa, pomijam"
    exit 0
  fi
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

N_PANELI=0
wczytaj_limity
odnowienia
skanuj
[ "$ZMIANA" = 0 ] || zapisz_limity
pilnuj_orkiestratora
log "przebieg: paneli $N_PANELI, aktywne limity ${#W_WYK[@]}${W_WYK[*]:+ (${W_WYK[*]})}"
