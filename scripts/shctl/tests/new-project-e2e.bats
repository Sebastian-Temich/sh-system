#!/usr/bin/env bats
# Pełny test na prawdziwym GitHubie. Wyłącznie po wyraźnej zgodzie właściciela w danej rozmowie
# (docs/serwer.md, „Praca nad systemem”). Uruchomienie:
#   SHCTL_E2E=1 bats scripts/shctl/tests/new-project-e2e.bats
# Zakłada prywatne repo sh-test-RRRRMMDD-HHMM i przed utworzeniem dopisuje je do
# /Users/Shared/sh/stan/do-usuniecia.md. Rejestr portów i klon są w katalogu tymczasowym.
bats_require_minimum_version 1.5.0

setup() {
  [ "${SHCTL_E2E:-}" = 1 ] || skip "wymaga SHCTL_E2E=1 i zgody właściciela"
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  T="$BATS_TEST_TMPDIR"
  LISTA="/Users/Shared/sh/stan/do-usuniecia.md"
  NAZWA="sh-test-$(date +%Y%m%d-%H%M)"
  SLUG="${SH_GH_OWNER:-Sebastian-Temich}/$NAZWA"
  export SH_DIR="$T/sh" SH_NOTIFY_CMD=/usr/bin/true SH_OBSIDIAN_DIR="$T/Obsidian Vault/SH/Projekty"
  mkdir -p "$SH_DIR"
  cp "/Users/Shared/sh/porty.md" "$SH_DIR/porty.md"
}

dopisz_do_usuniecia() {
  mkdir -p "$(dirname "$LISTA")"
  [ -f "$LISTA" ] || printf '# Repo do usunięcia\n\n| Nazwa | Data | Po co |\n|---|---|---|\n' >"$LISTA"
  printf '| %s | %s | test new-project-e2e |\n' "$NAZWA" "$(date +%F)" >>"$LISTA"
}

@test "new-project na GitHubie, z powtorka" {
  ! gh repo view "$SLUG" --json name >/dev/null 2>&1 || false
  dopisz_do_usuniecia
  run --separate-stderr "$REPO/scripts/shctl/shctl" new-project "$NAZWA" --opis "Test shctl" --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  P="$SH_DIR/projekty/$NAZWA"

  [ "$(gh repo view "$SLUG" --json visibility --jq .visibility)" = PRIVATE ]
  [ "$(gh repo view "$SLUG" --json templateRepository --jq .templateRepository.name)" = sh-template-projekt ]
  [ "$(gh repo view "$SLUG" --json deleteBranchOnMerge --jq .deleteBranchOnMerge)" = true ]
  [ "$(gh label list --repo "$SLUG" --limit 100 --json name --jq 'map(select(.name == "status:escalated")) | length')" -eq 1 ]
  gh api "repos/$SLUG/contents/docs/konfiguracja.md" --jq .content | base64 -d | grep -q '^blok_portow: '
  gh api "repos/$SLUG/contents/docs/02-design/DoD.md" --jq .content | base64 -d | grep -qx 'status: pominiety'
  bash "$P/scripts/check-dod.sh" "$P"
  [ -f "$SH_OBSIDIAN_DIR/$NAZWA/docs/konfiguracja.md" ]
  [ ! -e "$SH_OBSIDIAN_DIR/$NAZWA/scripts" ]

  a="$(git -C "$P" rev-parse HEAD)"
  run --separate-stderr "$REPO/scripts/shctl/shctl" new-project "$NAZWA" --opis "Test shctl"
  [ "$status" -eq 0 ]
  [ "$(git -C "$P" rev-parse HEAD)" = "$a" ]
}
