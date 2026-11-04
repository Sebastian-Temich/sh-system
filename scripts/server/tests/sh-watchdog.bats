#!/usr/bin/env bats
# Strażnik limitów sh-watchdog.sh na atrapach herdr i notify, z ustalonym czasem.

bats_require_minimum_version 1.5.0

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  T="$BATS_TEST_TMPDIR"
  export TZ=Europe/Warsaw
  mkdir -p "$T/sh" "$T/mock" "$T/panele"
  cp "$REPO/scripts/server/watchdog-wzorce.txt" "$T/sh/watchdog-wzorce.txt"

  # herdr: workspace "sh" (w1), panele z $T/panele/<id>.txt, etykieta z $T/panele/<id>.label.
  cat >"$T/mock/herdr" <<MOCK
#!/bin/bash
[ -f "$T/herdr-off" ] && exit 1
case "\$1 \$2" in
  "workspace list") echo '{"result":{"workspaces":[{"workspace_id":"w1","label":"sh"}]}}' ;;
  "pane list")
    for f in "$T"/panele/*.txt; do
      [ -e "\$f" ] || continue
      id="\$(basename "\$f" .txt)"
      jq -nc --arg i "\${id/_/:}" --arg l "\$(cat "$T/panele/\$id.label" 2>/dev/null)" '{pane_id:\$i, label:\$l}'
    done | jq -sc '{result:{panes:.}}' ;;
  "pane read") cat "$T/panele/\${3/:/_}.txt" ;;
  "pane process-info")
    if [ -f "$T/orch-dziala" ]; then
      echo '{"result":{"process_info":{"foreground_processes":[{"argv":["claude","remote-control","--name","sh-orkiestrator"],"cwd":"$T/sh","pid":777}]}}}'
    else
      echo '{"result":{"process_info":{"foreground_processes":[{"argv":["-zsh"],"cwd":"$T/sh","pid":11}]}}}'
    fi ;;
  *) exit 2 ;;
esac
MOCK
  cat >"$T/mock/notify" <<MOCK
#!/bin/sh
printf '%s|%s|%s\n' "\$1" "\$2" "\$3" >>"$T/notified"
[ ! -f "$T/notify-fail" ]
MOCK
  chmod +x "$T/mock/herdr" "$T/mock/notify"
}

# 2026-11-02 14:00 w Warszawie (CET, UTC+1).
TERAZ_14=1793624400

straznik() {
  PATH="$T/mock:$PATH" SH_DIR="$T/sh" SH_NOTIFY_CMD="$T/mock/notify" SH_WATCHDOG_PAUZA=0 \
    SH_WATCHDOG_ORKIESTRATOR="${ORKIESTRATOR:-0}" SH_START_CMD="$T/mock/sh-start" SH_WATCHDOG_ORCH_CZEKAJ=2 \
    SH_WATCHDOG_TERAZ="${1:-$TERAZ_14}" run bash "$REPO/scripts/server/sh-watchdog.sh"
}

panel() { # id etykieta tekst
  printf '%s\n' "$3" >"$T/panele/${1/:/_}.txt"
  printf '%s' "$2" >"$T/panele/${1/:/_}.label"
}

powiadomienia() { cat "$T/notified" 2>/dev/null | wc -l | tr -d ' '; }

# Ta sama logika co shctl (scripts/shctl/lib/zadania.sh).
wstrzymania_shctl() {
  LIMITY="$T/sh/limity.md"
  eval "$(sed -n '/^wstrzymania() {/,/^}/p;/^wstrzymany_codex()/p;/^wstrzymany_claude()/p' \
    "$REPO/scripts/shctl/lib/zadania.sh")"
  "$@"
}

@test "plista: co 5 minut, /bin/bash, skrypt z /Users/Shared/sh/bin" {
  local p="$REPO/scripts/server/pl.iskt.softwarehouse.sh-watchdog.plist"
  grep -A1 StartInterval "$p" | grep -q '<integer>300</integer>'
  grep -q '<string>/bin/bash</string>' "$p"
  grep -q 'sh/bin/sh-watchdog.sh</string>' "$p"
}

@test "Claude: wiersz w limity.md, jedno powiadomienie, shctl widzi blokade" {
  panel w1:p1 orkiestrator $'praca\n⎿  You\'ve hit your 5-hour limit · resets 7pm (Europe/Warsaw)\n> '
  straznik
  [ "$status" -eq 0 ]
  grep -qxF '| claude | 2026-11-02 14:00 | 2026-11-02 19:00 | panel orkiestrator (w1:p1) |' "$T/sh/limity.md"
  grep -qxF 'high|Limit claude|Limit claude do 19:00. Po odnowieniu napisz orkiestratorowi: wznów' "$T/notified"
  wstrzymania_shctl wstrzymany_claude
  ! wstrzymania_shctl wstrzymany_codex
  grep -q 'wykryto limit claude w panel orkiestrator (w1:p1)' "$T/sh/logs/watchdog.log"

  straznik $((TERAZ_14 + 300))
  [ "$(powiadomienia)" = 1 ]
}

@test "odnowienie: wiersz znika, drugie powiadomienie, stary komunikat nie wraca" {
  panel w1:p3 worker $'You\'ve hit your 5-hour limit · resets 7pm (Europe/Warsaw)'
  straznik
  straznik $((TERAZ_14 + 5 * 3600 + 120))
  grep -qxF 'default|Limit claude odnowiony|Limit claude odnowiony, możesz wznowić' "$T/notified"
  ! grep -q '^| claude' "$T/sh/limity.md"
  ! wstrzymania_shctl wstrzymany_claude
  grep -qxF '| Wykonawca | Od | Do | Źródło |' "$T/sh/limity.md"

  straznik $((TERAZ_14 + 5 * 3600 + 420))
  [ "$(powiadomienia)" = 2 ]
}

@test "ten sam limit w drugim panelu nie daje drugiego powiadomienia" {
  panel w1:p3 worker $'You\'ve hit your 5-hour limit · resets 7pm'
  straznik
  panel w1:p4 worker2 $'You\'ve hit your 5-hour limit · resets 7pm'
  straznik $((TERAZ_14 + 300))
  [ "$(powiadomienia)" = 1 ]
  [ "$(grep -c '^| claude' "$T/sh/limity.md")" = 1 ]
}

@test "Codex: try again at, blokuje tylko review" {
  panel w1:p5 'review:sklep:14' \
    "ERROR: You've hit your usage limit. Upgrade to Pro (https://chatgpt.com/explore/pro) or try again at 7:05 PM."
  straznik
  grep -qxF '| codex | 2026-11-02 14:00 | 2026-11-02 19:05 | panel review:sklep:14 (w1:p5) |' "$T/sh/limity.md"
  grep -qF 'Limit codex do 19:05.' "$T/notified"
  wstrzymania_shctl wstrzymany_codex
  ! wstrzymania_shctl wstrzymany_claude
}

@test "format z data: Claude 'Nov 3, 7:30pm' i Codex 'Nov 3rd, 2026 7:05 PM'" {
  panel w1:p1 a "You've hit your weekly limit · resets Nov 3, 7:30pm (Europe/Warsaw)"
  panel w1:p2 b "You've hit your usage limit. Upgrade to Plus or try again at Nov 3rd, 2026 7:05 PM."
  straznik
  grep -qF '| claude | 2026-11-02 14:00 | 2026-11-03 19:30 |' "$T/sh/limity.md"
  grep -qF '| codex | 2026-11-02 14:00 | 2026-11-03 19:05 |' "$T/sh/limity.md"
  grep -qF 'Limit claude do 2026-11-03 19:30.' "$T/notified"
}

@test "czas wzgledny: try again in 2 hours 5 minutes" {
  panel w1:p1 a "You've hit your usage limit. Try again in 2 hours 5 minutes."
  straznik
  grep -qF '| codex | 2026-11-02 14:00 | 2026-11-02 16:05 |' "$T/sh/limity.md"
}

@test "strefa z komunikatu: 7pm (UTC) to 20:00 w Warszawie" {
  panel w1:p1 a "You've hit your session limit · resets 7pm (Etc/UTC)"
  straznik
  grep -qF '| claude | 2026-11-02 14:00 | 2026-11-02 20:00 |' "$T/sh/limity.md"
}

@test "godzina sprzed ponad godziny to jutro, sprzed chwili to juz odnowiony" {
  panel w1:p1 a "You've hit your 5-hour limit · resets 12:30pm"
  panel w1:p2 b "You've hit your usage limit. Upgrade or try again at 1:30 PM."
  straznik
  grep -qF '| claude | 2026-11-02 14:00 | 2026-11-03 12:30 |' "$T/sh/limity.md"
  ! grep -q '^| codex' "$T/sh/limity.md"
  grep -q 'limit codex .* już odnowiony' "$T/sh/logs/watchdog.log"
  [ "$(powiadomienia)" = 1 ]
}

@test "komunikat bez godziny: szacunek +5 h, odnowienie dziala" {
  panel w1:p1 a "Claude: You've hit your limit"
  straznik
  grep -qF '| claude | 2026-11-02 14:00 | 2026-11-02 19:00 (szacunek) |' "$T/sh/limity.md"
  grep -qF 'Limit claude do 19:00 (szacunek).' "$T/notified"
  straznik $((TERAZ_14 + 5 * 3600))
  grep -qF 'Limit claude odnowiony' "$T/notified"
}

@test "starszy format Claude z epoch" {
  panel w1:p1 a "Claude AI usage limit reached|$((TERAZ_14 + 3600))"
  straznik
  grep -qF '| claude | 2026-11-02 14:00 | 2026-11-02 15:00 |' "$T/sh/limity.md"
}

@test "bez falszywych alarmow: fast limit, ostrzezenie, zwykly tekst" {
  panel w1:p1 a $'You\'ve hit your fast limit · resets in 8m\nApproaching 5-hour limit · resets 7pm\nrate limit test'
  straznik
  [ "$(powiadomienia)" = 0 ]
  [ ! -f "$T/sh/limity.md" ]
}

@test "herdr niedostepny: odnowienia dzialaja, pamiec komunikatow zostaje" {
  panel w1:p1 a "You've hit your 5-hour limit · resets 7pm"
  straznik
  touch "$T/herdr-off"
  straznik $((TERAZ_14 + 20 * 3600))
  grep -qF 'Limit claude odnowiony' "$T/notified"
  grep -q 'serwer herdr nie odpowiada' "$T/sh/logs/watchdog.log"
  grep -q 'resets 7pm' "$T/sh/stan/watchdog-widziane.txt"
}

@test "zachowuje reczne wpisy listy i nie ma lockfile po przebiegu" {
  printf '# Limity\n\n- codex: ręcznie do 18:00\n' >"$T/sh/limity.md"
  panel w1:p1 a "You've hit your 5-hour limit · resets 7pm"
  straznik
  grep -qxF -- '- codex: ręcznie do 18:00' "$T/sh/limity.md"
  grep -q '^| claude' "$T/sh/limity.md"
  [ ! -d "$T/sh/stan/watchdog.lock" ]
}

@test "brak pliku wzorcow: blad w logu, odnowienia dzialaja" {
  printf '# Limity\n\n| Wykonawca | Od | Do | Źródło |\n|---|---|---|---|\n| claude | 2026-11-02 09:00 | 2026-11-02 13:00 | panel a |\n' \
    >"$T/sh/limity.md"
  rm "$T/sh/watchdog-wzorce.txt"
  straznik
  grep -q 'BLAD: brak .*watchdog-wzorce.txt' "$T/sh/logs/watchdog.log"
  grep -qF 'Limit claude odnowiony' "$T/notified"
  ! grep -q '^| claude' "$T/sh/limity.md"
}

@test "nieudane powiadomienie: 3 proby i blad w logu, wiersz zapisany" {
  touch "$T/notify-fail"
  panel w1:p1 a "You've hit your 5-hour limit · resets 7pm"
  straznik
  [ "$(powiadomienia)" = 3 ]
  grep -q 'BLAD: powiadomienie nie wyszło' "$T/sh/logs/watchdog.log"
  grep -q '^| claude' "$T/sh/limity.md"
}

# --- Orkiestrator: panel w1:p1 „orkiestrator” w atrapie herdr; $T/orch-dziala = w panelu działa
# claude remote-control z cwd $T/sh. $T/orch-obcy = taki proces działa poza panelem (ps, lsof). ---

atrapy_orkiestratora() {
  : >"$T/panele/w1_p1.txt"
  echo orkiestrator >"$T/panele/w1_p1.label"
  printf '#!/bin/sh\n[ -f "%s/orch-obcy" ] && echo " 4242 claude remote-control"\nexit 0\n' "$T" >"$T/mock/ps"
  printf '#!/bin/sh\necho p4242\necho n%s/sh\n' "$T" >"$T/mock/lsof"
  # sh-start: zapisuje wywołanie; bez $T/start-psuje „uruchamia” orkiestratora.
  printf '#!/bin/sh\necho "$*" >>"%s/start-calls"\n[ -f "%s/start-psuje" ] || touch "%s/orch-dziala"\n' "$T" "$T" "$T" >"$T/mock/sh-start"
  chmod +x "$T/mock/ps" "$T/mock/lsof" "$T/mock/sh-start"
  mkdir -p "$T/sh/logs" "$T/sh/stan"
}

@test "orkiestrator dziala: bez restartu i powiadomien" {
  atrapy_orkiestratora
  touch "$T/orch-dziala"
  ORKIESTRATOR=1 straznik
  [ "$status" -eq 0 ]
  [ ! -f "$T/start-calls" ]
  [ "$(powiadomienia)" -eq 0 ]
}

@test "brak orkiestratora: sh-start --no-attach i powiadomienie" {
  atrapy_orkiestratora
  ORKIESTRATOR=1 straznik
  [ "$status" -eq 0 ]
  [ "$(cat "$T/start-calls")" = "--no-attach" ]
  grep -q '^high|Orkiestrator|Orkiestrator uruchomiony ponownie$' "$T/notified"
  grep -q 'orkiestrator uruchomiony ponownie' "$T/sh/logs/watchdog.log"
}

@test "nieudany restart: jedno pilne powiadomienie na serie" {
  atrapy_orkiestratora
  touch "$T/start-psuje"
  ORKIESTRATOR=1 straznik
  ORKIESTRATOR=1 straznik
  [ "$(wc -l <"$T/start-calls" | tr -d ' ')" -eq 2 ]
  [ "$(powiadomienia)" -eq 1 ]
  grep -q '^urgent|Orkiestrator|Orkiestrator nie wstał' "$T/notified"
}

@test "flaga autostart.off: bez restartu" {
  atrapy_orkiestratora
  touch "$T/sh/stan/autostart.off"
  ORKIESTRATOR=1 straznik
  [ ! -f "$T/start-calls" ]
  [ "$(powiadomienia)" -eq 0 ]
  grep -q 'restart wyłączony flagą autostart.off' "$T/sh/logs/watchdog.log"
}

@test "claude remote-control poza panelem: bez restartu, wpis w logu" {
  atrapy_orkiestratora
  touch "$T/orch-obcy"
  ORKIESTRATOR=1 straznik
  [ "$status" -eq 0 ]
  [ ! -f "$T/start-calls" ]
  [ "$(powiadomienia)" -eq 0 ]
  grep -q 'PID 4242) działa w .* poza panelem orkiestratora, nie restartuję' "$T/sh/logs/watchdog.log"
}

@test "minimalne srodowisko launchd (PATH=/usr/bin:/bin): herdr z ~/.local/bin, orkiestrator widoczny" {
  atrapy_orkiestratora
  touch "$T/orch-dziala"
  mkdir -p "$T/home/.local/bin"
  cp "$T/mock/herdr" "$T/mock/sh-start" "$T/home/.local/bin/"
  ln -s "$(command -v jq)" "$T/home/.local/bin/jq"
  run env -i HOME="$T/home" PATH=/usr/bin:/bin SH_DIR="$T/sh" SH_NOTIFY_CMD="$T/mock/notify" \
    SH_WATCHDOG_PAUZA=0 SH_START_CMD="$T/home/.local/bin/sh-start" SH_WATCHDOG_TERAZ="$TERAZ_14" \
    bash "$REPO/scripts/server/sh-watchdog.sh"
  [ "$status" -eq 0 ]
  [ ! -f "$T/start-calls" ]
  grep -q 'przebieg: paneli 1' "$T/sh/logs/watchdog.log"
}
