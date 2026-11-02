#!/usr/bin/env bats
# Kontrakt SKILL.md: repo przechodzi, a typowe odstępstwa od kontraktu są wykrywane.
bats_require_minimum_version 1.5.0

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  K="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$K/scripts"
  cp -R "$REPO/plugin" "$REPO/.claude-plugin" "$K/"
  cp -R "$REPO/scripts/shctl" "$K/scripts/"
  # Skill zbudowany z szablonu, jak robi to autor nowego skilla.
  S="$K/plugin/skills/sh-test"
  mkdir -p "$S"
  sed -e 's/^name: _szablon$/name: sh-test/' \
    -e 's/^description: .*/description: Testowy skill. Użyj, gdy test tego wymaga./' \
    -e '/^# Tylko w szablonie/d' -e '/^disable-model-invocation: true$/d' -e '/^user-invocable: false$/d' \
    "$REPO/plugin/skills/_szablon/SKILL.md" >"$S/SKILL.md"
}

sprawdz() { run --separate-stderr bash "$REPO/scripts/plugin/sprawdz-skille.sh" "$K"; }

@test "repo i skill z szablonu sa zgodne z kontraktem" {
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

@test "skill zablokowany jak szablon i szablon bez blokad" {
  printf -- '---\nname: sh-test\ndescription: X. Użyj, gdy Y.\ndisable-model-invocation: true\nuser-invocable: false\n---\n' >"$S/x"
  sed -n '/^---$/,/^---$/!p' "$S/SKILL.md" | sed '1,0d' >>"$S/x"
  mv "$S/x" "$S/SKILL.md"
  sed -i.bak '/^user-invocable: false$/d' "$K/plugin/skills/_szablon/SKILL.md"
  sprawdz
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"sh-test/SKILL.md: skill zablokowany jak szablon"* ]] || false
  [[ "$stderr" == *"_szablon/SKILL.md: szablon musi mieć"* ]] || false
}

@test "marketplace: nazwa wpisu rozna od plugin.json" {
  jq '.plugins[0].name = "inny"' "$K/.claude-plugin/marketplace.json" >"$K/m" && mv "$K/m" "$K/.claude-plugin/marketplace.json"
  sprawdz
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"brak wpisu dla pluginu software-house"* ]] || false
}
