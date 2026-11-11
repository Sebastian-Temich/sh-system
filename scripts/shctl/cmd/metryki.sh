# shctl metryki serwer [--probki N] [--co SEKUNDY]: obciążenie Maca do metryk przebiegu (load, swap,
# dysk, rdzenie). Orkiestrator woła ją zamiast sysctl i df: shctl działa poza sandboxem sesji SH
# (sandbox.excludedCommands), a sysctl w sandboxie orkiestratora jest zablokowany (sh-dryrun, przebieg 5).
# Bez projektu; tylko odczyt.
# shellcheck shell=bash

# Jedna próbka: {czas, load:{m1,m5,m15}, swap:{total_mb,used_mb}, dysk:{sciezka,wolne_gb}, rdzenie}.
probka() {
  local load swap dysk rdz
  load="$(sysctl -n vm.loadavg 2>/dev/null | tr -d '{}' || true)"
  swap="$(sysctl -n vm.swapusage 2>/dev/null || true)"
  rdz="$(sysctl -n hw.ncpu 2>/dev/null || true)"
  dysk="$(df -Pk "$SH_DIR" 2>/dev/null | LC_ALL=C awk 'NR == 2 { printf "%.1f", $4 / 1048576 }')"
  [ -n "$load" ] || die "$E_WYKONANIE" "sysctl vm.loadavg nie działa (shctl w sandboxie? wywołaj prostą komendą shctl)"
  jq -nc --arg c "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg l "$load" --arg s "$swap" --arg d "$dysk" --arg r "$rdz" --arg k "$SH_DIR" '
    def mb: if . == null then null else (.v | tonumber) * ({"K": (1 / 1024), "M": 1, "G": 1024}[.j] // 1) | . * 10 | round / 10 end;
    ($l | split(" ") | map(select(length > 0) | tonumber + 0)) as $la
    | {czas: $c,
       load: {m1: $la[0], m5: $la[1], m15: $la[2]},
       swap: {total_mb: ($s | capture("total = (?<v>[0-9.]+)(?<j>[KMG])")? | mb),
              used_mb: ($s | capture("used = (?<v>[0-9.]+)(?<j>[KMG])")? | mb)},
       dysk: {sciezka: $k, wolne_gb: (if $d == "" then null else ($d | tonumber + 0) end)},
       rdzenie: (if $r == "" then null else ($r | tonumber) end)}'
}

metryki_serwer() {
  local n=1 co=30 i=1 p wszystkie='[]' wynik
  while [ $# -gt 0 ]; do
    case "$1" in
      --probki) n="$(wartosc "$@")"; shift 2 ;;
      --co) co="$(wartosc "$@")"; shift 2 ;;
      *) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
    esac
  done
  case "$n" in "" | *[!0-9]* | 0) die "$E_UZYCIE" "--probki: liczba dodatnia" ;; esac
  case "$co" in "" | *[!0-9]*) die "$E_UZYCIE" "--co: liczba sekund" ;; esac
  wymagaj jq sysctl df
  while :; do
    p="$(probka)"
    wszystkie="$(jq -c --argjson p "$p" '. + [$p]' <<<"$wszystkie")"
    [ "$i" -lt "$n" ] || break
    i=$((i + 1))
    sleep "$co"
  done
  # Ostatnia próbka plus podsumowanie load 1 min przy kilku próbkach (średnia i maksimum).
  wynik="$(jq -c '(last) + {probki: length,
    load_m1: {srednia: (map(.load.m1) | add / length | . * 100 | round / 100), maks: (map(.load.m1) | max)}}' <<<"$wszystkie")"
  info "$(jq -r '"load \(.load.m1) \(.load.m5) \(.load.m15) (rdzenie \(.rdzenie // "-")), swap \(.swap.used_mb // "-") z \(.swap.total_mb // "-") MB, wolne \(.dysk.wolne_gb // "-") GB"
    + (if .probki > 1 then ", load 1 min z \(.probki) próbek: średnio \(.load_m1.srednia), maks. \(.load_m1.maks)" else "" end)' <<<"$wynik")"
  wynik_json "$wynik"
}

komenda_main() {
  case "${1:-}" in
    serwer) shift; metryki_serwer "$@" ;;
    *) die "$E_UZYCIE" "użycie: shctl metryki serwer [--probki N] [--co SEKUNDY]" ;;
  esac
}
