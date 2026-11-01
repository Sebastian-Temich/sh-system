#!/usr/bin/env bash
# scripts/server/install.sh - instaluje pliki serwera z repo sh-system (idempotentny).
#
# Symlinki: scripts/server/*.sh (bez install.sh) i pliki wykonywalne z scripts/shctl/ do
# ~/sh/bin oraz Brewfile do ~/sh/Brewfile. Zwykly plik zastepuje tylko, gdy jest identyczny
# z repo. Roznica to blad: nowsze zmiany trzeba najpierw przeniesc do repo.
# Plisty: scripts/server/*.plist kopiuje do ~/Library/LaunchAgents tylko przy roznicy
# i przeladowuje agenta. Agent z RunAtLoad wystartuje wtedy ponownie.
# Katalogi docelowe: SH_DIR, SH_BIN, SH_AGENTS.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SH_DIR="${SH_DIR:-$HOME/sh}"
BIN="${SH_BIN:-$SH_DIR/bin}"
AGENTS="${SH_AGENTS:-$HOME/Library/LaunchAgents}"
fail=0

mkdir -p "$BIN" "$AGENTS"

link() {
  local src="$1" dst="$2"

  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$src" ]; then
      echo "ok:      $dst"
      return
    fi
    echo "BLAD:    $dst wskazuje na $(readlink "$dst")" >&2
    fail=1
    return
  fi

  if [ -e "$dst" ] && ! cmp -s "$dst" "$src"; then
    echo "BLAD:    $dst rozni sie od $src, przenies zmiany do repo" >&2
    fail=1
    return
  fi

  ln -s "$src" "$dst.tmp.$$"
  mv -f "$dst.tmp.$$" "$dst"
  echo "link:    $dst -> $src"
}

plist() {
  local src="$1" name dst domain
  name="$(basename "$src")"
  dst="$AGENTS/$name"
  domain="gui/$(id -u)"

  if cmp -s "$src" "$dst"; then
    echo "ok:      $dst"
    return
  fi

  if ! plutil -lint -s "$src"; then
    echo "BLAD:    $src nie jest poprawna plista" >&2
    fail=1
    return
  fi

  # Agent moze nie byc zaladowany, np. przy pierwszej instalacji.
  launchctl bootout "$domain/${name%.plist}" 2>/dev/null || true
  cp "$src" "$dst.tmp.$$"
  mv -f "$dst.tmp.$$" "$dst"
  if launchctl bootstrap "$domain" "$dst"; then
    echo "plist:   $dst przeladowany"
  else
    echo "BLAD:    nie udalo sie zaladowac $dst" >&2
    fail=1
  fi
}

for src in "$REPO"/scripts/server/*.sh; do
  [ "$(basename "$src")" = install.sh ] || link "$src" "$BIN/$(basename "$src")"
done

for src in "$REPO"/scripts/shctl/*; do
  if [ -f "$src" ] && [ -x "$src" ]; then
    link "$src" "$BIN/$(basename "$src")"
  fi
done

link "$REPO/scripts/server/Brewfile" "$SH_DIR/Brewfile"

for src in "$REPO"/scripts/server/*.plist; do
  plist "$src"
done

# Pliki spoza repo: tylko ostrzezenie, nic nie kasujemy.
for dst in "$BIN"/*; do
  [ -e "$dst" ] || [ -L "$dst" ] || continue
  [ -L "$dst" ] || echo "UWAGA:   $dst nie pochodzi z repo" >&2
done

exit "$fail"
