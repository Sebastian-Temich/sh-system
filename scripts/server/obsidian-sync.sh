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
# docs/Projekt.md każdego klonu (sync-status.sh). Kolejność: najpierw projekty, w których coś czeka na
# właściciela, potem w toku, potem zakończone; w grupie alfabetycznie. Plik zmienia się tylko przy
# zmianie treści.
fm() { awk -v k="$2" 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } index($0, k ": ") == 1 { v = substr($0, length(k) + 3); gsub(/^"|"$/, "", v); gsub(/\\"/, "\"", v); print v; exit }' "$1"; }
komorka() { printf '%s' "$1" | sed 's/|/\\|/g'; }
SH_VAULT="$(dirname "$SH_OBSIDIAN_DIR")"
PODKAT="$(basename "$SH_OBSIDIAN_DIR")"
WSZYSTKIE="$SH_VAULT/Wszystkie projekty.md"
TAB="$(printf '\t')"
# Wiersze z kluczem sortowania „GRUPA<TAB>NAZWA<TAB>wiersz”; grupa 0 czeka na Ciebie, 1 w toku,
# 2 zakończony, 3 bez Projekt.md.
wiersze() {
  local k n f etap postep pe pz czeka esk pyt nast g
  for k in "$SH_OBSIDIAN_DIR"/*/; do
    [ -e "$k.git" ] || continue
    n="$(basename "$k")"
    f="$k/docs/Projekt.md"
    if [ ! -f "$f" ]; then
      printf '3\t%s\t| %s | (brak docs/Projekt.md) | | | | | |\n' "$n" "$n"
      continue
    fi
    etap="$(fm "$f" etap_opis)"
    pe="$(fm "$f" postep_etapy)"; pz="$(fm "$f" postep_zadania)"
    if [ -n "$pe$pz" ]; then postep="Etapy ${pe:--} · Zadania ${pz:--}"; else postep="$(fm "$f" postep)"; fi
    czeka="$(fm "$f" czeka_na_ciebie)"
    esk="$(fm "$f" eskalacje)"; pyt="$(fm "$f" pytania)"
    [ "${pyt:-0}" = 0 ] || esk="$(( ${esk:-0} + pyt ))"
    nast="$(fm "$f" nastepny_krok)"
    if [ "${czeka:-0}" != 0 ]; then g=0
    else case "$etap" in *akończon*) g=2 ;; *) g=1 ;; esac
    fi
    printf '%s\t%s\t| %s | %s | %s | %s | %s | %s | [Projekt.md](<%s/%s/docs/Projekt.md>) |\n' "$g" "$n" "$n" \
      "$(komorka "$etap")" "$postep" "${czeka:-0}" "${esk:-0}" "$(komorka "${nast:--}")" "$PODKAT" "$n"
  done
}
# Bez pliku tymczasowego: pod launchd nie ma TMPDIR, a treść jest mała.
tabela="$(
  echo "# Wszystkie projekty"
  echo
  echo "Generuje obsidian-sync.sh co 5 minut z \`docs/Projekt.md\` każdego projektu. Nie edytuj ręcznie."
  echo "Najpierw projekty, w których coś czeka na Ciebie, potem w toku, potem zakończone."
  echo
  echo "| Projekt | Etap | Postęp | Czeka na Ciebie | Eskalacje | Następny krok | Widok |"
  echo "|---|---|---|---|---|---|---|"
  wiersze | LC_ALL=C sort -t "$TAB" -k1,1n -k2,2 | cut -f3-
)"
if [ -d "$SH_VAULT" ] && [ "$tabela" != "$(cat "$WSZYSTKIE" 2>/dev/null)" ]; then
  printf '%s\n' "$tabela" >"$WSZYSTKIE" 2>>"$LOG" || printf '%s BŁĄD zapisu %s\n' "$(date '+%FT%T%z')" "$WSZYSTKIE" >>"$LOG"
fi
exit 0
