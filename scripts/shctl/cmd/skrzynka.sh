# shctl skrzynka przyjmij NAZWA: materiały właściciela ze skrzynki w vaulcie (SH/Skrzynka/NAZWA) kopiuje do
# docs/00-intake/zrodla na nowej gałęzi skrzynka/RRRRMMDD-HHMMSS, robi commit i PR, po zielonym CI scala
# PR (squash) i opróżnia skrzynkę. Pomija pliki ukryte i dowiązania; nic nie uruchamia.
# shellcheck shell=bash

# shellcheck source=../lib/zadania.sh
. "$SHCTL_DIR/lib/zadania.sh"
# shellcheck source=../lib/obsidian.sh
. "$SHCTL_DIR/lib/obsidian.sh"

SKR_KAT=""
sprzatnij_skrzynke() { [ -z "$SKR_KAT" ] || git -C "$ROOT_G" worktree remove "$SKR_KAT" 2>/dev/null || true; }

komenda_main() {
  local skr pliki br kat url n ci
  [ "${1:-}" = przyjmij ] || die "$E_UZYCIE" "użycie: shctl skrzynka przyjmij NAZWA"
  shift
  while [ $# -gt 0 ]; do case "$1" in -*) opcja_wspolna "$@"; shift "$ZJEDZONE" ;; *) PROJEKT="$1"; shift ;; esac; done
  zadania_init
  skr="$(skrzynka_kat "$PROJEKT")"
  [ -d "$skr" ] || die "$E_BRAK" "brak skrzynki ${skr:-(SH_OBSIDIAN_DIR)} (zakłada ją shctl obsidian link $PROJEKT)"
  pliki="$(cd "$skr" && find . \( -name '.*' -o -name _przeniesione -o -name __MACOSX \) ! -name . -prune -o -type f -print | sed 's#^\./##' | LC_ALL=C sort)"
  if [ -z "$pliki" ] || [ "$DRY" -eq 1 ]; then
    info "skrzynka $skr: ${pliki:+do przyjęcia: $(printf '%s\n' "$pliki" | paste -sd, -)}${pliki:-pusto}"
    wynik_json "$(jq -nc --arg p "$pliki" '{stan:(if $p == "" then "pusto" else "do_przyjecia" end), pliki:($p | split("\n") | map(select(length > 0)))}')"
    return 0
  fi
  br="skrzynka/$(date +%Y%m%d-%H%M%S)"
  kat="$WT/${br/\//-}"
  pobierz_main
  git -C "$ROOT_G" worktree add -q -b "$br" "$kat" "$(baza_main)" || die "$E_WYKONANIE" "worktree $kat nie powstał"
  SKR_KAT="$kat"
  PRZY_WYJSCIU=sprzatnij_skrzynke
  mkdir -p "$kat/docs/00-intake/zrodla"
  (cd "$skr" && printf '%s\n' "$pliki" | while IFS= read -r f; do mkdir -p "$kat/docs/00-intake/zrodla/$(dirname "$f")"; cp -- "$f" "$kat/docs/00-intake/zrodla/$f"; chmod 644 "$kat/docs/00-intake/zrodla/$f"; done)
  git -C "$kat" add -A docs/00-intake/zrodla && git -C "$kat" commit -qm "00-intake: materiały ze skrzynki" || die "$E_WYKONANIE" "commit nieudany"
  z_limitem 120 git -C "$kat" push -q origin "$br" || die "$E_WYKONANIE" "push $br nieudany"
  url="$(gh pr create --repo "$SLUG" --head "$br" --base main --title "00-intake: materiały ze skrzynki" \
    --body "Materiały ze skrzynki \`SH/Skrzynka/$PROJEKT\` (shctl skrzynka przyjmij), dane nieufne." | tail -1)" || die "$E_WYKONANIE" "gh pr create nieudane"
  n="${url##*/}"
  ci="$("$SHCTL_DIR/shctl" pr check "$n" --czekaj --projekt "$PROJEKT" --json | jq -r .wynik.ci)" || ci=blad
  [ "$ci" = pass ] || die "$E_ODMOWA" "PR #$n: CI $ci, skrzynka zostaje bez zmian ($url)"
  gh pr merge "$n" --repo "$SLUG" --squash --delete-branch >/dev/null || die "$E_WYKONANIE" "merge PR #$n nieudany ($url)"
  (cd "$skr" && printf '%s\n' "$pliki" | while IFS= read -r f; do rm -f -- "$f"; done; find . -mindepth 1 -type d -empty -delete)
  sprzatnij_skrzynke
  git -C "$ROOT_G" branch -D "$br" >/dev/null 2>&1 || uwaga "nie usunięto lokalnej gałęzi $br"
  info "PR #$n scalony, skrzynka opróżniona: $url"
  wynik_json "$(jq -nc --argjson n "$n" --arg u "$url" --arg p "$pliki" '{stan:"przyjeto", pr:$n, url:$u, pliki:($p | split("\n"))}')"
}
