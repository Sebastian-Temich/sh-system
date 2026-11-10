#!/usr/bin/env bats
# Kontrakt SKILL.md: repo przechodzi, a typowe odstępstwa od kontraktu są wykrywane.
bats_require_minimum_version 1.5.0

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  K="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$K/scripts"
  cp -R "$REPO/plugin" "$REPO/.claude-plugin" "$K/"
  cp -R "$REPO/scripts/shctl" "$K/scripts/"
  mkdir -p "$K/scripts/server"
  cp -R "$REPO/scripts/server/lib" "$K/scripts/server/"
  # Nowy skill jako kopia istniejącego, jak robi to autor nowego skilla.
  S="$K/plugin/skills/sh-test"
  mkdir -p "$S"
  sed -e 's/^name: sh-worker$/name: sh-test/' \
    -e 's/^description: .*/description: Testowy skill. Użyj, gdy test tego wymaga./' \
    "$REPO/plugin/skills/sh-worker/SKILL.md" >"$S/SKILL.md"
}

sprawdz() { run --separate-stderr bash "$REPO/scripts/plugin/sprawdz-skille.sh" "$K"; }

@test "repo i nowy skill sa zgodne z kontraktem" {
  run --separate-stderr bash "$REPO/scripts/plugin/sprawdz-skille.sh"
  [ "$status" -eq 0 ]
  sprawdz
  echo "$stderr"
  [ "$status" -eq 0 ]
  ile="$(find "$K/plugin/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')"
  [[ "$output" == *"$ile skill(i) zgodne"* ]] || false
}

@test "brak sekcji i zla kolejnosc" {
  sed -i.bak '/^## Kryteria review$/,/^## Eskalacja$/{/^## Eskalacja$/!d;}' "$S/SKILL.md"
  sprawdz
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"sekcje ## inne niż w kontrakcie"* ]] || false
}

@test "zmieniony blok zasad wspolnych" {
  sed -i.bak 's/Nie wychodzisz poza rolę/Czasem wychodzisz poza rolę/' "$S/SKILL.md"
  sprawdz
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"Zasady wspólne różni się"* ]] || false
}

@test "nieznana komenda shctl" {
  sed -i.bak 's/^shctl escalate --dotyczy/shctl eskaluj --dotyczy/' "$S/SKILL.md"
  sprawdz
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"nieznana komenda shctl: eskaluj"* ]] || false
}

@test "name rozny od katalogu, brak triggerow, brak trybu" {
  sed -i.bak -e 's/^name: sh-test$/name: sh-inny/' -e 's/^description: .*/description: Bez triggerów./' \
    -e '/^### Tryb M$/d' "$S/SKILL.md"
  sprawdz
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"różne od nazwy katalogu"* ]] || false
  [[ "$stderr" == *"Użyj, gdy"* ]] || false
  [[ "$stderr" == *"### Tryb M"* ]] || false
}

@test "skill zablokowany do wywolania" {
  printf -- '---\nname: sh-test\ndescription: X. Użyj, gdy Y.\ndisable-model-invocation: true\nuser-invocable: false\n---\n' >"$S/x"
  sed -n '/^---$/,/^---$/!p' "$S/SKILL.md" | sed '1,0d' >>"$S/x"
  mv "$S/x" "$S/SKILL.md"
  sprawdz
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"sh-test/SKILL.md: skill zablokowany"* ]] || false
}

@test "marketplace: nazwa wpisu rozna od plugin.json" {
  jq '.plugins[0].name = "inny"' "$K/.claude-plugin/marketplace.json" >"$K/m" && mv "$K/m" "$K/.claude-plugin/marketplace.json"
  sprawdz
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"brak wpisu dla pluginu software-house"* ]] || false
}

# --- skille techniczne ------------------------------------------------------------------------------

techniczny() {
  ST="$K/plugin/skills/techniczne/sh-kat-test"
  mkdir -p "$ST"
  sed 's/^name: sh-kat-frontend$/name: sh-kat-test/' \
    "$REPO/plugin/skills/techniczne/sh-kat-frontend/SKILL.md" >"$ST/SKILL.md"
}

@test "techniczne: kopia skilla kategorii jest zgodna" {
  techniczny
  sprawdz
  echo "$stderr"
  [ "$status" -eq 0 ]
  [[ "$output" == *"8 skill(i) techniczne zgodne"* ]] || false
}

@test "techniczne: ponad 150 linii" {
  techniczny
  for _ in $(seq 1 100); do echo "- dopisek" >>"$ST/SKILL.md"; done
  sprawdz
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"sh-kat-test/SKILL.md: 17"*"linii, limit 150"* ]] || false
}

@test "techniczne: brak sekcji Bledy, punkt bez wagi, brak log-failed" {
  techniczny
  sed -i.bak -e '/^## Błędy z naszych projektów$/,$d' -e 's/^1\. 🔴 /1. /' -e 's/--log-failed/--log/g' "$ST/SKILL.md"
  sprawdz
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"sekcje ## inne niż w kontrakcie skilli technicznych"* ]] || false
  [[ "$stderr" == *"bez wagi"* ]] || false
  [[ "$stderr" == *"--log-failed"* ]] || false
}

@test "techniczne: komenda zlozona w bloku sh i zla adnotacja zrodla" {
  techniczny
  printf '\n```sh\npnpm lint && pnpm test\n```\n<!-- źródło: https://github.com/anthropics/skills, wersja: main -->\n' >>"$ST/SKILL.md"
  sprawdz
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"komendą złożoną"* ]] || false
  [[ "$stderr" == *"adnotacja źródła"* ]] || false
}

@test "techniczne: poprawna adnotacja zrodla przechodzi" {
  techniczny
  awk 'NR == 4 { print; print "<!-- źródło: https://github.com/anthropics/skills/skills/webapp-testing, wersja: 0123abc, skopiowano: 2026-11-10, licencja: Apache-2.0 -->"; next } 1' \
    "$ST/SKILL.md" >"$ST/nowy" && mv "$ST/nowy" "$ST/SKILL.md"
  grep -q '^<!-- źródło:' "$ST/SKILL.md"
  sprawdz
  echo "$stderr"
  [ "$status" -eq 0 ]
}

@test "techniczne: brakujacy skill bazowy z mapy warstw" {
  command -v yq >/dev/null || skip "brak yq"
  sed -i.bak 's/^bazowe: \[/bazowe: [sh-nie-ma, /' "$K/plugin/warstwy-skilli.yaml"
  sprawdz
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"skill bazowy sh-nie-ma nie istnieje"* ]] || false
}
