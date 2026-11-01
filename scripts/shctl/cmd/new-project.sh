# shctl new-project NAZWA [--tryb S|M] [--public] [--opis "..."]
# Każdy krok sprawdza stan, więc przerwane zakładanie dokańcza się tą samą komendą.
# shellcheck shell=bash

# shellcheck source=../lib/porty.sh
. "$SHCTL_DIR/lib/porty.sh"
# shellcheck source=../lib/obsidian.sh
. "$SHCTL_DIR/lib/obsidian.sh"

KROKI='[]'
krok() {
  KROKI="$(jq -c --arg k "$1" '. + [$k]' <<<"$KROKI")"
  info "- $1"
}

repo_stan() {
  local slug="$1" wyj
  if wyj="$(gh repo view "$slug" --json templateRepository --jq '.templateRepository.name // ""' 2>&1)"; then
    printf 'jest:%s' "$wyj"
  elif printf '%s' "$wyj" | grep -q 'Could not resolve'; then
    printf 'brak'
  else
    die "$E_WYKONANIE" "gh repo view: $wyj"
  fi
}

czekaj_na_szablon() {
  local slug="$1" i
  # GitHub kopiuje szablon asynchronicznie.
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
    gh api "repos/$slug/contents/docs/konfiguracja.md" --silent >/dev/null 2>&1 && return 0
    sleep 1
  done
  die "$E_WYKONANIE" "repo $slug nie ma plików szablonu po 30 s"
}

komenda_main() {
  local nazwa="" tryb_arg="" public=0 opis="" slug stan katalog tryb_proj poprz e s origin
  local widocznosc=--private porty baza pliki rzeczy zrodlo tresc obs='null' zal=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --tryb) tryb_arg="$(wartosc "$@")"; shift 2 ;;
      --public) public=1; shift ;;
      --opis) opis="$(wartosc "$@")"; shift 2 ;;
      --projekt | --projekt=*) die "$E_UZYCIE" "new-project przyjmuje nazwę jako argument" ;;
      -*) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
      *)
        [ -z "$nazwa" ] || die "$E_UZYCIE" "nadmiarowy argument: $1"
        nazwa="$1"
        shift
        ;;
    esac
  done
  [ -n "$nazwa" ] || die "$E_UZYCIE" "użycie: shctl new-project NAZWA [--tryb S|M] [--public] [--opis \"...\"]"
  sprawdz_nazwe "$nazwa"
  case "${tryb_arg:-M}" in
    M) ;;
    S) uwaga "proces-v1.md: nowy projekt zaczyna od M lub L; S oznacza brak etapów DoD" ;;
    L) die "$E_UZYCIE" "tryb L jest dostępny dopiero w etapie wdrożenia B" ;;
    *) die "$E_UZYCIE" "--tryb: dozwolone S albo M" ;;
  esac
  [ "$public" -eq 0 ] || widocznosc=--public
  wymagaj gh git jq yq
  [ -f "$PORTY" ] || die "$E_BRAK" "brak $PORTY"

  PROJEKT="$nazwa"
  slug="$SH_GH_OWNER/$nazwa"
  katalog="$PROJEKTY/$nazwa"
  ROOT="$katalog"
  KONFIG="$ROOT/docs/konfiguracja.md"
  ST="$ROOT/docs/status.md"
  stan="$(repo_stan "$slug")"
  case "$stan" in
    brak)
      krok "utwórz repo $slug z szablonu $SH_TEMPLATE (${widocznosc#--})"
      if [ "$DRY" -eq 0 ]; then
        gh repo create "$slug" --template "$SH_GH_OWNER/$SH_TEMPLATE" "$widocznosc" \
          ${opis:+--description "$(komorka "$opis" | cut -c1-300)"} >/dev/null ||
          die "$E_WYKONANIE" "nie można utworzyć $slug"
      fi
      ;;
    "jest:$SH_TEMPLATE") krok "repo $slug już istnieje" ;;
    *) die "$E_ODMOWA" "repo $slug istnieje, ale nie powstało z $SH_TEMPLATE; nie ruszam go" ;;
  esac

  if [ -d "$katalog" ]; then
    origin="$(git -C "$katalog" config --get remote.origin.url || true)"
    case "$origin" in
      *"$slug" | *"$slug.git") krok "klon $katalog już istnieje" ;;
      *) die "$E_ODMOWA" "$katalog istnieje i nie jest klonem $slug" ;;
    esac
  else
    krok "sklonuj do $katalog"
    if [ "$DRY" -eq 0 ]; then
      czekaj_na_szablon "$slug"
      mkdir -p "$PROJEKTY"
      gh repo clone "$slug" "$katalog" -- --quiet >/dev/null 2>&1 || die "$E_WYKONANIE" "nie można sklonować $slug"
    fi
  fi

  krok "załóż etykiety (setup-labels.sh)"
  krok "ustaw konfigurację: tryb ${tryb_arg:-M}, etap_wdrozenia A, data"
  krok "zarezerwuj blok portów"
  krok "oznacz etapy spoza trybu jako pominiety, zaktualizuj status.md"
  [ -z "$opis" ] || krok "zapisz opis w docs/00-intake/zrodlo.md"
  krok "commit i push na main"
  if [ -n "${SH_OBSIDIAN_DIR:-}" ]; then
    krok "lekki klon docs/ w $(obsidian_kat "$nazwa")"
  else
    uwaga "brak SH_OBSIDIAN_DIR w $SH_CONFIG, pomijam klon w Obsidianie"
  fi

  if [ "$DRY" -eq 1 ]; then
    baza="$(porty_rezerwuj "$nazwa" 55 | jq -r .zakres)"
    info "blok portów: $baza"
    if [ -n "${SH_OBSIDIAN_DIR:-}" ]; then
      obs="$(jq -nc --arg k "$(obsidian_kat "$nazwa")" '{katalog:$k, utworzono:false}')"
    fi
    wynik_json "$(jq -nc --arg r "$slug" --arg k "$katalog" --argjson s "$KROKI" --arg b "$baza" --argjson o "$obs" \
      '{repo:$r, katalog:$k, kroki:$s, porty:$b, obsidian:$o}')"
    return 0
  fi

  [ -f "$KONFIG" ] || die "$E_BRAK" "$katalog nie ma docs/konfiguracja.md"
  rzeczy="$(bash "$ROOT/scripts/setup-labels.sh" --repo "$slug" 2>&1)" || die "$E_WYKONANIE" "setup-labels: $rzeczy"

  poprz="$(fm_get "$KONFIG" data)"
  tryb_proj="$(fm_get "$KONFIG" tryb_procesu)"
  if [ -z "$poprz" ]; then
    fm_set "$KONFIG" tryb_procesu "${tryb_arg:-M}"
    fm_set "$KONFIG" etap_wdrozenia A
    fm_set "$KONFIG" data "$(dzis)"
  elif [ -n "$tryb_arg" ] && [ "$tryb_arg" != "$tryb_proj" ]; then
    die "$E_ODMOWA" "projekt ma tryb $tryb_proj; zmiana trybu to decyzja właściciela (edytuj konfiguracja.md)"
  fi
  tryb_proj="$(fm_get "$KONFIG" tryb_procesu)"

  porty="$(porty_rezerwuj "$nazwa" 55)"
  baza="$(jq -r .baza <<<"$porty")"
  fm_set "$KONFIG" blok_portow "$(jq -r .zakres <<<"$porty")"
  porty_do_configu "$ROOT" "$nazwa" "$baza"

  for e in $ETAPY; do
    etap_w_trybie "$e" "$tryb_proj" && continue
    s="$(fm_get "$ROOT/docs/$e/DoD.md" status)"
    [ "$s" != todo ] || fm_set "$ROOT/docs/$e/DoD.md" status pominiety
  done
  odswiez_etap

  if [ -n "$opis" ]; then
    zrodlo="$ROOT/docs/00-intake/zrodlo.md"
    tresc="$(cat "$zrodlo")"
    case "$tresc" in
      *"$opis"*) ;;
      *) printf '\n%s\n' "$opis" >>"$zrodlo" ;;
    esac
  fi

  rzeczy="$(bash "$ROOT/scripts/check-dod.sh" "$ROOT" 2>&1)" || die "$E_ODMOWA" "check-dod: $rzeczy"

  # Jawna lista: powtórka na żywym projekcie nie zabiera cudzych zmian.
  pliki="docs/konfiguracja.md docs/status.md docs/00-intake/zrodlo.md"
  for e in $ETAPY; do pliki="$pliki docs/$e/DoD.md"; done
  [ ! -f "$ROOT/supabase/config.toml" ] || pliki="$pliki supabase/config.toml"
  # shellcheck disable=SC2086
  if [ -n "$(git -C "$ROOT" status --porcelain -- $pliki)" ]; then
    s="$(git -C "$ROOT" symbolic-ref --short -q HEAD || true)"
    [ "$s" = main ] || die "$E_ODMOWA" "commit konfiguracji wymaga gałęzi main, a jest '$s'"
    git -C "$ROOT" add -- $pliki
    git -C "$ROOT" commit -q -m "shctl: konfiguracja projektu $nazwa (tryb $tryb_proj)" -- $pliki ||
      die "$E_WYKONANIE" "commit nieudany"
  fi
  if [ "$(git -C "$ROOT" rev-list --count origin/main..HEAD)" -gt 0 ]; then
    git -C "$ROOT" push -q origin HEAD:main || die "$E_WYKONANIE" "push nieudany"
  fi

  info "Gotowe: https://github.com/$slug"
  # Po pushu: klon ma dostać gotową konfigurację.
  if [ -n "${SH_OBSIDIAN_DIR:-}" ]; then
    zal="$(obsidian_polacz "$nazwa")"
    obs="$(jq -nc --arg k "$(obsidian_kat "$nazwa")" --argjson z "$zal" '{katalog:$k, utworzono:($z == 1)}')"
    info "Klon docs/: $(obsidian_kat "$nazwa")"
    info "W Obsidianie wystarczy włączyć Obsidian Git dla tego folderu."
  fi
  wynik_json "$(jq -nc --arg r "$slug" --arg k "$katalog" --argjson s "$KROKI" --argjson p "$porty" --argjson o "$obs" \
    --arg t "$tryb_proj" '{repo:$r, katalog:$k, tryb:$t, kroki:$s, porty:$p, obsidian:$o}')"
}
