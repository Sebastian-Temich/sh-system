# Funkcje zadań: konfiguracja, bramki dispatchu, panele herdr, stan /Users/Shared/sh/stan/NAZWA.json, worktree.
# Wspólne dla task, review i reset-dryrun (proces.md, „Review i silniki”, „Limity, stop, wznowienie”).
# shellcheck shell=bash

ROOT_G=""
SLUG=""
WT=""
MAKS_ITERACJI=3

# --- Warstwy skilli (task dispatch, review run) ----------------------------------------------
# Mapa warstw i skille pluginu, w tym techniczne (plugin/skills/techniczne/NAZWA/SKILL.md).
WARSTWY_SKILLI="${SH_WARSTWY_SKILLI:-$SHCTL_DIR/../../plugin/warstwy-skilli.yaml}"
SKILLE_PLUGINU="${SH_SKILLE_PLUGINU:-$SHCTL_DIR/../../plugin/skills}"

# Mapa warstw jako JSON; {} gdy brak pliku albo błąd.
mapa_warstw() {
  if [ -f "$WARSTWY_SKILLI" ]; then yq -o=json '.' "$WARSTWY_SKILLI" 2>/dev/null || echo '{}'; else echo '{}'; fi
}

# Warstwy z treści issue (JSON issue): znacznik shctl:warstwy z task create; {} gdy brak.
warstwy_issue() {
  jq -c '(.body // "") | [capture("<!-- shctl:warstwy (?<d>[A-Za-z0-9+/=]+) -->")][0].d // empty | @base64d | fromjson' <<<"$1" 2>/dev/null |
    grep . || echo '{}'
}

# Ścieżka SKILL.md skilla pluginu (skills/NAZWA albo skills/techniczne/NAZWA) albo pusto.
plik_skilla_pluginu() {
  local n="${1##*:}" d
  for d in "$SKILLE_PLUGINU/$n" "$SKILLE_PLUGINU/techniczne/$n"; do
    if [ -f "$d/SKILL.md" ]; then
      printf '%s' "$d/SKILL.md"
      return 0
    fi
  done
}

# Skille warstwy kategorii (lista nazw w liniach), jak u workera: mapa albo sh-kat-KATEGORIA.
skille_kategorii() {
  [ -n "$1" ] || return 0
  jq -r --arg k "$1" '(.kategoria[$k] // ["sh-kat-" + $k])[]' <<<"$(mapa_warstw)"
}

# Skille warstwy stacku (lista nazw w liniach) dla listy stacków w JSON, jak u workera: mapa albo
# sh-stack-STACK.
skille_stacku() {
  [ -n "$1" ] || return 0
  jq -r --argjson s "$1" '. as $m | ($s // [])[] | ($m.stack[.] // ["sh-stack-" + .])[]' <<<"$(mapa_warstw)"
}

# Sekcja „## Lista kontrolna” skilla (bez nagłówka) albo pusto.
lista_kontrolna_skilla() {
  awk '$0 == "## Lista kontrolna" { w = 1; next } w && /^## / { exit } w' "$1" | awk 'NF { t = 1 } t'
}

# Projekt, repo główne (także gdy shctl działa z worktree), slug GitHuba i katalog worktree /Users/Shared/sh/wt/NAZWA.
zadania_init() {
  local wspolny
  znajdz_projekt
  wymagaj gh
  wspolny="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$wspolny" ] || die "$E_BRAK" "$ROOT nie jest repozytorium git"
  ROOT_G="$(dirname "$wspolny")"
  KONFIG="$ROOT_G/docs/konfiguracja.md"
  [ -f "$KONFIG" ] || KONFIG="$(konfig_adopt "$PROJEKT")" || KONFIG="$ROOT_G/docs/konfiguracja.md"
  # Katalog z docs/ projektu: main, a dla projektu przejętego przed merge'em analizy worktree etapu.
  ROOT_DOCS="$(dirname "$(dirname "$KONFIG")")"
  ST="$(plik_projektu "$ROOT_G")"
  [ -f "$KONFIG" ] || die "$E_BRAK" "brak $KONFIG"
  ustal_etapy
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

# Tag baseline projektu wzorcowego: baseline_tag z docs/konfiguracja.md albo najnowszy z baseline-*
# (i dawnego baseline) według daty commita, przy tej samej sekundzie nowsza nazwa. Pusto i kod 1, gdy brak.
najnowszy_baseline() {
  local t
  t="$(konf baseline_tag "")"
  if [ -n "$t" ]; then
    git -C "$ROOT_G" rev-parse -q --verify "refs/tags/$t^{commit}" >/dev/null || die "$E_BRAK" "baseline_tag: brak tagu $t"
    printf '%s' "$t"
    return 0
  fi
  t="$(git -C "$ROOT_G" for-each-ref --sort=-refname --sort=-creatordate --format='%(refname:short)' 'refs/tags/baseline' 'refs/tags/baseline-*' | head -1)"
  [ -n "$t" ] || return 1
  printf '%s' "$t"
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
# Panel workera eskalowanego zadania: zostaje do wglądu, ale nie zajmuje slotu (liczą się tylko worker:*).
etykieta_eskalacji() { printf 'eskalacja:%s:%s' "$PROJEKT" "$1"; }

# Eskalacja zwalnia slot: panel worker:P:NR dostaje etykietę eskalacja:P:NR. Panelu nie zamykamy, bo
# worker może sam wołać shctl escalate i musi dokończyć raport. Wypisuje pane_id albo nic.
zwolnij_slot() {
  local p
  herdr workspace list >/dev/null 2>&1 || return 0
  p="$(panel_po_etykiecie "$(panele_herdr)" "$(etykieta_workera "$1")")"
  [ -n "$p" ] || return 0
  [ "$DRY" -eq 1 ] || herdr pane rename "$p" "$(etykieta_eskalacji "$1")" >/dev/null ||
    { uwaga "nie zmieniono etykiety panelu $p; slot zostaje zajęty"; return 0; }
  printf '%s' "$p"
}

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
  # Zmiana statusu zadania to zmiana stanu projektu: widok docs/Projekt.md od razu ją pokazuje.
  odswiez_projekt || true
}

# Numery zależności z pola strukturalnego: pierwsza niepusta linia sekcji „### Zależności” (format
# task create i formularza), a w niej tylko lista „#NR, #NR” od początku linii. „brak”, notatki pod
# listą i dalsze wzmianki „#NR” (np. „#79 anulowane”) nie są zależnościami (sh-dryrun, przebieg 5).
# Linię zmienia shctl task deps.
JQ_ZALEZNOSCI='def zaleznosci:
  ((.body // "") | split("\n")) as $l
  | ([range(0; $l | length) | select($l[.] | test("^### Zale"))][0]) as $s
  | if $s == null then []
    else ([$l[$s + 1:][] | select(test("^\\s*$") | not)][0] // "") as $p
      | if ($p | test("^### ")) then []
        else [(($p | capture("^(?<l>(\\s*#[0-9]+\\s*,?)+)").l) // "") | scan("#([0-9]+)") | .[0] | tonumber] | unique end
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

# Wynik CI PR dla commita HEAD: statusCheckRollup, a przy pass jeszcze biegi workflow tego commita.
# Job czekający na inny (needs:) nie ma jeszcze check runu w rollupie, więc sam rollup dawał pass
# przy e2e w toku (sh-dryrun PR #83). Bieg workflow w toku to pending; błąd gh run list nie zmienia
# wyniku z rollupu. Wypisuje pass, fail, pending albo brak.
ci_pr() {
  local prn="$1" head="$2" ci runs
  ci="$(gh pr view "$prn" --repo "$SLUG" --json statusCheckRollup | jq -r "$JQ_CI"' ci')" || return 1
  if [ "$ci" = pass ] && [ -n "$head" ]; then
    runs="$(gh run list --repo "$SLUG" --commit "$head" --limit 50 --json workflowName,status,conclusion 2>/dev/null || echo '[]')"
    ci="$(jq -r '
      if any(.[]; (.status // "completed") != "completed") then "pending"
      elif any(.[]; (.conclusion // "") | IN("failure", "timed_out", "startup_failure", "cancelled")) then "fail"
      else "pass" end' <<<"$runs" 2>/dev/null || echo pass)"
  fi
  printf '%s' "$ci"
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

# Wynik review z treści komentarza w formacie sh-system/templates/review.md: zgłoszenia z linii
# „- IKONA WAGA [(przyczyna: P)] [`plik[:linia]`]: opis”, werdykt liczony z wag (FAIL przy krytyczne
# lub istotne). Przyczyna (wymaganie, kod, test, design) jest opcjonalna dla komentarzy sprzed F4.
JQ_PARSUJ_REVIEW='def parsuj_review($h):
  split("\n") as $l
  | ([range(0; $l | length) | select($l[.] | startswith("<!-- shctl:review head="))][0]) as $m
  | ([range(0; $l | length) | select($l[.] == "### Zgłoszenia")][0] // ($l | length)) as $k
  | [$l[] | capture("^- (?:🔴|🟡|⚪) (?<waga>krytyczne|istotne|drobne)(?: \\(przyczyna: (?<przyczyna>wymaganie|kod|test|design)\\))?(?: `(?<plik>[^`]*?)(?::(?<linia>[0-9]+))?`)?: (?<opis>.+)$")
      | {waga, przyczyna: (.przyczyna // ""), plik: (.plik // ""), linia: ((.linia // "0") | tonumber), opis}] as $z
  | {werdykt: (if any($z[]; .waga != "drobne") then "FAIL" else "PASS" end),
     podsumowanie: ([$l[($m + 1):$k][] | select(length > 0 and (startswith("Commit `") | not))] | join(" ")),
     zgloszenia: $z, head: $h};'

# Ostatni wynik review dla commita: {werdykt, zgloszenia, ...} albo pusto. Ukryte dane z shctl review
# run mają pierwszeństwo; bez nich wynik pochodzi z treści komentarza.
review_dla_heada() {
  local pr="$1" head="$2"
  gh pr view "$pr" --repo "$SLUG" --json comments 2>/dev/null | jq -c --arg h "$head" "$JQ_PARSUJ_REVIEW"'
    [.comments[].body | select(contains("<!-- shctl:review head=" + $h + " "))]
    | last // empty
    | if test("<!-- shctl:review-dane [A-Za-z0-9+/=]+ -->")
      then capture("<!-- shctl:review-dane (?<d>[A-Za-z0-9+/=]+) -->").d | @base64d | fromjson
      else parsuj_review($h) end'
}

# --- Konfiguracja wykonawców ------------------------------------------------------------------

model_workera() { konf modele.worker opus; }

# --- Bramki dispatchu -------------------------------------------------------------------------

# Wpisy z /Users/Shared/sh/limity.md: pozycje list i wiersze tabeli bez nagłówka; „brak” nie jest wstrzymaniem.
wstrzymania() {
  [ -f "$LIMITY" ] || return 0
  grep -E '^(- |\| )' "$LIMITY" | grep -vE '^\|[- |:]*$' | awk '!/^\| / || n++' |
    grep -viE '^(- |\| )[*_(]*(brak|nic|none)[*_)]*[ |]*$' || true
}

# Wstrzymanie Codexa blokuje review Codexem; każde inne wstrzymanie blokuje Claude (workerów i
# reviewera Claude).
wstrzymany_codex() { wstrzymania | grep -qi codex; }
wstrzymany_claude() { wstrzymania | grep -vi codex | grep -q . || wstrzymania | grep -qi claude; }
wstrzymany_silnik() { case "$1" in codex) wstrzymany_codex ;; *) wstrzymany_claude ;; esac; }
# Wiersz limity.md dla silnika (pierwszy pasujący) albo pusto.
wstrzymanie_silnika() {
  if [ "$1" = codex ]; then wstrzymania | grep -i codex | head -1
  else wstrzymania | grep -vi codex | head -1; fi
}

wolne_gb() {
  LC_ALL=C df -Pk "$1" 2>/dev/null | LC_ALL=C awk 'NR == 2 { printf "%d", $4 / 1048576 }'
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

# Limit workerów całego Maca: frontmatter /Users/Shared/sh/konfiguracja.md (max_local), domyślnie 2.
MAX_LOCAL_DOMYSLNY=2
max_local_globalny() {
  local v=""
  [ ! -f "$KONFIG_SH" ] || v="$(yq --front-matter=extract '.max_local // ""' "$KONFIG_SH" 2>/dev/null || true)"
  case "$v" in "" | null) printf '%s' "$MAX_LOCAL_DOMYSLNY" ;; *[!0-9]* | 0) die "$E_BRAK" "$KONFIG_SH: max_local musi być liczbą dodatnią, jest '$v'" ;; *) printf '%s' "$v" ;; esac
}

aktywni_workerzy_projektu() {
  jq -r --arg p "worker:$PROJEKT:" --arg bez "$2" '[.[] | select((.label | startswith($p)) and .label != $bez)] | length' <<<"$1"
}

# Ocena zadań do startu. Wejście: JSON wszystkich issue, JSON paneli, etykieta pomijana w limicie.
# Wynik: {kandydaci, zablokowane, blokady, sloty, kolejka_review, wolne_gb, min_wolne_gb}.
# Sloty: limit globalny Maca liczy workerów wszystkich projektów; max_local projektu może go tylko
# obniżyć i liczy workerów tego projektu.
# Lista startowa (sh-intake): rzeczy zewnętrzne od właściciela (konta, dostępy, domeny, klucze testowe,
# materiały). Realizacja nie startuje, dopóki w docs/00-intake/lista-startowa.md na main jest pole
# „- [ ]” poza blokiem kodu i komentarzem HTML (przykład w szablonie). „- [x]” to potwierdzone,
# „- [-] … (nie dotyczy: powód)” to pominięte. Brak pliku (projekt sprzed SH-lite F4) nie blokuje.
# Wypisuje liczbę niepotwierdzonych pozycji.
lista_startowa_braki() {
  local plik="$ROOT_G/docs/00-intake/lista-startowa.md"
  if [ ! -f "$plik" ]; then
    echo 0
    return 0
  fi
  pola_bez_komentarzy <"$plik" | awk '/^[ \t]*[-*+] \[ \]/ { n++ } END { print n + 0 }'
}

# Treść Markdown bez bloków kodu (``` i ~~~) i komentarzy HTML (także wieloliniowych); usunięte
# fragmenty zostają pustymi liniami. Pola „- [ ]” w przykładach nie są polami do zaznaczenia.
pola_bez_komentarzy() {
  awk '
    !kom && /^[ \t]*(```|~~~)/ { kod = !kod; print ""; next }
    kod { print ""; next }
    {
      l = $0; w = ""
      while (l != "") {
        if (kom) {
          i = index(l, "-->")
          if (i == 0) { l = ""; break }
          l = substr(l, i + 3); kom = 0
        } else {
          i = index(l, "<!--")
          if (i == 0) { w = w l; l = ""; break }
          w = w substr(l, 1, i - 1); l = substr(l, i + 4); kom = 1
        }
      }
      print w
    }'
}

ocen_gotowe() {
  local issues="$1" panele="$2" bez="${3:-}" max_local max_g max_p max_q min_gb wolne aktywni akt_p blokady='[]' w wolne_s
  max_g="$(max_local_globalny)"
  max_p="$(konf max_local "")"
  case "$max_p" in "") ;; *[!0-9]*) die "$E_BRAK" "konfiguracja.md: max_local musi być liczbą, jest '$max_p'" ;; esac
  max_local="$max_g"
  if [ -n "$max_p" ] && [ "$max_p" -lt "$max_g" ]; then max_local="$max_p"; fi
  max_q="$(konf_liczba max_review_queue 3)"
  min_gb="$(konf_liczba min_wolne_gb 15)"
  wolne="$(wolne_gb "$ROOT_G")"
  [ -n "$wolne" ] || wolne=0
  aktywni="$(aktywni_workerzy "$panele" "$bez")"
  akt_p="$(aktywni_workerzy_projektu "$panele" "$bez")"
  wolne_s=$((max_g - aktywni))
  [ $((max_local - akt_p)) -ge "$wolne_s" ] || wolne_s=$((max_local - akt_p))
  [ "$wolne_s" -ge 0 ] || wolne_s=0

  if [ "$aktywni" -ge "$max_g" ]; then
    blokady="$(jq -c --arg o "aktywni workerzy: $aktywni z max_local=$max_g ($KONFIG_SH, wszystkie projekty)" \
      '. + [{rodzaj:"max_local", opis:$o}]' <<<"$blokady")"
  elif [ "$akt_p" -ge "$max_local" ]; then
    blokady="$(jq -c --arg o "aktywni workerzy projektu $PROJEKT: $akt_p z max_local=$max_local (konfiguracja.md projektu)" \
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
  w="$(lista_startowa_braki)"
  if [ "$w" -gt 0 ]; then
    blokady="$(jq -c --arg o "lista startowa: $w pozycji bez potwierdzenia (docs/00-intake/lista-startowa.md)" \
      '. + [{rodzaj:"lista_startowa", opis:$o}]' <<<"$blokady")"
  fi

  jq -c --argjson b "$blokady" --argjson ml "$max_local" --argjson a "$aktywni" --argjson mq "$max_q" \
    --argjson wg "$wolne" --argjson mg "$min_gb" --argjson g "$max_g" --arg mp "$max_p" --argjson ap "$akt_p" \
    --argjson ws "$wolne_s" "$JQ_ZALEZNOSCI"'
    def et: [.labels[].name];
    def status: (et | map(select(startswith("status:")) | ltrimstr("status:"))[0]) // "todo";
    (map({key: (.number | tostring), value: .}) | from_entries) as $mapa
    | (map(select(.state == "OPEN" and status == "review")) | length) as $q
    | (map(select(.state == "OPEN" and (et | index("db:migracja")) and status != "todo")) | map(.number)) as $db_w_toku
    # Ścieżka krytyczna: długość najdłuższego łańcucha otwartych zadań, który zaczyna się od zadania
    # (ono i wszystkie zależne od niego pośrednio). Przy cyklu wynik jest ograniczony liczbą zadań.
    | (map(select(.state == "OPEN")) | map({key: (.number | tostring), value: [zaleznosci[] | tostring]}) | from_entries) as $zo
    | ($zo | keys) as $otw
    | (reduce range(0; $otw | length) as $_ ($otw | map({key: ., value: 1}) | from_entries;
        . as $d | reduce $otw[] as $n (.;
          .[$n] = 1 + ([$otw[] | select(($zo[.] | index($n)) != null) | $d[.]] | max // 0)))) as $sciezka
    | (map(select(.state == "OPEN" and status == "todo"))
      | map(. + {sciezka: ($sciezka[.number | tostring] // 1)}) | sort_by([-.sciezka, .number])
      | map(. as $i
        | ([zaleznosci[] | tostring | . as $z
            | if $mapa[$z] == null then "brak zależności #\($z)"
              elif $mapa[$z].state == "OPEN" then "zależność #\($z) otwarta"
              elif $mapa[$z].stateReason == "NOT_PLANNED" then
                "zależność #\($z) anulowana: zadanie zablokowane; usuń zależność (shctl task deps \($i.number) --usun #\($z)) albo eskaluj (shctl escalate --dotyczy \"#\($i.number)\")"
              else empty end]) as $p
        | {nr: .number, tytul: .title, sciezka, db_migracja: ((et | index("db:migracja")) != null), powody: $p})) as $todo
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
       sloty: {max_local: $ml, max_local_globalny: $g, max_local_projektu: (if $mp == "" then null else ($mp | tonumber) end),
         aktywne: $a, aktywne_projektu: $ap, wolne: $ws},
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

# --- Stan /Users/Shared/sh/stan/NAZWA.json, klucz .zadania -----------------------------------------------

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

# Stan etapu (klucz .etapy): pamięć powtórek shctl stage iter; iteracja etapu jest w DoD.md na main.
stan_etapu() {
  local f
  f="$(plik_stanu)"
  [ -f "$f" ] || { echo null; return 0; }
  jq -c --arg e "$1" '.etapy[$e] // null' "$f"
}

stan_etapu_zapisz() {
  local e="$1" obj="$2" f t
  [ "$DRY" -eq 0 ] || return 0
  f="$(plik_stanu)"
  mkdir -p "$STAN"
  zablokuj "$f.lock"
  t="$(tmp_plik)"
  if [ -f "$f" ]; then cp "$f" "$t"; else jq -n --arg p "$PROJEKT" '{projekt:$p, zadania:{}}' >"$t"; fi
  jq --arg e "$e" --argjson o "$obj" '.etapy = (.etapy // {}) | .etapy[$e] = ((.etapy[$e] // {}) + $o)' "$t" >"$t.n"
  mv "$t.n" "$f"
  rm -f "$t"
  odblokuj "$f.lock"
}

# --- PR: konflikt z main ----------------------------------------------------------------------------

# Stan scalania PR z GitHuba: MERGEABLE, CONFLICTING albo UNKNOWN. GitHub liczy go leniwie, więc
# UNKNOWN ponawiamy kilka razy. Przy CONFLICTING workflowy pull_request nie startują, a CI zostaje „brak”.
mergeable_pr() {
  local pr="$1" m i=0 proby="${SHCTL_MERGEABLE_PROBY:-5}"
  while :; do
    m="$(gh pr view "$pr" --repo "$SLUG" --json mergeable --jq '.mergeable // "UNKNOWN"' 2>/dev/null || echo UNKNOWN)"
    [ "$m" = UNKNOWN ] || break
    i=$((i + 1))
    [ "$i" -lt "$proby" ] || break
    sleep "${SHCTL_MERGEABLE_PAUZA:-3}"
  done
  printf '%s' "${m:-UNKNOWN}"
}

komunikat_konfliktu() {
  printf 'PR #%s ma konflikt z main (mergeable: CONFLICTING): CI nie wystartuje, nie czekaj na nie. Zaktualizuj gałąź %s: w worktree git pull --no-rebase origin main, rozwiąż konflikt w zakresie zadania, git commit --no-edit, push (bez konfliktu wystarczy gh pr update-branch %s i git pull)' "$1" "$2" "$1"
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
# and workspace trust”), więc wpis dla /Users/Shared/sh/projekty/NAZWA obejmuje też /Users/Shared/sh/wt/NAZWA/NR. Ręczny
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
