# shctl new-project NAZWA --opis "krótki opis repo" [--zlecenie "TREŚĆ ZLECENIA"] [--tryb S|M] [--prywatny]
# Repo zwykłe, nie z szablonu GitHuba (bez „generated from”): pliki szablonu SH_TEMPLATE trafiają do niego
# pierwszym commitem po skanie gitleaks. Domyślnie publiczne; --prywatny tylko na wyraźne polecenie
# właściciela (CI na runnerze serwera: zmienna repo SH_RUNS_ON). Opis repo (--opis, wymagany, do 350
# znaków), temat sh-projekt, ruleset sh-ochrona-galezi (bez usuwania i force push na main i production).
# Każdy krok sprawdza stan, więc przerwane zakładanie dokańcza się tą samą komendą.
# shellcheck shell=bash

# shellcheck source=../lib/porty.sh
. "$SHCTL_DIR/lib/porty.sh"
# shellcheck source=../lib/obsidian.sh
. "$SHCTL_DIR/lib/obsidian.sh"
# shellcheck source=../lib/repo.sh
. "$SHCTL_DIR/lib/repo.sh"

KROKI='[]'
krok() {
  KROKI="$(jq -c --arg k "$1" '. + [$k]' <<<"$KROKI")"
  info "- $1"
}

# brak, nasz (temat sh-projekt, repo z szablonu albo puste) albo obcy.
repo_stan() {
  local slug="$1" wyj
  if wyj="$(gh repo view "$slug" --json isEmpty,repositoryTopics,templateRepository 2>&1)"; then
    jq -r --arg t "$SH_TEMPLATE" '
      if ((.repositoryTopics // []) | map(.name? // .) | index("sh-projekt")) != null
        or (.templateRepository.name // "") == $t or .isEmpty == true then "nasz" else "obcy" end' <<<"$wyj" 2>/dev/null ||
      echo obcy
  elif printf '%s' "$wyj" | grep -q 'Could not resolve'; then
    printf 'brak'
  else
    die "$E_WYKONANIE" "gh repo view: $wyj"
  fi
}

# Pierwszy commit nowego projektu: pliki szablonu bez jego historii, README z nazwą i opisem.
zaloz_z_szablonu() {
  local katalog="$1" slug="$2" opis="$3" sha t
  t="$(tmp_plik).szablon"
  git_gh -t 120 clone -q --depth 1 "https://github.com/$SH_GH_OWNER/$SH_TEMPLATE.git" "$t" 2>/dev/null ||
    die "$E_WYKONANIE" "nie można pobrać szablonu $SH_GH_OWNER/$SH_TEMPLATE"
  sha="$(git -C "$t" rev-parse --short HEAD)"
  rm -rf "$t/.git"
  mkdir -p "$(dirname "$katalog")"
  mv "$t" "$katalog"
  if [ -f "$katalog/README.md" ]; then
    NAZWA_R="$PROJEKT" OPIS_R="$opis" awk '
      NR == 1 && $0 == "# NAZWA" { print "# " ENVIRON["NAZWA_R"]; next }
      $0 == "OPIS" { print ENVIRON["OPIS_R"]; next }
      { print }' "$katalog/README.md" >"$katalog/README.md.n" && mv "$katalog/README.md.n" "$katalog/README.md"
  fi
  git -C "$katalog" init -q -b main
  git -C "$katalog" remote add origin "https://github.com/$slug.git"
  git -C "$katalog" add -A
  git -C "$katalog" commit -q -m "Projekt $PROJEKT z $SH_TEMPLATE@$sha" || die "$E_WYKONANIE" "pierwszy commit nieudany"
}

komenda_main() {
  local nazwa="" tryb_arg="" prywatny=0 opis="" zlecenie="" slug stan katalog tryb_proj poprz e s origin
  local widocznosc=--public porty baza pliki rzeczy zrodlo tresc obs='null' zal=0 skr=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --tryb) tryb_arg="$(wartosc "$@")"; shift 2 ;;
      --prywatny) prywatny=1; shift ;;
      --public) uwaga "--public jest domyślne (SH-lite F5); flaga zostanie usunięta"; shift ;;
      --opis) opis="$(wartosc "$@")"; shift 2 ;;
      --zlecenie) zlecenie="$(wartosc "$@")"; shift 2 ;;
      --projekt | --projekt=*) die "$E_UZYCIE" "new-project przyjmuje nazwę jako argument" ;;
      -*) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
      *)
        [ -z "$nazwa" ] || die "$E_UZYCIE" "nadmiarowy argument: $1"
        nazwa="$1"
        shift
        ;;
    esac
  done
  [ -n "$nazwa" ] || die "$E_UZYCIE" "użycie: shctl new-project NAZWA --opis \"krótki opis repo\" [--zlecenie \"...\"] [--tryb S|M] [--prywatny]"
  sprawdz_nazwe "$nazwa"
  [ -n "$opis" ] || die "$E_UZYCIE" "--opis wymagany: krótki opis repo na GitHubie (do 350 znaków); treść zlecenia daj w --zlecenie"
  opis="$(komorka "$opis")"
  [ "${#opis}" -le 350 ] || die "$E_UZYCIE" "--opis ma ${#opis} znaków, GitHub przyjmuje do 350; treść zlecenia daj w --zlecenie"
  case "${tryb_arg:-M}" in
    M) ;;
    S) uwaga "proces.md: nowy projekt zaczyna od M lub L; S oznacza brak etapów DoD" ;;
    L) die "$E_UZYCIE" "tryb L jest dostępny dopiero w etapie wdrożenia B" ;;
    *) die "$E_UZYCIE" "--tryb: dozwolone S albo M" ;;
  esac
  [ "$prywatny" -eq 0 ] || widocznosc=--private
  wymagaj gh git jq yq gitleaks
  [ -f "$PORTY" ] || die "$E_BRAK" "brak $PORTY"

  PROJEKT="$nazwa"
  slug="$SH_GH_OWNER/$nazwa"
  katalog="$PROJEKTY/$nazwa"
  ROOT="$katalog"
  KONFIG="$ROOT/docs/konfiguracja.md"
  ST="$ROOT/docs/Projekt.md"
  SLUG="$slug"
  stan="$(repo_stan "$slug")"
  case "$stan" in
    brak)
      krok "utwórz repo $slug (${widocznosc#--}, bez szablonu GitHuba)"
      if [ "$DRY" -eq 0 ]; then
        gh repo create "$slug" "$widocznosc" --description "$opis" >/dev/null ||
          die "$E_WYKONANIE" "nie można utworzyć $slug"
      fi
      ;;
    nasz) krok "repo $slug już istnieje" ;;
    *) die "$E_ODMOWA" "repo $slug istnieje i nie jest projektem SH (brak tematu sh-projekt); nie ruszam go" ;;
  esac

  if [ -d "$katalog" ]; then
    origin="$(git -C "$katalog" config --get remote.origin.url || true)"
    case "$origin" in
      *"$slug" | *"$slug.git") krok "klon $katalog już istnieje" ;;
      *) die "$E_ODMOWA" "$katalog istnieje i nie jest klonem $slug" ;;
    esac
  else
    if [ "$DRY" -eq 0 ] && [ "$stan" = nasz ] && [ "$(gh repo view "$slug" --json isEmpty --jq .isEmpty 2>/dev/null)" != true ]; then
      krok "sklonuj do $katalog"
      mkdir -p "$PROJEKTY"
      gh repo clone "$slug" "$katalog" -- --quiet >/dev/null 2>&1 || die "$E_WYKONANIE" "nie można sklonować $slug"
    else
      krok "pliki szablonu $SH_TEMPLATE do $katalog (pierwszy commit, bez historii szablonu)"
      [ "$DRY" -eq 1 ] || zaloz_z_szablonu "$katalog" "$slug" "$opis"
    fi
  fi

  krok "opis repo, temat sh-projekt, usuwanie gałęzi po merge'u"
  [ "$prywatny" -eq 0 ] || krok "repo prywatne: CI na runnerze serwera (zmienna SH_RUNS_ON)"
  krok "załóż etykiety (setup-labels.sh)"
  krok "ustaw konfigurację: tryb ${tryb_arg:-M}, etap_wdrozenia A, data"
  krok "zarezerwuj blok portów"
  krok "oznacz etapy spoza trybu jako pominiety, widok docs/Projekt.md"
  [ -z "$zlecenie" ] || krok "zapisz zlecenie w docs/00-intake/zrodlo.md"
  krok "gitleaks, commit i push na main"
  krok "ruleset sh-ochrona-galezi: bez usuwania i force push na main i production"
  if [ -n "${SH_OBSIDIAN_DIR:-}" ]; then
    krok "lekki klon docs/ w $(obsidian_kat "$nazwa")"
    krok "skrzynka na materiały $(skrzynka_kat "$nazwa")"
  else
    uwaga "brak SH_OBSIDIAN_DIR w $SH_CONFIG, pomijam klon w Obsidianie"
  fi

  if [ "$DRY" -eq 1 ]; then
    baza="$(porty_rezerwuj "$nazwa" 55 | jq -r .zakres)"
    info "blok portów: $baza"
    if [ -n "${SH_OBSIDIAN_DIR:-}" ]; then
      obs="$(jq -nc --arg k "$(obsidian_kat "$nazwa")" --arg s "$(skrzynka_kat "$nazwa")" \
        '{katalog:$k, utworzono:false, skrzynka:{katalog:$s, utworzono:false}}')"
    fi
    wynik_json "$(jq -nc --arg r "$slug" --arg k "$katalog" --argjson s "$KROKI" --arg b "$baza" --argjson o "$obs" \
      '{repo:$r, katalog:$k, kroki:$s, porty:$b, obsidian:$o}')"
    return 0
  fi

  [ -f "$KONFIG" ] || die "$E_BRAK" "$katalog nie ma docs/konfiguracja.md"
  ustal_etapy
  repo_tozsamosc "$slug" "$opis" "sh-projekt" "" || die "$E_WYKONANIE" "gh repo edit $slug nieudane"
  if [ "$prywatny" -eq 1 ]; then
    gh variable set SH_RUNS_ON --repo "$slug" --body "$SH_RUNNER_PRYWATNY" >/dev/null ||
      die "$E_WYKONANIE" "nie można ustawić zmiennej SH_RUNS_ON w $slug"
    uwaga "repo prywatne: CI czeka na runner serwera z etykietami $SH_RUNNER_PRYWATNY (docs/serwer.md, „Repo prywatne”)"
  fi
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
  odswiez_projekt || true

  if [ -n "$zlecenie" ]; then
    zrodlo="$ROOT/docs/00-intake/zrodlo.md"
    tresc="$(cat "$zrodlo")"
    case "$tresc" in
      *"$zlecenie"*) ;;
      *) printf '\n%s\n' "$zlecenie" >>"$zrodlo" ;;
    esac
  fi

  rzeczy="$(bash "$ROOT/scripts/check-dod.sh" "$ROOT" 2>&1)" || die "$E_ODMOWA" "check-dod: $rzeczy"

  # Jawna lista: powtórka na żywym projekcie nie zabiera cudzych zmian.
  pliki="docs/konfiguracja.md docs/00-intake/zrodlo.md"
  for e in docs/Projekt.md docs/status.md docs/06-zadania/index.md; do
    [ ! -e "$ROOT/$e" ] && ! git -C "$ROOT" ls-files --error-unmatch -- "$e" >/dev/null 2>&1 || pliki="$pliki $e"
  done
  for e in $ETAPY; do pliki="$pliki docs/$e/DoD.md"; done
  [ ! -f "$ROOT/supabase/config.toml" ] || pliki="$pliki supabase/config.toml"
  # shellcheck disable=SC2086
  if [ -n "$(git -C "$ROOT" status --porcelain -- $pliki)" ]; then
    s="$(git -C "$ROOT" symbolic-ref --short -q HEAD || true)"
    [ "$s" = main ] || die "$E_ODMOWA" "commit konfiguracji wymaga gałęzi main, a jest '$s'"
    git -C "$ROOT" add -A -- $pliki
    git -C "$ROOT" commit -q -m "shctl: konfiguracja projektu $nazwa (tryb $tryb_proj)" -- $pliki ||
      die "$E_WYKONANIE" "commit nieudany"
  fi
  if ! git -C "$ROOT" rev-parse -q --verify origin/main >/dev/null || [ "$(git -C "$ROOT" rev-list --count origin/main..HEAD)" -gt 0 ]; then
    # Przed każdym pushem nowego projektu: sekret w plikach szablonu albo konfiguracji zatrzymuje push.
    rzeczy="$(gitleaks git --redact --no-banner "$ROOT" 2>&1)" ||
      die "$E_ODMOWA" "gitleaks znalazł sekret w $ROOT, push wstrzymany: $(printf '%s' "$rzeczy" | tail -3)"
    git_gh -t 120 -C "$ROOT" push -q -u origin HEAD:main || die "$E_WYKONANIE" "push nieudany"
  fi
  repo_ruleset "$slug" || uwaga "ruleset sh-ochrona-galezi nieustawiony w $slug (repo prywatne bez GitHub Pro?); ochronę gałęzi ustaw ręcznie"

  info "Gotowe: https://github.com/$slug"
  # Po pushu: klon ma dostać gotową konfigurację.
  if [ -n "${SH_OBSIDIAN_DIR:-}" ]; then
    zal="$(obsidian_polacz "$nazwa")"
    skr="$(skrzynka_utworz "$nazwa")"
    obs="$(jq -nc --arg k "$(obsidian_kat "$nazwa")" --argjson z "$zal" --arg s "$(skrzynka_kat "$nazwa")" \
      --argjson sz "$skr" '{katalog:$k, utworzono:($z == 1), skrzynka:{katalog:$s, utworzono:($sz == 1)}}')"
    info "Klon docs/: $(obsidian_kat "$nazwa")"
    info "Skrzynka na materiały: $(skrzynka_kat "$nazwa")"
    info "Synchronizację robi serwer co 5 minut (obsidian-sync.sh); w Obsidianie nic nie włączasz."
  fi
  wynik_json "$(jq -nc --arg r "$slug" --arg k "$katalog" --argjson s "$KROKI" --argjson p "$porty" --argjson o "$obs" \
    --arg t "$tryb_proj" '{repo:$r, katalog:$k, tryb:$t, kroki:$s, porty:$p, obsidian:$o}')"
}
