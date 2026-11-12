# shctl db start|stop|reset|migrate|test|status [--projekt NAZWA]: lokalny Supabase (Docker) projektu.
# Supabase CLI w sandboxie kończy się EPERM (~/.supabase), a shctl działa poza nim (wyjątek sandboxa jak
# git push), więc worker sprawdza migracje i pgTAP na żywej bazie tą komendą; CI zostaje drugim
# sprawdzeniem. Tylko baza lokalna:
# - CLI dostaje kopię roboczą $SH_DIR/stan/db/NAZWA/supabase: config.toml z portami bloku projektu w
#   porty.md, project_id = NAZWA i bez analytics, reszta katalogu supabase/ jako dowiązania, bez .temp (powiązanie z
#   chmurą) i plików .env; pliki repo zostają nietknięte;
# - odmowa, gdy supabase/ jest powiązany z projektem w chmurze (supabase/.temp/project-ref), gdy projekt
#   nie ma bloku w porty.md, albo gdy adres API nie jest lokalny;
# - CLI działa w czystym środowisku (env -i, bez SUPABASE_ACCESS_TOKEN i innych zmiennych) i zawsze z
#   --local, nigdy z --linked ani --db-url.
# Źródło migracji: worktree projektu, z którego wywołano komendę (np. wt/NAZWA/NR), inaczej główna kopia.
# shellcheck shell=bash

# shellcheck source=../lib/porty.sh
. "$SHCTL_DIR/lib/porty.sh"

DB_ZRODLO=""
DB_KAT=""
DB_BAZA=""
DB_LIMIT="${SHCTL_DB_TIMEOUT:-900}"

# Katalog z supabase/: worktree tego projektu z bieżącego katalogu albo główna kopia.
db_zrodlo() {
  local top wspolny glowny
  DB_ZRODLO="$ROOT"
  top="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$top" ] || return 0
  wspolny="$(git -C "$top" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$wspolny" ] && [ -d "$wspolny" ] || return 0
  glowny="$(cd -P "$ROOT" && pwd)/.git"
  [ "$(cd -P "$wspolny" && pwd)" = "$glowny" ] || return 0
  [ "$(cd -P "$top" && pwd)/.git" = "$glowny" ] || DB_ZRODLO="$top"
}

db_sprawdz_lokalny() {
  [ -f "$DB_ZRODLO/supabase/config.toml" ] ||
    die "$E_BRAK" "projekt $PROJEKT nie ma lokalnego Supabase (brak supabase/config.toml w $DB_ZRODLO)"
  [ ! -e "$DB_ZRODLO/supabase/.temp/project-ref" ] ||
    die "$E_ODMOWA" "supabase/ w $DB_ZRODLO jest powiązany z projektem w chmurze (supabase/.temp/project-ref po supabase link); shctl db działa tylko na bazie lokalnej"
  DB_BAZA="$(porty_baza_projektu "$PROJEKT")"
  case "$DB_BAZA" in
    [0-9][0-9][0-9]) ;;
    *) die "$E_BRAK" "projekt $PROJEKT nie ma bloku portów w $PORTY (rezerwuje go shctl new-project albo adopt)" ;;
  esac
}

# Kopia robocza dla --workdir: config.toml z portami bloku, reszta supabase/ jako dowiązania.
db_kopia() {
  local e n
  rm -rf "$DB_KAT/supabase"
  mkdir -p "$DB_KAT/supabase"
  for e in "$DB_ZRODLO"/supabase/* "$DB_ZRODLO"/supabase/.[!.]*; do
    [ -e "$e" ] || continue
    n="$(basename "$e")"
    case "$n" in config.toml | .temp | .branches | .env | .env.*) continue ;; esac
    ln -s "$e" "$DB_KAT/supabase/$n"
  done
  cp "$DB_ZRODLO/supabase/config.toml" "$DB_KAT/supabase/config.toml"
  porty_do_configu "$DB_KAT" "$PROJEKT" "$DB_BAZA"
  # Logflare i vector (logi) na macOS nie dochodzą do stanu healthy i przerywają start (test
  # sh-test-adopt); agentom niepotrzebne.
  toml_ustaw "$DB_KAT/supabase/config.toml" analytics enabled false
}

# Supabase CLI bez zmiennych środowiska sesji: żadnych tokenów i adresów chmury.
db_cli() {
  z_limitem "$DB_LIMIT" env -i PATH="$PATH" HOME="$HOME" USER="${USER:-}" TMPDIR="${TMPDIR:-/tmp}" \
    LANG="${LANG:-en_US.UTF-8}" ${DOCKER_HOST:+DOCKER_HOST="$DOCKER_HOST"} DO_NOT_TRACK=1 \
    supabase "$@" --workdir "$DB_KAT"
}

db_tekst() { printf 'supabase %s --workdir %s' "$*" "$DB_KAT"; }

db_dziala() { db_cli status -o json >/dev/null 2>&1; }

# Inne projekty SH (z porty.md) z działającym stackiem: jeden stack naraz (proces.md, „Limity”).
db_inne_stacki() {
  local dzialajace p
  dzialajace="$(z_limitem 30 docker ps --filter label=com.supabase.cli.project \
    --format '{{.Label "com.supabase.cli.project"}}' 2>/dev/null | sort -u || true)"
  for p in $(porty_wiersze | awk -F'\t' '$1 != "nd." && $2 != "*wolny*" { print $2 }'); do
    [ "$p" != "$PROJEKT" ] || continue
    printf '%s\n' "$dzialajace" | grep -qxF -- "$p" && printf '%s ' "$p"
  done
  return 0
}

db_sprawdz_porty() {
  local p
  command -v lsof >/dev/null || return 0
  for p in "${DB_BAZA}21" "${DB_BAZA}22" "${DB_BAZA}23" "${DB_BAZA}24"; do
    ! lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1 ||
      die "$E_ODMOWA" "port $p z bloku $PROJEKT jest zajęty przez inny proces (lsof -nP -iTCP:$p -sTCP:LISTEN)"
  done
}

db_wymagaj_dzialania() {
  db_dziala || die "$E_ODMOWA" "lokalny Supabase projektu $PROJEKT nie działa: najpierw shctl db start --projekt $PROJEKT"
}

# Adresy i lokalne klucze z supabase status do DB_STATUS; kod 1, gdy stack nie działa. Adres API
# musi być lokalny i z bloku projektu, inaczej odmowa.
DB_STATUS=""
db_status() {
  local s api
  s="$(db_cli status -o json 2>/dev/null)" || return 1
  s="$(printf '%s\n' "$s" | sed -n '/^{/,$p')"
  api="$(jq -r '.API_URL // ""' <<<"$s" 2>/dev/null || true)"
  case "$api" in
    http://127.0.0.1:"${DB_BAZA}21" | http://localhost:"${DB_BAZA}21") ;;
    *) die "$E_ODMOWA" "adres API '$api' nie jest lokalnym adresem z bloku projektu (http://127.0.0.1:${DB_BAZA}21)" ;;
  esac
  DB_STATUS="$(jq -c '{api:.API_URL, db:(.DB_URL // null), studio:(.STUDIO_URL // null),
    mail:(.MAILPIT_URL // .INBUCKET_URL // null), anon_key:(.ANON_KEY // null),
    service_role_key:(.SERVICE_ROLE_KEY // null), publishable_key:(.PUBLISHABLE_KEY // null),
    secret_key:(.SECRET_KEY // null)}' <<<"$s")"
}

db_wynik() {
  local akcja="$1" dziala="$2" status="${3:-null}" extra="${4:-}"
  [ -n "$extra" ] || extra='{}'
  wynik_json "$(jq -nc --arg p "$PROJEKT" --arg a "$akcja" --arg z "$DB_ZRODLO" --arg k "$DB_KAT" \
    --arg b "$DB_BAZA" --argjson d "$dziala" --argjson s "$status" --argjson e "$extra" \
    '{projekt:$p, akcja:$a, zrodlo:$z, workdir:$k, porty:($b + "21-" + $b + "29"), dziala:$d, status:$s} + $e')"
}

db_pokaz_status() {
  local s="$1"
  [ "$JSON" -eq 0 ] || return 0
  jq -r '"API: \(.api)", "DB: \(.db)", "Studio: \(.studio)", "Mail: \(.mail)",
    "Klucz anon (lokalny): \(.anon_key)", "Klucz service_role (lokalny): \(.service_role_key)"' <<<"$s"
}

komenda_main() {
  local akcja="${1:-}" inne s
  case "$akcja" in
    start | stop | reset | migrate | test | status) shift ;;
    *) die "$E_UZYCIE" "użycie: shctl db start|stop|reset|migrate|test|status [--projekt NAZWA]" ;;
  esac
  while [ $# -gt 0 ]; do opcja_wspolna "$@"; shift "$ZJEDZONE"; done
  znajdz_projekt
  db_zrodlo
  db_sprawdz_lokalny
  DB_KAT="$STAN/db/$PROJEKT"
  if [ "$DRY" -eq 1 ]; then
    case "$akcja" in
      start) s="$(db_tekst start)" ;;
      stop) s="$(db_tekst stop)" ;;
      reset) s="$(db_tekst db reset --local)" ;;
      migrate) s="$(db_tekst migration up --local)" ;;
      test) s="$(db_tekst test db --local)" ;;
      status) s="$(db_tekst status -o json)" ;;
    esac
    info "Źródło: $DB_ZRODLO; porty ${DB_BAZA}21-${DB_BAZA}29; komenda: $s"
    db_wynik "$akcja" null null "$(jq -nc --arg k "$s" '{komenda:$k}')"
    return 0
  fi
  wymagaj supabase docker
  z_limitem 30 docker info >/dev/null 2>&1 || die "$E_BRAK" "Docker nie działa (uruchom Docker Desktop)"
  # Kopię roboczą przebudowuje tylko komenda z blokadą; status bierze istniejącą.
  if [ "$akcja" != status ]; then
    mkdir -p "$STAN"
    db_blokada
    db_kopia
  elif [ ! -f "$DB_KAT/supabase/config.toml" ]; then
    db_kopia
  fi
  case "$akcja" in
    start)
      if db_dziala; then
        info "Lokalny Supabase $PROJEKT już działa"
      else
        inne="$(db_inne_stacki)"
        [ -z "$inne" ] || die "$E_ODMOWA" "działa już stack Supabase innego projektu SH: ${inne% } (jeden naraz; shctl db stop --projekt NAZWA)"
        db_sprawdz_porty
        db_cli start >&2 || die "$E_WYKONANIE" "supabase start nieudane (log wyżej)"
      fi
      db_status || die "$E_WYKONANIE" "supabase status nieudane po starcie"
      db_pokaz_status "$DB_STATUS"
      db_wynik start true "$DB_STATUS"
      ;;
    stop)
      if db_dziala; then
        db_cli stop >&2 || die "$E_WYKONANIE" "supabase stop nieudane (log wyżej)"
        info "Zatrzymano lokalny Supabase $PROJEKT (dane zostają w wolumenach Dockera)"
      else
        info "Lokalny Supabase $PROJEKT nie działa"
      fi
      db_wynik stop false
      ;;
    reset)
      db_wymagaj_dzialania
      db_cli db reset --local >&2 || die "$E_WYKONANIE" "supabase db reset nieudane: migracje albo seed z $DB_ZRODLO/supabase (log wyżej)"
      info "Baza $PROJEKT odtworzona z migracji i seedów ($DB_ZRODLO)"
      db_wynik reset true
      ;;
    migrate)
      db_wymagaj_dzialania
      db_cli migration up --local >&2 || die "$E_WYKONANIE" "supabase migration up nieudane (log wyżej)"
      info "Migracje $PROJEKT zastosowane ($DB_ZRODLO)"
      db_wynik migrate true
      ;;
    test)
      db_wymagaj_dzialania
      if [ ! -d "$DB_ZRODLO/supabase/tests" ]; then
        uwaga "brak $DB_ZRODLO/supabase/tests: projekt nie ma testów pgTAP"
        db_wynik test true null '{"testy":false}'
        return 0
      fi
      db_cli test db --local >&2 || die "$E_WYKONANIE" "testy pgTAP czerwone (log wyżej)"
      info "Testy pgTAP $PROJEKT zielone"
      db_wynik test true null '{"testy":true}'
      ;;
    status)
      if db_status; then
        db_pokaz_status "$DB_STATUS"
        db_wynik status true "$DB_STATUS"
      else
        info "Lokalny Supabase $PROJEKT nie działa (shctl db start --projekt $PROJEKT)"
        db_wynik status false
      fi
      ;;
  esac
}

# Jedna komenda db naraz na projekt (wspólne kontenery dla głównej kopii i worktree).
db_blokada() {
  local k="$STAN/db-$PROJEKT.lock"
  mkdir "$k" 2>/dev/null ||
    die "$E_ODMOWA" "trwa inna komenda shctl db dla $PROJEKT (blokada $k; usuń katalog, jeśli to pozostałość)"
  BLOKADA="$k"
}
