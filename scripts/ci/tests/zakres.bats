#!/usr/bin/env bats
# scripts/ci/zakres.sh: które testy uruchomić w GitHub Actions.

setup() {
  Z="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)/zakres.sh"
  cd "$BATS_TEST_TMPDIR"
  git init -q -b main r && cd r
  git config user.name t && git config user.email t@example.com
  mkdir -p docs scripts src && echo a >docs/a.md && echo b >src/b.sh && echo c >scripts/c.sh
  git add -A && GIT_COMMITTER_DATE="2020-01-01T00:00:00Z" git commit -qm baza --date 2020-01-01T00:00:00Z
  BAZA="$(git rev-parse HEAD)"
  export WZORCE_DOCS="docs/* *.md" WZORCE_SKRYPTY="scripts/* .github/*" GITHUB_OUTPUT="$BATS_TEST_TMPDIR/out"
}

pr() { git add -A && git commit -qm zmiana && ZDARZENIE=pull_request BAZA="$BAZA" GLOWA="$(git rev-parse HEAD)" bash "$Z" 2>/dev/null; }
wynik() { grep "^$1=" "$GITHUB_OUTPUT" | tail -1 | cut -d= -f2; }

@test "PR tylko z docs i .md: bez testow" {
  echo x >>docs/a.md && echo r >README.md && mkdir -p docs/x/y && echo z >docs/x/y/z.txt
  pr
  [ "$(wynik kod)" = false ] && [ "$(wynik skrypty)" = false ]
}

@test "PR z kodem: testy kodu, bez testow skryptow" {
  echo x >>src/b.sh && echo x >>docs/a.md
  pr
  [ "$(wynik kod)" = true ] && [ "$(wynik skrypty)" = false ]
}

@test "PR ze skryptami albo workflow: oba zestawy" {
  echo x >>scripts/c.sh
  pr
  [ "$(wynik kod)" = true ] && [ "$(wynik skrypty)" = true ]
  mkdir -p .github/workflows && echo y >.github/workflows/ci.yml
  pr
  [ "$(wynik skrypty)" = true ]
}

@test "bez WZORCE_SKRYPTY skrypty = kod" {
  unset WZORCE_SKRYPTY
  echo x >>src/b.sh
  pr
  [ "$(wynik skrypty)" = true ]
}

@test "PR bez bazy albo z blednym SHA: pelne testy" {
  ZDARZENIE=pull_request BAZA= GLOWA=x bash "$Z" 2>/dev/null
  [ "$(wynik kod)" = true ]
  ZDARZENIE=pull_request BAZA=deadbeef GLOWA=cafe bash "$Z" 2>/dev/null
  [ "$(wynik kod)" = true ] && [ "$(wynik skrypty)" = true ]
}

@test "push na main: smoke" {
  ZDARZENIE=push bash "$Z" 2>/dev/null
  [ "$(wynik kod)" = false ] && [ "$(wynik skrypty)" = false ]
}

@test "nocny: pelne tylko po swiezych commitach" {
  ZDARZENIE=schedule bash "$Z" 2>/dev/null
  [ "$(wynik kod)" = false ]
  echo x >>src/b.sh && git commit -qam swiezy
  ZDARZENIE=schedule bash "$Z" 2>/dev/null
  [ "$(wynik kod)" = true ] && [ "$(wynik skrypty)" = true ]
}

@test "recznie i nieznane zdarzenie: pelne testy" {
  ZDARZENIE=workflow_dispatch bash "$Z" 2>/dev/null
  [ "$(wynik kod)" = true ]
  ZDARZENIE=merge_group bash "$Z" 2>/dev/null
  [ "$(wynik kod)" = true ]
}
