# shctl cykl new --nazwa NAZWA [--od ISO]: kolejny cykl etapów trybu M w projekcie, którego poprzedni
# cykl jest zamknięty (wszystkie etapy done albo pominiety). Dokumenty etapów poprzedniego cyklu
# przechodzą do docs/cykle/POPRZEDNI/, etapy dostają świeże DoD.md (status todo, iteracja 0), a
# docs/konfiguracja.md pola cykl, cykl_od i zlecenie_od. Zostają na miejscu: ADR (decyzje obowiązują
# dalej, numeracja ciągła), 06-zadania/index.md (tabela wszystkich zadań) i 00-analiza projektu
# przejętego (analiza jest jednorazowa). Stare gałęzie stage/ETAP z PR zmergowanym albo zamkniętym
# znikają z origin i lokalnie, bo nowy cykl zakłada je od nowa z origin/main.
# shellcheck shell=bash

# shellcheck source=../lib/zadania.sh
. "$SHCTL_DIR/lib/zadania.sh"

# Etapy cyklu: ETAPY bez 00-analiza.
etapy_cyklu() {
  local e
  for e in $ETAPY; do [ "$e" = 00-analiza ] || printf '%s ' "$e"; done
}

# Ścieżki (względem docs/) zostające przy archiwizacji.
zostaje() {
  case "$1" in */adr | 06-zadania/index.md) return 0 ;; esac
  return 1
}

# Świeży DoD.md etapu do pliku $2: wersja z commita, który dodał plik (szablon projektu), a bez
# historii bieżąca z odznaczonymi polami. Zawsze status todo, iteracja 0 i bez decyzji o pominięciu.
swiezy_dod() {
  local wzgl="docs/$1/DoD.md" c
  c="$(git -C "$ROOT" log --diff-filter=A --format=%H -- "$wzgl" 2>/dev/null | tail -n 1)"
  if [ -z "$c" ] || ! git -C "$ROOT" show "$c:$wzgl" >"$2" 2>/dev/null || [ ! -s "$2" ]; then
    sed -E -e 's/^([ \t]*[-*+] )\[[xX-]\] (.*) \(nie dotyczy:[^)]*\)[ \t]*$/\1[ ] \2/' \
      -e 's/^([ \t]*[-*+] )\[[xX-]\]/\1[ ]/' "$ROOT/$wzgl" >"$2"
  fi
  yq -i --front-matter=process '.status = "todo" | .iteracja = 0 | del(.decyzja)' "$2"
}

# Opis archiwum: docs/cykle/NAZWA/cykl.md (frontmatter czyta scripts/sync-status.sh).
opis_archiwum() {
  local poprz="$1" od="$2" do_="$3" nowy="$4" kat="$5" e f
  printf -- '---\ncykl: %s\nod: "%s"\ndo: "%s"\n---\n\n# Cykl %s\n\n' "$poprz" "$od" "$do_" "$poprz"
  printf 'Dokumenty etapów zamkniętego cyklu %s, zarchiwizowane przy starcie cyklu %s (`shctl cykl new`,\n%s). ADR zostały w `docs/04-plan/adr/`, a lista wszystkich zadań jest w `docs/historia.md`.\n\n' \
    "$poprz" "$nowy" "$(dzis)"
  for e in $(etapy_cyklu); do
    [ -d "$kat/$e" ] || continue
    for f in "$kat/$e"/*.md; do
      [ -e "$f" ] || continue
      printf -- '- [%s/%s](%s/%s)\n' "$e" "$(basename "$f")" "$e" "$(basename "$f")"
    done
    if [ -d "$kat/$e/funkcje" ]; then
      printf -- '- Karty funkcji: %s w `%s/funkcje/`\n' "$(find "$kat/$e/funkcje" -name 'W-*.md' | wc -l | tr -d ' ')" "$e"
    fi
  done
}

# Dziennik etapów z nagłówkami cykli: wpisy sprzed pierwszego cyklu dostają „### Cykl POPRZEDNI”,
# a nowy cykl swój nagłówek i pierwszy wpis.
dziennik_cyklu() {
  local poprz="$1" nowy="$2" linia="$3" h obecne
  h="$(plik_historii "$ROOT")"
  [ -f "$h" ] || printf '# Historia projektu\n\n## Punkt przekazania\n\n(brak)\n\n## Dziennik etapów\n\n(brak)\n' >"$h"
  obecne="$(czytaj_sekcje "$h" "Dziennik etapów" | grep -vxF '(brak)' || true)"
  ! printf '%s\n' "$obecne" | grep -qxF "### Cykl $nowy" || return 0
  printf '%s\n' "$obecne" | grep -q '^### ' || obecne="### Cykl $poprz${obecne:+

$obecne}"
  ustaw_sekcje "$h" "Dziennik etapów" "$obecne

### Cykl $nowy

$linia"
}

# Gałęzie stage/ETAP poprzedniego cyklu. Wypisuje „zdalna ETAP” i „lokalna ETAP” do usunięcia;
# otwarty PR albo worktree gałęzi to odmowa.
stare_galezie() {
  local e prs stan wt
  for e in $(etapy_cyklu); do
    if git -C "$ROOT" rev-parse -q --verify "refs/remotes/origin/stage/$e" >/dev/null; then
      prs="$(gh pr list --repo "$SLUG" --head "stage/$e" --state all --json number,state 2>/dev/null)" ||
        die "$E_WYKONANIE" "gh pr list nie działa dla $SLUG"
      stan="$(jq -r 'if any(.[]; .state == "OPEN") then "OPEN" elif length == 0 then "BRAK" else "ZAMKNIETY" end' <<<"$prs")"
      case "$stan" in
        OPEN) die "$E_ODMOWA" "gałąź stage/$e ma otwarty PR; zamknij go albo zmerguj przed nowym cyklem" ;;
        BRAK) die "$E_ODMOWA" "gałąź origin/stage/$e nie ma PR; usuwa ją właściciel (git push origin --delete stage/$e)" ;;
      esac
      echo "zdalna $e"
    fi
    if git -C "$ROOT" rev-parse -q --verify "refs/heads/stage/$e" >/dev/null; then
      wt="$(git -C "$ROOT" worktree list --porcelain | awk -v b="branch refs/heads/stage/$e" '/^worktree /{w = substr($0, 10)} $0 == b {print w}')"
      [ -z "$wt" ] || die "$E_ODMOWA" "gałąź stage/$e jest w worktree $wt; najpierw shctl sprzataj"
      echo "lokalna $e"
    fi
  done
}

komenda_main() {
  local akcja="${1:-}" nazwa="" od="" poprz poprz_od e niezamkniete="" kat wzgl f n=0 linia galezie t
  [ "$akcja" = new ] || die "$E_UZYCIE" "użycie: shctl cykl new --nazwa NAZWA [--od RRRR-MM-DDTGG:MM:SSZ]"
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --nazwa) nazwa="$(wartosc "$@")"; shift 2 ;;
      --od) od="$(wartosc "$@")"; shift 2 ;;
      *) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
    esac
  done
  [ -n "$nazwa" ] || die "$E_UZYCIE" "brak --nazwa (np. M2-bezpieczenstwo)"
  printf '%s' "$nazwa" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9-]{0,39}$' ||
    die "$E_UZYCIE" "niepoprawna nazwa cyklu: '$nazwa' (litery, cyfry i -, do 40 znaków, np. M2-bezpieczenstwo)"
  [ -z "$od" ] || printf '%s' "$od" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(:[0-9]{2})?Z$' ||
    die "$E_UZYCIE" "--od w UTC, np. 2026-11-13T10:00:00Z"
  [ -n "$od" ] || od="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  zadania_init
  [ "$(tryb)" = M ] || die "$E_ODMOWA" "cykl etapów jest tylko w trybie M (tryb_procesu: $(tryb))"
  [ "$(kat_docs)" = "$ROOT" ] || die "$E_ODMOWA" "projekt przejęty przed merge'em analizy nie ma zamkniętego cyklu"

  poprz="$(fm_get "$KONFIG" cykl)"
  [ -n "$poprz" ] || poprz=M1
  poprz_od="$(fm_get "$KONFIG" cykl_od)"
  if [ "$poprz" = "$nazwa" ]; then
    info "$PROJEKT: cykl $nazwa już trwa (od ${poprz_od:-początku}), bez zmian"
    wynik_json "$(jq -nc --arg p "$PROJEKT" --arg c "$nazwa" --arg o "$poprz_od" '{projekt:$p, cykl:$c, cykl_od:$o, zmiana:false}')"
    return 0
  fi
  [ ! -e "$ROOT/docs/cykle/$nazwa" ] || die "$E_ODMOWA" "nazwa $nazwa jest już zajęta przez archiwum docs/cykle/$nazwa"
  kat="$ROOT/docs/cykle/$poprz"
  [ ! -e "$kat" ] || die "$E_ODMOWA" "archiwum docs/cykle/$poprz już istnieje; pole cykl w konfiguracji nie zgadza się z archiwum"

  for e in $(etapy_cyklu); do
    [ -f "$ROOT/docs/$e/DoD.md" ] || die "$E_BRAK" "brak docs/$e/DoD.md"
    case "$(fm_get "$ROOT/docs/$e/DoD.md" status)" in
      done | pominiety) ;;
      *) niezamkniete="$niezamkniete $e:$(fm_get "$ROOT/docs/$e/DoD.md" status)" ;;
    esac
  done
  [ -z "$niezamkniete" ] || die "$E_ODMOWA" "cykl $poprz nie jest zamknięty:$niezamkniete (nowy cykl po done albo pominiety wszystkich etapów)"
  # shellcheck disable=SC2046
  [ -z "$(git -C "$ROOT" status --porcelain -- $(for e in $(etapy_cyklu); do printf 'docs/%s ' "$e"; done) docs/konfiguracja.md ':(exclude)docs/06-zadania/index.md')" ] ||
    die "$E_ODMOWA" "niezacommitowane zmiany w docs/ etapów albo konfiguracji; zacommituj je przed nowym cyklem"

  git_gh -t 120 -C "$ROOT" fetch -q --prune origin || die "$E_WYKONANIE" "git fetch origin nie powiódł się"
  galezie="$(stare_galezie)"

  linia="- $(dzis) cykl \`$nazwa\`: start (zlecenie_od $od), cykl $poprz w docs/cykle/$poprz/"
  if [ "$DRY" -eq 0 ]; then
    ostrzez_gdy_nie_main
    t="$SHCTL_TMP/dod"
    mkdir -p "$t" "$kat"
    for e in $(etapy_cyklu); do
      swiezy_dod "$e" "$t/$e.md"
      mkdir -p "$kat/$e"
      for f in "$ROOT/docs/$e"/* "$ROOT/docs/$e"/.[!.]*; do
        [ -e "$f" ] || continue
        wzgl="$e/$(basename "$f")"
        if zostaje "$wzgl"; then continue; fi
        mv "$f" "$kat/$wzgl"
        n=$((n + 1))
        [ ! -d "$kat/$wzgl" ] || mkdir -p "$ROOT/docs/$wzgl"
      done
      cp "$t/$e.md" "$ROOT/docs/$e/DoD.md"
    done
    opis_archiwum "$poprz" "$poprz_od" "$od" "$nazwa" "$kat" >"$kat/cykl.md"
    fm_set "$KONFIG" cykl "$nazwa"
    fm_set "$KONFIG" cykl_od "$od"
    fm_set "$KONFIG" zlecenie_od "$od"
    stan_etapy_wyczysc
    while read -r rodzaj e; do
      [ -n "$e" ] || continue
      case "$rodzaj" in
        zdalna) git_gh -t 120 -C "$ROOT" push -q origin --delete "stage/$e" ||
          uwaga "nie można usunąć origin/stage/$e; nowa gałąź etapu wymaga ręcznego usunięcia starej" ;;
        lokalna) git -C "$ROOT" branch -q -D "stage/$e" || uwaga "nie można usunąć lokalnej gałęzi stage/$e" ;;
      esac
    done <<<"$galezie"
    dziennik_cyklu "$poprz" "$nazwa" "$linia"
    odswiez_projekt || true
  fi
  info "$PROJEKT: cykl $nazwa od $od; cykl $poprz w docs/cykle/$poprz/; etapy $(etapy_cyklu)todo"
  [ -z "$galezie" ] || info "stare gałęzie etapów do usunięcia: $(printf '%s\n' "$galezie" | awk '{printf "%s%s stage/%s", s, $1, $2; s = ", "}')"
  wynik_json "$(jq -nc --arg p "$PROJEKT" --arg c "$nazwa" --arg o "$od" --arg pp "$poprz" --arg e "$(etapy_cyklu)" \
    --argjson n "$n" --arg g "$galezie" '
    {projekt:$p, cykl:$c, cykl_od:$o, poprzedni:$pp, archiwum:"docs/cykle/\($pp)",
     etapy:($e | split(" ") | map(select(length > 0))), przeniesione:$n,
     galezie_usuniete:($g | split("\n") | map(select(length > 0) | split(" ") | {rodzaj:.[0], galaz:"stage/\(.[1])"})),
     zmiana:true}')"
}

# Pamięć powtórek stage iter (stan/NAZWA.json, .etapy) dotyczy poprzedniego cyklu.
stan_etapy_wyczysc() {
  local f t
  f="$(plik_stanu)"
  [ -f "$f" ] || return 0
  zablokuj "$f.lock"
  t="$(tmp_plik)"
  jq '.etapy = {}' "$f" >"$t" && cp "$t" "$f"
  rm -f "$t"
  odblokuj "$f.lock"
}
