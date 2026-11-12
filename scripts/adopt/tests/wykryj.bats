#!/usr/bin/env bats
# Detektor przejmowanego repo: Lovable, Supabase, klucze (bez wartości), env, RLS, dane osobowe.

setup() {
  W="$BATS_TEST_DIRNAME/../wykryj.sh"
  R="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$R"
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig"
  git config --global user.name test
  git config --global user.email test@example.com
  git init -q -b main "$R"
}

jwt() {
  local p
  p="$(printf '{"iss":"supabase","ref":"abcdefghij","role":"%s"}' "$1" | base64 | tr '+/' '-_' | tr -d '=\n')"
  printf 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.%s.c2lnbmF0dXJhLXRlc3Rvd2E' "$p"
}

commit() { git -C "$R" add -A; git -C "$R" commit -qm "${1:-start}" ${2:+--author="$2"}; }

repo_lovable() {
  mkdir -p "$R/src/integrations/supabase" "$R/supabase/migrations" "$R/supabase/functions/wyslij" "$R/supabase/functions/_shared"
  printf '{"name":"app","scripts":{"dev":"vite","build":"vite build"},"dependencies":{"react":"18","@supabase/supabase-js":"2"},"devDependencies":{"lovable-tagger":"1","vite":"5"}}\n' >"$R/package.json"
  printf 'lockfileVersion: 9\n' >"$R/pnpm-lock.yaml"
  printf '# App\n\nhttps://lovable.dev/projects/123\n' >"$R/README.md"
  printf 'import { createClient } from "@supabase/supabase-js";\nconst SUPABASE_URL = "https://abcdefghij.supabase.co";\nconst SUPABASE_PUBLISHABLE_KEY = "%s";\nexport const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);\n' "$(jwt anon)" \
    >"$R/src/integrations/supabase/client.ts"
  printf 'project_id = "abcdefghij"\n' >"$R/supabase/config.toml"
  printf 'create table public.notatki (id uuid primary key);\nalter table public.notatki\n  enable row level security;\ncreate table "Profile" (id uuid);\n' \
    >"$R/supabase/migrations/20250101000000_start.sql"
  printf 'const k = Deno.env.get("RESEND_API_KEY");\n' >"$R/supabase/functions/wyslij/index.ts"
  printf 'export const x = 1;\n' >"$R/supabase/functions/_shared/x.ts"
  printf "insert into profile values ('jan.kowalski@gmail.com', '600 700 800');\ninsert into profile values ('test@example.com');\n" >"$R/supabase/seed.sql"
  printf 'VITE_SUPABASE_URL=\nVITE_SUPABASE_ANON_KEY=\n' >"$R/.env.example"
  printf 'const u = import.meta.env.VITE_SENTRY_DSN;\n' >"$R/src/main.ts"
}

@test "Lovable i Supabase: pliki, synchronizacja, klient z kluczem anon w kodzie, migracje, funkcje, seed" {
  repo_lovable
  commit start "gpt-engineer-app[bot] <159125892+gpt-engineer-app[bot]@users.noreply.github.com>"
  run bash "$W" "$R"
  [ "$status" -eq 0 ]
  jq -e '.lovable.wykryto and .lovable.synchronizacja.aktywna and .lovable.synchronizacja.commity == 1' <<<"$output"
  jq -e '[.lovable.pliki[].plik] | index("package.json") and index("README.md")' <<<"$output"
  jq -e '.supabase.config_toml and .supabase.migracje.liczba == 1 and .supabase.funkcje == ["wyslij"] and .supabase.seed == ["supabase/seed.sql"]' <<<"$output"
  jq -e '.supabase.klienci == [{"plik":"src/integrations/supabase/client.ts","klucz_z":"kod"}]' <<<"$output"
  jq -e '.klucze == [{"plik":"src/integrations/supabase/client.ts","linia":"3","rodzaj":"jwt","rola":"anon"}]' <<<"$output"
  jq -e '.pakiety.menedzer == "pnpm" and (.pakiety.package_json.frameworki | index("react"))' <<<"$output"
  # Nazwy zmiennych z .env.example i kodu (frontend i edge functions), bez wartości.
  jq -e '.zmienne == ["RESEND_API_KEY","VITE_SENTRY_DSN","VITE_SUPABASE_ANON_KEY","VITE_SUPABASE_URL"]' <<<"$output"
  # Wartość klucza nie trafia na wyjście.
  [[ "$output" != *"$(jwt anon)"* ]]
}

@test "alarmy: service_role w repo, plik .env w repo, tabela bez RLS, dane osobowe w seedzie" {
  repo_lovable
  printf 'SUPABASE_SERVICE_ROLE_KEY=%s\n' "$(jwt service_role)" >"$R/.env"
  commit
  run bash "$W" "$R"
  [ "$status" -eq 0 ]
  jq -e '.klucze | any(.rola == "service_role" and .plik == ".env")' <<<"$output"
  jq -e '.env_w_repo == [".env"]' <<<"$output"
  jq -e '.rls.tabele == ["notatki","profile"] and .rls.bez_rls == ["profile"]' <<<"$output"
  jq -e '[.dane_osobowe[] | .rodzaj] | index("e-mail") and index("telefon")' <<<"$output"
  jq -e '[.dane_osobowe[] | select(.rodzaj == "e-mail")] | length == 1' <<<"$output"
  jq -e '.alarmy | any(startswith("🔴 klucz service_role")) and any(startswith("🔴 plik env")) and any(test("bez RLS.*: profile"))' <<<"$output" ||
    { jq -c .alarmy <<<"$output"; false; }
  [[ "$output" != *"$(jwt service_role)"* ]]
  [[ "$output" != *"jan.kowalski"* ]]
}

@test "klucze nowego typu: sb_secret to service_role, sb_publishable to anon; klient z env" {
  mkdir -p "$R/src"
  printf 'const a = "sb_publishable_abcdefghijkl";\nconst b = "sb_secret_abcdefghijklmnop";\n' >"$R/src/klucze.ts"
  printf 'import { createClient } from "@supabase/supabase-js";\nexport const s = createClient(import.meta.env.VITE_SUPABASE_URL, import.meta.env.VITE_SUPABASE_ANON_KEY);\n' >"$R/src/db.ts"
  commit
  run bash "$W" "$R"
  [ "$status" -eq 0 ]
  jq -e '[.klucze[] | .rola] == ["anon","service_role"] or [.klucze[] | .rola] == ["service_role","anon"]' <<<"$output"
  jq -e '.supabase.klienci == [{"plik":"src/db.ts","klucz_z":"env"}]' <<<"$output"
  jq -e '.lovable.wykryto == false' <<<"$output"
  [[ "$output" != *"sb_secret_abcdef"* ]]
}

@test "repo bez Supabase i Lovable: puste listy, bez alarmow" {
  printf '# x\n' >"$R/README.md"
  commit
  run bash "$W" "$R"
  [ "$status" -eq 0 ]
  jq -e '.supabase.wykryto == false and .lovable.wykryto == false and .alarmy == [] and .pakiety.package_json == null' <<<"$output"
}

@test "bez argumentu: kod 2" {
  run bash "$W"
  [ "$status" -eq 2 ]
}
