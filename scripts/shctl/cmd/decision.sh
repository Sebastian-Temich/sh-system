# shctl decision add --co --dlaczego --cofniecie [--rola]
# Kolumny decyzje.md: Data | Źródło | Pytanie | Decyzja. Źródło to rola, Pytanie to --co,
# a Decyzja niesie uzasadnienie i sposób cofnięcia.
# shellcheck shell=bash

komenda_main() {
  local co="" dlaczego="" cofniecie="" rola=orkiestrator plik ogon wiersz dodano=0
  [ "${1:-}" = add ] || die "$E_UZYCIE" "użycie: shctl decision add --co --dlaczego --cofniecie [--rola]"
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --co) co="$(wartosc "$@")"; shift 2 ;;
      --dlaczego) dlaczego="$(wartosc "$@")"; shift 2 ;;
      --cofniecie) cofniecie="$(wartosc "$@")"; shift 2 ;;
      --rola) rola="$(wartosc "$@")"; shift 2 ;;
      *) opcja_wspolna "$@"; shift "$ZJEDZONE" ;;
    esac
  done
  [ -n "$co" ] && [ -n "$dlaczego" ] && [ -n "$cofniecie" ] ||
    die "$E_UZYCIE" "wymagane: --co, --dlaczego, --cofniecie"
  znajdz_projekt
  plik="$ROOT/docs/decyzje.md"
  [ -f "$plik" ] || die "$E_BRAK" "brak docs/decyzje.md"

  ogon="| $(komorka "$rola") | $(komorka "$co") | $(komorka "$dlaczego"). Cofnięcie: $(komorka "$cofniecie") |"
  wiersz="| $(dzis) $ogon"
  # Bez daty: ta sama decyzja zapisana innego dnia też jest powtórką.
  if ! grep -qF -- " $ogon" "$plik"; then
    dodano=1
    if [ "$DRY" -eq 0 ]; then
      ostrzez_gdy_nie_main
      [ -z "$(tail -c 1 "$plik")" ] || printf '\n' >>"$plik"
      printf '%s\n' "$wiersz" >>"$plik"
    fi
  fi
  if [ "$dodano" -eq 1 ]; then info "dopisano: $wiersz"; else info "bez zmian: decyzja już jest w decyzje.md"; fi
  wynik_json "$(jq -nc --arg w "$wiersz" --argjson z "$dodano" '{wiersz:$w, dodano:($z == 1)}')"
}
