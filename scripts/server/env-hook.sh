#!/usr/bin/env bash
# /Users/Shared/sh/bin/env-hook.sh - hook PreToolUse profilu workera: pliki .env poza zasiegiem.
#
#   env-hook.sh     (JSON hooka na stdin, matcher "Read|Edit|Write|MultiEdit|NotebookEdit|Glob|Grep|Bash")
#
# Blokuje ("deny") kazdy plik o nazwie .env albo .env.* w dowolnym katalogu (.env.local,
# .env.production, .env.ci, apps/web/.env, .env* itd.) z jednym wyjatkiem: .env.example.
# Reguly deny w settings.json nie wyraza wyjatku (deny wygrywa z allow, [!x] nie jest negacja),
# dlatego wyjatek jest tutaj. Reguly deny .env w profilu zostaja jako pierwsza warstwa.
# Bash: komenda dzielona na slowa po bialych znakach i znakach powloki; slowo, ktorego ostatni
# segment sciezki to .env albo zaczyna sie od .env. / .env* / .env?, daje "deny".
# Inne nazwy (.envrc, env.ts, .environment) przechodza bez decyzji.
# Fail-closed: brak jq albo bledny JSON to kod 2 (Claude Code blokuje narzedzie); komenda w
# ustawieniach ma "|| exit 2", wiec brak skryptu tez blokuje.
set -uo pipefail

blad() { printf 'env-hook.sh: %s; narzedzie zablokowane\n' "$1" >&2; exit 2; }
command -v jq >/dev/null || blad 'brak jq'
WEJSCIE="$(cat)"
printf '%s' "$WEJSCIE" | jq -e 'type == "object"' >/dev/null 2>&1 || blad 'wejscie hooka nie jest obiektem JSON'
pole() { printf '%s' "$WEJSCIE" | jq -r "$1 // empty" 2>/dev/null; }

# 0, gdy nazwa (ostatni segment sciezki) to plik .env inny niz .env.example.
sekret_env() {
  local n="${1%/}"
  n="${n##*/}"
  [ "$n" = .env.example ] && return 1
  case "$n" in
    .env | .env.* | .env\** | .env\?* | .env\[*) return 0 ;;
  esac
  return 1
}

odmowa() {
  jq -nc --arg p "Plik $1: pliki .env (poza .env.example) sa poza zasiegiem workera. Zmienne opisz w .env.example; wartosci ustawia wlasciciel." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:$p}}'
  exit 0
}

NARZEDZIE="$(pole .tool_name)"
[ -n "$NARZEDZIE" ] || blad 'brak tool_name w wejsciu hooka'

case "$NARZEDZIE" in
  Bash)
    KOMENDA="$(pole .tool_input.command)"
    # Znaki powloki zamieniamy na spacje, potem kazde slowo osobno (bez rozwijania globow).
    SLOWA="$(printf '%s' "$KOMENDA" | tr ';&|<>()`"=,{}' '            ' | tr "'" ' ' | tr '\t\n' '  ')"
    set -f
    for s in $SLOWA; do
      sekret_env "$s" && odmowa "$s"
    done
    set +f
    ;;
  Read | Edit | Write | MultiEdit | NotebookEdit | Glob | Grep)
    for f in .tool_input.file_path .tool_input.notebook_path .tool_input.path .tool_input.pattern .tool_input.glob; do
      # Pattern Grepa to wyrazenie regularne w tresci, nie sciezka.
      [ "$NARZEDZIE" = Grep ] && [ "$f" = .tool_input.pattern ] && continue
      w="$(pole "$f")"
      [ -n "$w" ] || continue
      sekret_env "$w" && odmowa "$w"
    done
    ;;
esac
exit 0
