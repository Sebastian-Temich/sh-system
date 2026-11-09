#!/bin/bash
# /Users/Shared/sh/bin/obsidian-sync.sh - git pull --ff-only w klonach docs/ w vaulcie Obsidiana.
# LaunchAgent pl.iskt.softwarehouse.obsidian-sync co 5 minut. Klony: katalogi z .git w SH_OBSIDIAN_DIR
# (z ~/.config/sh/config) i klon sh-system obok (SH_OBSIDIAN_SYSTEM). Bez merge i resetu; nieudany
# pull to wpis w /Users/Shared/sh/logs/obsidian-sync.log. Flaga /Users/Shared/sh/stan/obsidian-sync.off
# wyłącza przebieg. Klony zakłada i usuwa shctl obsidian link|unlink.
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
exit 0
