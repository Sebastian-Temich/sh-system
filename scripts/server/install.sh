#!/usr/bin/env bash
# scripts/server/install.sh - instaluje pliki serwera z repo sh-system (idempotentny).
#
# Symlinki: scripts/server/*.sh (bez install.sh) i pliki wykonywalne z scripts/shctl/ do
# /Users/Shared/sh/bin, Brewfile do /Users/Shared/sh/Brewfile, codex/reviewer.config.toml do $CODEX_HOME (~/.codex) i
# orkiestrator-settings.json do /Users/Shared/sh/.claude/settings.json. Zwykly plik zastepuje tylko, gdy jest identyczny
# z repo. Roznica to blad: nowsze zmiany trzeba najpierw przeniesc do repo.
# Konfiguracja Maca (max_local): kopia scripts/server/konfiguracja-sh.md do /Users/Shared/sh/konfiguracja.md, gdy jej brak.
# Plisty: scripts/server/*.plist kopiuje do ~/Library/LaunchAgents tylko przy roznicy
# i przeladowuje agenta. Niezaladowanego agenta laduje zawsze, takze bez zmiany plisty.
# Agent z RunAtLoad wystartuje wtedy ponownie. Nieudany bootstrap to kod bledu, komenda
# do recznego zaladowania i notify.sh high. Flaga /Users/Shared/sh/stan/autostart.off wstrzymuje
# ladowanie agenta sh-start; plista jest nadal kopiowana, bez dotykania launchd.
# Tak samo /Users/Shared/sh/stan/obsidian-sync.off dla agenta obsidian-sync (obsidian-sync.sh co 5 minut).
# Git: globalny core.hooksPath na scripts/server/git-hooks. Inna wartosc to blad, nie nadpisujemy.
# Logowanie git do github.com: helper gh auth git-credential (bezwzgledna sciezka), gdy go brak.
# Repo z lokalnym core.hooksPath w SH_DIR i SH_DIR/projekty dostaje ostrzezenie, bo wygrywa on z globalnym.
# Katalogi docelowe: SH_DIR, SH_BIN, SH_AGENTS. Powiadomienie: SH_NOTIFY_CMD.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SH_DIR="${SH_DIR:-/Users/Shared/sh}"
BIN="${SH_BIN:-$SH_DIR/bin}"
AGENTS="${SH_AGENTS:-$HOME/Library/LaunchAgents}"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
NOTIFY="${SH_NOTIFY_CMD:-$REPO/scripts/server/notify.sh}"
AUTOSTART_LABEL=pl.iskt.softwarehouse.sh-start
AUTOSTART_OFF="$SH_DIR/stan/autostart.off"
OBSIDIAN_SYNC_LABEL=pl.iskt.softwarehouse.obsidian-sync
OBSIDIAN_SYNC_OFF="$SH_DIR/stan/obsidian-sync.off"
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
  local src="$1" name dst domain label off=0 changed="" co=autostart
  name="$(basename "$src")"
  dst="$AGENTS/$name"
  domain="gui/$(id -u)"
  label="${name%.plist}"
  if [ "$label" = "$AUTOSTART_LABEL" ] && [ -e "$AUTOSTART_OFF" ]; then
    off=1
  fi
  if [ "$label" = "$OBSIDIAN_SYNC_LABEL" ] && [ -e "$OBSIDIAN_SYNC_OFF" ]; then
    off=1
    co="agent synchronizacji Obsidiana"
  fi

  if ! cmp -s "$src" "$dst"; then
    changed=1
    if ! plutil -lint -s "$src"; then
      echo "BLAD:    $src nie jest poprawna plista" >&2
      fail=1
      return
    fi
    # Agent moze nie byc zaladowany, np. przy pierwszej instalacji.
    [ "$off" = 1 ] || launchctl bootout "$domain/$label" 2>/dev/null || true
    cp "$src" "$dst.tmp.$$"
    mv -f "$dst.tmp.$$" "$dst"
  fi

  if [ "$off" = 1 ]; then
    echo "pomijam: $label: $co wyłączony przez właściciela"
    return
  fi

  if [ -z "$changed" ] && launchctl print "$domain/$label" >/dev/null 2>&1; then
    echo "ok:      $dst"
    return
  fi

  if launchctl bootstrap "$domain" "$dst"; then
    echo "plist:   $dst zaladowany"
    return
  fi

  echo "BLAD:    nie udalo sie zaladowac $label. Recznie:" >&2
  echo "         launchctl bootstrap $domain $dst" >&2
  "$NOTIFY" high 'install.sh: agent niezaladowany' "$label: bootstrap nieudany" ||
    echo "UWAGA:   nie udalo sie wyslac powiadomienia" >&2
  fail=1
}

git_hooki() {
  local src="$REPO/scripts/server/git-hooks" obecny repo lokalny
  obecny="$(git config --global --get core.hooksPath || true)"

  if [ -z "$obecny" ]; then
    git config --global core.hooksPath "$src"
    echo "git:     core.hooksPath -> $src"
  elif [ "$obecny" = "$src" ]; then
    echo "ok:      core.hooksPath"
  else
    echo "BLAD:    core.hooksPath wskazuje na $obecny, oczekiwano $src" >&2
    fail=1
  fi

  for repo in "$SH_DIR"/*/ "$SH_DIR"/projekty/*/; do
    [ -e "$repo.git" ] || continue
    lokalny="$(git -C "$repo" config --local --get core.hooksPath || true)"
    [ -z "$lokalny" ] ||
      echo "UWAGA:   ${repo%/} ma wlasny core.hooksPath ($lokalny), hook globalny tam nie dziala" >&2
  done
}

# Logowanie git do github.com przez gh: token z pęku kluczy gh, helper z bezwzględną ścieżką, więc
# działa także pod launchd (minimalny PATH, bez terminala). Pusty helper przed nim wyłącza dla
# github.com osxkeychain, z którego git kasuje wpis po pierwszym odrzuconym tokenie.
git_logowanie() {
  local gh obecny
  obecny="$(git config --global --get-all credential.https://github.com.helper || true)"
  case "$obecny" in
    *"auth git-credential"*)
      echo "ok:      git credential helper (gh)"
      return
      ;;
  esac
  gh="$(command -v gh || true)"
  if [ -z "$gh" ]; then
    echo "UWAGA:   brak gh w PATH, git nie ma logowania do github.com" >&2
    return
  fi
  git config --global --replace-all credential.https://github.com.helper ''
  git config --global --add credential.https://github.com.helper "!'$gh' auth git-credential"
  echo "git:     credential.https://github.com.helper -> $gh auth git-credential"
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

# Konfiguracja Maca: limit workerów wspólny dla projektów. Wartość ustawia właściciel na serwerze.
konf_sh="$SH_DIR/konfiguracja.md"
if [ ! -e "$konf_sh" ]; then
  cp "$REPO/scripts/server/konfiguracja-sh.md" "$konf_sh"
  echo "kopia:   $konf_sh"
else
  echo "ok:      $konf_sh"
fi

# Profil Codex dla shctl review run (codex exec -p reviewer): tylko odczyt, model reviewera.
mkdir -p "$CODEX_DIR"
link "$REPO/codex/reviewer.config.toml" "$CODEX_DIR/reviewer.config.toml"

# Ustawienia sesji orkiestratora w /Users/Shared/sh: stare skille zostawione dla Paperclipa ukryte i zablokowane.
mkdir -p "$SH_DIR/.claude"
link "$REPO/scripts/server/orkiestrator-settings.json" "$SH_DIR/.claude/settings.json"

for src in "$REPO"/scripts/server/*.plist; do
  plist "$src"
done

git_hooki
git_logowanie

# Dowiązania do plików usuniętych z repo (np. notify-hook.sh) znikają; pliki spoza repo: tylko
# ostrzeżenie, nic innego nie kasujemy.
for dst in "$BIN"/*; do
  [ -e "$dst" ] || [ -L "$dst" ] || continue
  if [ -L "$dst" ]; then
    case "$(readlink "$dst")" in
      "$REPO"/*) [ -e "$dst" ] || { rm -f "$dst"; echo "usuniete: $dst (brak celu w repo)"; } ;;
    esac
  else
    echo "UWAGA:   $dst nie pochodzi z repo" >&2
  fi
done

exit "$fail"
