#!/bin/bash
# /Users/Shared/sh/bin/obsidian-sync.sh - git pull --ff-only w klonach docs/ w vaulcie Obsidiana.
# LaunchAgent pl.iskt.softwarehouse.obsidian-sync co 5 minut. Klony: katalogi z .git w SH_OBSIDIAN_DIR
# (z ~/.config/sh/config) i klon sh-system obok (SH_OBSIDIAN_SYSTEM). Bez merge i resetu; nieudany
# pull to wpis w /Users/Shared/sh/logs/obsidian-sync.log. Flaga /Users/Shared/sh/stan/obsidian-sync.off
# wyłącza przebieg. Klony zakłada i usuwa shctl obsidian link|unlink. Po pullach zapisuje
# SH/Wszystkie projekty.md (tabela z docs/Projekt.md każdego klonu).
set -u
SH_DIR="${SH_DIR:-/Users/Shared/sh}"
LOG="$SH_DIR/logs/obsidian-sync.log"
CONFIG="${SH_CONFIG:-$HOME/.config/sh/config}"
[ ! -e "$SH_DIR/stan/obsidian-sync.off" ] || exit 0
if [ -z "${SH_OBSIDIAN_DIR:-}" ] && [ -f "$CONFIG" ]; then
  SH_OBSIDIAN_DIR="$(sed -n 's/^SH_OBSIDIAN_DIR=//p' "$CONFIG" | tail -1 | sed "s/^[\"']//; s/[\"']\$//")"
fi
[ -n "${SH_OBSIDIAN_DIR:-}" ] || exit 0
mkdir -p "$(dirname "$LOG")"
for k in "$SH_OBSIDIAN_DIR"/*/ "${SH_OBSIDIAN_SYSTEM:-$(dirname "$SH_OBSIDIAN_DIR")/sh-system}/"; do
  [ -e "$k.git" ] || continue
  if ! wyj="$(GIT_TERMINAL_PROMPT=0 git -C "$k" pull -q --ff-only 2>&1)"; then
    printf '%s POMINIĘTY %s: %s\n' "$(date '+%FT%T%z')" "${k%/}" "$(printf '%s' "$wyj" | sed -n '/./{p;q;}')" >>"$LOG"
  fi
done

# Wszystkie projekty.md w katalogu SH vaulta (rodzic SH_OBSIDIAN_DIR): jedna tabela z frontmattera
# docs/Projekt.md każdego klonu (sync-status.sh). Plik zmienia się tylko przy zmianie treści.
fm() { awk -v k="$2" 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } index($0, k ": ") == 1 { v = substr($0, length(k) + 3); gsub(/^"|"$/, "", v); print v; exit }' "$1"; }
SH_VAULT="$(dirname "$SH_OBSIDIAN_DIR")"
PODKAT="$(basename "$SH_OBSIDIAN_DIR")"
WSZYSTKIE="$SH_VAULT/Wszystkie projekty.md"
# Bez pliku tymczasowego: pod launchd nie ma TMPDIR, a treść jest mała.
tabela="$(
  echo "# Wszystkie projekty"
  echo
  echo "Generuje obsidian-sync.sh co 5 minut z \`docs/Projekt.md\` każdego projektu. Nie edytuj ręcznie."
  echo
  echo "| Projekt | Etap | Postęp | Czeka na Ciebie | Eskalacje | Widok |"
  echo "|---|---|---|---|---|---|"
  for k in "$SH_OBSIDIAN_DIR"/*/; do
    [ -e "$k.git" ] || continue
    n="$(basename "$k")"
    f="$k/docs/Projekt.md"
    if [ -f "$f" ]; then
      esk="$(fm "$f" eskalacje)"; pyt="$(fm "$f" pytania)"
      [ "${pyt:-0}" = 0 ] || esk="${esk:-0} + $pyt pyt."
      printf '| %s | %s | %s | %s | %s | [Projekt.md](<%s/%s/docs/Projekt.md>) |\n' "$n" "$(fm "$f" etap_opis)" \
        "$(fm "$f" postep)" "$(fm "$f" czeka_na_ciebie)" "${esk:-0}" "$PODKAT" "$n"
    else
      printf '| %s | (brak docs/Projekt.md) | | | | |\n' "$n"
    fi
  done
)"
if [ -d "$SH_VAULT" ] && [ "$tabela" != "$(cat "$WSZYSTKIE" 2>/dev/null)" ]; then
  printf '%s\n' "$tabela" >"$WSZYSTKIE" 2>>"$LOG" || printf '%s BŁĄD zapisu %s\n' "$(date '+%FT%T%z')" "$WSZYSTKIE" >>"$LOG"
fi
exit 0
