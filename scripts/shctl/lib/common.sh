# Wspólne funkcje shctl: argumenty, błędy, wynik --json, log, blokady, zapis plików.
# shellcheck shell=bash

# bash 5.2: & w zamianie ${a//x/$b} nie może znaczyć dopasowania.
shopt -u patsub_replacement 2>/dev/null || true

E_WYKONANIE=1
E_UZYCIE=2
E_BRAK=3
E_ODMOWA=4

SH_DIR="${SH_DIR:-$HOME/sh}"
SH_GH_OWNER="${SH_GH_OWNER:-Sebastian-Temich}"
SH_TEMPLATE="${SH_TEMPLATE:-sh-template-projekt}"
SH_NOTIFY_CMD="${SH_NOTIFY_CMD:-$SH_DIR/bin/notify.sh}"
SH_CONFIG="${SH_CONFIG:-$HOME/.config/sh/config}"
PROJEKTY="$SH_DIR/projekty"
PORTY="$SH_DIR/porty.md"
LIMITY="$SH_DIR/limity.md"
STAN="$SH_DIR/stan"
LOG="$SH_DIR/logs/shctl.log"

# PATH pod launchd i kontrola orkiestratora: wspólne ze skryptami serwera.
# shellcheck source=../../server/lib/system.sh
. "$SHCTL_DIR/../server/lib/system.sh"
sh_uzupelnij_path

DRY=0
JSON=0
PROJEKT=""
ZJEDZONE=0
WYNIK_WYSLANY=0
BLOKADA=""
SHCTL_TMP=""
SHCTL_KOMENDA=""
SHCTL_ARGI=""
PRZY_WYJSCIU=""

# Czyta plik jako dane, bez source: konfiguracja nie wykonuje kodu. Zmienna środowiska wygrywa.
wczytaj_config() {
  local l v
  [ -z "${SH_OBSIDIAN_DIR:-}" ] || return 0
  [ -f "$SH_CONFIG" ] || return 0
  while IFS= read -r l || [ -n "$l" ]; do
    case "$l" in
      SH_OBSIDIAN_DIR=*)
        v="${l#SH_OBSIDIAN_DIR=}"
        case "$v" in
          \"*\") v="${v#\"}"; v="${v%\"}" ;;
          \'*\') v="${v#\'}"; v="${v%\'}" ;;
        esac
        SH_OBSIDIAN_DIR="$v"
        ;;
    esac
  done <"$SH_CONFIG"
}
wczytaj_config

dzis() { date +%F; }

# Przy --json komunikatów nie ma: cały wynik niesie jeden dokument JSON na stdout.
info() {
  [ "$JSON" -eq 1 ] || printf '%s\n' "$*"
}
uwaga() { printf 'UWAGA: %s\n' "$*" >&2; }

die() {
  local kod="$1"
  shift
  printf 'BŁĄD: %s\n' "$*" >&2
  # Plik, bo die działa też w podpowłoce $(...), a JSON wypisuje główny proces.
  [ -z "$SHCTL_TMP" ] || printf '%s' "$*" >"$SHCTL_TMP/blad"
  exit "$kod"
}

zapisz_log() {
  local rc="$1"
  mkdir -p "$(dirname "$LOG")" 2>/dev/null || return 0
  printf '%s rc=%s dry=%s projekt=%s %s %s\n' "$(date '+%FT%T%z')" "$rc" "$DRY" "${PROJEKT:--}" \
    "$SHCTL_KOMENDA" "$SHCTL_ARGI" >>"$LOG" 2>/dev/null || true
}

koniec_shctl() {
  local rc=$? nazwa
  trap - EXIT
  # Sprzątanie komendy (np. worktree review) także po die.
  [ -z "$PRZY_WYJSCIU" ] || "$PRZY_WYJSCIU" || true
  [ -z "$BLOKADA" ] || rmdir "$BLOKADA" 2>/dev/null || true
  if [ "$JSON" -eq 1 ] && [ "$WYNIK_WYSLANY" -eq 0 ] && [ "$rc" -ne 0 ]; then
    nazwa="$SHCTL_KOMENDA"
    jq -nc --arg k "$nazwa" --argjson rc "$rc" --rawfile b "$SHCTL_TMP/blad" \
      '{ok:false, komenda:$k, kod:$rc, blad:$b}' 2>/dev/null ||
      printf '{"ok":false,"kod":%s}\n' "$rc"
  fi
  zapisz_log "$rc"
  [ -z "$SHCTL_TMP" ] || rm -rf "$SHCTL_TMP"
  exit "$rc"
}

start_shctl() {
  SHCTL_KOMENDA="$1"
  shift
  # Log jest jednowierszowy i ucięty: pełna treść notatek zostaje w plikach projektu.
  # LC_ALL=C: printf %q rozcina znaki wielobajtowe, a tr w UTF-8 pada na takim wejściu.
  SHCTL_ARGI="$(printf '%q ' "$@" | LC_ALL=C tr '\r\n' '  ' | LC_ALL=C cut -c1-400)"
  SHCTL_TMP="$(mktemp -d)"
  : >"$SHCTL_TMP/blad"
  trap koniec_shctl EXIT
}

# Opcje wspólne. Wywołanie: opcja_wspolna "$@"; shift "$ZJEDZONE".
opcja_wspolna() {
  case "$1" in
    --dry-run) DRY=1; ZJEDZONE=1 ;;
    --json) JSON=1; ZJEDZONE=1 ;;
    --projekt)
      [ $# -ge 2 ] || die "$E_UZYCIE" "--projekt wymaga wartości"
      PROJEKT="$2"
      ZJEDZONE=2
      ;;
    --projekt=*) PROJEKT="${1#--projekt=}"; ZJEDZONE=1 ;;
    *) die "$E_UZYCIE" "nieznany argument: $1 (shctl --help)" ;;
  esac
}

# Wartość opcji: x="$(wartosc "$@")"; shift 2.
wartosc() {
  [ $# -ge 2 ] || die "$E_UZYCIE" "$1 wymaga wartości"
  printf '%s' "$2"
}

wymagaj() {
  local n
  for n in "$@"; do
    command -v "$n" >/dev/null || die "$E_BRAK" "brak narzędzia: $n (shctl doctor)"
  done
}

sprawdz_nazwe() {
  case "$1" in
    "" | -* | *[!A-Za-z0-9_-]*) die "$E_UZYCIE" "niepoprawna nazwa projektu: '$1' (litery, cyfry, - i _)" ;;
  esac
}

# Wynik końcowy: wynik_json '{"pole":1}'.
wynik_json() {
  WYNIK_WYSLANY=1
  [ "$JSON" -eq 1 ] || return 0
  jq -nc --arg k "$SHCTL_KOMENDA" --argjson d "$DRY" --argjson w "$1" \
    '{ok:true, komenda:$k, dry_run:($d == 1), wynik:$w}'
}

# Zapis przez cat, żeby zachować symlink i uprawnienia celu.
podmien_plik() {
  cat "$1" >"$2"
  rm -f "$1"
}

tmp_plik() { mktemp "$SHCTL_TMP/plik.XXXXXX"; }

# Blokada mkdir: macOS nie ma flock.
zablokuj() {
  local k="$1" i=0
  while ! mkdir "$k" 2>/dev/null; do
    i=$((i + 1))
    [ "$i" -lt 100 ] || die "$E_WYKONANIE" "blokada zajęta: $k (usuń katalog, jeśli to pozostałość)"
    sleep 0.1
  done
  BLOKADA="$k"
}

odblokuj() {
  rmdir "$1" 2>/dev/null || true
  BLOKADA=""
}

# Jedna linia do tabeli Markdown.
komorka() { printf '%s' "$1" | LC_ALL=C tr '\r\n' '  ' | LC_ALL=C sed 's/|/\\|/g'; }

# Docker, logowania i git potrafią wisieć przy braku sieci.
z_limitem() {
  local s="$1"
  shift
  if command -v perl >/dev/null; then
    perl -e 'alarm shift; exec @ARGV or exit 127' "$s" "$@"
  else
    "$@"
  fi
}

# Git z siecią (fetch, pull, clone, ls-remote) do github.com: logowanie zawsze przez gh, bez pytania
# o hasło. Pod launchd nie ma terminala, a wpis osxkeychain znika po pierwszym odrzuconym tokenie
# (git sam go kasuje), więc nie polegamy ani na nim, ani na globalnym ~/.gitconfig. Helper ma
# bezwzględną ścieżkę gh, bo git uruchamia go przez sh z PATH wywołującego.
# Wywołanie: git_gh [-t SEKUNDY] ARGUMENTY_GIT (-t: limit czasu jak z_limitem).
git_gh() {
  local gh limit=""
  if [ "${1:-}" = -t ]; then limit="$2"; shift 2; fi
  gh="$(command -v gh 2>/dev/null || true)"
  if [ -n "$gh" ]; then
    set -- env GIT_TERMINAL_PROMPT=0 git -c credential.https://github.com.helper= \
      -c "credential.https://github.com.helper=!'$gh' auth git-credential" "$@"
  else
    set -- env GIT_TERMINAL_PROMPT=0 git "$@"
  fi
  if [ -n "$limit" ]; then z_limitem "$limit" "$@"; else "$@"; fi
}

powiadom() {
  [ -x "$SH_NOTIFY_CMD" ] || { uwaga "brak $SH_NOTIFY_CMD"; return 1; }
  "$SH_NOTIFY_CMD" "$@" >&2
}
