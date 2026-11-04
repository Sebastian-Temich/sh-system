# shctl skrzynka przyjmij NAZWA [--etap ETAP/KATALOG]
# Materiały właściciela ze skrzynki w vaulcie (SH/Skrzynka/NAZWA, zwykły folder) trafiają do repo:
#   1. pliki ze skrzynki (bez _przeniesione/, plików ukrytych i __MACOSX) są sprawdzane i kopiowane do
#      docs/ETAP/KATALOG (domyślnie docs/02-design/zrodla), commit na gałęzi stage/ETAP, PR do main;
#   2. kolejne wywołanie po merge'u tego PR przenosi przyjęte pliki w skrzynce do
#      _przeniesione/RRRRMMDD/; plik zmieniony po przyjęciu zostaje i wejdzie do następnego PR.
# Pliki są danymi nieufnymi: nic nie jest uruchamiane. Odrzucane (zostają w skrzynce): dowiązania,
# pakiety aplikacji, pliki wykonywalne (rozszerzenie albo nagłówek ELF, Mach-O, PE, #!), pliki powyżej
# 50 MB. ZIP jest rozpakowywany tylko po kontroli: ścieżki bez „..”, bezwzględnych i „\”, bez dowiązań,
# do 2000 plików i 500 MB; pliki wykonywalne z archiwum są pomijane. Inne archiwa trafiają do repo
# bez rozpakowania. Stan partii: /Users/Shared/sh/stan/skrzynka/NAZWA.json.
# shellcheck shell=bash

# shellcheck source=../lib/zadania.sh
. "$SHCTL_DIR/lib/zadania.sh"
# shellcheck source=../lib/obsidian.sh
. "$SHCTL_DIR/lib/obsidian.sh"

MAKS_PLIK_B=$((50 * 1024 * 1024))
MAKS_ZIP_B=$((500 * 1024 * 1024))
MAKS_ZIP_PLIKOW=2000
# Rozszerzenia plików i pakietów, które da się uruchomić albo zainstalować.
ZAKAZANE=" app command tool pkg mpkg dmg iso exe msi msix bat cmd com scr ps1 psm1 vbs vbe wsf sh bash zsh
  csh ksh fish py pyc pyw rb pl php jar class scpt scptd applescript workflow action dylib so bin run elf
  apk ipa deb rpm appimage xpi crx kext prefpane plugin bundle framework "

SKR=""
STG=""
CEL=""
ETAP1=""

rozszerzenie() {
  local n="$1"
  case "$n" in *.*) ;; *) return 0 ;; esac
  printf '%s' "${n##*.}" | LC_ALL=C tr 'A-Z' 'a-z'
}

zakazane() {
  local e
  e="$(rozszerzenie "$1")"
  [ -n "$e" ] || return 1
  printf '%s' "$ZAKAZANE" | tr -s ' \n' '\n\n' | grep -qxF "$e"
}

# Powód odrzucenia pliku albo pusto. Odczyt pierwszych bajtów, bez uruchamiania czegokolwiek.
powod_pliku() {
  local f="$1" nazwa="$2" m rozm
  if zakazane "$nazwa"; then
    printf 'plik wykonywalny (.%s)' "$(rozszerzenie "$nazwa")"
    return 0
  fi
  m="$(LC_ALL=C od -An -tx1 -N4 -- "$f" 2>/dev/null | tr -d ' \n')"
  case "$m" in
    7f454c46*) printf 'plik wykonywalny (nagłówek ELF)'; return 0 ;;
    cffaedfe* | cefaedfe* | feedface* | feedfacf* | cafebabe*) printf 'plik wykonywalny (nagłówek Mach-O)'; return 0 ;;
    4d5a*) printf 'plik wykonywalny (nagłówek PE)'; return 0 ;;
    2321*) printf 'skrypt (nagłówek #!)'; return 0 ;;
  esac
  rozm="$(wc -c <"$f" | tr -d ' ')"
  [ "$rozm" -le "$MAKS_PLIK_B" ] || printf 'za duży (%s MB, limit 50 MB)' "$((rozm / 1024 / 1024))"
}

ma_znaki_sterujace() { printf '%s' "$1" | LC_ALL=C grep -q '[[:cntrl:]]'; }

odrzuc() { printf '%s\t%s\n' "$1" "$2" >>"$SHCTL_TMP/odrzucone"; }

# Pierwszy katalog ścieżki będący pakietem aplikacji (np. X.app), albo pusto.
pakiet_w_sciezce() {
  local rel="$1" acc="" c rest
  rest="$(dirname "$rel")"
  [ "$rest" != . ] || return 0
  while [ -n "$rest" ]; do
    c="${rest%%/*}"
    acc="${acc:+$acc/}$c"
    if zakazane "$c"; then printf '%s' "$acc"; return 0; fi
    case "$rest" in */*) rest="${rest#*/}" ;; *) rest="" ;; esac
  done
}

odrzuc_pakiet() {
  local p="$1"
  grep -qxF "$p	pakiet aplikacji" "$SHCTL_TMP/odrzucone" 2>/dev/null || odrzuc "$p" "pakiet aplikacji"
}

# ZIP: kontrola listy przed rozpakowaniem, rozpakowanie do katalogu tymczasowego, kontrola wyniku.
przyjmij_zip() {
  local f="$1" rel="$2" nazwy e t n bajty tmpx g r p powod cel_kat baza zostalo=0
  wymagaj unzip zipinfo
  if [ "$(wc -c <"$f" | tr -d ' ')" -gt "$MAKS_ZIP_B" ]; then odrzuc "$rel" "archiwum ponad 500 MB"; return 0; fi
  nazwy="$(zipinfo -1 "$f" 2>/dev/null)" || { odrzuc "$rel" "uszkodzone albo puste archiwum ZIP"; return 0; }
  while IFS= read -r e; do
    [ -n "$e" ] || continue
    case "$e" in
      /* | *\\*) odrzuc "$rel" "niebezpieczna ścieżka w archiwum: $e"; return 0 ;;
    esac
    case "/$e/" in
      */../*) odrzuc "$rel" "niebezpieczna ścieżka w archiwum: $e"; return 0 ;;
    esac
    if ma_znaki_sterujace "$e"; then odrzuc "$rel" "znaki sterujące w nazwie w archiwum"; return 0; fi
  done <<<"$nazwy"
  if zipinfo "$f" 2>/dev/null | grep -q '^l'; then odrzuc "$rel" "dowiązanie symboliczne w archiwum"; return 0; fi
  t="$(zipinfo -t "$f" 2>/dev/null || true)"
  n="$(printf '%s' "$t" | sed -nE 's/^([0-9]+) files?, ([0-9]+) bytes? uncompressed.*/\1/p')"
  bajty="$(printf '%s' "$t" | sed -nE 's/^([0-9]+) files?, ([0-9]+) bytes? uncompressed.*/\2/p')"
  [ -n "$n" ] && [ -n "$bajty" ] || { odrzuc "$rel" "nie można odczytać rozmiaru archiwum"; return 0; }
  [ "$n" -le "$MAKS_ZIP_PLIKOW" ] || { odrzuc "$rel" "archiwum ma $n plików (limit $MAKS_ZIP_PLIKOW)"; return 0; }
  [ "$bajty" -le "$MAKS_ZIP_B" ] || { odrzuc "$rel" "archiwum po rozpakowaniu ponad 500 MB"; return 0; }

  tmpx="$(mktemp -d "$SHCTL_TMP/zip.XXXXXX")"
  (umask 022 && unzip -qq -o "$f" -d "$tmpx") >/dev/null 2>&1 || { odrzuc "$rel" "błąd rozpakowania archiwum"; return 0; }
  if [ -n "$(find "$tmpx" -type l -print -quit)" ]; then odrzuc "$rel" "dowiązanie symboliczne w archiwum"; return 0; fi
  # Śmieci systemowe nie są materiałem.
  find "$tmpx" \( -name '__MACOSX' -o -name '.*' \) -prune -exec rm -rf {} + 2>/dev/null || true
  while IFS= read -r -d '' g; do
    r="${g#"$tmpx"/}"
    p="$(pakiet_w_sciezce "$r")"
    if [ -n "$p" ]; then odrzuc_pakiet "$rel:$p"; rm -f "$g"; continue; fi
    powod="$(powod_pliku "$g" "$(basename "$r")")"
    if [ -n "$powod" ]; then odrzuc "$rel:$r" "$powod"; rm -f "$g"; continue; fi
    zostalo=$((zostalo + 1))
  done < <(find "$tmpx" -type f -print0)
  [ "$zostalo" -gt 0 ] || { odrzuc "$rel" "archiwum bez plików do przyjęcia"; return 0; }

  baza="$(basename "$rel")"
  baza="${baza%.*}"
  cel_kat="$(dirname "$rel")"
  if [ "$cel_kat" = . ]; then cel_kat="$STG/$baza"; else cel_kat="$STG/$cel_kat/$baza"; fi
  mkdir -p "$cel_kat"
  find "$tmpx" -type d -empty -delete 2>/dev/null || true
  cp -R "$tmpx/." "$cel_kat/"
  printf '%s\t%s\n' "$rel" "$(git hash-object --no-filters -- "$f")" >>"$SHCTL_TMP/przyjete"
}

skanuj() {
  local f rel p powod
  : >"$SHCTL_TMP/przyjete"
  : >"$SHCTL_TMP/odrzucone"
  while IFS= read -r -d '' f; do
    rel="${f#"$SKR"/}"
    if ma_znaki_sterujace "$rel"; then odrzuc "$(printf '%s' "$rel" | LC_ALL=C tr '[:cntrl:]' '?')" "znaki sterujące w nazwie"; continue; fi
    p="$(pakiet_w_sciezce "$rel")"
    if [ -n "$p" ]; then odrzuc_pakiet "$p"; continue; fi
    if [ -L "$f" ]; then odrzuc "$rel" "dowiązanie symboliczne"; continue; fi
    if [ "$(rozszerzenie "$rel")" = zip ]; then przyjmij_zip "$f" "$rel"; continue; fi
    powod="$(powod_pliku "$f" "$(basename "$rel")")"
    if [ -n "$powod" ]; then odrzuc "$rel" "$powod"; continue; fi
    mkdir -p "$STG/$(dirname "$rel")"
    cp -- "$f" "$STG/$rel"
    printf '%s\t%s\n' "$rel" "$(git hash-object --no-filters -- "$f")" >>"$SHCTL_TMP/przyjete"
  done < <(find "$SKR" -mindepth 1 \( -name '_przeniesione' -o -name '.*' -o -name '__MACOSX' \) -prune \
    -o \( -type f -o -type l \) -print0)
  # Prawa jak zwykłe dokumenty: bit wykonywania nie trafia do repo.
  find "$STG" -type f -exec chmod 644 {} + 2>/dev/null || true
  find "$STG" -type d -exec chmod 755 {} + 2>/dev/null || true
}

# Przeniesienie partii po merge'u. Wypisuje JSON {przeniesione, pozostawione}.
przenies() {
  local sp="$1" dzien dst plik hash src h d i
  dzien="$(date +%Y%m%d)"
  : >"$SHCTL_TMP/przeniesione"
  : >"$SHCTL_TMP/pozostawione"
  while IFS=$'\t' read -r plik hash; do
    src="$SKR/$plik"
    if [ ! -f "$src" ]; then printf '%s\t%s\n' "$plik" "brak w skrzynce" >>"$SHCTL_TMP/pozostawione"; continue; fi
    h="$(git hash-object --no-filters -- "$src")"
    if [ "$h" != "$hash" ]; then printf '%s\t%s\n' "$plik" "zmieniony po przyjęciu" >>"$SHCTL_TMP/pozostawione"; continue; fi
    d="$SKR/_przeniesione/$dzien/$plik"
    i=2
    while [ -e "$d" ]; do d="$SKR/_przeniesione/$dzien/$plik.$i"; i=$((i + 1)); done
    if [ "$DRY" -eq 0 ]; then
      mkdir -p "$(dirname "$d")"
      mv -- "$src" "$d"
    fi
    printf '%s\n' "$plik" >>"$SHCTL_TMP/przeniesione"
  done < <(jq -r '.pliki[] | [.plik, .hash] | @tsv' "$sp")
  if [ "$DRY" -eq 0 ]; then
    find "$SKR" -mindepth 1 -depth -type d -empty -print 2>/dev/null | while IFS= read -r d; do
      case "$d" in "$SKR/_przeniesione" | "$SKR/_przeniesione/"*) ;; *) rmdir "$d" 2>/dev/null || true ;; esac
    done
  fi
}

lista_json() { jq -R -s -c 'split("\n") | map(select(length > 0))' "$1"; }
pary_json() {
  jq -R -s -c --arg a "$2" --arg b "$3" 'split("\n") | map(select(length > 0) | split("\t") | {($a): .[0], ($b): .[1]})' "$1"
}

# Commit w odłączonym worktree i push na stage/ETAP: lokalne gałęzie repo głównego zostają nietknięte.
wypchnij_partie() {
  local galaz="stage/$ETAP1" kat="$WT/skrzynka-$ETAP1" baza zdalna=0 ile pr_j body
  z_limitem 120 git -C "$ROOT_G" fetch -q origin || die "$E_WYKONANIE" "git fetch nieudany"
  if git -C "$ROOT_G" rev-parse -q --verify "refs/remotes/origin/$galaz" >/dev/null; then
    baza="origin/$galaz"
    zdalna=1
  else
    baza=origin/main
  fi
  mkdir -p "$WT"
  [ ! -e "$kat" ] || git -C "$ROOT_G" worktree remove --force "$kat" 2>/dev/null || rm -rf "$kat"
  git -C "$ROOT_G" worktree prune
  git -C "$ROOT_G" worktree add -q --detach "$kat" "$baza" || die "$E_WYKONANIE" "worktree $kat nie powstał"
  PRZY_WYJSCIU=sprzatnij_worktree
  WT_SKR="$kat"
  mkdir -p "$kat/docs/$CEL"
  cp -R "$STG/." "$kat/docs/$CEL/"
  git -C "$kat" add -A -- "docs/$CEL"
  ile="$(wc -l <"$SHCTL_TMP/przyjete" | tr -d ' ')"
  if ! git -C "$kat" diff --cached --quiet; then
    git -C "$kat" commit -qm "$ETAP1: materiały ze skrzynki ($ile)" || die "$E_WYKONANIE" "commit nieudany"
  fi
  if [ "$zdalna" -eq 0 ] && [ "$(git -C "$kat" rev-parse HEAD)" = "$(git -C "$kat" rev-parse origin/main)" ]; then
    # Ta sama treść jest już na main: nie ma czego proponować.
    PR_N=0
    return 0
  fi
  if [ "$zdalna" -eq 0 ] || [ "$(git -C "$kat" rev-parse HEAD)" != "$(git -C "$kat" rev-parse "$baza")" ]; then
    z_limitem 120 git -C "$kat" push -q origin "HEAD:refs/heads/$galaz" ||
      die "$E_WYKONANIE" "push na $galaz nieudany; ponów tę samą komendę"
  fi
  pr_j="$(gh pr list --repo "$SLUG" --head "$galaz" --state open --json number,url 2>/dev/null)" ||
    die "$E_WYKONANIE" "gh pr list nie działa dla $SLUG"
  PR_URL="$(jq -r 'max_by(.number) | .url // empty' <<<"$pr_j")"
  if [ -z "$PR_URL" ]; then
    body="$SHCTL_TMP/pr.md"
    {
      printf 'Materiały właściciela ze skrzynki `SH/Skrzynka/%s`, skopiowane do `docs/%s/` przez `shctl skrzynka przyjmij`.\n\n' "$PROJEKT" "$CEL"
      printf 'To dane nieufne: nic nie jest uruchamiane, a pliki wykonywalne zostały odrzucone.\n\n### Przyjęte\n\n'
      (cd "$STG" && find . -type f | sed 's#^\./##' | LC_ALL=C sort | sed 's/^/- `/; s/$/`/')
      if [ -s "$SHCTL_TMP/odrzucone" ]; then
        printf '\n### Odrzucone (zostają w skrzynce)\n\n'
        sed 's/^\([^	]*\)	\(.*\)$/- `\1`: \2/' "$SHCTL_TMP/odrzucone"
      fi
    } >"$body"
    PR_URL="$(gh pr create --repo "$SLUG" --head "$galaz" --base main \
      --title "$ETAP1: materiały ze skrzynki" --body-file "$body" | tail -1)" ||
      die "$E_WYKONANIE" "gh pr create nieudane; ponów tę samą komendę"
  fi
  PR_N="${PR_URL##*/}"
}

WT_SKR=""
sprzatnij_worktree() {
  [ -z "$WT_SKR" ] || git -C "$ROOT_G" worktree remove --force "$WT_SKR" 2>/dev/null || rm -rf "$WT_SKR"
  git -C "$ROOT_G" worktree prune 2>/dev/null || true
}

komenda_main() {
  local akcja="${1:-}" nazwa="" etap="02-design/zrodla" sp prn st stan="" pr_url="" przen='[]' pozost='[]'
  local ile_p ile_o
  [ "$akcja" = przyjmij ] || die "$E_UZYCIE" "użycie: shctl skrzynka przyjmij NAZWA [--etap ETAP/KATALOG]"
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --etap) etap="$(wartosc "$@")"; shift 2 ;;
      --*) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
      *)
        [ -z "$nazwa" ] || die "$E_UZYCIE" "nadmiarowy argument: $1"
        nazwa="$1"
        shift
        ;;
    esac
  done
  [ -z "$nazwa" ] || PROJEKT="$nazwa"
  [ -n "$PROJEKT" ] || die "$E_UZYCIE" "brak NAZWA projektu"

  CEL="${etap%/}"
  case "$CEL" in
    "" | /* | *//* | *[!A-Za-z0-9._/-]*) die "$E_UZYCIE" "niepoprawne --etap: '$etap' (np. 02-design/zrodla)" ;;
  esac
  case "/$CEL/" in */../* | */./*) die "$E_UZYCIE" "niepoprawne --etap: '$etap'" ;; esac
  ETAP1="${CEL%%/*}"
  case " $ETAPY " in *" $ETAP1 "*) ;; *) die "$E_UZYCIE" "nieznany etap w --etap: $ETAP1 (dozwolone: $ETAPY)" ;; esac

  zadania_init
  SKR="$(skrzynka_kat "$PROJEKT")"
  [ -n "$SKR" ] || die "$E_BRAK" "skrzynka nieskonfigurowana: brak SH_SKRZYNKA_DIR i SH_OBSIDIAN_DIR"
  [ -d "$SKR" ] || die "$E_BRAK" "brak skrzynki $SKR (zakłada ją shctl obsidian link $PROJEKT)"
  mkdir -p "$STAN/skrzynka"
  zablokuj "$STAN/skrzynka/$PROJEKT.lock"
  sp="$STAN/skrzynka/$PROJEKT.json"

  # Partia z poprzedniego wywołania: przeniesienie po merge'u albo czekanie.
  if [ -f "$sp" ]; then
    prn="$(jq -r .pr "$sp")"
    pr_url="$(jq -r '.url // ""' "$sp")"
    st="$(gh pr view "$prn" --repo "$SLUG" --json state --jq .state 2>/dev/null)" ||
      die "$E_WYKONANIE" "nie można odczytać PR #$prn"
    case "$st" in
      MERGED)
        przenies "$sp"
        przen="$(lista_json "$SHCTL_TMP/przeniesione")"
        pozost="$(pary_json "$SHCTL_TMP/pozostawione" plik powod)"
        [ "$DRY" -eq 1 ] || rm -f "$sp"
        stan=przeniesiono
        info "PR #$prn scalony: przeniesiono do _przeniesione/: $(jq length <<<"$przen") plików"
        ;;
      OPEN)
        info "PR #$prn z materiałami czeka na merge: $pr_url"
        wynik_json "$(jq -nc --arg p "$PROJEKT" --arg s "$SKR" --argjson n "$prn" --arg u "$pr_url" \
          '{projekt:$p, skrzynka:$s, stan:"czeka_na_merge", pr:$n, url:$u, przyjete:[], odrzucone:[], przeniesione:[]}')"
        return 0
        ;;
      *)
        [ "$DRY" -eq 1 ] || rm -f "$sp"
        die "$E_ODMOWA" "PR #$prn zamknięty bez merge'a; pliki zostały w skrzynce. Usuń zbędne i ponów, żeby założyć nowy PR"
        ;;
    esac
  fi

  STG="$SHCTL_TMP/przyjete-pliki"
  mkdir -p "$STG"
  skanuj
  ile_p="$(wc -l <"$SHCTL_TMP/przyjete" | tr -d ' ')"
  ile_o="$(wc -l <"$SHCTL_TMP/odrzucone" | tr -d ' ')"
  [ "$ile_o" -eq 0 ] || while IFS=$'\t' read -r a b; do uwaga "odrzucony $a: $b"; done <"$SHCTL_TMP/odrzucone"

  PR_N=""
  PR_URL=""
  if [ "$ile_p" -eq 0 ]; then
    if [ "$ile_o" -gt 0 ] && [ "$stan" != przeniesiono ]; then
      die "$E_ODMOWA" "żaden plik ze skrzynki nie został przyjęty (odrzucone: $ile_o); szczegóły wyżej"
    fi
    [ -n "$stan" ] || { stan=pusto; info "skrzynka $SKR: brak nowych plików"; }
  elif [ "$DRY" -eq 1 ]; then
    stan=do_przyjecia
    info "do przyjęcia: $ile_p, odrzucone: $ile_o, cel: docs/$CEL, gałąź stage/$ETAP1"
  else
    wypchnij_partie
    if [ "$PR_N" = 0 ]; then
      # Treść jest już na main: pliki od razu do _przeniesione/.
      jq -R -s '{pr:0, pliki:(split("\n") | map(select(length > 0) | split("\t") | {plik:.[0], hash:.[1]}))}' \
        "$SHCTL_TMP/przyjete" >"$SHCTL_TMP/partia.json"
      przenies "$SHCTL_TMP/partia.json"
      przen="$(jq -c --argjson a "$przen" '$a + .' <<<"$(lista_json "$SHCTL_TMP/przeniesione")")"
      stan=przeniesiono
      PR_N=""
      info "ta sama treść jest już na main: pliki przeniesione do _przeniesione/"
    else
      jq -n --argjson n "$PR_N" --arg u "$PR_URL" --arg g "stage/$ETAP1" --arg c "$CEL" --arg d "$(dzis)" \
        --rawfile p "$SHCTL_TMP/przyjete" \
        '{pr:$n, url:$u, galaz:$g, cel:$c, data:$d,
          pliki:($p | split("\n") | map(select(length > 0) | split("\t") | {plik:.[0], hash:.[1]}))}' >"$sp"
      stan=pr_otwarty
      info "PR #$PR_N z materiałami ($ile_p): $PR_URL"
      info "Po merge'u uruchom ponownie: shctl skrzynka przyjmij $PROJEKT"
    fi
  fi

  wynik_json "$(jq -nc --arg p "$PROJEKT" --arg s "$SKR" --arg st "$stan" --arg c "docs/$CEL" \
    --arg g "stage/$ETAP1" --arg n "${PR_N:-}" --arg u "${PR_URL:-}" \
    --argjson a "$(cut -f1 "$SHCTL_TMP/przyjete" | jq -R -s -c 'split("\n") | map(select(length > 0))')" \
    --argjson o "$(pary_json "$SHCTL_TMP/odrzucone" plik powod)" --argjson m "$przen" --argjson z "$pozost" \
    '{projekt:$p, skrzynka:$s, stan:$st, cel:$c, galaz:$g, pr:(if $n == "" then null else ($n | tonumber) end),
      url:(if $u == "" then null else $u end), przyjete:$a, odrzucone:$o, przeniesione:$m, pozostawione:$z}')"
}
