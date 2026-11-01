# shctl doctor [--test-notify]: stan narzędzi i logowań. Tylko odczyt; blad daje kod 1.
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

# Lista jest utrzymywana ręcznie: repo usuwa właściciel, potem kasuje wiersz.
sprawdz_do_usuniecia() {
  local plik="$STAN/do-usuniecia.md" nazwy n
  nazwy=""
  if [ -f "$plik" ]; then
    nazwy="$(awk -F'|' '/^\|/ && !/^\|[- |]*$/ {
      p = $2; gsub(/^[ \t`]+|[ \t`]+$/, "", p)
      if (p != "Nazwa" && p != "") print p }' "$plik")"
  fi
  if [ -z "$nazwy" ]; then
    wpis "repo do usunięcia" ok "0"
    return 0
  fi
  n="$(printf '%s\n' "$nazwy" | wc -l | tr -d ' ')"
  wpis "repo do usunięcia" uwaga "$n: $(printf '%s\n' "$nazwy" | paste -sd ' ' -)"
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
  sprawdz_notify "$test"
  sprawdz_srodowisko
  sprawdz_obsidian
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
