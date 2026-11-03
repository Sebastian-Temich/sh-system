#!/usr/bin/env bats
load helper

setup() {
  wspolny_setup
  for n in docker herdr codex claude bats; do printf '#!/bin/sh\nexit 0\n' >"$T/mock/$n"; done
  printf '#!/bin/sh\necho "status: running"\n' >"$T/mock/herdr"
  printf '#!/bin/sh\necho "{\\"loggedIn\\": true}"\n' >"$T/mock/claude"
  chmod +x "$T/mock/"*
  mkdir -p "$HOME/.config/sh"
  echo temat >"$HOME/.config/sh/ntfy-topic"
  # Orkiestrator: claude remote-control (PID 777) w $SH_DIR, PATH z $T/orch-path.
  printf '#!/bin/sh\n[ -f "%s/orch-off" ] || echo 777\n' "$T" >"$T/mock/pgrep"
  cat >"$T/mock/lsof" <<MOCK
#!/bin/sh
case "\$*" in *"-d cwd"*) echo p777; echo "n$SH_DIR" ;; *) exit 1 ;; esac
MOCK
  printf '#!/bin/sh\necho "claude remote-control PATH=$(cat "%s/orch-path") HOME=/x"\n' "$T" >"$T/mock/ps"
  echo "/usr/bin:$SH_DIR/bin:/bin" >"$T/orch-path"
  chmod +x "$T/mock/"*
}

@test "orkiestrator dziala i ma ~/sh/bin w PATH" {
  run "$SHCTL" doctor --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.kontrole | map(select(.nazwa == "orkiestrator"))[0].stan' <<<"$output")" = ok ]
  [ "$(jq -r '.wynik.kontrole | map(select(.nazwa == "PATH panelu herdr"))[0].stan' <<<"$output")" = ok ]
}

@test "orkiestrator nie dziala: kod 1" {
  touch "$T/orch-off"
  run --separate-stderr "$SHCTL" doctor --json
  [ "$status" -eq 1 ]
  [ "$(jq -r '.wynik.kontrole | map(select(.nazwa == "orkiestrator"))[0].stan' <<<"$output")" = blad ]
}

@test "brak ~/sh/bin w PATH orkiestratora: kod 1" {
  echo "/usr/bin:/bin" >"$T/orch-path"
  run --separate-stderr "$SHCTL" doctor --json
  [ "$status" -eq 1 ]
  jq -e '.wynik.kontrole | map(select(.nazwa == "PATH panelu herdr"))[0] | .stan == "blad" and (.szczegoly | test("orkiestrator PID 777"))' <<<"$output"
}

@test "wszystko dziala: kod 0, JSON z kontrolami" {
  run "$SHCTL" doctor --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.bledy <<<"$output")" -eq 0 ]
  jq -e '.wynik.kontrole | map(.nazwa) | index("logowanie claude")' <<<"$output"
}

@test "niezalogowany claude: kod 1 i wskazowka" {
  printf '#!/bin/sh\necho "{\\"loggedIn\\": false}"\n' >"$T/mock/claude"
  run --separate-stderr "$SHCTL" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"claude auth login"* ]] || false
}

@test "Docker nie odpowiada: kod 1" {
  printf '#!/bin/sh\nexit 1\n' >"$T/mock/docker"
  run --separate-stderr "$SHCTL" doctor --json
  [ "$status" -eq 1 ]
  [ "$(jq -r '.wynik.kontrole | map(select(.nazwa == "Docker"))[0].stan' <<<"$output")" = blad ]
}

@test "brak tematu ntfy: kod 1" {
  rm "$HOME/.config/sh/ntfy-topic"
  run --separate-stderr "$SHCTL" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"brak tematu"* ]] || false
}

@test "lokalny core.hooksPath to ostrzezenie, nie blad" {
  git config --global core.hooksPath /x/scripts/server/git-hooks
  projekt_demo
  git config --local core.hooksPath .husky
  cd "$T"
  run "$SHCTL" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"hooki demo"* ]] || false
  [[ "$output" == *"wyłącza globalny pre-push"* ]] || false
}

@test "bez --test-notify nie wysyla, z nim wysyla" {
  "$SHCTL" doctor
  [ ! -s "$T/notified" ]
  "$SHCTL" doctor --test-notify
  [ -s "$T/notified" ]
}

klon_vaulta() {
  szablon_remote
  "$SHCTL" obsidian link demo
}
ob_stan() { jq -r '.wynik.kontrole | map(select(.nazwa == "Obsidian demo"))[0] | .stan + ":" + .szczegoly' <<<"$output"; }

@test "czysty i aktualny klon w vaulcie" {
  klon_vaulta
  run --separate-stderr "$SHCTL" doctor --json
  [ "$(ob_stan)" = "ok:czysty i aktualny" ]
}

@test "niezacommitowana zmiana w klonie to uwaga" {
  klon_vaulta
  echo notatka >"$SH_OBSIDIAN_DIR/demo/docs/nowa.md"
  run --separate-stderr "$SHCTL" doctor --json
  [ "$status" -eq 0 ]
  [ "$(ob_stan)" = "uwaga:niezacommitowane zmiany: 1" ]
}

@test "klon za origin to uwaga, doctor niczego nie pobiera" {
  klon_vaulta
  git clone -q "$T/remote.git" "$T/obok"
  git -C "$T/obok" commit -q --allow-empty -m nowy
  git -C "$T/obok" push -q origin HEAD:main
  przed="$(git -C "$SH_OBSIDIAN_DIR/demo" rev-parse origin/main)"
  run --separate-stderr "$SHCTL" doctor --json
  [ "$(ob_stan)" = "uwaga:różni się od origin" ]
  [ "$(git -C "$SH_OBSIDIAN_DIR/demo" rev-parse origin/main)" = "$przed" ]
}

do_usuniecia() { jq -r '.wynik.kontrole | map(select(.nazwa == "repo do usunięcia"))[0] | .stan + ":" + .szczegoly' <<<"$output"; }

@test "brak listy repo do usuniecia: zero" {
  run --separate-stderr "$SHCTL" doctor --json
  [ "$(do_usuniecia)" = "ok:0" ]
}

lista() {
  mkdir -p "$SH_DIR/stan"
  printf '# Repo do usunięcia\n\nOpis.\n\n| Nazwa | Data | Po co |\n|---|---|---|\n| sh-test-a | 2026-11-02 | test |\n| `sh-test-b` | 2026-11-02 | test |\n' >"$SH_DIR/stan/do-usuniecia.md"
}

@test "lista: istniejace repo zostaja, bez wplywu na kod wyjscia" {
  lista
  printf 'x' >"$T/repo-istnieje"
  run --separate-stderr "$SHCTL" doctor --json
  [ "$status" -eq 0 ]
  [ "$(do_usuniecia)" = "uwaga:2: sh-test-a sh-test-b" ]
  grep -q 'repo view test-owner/sh-test-a --json name' "$T/gh.calls"
}

@test "lista: repo, ktorych nie ma, znikaja z listy" {
  lista
  cat >"$T/mock/gh" <<'MOCK'
#!/bin/bash
case "$3" in
  */sh-test-a) echo "GraphQL: Could not resolve to a Repository" >&2; exit 1 ;;
esac
MOCK
  run --separate-stderr "$SHCTL" doctor --json
  [ "$(do_usuniecia)" = "uwaga:1: sh-test-b; zdjęte z listy: sh-test-a" ]
  ! grep -q 'sh-test-a' "$SH_DIR/stan/do-usuniecia.md" || false
  grep -q '`sh-test-b`' "$SH_DIR/stan/do-usuniecia.md"
  grep -qx 'Opis.' "$SH_DIR/stan/do-usuniecia.md"
  grep -qx '| Nazwa | Data | Po co |' "$SH_DIR/stan/do-usuniecia.md"
}

@test "lista: wszystkie usuniete to zero i stan ok" {
  lista
  run --separate-stderr "$SHCTL" doctor --json
  [ "$(do_usuniecia)" = "ok:0; zdjęte z listy: sh-test-a sh-test-b" ]
}

@test "lista: blad sieci lub logowania niczego nie zdejmuje" {
  lista
  printf '#!/bin/sh\necho "HTTP 401: Bad credentials" >&2\nexit 1\n' >"$T/mock/gh"
  cp "$SH_DIR/stan/do-usuniecia.md" "$T/l"
  run --separate-stderr "$SHCTL" doctor --json
  [ "$(do_usuniecia)" = "uwaga:2; niesprawdzone: sh-test-a sh-test-b" ]
  cmp "$SH_DIR/stan/do-usuniecia.md" "$T/l"
}

@test "lista: --dry-run nie zmienia pliku" {
  lista
  cp "$SH_DIR/stan/do-usuniecia.md" "$T/l"
  run --separate-stderr "$SHCTL" doctor --dry-run --json
  [ "$(do_usuniecia)" = "ok:0; do zdjęcia z listy: sh-test-a sh-test-b" ]
  cmp "$SH_DIR/stan/do-usuniecia.md" "$T/l"
}

@test "lista z samym naglowkiem: zero" {
  mkdir -p "$SH_DIR/stan"
  printf '| Nazwa | Data | Po co |\n|---|---|---|\n' >"$SH_DIR/stan/do-usuniecia.md"
  run --separate-stderr "$SHCTL" doctor --json
  [ "$(do_usuniecia)" = "ok:0" ]
}

@test "Obsidian sync: brak przebiegu, potem data ostatniej udanej, flaga wylaczenia" {
  mkdir -p "$SH_OBSIDIAN_DIR"
  run --separate-stderr "$SHCTL" doctor --json
  [ "$(jq -r '.wynik.kontrole | map(select(.nazwa == "Obsidian sync"))[0].stan' <<<"$output")" = uwaga ]
  "$SHCTL" obsidian sync >/dev/null
  run --separate-stderr "$SHCTL" doctor --json
  [ "$(jq -r '.wynik.kontrole | map(select(.nazwa == "Obsidian sync"))[0].stan' <<<"$output")" = ok ]
  [[ "$(jq -r '.wynik.kontrole | map(select(.nazwa == "Obsidian sync"))[0].szczegoly' <<<"$output")" == "ostatnia udana "20* ]] || false
  touch "$SH_DIR/stan/obsidian-sync.off"
  run --separate-stderr "$SHCTL" doctor
  [[ "$output" == *"wyłączona flagą"* ]] || false
}
