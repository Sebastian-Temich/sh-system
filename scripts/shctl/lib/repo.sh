# Tożsamość repo projektu na GitHubie: opis, tematy, strona, ochrona gałęzi. Używają new-project i repo opis.
# gh repo edit i rulesety zmienia wyłącznie shctl (orkiestrator pokazuje komendę właścicielowi przed
# wykonaniem: shctl repo opis --dry-run).
# shellcheck shell=bash

# Etykiety runnera serwera dla repo prywatnych (zmienna repo SH_RUNS_ON, JSON dla runs-on w workflowach).
SH_RUNNER_PRYWATNY="${SH_RUNNER_PRYWATNY:-[\"self-hosted\",\"sh-imac\"]}"
RULESET_NAZWA="sh-ochrona-galezi"

# Argumenty gh repo edit: repo_edit_argumenty SLUG OPIS TEMATY_CSV STRONA [--usuwanie-galezi]
repo_edit_argumenty() {
  local slug="$1" opis="$2" tematy="$3" strona="$4" t reszta
  REPO_EDIT=(gh repo edit "$slug")
  [ -z "$opis" ] || REPO_EDIT+=(--description "$opis")
  [ -z "$strona" ] || REPO_EDIT+=(--homepage "$strona")
  reszta="$tematy,"
  while [ -n "$reszta" ]; do
    t="${reszta%%,*}"
    reszta="${reszta#*,}"
    t="$(printf '%s' "$t" | tr -d ' ')"
    [ -z "$t" ] || REPO_EDIT+=(--add-topic "$t")
  done
  [ "${5:-}" != --usuwanie-galezi ] || REPO_EDIT+=(--delete-branch-on-merge)
}

# Komenda w postaci do pokazania właścicielowi (cytowana jak w powłoce).
repo_edit_tekst() {
  local a out=""
  for a in "${REPO_EDIT[@]}"; do
    case "$a" in
      *[!A-Za-z0-9._/:,=@+-]*) out="$out '$(printf '%s' "$a" | sed "s/'/'\\\\''/g")'" ;;
      *) out="$out $a" ;;
    esac
  done
  printf '%s' "${out# }"
}

repo_tozsamosc() {
  repo_edit_argumenty "$1" "$2" "$3" "$4" --usuwanie-galezi
  [ "$DRY" -eq 1 ] && return 0
  "${REPO_EDIT[@]}" >/dev/null
}

# Ruleset na main i production: zakaz usuwania i force push (non_fast_forward). Idempotentny po nazwie.
repo_ruleset() {
  local slug="$1" t
  [ "$DRY" -eq 0 ] || return 0
  if gh api "repos/$slug/rulesets" 2>/dev/null | jq -e --arg n "$RULESET_NAZWA" 'any(.[]?; .name == $n)' >/dev/null; then
    return 0
  fi
  t="$(tmp_plik)"
  jq -n --arg n "$RULESET_NAZWA" '{
    name: $n, target: "branch", enforcement: "active",
    conditions: {ref_name: {include: ["refs/heads/main", "refs/heads/production"], exclude: []}},
    rules: [{type: "deletion"}, {type: "non_fast_forward"}]}' >"$t"
  gh api -X POST "repos/$slug/rulesets" --input "$t" >/dev/null 2>&1
}
