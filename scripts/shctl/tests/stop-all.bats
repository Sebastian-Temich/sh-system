#!/usr/bin/env bats
load helper

setup() {
  wspolny_setup
  projekt_demo
  cd "$T"
  cat >"$T/panele.json" <<JSON
[{"pane_id":"w1:p1","label":"orkiestrator","agent":"claude","agent_status":"idle","cwd":"$SH_DIR"},
 {"pane_id":"w1:p2","label":"powloka","cwd":"$SH_DIR/projekty/demo"},
 {"pane_id":"w1:p3","label":"worker:demo:12","agent":"claude","agent_status":"working","cwd":"$SH_DIR/projekty/wt/12"},
 {"pane_id":"w1:p4","label":"","agent":"claude","agent_status":"idle","cwd":"$SH_DIR/projekty/inny/src"},
 {"pane_id":"w1:p5","label":"","cwd":"$SH_DIR/projekty/demo"},
 {"pane_id":"w1:p6","label":"edytor","cwd":"/tmp"}]
JSON
  cat >"$T/mock/herdr" <<MOCK
#!/bin/bash
echo "\$*" >>"$T/herdr.calls"
case "\$1 \$2" in
  "workspace list") [ ! -f "$T/herdr-down" ] && echo '{"result":{"workspaces":[{"workspace_id":"w1"}]}}' ;;
  "pane list") jq -c '{result:{panes:.}}' "$T/panele.json" ;;
  "pane close") if [ -f "\$SH_DIR/stan/demo.json" ]; then echo "close \$3 stan" >>"$T/kolejnosc"; else echo "close \$3 BEZ-STANU" >>"$T/kolejnosc"; fi; jq -c --arg p "\$3" 'map(select(.pane_id != \$p))' "$T/panele.json" >"$T/p2"; mv "$T/p2" "$T/panele.json"; [ "\$3" != "$(echo w1:p9)" ] ;;
esac
MOCK
  cat >"$T/mock/notify" <<MOCK
#!/bin/sh
echo "\$*" >>"$T/notified"
echo notify >>"$T/kolejnosc"
[ ! -f "$T/notify-fail" ]
MOCK
  chmod +x "$T/mock/herdr" "$T/mock/notify"
  : >"$T/herdr.calls"
}

zamkniete() { grep '^pane close' "$T/herdr.calls" | awk '{print $3}' | tr '\n' ' '; }

@test "zatrzymuje workerow i orkiestratora, reszty nie rusza" {
  run "$SHCTL" stop-all
  [ "$status" -eq 0 ]
  [ "$(zamkniete)" = "w1:p3 w1:p4 w1:p1 " ]
  [ -f "$SH_DIR/stan/demo.json" ]
  [ -f "$SH_DIR/stan/inny.json" ]
  [ "$(jq -r '.panele[0].label, .orkiestrator_zatrzymany, .git.galaz' "$SH_DIR/stan/demo.json" | tr '\n' ' ')" = "worker:demo:12 true main " ]
  grep -q '^high STOP' "$T/notified"
}

@test "stan zawiera worktree, a worktree zostaje" {
  git -C "$P" worktree add -q "$T/wt-1" -b task/1
  "$SHCTL" stop-all
  [ -d "$T/wt-1" ]
  jq -e --arg w "$T/wt-1" '.git.worktree | map(endswith("wt-1")) | any' "$SH_DIR/stan/demo.json"
}

@test "z panelu orkiestratora: stan, workery, powiadomienie, orkiestrator na koncu" {
  HERDR_PANE_ID=w1:p1 run "$SHCTL" stop-all
  [ "$status" -eq 0 ]
  [ "$(tr '\n' ',' <"$T/kolejnosc")" = "close w1:p3 stan,close w1:p4 stan,notify,close w1:p1 stan," ]
}

@test "z panelu orkiestratora: orkiestrator projektu zamyka sie przed wlasnym panelem" {
  jq '. + [{"pane_id":"w1:p7","label":"orkiestrator:demo","agent":"claude","cwd":"/tmp"}]' "$T/panele.json" >"$T/p"
  mv "$T/p" "$T/panele.json"
  HERDR_PANE_ID=w1:p1 run "$SHCTL" stop-all
  [ "$status" -eq 0 ]
  [ "$(zamkniete)" = "w1:p3 w1:p4 w1:p7 w1:p1 " ]
}

@test "--dry-run pokazuje te sama kolejnosc, ktora wykonuje stop" {
  HERDR_PANE_ID=w1:p1 run --separate-stderr "$SHCTL" stop-all --dry-run --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.kolejnosc[0]' <<<"$output" | cut -c1-12)" = "zapisz stan:" ]
  [ "$(jq -r '.wynik.kolejnosc[-1]' <<<"$output")" = "zamknij na końcu: w1:p1 orkiestrator (własny panel)" ]
  run --separate-stderr "$SHCTL" stop-all --dry-run
  [[ "$output" == *"Kolejność:"* ]] || false
  [ -z "$(zamkniete)" ]
}

@test "--projekt nie rusza wspolnego orkiestratora ani innych projektow" {
  run "$SHCTL" stop-all --projekt demo
  [ "$status" -eq 0 ]
  [ "$(zamkniete)" = "w1:p3 " ]
  [ ! -e "$SH_DIR/stan/inny.json" ]
  [ "$(jq -r .orkiestrator_zatrzymany "$SH_DIR/stan/demo.json")" = false ]
}

@test "powtorka zachowuje stan i nie powiadamia" {
  "$SHCTL" stop-all
  cp "$SH_DIR/stan/demo.json" "$T/stan"
  : >"$T/notified"
  run "$SHCTL" stop-all
  [ "$status" -eq 0 ]
  cmp "$SH_DIR/stan/demo.json" "$T/stan"
  [ ! -s "$T/notified" ]
}

@test "--dry-run nic nie zamyka i nie zapisuje" {
  run "$SHCTL" stop-all --dry-run --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.panele | length' <<<"$output")" -eq 3 ]
  [ -z "$(zamkniete)" ]
  [ ! -e "$SH_DIR/stan" ]
  [ ! -s "$T/notified" ]
}

@test "wlasny panel jest zamykany na koncu, po wyniku" {
  HERDR_PANE_ID=w1:p3 run "$SHCTL" stop-all
  [ "$(zamkniete)" = "w1:p4 w1:p1 w1:p3 " ]
}

@test "serwer herdr nie odpowiada: kod 3" {
  touch "$T/herdr-down"
  run --separate-stderr "$SHCTL" stop-all
  [ "$status" -eq 3 ]
}

@test "nieudane powiadomienie: kod 1, panele zatrzymane" {
  touch "$T/notify-fail"
  run --separate-stderr "$SHCTL" stop-all
  [ "$status" -eq 1 ]
  [ "$(zamkniete)" = "w1:p3 w1:p4 w1:p1 " ]
}
