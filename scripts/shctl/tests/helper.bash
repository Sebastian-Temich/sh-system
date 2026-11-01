# Wspólne środowisko testów shctl: atrapy gh, herdr i notify, projekt w katalogu tymczasowym.
bats_require_minimum_version 1.5.0

ETAPY="00-intake 01-brief 02-design 03-wymagania 04-architektura 05-plan 06-zadania 07-realizacja 08-qa wydanie"

wspolny_setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  SHCTL="$REPO/scripts/shctl/shctl"
  # Spacja w ścieżce przez cały zestaw: katalog Obsidiana i projekty nie mogą się na niej rozsypać.
  T="$BATS_TEST_TMPDIR/ze spacja"
  mkdir -p "$T"
  export SH_DIR="$T/sh" SH_NOTIFY_CMD="$T/mock/notify" SH_GH_OWNER=test-owner
  export SH_OBSIDIAN_DIR="$T/Obsidian Vault/SH/Projekty"
  unset SH_CONFIG HERDR_PANE_ID
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$T/gitconfig" HOME="$T/home"
  mkdir -p "$SH_DIR/projekty" "$SH_DIR/logs" "$T/mock" "$T/home"
  git config --global user.name test
  git config --global user.email test@example.com
  git config --global init.defaultBranch main
  : >"$T/gh.calls"
  : >"$T/notified"
  atrapy
  porty_md
  export PATH="$T/mock:$PATH"
}

atrapy() {
  cat >"$T/mock/notify" <<MOCK
#!/bin/sh
echo "\$*" >>"$T/notified"
[ ! -f "$T/notify-fail" ]
MOCK
  cat >"$T/mock/lsof" <<MOCK
#!/bin/sh
exit 1
MOCK
  cat >"$T/mock/gh" <<MOCK
#!/bin/bash
echo "\$*" >>"$T/gh.calls"
case "\$1 \$2" in
  "repo view")
    if [ -f "$T/repo-istnieje" ]; then cat "$T/repo-istnieje"; echo; exit 0; fi
    echo "GraphQL: Could not resolve to a Repository" >&2; exit 1 ;;
  "repo create") printf 'sh-template-projekt' >"$T/repo-istnieje" ;;
  "repo clone") git clone -q "https://github.com/\$3.git" "\$4" ;;
  "issue view") cat "$T/issue-etykieta" 2>/dev/null; echo ;;
  "issue edit") [ ! -f "$T/gh-fail" ] ;;
  "issue list") cat "$T/issues.json" 2>/dev/null || exit 1 ;;
  "label create") ;;
  "api repos/"*) ;;
esac
MOCK
  chmod +x "$T/mock/notify" "$T/mock/lsof" "$T/mock/gh"
}

porty_md() {
  cat >"$SH_DIR/porty.md" <<'MD'
# Rejestr portów

## Zasada

| Port | Usługa | Klucz |
|---|---|---|
| 55X21 | API | port |

## Projekty Supabase

| X | Projekt | Katalog | API | DB | Studio | Mail | Analytics | Shadow | Pooler | Inspector | Stan |
|---|---|---|---|---|---|---|---|---|---|---|---|
| nd. | supabase-local | `~/supabase-local` | 54321 | 54322 | 54323 | 54324 | 54327 | 54320 | 54329 | 8083 | działa |
| 1 | *wolny* | | | | | | | | | | |

**Konflikt:** opis.

## Pozostałe zajęte porty

| Port | Bind | Usługa | Uwagi |
|---|---|---|---|
| 3000 | 127.0.0.1 | Forgejo | Docker |
MD
}

# Minimalna kopia układu szablonu; check-dod to uproszczona wersja reguły „done bez braków”.
szablon_projektu() {
  local d="$1" e
  mkdir -p "$d/docs/_szablony" "$d/scripts" "$d/docs/07-realizacja/escalations" "$d/docs/04-architektura/adr"
  for e in $ETAPY; do
    mkdir -p "$d/docs/$e"
    printf -- '---\netap: %s\nstatus: todo\niteracja: 0\n---\n\n# DoD\n\n## Dokumentacja\n\n- [ ] punkt\n' "$e" >"$d/docs/$e/DoD.md"
  done
  printf -- '---\netap_wdrozenia: A\ntryb_procesu: M\nmax_local: 1\n---\n\n# Konfiguracja\n\nTekst.\n' >"$d/docs/konfiguracja.md"
  printf -- '---\nzadania_todo: 2\nzadania_in_progress: 1\nzadania_review: 0\nzadania_blocked: 0\nzadania_escalated: 0\nzadania_done: 3\nzadania_anulowane: 0\n---\n\n# Status projektu\n\n## Bieżący etap\n\n(brak)\n\n## Punkt przekazania\n\n(brak)\n' >"$d/docs/status.md"
  printf '# Decyzje projektu\n\n| Data | Źródło | Pytanie | Decyzja |\n|---|---|---|---|\n' >"$d/docs/decyzje.md"
  printf '# Zlecenie źródłowe\n\nTreść.\n' >"$d/docs/00-intake/zrodlo.md"
  printf '# ADR-NNN: TYTUŁ\n\nStatus: proponowana | zastąpiona przez ADR-NNN\nData: RRRR-MM-DD\n\n## Kontekst\n' >"$d/docs/_szablony/adr.md"
  printf '# Specyfikacja: NAZWA\n\n## Cel\n' >"$d/docs/_szablony/specyfikacja.md"
  printf '# Raport T-NR: TYTUŁ\n\nIssue: #NR\nPR: #NR\n' >"$d/docs/_szablony/raport-zadania.md"
  printf '# Raport QA: KAMIEŃ MILOWY\n\nData: RRRR-MM-DD\n' >"$d/docs/_szablony/raport-qa.md"
  printf '# Dokumentacja techniczna: NAZWA\n' >"$d/docs/_szablony/wydanie-techniczna.md"
  printf '# Eskalacja E-NNN: TYTUŁ\n\nData: RRRR-MM-DD\nZadanie: #NR\nPowód: 3 iteracje | sekret\n\n## Sytuacja\n\n## Co już sprawdzono\n\n## Opcje i rekomendacja\n\n## Czego potrzeba od właściciela\n\n## Rozstrzygnięcie\n' >"$d/docs/_szablony/eskalacja.md"
  cat >"$d/scripts/check-dod.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
rc=0
for f in "$1"/docs/*/DoD.md; do
  if grep -q '^status: done' "$f" && grep -q '^- \[ \]' "$f"; then
    echo "BŁĄD: $f: pola niezaznaczone" >&2
    rc=1
  fi
done
exit "$rc"
SH
  printf '#!/bin/sh\nfor a in x; do gh label create test --force; done\n' >"$d/scripts/setup-labels.sh"
  chmod +x "$d/scripts/"*.sh
  printf '# Projekt\n' >"$d/README.md"
  mkdir -p "$d/src"
  printf 'kod\n' >"$d/src/app.txt"
}

# Projekt w ~/sh/projekty/demo z originem na atrapie GitHuba i poprawnym układem.
projekt_demo() {
  P="$SH_DIR/projekty/demo"
  git init -q "$P"
  szablon_projektu "$P"
  git -C "$P" remote add origin https://github.com/test-owner/demo.git
  git -C "$P" add -A
  git -C "$P" commit -qm start
  cd "$P"
}

szablon_remote() {
  local s="$T/szablon"
  git init -q "$s"
  szablon_projektu "$s"
  git -C "$s" add -A
  git -C "$s" commit -qm start
  git clone -q --bare "$s" "$T/remote.git"
  # Origin zostaje adresem GitHuba, a ruch idzie do lokalnego repo.
  git config --global url."$T/remote.git".insteadOf https://github.com/test-owner/demo.git
}

fm() { yq --front-matter=extract ".$2" "$1"; }
