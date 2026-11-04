#!/usr/bin/env bash
# /Users/Shared/sh/bin/odczyt-hook.sh - hook PreToolUse (Read|Glob|Grep): zakres odczytu sesji SH.
#
#   odczyt-hook.sh     (JSON hooka na stdin, matcher "Read|Glob|Grep")
#
# Odczyt dozwolony w:
#   - katalogu projektu sesji (CLAUDE_PROJECT_DIR, inaczej pole cwd): u workera jego worktree,
#     u orkiestratora /Users/Shared/sh; decyzje zostawia zwyklym regulom uprawnien;
#   - plikach konfiguracji Claude: ~/.claude i skille SH (SH_DIR/sh-system/plugin); tu hook zwraca
#     "allow", bo reguly Read() nie dzialaja dla katalogu domowego z kropka na koncu nazwy;
#   - katalogu tymczasowym wlasnej sesji Claude Code (/private/tmp/claude-UID/*/SESSION_ID:
#     scratchpad, wyniki zadan w tle); tu tez "allow". Katalogi innych sesji: "deny".
# Kazda inna sciezka: "deny" z powodem. Sciezki z "..", ktorych nie da sie rozwiazac, tez "deny".
# Fail-closed: rola rozpoznana tylko dla SH_DIR (orkiestrator) i SH_DIR/wt/NAZWA/KATALOG (worker,
# reviewer); inny katalog projektu to "deny". Brak jq, bledny JSON albo brak nazwy narzedzia: kod 2
# (Claude Code blokuje narzedzie). Komenda w ustawieniach ma "|| exit 2", wiec brak skryptu i kazdy
# inny niezerowy kod tez blokuja.
# Hook nie obejmuje Basha (cat, grep): u workera w trybie dontAsk blokuje je sprawdzanie sciezek
# Claude Code, u orkiestratora decyduje tryb Auto.
set -uo pipefail

SH_DIR="${SH_DIR:-/Users/Shared/sh}"
blad() { printf 'odczyt-hook.sh: %s; odczyt zablokowany\n' "$1" >&2; exit 2; }
command -v jq >/dev/null || blad 'brak jq'
WEJSCIE="$(cat)"
printf '%s' "$WEJSCIE" | jq -e 'type == "object"' >/dev/null 2>&1 || blad 'wejscie hooka nie jest obiektem JSON'
pole() { printf '%s' "$WEJSCIE" | jq -r "$1 // empty" 2>/dev/null; }

decyzja() {
  jq -nc --arg d "$1" --arg p "$2" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:$d, permissionDecisionReason:$p}}'
  exit 0
}

# Sciezka bezwzgledna bez dowiazan i "..". Pusty wynik: nie da sie ustalic.
rozwiaz() {
  local p="$1" baza="$2" przodek reszta=''
  case "$p" in
    "~") p="$HOME" ;;
    "~/"*) p="$HOME/${p#\~/}" ;;
    /*) ;;
    *) p="$baza/$p" ;;
  esac
  przodek="$p"
  while [ ! -d "$przodek" ]; do
    reszta="/$(basename "$przodek")$reszta"
    przodek="$(dirname "$przodek")"
  done
  case "$reszta/" in */../* | */./*) return 0 ;; esac
  przodek="$(cd -P "$przodek" 2>/dev/null && pwd -P)" || return 0
  printf '%s%s' "${przodek%/}" "$reszta"
}

# Stala czesc wzorca Glob przed pierwszym segmentem z * ? [ {.
prefiks_wzorca() {
  local w="$1" wynik='' seg
  local IFS=/
  for seg in $w; do
    case "$seg" in *[\*\?\[\{]*) break ;; esac
    wynik="$wynik$seg/"
  done
  case "$w" in /*) printf '/%s' "${wynik#/}" ;; *) printf '%s' "$wynik" ;; esac
}

w_katalogu() { [ -n "$2" ] && case "$1/" in "$2"/*) true ;; *) false ;; esac; }

NARZEDZIE="$(pole .tool_name)"
[ -n "$NARZEDZIE" ] || blad 'brak tool_name w wejsciu hooka'
CWD="$(pole .cwd)"
CWD="${CWD:-$PWD}"
SESJA="$(pole .session_id)"

case "$NARZEDZIE" in
  Read) SCIEZKI=("$(pole .tool_input.file_path)") ;;
  Grep) SCIEZKI=("$(pole .tool_input.path)") ;;
  Glob)
    SCIEZKI=("$(pole .tool_input.path)")
    wzorzec="$(pole .tool_input.pattern)"
    case "$wzorzec" in /* | "~"*) SCIEZKI+=("$(prefiks_wzorca "$wzorzec")") ;; esac
    ;;
  *) exit 0 ;;
esac

PROJEKT="$(rozwiaz "${CLAUDE_PROJECT_DIR:-$CWD}" /)"
SH_R="$(rozwiaz "$SH_DIR" /)"
[ -n "$PROJEKT" ] && [ -n "$SH_R" ] || blad 'nie da sie ustalic katalogu projektu sesji'
case "$PROJEKT" in
  "$SH_R") ;;
  "$SH_R"/wt/*/*)
    reszta="${PROJEKT#"$SH_R"/wt/}"
    case "$reszta" in */*/*) decyzja deny "Nierozpoznana rola sesji SH (katalog projektu $PROJEKT); odczyt zablokowany." ;; esac
    ;;
  *) decyzja deny "Nierozpoznana rola sesji SH (katalog projektu $PROJEKT); odczyt zablokowany." ;;
esac
DOM="$(rozwiaz "$HOME" /)"
KONFIG=("$DOM/.claude" "$(rozwiaz "$SH_DIR/sh-system/plugin" /)")
TMP=("$(rozwiaz "/private/tmp/claude-$(id -u)" /)" "$(rozwiaz "/tmp/claude-$(id -u)" /)")

zezwol=0
for s in "${SCIEZKI[@]}"; do
  [ -n "$s" ] || s="$CWD"
  r="$(rozwiaz "$s" "$CWD")"
  [ -n "$r" ] || decyzja deny "Odczyt $s: nie da się ustalić ścieżki (..). Podaj ścieżkę bezwzględną w $PROJEKT."
  w_katalogu "$r" "$PROJEKT" && continue
  ok=0
  for k in "${TMP[@]}"; do
    w_katalogu "$r" "$k" || continue
    reszta="${r#"$k"/}"
    reszta="${reszta#*/}"
    [ -n "$SESJA" ] && [ "${reszta%%/*}" = "$SESJA" ] && ok=1
  done
  for k in "${KONFIG[@]}"; do w_katalogu "$r" "$k" && ok=1; done
  if [ "$ok" = 1 ]; then
    zezwol=1
    continue
  fi
  decyzja deny "Odczyt poza zakresem sesji SH: $r. Dozwolone: $PROJEKT, konfiguracja Claude (~/.claude, skille SH) i katalog tymczasowy tej sesji."
done

[ "$zezwol" = 1 ] && decyzja allow "Konfiguracja Claude albo katalog tymczasowy sesji (odczyt dozwolony w sesjach SH)."
exit 0
