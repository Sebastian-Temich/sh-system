# shctl task create|ready|dispatch|iter|close|resume-check|wait (docs/shctl.md, „task”).
# task close NR --anuluj zastępuje task cancel (alias z ostrzeżeniem do następnej wersji).
# Etap A: każde zadanie ma runner:local i wykonawca:claude, a review robi Codex (shctl review run).
# shellcheck shell=bash

# shellcheck source=../lib/zadania.sh
. "$SHCTL_DIR/lib/zadania.sh"

KROKI='[]'
krok() {
  KROKI="$(jq -c --arg k "$1" '. + [$k]' <<<"$KROKI")"
  info "- $1"
}

# Cytowanie dla powłoki panelu (zsh): pojedyncze apostrofy działają w każdej powłoce POSIX.
cytuj() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

# Jeden argument pozycyjny (NR) i opcje wspólne; reszta to błąd.
NR_ARG=""
argument_nr() {
  NR_ARG=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -*) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
      *)
        [ -z "$NR_ARG" ] || die "$E_UZYCIE" "nadmiarowy argument: $1"
        NR_ARG="$1"
        shift
        ;;
    esac
  done
  [ -n "$NR_ARG" ] || die "$E_UZYCIE" "brak numeru issue (shctl task $SUB NR)"
  NR_ARG="$(numer "${NR_ARG#\#}")"
}

# =========================================================================================
# task create --plik zadania.yaml
# =========================================================================================

JQ_WALIDACJA='
def tekst: type == "string" and length > 0;
def pola: ["id","tytul","cel","kryteria","pliki","testy","zaleznosci","typ","tryb","db_migracja","milestone","waga",
  "kategoria","stack","skille","widoczne"];
def kategorie: ["frontend","backend","baza","integracje","bezpieczenstwo","testy","ci","ai-dane","refaktoryzacja"];
def nazwa: type == "string" and test("^[a-z0-9][a-z0-9._:-]*$");
([.[].id]) as $ids
| [to_entries[] | .key as $k | .value as $z
    | ("zadanie \($k + 1)" + (if ($z.id | type) == "string" then " (\($z.id))" else "" end)) as $kto
    | (if ($z | type) != "object" then "\($kto): oczekiwano mapy pól" else
        (($z | keys) - pola | .[] | "\($kto): nieznane pole \(.)"),
        (if ($z.id | type) != "string" or ($z.id | test("^[A-Za-z0-9._-]+$") | not)
          then "\($kto): id wymagane (litery, cyfry, kropka, _ i -)" else empty end),
        (if ($z.tytul | tekst) then empty else "\($kto): brak tytul" end),
        (if ($z.cel | tekst) then empty else "\($kto): brak cel" end),
        (if ($z.kryteria | type) == "array" and ($z.kryteria | length) > 0 and ($z.kryteria | all(tekst))
          then empty else "\($kto): kryteria to niepusta lista tekstów" end),
        (if ($z.pliki // []) | type == "array" and all(tekst) then empty else "\($kto): pliki to lista tekstów" end),
        (if ($z.testy // "") | type == "string" then empty else "\($kto): testy to tekst" end),
        (if ($z.typ // "feature") | IN("feature", "bug", "qa", "docs", "cr") then empty
          else "\($kto): typ: feature, bug, qa, docs albo cr" end),
        (if ($z.tryb // "") | IN("", "S", "M") then empty else "\($kto): tryb S albo M (L od etapu B)" end),
        (if ($z.db_migracja // false) | type == "boolean" then empty else "\($kto): db_migracja to true albo false" end),
        (if ($z.widoczne // true) | type == "boolean" then empty
          else "\($kto): widoczne to true albo false (false: bez zmian widocznych dla użytkownika)" end),
        (if ($z.milestone // "") | type == "string" then empty else "\($kto): milestone to tekst" end),
        (if ($z.kategoria // "") | . == "" or IN(kategorie[]) then empty
          else "\($kto): kategoria: \(kategorie | join(", "))" end),
        (if ($z.stack // []) | (type == "array" and all(nazwa)) or nazwa then empty
          else "\($kto): stack to nazwa albo lista nazw (małe litery, cyfry, . _ : -)" end),
        (if ($z.skille // []) | type == "array" and all(nazwa) then empty
          else "\($kto): skille to lista nazw skilli" end),
        (if ($z.waga // "") | IN("", "krytyczne", "istotne", "drobne") then empty
          else "\($kto): waga: krytyczne, istotne albo drobne" end),
        (if ($z.typ // "") == "qa" and (($z.waga // "") | IN("krytyczne", "istotne") | not)
          then "\($kto): typ qa wymaga wagi krytyczne albo istotne (drobne idą do „Drobnych uwag” raportu QA)" else empty end),
        (($z.zaleznosci // []) | if type != "array" then "\($kto): zaleznosci to lista"
          else .[] | select((test("^#[0-9]+$") or (. as $d | $ids | index($d)) != null) | not)
            | "\($kto): nieznana zależność \(.)" end)
      end)]
+ ($ids | map(select(type == "string")) | group_by(.) | map(select(length > 1) | "powtórzone id: \(.[0])"))
| .[]'

# Kolejność, w której zależności powstają przed zadaniem; cykl to błąd.
JQ_TOPO='
(map({key: .id, value: [(.zaleznosci // [])[] | select(startswith("#") | not)]}) | from_entries) as $g
| {wynik: [], zostalo: [.[].id]}
| until((.zostalo | length) == 0;
    . as $s
    | [$s.zostalo[] | select(($g[.] - $s.wynik) | length == 0)] as $gotowe
    | if ($gotowe | length) == 0 then error("cykl zależności: " + ($s.zostalo | join(", ")))
      else .wynik += $gotowe | .zostalo -= $gotowe end)
| .wynik[]'

JQ_TRESC='
def warstwy: {kategoria: (.kategoria // null), stack: ([.stack // empty] | flatten), skille: (.skille // [])};
def zal: [(.zaleznosci // [])[] | if startswith("#") then . elif $mapa[.] then "#\($mapa[.])" else "(\(.))" end];
"### Cel\n\n\(.cel | sub("\\s+$"; ""))\n\n"
+ "### Kryteria akceptacji\n\n" + ([.kryteria[] | "- [ ] \(.)"] | join("\n")) + "\n\n"
+ "### Zakres\n\n" + (if ((.pliki // []) | length) > 0 then "Pliki:\n\n" + ([.pliki[] | "- `\(.)`"] | join("\n"))
    else "Obszar opisany w celu." end) + "\n\n"
+ "### Komenda testów\n\n" + (if (.testy // "") != "" then "```sh\n\(.testy)\n```" else "brak" end) + "\n\n"
+ "### Typ\n\n\(.typ // "feature")\n\n"
+ "### Zależności\n\n" + (zal | if length == 0 then "brak" else join(", ") end) + "\n\n"
+ "### Baza danych\n\n- [" + (if .db_migracja then "x" else " " end)
+ "] Zadanie zawiera migrację lub reset bazy (etykieta db:migracja, realizacja pojedynczo)\n\n"
+ (warstwy as $w | if ($w.kategoria // "") == "" and ($w.stack | length) == 0 and ($w.skille | length) == 0 then ""
    else "### Warstwy skilli\n\n- kategoria: \($w.kategoria // "-")\n- stack: \($w.stack | if length == 0 then "-" else join(", ") end)\n"
      + "- skille: \($w.skille | if length == 0 then "-" else join(", ") end)\n\n"
      + "<!-- shctl:warstwy \($w | tojson | @base64) -->\n" end)
+ "<!-- shctl:id=\(.id) -->\n"'

MAPA_START='<!-- shctl:mapa:start -->'
MAPA_KONIEC='<!-- shctl:mapa:end -->'

# Sekcja mapy ID → issue w docs/06-zadania/index.md, poza tabelą sync-status.
aktualizuj_mape() {
  local plik="$ROOT_G/docs/06-zadania/index.md" wiersze stare t
  [ -f "$plik" ] || die "$E_BRAK" "brak docs/06-zadania/index.md"
  wiersze="$(jq -r '.[] | "| \(.id) | #\(.nr) | \(.tytul | gsub("[|\r\n]"; " ")) | \(.zal) |"' <<<"$1")"
  stare=""
  if grep -qxF "$MAPA_START" "$plik"; then
    stare="$(awk -v s="$MAPA_START" -v k="$MAPA_KONIEC" '$0 == s { w = 1; next } $0 == k { w = 0 } w' "$plik" |
      grep -E '^\| [^-]' | grep -vE '^\| ID \|' || true)"
  fi
  t="$(tmp_plik)"
  {
    printf '%s\n' "$stare" | while IFS= read -r l; do
      [ -n "$l" ] || continue
      id="$(printf '%s' "$l" | awk -F'|' '{ gsub(/ /, "", $2); print $2 }')"
      jq -e --arg i "$id" 'any(.[]; .id == $i)' <<<"$1" >/dev/null || printf '%s\n' "$l"
    done
    printf '%s\n' "$wiersze"
  } | awk 'NF' | sort -t'#' -k2 -n >"$t.w"
  if grep -qxF "$MAPA_START" "$plik"; then
    awk -v s="$MAPA_START" -v k="$MAPA_KONIEC" -v w="$t.w" '
      $0 == s { print; print "| ID | Issue | Tytuł | Zależności |"; print "|---|---|---|---|"
        while ((getline l < w) > 0) print l; pomin = 1; next }
      $0 == k { pomin = 0 }
      !pomin { print }' "$plik" >"$t"
  else
    {
      cat "$plik"
      printf '\n## Mapa zadań z planu\n\nSekcję uzupełnia `shctl task create`: ID z pliku YAML i numer issue.\n\n'
      printf '%s\n| ID | Issue | Tytuł | Zależności |\n|---|---|---|---|\n' "$MAPA_START"
      cat "$t.w"
      printf '%s\n' "$MAPA_KONIEC"
    } >"$t"
  fi
  rm -f "$t.w"
  podmien_plik "$t" "$plik"
}

uruchom_sync_status() { odswiez_projekt; }

milestone_istniejace() {
  gh api "repos/$SLUG/milestones?state=all&per_page=100" --paginate 2>/dev/null | jq -sc 'add // [] | map(.title)' ||
    die "$E_WYKONANIE" "nie można odczytać milestone'ów $SLUG"
}

task_create() {
  local plik="" dane lista bledy kolejnosc istn mapa='{}' utw='[]' juz='[]' ms_nowe='[]' ms m id z tytul
  local tresc etyk url nr wiersze
  while [ $# -gt 0 ]; do
    case "$1" in
      --plik) plik="$(wartosc "$@")"; shift 2 ;;
      *) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
    esac
  done
  [ -n "$plik" ] || die "$E_UZYCIE" "użycie: shctl task create --plik zadania.yaml"
  [ -f "$plik" ] || die "$E_BRAK" "brak pliku $plik"
  zadania_init
  [ "$(konf etap_wdrozenia A)" = A ] || uwaga "etap_wdrozenia inny niż A: zadania i tak dostają runner:local i wykonawca:claude"

  dane="$(yq -o=json '.' "$plik" 2>/dev/null)" || die "$E_UZYCIE" "$plik: niepoprawny YAML"
  lista="$(jq -c '
    (if type == "array" then . elif type == "object" and (.zadania | type) == "array" then .zadania
     else error("oczekiwano listy zadań albo klucza zadania") end)
    | map(if type == "object" then
        (if has("db:migracja") then .db_migracja = .["db:migracja"] | del(.["db:migracja"]) else . end)
        | (if .id != null then .id |= tostring else . end)
        | (if .zaleznosci | type == "array" then .zaleznosci |= map(tostring) else . end)
      else . end)' <<<"$dane" 2>"$SHCTL_TMP/jq.err")" || die "$E_UZYCIE" "$plik: $(cat "$SHCTL_TMP/jq.err")"
  [ "$(jq 'length' <<<"$lista")" -gt 0 ] || die "$E_UZYCIE" "$plik: brak zadań"
  bledy="$(jq -r "$JQ_WALIDACJA" <<<"$lista")"
  [ -z "$bledy" ] || die "$E_UZYCIE" "$plik: $(printf '%s' "$bledy" | paste -sd ';' - | sed 's/;/; /g')"
  kolejnosc="$(jq -r "$JQ_TOPO" <<<"$lista" 2>"$SHCTL_TMP/jq.err")" ||
    die "$E_UZYCIE" "$plik: $(sed 's/^jq: error[^:]*: //' "$SHCTL_TMP/jq.err")"

  # Powtórka: issue z tym samym znacznikiem ID już istnieje.
  istn="$(wszystkie_issue | jq -c '
    [.[] | ((.body // "") | [capture("<!-- shctl:id=(?<id>[^ ]+) -->")][0].id) as $id
      | select($id != null) | {id: $id, nr: .number, tytul: .title}]')"
  for id in $kolejnosc; do
    z="$(jq -c --arg i "$id" '.[] | select(.id == $i)' <<<"$lista")"
    tytul="$(jq -r .tytul <<<"$z")"
    nr="$(jq -r --arg i "$id" '[.[] | select(.id == $i)] | min_by(.nr).nr // ""' <<<"$istn")"
    if [ -n "$nr" ]; then
      [ "$(jq -r --arg i "$id" '[.[] | select(.id == $i)] | min_by(.nr).tytul' <<<"$istn")" = "$tytul" ] ||
        die "$E_ODMOWA" "ID $id jest już użyte przez #$nr o innym tytule; ID muszą być unikalne w projekcie"
    fi
  done

  ms="$(jq -c '[.[].milestone // empty] | unique' <<<"$lista")"
  if [ "$(jq length <<<"$ms")" -gt 0 ]; then
    m="$(milestone_istniejace)"
    ms_nowe="$(jq -c --argjson m "$m" '. - $m' <<<"$ms")"
    if [ "$DRY" -eq 0 ]; then
      jq -r '.[]' <<<"$ms_nowe" | while IFS= read -r m; do
        gh api -X POST "repos/$SLUG/milestones" -f "title=$m" >/dev/null ||
          die "$E_WYKONANIE" "nie można utworzyć milestone '$m'"
      done
    fi
    jq -r '.[] | "milestone: " + .' <<<"$ms_nowe" | while IFS= read -r m; do info "- utworzono $m"; done
  fi

  for id in $kolejnosc; do
    z="$(jq -c --arg i "$id" '.[] | select(.id == $i)' <<<"$lista")"
    nr="$(jq -r --arg i "$id" '[.[] | select(.id == $i)] | min_by(.nr).nr // ""' <<<"$istn")"
    if [ -n "$nr" ]; then
      juz="$(jq -c --arg i "$id" '. + [$i]' <<<"$juz")"
      mapa="$(jq -c --arg i "$id" --argjson n "$nr" '. + {($i): $n}' <<<"$mapa")"
      info "$id: istnieje jako #$nr"
      continue
    fi
    tresc="$(tmp_plik)"
    jq -r --argjson mapa "$mapa" "$JQ_TRESC" <<<"$z" >"$tresc"
    etyk="$(jq -r '["status:todo", "runner:local", "wykonawca:claude", "typ:\(.typ // "feature")"]
      + (if (.tryb // "") != "" then ["tryb:\(.tryb)"] else [] end)
      + (if .db_migracja then ["db:migracja"] else [] end)
      + (if .widoczne == false then ["widoczne:nie"] else [] end)
      + (if (.waga // "") != "" then ["sev:\(.waga)"] else [] end) | join(",")' <<<"$z")"
    utw="$(jq -c --arg i "$id" '. + [$i]' <<<"$utw")"
    if [ "$DRY" -eq 1 ]; then
      mapa="$(jq -c --arg i "$id" '. + {($i): null}' <<<"$mapa")"
      info "$id: zostanie utworzone ($etyk)"
      continue
    fi
    m="$(jq -r '.milestone // ""' <<<"$z")"
    if [ -n "$m" ]; then
      url="$(gh issue create --repo "$SLUG" --title "$(jq -r .tytul <<<"$z")" --body-file "$tresc" --label "$etyk" --milestone "$m")" ||
        die "$E_WYKONANIE" "nie można utworzyć issue $id; powtórz komendę, utworzone zostaną pominięte"
    else
      url="$(gh issue create --repo "$SLUG" --title "$(jq -r .tytul <<<"$z")" --body-file "$tresc" --label "$etyk")" ||
        die "$E_WYKONANIE" "nie można utworzyć issue $id; powtórz komendę, utworzone zostaną pominięte"
    fi
    nr="$(numer "$(printf '%s' "$url" | tail -1 | sed 's#.*/##')")"
    mapa="$(jq -c --arg i "$id" --argjson n "$nr" '. + {($i): $n}' <<<"$mapa")"
    info "$id: utworzono #$nr"
  done

  if [ "$DRY" -eq 0 ]; then
    ostrzez_gdy_nie_main
    wiersze="$(jq -c --argjson mapa "$mapa" '
      map(select($mapa[.id] != null) | {id, nr: $mapa[.id], tytul,
        zal: ([(.zaleznosci // [])[] | if startswith("#") then . else "#\($mapa[.])" end]
          | if length == 0 then "-" else join(", ") end)})' <<<"$lista")"
    aktualizuj_mape "$wiersze"
    uruchom_sync_status || true
  fi
  wynik_json "$(jq -nc --argjson m "$mapa" --argjson u "$utw" --argjson j "$juz" --argjson ms "$ms_nowe" \
    '{mapa:$m, utworzone:$u, istniejace:$j, milestone_utworzone:$ms, indeks:"docs/06-zadania/index.md"}')"
}

# =========================================================================================
# task ready
# =========================================================================================

ocena_ready() {
  local ocena
  ocena="$(ocen_gotowe "$(wszystkie_issue)" "$(panele_herdr)" "")"
  jq -c '. + {mozna_dispatch: ((.blokady | length) == 0 and (.kandydaci | length) > 0),
    gotowe: (if (.blokady | length) == 0 then .kandydaci else [] end)}' <<<"$ocena"
}

# --czekaj: czeka, aż blokada slotu, kolejki review, dysku albo limitu zejdzie, gdy są kandydaci.
# Bez kandydatów czekanie nic nie da (zależności zamyka orkiestrator), więc wynik wraca od razu.
task_ready() {
  local wynik czekaj=0 timeout=1800 start_s t=0 pauza
  while [ $# -gt 0 ]; do
    case "$1" in
      --czekaj) czekaj=1; shift ;;
      --timeout) timeout="$(wartosc "$@")"; shift 2 ;;
      *) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
    esac
  done
  timeout="$(numer "$timeout")"
  zadania_init
  herdr_dziala
  start_s="$(date +%s)"
  while :; do
    wynik="$(ocena_ready)"
    [ "$czekaj" -eq 1 ] || break
    jq -e '(.blokady | length) > 0 and (.kandydaci | length) > 0' <<<"$wynik" >/dev/null || break
    t=$(($(date +%s) - start_s))
    [ "$t" -lt "$timeout" ] || break
    pauza="${SHCTL_READY_PAUZA:-30}"
    [ $((timeout - t)) -ge "$pauza" ] || pauza=$((timeout - t))
    sleep "$pauza"
  done
  t=$(($(date +%s) - start_s))
  wynik="$(jq -c --argjson t "$t" --argjson c "$czekaj" \
    '. + {czekano_s:$t, limit_czasu:($c == 1 and (.blokady | length) > 0 and (.kandydaci | length) > 0)}' <<<"$wynik")"
  if [ "$JSON" -eq 0 ]; then
    jq -r '
      (if (.blokady | length) > 0 then "Dispatch wstrzymany:", (.blokady[] | "  - \(.opis)") else empty end),
      "Gotowe: " + (if (.gotowe | length) == 0 then "brak" else (.gotowe | map("#\(.nr) \(.tytul)") | join(", ")) end),
      (if (.zablokowane | length) > 0 then "Czekają:", (.zablokowane[] | "  #\(.nr): \(.powody | join("; "))") else empty end),
      "Sloty: \(.sloty.aktywne)/\(.sloty.max_local), kolejka review: \(.kolejka_review.czeka)/\(.kolejka_review.max), wolne \(.wolne_gb) GB"
        + (if .czekano_s > 0 then ", czekano \(.czekano_s) s" else "" end)' <<<"$wynik"
  fi
  wynik_json "$wynik"
}

# =========================================================================================
# task dispatch NR
# =========================================================================================

polecenie_workera() {
  local kat="$1" prompt="$2" m c
  m="$(model_workera)"
  c="cd $(cytuj "$kat") && claude --settings .claude/roles/worker/settings.json"
  [ "$m" = domyslny ] || c="$c --model $(cytuj "$m")"
  printf '%s %s' "$c" "$(cytuj "$prompt")"
}

# Warstwy skilli workera (plugin/warstwy-skilli.yaml, lib/zadania.sh): bazowe + kategoria + stack +
# skille z zadania + skille projektu (.claude/skills w worktree, zawsze). Kategoria, stack i skille są
# w znaczniku shctl:warstwy w treści issue (task create). Skill bez SKILL.md w pluginie (także
# skills/techniczne/), projekcie ani ~/.claude/skills jest pomijany z ostrzeżeniem, a dispatch idzie dalej.
SKILLE_W='{"skille":[],"brak":[]}'

skill_istnieje() {
  local n="${2##*:}" d
  [ -z "$(plik_skilla_pluginu "$n")" ] || return 0
  for d in "$1/.claude/skills" "$HOME/.claude/skills"; do
    [ ! -f "$d/$n/SKILL.md" ] || return 0
  done
  return 1
}

# Ustawia SKILLE_W {skille, brak} dla issue (JSON) i worktree workera.
skille_workera() {
  local j="$1" kat="$2" w mapa lista n ok='[]' brak='[]' d
  w="$(warstwy_issue "$j")"
  mapa="$(mapa_warstw)"
  lista="$(jq -c --argjson m "$mapa" '
    ($m.bazowe // [])
    + (if (.kategoria // "") != "" then ($m.kategoria[.kategoria] // ["sh-kat-" + .kategoria]) else [] end)
    + ((.stack // []) | map($m.stack[.] // ["sh-stack-" + .]) | add // [])
    + (.skille // [])' <<<"$w")"
  for d in "$kat/.claude/skills"/*/SKILL.md; do
    [ -f "$d" ] || continue
    lista="$(jq -c --arg n "$(basename "$(dirname "$d")")" '. + [$n]' <<<"$lista")"
  done
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    if skill_istnieje "$kat" "$n"; then ok="$(jq -c --arg n "$n" '. + [$n]' <<<"$ok")"
    else brak="$(jq -c --arg n "$n" '. + [$n]' <<<"$brak")"; uwaga "brak skilla $n (warstwy skilli); worker go nie wczyta"; fi
  done < <(jq -r 'reduce .[] as $s ([]; if index([$s]) then . else . + [$s] end) | .[]' <<<"$lista")
  SKILLE_W="$(jq -nc --argjson s "$ok" --argjson b "$brak" '{skille:$s, brak:$b}')"
}

# Dopisek do polecenia workera: skille do wczytania przed pracą. Skille techniczne
# (plugin/skills/techniczne/) worker czyta jako pliki, bo Claude Code ładuje z pluginu tylko
# skills/NAZWA/SKILL.md; kolejność ważności przy sprzeczności: plugin/skills/_kontrakt.md.
z_skillami() {
  local n p s='' t='' wynik="$1"
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    p="$(plik_skilla_pluginu "$n")"
    case "$p" in
      */techniczne/*) t="${t:+$t, }$(cd -P "$(dirname "$p")" && pwd -P)/SKILL.md" ;;
      *) s="${s:+$s, }$n" ;;
    esac
  done < <(jq -r '.skille[]' <<<"$SKILLE_W")
  [ -z "$s" ] || wynik="$wynik Przed pracą wczytaj skille: $s."
  [ -z "$t" ] || wynik="$wynik Przeczytaj skille techniczne (przy sprzeczności wygrywa projekt, potem stack, kategoria, bazowe): $t."
  printf '%s' "$wynik"
}

galaz_zadania() {
  local nr="$1" tytul="$2" b s
  b="$(git -C "$ROOT_G" for-each-ref --format='%(refname:short)' "refs/heads/task/$nr-*" | head -1)"
  if [ -n "$b" ]; then printf '%s' "$b"; return; fi
  s="$(odslugifikuj "$tytul" | cut -c1-40 | sed -E 's/-+$//')"
  if [ -n "$s" ]; then printf 'task/%s-%s' "$nr" "$s"; else printf 'task/%s' "$nr"; fi
}

# Worktree workera na gałęzi zadania: istniejąca gałąź lokalna, zdalna albo nowa od main.
utworz_worktree_workera() {
  local kat="$1" br="$2"
  worktree_tego_repo "$kat" && return 0
  mkdir -p "$WT"
  pobierz_main
  if git -C "$ROOT_G" show-ref --verify -q "refs/heads/$br"; then
    git -C "$ROOT_G" worktree add -q "$kat" "$br" || die "$E_WYKONANIE" "git worktree add $kat nie powiódł się"
    return 0
  fi
  z_limitem 120 git -C "$ROOT_G" fetch -q origin "$br" 2>/dev/null || true
  if git -C "$ROOT_G" rev-parse -q --verify "refs/remotes/origin/$br" >/dev/null; then
    git -C "$ROOT_G" worktree add -q -b "$br" "$kat" "origin/$br" || die "$E_WYKONANIE" "git worktree add $kat nie powiódł się"
  else
    git -C "$ROOT_G" worktree add -q -b "$br" "$kat" "$(baza_main)" || die "$E_WYKONANIE" "git worktree add $kat nie powiódł się"
  fi
}

# Pliki env do worktree workera: .env.local i env_files z konfiguracja.md (ścieżki względne).
pliki_env() {
  printf '.env.local\n'
  yq --front-matter=extract '.env_files // [] | .[]' "$KONFIG" 2>/dev/null || true
}

kopiuj_env() {
  local kat="$1" f skop='[]'
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in /* | ..* | */../* | */..) die "$E_UZYCIE" "env_files: tylko ścieżki względne w projekcie, bez ..: $f" ;; esac
    if [ ! -f "$ROOT_G/$f" ]; then
      uwaga "brak $f w $ROOT_G; worker go nie dostanie"
      continue
    fi
    skop="$(jq -c --arg f "$f" '. + [$f]' <<<"$skop")"
    [ "$DRY" -eq 0 ] || continue
    mkdir -p "$(dirname "$kat/$f")"
    cmp -s "$ROOT_G/$f" "$kat/$f" || cp -p "$ROOT_G/$f" "$kat/$f"
    chmod go-rwx "$kat/$f" 2>/dev/null || true
  done < <(pliki_env | awk '!w[$0]++')
  printf '%s' "$skop"
}

# Wersja Node z .nvmrc albo .node-version zainstalowana przed startem panelu: inaczej fnm --use-on-cd
# w powłoce panelu pyta o instalację i worker stoi (iskt-www #44). Błąd to tylko ostrzeżenie.
przygotuj_node() {
  [ -f "$1/.nvmrc" ] || [ -f "$1/.node-version" ] || return 0
  command -v fnm >/dev/null || return 0
  (cd "$1" && z_limitem "${SHCTL_FNM_LIMIT:-300}" fnm install --progress=never </dev/null >/dev/null 2>&1) ||
    uwaga "fnm install w $1 nie powiódł się; panel może pytać o wersję Node"
}

task_dispatch() {
  local nr j st label panele pane stan issues ocena powody br kat env uruchom=0 cmd start zmiana=0 iter zaufanie esk
  argument_nr "$@"
  nr="$NR_ARG"
  zadania_init
  herdr_dziala
  j="$(issue_json "$nr")"
  [ "$(jq -r .state <<<"$j")" = OPEN ] || die "$E_ODMOWA" "issue #$nr jest zamknięte"
  st="$(status_issue "$j")"
  label="$(etykieta_workera "$nr")"
  panele="$(panele_herdr)"
  pane="$(panel_po_etykiecie "$panele" "$label")"
  stan="$(stan_zadania "$nr")"

  case "$st" in
    todo | "")
      issues="$(wszystkie_issue)"
      ocena="$(ocen_gotowe "$issues" "$panele" "$label")"
      powody="$(jq -r '.blokady | map(.opis) | join("; ")' <<<"$ocena")"
      [ -z "$powody" ] || die "$E_ODMOWA" "dispatch #$nr wstrzymany: $powody"
      if ! jq -e --argjson n "$nr" 'any(.kandydaci[]; .nr == $n)' <<<"$ocena" >/dev/null; then
        powody="$(jq -r --argjson n "$nr" '[.zablokowane[] | select(.nr == $n) | .powody[]] | join("; ")' <<<"$ocena")"
        die "$E_ODMOWA" "#$nr nie jest gotowe: ${powody:-brak statusu todo}"
      fi
      zmiana=1
      ;;
    in-progress)
      info "#$nr jest w toku: dokańczam dispatch bez bramek zależności"
      if [ -z "$pane" ]; then
        # Nowy panel zajmuje slot, więc obowiązują bramki slotów, dysku i limitów (np. po eskalacji).
        ocena="$(ocen_gotowe "$(wszystkie_issue)" "$panele" "$label")"
        powody="$(jq -r '.blokady | map(select(.rodzaj != "kolejka_review") | .opis) | join("; ")' <<<"$ocena")"
        [ -z "$powody" ] || die "$E_ODMOWA" "dispatch #$nr wstrzymany: $powody"
        esk="$(panel_po_etykiecie "$panele" "$(etykieta_eskalacji "$nr")")"
        if [ -n "$esk" ]; then
          krok "panel $esk wraca z eskalacji jako $label"
          zmiana=1
          [ "$DRY" -eq 1 ] || herdr pane rename "$esk" "$label" >/dev/null || die "$E_WYKONANIE" "nie można zmienić etykiety panelu $esk"
          pane="$esk"
        fi
      fi
      ;;
    *) die "$E_ODMOWA" "#$nr ma status $st; dispatch tylko z status:todo" ;;
  esac

  br="$(galaz_zadania "$nr" "$(jq -r .title <<<"$j")")"
  kat="$WT/$nr"
  sprawdz_wolny_katalog "$kat"
  worktree_tego_repo "$kat" || { krok "worktree $kat na gałęzi $br"; zmiana=1; }
  if [ "$DRY" -eq 0 ]; then
    ostrzez_gdy_nie_main
    utworz_worktree_workera "$kat" "$br"
    [ "$(git -C "$kat" symbolic-ref --short -q HEAD || true)" = "$br" ] ||
      die "$E_ODMOWA" "$kat jest na innej gałęzi niż $br"
  fi
  env="$(kopiuj_env "$kat")"
  krok "env: $(jq -r 'if length == 0 then "brak plików" else join(", ") end' <<<"$env")"
  if [ "$DRY" -eq 0 ] && [ ! -f "$kat/.claude/roles/worker/settings.json" ]; then
    die "$E_BRAK" "brak .claude/roles/worker/settings.json w $kat (szablon projektu)"
  fi

  [ "$DRY" -eq 1 ] || przygotuj_node "$kat"
  zaufanie="$(zaufaj_projektowi)"
  [ "$zaufanie" = false ] || krok "zaufanie folderu Claude Code dla $ROOT_G (~/.claude.json)"
  skille_workera "$j" "$kat"
  krok "skille: $(jq -r '(.skille | if length == 0 then "brak" else join(", ") end) + (if (.brak | length) > 0 then " (brak: " + (.brak | join(", ")) + ")" else "" end)' <<<"$SKILLE_W")"
  cmd="$(polecenie_workera "$kat" "$(z_skillami "Zrealizuj issue #$nr skillem sh-worker.")")"
  if [ -z "$pane" ]; then
    krok "panel $label i start claude (model $(model_workera))"
    uruchom=1
    zmiana=1
    [ "$DRY" -eq 1 ] || pane="$(otworz_panel "$label" "$kat")"
  elif [ "$(jq -r '.panel // ""' <<<"$stan")" = "$pane" ] && [ "$(jq -r '.uruchomiono // false' <<<"$stan")" = true ]; then
    info "panel $pane ($label) już działa"
  elif [ -n "$(jq -r --arg p "$pane" '.[] | select(.pane_id == $p) | .agent' <<<"$panele")" ]; then
    info "w panelu $pane działa już agent"
  else
    krok "start claude w panelu $pane"
    uruchom=1
    zmiana=1
  fi

  iter="$(iteracja_issue "$j")"
  [ "$iter" -gt 0 ] || iter=1
  if [ "$DRY" -eq 0 ]; then
    start="$(jq -r '.start // ""' <<<"$stan")"
    [ -n "$start" ] || start="$(teraz_utc)"
    stan_zapisz "$nr" "$(jq -nc --arg p "$pane" --arg l "$label" --arg w "$kat" --arg g "$br" --arg s "$start" \
      --argjson i "$iter" '{panel:$p, label:$l, worktree:$w, galaz:$g, start:$s, iteracja:$i}')"
    if [ "$uruchom" -eq 1 ]; then
      stan_zapisz "$nr" '{"uruchomiono":false}'
      herdr pane run "$pane" "$cmd" >/dev/null || die "$E_WYKONANIE" "nie można uruchomić claude w panelu $pane"
      stan_zapisz "$nr" "$(jq -nc --arg t "$(teraz_utc)" '{uruchomiono:true, polecenie:$t, tura:false}')"
    fi
    ustaw_status "$nr" "$j" status:in-progress
    [ "$(iteracja_issue "$j")" -gt 0 ] || zmien_etykiety "$nr" "$j" iter:1 ""
  fi
  [ "$st" = in-progress ] && [ "$(iteracja_issue "$j")" -gt 0 ] || krok "etykiety status:in-progress, iter:$iter"

  info "#$nr: $( [ "$zmiana" -eq 1 ] && echo "dispatch" || echo "bez zmian") ($label, $kat)"
  wynik_json "$(jq -nc --argjson n "$nr" --arg g "$br" --arg w "$kat" --arg p "$pane" --arg l "$label" \
    --argjson e "$env" --argjson u "$uruchom" --argjson z "$zmiana" --argjson k "$KROKI" --arg c "$cmd" \
    --argjson zf "$zaufanie" --argjson sk "$SKILLE_W" \
    '{nr:$n, galaz:$g, worktree:$w, panel:$p, label:$l, env:$e, uruchomiono:($u == 1), polecenie:$c,
      skille:$sk.skille, skille_brak:$sk.brak, zaufanie_dopisane:$zf, zmiana:($z == 1), kroki:$k}')"
}

# =========================================================================================
# task iter NR
# =========================================================================================

task_iter() {
  local nr j pr prn head rev stan iter cel label pane kat msg wyn esk wyslano pol zmiana=1
  argument_nr "$@"
  nr="$NR_ARG"
  zadania_init
  j="$(issue_json "$nr")"
  [ "$(jq -r .state <<<"$j")" = OPEN ] || die "$E_ODMOWA" "issue #$nr jest zamknięte"
  pr="$(pr_zadania "$nr")"
  [ -n "$pr" ] && [ "$(jq -r .state <<<"$pr")" = OPEN ] || die "$E_ODMOWA" "#$nr nie ma otwartego PR"
  prn="$(jq -r .number <<<"$pr")"
  head="$(jq -r .headRefOid <<<"$pr")"
  stan="$(stan_zadania "$nr")"

  # Powtórka dla tego samego review nie podbija licznika drugi raz.
  if [ "$(jq -r '.iter_review // ""' <<<"$stan")" = "$head" ]; then
    cel="$(jq -r '.iter_cel' <<<"$stan")"
    wyslano="$(jq -r '.iter_wyslano // false' <<<"$stan")"
    [ "$wyslano" != true ] || zmiana=0
  else
    rev="$(review_dla_heada "$prn" "$head")"
    [ -n "$rev" ] || die "$E_ODMOWA" "brak wyniku shctl review run dla bieżącego commita PR #$prn"
    [ "$(jq -r .werdykt <<<"$rev")" = FAIL ] ||
      die "$E_ODMOWA" "ostatnie review PR #$prn to PASS; iteracja tylko po FAIL"
    iter="$(iteracja_issue "$j")"
    [ "$iter" -gt 0 ] || iter=1
    cel=$((iter + 1))
    wyslano=false
  fi

  if [ "$cel" -gt "$MAKS_ITERACJI" ]; then
    info "#$nr: FAIL w iteracji $MAKS_ITERACJI, eskalacja"
    set -- escalate --projekt "$PROJEKT" --dotyczy "#$nr" --powod "$MAKS_ITERACJI iteracje bez PASS" \
      --potrzebne "decyzja: dalsze poprawki poza limitem, zmiana zakresu albo anulowanie zadania (PR #$prn)" --json
    [ "$DRY" -eq 0 ] || set -- "$@" --dry-run
    wyn="$("$SHCTL_DIR/shctl" "$@")" || die "$E_WYKONANIE" "shctl escalate nie powiódł się: $(jq -r '.blad // ""' <<<"$wyn" 2>/dev/null)"
    esk="$(jq -r '.wynik.id' <<<"$wyn")"
    stan_zapisz "$nr" "$(jq -nc --arg e "$esk" '{eskalacja:$e}')"
    wynik_json "$(jq -nc --argjson n "$nr" --argjson p "$prn" --argjson i "$MAKS_ITERACJI" --arg e "$esk" \
      --argjson w "$(jq -c .wynik <<<"$wyn")" \
      '{nr:$n, pr:$p, iteracja:$i, eskalacja:$e, eskalowano:true, szczegoly:$w}')"
    return 0
  fi

  label="$(etykieta_workera "$nr")"
  kat="$WT/$nr"
  msg="Iteracja $cel/$MAKS_ITERACJI zadania #$nr: popraw wyłącznie zgłoszenia 🔴 i 🟡 z ostatniego review Codexa w PR #$prn (komentarz „Review Codex: FAIL” dla commita ${head:0:7}). Nie zmieniaj niczego poza nimi, uruchom testy i wypchnij poprawki na gałąź PR."
  if [ "$DRY" -eq 0 ] && [ "$wyslano" != true ]; then
    herdr_dziala
    stan_zapisz "$nr" "$(jq -nc --arg h "$head" --argjson c "$cel" '{iter_review:$h, iter_cel:$c, iter_wyslano:false}')"
    zmien_etykiety "$nr" "$j" "iter:$cel" "$(jq -r --arg c "iter:$cel" '[.labels[].name | select(startswith("iter:") and . != $c)] | join(" ")' <<<"$j")"
    ustaw_status "$nr" "$(issue_json "$nr")" status:in-progress
    pane="$(panel_po_etykiecie "$(panele_herdr)" "$label")"
    pol="$(teraz_utc)"
    if [ -n "$pane" ]; then
      herdr pane run "$pane" "$msg" >/dev/null || die "$E_WYKONANIE" "nie można wysłać polecenia do panelu $pane"
    else
      worktree_tego_repo "$kat" || die "$E_ODMOWA" "brak panelu $label i worktree $kat; sprawdź shctl task resume-check $nr"
      zaufaj_projektowi >/dev/null
      skille_workera "$j" "$kat"
      pane="$(otworz_panel "$label" "$kat")"
      herdr pane run "$pane" "$(polecenie_workera "$kat" "$(z_skillami "$msg")")" >/dev/null ||
        die "$E_WYKONANIE" "nie można uruchomić claude w panelu $pane"
    fi
    stan_zapisz "$nr" "$(jq -nc --arg p "$pane" --arg l "$label" --argjson c "$cel" --arg t "$pol" '{panel:$p, label:$l, iteracja:$c, iter_wyslano:true, uruchomiono:true, polecenie:$t, tura:false}')"
  fi
  if [ "$zmiana" -eq 1 ]; then info "#$nr: iteracja $cel, polecenie wysłane do $label"; else info "#$nr: iteracja $cel już wysłana"; fi
  wynik_json "$(jq -nc --argjson n "$nr" --argjson p "$prn" --argjson c "$cel" --arg m "$msg" --argjson z "$zmiana" \
    '{nr:$n, pr:$p, iteracja:$c, eskalowano:false, polecenie:$m, zmiana:($z == 1)}')"
}

# =========================================================================================
# task close NR
# =========================================================================================

# Pozycje sekcji raportu: punkty listy (z kontynuacją) albo akapity; „brak” pomijamy.
pozycje() {
  awk '
    /^[[:space:]]*<!--/ { next }
    /^[-*] / { if (b != "") print b; b = substr($0, 3); next }
    /^[0-9]+\. / { if (b != "") print b; sub(/^[0-9]+\. /, ""); b = $0; next }
    /^[[:space:]]*$/ { if (b != "") print b; b = ""; next }
    { sub(/^[[:space:]]+/, ""); b = (b == "" ? $0 : b " " $0) }
    END { if (b != "") print b }' |
    grep -viE '^[[:space:](*_]*(brak|nie ma|nic|-|—)[[:space:].)*_]*$' || true
}

dopisz_wiersz() {
  local plik="$1"
  [ -f "$plik" ] || die "$E_BRAK" "brak $plik"
  [ -z "$(tail -c1 "$plik")" ] || printf '\n' >>"$plik"
  printf '%s\n' "$2" >>"$plik"
}

# Wiersz zadania na końcu ostatniej tabeli metryk (nagłówek „| Zlecenie |”): w sh-dryrun każdy
# przebieg ma własną tabelę, a opisy przebiegu pod nią nie przechwytują wierszy. Bez tabeli: koniec pliku.
dopisz_metryke() {
  local plik="$1" t
  [ -f "$plik" ] || die "$E_BRAK" "brak $plik"
  if ! grep -q '^| Zlecenie |' "$plik"; then
    dopisz_wiersz "$plik" "$2"
    return 0
  fi
  t="$(tmp_plik)"
  WIERSZ="$2" awk '
    { l[NR] = $0 }
    /^\| Zlecenie \|/ { h = NR }
    END {
      k = h
      while (k < NR && l[k + 1] ~ /^\|/) k++
      for (i = 1; i <= NR; i++) { print l[i]; if (i == k) print ENVIRON["WIERSZ"] }
    }' "$plik" >"$t"
  podmien_plik "$t" "$plik"
}

# Przyczyny uwag review (templates/review.md): wiersz w tabeli „| Źródło | Wymaganie |” w metryki.md,
# na końcu ostatniej takiej tabeli. Bez niej (projekt sprzed F4) shctl wstawia sekcję „## Przyczyny uwag”
# zaraz pod ostatnią tabelą metryk („| Zlecenie |”), a bez niej na końcu pliku.
NAGLOWEK_PRZYCZYN='| Źródło | Wymaganie | Kod | Test | Design | Bez przyczyny |'
dopisz_przyczyny() {
  local plik="$1" t
  [ -f "$plik" ] || die "$E_BRAK" "brak $plik"
  t="$(tmp_plik)"
  WIERSZ="$2" NAGL="$NAGLOWEK_PRZYCZYN" awk '
    { l[NR] = $0 }
    $0 == ENVIRON["NAGL"] { h = NR }
    /^\| Zlecenie \|/ { m = NR }
    END {
      nowa = 0
      if (h) k = h
      else if (m) { k = m; nowa = 1 }
      else { k = NR; nowa = 1 }
      if (k) while (k < NR && l[k + 1] ~ /^\|/) k++
      if (NR == 0) k = 0
      for (i = 1; i <= NR; i++) {
        print l[i]
        if (i == k) {
          if (nowa) printf "\n## Przyczyny uwag\n\n%s\n|---|---|---|---|---|---|\n", ENVIRON["NAGL"]
          print ENVIRON["WIERSZ"]
        }
      }
      if (k == 0) {
        printf "## Przyczyny uwag\n\n%s\n|---|---|---|---|---|---|\n", ENVIRON["NAGL"]
        print ENVIRON["WIERSZ"]
      }
    }' "$plik" >"$t"
  podmien_plik "$t" "$plik"
}

# Zgłoszenia ze wszystkich review PR (ostatni komentarz dla każdego commita) policzone według przyczyny:
# {wymaganie, kod, test, design, brak, razem}.
przyczyny_pr() {
  local j
  j="$(gh pr view "$1" --repo "$SLUG" --json comments 2>/dev/null)" || j='{"comments":[]}'
  jq -c "$JQ_PARSUJ_REVIEW"'
    [.comments[].body | select(contains("<!-- shctl:review head="))
      | (capture("<!-- shctl:review head=(?<h>[0-9a-f]+) ").h) as $h
      | if test("<!-- shctl:review-dane [A-Za-z0-9+/=]+ -->")
        then capture("<!-- shctl:review-dane (?<d>[A-Za-z0-9+/=]+) -->").d | @base64d | fromjson
        else parsuj_review($h) end
      | {head: $h, zgloszenia}]
    | [group_by(.head)[] | last.zgloszenia[]] as $z
    | {wymaganie: ([$z[] | select(.przyczyna == "wymaganie")] | length),
       kod: ([$z[] | select(.przyczyna == "kod")] | length),
       test: ([$z[] | select(.przyczyna == "test")] | length),
       design: ([$z[] | select(.przyczyna == "design")] | length),
       brak: ([$z[] | select((.przyczyna // "") == "")] | length),
       razem: ($z | length)}' <<<"$j" 2>/dev/null || echo '{"razem":0}'
}

przenies_decyzje() {
  local tekst="$1" zr="$2" p d l n=0
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    case "$l" in
      *" → "*) p="${l%% → *}"; d="${l#* → }" ;;
      *" -> "*) p="${l%% -> *}"; d="${l#* -> }" ;;
      *) p="-"; d="$l" ;;
    esac
    p="$(komorka "$p")"
    d="$(komorka "$d")"
    grep -qF "| $zr | $p | $d |" "$ROOT_G/docs/decyzje.md" && continue
    dopisz_wiersz "$ROOT_G/docs/decyzje.md" "| $(dzis) | $zr | $p | $d |"
    n=$((n + 1))
  done < <(printf '%s\n' "$tekst" | pozycje)
  echo "$n"
}

przenies_uwagi() {
  local tekst="$1" zr="$2" u l n=0
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    u="$(komorka "$l")"
    grep -qF "| $zr | $u |" "$ROOT_G/docs/backlog-drobne.md" && continue
    dopisz_wiersz "$ROOT_G/docs/backlog-drobne.md" "| $(dzis) | $zr | $u | otwarta |"
    n=$((n + 1))
  done < <(printf '%s\n' "$tekst" | pozycje)
  echo "$n"
}

wpis_changelog() {
  local plik="$ROOT_G/CHANGELOG.md" linia="$1" nr="$2" obecne
  [ -f "$plik" ] || die "$E_BRAK" "brak CHANGELOG.md"
  obecne="$(czytaj_sekcje "$plik" Niewydane)"
  if printf '%s\n' "$obecne" | grep -qF -- "- #$nr: "; then return 1; fi
  ustaw_sekcje "$plik" Niewydane "${obecne:+$obecne
}$linia"
}

# Propozycje dla systemu: jedno otwarte issue miesiąca w sh-system (etykieta propozycja, tytuł
# „Propozycje RRRR-MM”), każda propozycja to komentarz. Znacznik w komentarzu chroni przed dublowaniem.
# Gdy issue miesiąca nie ma (albo zostało zamknięte), task close zakłada nowe.
SH_SYSTEM_DIR="${SH_SYSTEM_DIR:-$SH_DIR/sh-system}"
miesiac_propozycji() { printf '%s' "${SHCTL_MIESIAC:-$(date +%Y-%m)}"; }

issue_propozycji() {
  local nr="$1" tekst="$2" sys="$SH_SYSTEM_DIR" sslug tytul znacznik n url t
  [ -d "$sys/.git" ] || { uwaga "brak repo sh-system w $sys; propozycje zostają w raporcie"; return 1; }
  sslug="$(git -C "$sys" config --get remote.origin.url | sed -nE 's#^(https://github\.com/|git@github\.com:)([^/]+/[^/]+)$#\2#p' | sed 's/\.git$//')"
  [ -n "$sslug" ] || { uwaga "origin sh-system nie wskazuje GitHuba"; return 1; }
  tytul="Propozycje $(miesiac_propozycji)"
  znacznik="<!-- propozycje:$PROJEKT:T-$nr -->"
  n="$(gh issue list --repo "$sslug" --label propozycja --state open --limit 100 --json number,title |
    jq -r --arg t "$tytul" '[.[] | select(.title == $t)] | min_by(.number).number // ""')" ||
    { uwaga "nie można sprawdzić issue propozycji w $sslug"; return 1; }
  if [ -n "$n" ]; then
    url="https://github.com/$sslug/issues/$n"
    if gh issue view "$n" --repo "$sslug" --json comments | jq -e --arg z "$znacznik" 'any((.comments // [])[]; .body | contains($z))' >/dev/null; then
      printf '%s' "$url"
      return 0
    fi
  fi
  [ "$DRY" -eq 0 ] || { printf 'do dopisania: %s' "${url:-$tytul (nowe issue)}"; return 0; }
  if [ -z "$n" ]; then
    gh label create propozycja --repo "$sslug" --color C5DEF5 --description "Propozycje dla systemu z raportów zadań" --force >/dev/null 2>&1 || true
    url="$(gh issue create --repo "$sslug" --title "$tytul" --label propozycja \
      --body "Propozycje dla systemu z raportów zadań (sekcja „Propozycje dla systemu” w \`docs/07-realizacja/T-NR.md\`). Każda propozycja to komentarz; kolejne dopisuje \`shctl task close\`. Decyzję podejmuje retro.")" ||
      { uwaga "gh issue create w $sslug nie powiódł się"; return 1; }
    url="$(printf '%s' "$url" | tail -1)"
    n="${url##*/}"
  fi
  t="$(tmp_plik)"
  printf '**Propozycje: %s T-%s** (%s)\n\n%s\n\n%s\n' "$PROJEKT" "$nr" "$(dzis)" "$tekst" "$znacznik" >"$t"
  gh issue comment "$n" --repo "$sslug" --body-file "$t" >/dev/null || { uwaga "komentarz propozycji w $sslug#$n nie powstał"; return 1; }
  printf '%s' "$url"
}

# Odbiór zlecenia S (konfiguracja.md, odbior_S): reczny (domyślnie) wymaga --odbior, czyli odpowiedzi
# właściciela „odbieram #NR”; auto_bez_zmian_widocznych przepuszcza zlecenie z etykietą widoczne:nie
# (bez zmian widocznych dla użytkownika) i po merge'u powiadamia. Dawne auto_merge_S: true bez odbior_S
# działa jak dotąd (bez bramki). Wypisuje: odbior, auto albo brak (nie S).
tryb_odbioru_s() {
  local j="$1" o
  jq -e '[.labels[].name] | index("tryb:S")' <<<"$j" >/dev/null || { echo brak; return 0; }
  o="$(konf odbior_S "")"
  if [ -z "$o" ]; then
    [ "$(konf auto_merge_S false)" != true ] || { echo auto; return 0; }
    o=reczny
  fi
  case "$o" in
    reczny) echo odbior ;;
    auto_bez_zmian_widocznych)
      if jq -e '[.labels[].name] | index("widoczne:nie")' <<<"$j" >/dev/null; then echo auto; else echo odbior; fi ;;
    *) die "$E_BRAK" "konfiguracja.md: odbior_S='$o', dozwolone reczny albo auto_bez_zmian_widocznych" ;;
  esac
}

task_close() {
  local nr j pr prn prst head ci rev kat label raport dec uw prop prop_url="" tytul tryb_z iter czas esk f
  local bledy=0 d_n=0 u_n=0 r_n=0 metr=false chlog=false st_rev rev_plik pyt uw_m pz odb
  argument_nr "$@"
  nr="$NR_ARG"
  zadania_init
  j="$(issue_json "$nr")"
  tytul="$(jq -r .title <<<"$j")"
  pr="$(pr_zadania "$nr")"
  [ -n "$pr" ] || die "$E_ODMOWA" "#$nr nie ma PR"
  prn="$(jq -r .number <<<"$pr")"
  prst="$(jq -r .state <<<"$pr")"
  head="$(jq -r .headRefOid <<<"$pr")"
  kat="$WT/$nr"
  label="$(etykieta_workera "$nr")"
  [ "$(git -C "$ROOT_G" symbolic-ref --short -q HEAD || true)" = main ] ||
    die "$E_ODMOWA" "task close działa na main; $ROOT_G jest na innej gałęzi"

  if [ "$prst" = OPEN ]; then
    ci="$(gh pr view "$prn" --repo "$SLUG" --json statusCheckRollup | jq -r "$JQ_CI"' ci')" ||
      die "$E_WYKONANIE" "nie można odczytać CI PR #$prn"
    if [ "$ci" != pass ] && [ "$(mergeable_pr "$prn")" = CONFLICTING ]; then
      die "$E_ODMOWA" "$(komunikat_konfliktu "$prn" "$(jq -r .headRefName <<<"$pr")")"
    fi
    [ "$ci" = pass ] || die "$E_ODMOWA" "CI PR #$prn: $ci; merge tylko przy zielonym CI"
    rev="$(review_dla_heada "$prn" "$head")"
    st_rev="$(jq -r '.werdykt // "brak"' <<<"${rev:-null}")"
    [ "$st_rev" = PASS ] || die "$E_ODMOWA" "PR #$prn nie ma werdyktu PASS dla commita ${head:0:7} (jest: $st_rev)"
    odb="$(tryb_odbioru_s "$j")"
    if [ "$odb" = odbior ] && [ "${ODBIOR:-0}" -eq 0 ]; then
      die "$E_ODMOWA" "zlecenie S #$nr czeka na odbiór właściciela (odbior_S=$(konf odbior_S reczny)); po jego „odbieram #${nr}” powtórz z --odbior"
    fi
    if worktree_tego_repo "$kat"; then
      [ -z "$(git -C "$kat" status --porcelain)" ] || die "$E_ODMOWA" "$kat ma niezacommitowane zmiany"
      [ "$(git -C "$kat" rev-parse HEAD)" = "$head" ] || die "$E_ODMOWA" "$kat ma commity spoza PR #$prn (HEAD różny od PR)"
    fi
    krok "merge (squash) PR #$prn"
    [ "$DRY" -eq 1 ] || gh pr merge "$prn" --repo "$SLUG" --squash --match-head-commit "$head" >/dev/null ||
      die "$E_WYKONANIE" "gh pr merge #$prn nie powiódł się"
  elif [ "$prst" != MERGED ]; then
    die "$E_ODMOWA" "PR #$prn ma stan $prst"
  fi

  krok "main: pull, raport T-$nr do plików wspólnych, metryki, CHANGELOG"
  if [ "$DRY" -eq 0 ]; then
    z_limitem 120 git -C "$ROOT_G" pull -q --ff-only origin main ||
      die "$E_WYKONANIE" "git pull --ff-only na main nie powiódł się; popraw i powtórz komendę"
    raport="$ROOT_G/docs/07-realizacja/T-$nr.md"
    if [ -f "$raport" ]; then
      dec="$(czytaj_sekcje "$raport" Decyzje)"
      uw="$(czytaj_sekcje "$raport" "Drobne uwagi")"
      prop="$(czytaj_sekcje "$raport" "Propozycje dla systemu")"
      d_n="$(przenies_decyzje "$dec" "T-$nr")"
      u_n="$(przenies_uwagi "$uw" "T-$nr")"
      if [ -n "$(printf '%s\n' "$prop" | pozycje)" ]; then
        prop_url="$(issue_propozycji "$nr" "$prop")" || { bledy=$((bledy + 1)); prop_url=""; }
      fi
    else
      uwaga "brak raportu docs/07-realizacja/T-$nr.md; decyzje i uwagi nie zostały przeniesione"
    fi
    # Drobne zgłoszenia ⚪ z ostatniego review.
    # Źródło: komentarz review w PR (także pisany ręcznie), a gdy go brak, lokalna kopia z review run.
    rev_plik="$STAN/review/$PROJEKT-$nr/$head.json"
    [ -n "${rev:-}" ] || rev="$(review_dla_heada "$prn" "$head")"
    if [ -z "$rev" ] && [ -f "$rev_plik" ]; then rev="$(cat "$rev_plik")"; fi
    if [ -n "$rev" ]; then
      r_n="$(przenies_uwagi "$(jq -r '.zgloszenia[] | select(.waga == "drobne") | "- \(.opis)\(if .plik != "" then " (`\(.plik)\(if .linia > 0 then ":\(.linia)" else "" end)`)" else "" end)"' <<<"$rev")" "review PR #$prn")"
    fi
    if ! grep -q "^| #$nr " "$ROOT_G/docs/metryki.md"; then
      tryb_z="$(jq -r '[.labels[].name | select(startswith("tryb:")) | ltrimstr("tryb:")][0] // ""' <<<"$j")"
      [ -n "$tryb_z" ] || tryb_z="$(tryb)"
      iter="$(iteracja_issue "$j")"
      [ "$iter" -gt 0 ] || iter=1
      f="$(jq -r '.start // ""' <<<"$(stan_zadania "$nr")")"
      [ -n "$f" ] || f="$(jq -r '.createdAt // ""' <<<"$pr")"
      czas="$( [ -n "$f" ] && czas_trwania "$f" || echo -)"
      esk=0
      pyt=0
      for f in "$ROOT_G"/docs/07-realizacja/escalations/E-[0-9]*.md; do
        [ -e "$f" ] || continue
        [ "$(fm_get "$f" dotyczy)" = "#$nr" ] || continue
        # Pytanie workera (escalate --typ pytanie) nie jest porażką: liczone osobno w „Uwagach”.
        if [ "$(fm_get "$f" typ)" = pytanie ]; then pyt=$((pyt + 1)); else esk=$((esk + 1)); fi
      done
      uw_m="PR #$prn"
      [ "$pyt" -eq 0 ] || uw_m="$uw_m, pytania: $pyt"
      dopisz_metryke "$ROOT_G/docs/metryki.md" "| #$nr $(komorka "$tytul") | $tryb_z | $czas | 1 | $iter | $esk | $uw_m |"
      pz="$(przyczyny_pr "$prn")"
      if [ "$(jq -r '.razem // 0' <<<"$pz")" -gt 0 ]; then
        dopisz_przyczyny "$ROOT_G/docs/metryki.md" "$(jq -r --arg z "review PR #$prn (#$nr $(komorka "$tytul"))" \
          '"| \($z) | \(.wymaganie) | \(.kod) | \(.test) | \(.design) | \(.brak) |"' <<<"$pz")"
      fi
      metr=true
    fi
    ! wpis_changelog "- #$nr: $(komorka "$tytul") (PR #$prn)" "$nr" || chlog=true
  fi

  krok "sprzątanie: worktree $kat, gałąź, panel $label, zamknięcie issue"
  if [ "$DRY" -eq 0 ]; then
    if worktree_tego_repo "$kat"; then
      [ -z "$(git -C "$kat" status --porcelain)" ] || die "$E_ODMOWA" "$kat ma niezacommitowane zmiany"
      git -C "$ROOT_G" worktree remove "$kat" || die "$E_WYKONANIE" "nie można usunąć worktree $kat"
    fi
    git -C "$ROOT_G" worktree prune
    git -C "$ROOT_G" for-each-ref --format='%(refname:short)' "refs/heads/task/$nr-*" "refs/heads/task/$nr" |
      while IFS= read -r f; do git -C "$ROOT_G" branch -D "$f" >/dev/null; done
    if herdr workspace list >/dev/null 2>&1; then
      zamknij_panel_etykieta "$label" || bledy=$((bledy + 1))
      zamknij_panel_etykieta "$(etykieta_eskalacji "$nr")" || bledy=$((bledy + 1))
    else
      uwaga "serwer herdr nie odpowiada; panel $label nie został zamknięty"
    fi
    j="$(issue_json "$nr")"
    if [ "$(jq -r .state <<<"$j")" = OPEN ]; then
      gh issue close "$nr" --repo "$SLUG" --reason completed >/dev/null || die "$E_WYKONANIE" "nie można zamknąć #$nr"
    fi
    zmien_etykiety "$nr" "$j" "" "$STATUSY"
    uruchom_sync_status || bledy=$((bledy + 1))
    stan_zapisz "$nr" null
    rm -rf "${STAN:?}/review/$PROJEKT-$nr"
  fi

  [ "$bledy" -eq 0 ] || die "$E_WYKONANIE" "#$nr zamknięte z błędami ($bledy, szczegóły wyżej); powtórz komendę, wykonane kroki zostaną pominięte"
  if [ "${odb:-}" = auto ] && [ "$DRY" -eq 0 ]; then
    powiadom default "Zmergowano zlecenie S: $PROJEKT" "#$nr $tytul (PR #$prn): bez zmian widocznych, PASS i zielone CI" \
      "https://github.com/$SLUG/pull/$prn" white_check_mark || uwaga "powiadomienie o merge'u #$nr nie wyszło"
  fi
  info "#$nr: zamknięte (PR #$prn)"
  wynik_json "$(jq -nc --argjson n "$nr" --argjson p "$prn" --argjson d "$d_n" --argjson u "$u_n" --argjson r "$r_n" \
    --argjson m "$metr" --argjson c "$chlog" --arg pr "$prop_url" --argjson k "$KROKI" \
    '{nr:$n, pr:$p, decyzje:$d, uwagi:$u, uwagi_review:$r, metryki:$m, changelog:$c,
      propozycje:(if $pr == "" then null else $pr end), kroki:$k}')"
}

# =========================================================================================
# task resume-check NR
# =========================================================================================

komenda_testow() {
  sekcja_issue "$1" "Komenda testów" | grep -v '^```' | grep -v '^[[:space:]]*$' | head -1 |
    sed -E 's/^`(.*)`$/\1/' | grep -vx 'brak' || true
}

task_resume_check() {
  local nr j kat testy="" bez=0 st iter pane panele git_j='{}' t_j br wyj rc rek baza
  local -a reszta=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --testy) testy="$(wartosc "$@")"; shift 2 ;;
      --bez-testow) bez=1; shift ;;
      *) reszta+=("$1"); shift ;;
    esac
  done
  argument_nr ${reszta[@]+"${reszta[@]}"}
  nr="$NR_ARG"
  zadania_init
  j="$(issue_json "$nr")"
  st="$(status_issue "$j")"
  iter="$(iteracja_issue "$j")"
  kat="$WT/$nr"
  pane=""
  if herdr workspace list >/dev/null 2>&1; then
    panele="$(panele_herdr)"
    pane="$(jq -c --arg l "$(etykieta_workera "$nr")" '[.[] | select(.label == $l)][0] // null' <<<"$panele")"
  else
    pane=null
  fi

  t_j='{"wynik":"brak worktree"}'
  if worktree_tego_repo "$kat"; then
    pobierz_main
    baza="$(baza_main)"
    br="$(git -C "$kat" symbolic-ref --short -q HEAD || true)"
    git_j="$(jq -nc --arg g "$br" --arg h "$(git -C "$kat" rev-parse HEAD)" \
      --arg z "$(git -C "$kat" status --porcelain)" \
      --arg ab "$(git -C "$kat" rev-list --left-right --count "$baza...HEAD" 2>/dev/null || echo '0 0')" \
      --arg zd "$(git -C "$kat" rev-list --left-right --count "origin/$br...HEAD" 2>/dev/null || echo '')" \
      --arg o "$(git -C "$kat" log -1 --format='%h %s' 2>/dev/null)" \
      '{galaz:$g, head:$h, ostatni_commit:$o,
        niezacommitowane:($z | split("\n") | map(select(length > 0))),
        za_main:($ab | split("\t")[0] | tonumber), przed_main:($ab | split("\t")[1] | tonumber),
        niewypchniete:(if $zd == "" then null else ($zd | split("\t")[1] | tonumber) end)}')"
    [ -n "$testy" ] || testy="$(komenda_testow "$j")"
    if [ "$bez" -eq 1 ]; then
      t_j='{"wynik":"pominiete"}'
    elif [ -z "$testy" ]; then
      t_j='{"wynik":"brak komendy"}'
    elif [ "$DRY" -eq 1 ]; then
      t_j="$(jq -nc --arg k "$testy" '{komenda:$k, wynik:"pominiete (dry-run)"}')"
    else
      rc=0
      wyj="$(cd "$kat" && z_limitem "${SHCTL_TEST_TIMEOUT:-1800}" bash -c "$testy" 2>&1)" || rc=$?
      t_j="$(jq -nc --arg k "$testy" --argjson r "$rc" --arg w "$(printf '%s\n' "$wyj" | tail -40)" \
        '{komenda:$k, kod:$r, wynik:(if $r == 0 then "pass" else "fail" end), koniec_wyjscia:$w}')"
    fi
  fi

  rek="$(jq -nr --argjson g "$git_j" --argjson t "$t_j" --argjson w "$(worktree_tego_repo "$kat" && echo true || echo false)" '
    if ($w | not) then "iteracja od nowa"
    elif ($g.za_main // 0) > 0 then "rebase i kontynuuj"
    else "kontynuuj" end')"
  info "#$nr: status $st, iteracja $iter, sugestia: $rek"
  wynik_json "$(jq -nc --argjson n "$nr" --arg s "$st" --argjson i "$iter" --arg k "$kat" \
    --argjson w "$(worktree_tego_repo "$kat" && echo true || echo false)" --argjson g "$git_j" \
    --argjson t "$t_j" --argjson p "${pane:-null}" --arg r "$rek" \
    '{nr:$n, status:$s, iteracja:$i, worktree:$k, worktree_istnieje:$w, git:$g, testy:$t, panel:$p,
      sugestia:$r, uwaga:"przerwanie przez limit nie podbija iteracji"}')"
}

# =========================================================================================
# task close NR --anuluj [--powod "..."] (dawniej task cancel)
# =========================================================================================

# Anulowanie zadania: issue „not planned”, PR zamknięty z gałęzią, worktree, gałąź lokalna, panele
# (worker, eskalacja, review) i wpis w stanie usunięte. Scalonego PR nie da się anulować.
task_cancel() {
  local nr j pr prn="" prst="" powod="" kat label p panele zam_p='[]' komentarz wt_rev zmiana=0 l
  local -a reszta=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --powod) powod="$(wartosc "$@")"; shift 2 ;;
      *) reszta+=("$1"); shift ;;
    esac
  done
  argument_nr ${reszta[@]+"${reszta[@]}"}
  nr="$NR_ARG"
  zadania_init
  j="$(issue_json "$nr")"
  pr="$(pr_zadania "$nr")"
  if [ -n "$pr" ]; then
    prn="$(jq -r .number <<<"$pr")"
    prst="$(jq -r .state <<<"$pr")"
    [ "$prst" != MERGED ] || die "$E_ODMOWA" "#$nr ma scalony PR #$prn; anulowanie niemożliwe (zmianę cofa nowe zadanie)"
  fi
  kat="$WT/$nr"
  wt_rev="$WT/review-$nr"
  label="$(etykieta_workera "$nr")"
  komentarz="Anulowane przez orkiestratora${powod:+: $powod} (shctl task close --anuluj)."

  if [ "$prst" = OPEN ]; then
    krok "zamknięcie PR #$prn z gałęzią"
    zmiana=1
    [ "$DRY" -eq 1 ] || gh pr close "$prn" --repo "$SLUG" --delete-branch --comment "$komentarz" >/dev/null ||
      die "$E_WYKONANIE" "nie można zamknąć PR #$prn"
  fi
  if herdr workspace list >/dev/null 2>&1; then
    panele="$(panele_herdr)"
    for l in "$label" "$(etykieta_eskalacji "$nr")" "$(etykieta_review "$nr")"; do
      p="$(panel_po_etykiecie "$panele" "$l")"
      [ -n "$p" ] || continue
      krok "zamknięcie panelu $p ($l)"
      zmiana=1
      zam_p="$(jq -c --arg l "$l" '. + [$l]' <<<"$zam_p")"
      [ "$DRY" -eq 1 ] || herdr pane close "$p" >/dev/null || uwaga "nie zamknięto panelu $p ($l)"
    done
  else
    uwaga "serwer herdr nie odpowiada; panele #$nr zostają"
  fi
  for p in "$kat" "$wt_rev"; do
    worktree_tego_repo "$p" || continue
    krok "usunięcie worktree $p (bez zachowania zmian)"
    zmiana=1
    if [ "$DRY" -eq 0 ]; then
      git -C "$ROOT_G" worktree remove --force "$p" || die "$E_WYKONANIE" "nie można usunąć worktree $p"
    fi
  done
  if [ "$DRY" -eq 0 ]; then
    git -C "$ROOT_G" worktree prune
    git -C "$ROOT_G" for-each-ref --format='%(refname:short)' "refs/heads/task/$nr-*" "refs/heads/task/$nr" |
      while IFS= read -r p; do git -C "$ROOT_G" branch -D "$p" >/dev/null; done
  fi
  if [ "$(jq -r .state <<<"$j")" = OPEN ]; then
    krok "zamknięcie #$nr jako not planned"
    zmiana=1
    if [ "$DRY" -eq 0 ]; then
      gh issue close "$nr" --repo "$SLUG" --reason "not planned" --comment "$komentarz" >/dev/null ||
        die "$E_WYKONANIE" "nie można zamknąć #$nr"
    fi
  fi
  if [ "$DRY" -eq 0 ]; then
    zmien_etykiety "$nr" "$(issue_json "$nr")" "" "$STATUSY"
    [ "$(stan_zadania "$nr")" = null ] || zmiana=1
    stan_zapisz "$nr" null
    rm -rf "${STAN:?}/review/$PROJEKT-$nr"
    uruchom_sync_status || true
  fi
  if [ "$zmiana" -eq 1 ]; then info "#$nr: anulowane"; else info "#$nr: już anulowane"; fi
  wynik_json "$(jq -nc --argjson n "$nr" --arg p "$prn" --arg ps "$prst" --argjson z "$zmiana" --argjson pa "$zam_p" \
    --arg o "$powod" --argjson k "$KROKI" \
    '{nr:$n, pr:(if $p == "" then null else ($p | tonumber) end), pr_zamkniety:($ps == "OPEN"), panele:$pa,
      powod:(if $o == "" then null else $o end), zmiana:($z == 1), kroki:$k}')"
}

# =========================================================================================
# task wait NR [--timeout SEKUNDY]
# =========================================================================================

# Czekanie na workera z limitem czasu i sprawdzeniem stanu. herdr agent wait na panelu idle wraca
# od razu, a na panelu bez agenta pada, więc najpierw stan, a czekamy tylko na pracującego agenta.
# Po poleceniu (dispatch albo iter zapisują .polecenie w stanie zadania) liczy się tylko nowa tura:
# agent przeszedł w working (zapamiętane jako .tura), a potem idle, albo w PR jest commit nowszy niż
# polecenie. Raport z poprzedniej iteracji ani panel idle przed podjęciem polecenia nie kończą czekania.
# Wynik: gotowe (PR z raportem), idle, blocked, brak_agenta, brak_panelu, pracuje (limit czasu) albo
# bez_tury (limit czasu, a agent nie podjął polecenia).
task_wait() {
  local nr timeout=600 t=0 label pr prn="" raport=false st="" p a krok_s start_s pol tura nowy pj
  local -a reszta=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --timeout) timeout="$(wartosc "$@")"; shift 2 ;;
      *) reszta+=("$1"); shift ;;
    esac
  done
  argument_nr ${reszta[@]+"${reszta[@]}"}
  nr="$NR_ARG"
  timeout="$(numer "$timeout")"
  zadania_init
  herdr_dziala
  label="$(etykieta_workera "$nr")"
  pol="$(jq -r '.polecenie // ""' <<<"$(stan_zadania "$nr")")"
  tura="$(jq -r 'if .tura == false then "false" else "true" end' <<<"$(stan_zadania "$nr")")"
  [ -n "$pol" ] || tura=true
  start_s="$(date +%s)"
  while :; do
    pr="$(pr_zadania "$nr")"
    prn=""
    raport=false
    nowy=false
    if [ -n "$pr" ] && [ "$(jq -r .state <<<"$pr")" = OPEN ]; then
      prn="$(jq -r .number <<<"$pr")"
      pj="$(gh pr view "$prn" --repo "$SLUG" --json files,commits 2>/dev/null || echo '{}')"
      jq -e --arg f "docs/07-realizacja/T-$nr.md" 'any((.files // [])[]; .path == $f)' <<<"$pj" >/dev/null && raport=true
      # Daty ISO 8601 w UTC porównujemy jako tekst.
      [ -n "$pol" ] && jq -e --arg p "$pol" '[(.commits // [])[] | .committedDate // ""] | max // "" | . >= $p' <<<"$pj" >/dev/null &&
        nowy=true
    fi
    [ -n "$pol" ] || nowy=true
    if [ "$raport" = true ] && [ "$nowy" = true ]; then st=gotowe; break; fi
    p="$(jq -c --arg l "$label" '[.[] | select(.label == $l)][0] // null' <<<"$(panele_herdr)")"
    if [ "$p" = null ]; then st=brak_panelu; break; fi
    a="$(jq -r '.agent_status // ""' <<<"$p")"
    case "$(jq -r '.agent // ""' <<<"$p")/$a" in
      /*) st=brak_agenta; break ;;
      */working)
        if [ "$tura" = false ]; then
          tura=true
          stan_zapisz "$nr" '{"tura":true}'
        fi
        ;;
      */idle | */done)
        if [ "$tura" = true ] || [ "$nowy" = true ]; then st=idle; break; fi
        ;;
      */blocked) st=blocked; break ;;
    esac
    t=$(($(date +%s) - start_s))
    if [ "$t" -ge "$timeout" ]; then
      if [ "$tura" = true ]; then st=pracuje; else st=bez_tury; fi
      break
    fi
    krok_s=$((timeout - t))
    [ "$krok_s" -le "${SHCTL_WAIT_KROK:-60}" ] || krok_s="${SHCTL_WAIT_KROK:-60}"
    if [ "$tura" = false ]; then
      # Agent jeszcze nie podjął polecenia: agent wait na idle wróciłby od razu.
      sleep "${SHCTL_WAIT_PAUZA:-5}"
      continue
    fi
    # Błąd agent wait (agent zniknął) rozstrzyga następny obieg; pauza chroni przed pętlą bez czekania.
    z_limitem $((krok_s + 10)) herdr agent wait "$(jq -r .pane_id <<<"$p")" --timeout "$((krok_s * 1000))" >/dev/null 2>&1 ||
      sleep "${SHCTL_WAIT_PAUZA:-5}"
  done
  t=$(($(date +%s) - start_s))
  case "$st" in
    gotowe) krok_s="shctl pr check $prn --czekaj" ;;
    idle) krok_s="agent czeka bez PR z raportem po poleceniu: polecenie dokończenia (herdr agent prompt)" ;;
    blocked) krok_s="agent pyta albo czeka na zgodę: herdr agent read, pytanie do właściciela w statusie" ;;
    brak_agenta | brak_panelu) krok_s="shctl task resume-check $nr, potem shctl task dispatch $nr" ;;
    pracuje) krok_s="worker pracuje: ponów shctl task wait $nr" ;;
    bez_tury) krok_s="agent nie podjął polecenia: herdr agent read; gdy czeka na wejście, herdr agent prompt" ;;
  esac
  info "#$nr: $st po ${t} s; dalej: $krok_s"
  wynik_json "$(jq -nc --argjson n "$nr" --arg s "$st" --arg p "$prn" --argjson r "$raport" --argjson t "$t" --arg k "$krok_s" \
    --arg pol "$pol" --argjson nc "$nowy" \
    '{nr:$n, stan:$s, pr:(if $p == "" then null else ($p | tonumber) end), raport:$r, czekano_s:$t,
      polecenie:(if $pol == "" then null else $pol end), nowy_commit:$nc,
      limit_czasu:($s == "pracuje" or $s == "bez_tury"), nastepny_krok:$k}')"
}

komenda_main() {
  local a poprz=""
  local -a reszta=()
  # Podkomenda to pierwszy argument niebędący opcją ani jej wartością.
  SUB=""
  ANULUJ=0
  ODBIOR=0
  for a in "$@"; do
    case "$poprz" in
      --projekt | --plik | --testy | --powod | --timeout) reszta+=("$a") ;;
      *)
        if [ "$a" = --anuluj ]; then ANULUJ=1
        elif [ "$a" = --odbior ]; then ODBIOR=1
        elif [ -z "$SUB" ] && [ "${a#-}" = "$a" ]; then SUB="$a"; else reszta+=("$a"); fi
        ;;
    esac
    poprz="$a"
  done
  [ "$ANULUJ" -eq 0 ] || [ "$SUB" = close ] || die "$E_UZYCIE" "--anuluj tylko z shctl task close NR"
  [ "$ODBIOR" -eq 0 ] || [ "$SUB" = close ] || die "$E_UZYCIE" "--odbior tylko z shctl task close NR"
  set -- ${reszta[@]+"${reszta[@]}"}
  case "$SUB" in
    create) task_create "$@" ;;
    ready) task_ready "$@" ;;
    dispatch) task_dispatch "$@" ;;
    iter) task_iter "$@" ;;
    close) if [ "$ANULUJ" -eq 1 ]; then task_cancel "$@"; else task_close "$@"; fi ;;
    resume-check) task_resume_check "$@" ;;
    cancel)
      uwaga "shctl task cancel jest przestarzałe: użyj shctl task close NR --anuluj (alias działa do następnej wersji)"
      task_cancel "$@"
      ;;
    wait) task_wait "$@" ;;
    *) die "$E_UZYCIE" "użycie: shctl task create|ready|dispatch|iter|close [--anuluj]|resume-check|wait (shctl --help)" ;;
  esac
}
