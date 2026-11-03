# shctl doctor [--test-notify]: stan narzędzi i logowań; blad daje kod 1. Sprawdza odczytem. Zapisuje
# tylko jedno: usuwa z ~/sh/stan/do-usuniecia.md repo, których już nie ma (nie przy --dry-run).
# --test-notify wysyła prawdziwe powiadomienie.
# shellcheck shell=bash

# shellcheck source=../lib/obsidian.sh
. "$SHCTL_DIR/lib/obsidian.sh"

wpis() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >>"$SHCTL_TMP/doctor"; }

sprawdz_narzedzia() {
  local n
  for n in git gh jq yq bats docker herdr codex claude; do
    if command -v "$n" >/dev/null; then wpis "narzędzie $n" ok "$(command -v "$n")"; else wpis "narzędzie $n" blad "brak w PATH"; fi
  done
  # Wynik do zmiennej: przy pipefail grep -q urywa potok i daje fałszywy błąd.
  if command -v yq >/dev/null; then
    case "$(yq --version 2>&1)" in
      *mikefarah*) ;;
      *) wpis "yq wariant" blad "wymagany yq mikefarah" ;;
    esac
  fi
}

sprawdz_logowania() {
  if command -v gh >/dev/null; then
    if z_limitem 20 gh auth status >/dev/null 2>&1; then wpis "logowanie gh" ok "zalogowany"; else wpis "logowanie gh" blad "gh auth login"; fi
  fi
  if command -v codex >/dev/null; then
    if z_limitem 20 codex login status >/dev/null 2>&1; then wpis "logowanie codex" ok "zalogowany"; else wpis "logowanie codex" blad "codex login"; fi
  fi
  if command -v claude >/dev/null; then
    case "$(z_limitem 20 claude auth status 2>/dev/null || true)" in
      *'"loggedIn": true'* | *'"loggedIn":true'*) wpis "logowanie claude" ok "zalogowany" ;;
      *) wpis "logowanie claude" blad "claude auth login" ;;
    esac
  fi
}

sprawdz_uslugi() {
  if command -v docker >/dev/null; then
    if z_limitem 20 docker info >/dev/null 2>&1; then wpis "Docker" ok "działa"; else wpis "Docker" blad "nie odpowiada, uruchom Docker Desktop"; fi
  fi
  if command -v herdr >/dev/null; then
    case "$(z_limitem 20 herdr status server 2>/dev/null || true)" in
      *'status: running'*) wpis "herdr" ok "serwer działa" ;;
      *) wpis "herdr" blad "serwer nie działa: sh-start.sh" ;;
    esac
  fi
}

# PID claude remote-control z katalogiem roboczym $SH_DIR (pusto, gdy brak).
pid_orkiestratora() {
  local pid cwd want
  want="$(cd "$SH_DIR" 2>/dev/null && pwd -P || printf '%s' "$SH_DIR")"
  for pid in $(pgrep -f 'claude remote-control' 2>/dev/null || true); do
    cwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' || true)"
    if [ "$cwd" = "$SH_DIR" ] || [ "$cwd" = "$want" ]; then printf '%s' "$pid"; return 0; fi
  done
}

# PATH z początkowego środowiska procesu (ps eww, procesy tego samego użytkownika). Wartość
# kończy się przed następnym „ NAZWA=”, więc katalogi ze spacją zostają całe.
path_procesu() {
  ps eww -o command= -p "$1" 2>/dev/null | head -n 1 |
    sed -n 's/.* PATH=//p' | sed 's/ [A-Za-z_][A-Za-z0-9_]*=.*//'
}

# PID powłoki panelu z etykietą orkiestrator w workspace sh (pusto, gdy brak).
powloka_orkiestratora() {
  local ws panel
  ws="$(z_limitem 20 herdr workspace list 2>/dev/null |
    jq -r '[.result.workspaces[]? | select(.label == "sh")][0].workspace_id // empty' 2>/dev/null || true)"
  [ -n "$ws" ] || return 0
  panel="$(z_limitem 20 herdr pane list --workspace "$ws" 2>/dev/null |
    jq -r '[.result.panes[]? | select(.label == "orkiestrator")][0].pane_id // empty' 2>/dev/null || true)"
  [ -n "$panel" ] || return 0
  z_limitem 20 herdr pane process-info --pane "$panel" 2>/dev/null |
    jq -r '.result.process_info.shell_pid // empty' 2>/dev/null || true
}

# Orkiestrator działa i ma ~/sh/bin w PATH. PATH czytany z procesu orkiestratora (to, co
# dziedziczą nowe sesje), a gdy nie działa, z powłoki panelu orkiestratora w herdr.
sprawdz_orkiestrator() {
  local pid='' zrodlo sciezki
  if ! command -v pgrep >/dev/null || ! command -v lsof >/dev/null; then
    wpis "orkiestrator" uwaga "brak pgrep albo lsof, nie sprawdzono"
  else
    pid="$(pid_orkiestratora)"
    if [ -n "$pid" ]; then wpis "orkiestrator" ok "działa (PID $pid)"; else wpis "orkiestrator" blad "nie działa: sh-start.sh"; fi
  fi
  if [ -n "$pid" ]; then
    zrodlo="orkiestrator PID $pid"
    sciezki="$(path_procesu "$pid")"
  elif command -v herdr >/dev/null && command -v jq >/dev/null; then
    zrodlo="$(powloka_orkiestratora "")"
    if [ -z "$zrodlo" ]; then
      wpis "PATH panelu herdr" uwaga "nie znaleziono panelu orkiestratora w workspace sh"
      return 0
    fi
    sciezki="$(path_procesu "$zrodlo")"
    zrodlo="powłoka PID $zrodlo"
  else
    return 0
  fi
  if [ -z "$sciezki" ]; then
    wpis "PATH panelu herdr" uwaga "nie udało się odczytać PATH ($zrodlo)"
    return 0
  fi
  case ":$sciezki:" in
    *":$SH_DIR/bin:"*) wpis "PATH panelu herdr" ok "$SH_DIR/bin jest ($zrodlo)" ;;
    *) wpis "PATH panelu herdr" blad "brak $SH_DIR/bin ($zrodlo); zatrzymaj orkiestratora i uruchom sh-start.sh" ;;
  esac
}

sprawdz_notify() {
  local temat="$HOME/.config/sh/ntfy-topic" test="$1"
  if [ ! -x "$SH_NOTIFY_CMD" ]; then
    wpis notify blad "brak $SH_NOTIFY_CMD"
  elif [ ! -s "$temat" ] && [ "$test" -eq 0 ]; then
    wpis notify blad "brak tematu w $temat"
  elif [ "$test" -eq 1 ]; then
    if "$SH_NOTIFY_CMD" min "shctl doctor" "Test powiadomienia" >/dev/null 2>&1; then wpis notify ok "wysłano test"; else wpis notify blad "wysyłka nieudana"; fi
  else
    wpis notify ok "skrypt i temat są (wysyłka: --test-notify)"
  fi
}

sprawdz_srodowisko() {
  local repo lokalny wolne min=15 globalny
  globalny="$(git config --global --get core.hooksPath 2>/dev/null || true)"
  case "$globalny" in
    */scripts/server/git-hooks) wpis "hook globalny" ok "$globalny" ;;
    *) wpis "hook globalny" uwaga "core.hooksPath='$globalny', push na production nie jest blokowany" ;;
  esac
  for repo in "$SH_DIR"/projekty/*/; do
    [ -e "$repo.git" ] || continue
    lokalny="$(git -C "$repo" config --local --get core.hooksPath 2>/dev/null || true)"
    [ -z "$lokalny" ] || wpis "hooki $(basename "$repo")" uwaga "lokalny core.hooksPath ($lokalny) wyłącza globalny pre-push"
  done
  wolne="$(df -g "$HOME" 2>/dev/null | awk 'NR == 2 { print $4 }' || true)"
  if [ -n "$wolne" ]; then
    if [ "$wolne" -ge "$min" ]; then wpis "dysk" ok "wolne $wolne GB"; else wpis "dysk" uwaga "wolne $wolne GB, minimum $min GB"; fi
  fi
  if [ -f "$PORTY" ]; then wpis "porty.md" ok "$PORTY"; else wpis "porty.md" blad "brak $PORTY"; fi
}

sprawdz_obsidian() {
  local k stan ile=0
  if [ -z "${SH_OBSIDIAN_DIR:-}" ]; then
    wpis "Obsidian" uwaga "brak SH_OBSIDIAN_DIR w $SH_CONFIG"
    return 0
  fi
  for k in "$SH_OBSIDIAN_DIR"/*/; do
    [ -e "$k.git" ] || continue
    ile=$((ile + 1))
    stan="$(obsidian_stan "${k%/}")"
    if [ "$stan" = ok ]; then
      wpis "Obsidian $(basename "$k")" ok "czysty i aktualny"
    else
      wpis "Obsidian $(basename "$k")" uwaga "$stan"
    fi
  done
  [ "$ile" -gt 0 ] || wpis "Obsidian" ok "brak klonów w $SH_OBSIDIAN_DIR"
}

# Data ostatniej udanej synchronizacji (wszystkie klony aktualne) z ~/sh/stan/obsidian-sync.json.
sprawdz_obsidian_sync() {
  local plik="$STAN/obsidian-sync.json" udana przebieg prob wiek
  [ -n "${SH_OBSIDIAN_DIR:-}" ] || return 0
  if [ -e "$STAN/obsidian-sync.off" ]; then
    wpis "Obsidian sync" uwaga "wyłączona flagą $STAN/obsidian-sync.off"
    return 0
  fi
  if [ ! -f "$plik" ]; then
    wpis "Obsidian sync" uwaga "jeszcze nie było przebiegu (LaunchAgent pl.iskt.softwarehouse.obsidian-sync)"
    return 0
  fi
  udana="$(jq -r '.ostatnia_udana // ""' "$plik" 2>/dev/null || true)"
  przebieg="$(jq -r '.ostatni_przebieg // ""' "$plik" 2>/dev/null || true)"
  prob="$(jq -r '[.problemy // {} | to_entries[] | "\(.key | split("/") | last): \(.value.powod)"] | join("; ")' "$plik" 2>/dev/null || true)"
  if [ -z "$udana" ]; then
    wpis "Obsidian sync" uwaga "brak udanej synchronizacji; ostatni przebieg ${przebieg:-?}${prob:+; $prob}"
    return 0
  fi
  wiek="$(jq -r '.ostatnia_udana_epoch // 0' "$plik" 2>/dev/null || echo 0)"
  wiek=$(( ($(date +%s) - wiek) / 60 ))
  if [ -n "$prob" ] || [ "$wiek" -gt 30 ]; then
    wpis "Obsidian sync" uwaga "ostatnia udana $udana ($wiek min temu)${prob:+; $prob}"
  else
    wpis "Obsidian sync" ok "ostatnia udana $udana"
  fi
}

# Tylko „nie ma takiego repo” zdejmuje wpis: błąd sieci albo logowania nie może skasować listy.
sprawdz_do_usuniecia() {
  local plik="$STAN/do-usuniecia.md" nazwy n wyj nowy zostaja="" usuniete="" niepewne="" ile=0 opis
  [ -f "$plik" ] || { wpis "repo do usunięcia" ok "0"; return 0; }
  nazwy="$(awk -F'|' '/^\|/ && !/^\|[- |]*$/ {
    p = $2; gsub(/^[ \t`]+|[ \t`]+$/, "", p)
    if (p != "Nazwa" && p != "") print p }' "$plik")"
  for n in $nazwy; do
    if ! command -v gh >/dev/null; then
      niepewne="$niepewne $n"
    elif wyj="$(z_limitem 20 gh repo view "$SH_GH_OWNER/$n" --json name 2>&1)"; then
      zostaja="$zostaja $n"
    else
      case "$wyj" in
        *"Could not resolve"*)
          usuniete="$usuniete $n"
          if [ "$DRY" -eq 0 ]; then
            nowy="$(tmp_plik)"
            awk -F'|' -v n="$n" '{ p = $2; gsub(/^[ \t`]+|[ \t`]+$/, "", p) } !/^\|/ || p != n' "$plik" >"$nowy"
            podmien_plik "$nowy" "$plik"
          fi
          ;;
        *) niepewne="$niepewne $n" ;;
      esac
    fi
  done
  for n in $zostaja $niepewne; do ile=$((ile + 1)); done
  opis="$ile${zostaja:+:$zostaja}"
  [ -z "$niepewne" ] || opis="$opis; niesprawdzone:$niepewne"
  if [ -n "$usuniete" ]; then
    if [ "$DRY" -eq 0 ]; then opis="$opis; zdjęte z listy:$usuniete"; else opis="$opis; do zdjęcia z listy:$usuniete"; fi
  fi
  if [ "$ile" -gt 0 ]; then wpis "repo do usunięcia" uwaga "$opis"; else wpis "repo do usunięcia" ok "$opis"; fi
}

komenda_main() {
  local test=0 bledy
  while [ $# -gt 0 ]; do
    case "$1" in
      --test-notify) test=1; shift ;;
      *) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
    esac
  done
  [ "$JSON" -eq 0 ] || wymagaj jq
  : >"$SHCTL_TMP/doctor"
  sprawdz_narzedzia
  sprawdz_logowania
  sprawdz_uslugi
  sprawdz_orkiestrator
  sprawdz_notify "$test"
  sprawdz_srodowisko
  sprawdz_obsidian
  sprawdz_obsidian_sync
  sprawdz_do_usuniecia

  bledy="$(awk -F'\t' '$2 == "blad" { n++ } END { print n + 0 }' "$SHCTL_TMP/doctor")"
  if [ "$JSON" -eq 1 ]; then
    wynik_json "$(jq -Rsc --argjson b "$bledy" '
      split("\n") | map(select(length > 0) | split("\t") | {nazwa:.[0], stan:.[1], szczegoly:.[2]})
      | {bledy:$b, kontrole:.}' "$SHCTL_TMP/doctor")"
  else
    WYNIK_WYSLANY=1
    awk -F'\t' '{ printf "%-6s %-22s %s\n", toupper($2), $1, $3 }' "$SHCTL_TMP/doctor"
  fi
  [ "$bledy" -eq 0 ] || { [ "$JSON" -eq 1 ] || echo "doctor: błędy: $bledy" >&2; exit "$E_WYKONANIE"; }
}
