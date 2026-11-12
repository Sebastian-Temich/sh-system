#!/usr/bin/env bats
# shctl adopt: przejęcie istniejącego repo (start i analiza, adaptacja po checkpoincie, bramka,
# upublicznienie). Repo przejęte i szablon to lokalne repo pod adresami GitHuba (insteadOf).

load helper

setup() {
  wspolny_setup
  REPO_INFO='{"nameWithOwner":"acme/app","visibility":"PRIVATE","isArchived":false,"isEmpty":false,"defaultBranchRef":{"name":"main"}}'
  printf '%s' "$REPO_INFO" >"$T/repo.json"
  echo PRIVATE >"$T/widocznosc"
  cat >"$T/mock/gh" <<MOCK
#!/bin/bash
echo "\$*" >>"$T/gh.calls"
case "\$1 \$2" in
  "repo view")
    case "\$*" in
      *"--jq"*) tr 'A-Z' 'a-z' <"$T/widocznosc" ;;
      *) cat "$T/repo.json"; echo ;;
    esac ;;
  "repo edit") case "\$*" in *"--visibility public"*) echo PUBLIC >"$T/widocznosc" ;; esac ;;
  "pr list") cat "$T/pr-otwarty" 2>/dev/null || true ;;
  "pr create") echo "https://github.com/acme/app/pull/7" ;;
  "pr view")
    case "\$*" in
      *"--json comments"*) echo '{"comments":[]}' ;;
      *) echo '{"number":7,"title":"00-analiza: raport","state":"OPEN","headRefName":"stage/00-analiza","headRefOid":"abc1234","closingIssuesReferences":[],"url":"https://github.com/acme/app/pull/7"}' ;;
    esac ;;
  "label create" | "variable set") ;;
  "auth git-credential") printf 'username=x-access-token\npassword=atrapa\n' ;;
esac
MOCK
  # gitleaks: przy $T/gitleaks-sekret zapisuje raport (bez wartości sekretu) i kończy się kodem 1.
  cat >"$T/mock/gitleaks" <<MOCK
#!/bin/bash
echo "\$*" >>"$T/gitleaks.calls"
[ -f "$T/gitleaks-sekret" ] || exit 0
r=""
while [ \$# -gt 0 ]; do [ "\$1" = --report-path ] && r="\$2"; shift; done
[ -z "\$r" ] || printf '[{"RuleID":"generic-api-key","File":"src/stary.ts","StartLine":3,"Commit":"abcdef1234567","Date":"2025-01-01T00:00:00Z","Secret":"REDACTED"}]' >"\$r"
echo "leaks found: 1"
exit 1
MOCK
  chmod +x "$T/mock/gh" "$T/mock/gitleaks"
  aplikacja
  szablon
}

# Repo przejęte: aplikacja z Lovable i Supabase, bez docs/ procesu.
aplikacja() {
  local s="$T/app-src"
  git init -q -b main "$s"
  mkdir -p "$s/src" "$s/supabase/migrations"
  printf '{"name":"app","devDependencies":{"lovable-tagger":"1"}}\n' >"$s/package.json"
  printf 'export const app = 1;\n' >"$s/src/app.ts"
  printf 'create table public.notatki (id uuid);\nalter table public.notatki enable row level security;\n' >"$s/supabase/migrations/20250101_start.sql"
  printf '# App\n' >"$s/README.md"
  printf 'node_modules\n' >"$s/.gitignore"
  git -C "$s" add -A
  git -C "$s" commit -qm "Lovable: start" --author="gpt-engineer-app[bot] <bot@users.noreply.github.com>"
  git clone -q --bare "$s" "$T/app.git"
  git config --global url."$T/app.git".insteadOf https://github.com/acme/app.git
}

szablon() {
  local s="$T/szablon"
  git init -q -b main "$s"
  szablon_projektu "$s"
  printf '# AGENTS.md\n\nZasady.\n' >"$s/AGENTS.md"
  printf '@AGENTS.md\n' >"$s/CLAUDE.md"
  mkdir -p "$s/.github/workflows" "$s/.claude/roles/worker" "$s/scripts/tests"
  printf 'name: CI\n' >"$s/.github/workflows/ci.yml"
  printf '{}\n' >"$s/.claude/roles/worker/settings.json"
  printf 'test\n' >"$s/scripts/tests/x.bats"
  printf 'packages: []\n' >"$s/pnpm-workspace.yaml"
  git -C "$s" add -A
  git -C "$s" commit -qm szablon
  git config --global url."$s".insteadOf https://github.com/test-owner/sh-template-projekt.git
}

WT() { printf '%s' "$SH_DIR/wt/app/stage-00-analiza"; }

@test "start: klon, worktree stage/00-analiza, szkielet etapu w commicie, bez pushu i bez zmiany widocznosci" {
  run --separate-stderr "$SHCTL" adopt acme/app --nazwa app --json
  [ "$status" -eq 0 ] || { echo "$output"; false; }
  jq -e '.ok and .wynik.repo == "acme/app" and .wynik.widocznosc == "private" and .wynik.galaz == "stage/00-analiza"' <<<"$output"
  jq -e '.wynik.lovable == true and .wynik.supabase == true and .wynik.limit_analizy_min == 120' <<<"$output"
  P="$SH_DIR/projekty/app"
  [ "$(git -C "$P" symbolic-ref --short HEAD)" = main ]
  [ ! -e "$P/docs/konfiguracja.md" ]
  [ "$(git -C "$(WT)" symbolic-ref --short HEAD)" = stage/00-analiza ]
  K="$(WT)/docs/konfiguracja.md"
  [ "$(fm "$K" pochodzenie)" = adopt ]
  [ "$(fm "$K" adopt.repo)" = acme/app ]
  [ "$(fm "$K" adopt.widocznosc)" = private ]
  [ "$(fm "$K" adopt.lovable)" = true ]
  [ "$(fm "$K" adopt.limit_analizy_min)" = 120 ]
  [ -n "$(fm "$K" adopt.analiza_do)" ]
  [ "$(fm "$(WT)/docs/00-analiza/DoD.md" status)" = in-progress ]
  grep -q '^# Analiza projektu: app$' "$(WT)/docs/00-analiza/raport.md"
  grep -q '^# Dla właściciela$' "$(WT)/docs/00-analiza/raport.md"
  jq -e '.lovable.wykryto' "$(WT)/docs/00-analiza/wykryj.json"
  [ "$(git -C "$(WT)" log -1 --format=%s)" = "shctl: adopt app, etap 00-analiza" ]
  # Szkielet dotyka tylko docs/.
  [ -z "$(git -C "$(WT)" diff --name-only origin/main HEAD | grep -v '^docs/')" ]
  # Bez pushu, bez zmiany widoczności, bez plików env.
  [ -z "$(git --git-dir="$T/app.git" branch --list 'stage/*')" ]
  ! grep -q 'repo edit' "$T/gh.calls" || false
  [ ! -e "$P/.env.local" ] && [ ! -e "$(WT)/.env.local" ]
  grep -q '| 1 | app |' "$SH_DIR/porty.md"
  [ -d "$SH_OBSIDIAN_DIR/app/.git" ]
}

@test "start: powtorka niczego nie dubluje" {
  "$SHCTL" adopt acme/app --nazwa app >/dev/null
  n="$(git -C "$(WT)" rev-list --count HEAD)"
  run "$SHCTL" adopt acme/app --nazwa app
  [ "$status" -eq 0 ]
  [ "$(git -C "$(WT)" rev-list --count HEAD)" -eq "$n" ]
  [[ "$output" == *"szkielet etapu już jest"* ]]
}

@test "start: --dry-run nic nie tworzy; limit analizy z konfiguracja.md serwera" {
  printf -- '---\nadopt:\n  limit_analizy_min: 45\n---\n' >"$SH_DIR/konfiguracja.md"
  run "$SHCTL" adopt acme/app --nazwa app --dry-run --json
  [ "$status" -eq 0 ]
  jq -e '.dry_run and .wynik.limit_analizy_min == 45' <<<"$output"
  [ ! -e "$SH_DIR/projekty/app" ]
  [ ! -e "$(WT)" ]
}

@test "start: odmowy i bledne uzycie" {
  run "$SHCTL" adopt app --nazwa app
  [ "$status" -eq 2 ]
  run "$SHCTL" adopt acme/app
  [ "$status" -eq 2 ]
  run "$SHCTL" adopt acme/app --nazwa app --limit-analizy zero
  [ "$status" -eq 2 ]
  jq '.defaultBranchRef.name = "master"' <<<"$REPO_INFO" >"$T/repo.json"
  run "$SHCTL" adopt acme/app --nazwa app
  [ "$status" -eq 4 ]
  [[ "$output" == *"master"* ]]
  jq '.isArchived = true' <<<"$REPO_INFO" >"$T/repo.json"
  run "$SHCTL" adopt acme/app --nazwa app
  [ "$status" -eq 4 ]
  printf '%s' "$REPO_INFO" >"$T/repo.json"
  mkdir -p "$SH_DIR/projekty/app"
  git init -q "$SH_DIR/projekty/app"
  git -C "$SH_DIR/projekty/app" remote add origin https://github.com/acme/inne.git
  run "$SHCTL" adopt acme/app --nazwa app
  [ "$status" -eq 4 ]
}

@test "start: repo z docs/konfiguracja.md spoza adopt to juz projekt SH" {
  git clone -q "$T/app.git" "$T/k"
  mkdir -p "$T/k/docs"
  printf -- '---\ntryb_procesu: M\n---\n' >"$T/k/docs/konfiguracja.md"
  git -C "$T/k" add -A
  git -C "$T/k" commit -qm sh
  git -C "$T/k" push -q origin HEAD:main
  run "$SHCTL" adopt acme/app --nazwa app
  [ "$status" -eq 4 ]
  [[ "$output" == *"to projekt SH"* ]]
}

# Analiza zmergowana na main repo przejętego; CHECKPOINT=1 zaznacza wszystkie pola i akceptację.
analiza_na_main() {
  "$SHCTL" adopt acme/app --nazwa app >/dev/null
  printf '\n## Lovable i Supabase\n\nRLS: notatki ma politykę.\n' >>"$(WT)/docs/00-analiza/raport.md"
  if [ "${1:-}" = checkpoint ]; then
    sed -i.bak 's/^- \[ \]/- [x]/' "$(WT)/docs/00-analiza/DoD.md"
    rm -f "$(WT)/docs/00-analiza/DoD.md.bak"
    printf '| 2026-11-12 | wlasciciel | Akceptacja analizy i kierunku | akceptuję analizę i kierunek. Cofnięcie: nowa analiza |\n' >>"$(WT)/docs/decyzje.md"
  fi
  git -C "$(WT)" add -A
  git -C "$(WT)" commit -qm "00-analiza: raport"
  git -C "$(WT)" push -q origin HEAD:main
  git -C "$SH_DIR/projekty/app" pull -q --ff-only
}

@test "przed merge'em analizy: review run i --projekt znajduja konfiguracje i DoD w worktree 00-analiza" {
  "$SHCTL" adopt acme/app --nazwa app >/dev/null
  [ ! -e "$SH_DIR/projekty/app/docs/konfiguracja.md" ]
  cd "$(WT)"
  run --separate-stderr "$SHCTL" review run 7 --dry-run --json
  [ "$status" -eq 0 ] || { echo "$output $stderr"; false; }
  jq -e '.ok and (.wynik | tostring | test("00-analiza"))' <<<"$output"
  cd "$T"
  run --separate-stderr "$SHCTL" review run 7 --dry-run --json --projekt app
  [ "$status" -eq 0 ] || { echo "$output $stderr"; false; }
}

@test "etapy projektu przejetego zaczynaja sie od 00-analiza" {
  analiza_na_main
  run "$SHCTL" stage review 00-analiza --projekt app --dry-run
  [[ "$output" != *"nieznany etap"* ]] || { echo "$output"; false; }
}

@test "adaptacja: odmowa bez checkpointu" {
  analiza_na_main
  run "$SHCTL" adopt adaptacja --projekt app
  [ "$status" -eq 4 ]
  [[ "$output" == *"akceptuję analizę i kierunek"* ]]
}

@test "adaptacja po checkpoincie: pliki procesu bez kodu aplikacji, CI szablonu pominiete, sh.yml, Lovable, PR" {
  analiza_na_main checkpoint
  run --separate-stderr "$SHCTL" adopt adaptacja --projekt app --json
  [ "$status" -eq 0 ] || { echo "$output"; false; }
  jq -e '.wynik.pr == "https://github.com/acme/app/pull/7" and .wynik.nowy' <<<"$output"
  A="$SH_DIR/wt/app/adaptacja"
  [ "$(git -C "$A" symbolic-ref --short HEAD)" = adopt/adaptacja ]
  zmiany="$(git -C "$A" diff --name-only origin/main HEAD)"
  # Bez kodu aplikacji i bez plików szablonu, które kolidują z projektem.
  ! grep -qE '^(src/|supabase/|package.json|README.md|\.gitignore|pnpm-workspace.yaml|scripts/tests/|\.github/workflows/ci.yml)' <<<"$zmiany" || { echo "$zmiany"; false; }
  grep -qx AGENTS.md <<<"$zmiany"
  grep -qx CLAUDE.md <<<"$zmiany"
  grep -qx .github/workflows/sh.yml <<<"$zmiany"
  grep -qx scripts/check-dod.sh <<<"$zmiany"
  grep -qx .claude/roles/worker/settings.json <<<"$zmiany"
  grep -qx docs/04-plan/DoD.md <<<"$zmiany"
  grep -qxF '## Lovable' "$A/AGENTS.md"
  K="$A/docs/konfiguracja.md"
  [ "$(fm "$K" pochodzenie)" = adopt ]
  [ "$(fm "$K" adopt.repo)" = acme/app ]
  [ "$(fm "$K" max_local)" = 1 ]
  [ "$(fm "$A/docs/00-analiza/DoD.md" status)" = done ]
  grep -q 'Akceptacja analizy' "$A/docs/decyzje.md"
  [ -n "$(git --git-dir="$T/app.git" branch --list adopt/adaptacja)" ]
  grep -q 'label create' "$T/gh.calls"
  grep -q -- '--log-opts=origin/main..HEAD' "$T/gitleaks.calls"
  # Druga adaptacja przy otwartym PR niczego nie robi.
  echo "https://github.com/acme/app/pull/7" >"$T/pr-otwarty"
  run --separate-stderr "$SHCTL" adopt adaptacja --projekt app --json
  [ "$status" -eq 0 ]
  jq -e '.wynik.nowy == false' <<<"$output"
}

@test "bramka: czysto daje ok; sekret w historii, tabela bez RLS i dane osobowe blokuja (kod 4)" {
  analiza_na_main
  run --separate-stderr "$SHCTL" adopt bramka --projekt app --json
  [ "$status" -eq 0 ] || { echo "$output"; false; }
  jq -e '.wynik.wynik == "ok" and .wynik.gitleaks.znaleziska == 0' <<<"$output"
  grep -q -- '--report-path' "$T/gitleaks.calls"
  ! grep -q -- '--log-opts' "$T/gitleaks.calls" || false

  touch "$T/gitleaks-sekret"
  P="$SH_DIR/projekty/app"
  printf 'create table public.profile (id uuid);\n' >"$P/supabase/migrations/20250102_profile.sql"
  printf "insert into profile values ('jan.kowalski@gmail.com');\n" >"$P/supabase/seed.sql"
  git -C "$P" add -A
  git -C "$P" commit -qm zmiany
  run --separate-stderr "$SHCTL" adopt bramka --projekt app --json
  [ "$status" -eq 4 ]
  jq -e '.ok == false and .wynik.wynik == "blokada"' <<<"$output"
  jq -e '.wynik.gitleaks.znaleziska == 1 and (.wynik.gitleaks.zalecenie | test("unieważnij"))' <<<"$output"
  jq -e '.wynik.rls.bez_rls == ["profile"] and (.wynik.dane_osobowe | length) == 1' <<<"$output"
  [[ "$output" != *"jan.kowalski"* ]]
}

@test "upublicznij: tylko z decyzja wlasciciela i po bramce; zmienia widocznosc przez gh repo edit" {
  analiza_na_main
  run "$SHCTL" adopt upublicznij --projekt app
  [ "$status" -eq 4 ]
  [[ "$output" == *"brak zgody właściciela"* ]]
  ! grep -q 'repo edit' "$T/gh.calls" || false

  P="$SH_DIR/projekty/app"
  printf '| 2026-11-12 | wlasciciel | Upublicznienie repo acme/app | zgoda. Cofnięcie: repo prywatne |\n' >>"$P/docs/decyzje.md"
  touch "$T/gitleaks-sekret"
  run "$SHCTL" adopt upublicznij --projekt app
  [ "$status" -eq 4 ]
  [[ "$output" == *"bramka"* ]]
  ! grep -q 'repo edit' "$T/gh.calls" || false

  rm "$T/gitleaks-sekret"
  run --separate-stderr "$SHCTL" adopt upublicznij --projekt app --json
  [ "$status" -eq 0 ] || { echo "$output"; false; }
  grep -q 'repo edit acme/app --visibility public --accept-visibility-change-consequences' "$T/gh.calls"
  [ "$(fm "$P/docs/konfiguracja.md" adopt.widocznosc)" = public ]
  run --separate-stderr "$SHCTL" adopt upublicznij --projekt app --json
  jq -e '.wynik.zmiana == false' <<<"$output"
}

@test "obsidian link projektu przejetego klonuje repo z originu, nie SH_GH_OWNER/NAZWA" {
  analiza_na_main
  rm -rf "$SH_OBSIDIAN_DIR/app"
  run "$SHCTL" obsidian link app
  [ "$status" -eq 0 ] || { echo "$output"; false; }
  [ "$(git -C "$SH_OBSIDIAN_DIR/app" config --get remote.origin.url)" = https://github.com/acme/app.git ]
  [ -f "$SH_OBSIDIAN_DIR/app/docs/00-analiza/raport.md" ]
}
