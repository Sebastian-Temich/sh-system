# shctl pr check PR [--czekaj] [--timeout SEKUNDY]: stan PR przed czekaniem na CI (docs/shctl.md, „pr”).
# Najpierw konflikt z main: przy CONFLICTING GitHub nie uruchamia workflowów pull_request, więc
# czekanie na CI nie ma sensu i shctl zgłasza konflikt wprost (kod 4). Potem wynik CI; z --czekaj
# czeka, aż CI się rozstrzygnie: pass dopiero, gdy wszystkie joby i biegi workflow commita są zakończone
# (ci_pr w lib/zadania.sh). Dla PR zadania liczy czerwone commity: po 2 nieudanych naprawach
# workera zadanie idzie do review albo eskalacji (proces.md, „Etapy trybu M”, „Realizacja”). Commit zmieniający
# tylko raport zadania nie jest próbą naprawy.
# shellcheck shell=bash

# shellcheck source=../lib/zadania.sh
. "$SHCTL_DIR/lib/zadania.sh"

MAKS_NAPRAW_CI=2

# Czy między commitami zmienił się tylko raport zadania (docs/07-realizacja/T-NR.md). Taki commit nie
# jest próbą naprawy CI. Brak commitów lokalnie albo błąd diff liczy się jako naprawa.
tylko_raport() {
  local nr="$1" od="$2" do_="$3" br="$4" pliki
  git -C "$ROOT_G" cat-file -e "$do_^{commit}" 2>/dev/null ||
    z_limitem 120 git -C "$ROOT_G" fetch -q origin "$br" 2>/dev/null || true
  pliki="$(git -C "$ROOT_G" diff --name-only "$od" "$do_" 2>/dev/null)" || return 1
  [ -n "$pliki" ] && [ "$pliki" = "docs/07-realizacja/T-$nr.md" ]
}

# Czerwone commity zadania (stan .zadania[NR].ci_czerwone); dopisuje bieżący przy fail. Commit, który
# względem poprzedniego czerwonego zmienia tylko raport, trafia też do .ci_tylko_raport.
czerwone_ci() {
  local nr="$1" head="$2" ci="$3" br="$4" st lista raport poprz
  st="$(stan_zadania "$nr")"
  lista="$(jq -c '.ci_czerwone // []' <<<"$st")"
  raport="$(jq -c '.ci_tylko_raport // []' <<<"$st")"
  if [ "$ci" = fail ] && ! jq -e --arg h "$head" 'index($h) != null' <<<"$lista" >/dev/null; then
    poprz="$(jq -r 'last // ""' <<<"$lista")"
    if [ -n "$poprz" ] && tylko_raport "$nr" "$poprz" "$head" "$br"; then
      raport="$(jq -c --arg h "$head" '. + [$h]' <<<"$raport")"
    fi
    lista="$(jq -c --arg h "$head" '. + [$h]' <<<"$lista")"
    stan_zapisz "$nr" "$(jq -nc --argjson l "$lista" --argjson r "$raport" '{ci_czerwone:$l, ci_tylko_raport:$r}')"
  fi
  jq -nc --argjson l "$lista" --argjson r "$raport" '{czerwone:$l, tylko_raport:$r}'
}

pr_check() {
  local prn="" czekaj=0 timeout=1800 pr m ci t=0 nr head br brak_od=0 czerwone='[]' naprawy=0 krok=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --czekaj) czekaj=1; shift ;;
      --timeout) timeout="$(wartosc "$@")"; shift 2 ;;
      -*) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
      *)
        [ -z "$prn" ] || die "$E_UZYCIE" "nadmiarowy argument: $1"
        prn="$1"
        shift
        ;;
    esac
  done
  [ -n "$prn" ] || die "$E_UZYCIE" "użycie: shctl pr check PR [--czekaj] [--timeout SEKUNDY]"
  prn="$(numer "${prn#\#}")"
  timeout="$(numer "$timeout")"
  zadania_init

  pr="$(gh pr view "$prn" --repo "$SLUG" --json number,state,headRefName,headRefOid,closingIssuesReferences 2>/dev/null)" ||
    die "$E_BRAK" "nie można odczytać PR #$prn w $SLUG"
  [ "$(jq -r .state <<<"$pr")" = OPEN ] || die "$E_ODMOWA" "PR #$prn nie jest otwarty"
  br="$(jq -r .headRefName <<<"$pr")"
  head="$(jq -r .headRefOid <<<"$pr")"
  nr="$(jq -r '.closingIssuesReferences[0].number // (.headRefName | capture("^task/(?<n>[0-9]+)").n // "")' <<<"$pr")"

  while :; do
    m="$(mergeable_pr "$prn")"
    [ "$m" != CONFLICTING ] || die "$E_ODMOWA" "$(komunikat_konfliktu "$prn" "$br")"
    ci="$(ci_pr "$prn" "$head")" || die "$E_WYKONANIE" "nie można odczytać CI PR #$prn"
    [ "$czekaj" -eq 1 ] || break
    case "$ci" in
      pass | fail) break ;;
      brak)
        # Workflow rejestruje się chwilę po pushu; dłuższy brak to brak CI, nie oczekiwanie.
        [ "$brak_od" -gt 0 ] || brak_od=$((t + 1))
        [ $((t + 1 - brak_od)) -lt "${SHCTL_CI_BRAK:-180}" ] || break
        ;;
      *) brak_od=0 ;;
    esac
    [ "$t" -lt "$timeout" ] || break
    sleep "${SHCTL_CI_PAUZA:-20}"
    t=$((t + ${SHCTL_CI_PAUZA:-20}))
  done

  if [ -n "$nr" ]; then
    czerwone="$(czerwone_ci "$nr" "$head" "$ci" "$br")"
    naprawy="$(jq -r '(.czerwone | length) - 1 - (.tylko_raport | length) | if . < 0 then 0 else . end' <<<"$czerwone")"
    czerwone="$(jq -c .czerwone <<<"$czerwone")"
  fi
  case "$ci" in
    pass) krok="shctl review run $prn" ;;
    fail)
      if [ -n "$nr" ] && [ "$naprawy" -ge "$MAKS_NAPRAW_CI" ]; then
        krok="limit napraw CI: review albo eskalacja (proces.md, „Etapy trybu M”, „Realizacja”)"
      else
        krok="naprawa CI przez workera (nieudane naprawy: $naprawy z $MAKS_NAPRAW_CI)"
      fi
      ;;
    pending) krok="CI w toku: shctl pr check $prn --czekaj" ;;
    brak) krok="brak CI dla commita ${head:0:7}: sprawdź workflow i gałąź" ;;
  esac
  info "PR #$prn: mergeable $m, CI $ci; dalej: $krok"
  wynik_json "$(jq -nc --argjson p "$prn" --arg n "$nr" --arg h "$head" --arg m "$m" --arg c "$ci" \
    --argjson cz "$czerwone" --argjson np "$naprawy" --argjson mx "$MAKS_NAPRAW_CI" --arg k "$krok" \
    '{pr:$p, nr:(if $n == "" then null else ($n | tonumber) end), head:$h, mergeable:$m, konflikt:false, ci:$c,
      czerwone_commity:($cz | length), nieudane_naprawy_ci:$np, maks_napraw_ci:$mx,
      limit_napraw_ci:($c == "fail" and $n != "" and $np >= $mx), nastepny_krok:$k}')"
}

komenda_main() {
  local sub="${1:-}"
  case "$sub" in
    check) shift; pr_check "$@" ;;
    *) die "$E_UZYCIE" "użycie: shctl pr check PR [--czekaj] [--timeout SEKUNDY]" ;;
  esac
}
