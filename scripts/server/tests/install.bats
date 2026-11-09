#!/usr/bin/env bats
# Test LaunchAgentow w install.sh na atrapach launchctl i notify.

bats_require_minimum_version 1.5.0

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  T="$BATS_TEST_TMPDIR"
  LABEL=pl.iskt.softwarehouse.sh-start
  PLIST="$T/agents/$LABEL.plist"
  mkdir -p "$T/sh" "$T/agents" "$T/mock"

  # Stan i wywolania liczymy tylko dla sh-start; inne agenty (np. sh-watchdog) trafiaja do calls-inne.
  cat >"$T/mock/launchctl" <<MOCK
#!/bin/sh
case "\$*" in
  *$LABEL*) ;;
  *) echo "\$*" >>"$T/calls-inne"; exit 0 ;;
esac
echo "\$1" >>"$T/calls"
case "\$1" in
  print) [ -f "$T/loaded" ] ;;
  bootout) rm -f "$T/loaded" ;;
  bootstrap) [ ! -f "$T/fail" ] && touch "$T/loaded" ;;
esac
MOCK
  cat >"$T/mock/notify" <<MOCK
#!/bin/sh
echo "\$*" >>"$T/notified"
[ ! -f "$T/notify-fail" ]
MOCK
  chmod +x "$T/mock/launchctl" "$T/mock/notify"
  # Wszystkie plisty juz na miejscu: bez zmiany install.sh nie wola plutil (brak go w CI na Linuksie).
  cp "$REPO"/scripts/server/*.plist "$T/agents/"
  : >"$T/calls"
}

install() {
  GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$T/gitconfig" \
    PATH="$T/mock:$PATH" SH_DIR="$T/sh" CODEX_HOME="$T/codex" SH_AGENTS="$T/agents" SH_NOTIFY_CMD="$T/mock/notify" \
    run --separate-stderr bash "$REPO/scripts/server/install.sh"
}

wymaga_plutil() {
  command -v plutil >/dev/null || skip "wymaga macOS: plutil"
}

globalny_hooks_path() {
  GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$T/gitconfig" git config --global --get core.hooksPath
}

@test "ustawia globalny core.hooksPath, drugi raz bez zmian" {
  install
  [ "$status" -eq 0 ]
  [ "$(globalny_hooks_path)" = "$REPO/scripts/server/git-hooks" ]
  install
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok:      core.hooksPath"* ]]
}

@test "obcy core.hooksPath: blad bez nadpisania" {
  GIT_CONFIG_GLOBAL="$T/gitconfig" git config --global core.hooksPath /inny
  install
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"core.hooksPath wskazuje na /inny"* ]]
  [ "$(globalny_hooks_path)" = /inny ]
}

@test "repo z lokalnym core.hooksPath: ostrzezenie" {
  git init -q "$T/sh/projekt"
  git -C "$T/sh/projekt" config --local core.hooksPath .husky/_
  install
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"projekt ma wlasny core.hooksPath (.husky/_)"* ]]
}

@test "repo w projekty/ z lokalnym core.hooksPath: ostrzezenie" {
  mkdir "$T/sh/projekty"
  git init -q "$T/sh/projekty/klient"
  git -C "$T/sh/projekty/klient" config --local core.hooksPath .husky/_
  install
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"projekty/klient ma wlasny core.hooksPath"* ]]
}

@test "zaladowany, plista bez zmian: tylko print" {
  touch "$T/loaded"
  install
  [ "$status" -eq 0 ]
  [ "$(cat "$T/calls")" = print ]
  [ ! -f "$T/notified" ]
}

@test "niezaladowany, plista bez zmian: bootstrap" {
  install
  [ "$status" -eq 0 ]
  [ "$(tr '\n' ' ' <"$T/calls")" = "print bootstrap " ]
  [ -f "$T/loaded" ]
  [ ! -f "$T/notified" ]
}

@test "blad bootstrap: kod bledu, komenda reczna, notify high" {
  touch "$T/fail"
  install
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"launchctl bootstrap gui/$(id -u) $PLIST"* ]]
  [[ "$(cat "$T/notified")" == high* ]]
}

@test "blad bootstrap i blad notify: nadal kod bledu" {
  touch "$T/fail" "$T/notify-fail"
  install
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"nie udalo sie wyslac"* ]]
}

@test "po bledzie bootstrap kolejne uruchomienie laduje agenta" {
  wymaga_plutil
  rm "$PLIST"
  touch "$T/fail"
  install
  [ "$status" -eq 1 ]
  rm "$T/fail"
  install
  [ "$status" -eq 0 ]
  [ -f "$T/loaded" ]
}

@test "zaladowany, plista zmieniona: bootout i bootstrap" {
  wymaga_plutil
  touch "$T/loaded"
  echo '<!-- x -->' >>"$PLIST"
  install
  [ "$status" -eq 0 ]
  [ "$(tr '\n' ' ' <"$T/calls")" = "bootout bootstrap " ]
  cmp "$REPO/scripts/server/$LABEL.plist" "$PLIST"
}

@test "flaga autostart.off: brak launchctl i komunikat" {
  mkdir -p "$T/sh/stan"
  touch "$T/sh/stan/autostart.off"
  install
  [ "$status" -eq 0 ]
  [[ "$output" == *"autostart wyłączony przez właściciela"* ]]
  [ ! -s "$T/calls" ]
  [ ! -f "$T/loaded" ]
}

@test "flaga autostart.off, plista zmieniona: kopia bez launchctl" {
  wymaga_plutil
  mkdir -p "$T/sh/stan"
  touch "$T/sh/stan/autostart.off"
  echo '<!-- x -->' >>"$PLIST"
  install
  [ "$status" -eq 0 ]
  [ ! -s "$T/calls" ]
  cmp "$REPO/scripts/server/$LABEL.plist" "$PLIST"
}

@test "usuniecie flagi: kolejny install laduje agenta" {
  mkdir -p "$T/sh/stan"
  touch "$T/sh/stan/autostart.off"
  install
  rm "$T/sh/stan/autostart.off"
  install
  [ "$status" -eq 0 ]
  [ -f "$T/loaded" ]
}

@test "profil Codex reviewer: symlink do repo, powtorka bez zmian" {
  install
  [ "$status" -eq 0 ]
  [ "$(readlink "$T/codex/reviewer.config.toml")" = "$REPO/codex/reviewer.config.toml" ]
  install
  [ "$status" -eq 0 ]
  grep -q "ok:      $T/codex/reviewer.config.toml" <<<"$output"
}

@test "plista sh-watchdog: kopia i zaladowanie" {
  wymaga_plutil
  rm "$T/agents/pl.iskt.softwarehouse.sh-watchdog.plist"
  install
  [ "$status" -eq 0 ]
  cmp "$REPO/scripts/server/pl.iskt.softwarehouse.sh-watchdog.plist" "$T/agents/pl.iskt.softwarehouse.sh-watchdog.plist"
  grep -q 'bootstrap .*sh-watchdog.plist' "$T/calls-inne"
  [ "$(readlink "$T/sh/bin/sh-watchdog.sh")" = "$REPO/scripts/server/sh-watchdog.sh" ]
}

@test "dowiazanie do pliku usunietego z repo znika, obce pliki zostaja" {
  mkdir -p "$T/sh/bin"
  ln -s "$REPO/scripts/server/notify-hook.sh" "$T/sh/bin/notify-hook.sh"
  ln -s /nie/ma/takiego "$T/sh/bin/obce-dowiazanie"
  echo x >"$T/sh/bin/wlasny.sh"
  install
  [ ! -L "$T/sh/bin/notify-hook.sh" ]
  [ -L "$T/sh/bin/obce-dowiazanie" ]
  [ -f "$T/sh/bin/wlasny.sh" ]
  [ "$(readlink "$T/sh/bin/obsidian-sync.sh")" = "$REPO/scripts/server/obsidian-sync.sh" ]
}

@test "ustawienia orkiestratora: symlink /Users/Shared/sh/.claude/settings.json do repo" {
  install
  [ "$status" -eq 0 ]
  [ "$(readlink "$T/sh/.claude/settings.json")" = "$REPO/scripts/server/orkiestrator-settings.json" ]
  jq -e '.skillOverrides["tworca-wymagan"] == "off" and (.permissions.deny | index("Skill(tworca-wymagan)"))' \
    "$T/sh/.claude/settings.json" >/dev/null
}

@test "instrukcje sesji: symlink /Users/Shared/sh/CLAUDE.md do repo" {
  install
  [ "$status" -eq 0 ]
  [ "$(readlink "$T/sh/CLAUDE.md")" = "$REPO/scripts/server/CLAUDE-sh.md" ]
  grep -q 'Jedna prosta komenda na jedno wywołanie' "$T/sh/CLAUDE.md"
}

@test "plista obsidian-sync: kopia i zaladowanie" {
  wymaga_plutil
  rm "$T/agents/pl.iskt.softwarehouse.obsidian-sync.plist"
  install
  [ "$status" -eq 0 ]
  cmp "$REPO/scripts/server/pl.iskt.softwarehouse.obsidian-sync.plist" "$T/agents/pl.iskt.softwarehouse.obsidian-sync.plist"
  grep -q 'bootstrap .*obsidian-sync.plist' "$T/calls-inne"
}

@test "flaga obsidian-sync.off: agent obsidian-sync bez launchctl, sh-start dalej ladowany" {
  mkdir -p "$T/sh/stan"
  touch "$T/sh/stan/obsidian-sync.off"
  install
  [ "$status" -eq 0 ]
  [[ "$output" == *"obsidian-sync: agent synchronizacji Obsidiana wyłączony przez właściciela"* ]]
  ! grep -q obsidian-sync "$T/calls-inne" 2>/dev/null
  [ -f "$T/loaded" ]
}

@test "git: helper gh auth git-credential z bezwzgledna sciezka, drugi raz bez zmian" {
  printf '#!/bin/sh\nexit 0\n' >"$T/mock/gh"
  chmod +x "$T/mock/gh"
  install
  [ "$status" -eq 0 ]
  helpery="$(GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$T/gitconfig" git config --global --get-all credential.https://github.com.helper)"
  [ "$helpery" = "$(printf '\n%s' "!'$T/mock/gh' auth git-credential")" ]
  install
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok:      git credential helper (gh)"* ]] || false
  [ "$(GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$T/gitconfig" git config --global --get-all credential.https://github.com.helper | wc -l | tr -d ' ')" -eq 2 ]
}

@test "konfiguracja Maca: kopia z max_local 2 gdy brak, wartosc wlasciciela zostaje" {
  install
  [ "$status" -eq 0 ]
  grep -qx 'max_local: 2' "$T/sh/konfiguracja.md"
  sed -i.bak 's/^max_local: 2$/max_local: 1/' "$T/sh/konfiguracja.md"
  install
  [ "$status" -eq 0 ]
  grep -qx 'max_local: 1' "$T/sh/konfiguracja.md"
}
