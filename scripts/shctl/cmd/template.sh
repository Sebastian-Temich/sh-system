# shctl template update [--baseline] [--force]: pliki zarządzane przez szablon SH_TEMPLATE (scripts/,
# .github/workflows/, .claude/roles/, AGENTS.md, docs/_szablony/) z main szablonu do istniejącego
# projektu (docs/shctl.md, „template update”). Plik projektu równy którejś wersji z historii szablonu
# to treść szablonu i dostaje bieżącą wersję; plik zmieniony w projekcie zostaje (pominięty), chyba że
# --force. Brakujące pliki dochodzą; pliki usunięte z szablonu zostają w projekcie. Klon projektu musi
# stać na main: komenda nie przełącza gałęzi; zmiana to commit na main i push. --baseline robi to samo
# na najnowszym baseline i zapisuje wynik jako nowy tag baseline-RRRRMMDD (bez przesuwania tagów).
# shellcheck shell=bash

# shellcheck source=../lib/zadania.sh
. "$SHCTL_DIR/lib/zadania.sh"

ZARZADZANE="scripts .github/workflows .claude/roles AGENTS.md docs/_szablony"

# Decyzje dla REF (pusty: katalog roboczy main): wiersze „akcja<TAB>ścieżka”, akcja: nowy,
# aktualizacja, nadpisany (--force) albo pominiety (zmieniony w projekcie). Pliki równe szablonowi pomija.
decyzje() {
  local ref="$1" p sz pr
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    sz="$(git -C "$SZABLON" rev-parse "HEAD:$p")"
    pr="$(git -C "$ROOT_G" rev-parse -q --verify "$ref:$p" 2>/dev/null || true)"
    if [ -z "$pr" ]; then printf 'nowy\t%s\n' "$p"
    elif [ "$pr" = "$sz" ]; then continue
    elif grep -qxF "$pr $p" "$HISTORIA"; then printf 'aktualizacja\t%s\n' "$p"
    elif [ "$FORCE" -eq 1 ]; then printf 'nadpisany\t%s\n' "$p"
    else printf 'pominiety\t%s\n' "$p"; fi
  done <<<"$PLIKI"
}

do_zapisu() { awk -F'\t' '$1 != "pominiety" { print $2 }' <<<"$1"; }

# Commit REF + pliki szablonu z listy, bez dotykania indeksu i katalogu roboczego. Wypisuje SHA.
commit_z_plikami() {
  local ref="$1" msg="$2" lista="$3" idx="$SHCTL_TMP/indeks" p
  rm -f "$idx"
  GIT_INDEX_FILE="$idx" git -C "$ROOT_G" read-tree "$ref" || return 1
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    git -C "$SZABLON" cat-file blob "HEAD:$p" | git -C "$ROOT_G" hash-object -w --stdin >/dev/null || return 1
    GIT_INDEX_FILE="$idx" git -C "$ROOT_G" update-index --add \
      --cacheinfo "$(git -C "$SZABLON" ls-tree HEAD -- "$p" | awk '{ print $1 "," $3 }'),$p" || return 1
  done <<<"$lista"
  git -C "$ROOT_G" commit-tree "$(GIT_INDEX_FILE="$idx" git -C "$ROOT_G" write-tree)" -p "$ref" -m "$msg"
}

# Wolna nazwa tagu baseline-RRRRMMDD (kolejny tego dnia: -2, -3).
nowy_tag_baseline() {
  local t i=2
  t="baseline-$(date +%Y%m%d)"
  while git -C "$ROOT_G" rev-parse -q --verify "refs/tags/$t" >/dev/null ||
    git_gh -t 60 -C "$ROOT_G" ls-remote --exit-code --tags origin "refs/tags/$t" >/dev/null 2>&1; do
    t="baseline-$(date +%Y%m%d)-$i"
    i=$((i + 1))
  done
  printf '%s' "$t"
}

opis() { if [ -n "$1" ]; then printf '%s' "$1" | awk -F'\t' '{ printf "%s%s (%s)", (NR > 1 ? ", " : ""), $2, $1 }'; else printf 'bez zmian'; fi; }

komenda_main() {
  local z_baseline=0 sha galaz dec_main dec_base="" lista base="" base_tag="" nowy_tag="" nowy_base="" main_po="" p
  FORCE=0
  [ "${1:-}" = update ] || die "$E_UZYCIE" "użycie: shctl template update [--projekt NAZWA] [--baseline] [--force] [--dry-run]"
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --baseline) z_baseline=1; shift ;;
      --force) FORCE=1; shift ;;
      *) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
    esac
  done
  zadania_init
  galaz="$(git -C "$ROOT_G" symbolic-ref --short -q HEAD || true)"
  [ "$galaz" = main ] || die "$E_ODMOWA" "$ROOT_G stoi na '${galaz:-odłączony HEAD}', nie na main; template update nie przełącza gałęzi"

  SZABLON="$SHCTL_TMP/szablon"
  git_gh -t 120 clone -q --branch main "https://github.com/$SH_GH_OWNER/$SH_TEMPLATE.git" "$SZABLON" ||
    die "$E_WYKONANIE" "nie można pobrać szablonu $SH_GH_OWNER/$SH_TEMPLATE"
  sha="$(git -C "$SZABLON" rev-parse HEAD)"
  # shellcheck disable=SC2086
  PLIKI="$(git -C "$SZABLON" ls-files -- $ZARZADZANE)"
  [ -n "$PLIKI" ] || die "$E_BRAK" "szablon $SH_TEMPLATE nie ma plików zarządzanych ($ZARZADZANE)"
  HISTORIA="$SHCTL_TMP/historia"
  # shellcheck disable=SC2086
  git -C "$SZABLON" log --raw --no-abbrev --no-renames --format= -- $ZARZADZANE |
    awk '/^:/ { split($0, a, "\t"); split(a[1], b, " "); print b[4] " " a[2] }' | sort -u >"$HISTORIA"

  git_gh -t 120 -C "$ROOT_G" fetch -q origin main 'refs/tags/*:refs/tags/*' || die "$E_WYKONANIE" "git fetch origin nie powiódł się"
  git -C "$ROOT_G" merge-base --is-ancestor HEAD origin/main ||
    die "$E_ODMOWA" "main w $ROOT_G ma commity spoza origin/main; wypchnij albo zsynchronizuj ręcznie"
  if [ "$DRY" -eq 0 ]; then
    # shellcheck disable=SC2086
    [ -z "$(git -C "$ROOT_G" status --porcelain -- $ZARZADZANE)" ] ||
      die "$E_ODMOWA" "niezacommitowane zmiany w plikach szablonu w $ROOT_G"
    git -C "$ROOT_G" merge -q --ff-only origin/main || die "$E_WYKONANIE" "nie można przewinąć main do origin/main"
  fi
  dec_main="$(decyzje origin/main)"
  if [ "$z_baseline" -eq 1 ]; then
    base_tag="$(najnowszy_baseline)" || die "$E_BRAK" "brak tagu baseline w $SLUG"
    base="$(git -C "$ROOT_G" rev-parse "refs/tags/$base_tag^{commit}")"
    dec_base="$(decyzje "$base")"
  fi
  info "pliki szablonu $SH_TEMPLATE ${sha:0:7}:"
  info "- main: $(opis "$dec_main")"
  [ "$z_baseline" -eq 0 ] || info "- $base_tag ${base:0:7}: $(opis "$dec_base")"
  grep -q '^pominiety' <<<"$dec_main$dec_base" && uwaga "pliki zmienione w projekcie pominięte; nadpisanie: --force"

  if [ "$DRY" -eq 0 ]; then
    lista="$(do_zapisu "$dec_main")"
    if [ -n "$lista" ]; then
      while IFS= read -r p; do
        mkdir -p "$(dirname "$ROOT_G/$p")"
        cp -p "$SZABLON/$p" "$ROOT_G/$p"
        git -C "$ROOT_G" add -- "$p"
      done <<<"$lista"
      git -C "$ROOT_G" commit -qm "szablon: pliki z $SH_TEMPLATE ${sha:0:7}" || die "$E_WYKONANIE" "commit nie powiódł się"
      git_gh -t 120 -C "$ROOT_G" push -q origin main || die "$E_WYKONANIE" "push main nie powiódł się; wypchnij ręcznie"
      main_po="$(git -C "$ROOT_G" rev-parse HEAD)"
    fi
    lista="$(do_zapisu "$dec_base")"
    if [ -n "$lista" ]; then
      nowy_base="$(commit_z_plikami "$base" "baseline: pliki z $SH_TEMPLATE ${sha:0:7}" "$lista")" ||
        die "$E_WYKONANIE" "nie można zbudować commita baseline"
      nowy_tag="$(nowy_tag_baseline)"
      git -C "$ROOT_G" tag "$nowy_tag" "$nowy_base" || die "$E_WYKONANIE" "nie można utworzyć tagu $nowy_tag"
      git_gh -t 120 -C "$ROOT_G" push -q origin "refs/tags/$nowy_tag" || die "$E_WYKONANIE" "push tagu $nowy_tag nie powiódł się"
      info "nowy baseline: $nowy_tag (${nowy_base:0:7}, z $base_tag); reset-dryrun bierze najnowszy albo baseline_tag z konfiguracji"
    fi
  fi

  wynik_json "$(jq -nc --arg s "$sha" --arg dm "$dec_main" --arg db "$dec_base" --arg mp "$main_po" \
    --arg bt "$base_tag" --arg b "$base" --arg nt "$nowy_tag" --arg nb "$nowy_base" --argjson zb "$z_baseline" '
    def lista: split("\n") | map(select(length > 0) | split("\t") | {akcja:.[0], plik:.[1]});
    {szablon:$s, main:{po:(if $mp == "" then null else $mp end), pliki:($dm | lista)},
     baseline:(if $zb == 1 then {z:$bt, przed:$b, tag:(if $nt == "" then null else $nt end),
       po:(if $nb == "" then null else $nb end), pliki:($db | lista)} else null end),
     zmiana:(([$dm, $db] | map(lista) | add | map(select(.akcja != "pominiety")) | length) > 0)}')"
}
