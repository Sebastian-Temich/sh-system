# shctl reset-dryrun: projekt wzorcowy sh-dryrun wraca do tagu „baseline” (proces-v1.md, „Projekt
# wzorcowy”). Zamyka panele, worktree i otwarte PR, archiwizuje otwarte issue, resetuje main do tagu
# (force push) i odtwarza issue z zadania.yaml zapisanego w repo. Działa wyłącznie na sh-dryrun.
# shellcheck shell=bash

# shellcheck source=../lib/zadania.sh
. "$SHCTL_DIR/lib/zadania.sh"

DRYRUN_NAZWA="${SHCTL_DRYRUN_NAZWA:-sh-dryrun}"

komenda_main() {
  local baseline plik_rel ids prs issues main_sha otwarte zgodne ile_wt panele etyk n wyn mapa='{}' t
  local zam_pr='[]' zam_is='[]'
  while [ $# -gt 0 ]; do opcja_wspolna "$@"; shift "$ZJEDZONE"; done
  [ -n "$PROJEKT" ] || PROJEKT="$DRYRUN_NAZWA"
  [ "$PROJEKT" = "$DRYRUN_NAZWA" ] || die "$E_ODMOWA" "reset-dryrun działa tylko na projekcie $DRYRUN_NAZWA, nie na $PROJEKT"
  zadania_init
  herdr_dziala

  z_limitem 120 git -C "$ROOT_G" fetch -q --force origin main 'refs/tags/*:refs/tags/*' ||
    die "$E_WYKONANIE" "git fetch origin nie powiódł się"
  baseline="$(git -C "$ROOT_G" rev-parse -q --verify 'refs/tags/baseline^{commit}')" ||
    die "$E_BRAK" "brak tagu baseline w $SLUG"
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
  otwarte="$(jq -c 'map(select(.state == "OPEN"))' <<<"$issues")"
  main_sha="$(git -C "$ROOT_G" rev-parse -q --verify origin/main || true)"
  ile_wt="$(git -C "$ROOT_G" worktree list --porcelain | grep -c '^worktree ' || true)"
  panele="$(panele_herdr)"
  etyk="$(jq -c --arg p "$PROJEKT" '[.[] | select(.label | test("^(worker|review|qa):" + $p + ":"))]' <<<"$panele")"

  zgodne="$(jq -nr --argjson o "$otwarte" --argjson ids "$ids" --argjson prs "$prs" --argjson e "$etyk" \
    --arg m "$main_sha" --arg b "$baseline" --argjson w "$ile_wt" '
    ($o | map((.body // "") | [capture("<!-- shctl:id=(?<id>[^ ]+) -->")][0].id) ) as $mk
    | ($m == $b) and ($prs | length == 0) and ($e | length == 0) and ($w <= 1)
      and ($mk | all(. != null)) and (($mk | sort) == $ids)
      and ($o | all([.labels[].name] | (index("status:todo") != null) and (map(select(startswith("iter:"))) | length == 0)))')"
  if [ "$zgodne" = true ]; then
    info "$PROJEKT jest już w stanie baseline (${baseline:0:7})"
    wynik_json "$(jq -nc --arg b "$baseline" '{baseline:$b, zmiana:false}')"
    return 0
  fi

  info "reset $PROJEKT do baseline ${baseline:0:7}:"
  info "- zamknij panele: $(jq -r 'map(.label) | join(", ") | if . == "" then "brak" else . end' <<<"$etyk")"
  info "- usuń worktree i gałęzie task/*, zamknij PR: $(jq -r 'map("#\(.number)") | join(", ") | if . == "" then "brak" else . end' <<<"$prs")"
  info "- zarchiwizuj i zamknij issue: $(jq -r 'map("#\(.number)") | join(", ") | if . == "" then "brak" else . end' <<<"$otwarte")"
  info "- main = baseline (force push), issue z $plik_rel"
  zam_pr="$(jq -c 'map(.number)' <<<"$prs")"
  zam_is="$(jq -c 'map(.number)' <<<"$otwarte")"

  if [ "$DRY" -eq 0 ]; then
    for n in $(jq -r '.[].pane_id' <<<"$etyk"); do herdr pane close "$n" >/dev/null || uwaga "nie zamknięto panelu $n"; done
    git -C "$ROOT_G" worktree list --porcelain | awk '/^worktree /{print substr($0, 10)}' | while IFS= read -r t; do
      [ "$t" = "$ROOT_G" ] || git -C "$ROOT_G" worktree remove --force "$t" || die "$E_WYKONANIE" "nie można usunąć worktree $t"
    done
    git -C "$ROOT_G" worktree prune
    for n in $(jq -r '.[].number' <<<"$prs"); do
      gh pr close "$n" --repo "$SLUG" --delete-branch --comment "reset-dryrun: powrót do baseline" >/dev/null ||
        die "$E_WYKONANIE" "nie można zamknąć PR #$n"
    done
    for n in $(jq -r '.[].number' <<<"$otwarte"); do
      t="$(tmp_plik)"
      jq -r --argjson n "$n" '.[] | select(.number == $n) | .body // ""' <<<"$otwarte" |
        sed 's/<!-- shctl:id=/<!-- shctl:archiwum-id=/' >"$t"
      gh issue edit "$n" --repo "$SLUG" --body-file "$t" >/dev/null || die "$E_WYKONANIE" "nie można zarchiwizować #$n"
      gh issue close "$n" --repo "$SLUG" --reason "not planned" --comment "reset-dryrun: powrót do baseline" >/dev/null ||
        die "$E_WYKONANIE" "nie można zamknąć #$n"
    done
    git -C "$ROOT_G" checkout -q -f main || die "$E_WYKONANIE" "nie można przełączyć $ROOT_G na main"
    git -C "$ROOT_G" reset -q --hard "$baseline"
    git -C "$ROOT_G" clean -fdq
    git -C "$ROOT_G" for-each-ref --format='%(refname:short)' 'refs/heads/task/*' | while IFS= read -r t; do
      git -C "$ROOT_G" branch -D "$t" >/dev/null
    done
    if [ "$main_sha" != "$baseline" ]; then
      z_limitem 120 git -C "$ROOT_G" push -q --force-with-lease="main:$main_sha" origin "$baseline:refs/heads/main" ||
        die "$E_WYKONANIE" "force push main do baseline nie powiódł się (ochrona gałęzi?)"
    fi
    if [ -f "$(plik_stanu)" ]; then
      t="$(tmp_plik)"
      jq '.zadania = {}' "$(plik_stanu)" >"$t" && mv "$t" "$(plik_stanu)"
    fi
    rm -rf "$STAN/review/$PROJEKT-"*
    wyn="$("$SHCTL_DIR/shctl" task create --projekt "$PROJEKT" --plik "$ROOT_G/$plik_rel" --json)" ||
      die "$E_WYKONANIE" "task create po resecie nie powiódł się; powtórz reset-dryrun"
    mapa="$(jq -c '.wynik.mapa' <<<"$wyn")"
  fi
  wynik_json "$(jq -nc --arg b "$baseline" --argjson p "$zam_pr" --argjson i "$zam_is" --argjson m "$mapa" \
    --arg f "$plik_rel" '{baseline:$b, zamkniete_pr:$p, zamkniete_issue:$i, plik_zadan:$f, mapa:$m, zmiana:true}')"
}
