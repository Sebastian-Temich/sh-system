#!/usr/bin/env bats
# shctl template update: pliki zarządzane przez szablon z main szablonu do projektu (main i nowy tag baseline).
load helper-zadania

setup() {
  zadania_setup
  git tag baseline && git push -q origin main baseline
  S="$T/tpl-src"
  git init -q -b main "$S"
  mkdir -p "$S/.claude/roles/worker" "$S/docs/_szablony" "$S/.github/workflows"
  # Wersja 1 szablonu: taka jak w projekcie (check-dod.sh, adr.md).
  cp scripts/check-dod.sh "$S/scripts-check-dod.tmp"
  mkdir -p "$S/scripts" && mv "$S/scripts-check-dod.tmp" "$S/scripts/check-dod.sh"
  cp docs/_szablony/adr.md "$S/docs/_szablony/adr.md"
  cp docs/_szablony/specyfikacja.md "$S/docs/_szablony/specyfikacja.md"
  cp .claude/roles/worker/settings.json "$S/.claude/roles/worker/settings.json"
  git -C "$S" add -A && git -C "$S" commit -qm v1
  # Wersja 2: nowe treści i nowe pliki.
  printf '#!/usr/bin/env bash\necho v2\n' >"$S/scripts/check-dod.sh"
  chmod +x "$S/scripts/check-dod.sh"
  printf '# ADR v2\n' >"$S/docs/_szablony/adr.md"
  printf '# Spec v2\n' >"$S/docs/_szablony/specyfikacja.md"
  echo '{"nowy":"worker"}' >"$S/.claude/roles/worker/settings.json"
  printf 'name: ci\n' >"$S/.github/workflows/ci.yml"
  printf '# AGENTS v2\n' >"$S/AGENTS.md"
  printf '# poza zakresem\n' >"$S/README.md"
  git -C "$S" add -A && git -C "$S" commit -qm v2
  git clone -q --bare "$S" "$T/tpl.git"
  git config --global url."$T/tpl.git".insteadOf https://github.com/test-owner/sh-template-projekt.git
  # Projekt zmienił specyfikację po swojemu: to treść projektu.
  printf '# Spec projektu\n' >docs/_szablony/specyfikacja.md
  git commit -qam "spec projektu" && git push -q origin main
  BASE="$(git rev-parse baseline)"
}

akcje() { jq -r --arg k "$1" '.wynik[$k].pliki | map("\(.plik)=\(.akcja)") | sort | join(" ")' <<<"$output"; }

@test "template update --dry-run: plan zmian, nic nie zmienia" {
  MAIN="$(git rev-parse main)"
  run --separate-stderr "$SHCTL" template update --baseline --dry-run --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(akcje main)" = ".claude/roles/worker/settings.json=aktualizacja .github/workflows/ci.yml=nowy AGENTS.md=nowy docs/_szablony/adr.md=aktualizacja docs/_szablony/specyfikacja.md=pominiety scripts/check-dod.sh=aktualizacja" ]
  [[ "$stderr" == *"--force"* ]] || false
  [ "$(git rev-parse main)" = "$MAIN" ]
  [ -z "$(git tag -l 'baseline-*')" ]
}

@test "template update: commit na main, tresc projektu zostaje, README poza zakresem" {
  run --separate-stderr "$SHCTL" template update --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(cat docs/_szablony/adr.md)" = "# ADR v2" ]
  [ "$(cat docs/_szablony/specyfikacja.md)" = "# Spec projektu" ]
  [ "$(cat AGENTS.md)" = "# AGENTS v2" ]
  [ -x scripts/check-dod.sh ]
  [ "$(cat README.md)" = "# Projekt" ]
  [ "$(git --git-dir "$T/remote.git" rev-parse main)" = "$(git rev-parse HEAD)" ]
  [[ "$(git log -1 --format=%s)" == "szablon: pliki z sh-template-projekt "* ]] || false
  [ "$(jq -r .wynik.baseline <<<"$output")" = null ]
  # Druga runda: zostaje tylko pominięta treść projektu.
  run --separate-stderr "$SHCTL" template update --json
  [ "$(akcje main)" = "docs/_szablony/specyfikacja.md=pominiety" ]
  [ "$(jq -r .wynik.zmiana <<<"$output")" = false ]
}

@test "template update --force nadpisuje tresc projektu" {
  run --separate-stderr "$SHCTL" template update --force --json
  [ "$status" -eq 0 ]
  [ "$(cat docs/_szablony/specyfikacja.md)" = "# Spec v2" ]
  [[ "$(akcje main)" == *"docs/_szablony/specyfikacja.md=nadpisany"* ]] || false
}

@test "template update --baseline: nowy tag baseline-RRRRMMDD, stary baseline nieruszony" {
  run --separate-stderr "$SHCTL" template update --baseline --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  t="baseline-$(date +%Y%m%d)"
  [ "$(jq -r .wynik.baseline.tag <<<"$output")" = "$t" ]
  [ "$(git rev-parse baseline)" = "$BASE" ]
  [ "$(git --git-dir "$T/remote.git" rev-parse refs/tags/baseline)" = "$BASE" ]
  [ "$(git --git-dir "$T/remote.git" rev-parse "refs/tags/$t^{commit}")" = "$(jq -r .wynik.baseline.po <<<"$output")" ]
  [ "$(git show "$t:docs/_szablony/adr.md")" = "# ADR v2" ]
  [ "$(git rev-parse "$t^")" = "$BASE" ]
  [ "$(git ls-tree "$t" scripts/check-dod.sh | cut -c1-6)" = 100755 ]
  # Kolejny baseline tego dnia dostaje sufiks, a bazą jest najnowszy.
  git -C "$T/tpl-src" commit -q --allow-empty -m pusty
  printf '# ADR v3\n' >"$T/tpl-src/docs/_szablony/adr.md"
  git -C "$T/tpl-src" commit -qam v3 && git -C "$T/tpl-src" push -q "$T/tpl.git" main
  sleep 1
  run --separate-stderr "$SHCTL" template update --baseline --json
  [ "$(jq -r '.wynik.baseline.z, .wynik.baseline.tag' <<<"$output" | tr '\n' ' ')" = "$t $t-2 " ]
}

@test "template update: klon poza main to odmowa, profile update juz nie istnieje" {
  git checkout -q -b inna
  run --separate-stderr "$SHCTL" template update
  [ "$status" -eq 4 ]
  run --separate-stderr "$SHCTL" profile update
  [ "$status" -eq 2 ]
}
