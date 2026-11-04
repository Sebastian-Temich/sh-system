#!/usr/bin/env bats
# .github/workflows sh-system oszczędzają minuty (docs/serwer.md, „CI i minuty GitHub Actions”).

setup() {
  command -v yq >/dev/null || skip "brak yq"
  W="$BATS_TEST_DIRNAME/../../../.github/workflows"
}

@test "kazdy job ma timeout-minutes" {
  for f in "$W"/*.yml; do
    run yq -r '.jobs | to_entries[] | select(.value["timeout-minutes"] == null) | .key' "$f"
    [ -z "$output" ] || { echo "$(basename "$f"): $output"; false; }
  done
}

@test "concurrency anuluje tylko biegi PR, bez filtra paths na poziomie workflow" {
  [ "$(yq -r '.concurrency["cancel-in-progress"]' "$W/test.yml")" = "\${{ github.event_name == 'pull_request' }}" ]
  [ "$(yq -r '.on.pull_request.paths // "brak"' "$W/test.yml")" = brak ]
}

@test "bats za lekkimi kontrolami, tylko gdy zakres tego wymaga; nocny i reczny przebieg" {
  [ "$(yq -r '.jobs.bats.needs' "$W/test.yml")" = szybkie ]
  yq -r '.jobs.bats.if' "$W/test.yml" | grep -q 'needs.szybkie.outputs.bats'
  [ "$(yq -r '.on.schedule[0].cron' "$W/test.yml")" != null ]
  [ "$(yq -r '.on | has("workflow_dispatch")' "$W/test.yml")" = true ]
}
