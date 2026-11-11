# shctl sprzataj [--dry-run]: sprzątanie po builderze i orkiestratorze. Usuwa worktree w
# /Users/Shared/sh/wt-system/ i /Users/Shared/sh/wt/ oraz lokalne gałęzie repo w /Users/Shared/sh i
# /Users/Shared/sh/projekty tylko wtedy, gdy PR gałęzi ma stan MERGED albo CLOSED (gh pr list). Bez
# --force: worktree z niezacommitowanymi zmianami, gałąź z commitami spoza PR, gałąź bieżąca i main
# zostają i trafiają do pominiętych. Gałąź po squash merge usuwa git branch -D (git branch -d jej nie
# usunie, bo commity nie są w main), dlatego robi to skrypt, nie agent.
# shellcheck shell=bash

WT_KATALOGI="$SH_DIR/wt-system $SH_DIR/wt"

# owner/repo z adresu origin (https albo ssh GitHuba); pusto, gdy to nie GitHub albo repo nie ma
# origin (np. lokalne sh-test). git config bez klucza kończy się kodem 1, który przy pipefail
# przerywał całe sprzątanie, stąd || true.
slug_repo() {
  { git -C "$1" config --get remote.origin.url 2>/dev/null || true; } |
    sed -nE 's#^(https://github\.com/|git@github\.com:)([^/]+/[^/]+)$#\2#p' | sed 's/\.git$//'
}

ma_origin() { git -C "$1" config --get remote.origin.url >/dev/null 2>&1; }

# Stan PR gałęzi: „STAN<TAB>headRefOid” ostatniego PR albo pusto (brak PR).
pr_galezi() {
  gh pr list --repo "$1" --head "$2" --state all --limit 20 --json number,state,headRefOid 2>/dev/null |
    jq -r 'max_by(.number) // empty | "\(.state)\t\(.headRefOid)"'
}

pomin() { printf '%s\t%s\n' "$1" "$2" >>"$SHCTL_TMP/pominiete"; [ "$JSON" -eq 1 ] || info "pominięto $1: $2"; }

# Repo główne (wspólny katalog .git) worktree.
repo_glowne() { (cd "$1" && cd "$(git rev-parse --git-common-dir)/.." && pwd -P); }

sprzataj_galaz() {
  local repo="$1" br="$2" slug="$3" pr st oid
  [ "$br" != main ] && [ "$br" != master ] || return 0
  [ "$br" != "$(git -C "$repo" symbolic-ref --short -q HEAD || true)" ] || return 0
  pr="$(pr_galezi "$slug" "$br")"
  [ -n "$pr" ] || { pomin "$repo:$br" "brak PR"; return 0; }
  st="${pr%%	*}"
  oid="${pr#*	}"
  case "$st" in MERGED | CLOSED) ;; *) pomin "$repo:$br" "PR $st"; return 0 ;; esac
  if [ -n "$oid" ] && [ "$(git -C "$repo" rev-parse "refs/heads/$br")" != "$oid" ] &&
    ! git -C "$repo" merge-base --is-ancestor "refs/heads/$br" "$oid" 2>/dev/null; then
    pomin "$repo:$br" "lokalne commity spoza PR"
    return 0
  fi
  if git -C "$repo" worktree list --porcelain | grep -qxF "branch refs/heads/$br"; then
    pomin "$repo:$br" "gałąź w worktree"
    return 0
  fi
  [ "$DRY" -eq 1 ] || git -C "$repo" branch -D -q "$br" || { pomin "$repo:$br" "git branch -D nieudane"; return 0; }
  printf '%s\n' "$repo:$br" >>"$SHCTL_TMP/galezie"
  info "gałąź $br ($repo, PR $st)"
}

komenda_main() {
  local k repo br slug pr st kat
  while [ $# -gt 0 ]; do opcja_wspolna "$@"; shift "$ZJEDZONE"; done
  wymagaj git gh jq
  : >"$SHCTL_TMP/worktree"
  : >"$SHCTL_TMP/galezie"
  : >"$SHCTL_TMP/pominiete"

  # 1. Worktree w dwóch katalogach: wt-system/X i wt/NAZWA/X.
  for k in "$SH_DIR"/wt-system/*/ "$SH_DIR"/wt/*/*/; do
    kat="${k%/}"
    [ -e "$kat/.git" ] || continue
    repo="$(repo_glowne "$kat")" || { pomin "$kat" "nie można ustalić repo"; continue; }
    br="$(git -C "$kat" symbolic-ref --short -q HEAD || true)"
    [ -n "$br" ] || { pomin "$kat" "odłączony HEAD"; continue; }
    slug="$(slug_repo "$repo")"
    ma_origin "$repo" || { pomin "$kat" "repo bez origin"; continue; }
    [ -n "$slug" ] || { pomin "$kat" "origin poza GitHubem"; continue; }
    pr="$(pr_galezi "$slug" "$br")"
    st="${pr%%	*}"
    case "$st" in MERGED | CLOSED) ;; *) pomin "$kat" "PR gałęzi $br: ${st:-brak}"; continue ;; esac
    [ -z "$(git -C "$kat" status --porcelain)" ] || { pomin "$kat" "niezacommitowane zmiany"; continue; }
    if [ "$DRY" -eq 0 ]; then
      git -C "$repo" worktree remove "$kat" || { pomin "$kat" "git worktree remove nieudane"; continue; }
    fi
    printf '%s\n' "$kat" >>"$SHCTL_TMP/worktree"
    info "worktree $kat (PR $st)"
  done

  # 2. Lokalne gałęzie repo w SH_DIR i SH_DIR/projekty.
  for k in "$SH_DIR"/*/ "$SH_DIR"/projekty/*/; do
    repo="${k%/}"
    [ -d "$repo/.git" ] || continue
    slug="$(slug_repo "$repo")"
    ma_origin "$repo" || { pomin "$repo" "repo bez origin"; continue; }
    [ -n "$slug" ] || continue
    [ "$DRY" -eq 1 ] || git -C "$repo" worktree prune
    while IFS= read -r br; do
      sprzataj_galaz "$repo" "$br" "$slug"
    done < <(git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads)
  done

  wynik_json "$(jq -nc --rawfile w "$SHCTL_TMP/worktree" --rawfile g "$SHCTL_TMP/galezie" --rawfile p "$SHCTL_TMP/pominiete" '
    def l: split("\n") | map(select(length > 0));
    {worktree:($w | l), galezie:($g | l), pominiete:($p | l | map(split("\t") | {co:.[0], powod:.[1]}))}')"
}
