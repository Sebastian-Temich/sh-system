#!/usr/bin/env bats
# shctl db: lokalny Supabase projektu na atrapach supabase i docker (bez Dockera i sieci).
load helper

setup() {
  wspolny_setup
  projekt_demo
  mkdir -p supabase/migrations supabase/.temp
  printf 'project_id = "oryginalny"\n\n[api]\nport = 54321\n\n[db]\nport = 54322\n' >supabase/config.toml
  printf 'create table public.a (id int);\n' >supabase/migrations/20260101000000_a.sql
  printf 'insert into public.a values (1);\n' >supabase/seed.sql
  printf 'SEKRET=1\n' >supabase/.env
  printf 'v2\n' >supabase/.temp/cli-latest
  git add -A
  git commit -qm supabase
  sed -i.bak 's/^| 1 | \*wolny\* |.*/| 1 | demo | `x` | 55121 | 55122 | 55123 | 55124 | 55127 | 55128 | 55129 | 55125 | zarezerwowany |\n| 2 | inny | `y` | 55221 | 55222 | 55223 | 55224 | 55227 | 55228 | 55229 | 55225 | zarezerwowany |/' "$SH_DIR/porty.md"
  : >"$T/supabase.calls"
  cat >"$T/mock/supabase" <<MOCK
#!/bin/bash
echo "\$*" >>"$T/supabase.calls"
env | grep '^SUPABASE_' >>"$T/supabase.env" || true
wd=""; prev=""
for a in "\$@"; do [ "\$prev" = --workdir ] && wd="\$a"; prev="\$a"; done
case "\$1 \$2" in
  "status -o")
    [ -f "$T/db-dziala" ] || { echo "failed to inspect container health" >&2; exit 1; }
    api="\$(cat "$T/db-api" 2>/dev/null || echo http://127.0.0.1:55121)"
    printf '{\n  "API_URL": "%s",\n  "DB_URL": "postgresql://postgres:postgres@127.0.0.1:55122/postgres",\n  "STUDIO_URL": "http://127.0.0.1:55123",\n  "MAILPIT_URL": "http://127.0.0.1:55124",\n  "ANON_KEY": "anon-lokalny",\n  "SERVICE_ROLE_KEY": "service-lokalny"\n}\n' "\$api"
    ;;
  "start --workdir")
    [ ! -f "$T/start-fail" ] || exit 1
    cp "\$wd/supabase/config.toml" "$T/config.kopia"
    ls -A "\$wd/supabase" >"$T/kopia.ls"
    readlink "\$wd/supabase/migrations" >"$T/kopia.migracje"
    touch "$T/db-dziala" ;;
  "stop --workdir") rm -f "$T/db-dziala" ;;
  "db reset") [ ! -f "$T/reset-fail" ] ;;
  "test db") [ ! -f "$T/pgtap-fail" ] ;;
esac
MOCK
  cat >"$T/mock/docker" <<MOCK
#!/bin/sh
case "\$1" in
  info) [ ! -f "$T/docker-stoi" ] ;;
  ps) cat "$T/docker-ps" 2>/dev/null; exit 0 ;;
esac
MOCK
  chmod +x "$T/mock/supabase" "$T/mock/docker"
  export SUPABASE_ACCESS_TOKEN=sbp_chmura SUPABASE_DB_PASSWORD=haslo
}

@test "start: kopia robocza z portami bloku i project_id, repo bez zmian, bez poswiadczen chmury" {
  run --separate-stderr "$SHCTL" db start --projekt demo --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  grep -qx "start --workdir $SH_DIR/stan/db/demo" "$T/supabase.calls"
  grep -qx 'project_id = "demo"' "$T/config.kopia"
  grep -qx 'port = 55121' "$T/config.kopia"
  grep -qx 'port = 55122' "$T/config.kopia"
  grep -qx 'shadow_port = 55128' "$T/config.kopia"
  grep -qx 'inspector_port = 55125' "$T/config.kopia"
  awk '/^\[analytics\]/{w=1;next} /^\[/{w=0} w' "$T/config.kopia" | grep -qx 'enabled = false'
  [ "$(cat "$T/kopia.migracje")" = "$P/supabase/migrations" ]
  ! grep -qE '^\.env|^\.temp' "$T/kopia.ls" || false
  grep -qx 'seed.sql' "$T/kopia.ls"
  [ -z "$(git -C "$P" status --porcelain)" ]
  grep -q 'project_id = "oryginalny"' "$P/supabase/config.toml"
  [ ! -s "$T/supabase.env" ]
  [ "$(jq -r .wynik.status.api <<<"$output")" = http://127.0.0.1:55121 ]
  [ "$(jq -r .wynik.status.anon_key <<<"$output")" = anon-lokalny ]
  [ "$(jq -r .wynik.porty <<<"$output")" = 55121-55129 ]
  [ "$(jq -r .wynik.zrodlo <<<"$output")" = "$P" ]
}

@test "start: dzialajacy stack zostaje, bez drugiego supabase start; status w tekscie" {
  touch "$T/db-dziala"
  run --separate-stderr "$SHCTL" db start --projekt demo
  [ "$status" -eq 0 ]
  ! grep -q '^start' "$T/supabase.calls" || false
  [[ "$output" == *"już działa"* ]] || false
  [[ "$output" == *"API: http://127.0.0.1:55121"* ]] || false
  [[ "$output" == *"Klucz service_role (lokalny): service-lokalny"* ]] || false
}

@test "odmowa: supabase/ powiazany z chmura (project-ref)" {
  printf 'abcdefghijklmnop\n' >"$P/supabase/.temp/project-ref"
  run --separate-stderr "$SHCTL" db start --projekt demo
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"powiązany z projektem w chmurze"* ]] || false
  [ ! -s "$T/supabase.calls" ]
}

@test "brak: config.toml, blok portow, Docker" {
  sed -i.bak '/^| 1 | demo/d' "$SH_DIR/porty.md"
  run --separate-stderr "$SHCTL" db status --projekt demo
  [ "$status" -eq 3 ]
  [[ "$stderr" == *"nie ma bloku portów"* ]] || false
  mv "$SH_DIR/porty.md.bak" "$SH_DIR/porty.md"
  touch "$T/docker-stoi"
  run --separate-stderr "$SHCTL" db status --projekt demo
  [ "$status" -eq 3 ]
  [[ "$stderr" == *"Docker nie działa"* ]] || false
  rm "$P/supabase/config.toml"
  run --separate-stderr "$SHCTL" db status --projekt demo
  [ "$status" -eq 3 ]
  [[ "$stderr" == *"nie ma lokalnego Supabase"* ]] || false
}

@test "reset, migrate, test: odmowa przy zatrzymanym stacku, potem zawsze --local" {
  for a in reset migrate test; do
    run --separate-stderr "$SHCTL" db "$a" --projekt demo
    [ "$status" -eq 4 ] || { echo "$a: $status"; false; }
    [[ "$stderr" == *"shctl db start --projekt demo"* ]] || false
  done
  touch "$T/db-dziala"
  mkdir -p "$P/supabase/tests"
  run --separate-stderr "$SHCTL" db reset --projekt demo
  [ "$status" -eq 0 ]
  run --separate-stderr "$SHCTL" db migrate --projekt demo
  [ "$status" -eq 0 ]
  run --separate-stderr "$SHCTL" db test --projekt demo --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.testy <<<"$output")" = true ]
  grep -qx "db reset --local --workdir $SH_DIR/stan/db/demo" "$T/supabase.calls"
  grep -qx "migration up --local --workdir $SH_DIR/stan/db/demo" "$T/supabase.calls"
  grep -qx "test db --local --workdir $SH_DIR/stan/db/demo" "$T/supabase.calls"
  ! grep -qE -- '--linked|--db-url|--project-ref' "$T/supabase.calls" || false
}

@test "test: bez supabase/tests uwaga i kod 0; czerwone pgTAP kod 1; reset nieudany kod 1" {
  touch "$T/db-dziala"
  run --separate-stderr "$SHCTL" db test --projekt demo --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.testy <<<"$output")" = false ]
  [[ "$stderr" == *"nie ma testów pgTAP"* ]] || false
  mkdir -p "$P/supabase/tests"
  touch "$T/pgtap-fail"
  run --separate-stderr "$SHCTL" db test --projekt demo
  [ "$status" -eq 1 ]
  touch "$T/reset-fail"
  run --separate-stderr "$SHCTL" db reset --projekt demo
  [ "$status" -eq 1 ]
}

@test "status: zatrzymany stack to dziala:false; adres API spoza bloku to odmowa" {
  run --separate-stderr "$SHCTL" db status --projekt demo --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.dziala <<<"$output")" = false ]
  touch "$T/db-dziala"
  echo https://abcd.supabase.co >"$T/db-api"
  run --separate-stderr "$SHCTL" db status --projekt demo --json
  [ "$status" -eq 4 ]
  [ "$(jq -r .ok <<<"$output")" = false ]
}

@test "start: odmowa, gdy dziala stack innego projektu SH albo port bloku jest zajety" {
  printf 'inny\nsupabase-local\n' >"$T/docker-ps"
  run --separate-stderr "$SHCTL" db start --projekt demo
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"innego projektu SH: inny"* ]] || false
  printf 'supabase-local\n' >"$T/docker-ps"
  printf '#!/bin/sh\ncase "$*" in *55122*) exit 0 ;; esac\nexit 1\n' >"$T/mock/lsof"
  run --separate-stderr "$SHCTL" db start --projekt demo
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"port 55122"* ]] || false
  ! grep -q '^start' "$T/supabase.calls" || false
}

@test "zrodlo: worktree projektu, z ktorego wywolano komende" {
  git -C "$P" worktree add -q -b task/5-x "$SH_DIR/wt/demo/5" main
  printf 'create table public.b (id int);\n' >"$SH_DIR/wt/demo/5/supabase/migrations/20260102000000_b.sql"
  cd "$SH_DIR/wt/demo/5"
  run --separate-stderr "$SHCTL" db start --projekt demo --json
  [ "$status" -eq 0 ]
  wt="$(cd -P "$SH_DIR/wt/demo/5" && pwd)"
  [ "$(jq -r .wynik.zrodlo <<<"$output")" = "$wt" ]
  [ "$(cat "$T/kopia.migracje")" = "$wt/supabase/migrations" ]
  # Inny katalog (nie projekt demo): główna kopia.
  cd "$T"
  run --separate-stderr "$SHCTL" db status --projekt demo --json
  [ "$(jq -r .wynik.zrodlo <<<"$output")" = "$P" ]
}

@test "--dry-run: komenda bez wywolan supabase i bez kopii roboczej" {
  run --separate-stderr "$SHCTL" db reset --projekt demo --dry-run --json
  [ "$status" -eq 0 ]
  [ "$(jq -r .wynik.komenda <<<"$output")" = "supabase db reset --local --workdir $SH_DIR/stan/db/demo" ]
  [ ! -s "$T/supabase.calls" ]
  [ ! -e "$SH_DIR/stan/db/demo" ]
}

@test "blokada: druga komenda db tego projektu to odmowa; stop zwalnia stack" {
  mkdir -p "$SH_DIR/stan/db-demo.lock"
  run --separate-stderr "$SHCTL" db start --projekt demo
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"trwa inna komenda shctl db"* ]] || false
  rmdir "$SH_DIR/stan/db-demo.lock"
  touch "$T/db-dziala"
  run --separate-stderr "$SHCTL" db stop --projekt demo --json
  [ "$status" -eq 0 ]
  [ ! -e "$T/db-dziala" ]
  [ "$(jq -r .wynik.dziala <<<"$output")" = false ]
  [ ! -e "$SH_DIR/stan/db-demo.lock" ]
}

@test "bledy uzycia" {
  run --separate-stderr "$SHCTL" db
  [ "$status" -eq 2 ]
  run --separate-stderr "$SHCTL" db push --projekt demo
  [ "$status" -eq 2 ]
  run --separate-stderr "$SHCTL" db start --linked
  [ "$status" -eq 2 ]
}
