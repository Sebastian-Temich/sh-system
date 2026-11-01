#!/usr/bin/env bash
# scripts/server/install.sh - symlinki w ~/sh/bin do skryptow z repo sh-system (idempotentny).
#
# Linkuje scripts/server/*.sh (bez install.sh) i pliki wykonywalne z scripts/shctl/.
# Zwykly plik w ~/sh/bin zastepuje tylko, gdy jest identyczny z repo. Roznica to blad:
# nowsze zmiany trzeba najpierw przeniesc do repo. Katalog docelowy: SH_BIN.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
BIN="${SH_BIN:-$HOME/sh/bin}"
fail=0

mkdir -p "$BIN"

link() {
  local src="$1" dst
  dst="$BIN/$(basename "$src")"

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

for src in "$REPO"/scripts/server/*.sh; do
  [ "$(basename "$src")" = install.sh ] || link "$src"
done

for src in "$REPO"/scripts/shctl/*; do
  [ -f "$src" ] && [ -x "$src" ] && link "$src"
done

# Pliki spoza repo: tylko ostrzezenie, nic nie kasujemy.
for dst in "$BIN"/*; do
  [ -e "$dst" ] || [ -L "$dst" ] || continue
  [ -L "$dst" ] || echo "UWAGA:   $dst nie pochodzi z repo" >&2
done

exit "$fail"
