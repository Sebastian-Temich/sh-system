#!/usr/bin/env bash
# scripts/adopt/wykryj.sh KATALOG - fakty o przejmowanym repo (shctl adopt, sh-intake w trybie adopt).
# Tylko odczyt plików i historii git, bez sieci. Na stdout jeden dokument JSON. Wartości kluczy,
# adresów e-mail i numerów nigdy nie trafiają na wyjście: tylko plik, linia i rodzaj.
#
# Pola: lovable (pliki, synchronizacja z GitHubem z autorów commitów), supabase (config.toml,
# migracje, edge functions, seed, klienci: klucz w kodzie czy w env), klucze (JWT Supabase z rolą
# anon/service_role i klucze sb_publishable_/sb_secret_), env_w_repo (śledzone pliki .env),
# zmienne (nazwy z .env.example i kodu), rls (tabele public bez enable row level security w
# migracjach), dane_osobowe (e-mail, telefon, PESEL, IBAN w seedach i fixture'ach), pakiety, ci,
# testy, alarmy (lista 🔴 do raportu i bramki).
set -euo pipefail

K="${1:-}"
[ -n "$K" ] && [ -d "$K" ] || { echo "użycie: wykryj.sh KATALOG" >&2; exit 2; }
command -v jq >/dev/null || { echo "BŁĄD: brak jq" >&2; exit 3; }
cd "$K"

T="$(mktemp -d "${TMPDIR:-/tmp}/wykryj.XXXXXX")"
trap 'rm -rf "$T"' EXIT

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT=1
  git ls-files >"$T/pliki"
else
  GIT=0
  find . -type f -not -path './node_modules/*' -not -path './.git/*' | sed 's#^\./##' | sort >"$T/pliki"
fi
# Pliki tekstowe do przeszukania: bez zależności, locków, buildów i binariów.
grep -vE '(^|/)(node_modules|dist|build|\.next|coverage|vendor)/|(^|/)(pnpm-lock\.yaml|package-lock\.json|yarn\.lock|bun\.lockb?)$|\.(png|jpe?g|gif|webp|ico|svg|pdf|woff2?|ttf|otf|eot|mp4|mp3|zip|gz|tgz)$' \
  "$T/pliki" >"$T/tekst" || true

# Linie pasujące do wzorca: plik<TAB>nr<TAB>treść (grep -I pomija binaria).
szukaj() {
  local wzorzec="$1" lista="${2:-$T/tekst}" p
  while IFS= read -r p; do
    [ -f "$p" ] || continue
    grep -InE -- "$wzorzec" "$p" 2>/dev/null | awk -v p="$p" '{ i = index($0, ":"); printf "%s\t%s\t%s\n", p, substr($0, 1, i - 1), substr($0, i + 1) }' || true
  done <"$lista"
}

# Tablica JSON z wierszy „pole1<TAB>pole2…” i nazw pól.
tsv_json() {
  jq -Rsc --arg pola "$1" '($pola | split(",")) as $n | split("\n") | map(select(length > 0) | split("\t")
    | . as $w | reduce range(0; $n | length) as $i ({}; .[$n[$i]] = ($w[$i] // "")))' "$2"
}
lista_json() { jq -Rsc 'split("\n") | map(select(length > 0)) | unique' "$1"; }

b64url() {
  local s
  s="$(printf '%s' "$1" | tr '_-' '/+')"
  case $((${#s} % 4)) in 2) s="$s==" ;; 3) s="$s=" ;; esac
  printf '%s' "$s" | base64 --decode 2>/dev/null || true
}

# --- Lovable -------------------------------------------------------------------------------------
: >"$T/lovable"
grep -E '(^|/)\.lovable(/|$)' "$T/pliki" | sed 's/$/\tkatalog .lovable/' >>"$T/lovable" || true
for p in package.json vite.config.ts vite.config.js vite.config.mts vite.config.mjs; do
  [ -f "$p" ] && grep -q 'lovable-tagger' "$p" && printf '%s\tlovable-tagger\n' "$p" >>"$T/lovable" || true
done
for p in README.md readme.md index.html; do
  [ -f "$p" ] && grep -qi 'lovable\.dev\|lovable\.app' "$p" && printf '%s\todnośnik lovable.dev\n' "$p" >>"$T/lovable" || true
done
SYNC_N=0
SYNC_OST=""
if [ "$GIT" -eq 1 ]; then
  git log --format='%an %ae%x09%cI' 2>/dev/null | grep -iE 'lovable|gpt-engineer' | cut -f2 >"$T/sync" || true
  SYNC_N="$(wc -l <"$T/sync" | tr -d ' ')"
  SYNC_OST="$(head -1 "$T/sync")"
fi

# --- Supabase ------------------------------------------------------------------------------------
grep -E '^supabase/migrations/[^/]+\.sql$' "$T/pliki" | sort >"$T/migracje" || true
grep -E '^supabase/functions/[^/_][^/]*/' "$T/pliki" | cut -d/ -f3 | sort -u >"$T/funkcje" || true
grep -E '^supabase/seed[^/]*\.sql$|^supabase/seeds?/' "$T/pliki" >"$T/seed" || true

# Klienci Supabase: pliki z createClient; klucz w kodzie (literał JWT, sb_ albo adres *.supabase.co)
# czy ze zmiennych środowiska.
: >"$T/klienci"
szukaj 'createClient[[:space:]]*(<[^>]*>)?[[:space:]]*\(' | cut -f1 | sort -u >"$T/pliki-klient" || true
while IFS= read -r p; do
  [ -n "$p" ] || continue
  if grep -qE 'eyJ[A-Za-z0-9_-]{8,}\.eyJ|sb_(publishable|secret)_|https://[a-z0-9]+\.supabase\.co' "$p"; then z=kod
  elif grep -qE 'import\.meta\.env|process\.env|Deno\.env' "$p"; then z=env
  else z=nieustalone; fi
  printf '%s\t%s\n' "$p" "$z" >>"$T/klienci"
done <"$T/pliki-klient"

# Klucze: JWT z claimem role (anon, service_role) i klucze nowego typu. Bez wartości na wyjściu.
: >"$T/klucze"
szukaj 'eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+|sb_(publishable|secret)_[A-Za-z0-9_-]{8,}' >"$T/kandydaci" || true
while IFS="$(printf '\t')" read -r p n tresc; do
  for jwt in $(printf '%s' "$tresc" | grep -oE 'eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+' || true); do
    rola="$(b64url "$(printf '%s' "$jwt" | cut -d. -f2)" | jq -r '.role // "nieznana"' 2>/dev/null || echo nieznana)"
    printf '%s\t%s\tjwt\t%s\n' "$p" "$n" "$rola" >>"$T/klucze"
  done
  printf '%s' "$tresc" | grep -qE 'sb_secret_[A-Za-z0-9_-]{8,}' && printf '%s\t%s\tsb_secret\tservice_role\n' "$p" "$n" >>"$T/klucze" || true
  printf '%s' "$tresc" | grep -qE 'sb_publishable_[A-Za-z0-9_-]{8,}' && printf '%s\t%s\tsb_publishable\tanon\n' "$p" "$n" >>"$T/klucze" || true
done <"$T/kandydaci"

# --- Pliki .env w repo i nazwy zmiennych --------------------------------------------------------
grep -E '(^|/)\.env(\.[^/]*)?$' "$T/pliki" | grep -vE '\.(example|sample|template|dist)$' >"$T/env" || true
: >"$T/zmienne"
grep -E '(^|/)\.env\.(example|sample|template|dist)$' "$T/pliki" | while IFS= read -r p; do
  [ -f "$p" ] && grep -oE '^[[:space:]]*(export[[:space:]]+)?[A-Z][A-Z0-9_]*=' "$p" | sed -E 's/^[[:space:]]*(export[[:space:]]+)?//; s/=$//'
done >>"$T/zmienne" || true
szukaj 'import\.meta\.env\.[A-Z]|process\.env\.[A-Z]|process\.env\[|Deno\.env\.get' | cut -f3 |
  grep -oE 'import\.meta\.env\.[A-Z][A-Z0-9_]*|process\.env\.[A-Z][A-Z0-9_]*|process\.env\[["'"'"'][A-Z][A-Z0-9_]*|Deno\.env\.get\(["'"'"'][A-Z][A-Z0-9_]*' |
  grep -oE '[A-Z][A-Z0-9_]*$' >>"$T/zmienne" || true

# --- RLS w migracjach (heurystyka: tabele public bez enable row level security) -----------------
: >"$T/tabele"
: >"$T/rls"
while IFS= read -r p; do
  [ -f "$p" ] || continue
  tr 'A-Z\n' 'a-z ' <"$p" | tr -d '"' >"$T/sql"
  grep -oE 'create[[:space:]]+table[[:space:]]+(if[[:space:]]+not[[:space:]]+exists[[:space:]]+)?([a-z0-9_]+\.)?[a-z0-9_]+' "$T/sql" |
    awk '{ print $NF }' | awk -F. 'NF == 1 || $1 == "public" { print $NF }' >>"$T/tabele" || true
  grep -oE 'alter[[:space:]]+table[[:space:]]+(if[[:space:]]+exists[[:space:]]+)?(only[[:space:]]+)?([a-z0-9_]+\.)?[a-z0-9_]+[[:space:]]+enable[[:space:]]+row[[:space:]]+level[[:space:]]+security' "$T/sql" |
    awk '{ print $(NF - 4) }' | awk -F. '{ print $NF }' >>"$T/rls" || true
done <"$T/migracje"
sort -u "$T/tabele" -o "$T/tabele"
sort -u "$T/rls" -o "$T/rls"
comm -23 "$T/tabele" "$T/rls" >"$T/bez-rls" || true

# --- Dane osobowe w seedach i fixture'ach ------------------------------------------------------
grep -E '(^|/)seeds?[^/]*\.(sql|json|csv|ts|js|ya?ml)$|^supabase/seeds?/|(^|/)(fixtures?|__fixtures__|mocks?|__mocks__|seeds?)/' "$T/tekst" >"$T/seedy" || true
: >"$T/pii"
szukaj '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$T/seedy" | while IFS="$(printf '\t')" read -r p n tresc; do
  # Adresy w domenach testowych (RFC 2606) i bez TLD nie są danymi osobowymi.
  printf '%s' "$tresc" | grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' |
    grep -viqE '@([a-z0-9-]+\.)*(example\.(com|org|net)|test|invalid|localhost|example)$' &&
    printf '%s\t%s\te-mail\n' "$p" "$n"
done >>"$T/pii" || true
szukaj '(\+48[ -]?)?[0-9]{3}[ -][0-9]{3}[ -][0-9]{3}' "$T/seedy" | awk -F'\t' '{ print $1 "\t" $2 "\ttelefon" }' >>"$T/pii" || true
szukaj '(^|[^0-9])[0-9]{11}([^0-9]|$)' "$T/seedy" | awk -F'\t' '{ print $1 "\t" $2 "\tPESEL (11 cyfr)" }' >>"$T/pii" || true
szukaj 'PL[0-9]{26}|PL[0-9]{2}( ?[0-9]{4}){6}' "$T/seedy" | awk -F'\t' '{ print $1 "\t" $2 "\tIBAN" }' >>"$T/pii" || true

# --- Pakiety, CI, testy ---------------------------------------------------------------------------
menedzer=brak
[ ! -f package-lock.json ] || menedzer=npm
[ ! -f yarn.lock ] || menedzer=yarn
[ ! -f bun.lockb ] && [ ! -f bun.lock ] || menedzer=bun
[ ! -f pnpm-lock.yaml ] || menedzer=pnpm
if [ -f package.json ]; then
  jq -c '{nazwa:(.name // null), skrypty:((.scripts // {}) | keys),
    zaleznosci:((.dependencies // {}) | length), dev:((.devDependencies // {}) | length),
    frameworki:([(.dependencies // {}) + (.devDependencies // {}) | keys[]
      | select(IN("react","vue","svelte","next","vite","astro","@supabase/supabase-js","vitest","jest","@playwright/test","tailwindcss","typescript"))])}' \
    package.json >"$T/pkg" 2>/dev/null || echo '{"blad":"package.json nieczytelny"}' >"$T/pkg"
else
  echo null >"$T/pkg"
fi
grep -E '^\.github/workflows/[^/]+\.ya?ml$' "$T/pliki" >"$T/ci" || true
grep -E '(^|/)(vitest|jest|playwright)\.config\.[a-z]+$|(^|/)[^/]+\.(test|spec)\.[jt]sx?$|^supabase/tests/' "$T/pliki" >"$T/testy" || true

# --- Alarmy 🔴 ----------------------------------------------------------------------------------
: >"$T/alarmy"
awk -F'\t' '$4 == "service_role" { print "🔴 klucz service_role w repo: " $1 ":" $2 " (unieważnij u dostawcy)" }' "$T/klucze" >>"$T/alarmy"
awk '{ print "🔴 plik env śledzony w repo: " $0 }' "$T/env" >>"$T/alarmy"
awk '{ print "🔴 tabela public bez RLS w migracjach: " $0 }' "$T/bez-rls" >>"$T/alarmy"
awk -F'\t' '{ print "🔴 możliwe dane osobowe (" $3 "): " $1 ":" $2 }' "$T/pii" >>"$T/alarmy"

jq -n \
  --argjson lovable_pliki "$(tsv_json plik,sygnal "$T/lovable")" \
  --argjson sync_n "$SYNC_N" --arg sync_ost "$SYNC_OST" \
  --argjson config "$([ -f supabase/config.toml ] && echo true || echo false)" \
  --argjson migracje "$(lista_json "$T/migracje")" \
  --argjson funkcje "$(lista_json "$T/funkcje")" \
  --argjson seed "$(lista_json "$T/seed")" \
  --argjson klienci "$(tsv_json plik,klucz_z "$T/klienci")" \
  --argjson klucze "$(tsv_json plik,linia,rodzaj,rola "$T/klucze")" \
  --argjson env "$(lista_json "$T/env")" \
  --argjson zmienne "$(lista_json "$T/zmienne")" \
  --argjson tabele "$(lista_json "$T/tabele")" \
  --argjson bez_rls "$(lista_json "$T/bez-rls")" \
  --argjson pii "$(tsv_json plik,linia,rodzaj "$T/pii")" \
  --arg menedzer "$menedzer" --argjson pkg "$(cat "$T/pkg")" \
  --argjson ci "$(lista_json "$T/ci")" --argjson testy "$(lista_json "$T/testy")" \
  --argjson alarmy "$(jq -Rsc 'split("\n") | map(select(length > 0))' "$T/alarmy")" '
  {lovable: {wykryto: (($lovable_pliki | length) > 0 or $sync_n > 0), pliki: $lovable_pliki,
     synchronizacja: {commity: $sync_n, ostatni: (if $sync_ost == "" then null else $sync_ost end),
       aktywna: ($sync_n > 0)}},
   supabase: {wykryto: ($config or ($migracje | length) > 0 or ($funkcje | length) > 0 or ($klienci | length) > 0),
     config_toml: $config, migracje: {liczba: ($migracje | length), pierwsza: ($migracje | first),
       ostatnia: ($migracje | last)}, funkcje: $funkcje, seed: $seed, klienci: $klienci},
   klucze: $klucze, env_w_repo: $env, zmienne: $zmienne,
   rls: {tabele: $tabele, bez_rls: $bez_rls}, dane_osobowe: $pii,
   pakiety: {menedzer: $menedzer, package_json: $pkg}, ci: $ci, testy: $testy, alarmy: $alarmy}'
