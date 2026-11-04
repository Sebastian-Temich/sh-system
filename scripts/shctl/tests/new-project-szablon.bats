#!/usr/bin/env bats
# Nowy projekt z prawdziwego szablonu (sh-template-projekt) na atrapie GitHuba ma zielone CI od
# pierwszego commita: po shctl new-project przechodzą zadania CI szablonu, które nie potrzebują sieci
# (check-dod.sh i testy skryptów). Szablon: SH_TEMPLATE_DIR albo /Users/Shared/sh/sh-template-projekt;
# bez niego (np. CI sh-system) test jest pomijany. Testowany jest commit HEAD szablonu.
load helper

setup() {
  SZABLON="${SH_TEMPLATE_DIR:-/Users/Shared/sh/sh-template-projekt}"
  [ -d "$SZABLON/.git" ] || [ -f "$SZABLON/.git" ] || skip "brak szablonu $SZABLON (SH_TEMPLATE_DIR)"
  command -v bats >/dev/null || skip "brak bats"
  wspolny_setup
  git clone -q --bare "$SZABLON" "$T/remote.git"
  # Szablon może stać na gałęzi roboczej: jej HEAD staje się main nowego repo, jak przy --template.
  git -C "$T/remote.git" update-ref refs/heads/main "$(git -C "$SZABLON" rev-parse HEAD)"
  git -C "$T/remote.git" symbolic-ref HEAD refs/heads/main
  git config --global url."$T/remote.git".insteadOf https://github.com/test-owner/demo.git
}

@test "new-project z szablonu: check-dod i testy skryptow zielone od pierwszego commita" {
  run --separate-stderr "$SHCTL" new-project demo --opis "Projekt testowy CI" --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  P="$SH_DIR/projekty/demo"
  [ -z "$(git -C "$P" status --porcelain)" ]
  run bash "$P/scripts/check-dod.sh" "$P"
  echo "$output"
  [ "$status" -eq 0 ]
  # Testy skryptów w czystym klonie pierwszego commita, jak runner CI.
  git clone -q "$T/remote.git" "$T/ci"
  [ "$(git -C "$T/ci" log -1 --format=%s)" = "shctl: konfiguracja projektu demo (tryb M)" ]
  run env -u SH_DIR bats "$T/ci/scripts/tests"
  echo "$output" | grep -v '^ok' || true
  [ "$status" -eq 0 ]
}

@test "new-project z szablonu: testy skryptow zielone po zmianach orkiestratora w docs/" {
  "$SHCTL" new-project demo --opis "Projekt testowy CI" >/dev/null
  P="$SH_DIR/projekty/demo"
  cd "$P"
  # Typowe pliki wspólne po pierwszych krokach: decyzja, etap w toku, pominięcie z uzasadnieniem.
  "$SHCTL" decision add --co "Pierwsza decyzja | z kreską" --dlaczego "test" --cofniecie "brak" --rola wlasciciel >/dev/null
  "$SHCTL" stage start 00-intake >/dev/null
  "$SHCTL" stage skip 08-qa --notatka "biblioteka bez UI" >/dev/null
  printf '\n| #1 Zadanie | M | 3min | 1 | 1 | 0 | PR #2 |\n' >>docs/metryki.md
  git add -A && git commit -qm "orkiestrator: zmiany" && git push -q origin main
  run bash scripts/check-dod.sh "$P"
  echo "$output"
  [ "$status" -eq 0 ]
  git clone -q "$T/remote.git" "$T/ci"
  run env -u SH_DIR bats "$T/ci/scripts/tests"
  echo "$output" | grep -v '^ok' || true
  [ "$status" -eq 0 ]
}
