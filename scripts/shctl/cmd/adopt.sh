# shctl adopt: przejęcie istniejącego projektu (docs/proces.md, „Projekty przejęte”).
#   shctl adopt OWNER/REPO --nazwa NAZWA [--tryb M|S] [--limit-analizy MIN]
#   shctl adopt adaptacja --projekt NAZWA
#   shctl adopt bramka --projekt NAZWA
#   shctl adopt upublicznij --projekt NAZWA
# Start: pełny klon w /Users/Shared/sh/projekty/NAZWA (bez plików env i bez dostępu do produkcji),
# worktree /Users/Shared/sh/wt/NAZWA/stage-00-analiza na gałęzi stage/00-analiza z commitem szkieletu
# etapu (docs/konfiguracja.md z pochodzenie: adopt, docs/decyzje.md, docs/00-analiza/), blok portów,
# klon docs/ w Obsidianie i skrzynka. Kodu aplikacji, ustawień repo ani widoczności nie zmienia; PR
# raportu otwiera sh-intake. Adaptacja dopiero po checkpoincie „akceptuję analizę i kierunek”: osobny
# PR z plikami procesu (bez kodu aplikacji), etykiety. Bramka przed upublicznieniem: gitleaks na
# całej historii, RLS, dane osobowe w seedach. Upublicznienie: tylko z decyzją właściciela i po bramce.
# shellcheck shell=bash

# shellcheck source=../lib/porty.sh
. "$SHCTL_DIR/lib/porty.sh"
# shellcheck source=../lib/obsidian.sh
. "$SHCTL_DIR/lib/obsidian.sh"
# shellcheck source=../lib/repo.sh
. "$SHCTL_DIR/lib/repo.sh"

ADOPT_SZABLONY="$SHCTL_DIR/../../templates/adopt"
WYKRYJ="$SHCTL_DIR/../adopt/wykryj.sh"
ADOPT_LIMIT_DOMYSLNY=120

KROKI='[]'
krok() {
  KROKI="$(jq -c --arg k "$1" '. + [$k]' <<<"$KROKI")"
  info "- $1"
}

# Limit czasu analizy: --limit-analizy, potem adopt.limit_analizy_min z /Users/Shared/sh/konfiguracja.md.
limit_analizy() {
  local l=""
  [ ! -f "$KONFIG_SH" ] || l="$(yq --front-matter=extract '.adopt.limit_analizy_min // ""' "$KONFIG_SH" 2>/dev/null || true)"
  printf '%s' "${l:-$ADOPT_LIMIT_DOMYSLNY}"
}

# Data UTC za N minut (BSD date na macOS, GNU w CI).
utc_za() {
  date -u -v+"$1"M +%Y-%m-%dT%H:%MZ 2>/dev/null || date -u -d "+$1 minutes" +%Y-%m-%dT%H:%MZ
}

adopt_start() {
  local slug="" nazwa="" tryb=M limit="" info_repo widocznosc galaz katalog origin wt rem fakty
  local lovable supabase porty="" baza zakres teraz obs='null' zal=0 skr=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --nazwa) nazwa="$(wartosc "$@")"; shift 2 ;;
      --tryb) tryb="$(wartosc "$@")"; shift 2 ;;
      --limit-analizy) limit="$(wartosc "$@")"; shift 2 ;;
      --projekt | --projekt=*) die "$E_UZYCIE" "adopt przyjmuje nazwę przez --nazwa" ;;
      -*) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
      *)
        [ -z "$slug" ] || die "$E_UZYCIE" "nadmiarowy argument: $1"
        slug="$1"
        shift
        ;;
    esac
  done
  printf '%s' "$slug" | grep -qE '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' ||
    die "$E_UZYCIE" "użycie: shctl adopt OWNER/REPO --nazwa NAZWA [--tryb M|S] [--limit-analizy MIN]"
  [ -n "$nazwa" ] || die "$E_UZYCIE" "--nazwa wymagana: nazwa projektu w /Users/Shared/sh/projekty"
  sprawdz_nazwe "$nazwa"
  case "$tryb" in M | S) ;; *) die "$E_UZYCIE" "--tryb: dozwolone M albo S" ;; esac
  [ -n "$limit" ] || limit="$(limit_analizy)"
  case "$limit" in "" | *[!0-9]* | 0) die "$E_UZYCIE" "--limit-analizy: liczba minut większa od 0" ;; esac
  wymagaj gh git jq yq
  [ -f "$PORTY" ] || die "$E_BRAK" "brak $PORTY"

  PROJEKT="$nazwa"
  katalog="$PROJEKTY/$nazwa"
  wt="$SH_DIR/wt/$nazwa/stage-00-analiza"

  info_repo="$(gh repo view "$slug" --json nameWithOwner,visibility,isArchived,isEmpty,defaultBranchRef 2>&1)" || {
    printf '%s' "$info_repo" | grep -q 'Could not resolve' && die "$E_BRAK" "brak repo $slug albo brak dostępu"
    die "$E_WYKONANIE" "gh repo view $slug: $info_repo"
  }
  [ "$(jq -r '.isArchived // false' <<<"$info_repo")" != true ] || die "$E_ODMOWA" "repo $slug jest zarchiwizowane"
  [ "$(jq -r '.isEmpty // false' <<<"$info_repo")" != true ] || die "$E_ODMOWA" "repo $slug jest puste: to nowy projekt (shctl new-project)"
  widocznosc="$(jq -r '.visibility // "" | ascii_downcase' <<<"$info_repo")"
  galaz="$(jq -r '.defaultBranchRef.name // ""' <<<"$info_repo")"
  [ "$galaz" = main ] || die "$E_ODMOWA" "domyślna gałąź $slug to '$galaz', proces wymaga main; zmiana gałęzi to decyzja właściciela"

  # Klon: pełna historia (bramka skanuje ją gitleaksem). Bez kopiowania .env i bez kluczy produkcji.
  if [ -d "$katalog" ]; then
    origin="$(git -C "$katalog" config --get remote.origin.url || true)"
    case "$origin" in
      *"/$slug" | *"/$slug.git") krok "klon $katalog już istnieje" ;;
      *) die "$E_ODMOWA" "$katalog istnieje i nie jest klonem $slug" ;;
    esac
  else
    krok "sklonuj $slug do $katalog (pełna historia, bez plików env)"
    if [ "$DRY" -eq 0 ]; then
      mkdir -p "$PROJEKTY"
      git_gh -t 900 clone -q "https://github.com/$slug.git" "$katalog" || die "$E_WYKONANIE" "nie można sklonować $slug"
    fi
  fi
  if [ "$DRY" -eq 0 ] && git -C "$katalog" cat-file -e origin/main:docs/konfiguracja.md 2>/dev/null; then
    [ "$(git -C "$katalog" show origin/main:docs/konfiguracja.md | yq --front-matter=extract '.pochodzenie // ""')" = adopt ] ||
      die "$E_ODMOWA" "$slug ma już docs/konfiguracja.md: to projekt SH, nie przejęcie"
    krok "analiza jest już na main; dalej: shctl adopt adaptacja --projekt $nazwa"
    wynik_json "$(jq -nc --arg r "$slug" --arg k "$katalog" --argjson s "$KROKI" '{repo:$r, katalog:$k, kroki:$s, etap:"po-analizie"}')"
    return 0
  fi

  # Worktree etapu: lokalna gałąź, potem zdalna (wznowienie), potem nowa z origin/main.
  if [ -d "$wt" ]; then
    krok "worktree $wt już istnieje"
  else
    krok "worktree $wt na gałęzi stage/00-analiza"
    if [ "$DRY" -eq 0 ]; then
      mkdir -p "$(dirname "$wt")"
      git_gh -t 120 -C "$katalog" fetch -q origin || die "$E_WYKONANIE" "git fetch origin nieudany"
      if git -C "$katalog" rev-parse -q --verify refs/heads/stage/00-analiza >/dev/null; then
        git -C "$katalog" worktree add -q "$wt" stage/00-analiza
      elif git -C "$katalog" rev-parse -q --verify refs/remotes/origin/stage/00-analiza >/dev/null; then
        git -C "$katalog" worktree add -q --no-track -b stage/00-analiza "$wt" origin/stage/00-analiza
      else
        git -C "$katalog" worktree add -q --no-track -b stage/00-analiza "$wt" origin/main
      fi || die "$E_WYKONANIE" "nie można założyć worktree $wt"
    fi
  fi

  krok "zarezerwuj blok portów (bez zmian w supabase/config.toml do adaptacji)"
  krok "szkielet etapu w worktree: docs/konfiguracja.md (pochodzenie: adopt), docs/decyzje.md, docs/00-analiza/"
  if [ -n "${SH_OBSIDIAN_DIR:-}" ]; then
    krok "lekki klon docs/ w $(obsidian_kat "$nazwa") i skrzynka $(skrzynka_kat "$nazwa")"
  fi
  if [ "$DRY" -eq 1 ]; then
    wynik_json "$(jq -nc --arg r "$slug" --arg k "$katalog" --arg w "$wt" --argjson s "$KROKI" --arg v "$widocznosc" \
      --argjson l "$limit" '{repo:$r, katalog:$k, worktree:$w, widocznosc:$v, limit_analizy_min:$l, kroki:$s}')"
    return 0
  fi

  porty="$(porty_rezerwuj "$nazwa" 55)"
  zakres="$(jq -r .zakres <<<"$porty")"
  baza="$(jq -r .baza <<<"$porty")"
  fakty="$(bash "$WYKRYJ" "$wt")" || die "$E_WYKONANIE" "wykryj.sh nie powiódł się"
  lovable="$(jq -r .lovable.wykryto <<<"$fakty")"
  supabase="$(jq -r .supabase.wykryto <<<"$fakty")"

  if [ ! -f "$wt/docs/00-analiza/DoD.md" ]; then
    [ ! -e "$wt/docs/konfiguracja.md" ] || die "$E_ODMOWA" "$wt/docs/konfiguracja.md istnieje; nie nadpisuję"
    mkdir -p "$wt/docs/00-analiza/funkcje"
    teraz="$(date -u +%Y-%m-%dT%H:%MZ)"
    cat >"$wt/docs/konfiguracja.md" <<EOF
---
wersja_procesu: 2
etap_wdrozenia: A
tryb_procesu: $tryb
odbior_S: reczny
pochodzenie: adopt
blok_portow: "$zakres"
adopt:
  repo: $slug
  widocznosc: $widocznosc
  data: $(dzis)
  analiza_od: "$teraz"
  analiza_do: "$(utc_za "$limit")"
  limit_analizy_min: $limit
  lovable: $lovable
  supabase: $supabase
  produkcja: brak dostępu agentów
---

# Konfiguracja projektu

Projekt przejęty przez \`shctl adopt\` (\`sh-system/docs/proces.md\`, „Projekty przejęte”). Pełną
konfigurację z szablonu dostaje adaptacja po akceptacji analizy (\`shctl adopt adaptacja\`).

| Pole | Znaczenie |
|---|---|
| \`pochodzenie\` | \`adopt\`: projekt przejęty, etapy zaczynają się od \`00-analiza\` |
| \`adopt.repo\` | Repo przejęte; widoczność zmienia tylko \`shctl adopt upublicznij\` po decyzji właściciela |
| \`adopt.analiza_od\`, \`adopt.analiza_do\` | Okno analizy (UTC); \`limit_analizy_min\` z \`/Users/Shared/sh/konfiguracja.md\` albo \`--limit-analizy\` |
| \`adopt.lovable\`, \`adopt.supabase\` | Wynik \`scripts/adopt/wykryj.sh\` przy przejęciu |
| \`adopt.produkcja\` | Agenci nie mają dostępu do produkcji ani chmury Supabase |
EOF
    printf '# Decyzje projektu\n\nPlik wspólny, aktualizuje orkiestrator. Decyzje workerów przenosi z raportów `T-NR.md`.\n\n| Data | Źródło | Pytanie | Decyzja |\n|---|---|---|---|\n' \
      >"$wt/docs/decyzje.md"
    cp "$ADOPT_SZABLONY/DoD-00-analiza.md" "$wt/docs/00-analiza/DoD.md"
    NAZWA_R="$nazwa" REPO_R="$slug" awk '
      NR == 1 { sub(/NAZWA/, ENVIRON["NAZWA_R"]) }
      NR == 3 { sub(/OWNER\/REPO/, ENVIRON["REPO_R"]) }
      { print }' "$ADOPT_SZABLONY/raport.md" >"$wt/docs/00-analiza/raport.md"
    cp "$ADOPT_SZABLONY/karta-obecna.md" "$wt/docs/00-analiza/funkcje/_szablon-karty.md"
    printf '%s\n' "$fakty" | jq . >"$wt/docs/00-analiza/wykryj.json"
    git -C "$wt" add -- docs/konfiguracja.md docs/decyzje.md docs/00-analiza
    git -C "$wt" commit -q -m "shctl: adopt $nazwa, etap 00-analiza" -- docs/konfiguracja.md docs/decyzje.md docs/00-analiza ||
      die "$E_WYKONANIE" "commit szkieletu nieudany"
  else
    krok "szkielet etapu już jest w worktree"
  fi

  if [ -n "${SH_OBSIDIAN_DIR:-}" ]; then
    zal="$(obsidian_polacz "$nazwa" "$slug")"
    skr="$(skrzynka_utworz "$nazwa")"
    obs="$(jq -nc --arg k "$(obsidian_kat "$nazwa")" --argjson z "$zal" --arg s "$(skrzynka_kat "$nazwa")" \
      --argjson sz "$skr" '{katalog:$k, utworzono:($z == 1), skrzynka:{katalog:$s, utworzono:($sz == 1)}}')"
  else
    uwaga "brak SH_OBSIDIAN_DIR w $SH_CONFIG, pomijam klon w Obsidianie"
  fi

  [ "$(jq '.alarmy | length' <<<"$fakty")" -eq 0 ] || uwaga "alarmy do raportu: $(jq -r '.alarmy | join("; ")' <<<"$fakty")"
  info "Gotowe: analiza w $wt (sh-intake w trybie adopt, raport docs/00-analiza/raport.md)"
  info "Repo zostaje $widocznosc; widoczność zmienia tylko shctl adopt upublicznij po Twojej zgodzie."
  wynik_json "$(jq -nc --arg r "$slug" --arg k "$katalog" --arg w "$wt" --argjson s "$KROKI" --arg v "$widocznosc" \
    --argjson l "$limit" --argjson p "$porty" --argjson o "$obs" --argjson f "$fakty" --arg t "$tryb" '
    {repo:$r, katalog:$k, worktree:$w, galaz:"stage/00-analiza", tryb:$t, widocznosc:$v, limit_analizy_min:$l,
     porty:$p, obsidian:$o, lovable:$f.lovable.wykryto, supabase:$f.supabase.wykryto, alarmy:$f.alarmy, kroki:$s}')"
}

# Projekt przejęty na main głównego klonu (po merge'u PR analizy).
adopt_projekt() {
  znajdz_projekt
  [ "$(fm_get "$KONFIG" pochodzenie)" = adopt ] || die "$E_ODMOWA" "$PROJEKT nie jest projektem przejętym (pochodzenie: adopt)"
  SLUG="$(slug_repo)"
  [ -n "$SLUG" ] || die "$E_BRAK" "origin $ROOT nie wskazuje GitHuba"
}

# Bramka przed upublicznieniem. Wypisuje JSON wyniku; zwraca 1, gdy coś blokuje.
bramka_json() {
  local raport fakty wyj gl=0 lista='[]'
  raport="$(tmp_plik)"
  if wyj="$(gitleaks git --redact --no-banner --report-format json --report-path "$raport" "$ROOT" 2>&1)"; then
    gl=0
  else
    [ -s "$raport" ] || die "$E_WYKONANIE" "gitleaks nie zadziałał: $(printf '%s' "$wyj" | tail -3)"
    gl=1
  fi
  [ ! -s "$raport" ] || lista="$(jq -c '[.[]? | {regula:.RuleID, plik:.File, linia:.StartLine, commit:(.Commit[0:7]), data:.Date}]' "$raport" 2>/dev/null || echo '[]')"
  [ "$gl" -eq 0 ] || [ "$(jq length <<<"$lista")" -gt 0 ] || lista='[{"regula":"nieznana","plik":"zob. gitleaks"}]'
  fakty="$(bash "$WYKRYJ" "$ROOT")" || die "$E_WYKONANIE" "wykryj.sh nie powiódł się"
  jq -nc --argjson g "$lista" --argjson f "$fakty" --arg raport "$([ -f "$ROOT/docs/00-analiza/raport.md" ] && grep -qi 'RLS' "$ROOT/docs/00-analiza/raport.md" && echo tak || echo nie)" '
    # Klucz anon Supabase (np. client.ts z Lovable) jest publiczny z założenia: gitleaks go zgłasza
    # (reguła jwt), ale w miejscu klucza o roli anon według wykryj.sh znalezisko nie blokuje.
    [$f.klucze[] | select(.rola == "anon") | "\(.plik):\(.linia)"] as $anon
    | ($g | map(. + {klucz_anon: (("\(.plik):\(.linia)") as $k | $anon | index($k) != null)})) as $g
    | ([$g[] | select(.klucz_anon | not)]) as $s
    | {gitleaks: {znaleziska: ($s | length), klucze_anon: ([$g[] | select(.klucz_anon)] | length), lista: $g,
       zalecenie: (if ($s | length) > 0 then "unieważnij każdy znaleziony sekret u dostawcy i wydaj nowy; historii nie przepisujemy" else null end)},
     rls: {bez_rls: $f.rls.bez_rls, przeglad_w_raporcie: ($raport == "tak")},
     dane_osobowe: $f.dane_osobowe, env_w_repo: $f.env_w_repo,
     service_role: [$f.klucze[] | select(.rola == "service_role")]}
    | .blokady = ([
        (if .gitleaks.znaleziska > 0 then "gitleaks: \(.gitleaks.znaleziska) znalezisk w historii" else empty end),
        (if (.rls.bez_rls | length) > 0 then "tabele bez RLS: \(.rls.bez_rls | join(", "))" else empty end),
        (if .rls.przeglad_w_raporcie | not then "brak przeglądu RLS w docs/00-analiza/raport.md" else empty end),
        (if (.dane_osobowe | length) > 0 then "możliwe dane osobowe w seedach i fixture’ach: \(.dane_osobowe | length)" else empty end),
        (if (.env_w_repo | length) > 0 then "pliki env w repo: \(.env_w_repo | join(", "))" else empty end),
        (if (.service_role | length) > 0 then "klucz service_role w repo" else empty end)])
    | .wynik = (if (.blokady | length) == 0 then "ok" else "blokada" end)'
}

adopt_bramka() {
  local w
  while [ $# -gt 0 ]; do opcja_wspolna "$@"; shift "$ZJEDZONE"; done
  adopt_projekt
  wymagaj gitleaks
  w="$(bramka_json)"
  info "Bramka przed upublicznieniem $SLUG: $(jq -r .wynik <<<"$w")"
  jq -r '.blokady[] | "- " + .' <<<"$w" | while IFS= read -r l; do info "$l"; done
  [ "$(jq -r '.gitleaks.zalecenie // ""' <<<"$w")" = "" ] || info "Zalecenie: $(jq -r .gitleaks.zalecenie <<<"$w")"
  if [ "$(jq -r .wynik <<<"$w")" != ok ]; then
    printf '%s' "bramka: $(jq -r '.blokady | join("; ")' <<<"$w")" >"$SHCTL_TMP/blad"
    WYNIK_WYSLANY=1
    [ "$JSON" -eq 0 ] || jq -nc --argjson w "$w" '{ok:false, komenda:"adopt", kod:4, blad:"bramka: blokady", wynik:$w}'
    exit "$E_ODMOWA"
  fi
  wynik_json "$w"
}

adopt_upublicznij() {
  local w wid
  while [ $# -gt 0 ]; do opcja_wspolna "$@"; shift "$ZJEDZONE"; done
  adopt_projekt
  wymagaj gitleaks
  wid="$(gh repo view "$SLUG" --json visibility --jq '.visibility | ascii_downcase' 2>/dev/null || true)"
  if [ "$wid" = public ]; then
    info "repo $SLUG jest już publiczne"
    wynik_json "$(jq -nc --arg r "$SLUG" '{repo:$r, widocznosc:"public", zmiana:false}')"
    return 0
  fi
  # Zgoda właściciela: wiersz wlasciciel w decyzje.md z „upublicz” (shctl decision add --rola wlasciciel).
  grep -iE '^\|[^|]*\| *wlasciciel *\|.*upublicz' "$ROOT/docs/decyzje.md" >/dev/null 2>&1 ||
    die "$E_ODMOWA" "brak zgody właściciela: najpierw shctl decision add --rola wlasciciel --co \"Upublicznienie repo $SLUG\" ..."
  w="$(bramka_json)"
  [ "$(jq -r .wynik <<<"$w")" = ok ] || die "$E_ODMOWA" "bramka: $(jq -r '.blokady | join("; ")' <<<"$w")"
  if [ "$DRY" -eq 0 ]; then
    gh repo edit "$SLUG" --visibility public --accept-visibility-change-consequences >/dev/null ||
      die "$E_WYKONANIE" "gh repo edit --visibility public nieudane"
    fm_set "$KONFIG" adopt.widocznosc public
  fi
  info "repo $SLUG publiczne; docs/konfiguracja.md (adopt.widocznosc) commituje orkiestrator na main"
  wynik_json "$(jq -nc --arg r "$SLUG" --argjson w "$w" '{repo:$r, widocznosc:"public", zmiana:true, bramka:$w}')"
}

# Pliki procesu, które adaptacja bierze z szablonu (biała lista: nic z kodu aplikacji). CI szablonu,
# .gitignore, README, .env.example i konfiguracja pnpm zostają po stronie projektu; istniejące CI
# działa dalej, a obok dochodzi .github/workflows/sh.yml.
plik_procesu() {
  case "$1" in
    scripts/tests/*) return 1 ;;
    AGENTS.md | CLAUDE.md | CHANGELOG.md | docs/* | scripts/* | .claude/roles/* | \
      .github/PULL_REQUEST_TEMPLATE.md | .github/ISSUE_TEMPLATE/*) return 0 ;;
  esac
  return 1
}

adopt_adaptacja() {
  local wt galaz=adopt/adaptacja szablon p dodane="" pominiete="" pr cialo old wyj tytul="adopt: adaptacja do procesu SH"
  while [ $# -gt 0 ]; do opcja_wspolna "$@"; shift "$ZJEDZONE"; done
  adopt_projekt
  wymagaj gitleaks
  wt="$SH_DIR/wt/$PROJEKT/adaptacja"

  pr="$(gh pr list --repo "$SLUG" --head "$galaz" --state open --json number,url --jq '.[0].url // ""' 2>/dev/null || true)"
  if [ -n "$pr" ]; then
    info "PR adaptacji już otwarty: $pr"
    wynik_json "$(jq -nc --arg p "$pr" --arg w "$wt" '{pr:$p, worktree:$w, nowy:false}')"
    return 0
  fi
  # Checkpoint: wszystkie pola DoD analizy (z akceptacją) i wiersz właściciela w decyzje.md.
  grep -q '^- \[ \]' "$ROOT/docs/00-analiza/DoD.md" &&
    die "$E_ODMOWA" "docs/00-analiza/DoD.md ma niezaznaczone pola: adaptacja dopiero po review PASS i „akceptuję analizę i kierunek”"
  grep -iE '^\|[^|]*\| *wlasciciel *\|.*analiz' "$ROOT/docs/decyzje.md" >/dev/null ||
    die "$E_ODMOWA" "brak akceptacji analizy w decyzje.md (shctl decision add --rola wlasciciel --co \"Akceptacja analizy i kierunku\" ...)"

  krok "worktree $wt na gałęzi $galaz z origin/main"
  krok "pliki szablonu $SH_TEMPLATE bez kodu aplikacji: AGENTS.md, CLAUDE.md, docs/ v2, scripts/, .claude/roles/, .github/workflows/sh.yml"
  [ "$(fm_get "$KONFIG" adopt.lovable)" != true ] || krok "AGENTS.md: zasady Lovable (bez publikacji bez decyzji właściciela)"
  krok "etykiety (setup-labels.sh), gitleaks commitu adaptacji, check-dod, push i PR"
  if [ "$DRY" -eq 1 ]; then
    wynik_json "$(jq -nc --arg w "$wt" --argjson s "$KROKI" '{worktree:$w, kroki:$s}')"
    return 0
  fi

  git_gh -t 120 -C "$ROOT" fetch -q origin || die "$E_WYKONANIE" "git fetch origin nieudany"
  if [ ! -d "$wt" ]; then
    mkdir -p "$(dirname "$wt")"
    if git -C "$ROOT" rev-parse -q --verify "refs/heads/$galaz" >/dev/null; then
      git -C "$ROOT" worktree add -q "$wt" "$galaz"
    else
      git -C "$ROOT" worktree add -q --no-track -b "$galaz" "$wt" origin/main
    fi || die "$E_WYKONANIE" "nie można założyć worktree $wt"
  fi

  szablon="$SHCTL_TMP/szablon"
  git_gh -t 120 clone -q --depth 1 "https://github.com/$SH_GH_OWNER/$SH_TEMPLATE.git" "$szablon" ||
    die "$E_WYKONANIE" "nie można pobrać szablonu $SH_GH_OWNER/$SH_TEMPLATE"
  git -C "$szablon" ls-files >"$SHCTL_TMP/pliki-szablonu"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    plik_procesu "$p" || continue
    case "$p" in
      docs/konfiguracja.md | docs/decyzje.md) continue ;;
    esac
    if [ -e "$wt/$p" ]; then
      cmp -s "$szablon/$p" "$wt/$p" || pominiete="$pominiete$p"$'\n'
      continue
    fi
    mkdir -p "$(dirname "$wt/$p")"
    cp -p "$szablon/$p" "$wt/$p"
    dodane="$dodane$p"$'\n'
  done <"$SHCTL_TMP/pliki-szablonu"

  # Konfiguracja: pełna z szablonu, z polami przejęcia z analizy.
  old="$(tmp_plik)"
  yq --front-matter=extract '.' "$ROOT/docs/konfiguracja.md" >"$old"
  cp "$szablon/docs/konfiguracja.md" "$wt/docs/konfiguracja.md"
  STARA="$old" yq -i --front-matter=process '
    load(strenv(STARA)) as $s
    | .tryb_procesu = $s.tryb_procesu | .pochodzenie = "adopt" | .adopt = $s.adopt
    | .blok_portow = ($s.blok_portow // "")' "$wt/docs/konfiguracja.md"
  mkdir -p "$wt/.github/workflows"
  cp "$ADOPT_SZABLONY/sh-dod.yml" "$wt/.github/workflows/sh.yml"
  dodane="$dodane.github/workflows/sh.yml"$'\n'
  if [ "$(fm_get "$KONFIG" adopt.lovable)" = true ] && ! grep -qxF '## Lovable' "$wt/AGENTS.md"; then
    cat "$ADOPT_SZABLONY/AGENTS-lovable.md" >>"$wt/AGENTS.md"
  fi
  # Etap analizy kończy się w tym PR: checkpoint jest na main, a check-dod jest już w repo.
  fm_set "$wt/docs/00-analiza/DoD.md" status done

  wyj="$(bash "$wt/scripts/check-dod.sh" "$wt" 2>&1)" || die "$E_ODMOWA" "check-dod w adaptacji: $wyj"
  git -C "$wt" add -A
  if [ -n "$(git -C "$wt" status --porcelain)" ]; then
    git -C "$wt" commit -q -m "$tytul" || die "$E_WYKONANIE" "commit adaptacji nieudany"
  fi
  # Tylko nowe commity: sekret ze starej historii to sprawa bramki, nie blokada adaptacji.
  wyj="$(gitleaks git --redact --no-banner --log-opts="origin/main..HEAD" "$wt" 2>&1)" ||
    die "$E_ODMOWA" "gitleaks w commicie adaptacji: $(printf '%s' "$wyj" | tail -3)"

  wyj="$(bash "$wt/scripts/setup-labels.sh" --repo "$SLUG" 2>&1)" || die "$E_WYKONANIE" "setup-labels: $wyj"
  if [ "$(gh repo view "$SLUG" --json visibility --jq '.visibility | ascii_downcase' 2>/dev/null || true)" = private ]; then
    gh variable set SH_RUNS_ON --repo "$SLUG" --body "$SH_RUNNER_PRYWATNY" >/dev/null ||
      uwaga "nie ustawiono SH_RUNS_ON w $SLUG; workflow sh.yml pójdzie na runner GitHuba (minuty płatne)"
  fi
  git_gh -t 120 -C "$wt" push -q -u origin "HEAD:refs/heads/$galaz" || die "$E_WYKONANIE" "push $galaz nieudany"
  cialo="$(tmp_plik)"
  {
    printf 'Adaptacja projektu przejętego do procesu SH, po akceptacji analizy (docs/00-analiza/raport.md).\n'
    printf 'Bez zmian w kodzie aplikacji: tylko pliki procesu. Istniejące CI zostaje, obok dochodzi workflow `SH` (check-dod, gitleaks).\n\n'
    printf '## Dodane\n\n'
    printf '%s' "$dodane" | sed '/^$/d; s/^/- `/; s/$/`/'
    if [ -n "$pominiete" ]; then
      printf '\n## Pominięte (plik projektu różni się od szablonu, do ręcznego połączenia)\n\n'
      printf '%s' "$pominiete" | sed '/^$/d; s/^/- `/; s/$/`/'
    fi
    printf '\n## Zmienione\n\n- `docs/konfiguracja.md`: pełna konfiguracja szablonu z polami `pochodzenie` i `adopt`\n- `docs/00-analiza/DoD.md`: `status: done`\n'
    printf '\n🤖 shctl adopt adaptacja\n'
  } >"$cialo"
  pr="$(gh pr create --repo "$SLUG" --base main --head "$galaz" --title "$tytul" --body-file "$cialo" 2>&1)" ||
    die "$E_WYKONANIE" "gh pr create: $pr"
  info "PR adaptacji: $pr"
  [ -z "$pominiete" ] || uwaga "pliki pominięte (różne od szablonu): $(printf '%s' "$pominiete" | tr '\n' ' ')"
  wynik_json "$(jq -nc --arg p "$pr" --arg w "$wt" --arg d "$dodane" --arg o "$pominiete" '
    {pr:$p, worktree:$w, nowy:true, dodane:($d | split("\n") | map(select(length > 0))),
     pominiete:($o | split("\n") | map(select(length > 0)))}')"
}

komenda_main() {
  case "${1:-}" in
    adaptacja) shift; adopt_adaptacja "$@" ;;
    bramka) shift; adopt_bramka "$@" ;;
    upublicznij) shift; adopt_upublicznij "$@" ;;
    *) adopt_start "$@" ;;
  esac
}
