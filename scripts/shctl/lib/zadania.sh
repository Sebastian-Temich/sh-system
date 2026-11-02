# Funkcje zadań: konfiguracja, bramki dispatchu, panele herdr, stan ~/sh/stan/NAZWA.json, worktree.
# Wspólne dla task, review i reset-dryrun (proces-v1.md, „Review, QA, pętla poprawek”, „Limity”).
# shellcheck shell=bash

ROOT_G=""
SLUG=""
WT=""
MAKS_ITERACJI=3

# Projekt, repo główne (także gdy shctl działa z worktree), slug GitHuba i katalog worktree ~/sh/wt/NAZWA.
zadania_init() {
  local wspolny
  znajdz_projekt
  wymagaj gh
  wspolny="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$wspolny" ] || die "$E_BRAK" "$ROOT nie jest repozytorium git"
  ROOT_G="$(dirname "$wspolny")"
  KONFIG="$ROOT_G/docs/konfiguracja.md"
  ST="$ROOT_G/docs/status.md"
  [ -f "$KONFIG" ] || die "$E_BRAK" "brak $KONFIG"
  ROOT="$ROOT_G"
  SLUG="$(slug_repo)"
  [ -n "$SLUG" ] || die "$E_BRAK" "origin projektu $PROJEKT nie wskazuje repo GitHub"
  WT="$SH_DIR/wt/$PROJEKT"
}

# Wartość z frontmattera konfiguracja.md albo domyślna.
konf() {
  local v
  v="$(yq --front-matter=extract ".$1 // \"\"" "$KONFIG" 2>/dev/null || true)"
  case "$v" in "" | null) printf '%s' "$2" ;; *) printf '%s' "$v" ;; esac
}

konf_liczba() {
  local v
  v="$(konf "$1" "$2")"
  case "$v" in "" | *[!0-9]*) die "$E_BRAK" "konfiguracja.md: $1 musi być liczbą, jest '$v'" ;; esac
  printf '%s' "$v"
}

numer() {
  case "$1" in "" | *[!0-9]*) die "$E_UZYCIE" "niepoprawny numer: '$1'" ;; esac
  printf '%s' "$((10#$1))"
}

etykieta_workera() { printf 'worker:%s:%s' "$PROJEKT" "$1"; }
etykieta_review() { printf 'review:%s:%s' "$PROJEKT" "$1"; }

# --- GitHub -----------------------------------------------------------------------------------

issue_json() {
  gh issue view "$1" --repo "$SLUG" --json number,title,state,stateReason,labels,body,milestone,createdAt 2>/dev/null ||
    die "$E_BRAK" "nie można odczytać issue #$1 w $SLUG"
}

wszystkie_issue() {
  gh issue list --repo "$SLUG" --state all --limit 1000 \
    --json number,title,state,stateReason,labels,body,milestone 2>/dev/null ||
    die "$E_WYKONANIE" "gh issue list nie działa dla $SLUG"
}

ma_etykiete() { jq -e --arg e "$2" '[.labels[].name] | index($e) != null' <<<"$1" >/dev/null; }

status_issue() {
  jq -r '[.labels[].name | select(startswith("status:")) | ltrimstr("status:")][0] // ""' <<<"$1"
}

iteracja_issue() {
  jq -r '[.labels[].name | select(test("^iter:[0-9]+$")) | ltrimstr("iter:") | tonumber] | max // 0' <<<"$1"
}

# Zmiana etykiet; zdejmuje tylko te, które issue ma (gh nie lubi zdejmowania nieobecnych).
# zmien_etykiety NR JSON_ISSUE "dodaj1 dodaj2" "zdejmij1 zdejmij2"
zmien_etykiety() {
  local nr="$1" j="$2" e args=""
  local -a a=()
  for e in $3; do
    ma_etykiete "$j" "$e" || a+=(--add-label "$e")
  done
  for e in $4; do
    ! ma_etykiete "$j" "$e" || a+=(--remove-label "$e")
  done
  [ "${#a[@]}" -gt 0 ] || return 0
  args="${a[*]}"
  gh issue edit "$nr" --repo "$SLUG" "${a[@]}" >/dev/null || die "$E_WYKONANIE" "nie można zmienić etykiet #$nr ($args)"
}

# Status etykiet do ustawienia: wszystkie status:* poza docelowym zdejmujemy.
STATUSY="status:todo status:in-progress status:review status:blocked status:escalated"
ustaw_status() {
  local nr="$1" j="$2" cel="$3" e zdejmij=""
  for e in $STATUSY; do [ "$e" = "$cel" ] || zdejmij="$zdejmij $e"; done
  zmien_etykiety "$nr" "$j" "$cel" "$zdejmij"
}

# Numery zależności z sekcji „### Zależności” treści issue (format formularza i task create).
JQ_ZALEZNOSCI='def zaleznosci:
  ((.body // "") | split("\n")) as $l
  | ([range(0; $l | length) | select($l[.] | test("^### Zale"))][0]) as $s
  | if $s == null then []
    else [$l[$s + 1:][]] as $r
      | ([range(0; $r | length) | select($r[.] | test("^### "))][0] // ($r | length)) as $k
      | [$r[0:$k][] | scan("#([0-9]+)") | .[0] | tonumber] | unique
    end;'

# PR zadania: otwarty, a gdy go nie ma, najnowszy scalony. Wiąże przez „Closes #NR” lub gałąź task/NR-.
pr_zadania() {
  local nr="$1"
  gh pr list --repo "$SLUG" --state all --limit 200 \
    --json number,state,headRefName,headRefOid,closingIssuesReferences,url,createdAt 2>/dev/null |
    jq -c --argjson n "$nr" '
      map(select(([.closingIssuesReferences[]?.number] | index($n)) != null
        or (.headRefName | startswith("task/\($n)-"))))
      | (map(select(.state == "OPEN")) | max_by(.number)) // (map(select(.state == "MERGED")) | max_by(.number)) // empty'
}

# Wynik CI z statusCheckRollup, jak w scripts/sync-status.sh: pass, fail, pending albo brak.
JQ_CI='def ci:
  (.statusCheckRollup // []) as $c
  | if ($c | length) == 0 then "brak"
    elif any($c[]; (.conclusion // .state // "")
      | IN("FAILURE", "ERROR", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE")) then "fail"
    elif any($c[]; (.status // "") as $s | (.state // "") as $t
      | ($s != "" and $s != "COMPLETED") or $t == "PENDING" or $t == "EXPECTED") then "pending"
    else "pass" end;'

# Ostatni wynik shctl review dla commita: {werdykt, zgloszenia, ...} albo pusto.
review_dla_heada() {
  local pr="$1" head="$2"
  gh pr view "$pr" --repo "$SLUG" --json comments 2>/dev/null | jq -c --arg h "$head" '
    [.comments[].body | select(contains("<!-- shctl:review head=" + $h + " "))]
    | last // empty
    | (capture("<!-- shctl:review-dane (?<d>[A-Za-z0-9+/=]+) -->").d | @base64d | fromjson)'
}

# --- Konfiguracja wykonawców ------------------------------------------------------------------

model_workera() { konf modele.worker opus; }

# Model Codex: nazwa z konfiguracja.md („GPT-6.1 Terra”) jako identyfikator („gpt-6.1-terra”).
model_reviewera() {
  local m
  m="$(konf modele.reviewer.model domyslny)"
  case "$m" in domyslny | "") return 0 ;; esac
  printf '%s' "$m" | LC_ALL=C tr 'A-Z' 'a-z' | LC_ALL=C sed -E 's/[[:space:]]+/-/g'
}

# --- Bramki dispatchu -------------------------------------------------------------------------

# Wpisy z ~/sh/limity.md: pozycje list i wiersze tabeli bez nagłówka; „brak” nie jest wstrzymaniem.
wstrzymania() {
  [ -f "$LIMITY" ] || return 0
  grep -E '^(- |\| )' "$LIMITY" | grep -vE '^\|[- |:]*$' | awk '!/^\| / || n++' |
    grep -viE '^(- |\| )[*_(]*(brak|nic|none)[*_)]*[ |]*$' || true
}

# Wstrzymanie Codexa blokuje review; każde inne wstrzymanie blokuje workerów Claude.
wstrzymany_codex() { wstrzymania | grep -qi codex; }
wstrzymany_claude() { wstrzymania | grep -vi codex | grep -q . || wstrzymania | grep -qi claude; }

wolne_gb() {
  df -Pk "$1" 2>/dev/null | awk 'NR == 2 { printf "%d", $4 / 1048576 }'
}

# Powiadomienie o braku miejsca raz dziennie; znika, gdy miejsce wróci.
alarm_dysku() {
  local plik="$STAN/dysk-alarm" wolne="$1" min="$2"
  [ "$DRY" -eq 0 ] || return 0
  if [ "$wolne" -ge "$min" ]; then
    rm -f "$plik"
    return 0
  fi
  [ "$(cat "$plik" 2>/dev/null || true)" != "$(dzis)" ] || return 0
  mkdir -p "$STAN"
  if powiadom high "Brak miejsca" "Wolne ${wolne} GB, minimum ${min} GB: dispatch wstrzymany" "" warning; then
    dzis >"$plik"
  else
    uwaga "powiadomienie o braku miejsca nie wyszło"
  fi
}

# Wszystkie panele herdr: pane_id, label, agent, workspace_id.
panele_herdr() {
  local w
  herdr workspace list | jq -r '.result.workspaces[].workspace_id' | while IFS= read -r w; do
    herdr pane list --workspace "$w" | jq -c '.result.panes[]'
  done | jq -sc 'map({pane_id, workspace_id, label: (.label // ""), agent: (.agent // ""),
    agent_status: (.agent_status // ""), cwd: (.foreground_cwd // .cwd // "")})'
}

panel_po_etykiecie() {
  jq -r --arg l "$2" '[.[] | select(.label == $l)][0].pane_id // ""' <<<"$1"
}

# Aktywni workerzy we wszystkich projektach (etykiety worker:*), bez wskazanej etykiety.
aktywni_workerzy() {
  jq -r --arg bez "$2" '[.[] | select((.label | startswith("worker:")) and .label != $bez)] | length' <<<"$1"
}

# Ocena zadań do startu. Wejście: JSON wszystkich issue, JSON paneli, etykieta pomijana w limicie.
# Wynik: {kandydaci, zablokowane, blokady, sloty, kolejka_review, wolne_gb, min_wolne_gb}.
ocen_gotowe() {
  local issues="$1" panele="$2" bez="${3:-}" max_local max_q min_gb wolne aktywni blokady='[]' w
  max_local="$(konf_liczba max_local 1)"
  max_q="$(konf_liczba max_review_queue 3)"
  min_gb="$(konf_liczba min_wolne_gb 15)"
  wolne="$(wolne_gb "$ROOT_G")"
  [ -n "$wolne" ] || wolne=0
  aktywni="$(aktywni_workerzy "$panele" "$bez")"

  if [ "$aktywni" -ge "$max_local" ]; then
    blokady="$(jq -c --arg o "aktywni workerzy: $aktywni z max_local=$max_local (wszystkie projekty)" \
      '. + [{rodzaj:"max_local", opis:$o}]' <<<"$blokady")"
  fi
  if [ "$wolne" -lt "$min_gb" ]; then
    blokady="$(jq -c --arg o "wolne ${wolne} GB, min_wolne_gb=$min_gb" '. + [{rodzaj:"dysk", opis:$o}]' <<<"$blokady")"
  fi
  if wstrzymany_claude; then
    w="$(wstrzymania | grep -vi codex | head -1)"
    [ -n "$w" ] || w="$(wstrzymania | grep -i claude | head -1)"
    blokady="$(jq -c --arg o "limity.md: $w" '. + [{rodzaj:"limit", opis:$o}]' <<<"$blokady")"
  fi
  alarm_dysku "$wolne" "$min_gb"

  jq -c --argjson b "$blokady" --argjson ml "$max_local" --argjson a "$aktywni" --argjson mq "$max_q" \
    --argjson wg "$wolne" --argjson mg "$min_gb" "$JQ_ZALEZNOSCI"'
    def et: [.labels[].name];
    def status: (et | map(select(startswith("status:")) | ltrimstr("status:"))[0]) // "todo";
    (map({key: (.number | tostring), value: .}) | from_entries) as $mapa
    | (map(select(.state == "OPEN" and status == "review")) | length) as $q
    | (map(select(.state == "OPEN" and (et | index("db:migracja")) and status != "todo")) | map(.number)) as $db_w_toku
    | (map(select(.state == "OPEN" and status == "todo")) | sort_by(.number)
      | map(. as $i
        | ([zaleznosci[] | tostring | . as $z
            | if $mapa[$z] == null then "brak zależności #\($z)"
              elif $mapa[$z].state == "OPEN" then "zależność #\($z) otwarta"
              elif $mapa[$z].stateReason == "NOT_PLANNED" then "zależność #\($z) anulowana"
              else empty end]) as $p
        | {nr: .number, tytul: .title, db_migracja: ((et | index("db:migracja")) != null), powody: $p})) as $todo
    | (reduce $todo[] as $t ({lista: [], db: ($db_w_toku | length > 0), db_nr: ($db_w_toku[0] // null)};
        if ($t.powody | length) > 0 then .lista += [$t]
        elif $t.db_migracja and .db then
          .lista += [$t + {powody: ["db:migracja: w projekcie trwa #\(.db_nr)"]}]
        elif $t.db_migracja then .lista += [$t] | .db = true | .db_nr = $t.nr
        else .lista += [$t] end)) as $ocena
    | ($b + (if $q >= $mq then [{rodzaj: "kolejka_review",
        opis: "na review czeka \($q) PR, max_review_queue=\($mq)"}] else [] end)) as $blok
    | {kandydaci: [$ocena.lista[] | select(.powody | length == 0) | del(.powody)],
       zablokowane: [$ocena.lista[] | select(.powody | length > 0)],
       blokady: $blok,
       sloty: {max_local: $ml, aktywne: $a, wolne: ([$ml - $a, 0] | max)},
       kolejka_review: {max: $mq, czeka: $q},
       wolne_gb: $wg, min_wolne_gb: $mg}' <<<"$issues"
}

# --- herdr --------------------------------------------------------------------------------------

herdr_dziala() {
  wymagaj herdr
  herdr workspace list >/dev/null 2>&1 || die "$E_BRAK" "serwer herdr nie odpowiada"
}

# Workspace „sh” (sh-start.sh), a gdy go nie ma, pierwszy.
workspace_sh() {
  herdr workspace list | jq -r '(.result.workspaces | map(select(.label == "sh"))[0] // .result.workspaces[0]).workspace_id // ""'
}

# Nowa karta z jednym panelem o etykiecie LABEL; wypisuje pane_id.
otworz_panel() {
  local label="$1" kat="$2" ws r p
  ws="$(workspace_sh)"
  [ -n "$ws" ] || die "$E_BRAK" "herdr nie ma żadnego workspace (sh-start.sh)"
  r="$(herdr tab create --workspace "$ws" --cwd "$kat" --label "$label" --no-focus)" ||
    die "$E_WYKONANIE" "herdr tab create nie działa"
  p="$(jq -r '.result.root_pane.pane_id // ""' <<<"$r")"
  [ -n "$p" ] || die "$E_WYKONANIE" "herdr nie zwrócił panelu nowej karty"
  herdr pane rename "$p" "$label" >/dev/null || die "$E_WYKONANIE" "nie można nadać etykiety $label panelowi $p"
  printf '%s' "$p"
}

zamknij_panel_etykieta() {
  local p
  p="$(panel_po_etykiecie "$(panele_herdr)" "$1")"
  [ -n "$p" ] || return 0
  herdr pane close "$p" >/dev/null || { uwaga "nie zamknięto panelu $p ($1)"; return 1; }
}

# --- Stan ~/sh/stan/NAZWA.json, klucz .zadania -----------------------------------------------

plik_stanu() { printf '%s/%s.json' "$STAN" "$PROJEKT"; }

stan_zadania() {
  local f
  f="$(plik_stanu)"
  [ -f "$f" ] || { echo null; return 0; }
  jq -c --arg n "$1" '.zadania[$n] // null' "$f"
}

# Scala obiekt z wpisem zadania; null usuwa wpis.
stan_zapisz() {
  local nr="$1" obj="$2" f t
  [ "$DRY" -eq 0 ] || return 0
  f="$(plik_stanu)"
  mkdir -p "$STAN"
  zablokuj "$f.lock"
  t="$(tmp_plik)"
  if [ -f "$f" ]; then cp "$f" "$t"; else jq -n --arg p "$PROJEKT" '{projekt:$p, zadania:{}}' >"$t"; fi
  jq --arg n "$nr" --argjson o "$obj" '
    .zadania = (.zadania // {})
    | if $o == null then .zadania |= del(.[$n]) else .zadania[$n] = ((.zadania[$n] // {}) + $o) end' "$t" >"$t.n"
  mv "$t.n" "$f"
  rm -f "$t"
  odblokuj "$f.lock"
}

# --- git ------------------------------------------------------------------------------------------

# Czy KATALOG jest worktree tego repo.
worktree_tego_repo() {
  local w
  [ -d "$1" ] || return 1
  w="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ "$w" = "$ROOT_G/.git" ]
}

# Katalog istnieje, ale należy do innego repo (np. sklonowany ręcznie): niczego nie nadpisujemy.
sprawdz_wolny_katalog() {
  [ -e "$1" ] || return 0
  worktree_tego_repo "$1" && return 0
  die "$E_ODMOWA" "$1 istnieje i nie jest worktree projektu $PROJEKT (numer zajęty przez inny projekt?)"
}

pobierz_main() {
  z_limitem 120 git -C "$ROOT_G" fetch -q origin main 2>/dev/null || uwaga "git fetch origin main nie powiódł się; używam lokalnych refów"
}

baza_main() {
  if git -C "$ROOT_G" rev-parse -q --verify origin/main >/dev/null; then echo origin/main; else echo main; fi
}

usun_worktree() {
  local k="$1"
  [ -e "$k" ] || return 0
  if worktree_tego_repo "$k"; then
    git -C "$ROOT_G" worktree remove --force "$k" || die "$E_WYKONANIE" "nie można usunąć worktree $k"
  else
    die "$E_ODMOWA" "$k nie jest worktree projektu $PROJEKT; nie usuwam"
  fi
  git -C "$ROOT_G" worktree prune
}

# Sekcja „### NAZWA” treści issue (format formularza), bez pustych brzegów.
sekcja_issue() {
  jq -r '.body // ""' <<<"$1" | awk -v n="### $2" '
    $0 == n { w = 1; next }
    w && /^### / { exit }
    w { print }' | sed '/./,$!d' | awk 'NF { for (; p > 0; p--) print ""; print; next } { p++ }'
}

czas_trwania() {
  jq -nr --arg s "$1" '
    (now - ($s | fromdateiso8601)) as $d | ($d / 3600 | floor) as $h | (($d % 3600) / 60 | floor) as $m
    | if $h > 0 then "\($h)h \($m)min" else "\($m)min" end' 2>/dev/null || echo "-"
}

teraz_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# --- Zaufanie folderu Claude Code ---------------------------------------------------------------

# Claude Code w sesji interaktywnej pyta o zaufanie folderu. W repo klucz to katalog główny repo, a
# w worktree katalog główny głównej kopii (code.claude.com/docs/en/permissions, „Project allow rules
# and workspace trust”), więc wpis dla ~/sh/projekty/NAZWA obejmuje też ~/sh/wt/NAZWA/NR. Ręczny
# wpis projects["<repo>"].hasTrustDialogAccepted w ~/.claude.json opisuje ta sama strona
# („What runs before you trust a folder”). Wypisuje true, gdy wpis dodano (lub dodałby --dry-run).
CLAUDE_JSON="${SH_CLAUDE_JSON:-$HOME/.claude.json}"
zaufaj_projektowi() {
  local f="$CLAUDE_JSON" t
  if [ -f "$f" ] && jq -e --arg p "$ROOT_G" '.projects[$p].hasTrustDialogAccepted == true' "$f" >/dev/null 2>&1; then
    echo false
    return 0
  fi
  if [ "$DRY" -eq 1 ]; then echo true; return 0; fi
  if [ -f "$f" ]; then
    jq -e 'type == "object"' "$f" >/dev/null 2>&1 || die "$E_WYKONANIE" "$f nie jest poprawnym JSON; zaufanie folderu nie zostało zapisane"
  fi
  t="$(mktemp "$f.shctl.XXXXXX")"
  if [ -f "$f" ]; then cat "$f"; else echo '{}'; fi |
    jq --arg p "$ROOT_G" '.projects[$p] = ((.projects[$p] // {}) + {hasTrustDialogAccepted: true})' >"$t" ||
    { rm -f "$t"; die "$E_WYKONANIE" "nie można zapisać zaufania folderu w $f"; }
  chmod 600 "$t"
  mv "$t" "$f"
  echo true
}
