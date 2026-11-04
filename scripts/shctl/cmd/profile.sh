# shctl profile update [--baseline]: profile ról (.claude/roles/*/settings.json) istniejącego projektu
# z main szablonu SH_TEMPLATE (docs/shctl.md, „profile update”). Klon projektu musi stać na main:
# komenda nie przełącza gałęzi. Zmiana to commit na main i push. --baseline dodatkowo przesuwa tag
# baseline na commit „baseline + profile” (bez przełączania gałęzi, przez osobny indeks), a poprzedni
# tag zachowuje jako baseline-RRRRMMDD-HHMMSS. Zadania w toku mają stare profile do rebase'u na main.
# shellcheck shell=bash

# shellcheck source=../lib/zadania.sh
. "$SHCTL_DIR/lib/zadania.sh"

# Profile z klonu szablonu: ścieżki względne, po jednej w linii.
profile_szablonu() {
  (cd "$1" && find .claude/roles -mindepth 2 -maxdepth 2 -name settings.json -type f | sed 's#^\./##' | sort)
}

# Ścieżki z listy, których treść w drzewie REF (albo w katalogu roboczym przy REF pustym) różni się od szablonu.
rozne() {
  local ref="$1" p
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ -n "$ref" ]; then
      git -C "$ROOT_G" show "$ref:$p" 2>/dev/null | cmp -s - "$SZABLON/$p" || echo "$p"
    else
      cmp -s "$ROOT_G/$p" "$SZABLON/$p" || echo "$p"
    fi
  done <<<"$PLIKI"
}

# Commit REF + profile szablonu, bez dotykania indeksu i katalogu roboczego. Wypisuje SHA.
commit_z_profilami() {
  local ref="$1" msg="$2" idx p h drzewo
  idx="$SHCTL_TMP/indeks"
  rm -f "$idx"
  GIT_INDEX_FILE="$idx" git -C "$ROOT_G" read-tree "$ref" || return 1
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    h="$(git -C "$ROOT_G" hash-object -w "$SZABLON/$p")" || return 1
    GIT_INDEX_FILE="$idx" git -C "$ROOT_G" update-index --add --cacheinfo "100644,$h,$p" || return 1
  done <<<"$PLIKI"
  drzewo="$(GIT_INDEX_FILE="$idx" git -C "$ROOT_G" write-tree)" || return 1
  git -C "$ROOT_G" commit-tree "$drzewo" -p "$ref" -m "$msg"
}

komenda_main() {
  local akcja="${1:-}" z_baseline=0 sha_szablonu galaz zmiany_main zmiany_base baseline="" nowy_base="" archiwum=""
  local main_przed main_po="" ref_main p
  [ "$akcja" = update ] || die "$E_UZYCIE" "użycie: shctl profile update [--baseline] [--dry-run] [--projekt NAZWA]"
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --baseline) z_baseline=1; shift ;;
      *) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
    esac
  done
  zadania_init

  galaz="$(git -C "$ROOT_G" symbolic-ref --short -q HEAD || true)"
  [ "$galaz" = main ] || die "$E_ODMOWA" "$ROOT_G stoi na '${galaz:-odłączony HEAD}', nie na main; profile update nie przełącza gałęzi"

  SZABLON="$SHCTL_TMP/szablon"
  git_gh -t 120 clone -q --depth 1 --branch main "https://github.com/$SH_GH_OWNER/$SH_TEMPLATE.git" "$SZABLON" ||
    die "$E_WYKONANIE" "nie można pobrać szablonu $SH_GH_OWNER/$SH_TEMPLATE"
  sha_szablonu="$(git -C "$SZABLON" rev-parse HEAD)"
  PLIKI="$(profile_szablonu "$SZABLON")"
  [ -n "$PLIKI" ] || die "$E_BRAK" "szablon $SH_TEMPLATE nie ma .claude/roles/*/settings.json"

  git_gh -t 120 -C "$ROOT_G" fetch -q --force origin main 'refs/tags/*:refs/tags/*' ||
    die "$E_WYKONANIE" "git fetch origin nie powiódł się"
  git -C "$ROOT_G" merge-base --is-ancestor HEAD origin/main ||
    die "$E_ODMOWA" "main w $ROOT_G ma commity spoza origin/main; wypchnij albo zsynchronizuj ręcznie"
  # --dry-run niczego nie zmienia, więc porównuje z origin/main bez przewijania klonu.
  ref_main=origin/main
  if [ "$DRY" -eq 0 ]; then
    git -C "$ROOT_G" merge -q --ff-only origin/main || die "$E_WYKONANIE" "nie można przewinąć main do origin/main"
    ref_main=HEAD
  fi
  main_przed="$(git -C "$ROOT_G" rev-parse "$ref_main")"
  # shellcheck disable=SC2086
  [ -z "$(git -C "$ROOT_G" status --porcelain -- $PLIKI)" ] ||
    die "$E_ODMOWA" "niezacommitowane zmiany w profilach ról w $ROOT_G"

  zmiany_main="$(rozne "$ref_main")"
  zmiany_base=""
  if [ "$z_baseline" -eq 1 ]; then
    baseline="$(git -C "$ROOT_G" rev-parse -q --verify 'refs/tags/baseline^{commit}')" ||
      die "$E_BRAK" "brak tagu baseline w $SLUG"
    zmiany_base="$(rozne "$baseline")"
  fi

  info "profile ról z $SH_TEMPLATE ${sha_szablonu:0:7}:"
  info "- main: $(if [ -n "$zmiany_main" ]; then printf '%s' "$zmiany_main" | paste -sd ' ' -; else echo "bez zmian"; fi)"
  [ "$z_baseline" -eq 0 ] ||
    info "- baseline ${baseline:0:7}: $(if [ -n "$zmiany_base" ]; then printf '%s' "$zmiany_base" | paste -sd ' ' -; else echo "bez zmian"; fi)"

  if [ "$DRY" -eq 0 ]; then
    if [ -n "$zmiany_main" ]; then
      while IFS= read -r p; do cp "$SZABLON/$p" "$ROOT_G/$p"; done <<<"$zmiany_main"
      # shellcheck disable=SC2086
      git -C "$ROOT_G" add -- $zmiany_main
      git -C "$ROOT_G" commit -qm "profile ról z $SH_TEMPLATE ${sha_szablonu:0:7}" ||
        die "$E_WYKONANIE" "commit profili nie powiódł się"
      git_gh -t 120 -C "$ROOT_G" push -q origin main ||
        die "$E_WYKONANIE" "push main nie powiódł się; wypchnij ręcznie"
      main_po="$(git -C "$ROOT_G" rev-parse HEAD)"
    fi
    if [ -n "$zmiany_base" ]; then
      nowy_base="$(commit_z_profilami "$baseline" "baseline: profile ról z $SH_TEMPLATE ${sha_szablonu:0:7}")" ||
        die "$E_WYKONANIE" "nie można zbudować commita baseline z profilami"
      archiwum="baseline-$(date -u +%Y%m%d-%H%M%S)"
      git -C "$ROOT_G" tag "$archiwum" "$baseline" || die "$E_WYKONANIE" "nie można zapisać tagu $archiwum"
      git -C "$ROOT_G" tag -f baseline "$nowy_base" >/dev/null
      git_gh -t 120 -C "$ROOT_G" push -q origin "refs/tags/$archiwum" ||
        die "$E_WYKONANIE" "push tagu $archiwum nie powiódł się; baseline nie został przesunięty na origin"
      git_gh -t 120 -C "$ROOT_G" push -q --force origin refs/tags/baseline ||
        die "$E_WYKONANIE" "push tagu baseline nie powiódł się; lokalnie baseline = ${nowy_base:0:7}"
      info "baseline: ${baseline:0:7} -> ${nowy_base:0:7} (poprzedni jako $archiwum)"
    fi
  fi

  wynik_json "$(jq -nc --arg s "$sha_szablonu" --arg mp "$main_przed" --arg mn "$main_po" \
    --arg zm "$zmiany_main" --arg zb "$zmiany_base" --arg b "$baseline" --arg nb "$nowy_base" --arg a "$archiwum" \
    --argjson zbase "$z_baseline" '
    def lista: split("\n") | map(select(length > 0));
    {szablon:$s, main:{przed:$mp, po:(if $mn == "" then null else $mn end), pliki:($zm | lista)},
     baseline:(if $zbase == 1 then {przed:$b, po:(if $nb == "" then null else $nb end),
       archiwum:(if $a == "" then null else $a end), pliki:($zb | lista)} else null end),
     zmiana:((($zm | lista) + ($zb | lista)) | length > 0)}')"
}
