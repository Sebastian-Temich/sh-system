# shctl reset-dryrun: projekt wzorcowy sh-dryrun wraca do tagu „baseline” (proces-v1.md, „Projekt
# wzorcowy”). Zamyka panele, worktree i otwarte PR, archiwizuje znaczniki shctl:id we wszystkich issue
# (także zamkniętych), usuwa lokalne gałęzie stage/* i task/*, resetuje main do tagu (force push),
# odtwarza issue z zadania.yaml zapisanego w repo, dopisuje nowy przebieg do docs/metryki.md (plik
# przechodzi przez reset) i odtwarza klon docs/ w vaulcie Obsidiana. Działa wyłącznie na sh-dryrun.
# shellcheck shell=bash

# shellcheck source=../lib/zadania.sh
. "$SHCTL_DIR/lib/zadania.sh"
# shellcheck source=../lib/obsidian.sh
. "$SHCTL_DIR/lib/obsidian.sh"

DRYRUN_NAZWA="${SHCTL_DRYRUN_NAZWA:-sh-dryrun}"

# Pliki, które reset zapisuje po task create; poza nimi drzewo main musi być równe baseline.
PLIKI_PRZEBIEGU="docs/metryki.md docs/06-zadania/index.md docs/status.md"

# Artefakty przebiegu w commicie baseline, po jednym w linii; pusto, gdy baseline jest czysty.
artefakty_baseline() {
  local b="$1" f s i
  git -C "$ROOT_G" ls-tree -r --name-only "$b" |
    grep -E '^docs/07-realizacja/T-[0-9]+\.md$|^docs/07-realizacja/escalations/E-[0-9]+\.md$|^docs/08-qa/raport-[^/]+\.md$' |
    sed 's/$/: plik przebiegu/' || true
  if git -C "$ROOT_G" show "$b:docs/06-zadania/index.md" 2>/dev/null | grep -qF '<!-- shctl:mapa:start -->'; then
    echo "docs/06-zadania/index.md: mapa zadań z task create"
  fi
  if git -C "$ROOT_G" show "$b:CHANGELOG.md" 2>/dev/null | grep -qE '^- #[0-9]+: '; then
    echo "CHANGELOG.md: wpisy zamkniętych zadań"
  fi
  for f in $(git -C "$ROOT_G" ls-tree -r --name-only "$b" | grep -E '^docs/[^/]+/DoD\.md$'); do
    s="$(git -C "$ROOT_G" show "$b:$f" | yq --front-matter=extract '.status // ""' 2>/dev/null || true)"
    i="$(git -C "$ROOT_G" show "$b:$f" | yq --front-matter=extract '.iteracja // 0' 2>/dev/null || true)"
    case "$s" in todo | pominiety) ;; *) echo "$f: status $s" ;; esac
    [ "$i" = 0 ] || echo "$f: iteracja $i"
  done
}

# Metryki sprzed resetu: kopia robocza main (z niezacommitowanymi wpisami) albo main z origin.
metryki_przed() {
  local m="$1"
  if [ "$(git -C "$ROOT_G" symbolic-ref --short -q HEAD || true)" = main ] && [ -f "$ROOT_G/docs/metryki.md" ]; then
    cat "$ROOT_G/docs/metryki.md"
  elif [ -n "$m" ] && git -C "$ROOT_G" cat-file -e "$m:docs/metryki.md" 2>/dev/null; then
    git -C "$ROOT_G" show "$m:docs/metryki.md"
  fi
}

# Następny numer przebiegu z nagłówków „## Przebieg dryrun N”.
nastepny_przebieg() {
  awk 'match($0, /^## Przebieg dryrun [0-9]+/) { n = substr($0, 20, RLENGTH - 19) + 0; if (n > m) m = n }
    END { print m + 1 }' "$1"
}

# Nowa sekcja przebiegu na końcu metryk; wiersze zadań trafiają do jej tabeli (task close).
dopisz_przebieg() {
  local plik="$1" n="$2" b="$3"
  [ -z "$(tail -c1 "$plik")" ] || printf '\n' >>"$plik"
  printf '\n## Przebieg dryrun %s (%s)\n\nReset do baseline `%s` o %s UTC. Wiersze zadań dopisuje `shctl task close`, miary przebiegu orkiestrator.\n\n| Zlecenie | Tryb | Czas | Zadania | Iteracje | Eskalacje | Uwagi |\n|---|---|---|---|---|---|---|\n' \
    "$n" "$(dzis)" "${b:0:7}" "$(date -u +%H:%M)" >>"$plik"
}

# Klon docs/ w vaulcie: usunięcie (po force push ma historię sprzed resetu) i nowy klon.
# Wypisuje opis wyniku; błąd nie przerywa resetu, bo repo jest już w stanie baseline.
odtworz_obsidian() {
  local kat zmiany
  [ -n "${SH_OBSIDIAN_DIR:-}" ] || { echo "pominiety: brak SH_OBSIDIAN_DIR"; return 0; }
  kat="$(obsidian_kat "$PROJEKT")"
  if [ -e "$kat" ]; then
    obsidian_czy_klon "$kat" "$SH_GH_OWNER/$PROJEKT" || { echo "pominiety: $kat nie jest klonem $SH_GH_OWNER/$PROJEKT"; return 0; }
    # Niewypchnięte commity to stara historia main; lokalne zmiany właściciela zostają nietknięte.
    zmiany="$(git -C "$kat" status --porcelain 2>/dev/null || echo blad)"
    [ -z "$zmiany" ] || { echo "pominiety: $kat ma niezacommitowane zmiany"; return 0; }
    rm -rf "$kat"
  fi
  if (obsidian_polacz "$PROJEKT" >/dev/null) 2>"$SHCTL_TMP/obs.err"; then
    echo "odtworzony"
  else
    echo "pominiety: $(head -1 "$SHCTL_TMP/obs.err" | sed 's/^BŁĄD: //')"
  fi
}

komenda_main() {
  local baseline plik_rel ids prs issues main_sha zgodne ile_wt panele etyk n wyn mapa='{}' t art galezie
  local zam_pr='[]' zam_is='[]' arch='[]' oznaczone metryki nr_przebiegu=null obs="" drzewo
  while [ $# -gt 0 ]; do opcja_wspolna "$@"; shift "$ZJEDZONE"; done
  [ -n "$PROJEKT" ] || PROJEKT="$DRYRUN_NAZWA"
  [ "$PROJEKT" = "$DRYRUN_NAZWA" ] || die "$E_ODMOWA" "reset-dryrun działa tylko na projekcie $DRYRUN_NAZWA, nie na $PROJEKT"
  zadania_init
  herdr_dziala

  z_limitem 120 git -C "$ROOT_G" fetch -q --force origin main 'refs/tags/*:refs/tags/*' ||
    die "$E_WYKONANIE" "git fetch origin nie powiódł się"
  baseline="$(git -C "$ROOT_G" rev-parse -q --verify 'refs/tags/baseline^{commit}')" ||
    die "$E_BRAK" "brak tagu baseline w $SLUG"
  art="$(artefakty_baseline "$baseline")"
  [ -z "$art" ] || die "$E_ODMOWA" "baseline ${baseline:0:7} zawiera artefakty przebiegu: $(printf '%s' "$art" | paste -sd ';' - | sed 's/;/; /g'); przesuń tag baseline na czysty commit"
  plik_rel=""
  for t in zadania.yaml docs/06-zadania/zadania.yaml; do
    if git -C "$ROOT_G" cat-file -e "$baseline:$t" 2>/dev/null; then plik_rel="$t"; break; fi
  done
  [ -n "$plik_rel" ] || die "$E_BRAK" "baseline nie ma zadania.yaml ani docs/06-zadania/zadania.yaml"
  ids="$(git -C "$ROOT_G" show "$baseline:$plik_rel" | yq -o=json '.' |
    jq -c '(if type == "array" then . else .zadania end) | map(.id | tostring) | sort')" ||
    die "$E_UZYCIE" "$plik_rel w baseline: niepoprawny YAML"

  prs="$(gh pr list --repo "$SLUG" --state open --limit 200 --json number,headRefName)" || die "$E_WYKONANIE" "gh pr list nie działa"
  issues="$(wszystkie_issue)"
  # Każde issue ze znacznikiem shctl:id, także zamknięte: inaczej task create uzna ID za istniejące.
  oznaczone="$(jq -c '[.[] | select((.body // "") | test("<!-- shctl:id=[^ ]+ -->"))]' <<<"$issues")"
  main_sha="$(git -C "$ROOT_G" rev-parse -q --verify origin/main || true)"
  ile_wt="$(git -C "$ROOT_G" worktree list --porcelain | grep -c '^worktree ' || true)"
  galezie="$(git -C "$ROOT_G" for-each-ref --format='%(refname:short)' 'refs/heads/task/*' 'refs/heads/stage/*' |
    jq -Rsc 'split("\n") | map(select(length > 0))')"
  panele="$(panele_herdr)"
  etyk="$(jq -c --arg p "$PROJEKT" '[.[] | select(.label | test("^(worker|review|qa|eskalacja):" + $p + ":"))]' <<<"$panele")"
  drzewo=false
  # shellcheck disable=SC2046
  if [ -n "$main_sha" ] && git -C "$ROOT_G" diff --quiet "$baseline" "$main_sha" -- . \
    $(for t in $PLIKI_PRZEBIEGU; do printf ':(exclude)%s ' "$t"; done); then drzewo=true; fi

  zgodne="$(jq -nr --argjson o "$oznaczone" --argjson ids "$ids" --argjson prs "$prs" --argjson e "$etyk" \
    --argjson d "$drzewo" --argjson w "$ile_wt" --argjson g "$galezie" '
    ($o | map((.body // "") | [capture("<!-- shctl:id=(?<id>[^ ]+) -->")][0].id)) as $mk
    | $d and ($prs | length == 0) and ($e | length == 0) and ($w <= 1) and ($g | length == 0)
      and (($mk | sort) == $ids)
      and ($o | all(.state == "OPEN" and ([.labels[].name] | (index("status:todo") != null)
        and (map(select(startswith("iter:"))) | length == 0))))')"
  if [ "$zgodne" = true ]; then
    info "$PROJEKT jest już w stanie baseline (${baseline:0:7})"
    wynik_json "$(jq -nc --arg b "$baseline" '{baseline:$b, zmiana:false}')"
    return 0
  fi

  info "reset $PROJEKT do baseline ${baseline:0:7}:"
  info "- zamknij panele: $(jq -r 'map(.label) | join(", ") | if . == "" then "brak" else . end' <<<"$etyk")"
  info "- usuń worktree, gałęzie task/* i stage/*, zamknij PR: $(jq -r 'map("#\(.number)") | join(", ") | if . == "" then "brak" else . end' <<<"$prs")"
  info "- zarchiwizuj znaczniki shctl:id: $(jq -r 'map("#\(.number)") | join(", ") | if . == "" then "brak" else . end' <<<"$oznaczone")"
  info "- main = baseline (force push), issue z $plik_rel, nowy przebieg w docs/metryki.md"
  info "- klon docs/ w vaulcie Obsidiana od nowa"
  zam_pr="$(jq -c 'map(.number)' <<<"$prs")"
  zam_is="$(jq -c 'map(select(.state == "OPEN") | .number)' <<<"$oznaczone")"
  arch="$(jq -c 'map(.number)' <<<"$oznaczone")"

  if [ "$DRY" -eq 0 ]; then
    metryki="$(tmp_plik)"
    metryki_przed "$main_sha" >"$metryki"
    [ -s "$metryki" ] || git -C "$ROOT_G" show "$baseline:docs/metryki.md" >"$metryki" 2>/dev/null ||
      printf '# Metryki\n' >"$metryki"
    for n in $(jq -r '.[].pane_id' <<<"$etyk"); do herdr pane close "$n" >/dev/null || uwaga "nie zamknięto panelu $n"; done
    git -C "$ROOT_G" worktree list --porcelain | awk '/^worktree /{print substr($0, 10)}' | while IFS= read -r t; do
      [ "$t" = "$ROOT_G" ] || git -C "$ROOT_G" worktree remove --force "$t" || die "$E_WYKONANIE" "nie można usunąć worktree $t"
    done
    git -C "$ROOT_G" worktree prune
    for n in $(jq -r '.[].number' <<<"$prs"); do
      gh pr close "$n" --repo "$SLUG" --delete-branch --comment "reset-dryrun: powrót do baseline" >/dev/null ||
        die "$E_WYKONANIE" "nie można zamknąć PR #$n"
    done
    for n in $(jq -r '.[].number' <<<"$oznaczone"); do
      t="$(tmp_plik)"
      jq -r --argjson n "$n" '.[] | select(.number == $n) | .body // ""' <<<"$oznaczone" |
        sed 's/<!-- shctl:id=/<!-- shctl:archiwum-id=/' >"$t"
      gh issue edit "$n" --repo "$SLUG" --body-file "$t" >/dev/null || die "$E_WYKONANIE" "nie można zarchiwizować #$n"
      if [ "$(jq -r --argjson n "$n" '.[] | select(.number == $n) | .state' <<<"$oznaczone")" = OPEN ]; then
        gh issue close "$n" --repo "$SLUG" --reason "not planned" --comment "reset-dryrun: powrót do baseline" >/dev/null ||
          die "$E_WYKONANIE" "nie można zamknąć #$n"
      fi
    done
    git -C "$ROOT_G" checkout -q -f main || die "$E_WYKONANIE" "nie można przełączyć $ROOT_G na main"
    git -C "$ROOT_G" reset -q --hard "$baseline"
    git -C "$ROOT_G" clean -fdq
    git -C "$ROOT_G" for-each-ref --format='%(refname:short)' 'refs/heads/task/*' 'refs/heads/stage/*' | while IFS= read -r t; do
      git -C "$ROOT_G" branch -D "$t" >/dev/null
    done
    if [ "$main_sha" != "$baseline" ]; then
      z_limitem 120 git -C "$ROOT_G" push -q --force-with-lease="main:$main_sha" origin "$baseline:refs/heads/main" ||
        die "$E_WYKONANIE" "force push main do baseline nie powiódł się (ochrona gałęzi?)"
    fi
    if [ -f "$(plik_stanu)" ]; then
      t="$(tmp_plik)"
      jq '.zadania = {} | del(.etapy)' "$(plik_stanu)" >"$t" && mv "$t" "$(plik_stanu)"
    fi
    rm -rf "$STAN/review/$PROJEKT-"*
    wyn="$("$SHCTL_DIR/shctl" task create --projekt "$PROJEKT" --plik "$ROOT_G/$plik_rel" --json)" ||
      die "$E_WYKONANIE" "task create po resecie nie powiódł się; powtórz reset-dryrun"
    mapa="$(jq -c '.wynik.mapa' <<<"$wyn")"

    nr_przebiegu="$(nastepny_przebieg "$metryki")"
    dopisz_przebieg "$metryki" "$nr_przebiegu" "$baseline"
    podmien_plik "$metryki" "$ROOT_G/docs/metryki.md"
    for t in $PLIKI_PRZEBIEGU; do [ ! -e "$ROOT_G/$t" ] || git -C "$ROOT_G" add -- "$t"; done
    if ! git -C "$ROOT_G" diff --cached --quiet; then
      git -C "$ROOT_G" commit -qm "reset-dryrun: przebieg $nr_przebiegu od baseline ${baseline:0:7}" ||
        die "$E_WYKONANIE" "commit metryk przebiegu nie powiódł się"
      z_limitem 120 git -C "$ROOT_G" push -q origin main ||
        die "$E_WYKONANIE" "push metryk przebiegu nie powiódł się; wypchnij main ręcznie"
    fi
    obs="$(odtworz_obsidian)"
    case "$obs" in pominiety*) uwaga "Obsidian: $obs" ;; esac
  fi
  wynik_json "$(jq -nc --arg b "$baseline" --argjson p "$zam_pr" --argjson i "$zam_is" --argjson a "$arch" --argjson m "$mapa" \
    --arg f "$plik_rel" --argjson n "$nr_przebiegu" --arg o "$obs" \
    '{baseline:$b, zamkniete_pr:$p, zamkniete_issue:$i, zarchiwizowane:$a, plik_zadan:$f, mapa:$m,
      przebieg:$n, obsidian:(if $o == "" then null else $o end), zmiana:true}')"
}
