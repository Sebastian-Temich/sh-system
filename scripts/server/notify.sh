#!/usr/bin/env bash
# /Users/Shared/sh/bin/notify.sh - powiadomienie push przez ntfy.sh.
#
#   notify.sh <min|default|high|urgent> <tytul> <tresc> [url] [tagi]
#
#   url    adres otwierany po kliknieciu (naglowek Click); "" gdy podajesz tylko tagi
#   tagi   lista po przecinku, np. warning,skull
#
# Temat czytany z ~/.config/sh/ntfy-topic. Kody wyjscia: 0 wyslano, 1 blad wysylki,
# 2 bledne argumenty, 3 brak lub bledny temat.
set -euo pipefail

TOPIC_FILE="$HOME/.config/sh/ntfy-topic"
NTFY_URL=https://ntfy.sh
USAGE='uzycie: notify.sh <min|default|high|urgent> <tytul> <tresc> [url] [tagi]'

die() { printf 'notify.sh: BLAD: %s\n' "$2" >&2; exit "$1"; }

# Jedna linia, zeby wartosc nie mogla dopisac wlasnego naglowka.
one_line() { printf '%s' "$1" | tr '\r\n' '  '; }

# Naglowki HTTP sa ASCII; reszte (np. polskie znaki) ntfy dekoduje z RFC 2047.
header_value() {
  local value
  value=$(one_line "$1")
  if printf '%s' "$value" | LC_ALL=C grep -q '[^ -~]'; then
    printf '=?UTF-8?B?%s?=' "$(printf '%s' "$value" | base64 | tr -d '\n')"
  else
    printf '%s' "$value"
  fi
}

[ $# -ge 3 ] && [ $# -le 5 ] || die 2 "$USAGE"
PRIORITY=$1 TITLE=$2 MESSAGE=$3 CLICK=${4:-} TAGS=${5:-}

case "$PRIORITY" in
  min | default | high | urgent) ;;
  *) die 2 "nieznany priorytet '$PRIORITY' (dozwolone: min, default, high, urgent)" ;;
esac
[ -n "$TITLE" ] || die 2 'pusty tytul'
[ -n "$MESSAGE" ] || die 2 'pusta tresc'

[ -f "$TOPIC_FILE" ] || die 3 "brak pliku z tematem ntfy: $TOPIC_FILE (zapisz w nim nazwe tematu)"
[ -r "$TOPIC_FILE" ] || die 3 "brak prawa odczytu pliku z tematem ntfy: $TOPIC_FILE"
TOPIC=$(tr -d '[:space:]' <"$TOPIC_FILE")
[ -n "$TOPIC" ] || die 3 "pusty plik z tematem ntfy: $TOPIC_FILE"
[[ "$TOPIC" =~ ^[-_A-Za-z0-9]{1,64}$ ]] ||
  die 3 "bledny temat w $TOPIC_FILE (dozwolone: litery, cyfry, - i _, do 64 znakow)"

HEADERS=(-H "Priority: $PRIORITY" -H "Title: $(header_value "$TITLE")")
[ -z "$CLICK" ] || HEADERS+=(-H "Click: $(header_value "$CLICK")")
[ -z "$TAGS" ] || HEADERS+=(-H "Tags: $(header_value "$TAGS")")

# Tresc idzie przez stdin: curl czytalby plik z wartosci zaczynajacej sie od @.
CODE=$(printf '%s' "$MESSAGE" | curl -sS --max-time 10 -o /dev/null -w '%{http_code}' \
  "${HEADERS[@]}" --data-binary @- "$NTFY_URL/$TOPIC") ||
  die 1 'nie udalo sie polaczyc z ntfy.sh'
case "$CODE" in
  2??) ;;
  *) die 1 "ntfy.sh odpowiedzialo kodem HTTP $CODE" ;;
esac
