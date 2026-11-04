#!/usr/bin/env bash
# /Users/Shared/sh/bin/test-herdr.sh - test CLI herdr. Uruchamiac z wnetrza panelu herdr.
# Tworzy panel, uruchamia komende, czyta wynik, czeka na status i zamyka panel.
set -euo pipefail

[[ "${HERDR_ENV:-}" == 1 ]] || { echo 'FAIL: test trzeba uruchomic w panelu herdr' >&2; exit 1; }
echo "kontekst: workspace=$HERDR_WORKSPACE_ID pane=$HERDR_PANE_ID"

PANE=""
cleanup() {
  [[ -n "$PANE" ]] && herdr pane close "$PANE" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo '1. pane split'
PANE="$(herdr pane split --current --direction down --cwd "$PWD" --no-focus | jq -r .result.pane.pane_id)"
echo "   panel: $PANE"

echo '2. pane run'
herdr pane run "$PANE" 'echo test-herdr' >/dev/null

echo '3. pane wait-output'
# Regex dopasowuje cala linie, zeby nie zlapac echa samej komendy.
LINE="$(herdr pane wait-output "$PANE" --regex '(?m)^test-herdr$' --source recent-unwrapped --timeout 15000 |
  jq -r .result.matched_line)"
echo "   dopasowanie: $LINE"

echo '4. pane read'
READ="$(herdr pane read "$PANE" --source recent-unwrapped --lines 20)"
grep -qx 'test-herdr' <<<"$READ" || { echo 'FAIL: brak wyniku w pane read' >&2; exit 1; }
echo '   wynik obecny'

echo '5. status: pane get i agent wait'
herdr pane get "$PANE" | jq -c '.result.pane | {pane_id, agent_status}'
ORCH="$(herdr pane list --workspace "$HERDR_WORKSPACE_ID" |
  jq -r '[.result.panes[] | select(.label == "orkiestrator")][0].pane_id')"
herdr agent wait "$ORCH" --until idle --timeout 15000 | jq -c '.result.agent | {pane_id, agent, agent_status}'

echo '6. pane close'
herdr pane close "$PANE" | jq -r .result.type
CLOSED="$PANE"
PANE=""
herdr pane list --workspace "$HERDR_WORKSPACE_ID" |
  jq -e --arg p "$CLOSED" 'all(.result.panes[]; .pane_id != $p)' >/dev/null
echo "   panel $CLOSED zamkniety"

echo 'OK: test-herdr zaliczony'
