# Lekki klon docs/ projektu w vaulcie Obsidiana. Używają go new-project i obsidian link.
# shellcheck shell=bash

obsidian_kat() { printf '%s/%s' "$SH_OBSIDIAN_DIR" "$1"; }

obsidian_wymagaj() {
  [ -n "${SH_OBSIDIAN_DIR:-}" ] || die "$E_BRAK" "brak SH_OBSIDIAN_DIR w $SH_CONFIG"
}

# Czy katalog jest klonem repo OWNER/NAZWA. Surowy URL, bez reguł insteadOf.
obsidian_czy_klon() {
  local o
  o="$(git -C "$1" config --local --get remote.origin.url 2>/dev/null || true)"
  case "$o" in
    *"/$2" | *"/$2.git" | *":$2" | *":$2.git") [ -e "$1/.git" ] ;;
    *) return 1 ;;
  esac
}

# Tryb no-cone: cone zostawiłby też pliki z katalogu głównego repo.
# Wypisuje 1, gdy założono klon, 0, gdy już był.
obsidian_polacz() {
  local nazwa="$1" slug="${2:-$SH_GH_OWNER/$1}" kat
  kat="$(obsidian_kat "$nazwa")"
  if [ -e "$kat" ]; then
    obsidian_czy_klon "$kat" "$slug" || die "$E_ODMOWA" "$kat istnieje i nie jest klonem $slug"
    echo 0
    return 0
  fi
  if [ "$DRY" -eq 0 ]; then
    mkdir -p "$SH_OBSIDIAN_DIR"
    git_gh clone --quiet --filter=blob:none --sparse "https://github.com/$slug.git" "$kat" >&2 ||
      die "$E_WYKONANIE" "nie można sklonować $slug do $kat; ponów: shctl obsidian link $nazwa"
    git -C "$kat" sparse-checkout set --no-cone /docs/ >&2 ||
      die "$E_WYKONANIE" "sparse-checkout nieudany w $kat"
  fi
  echo 1
}

# Pusto, gdy klon wolno usunąć; inaczej powód.
obsidian_przeszkoda() {
  local kat="$1" zmiany g n
  zmiany="$(git -C "$kat" status --porcelain 2>/dev/null || echo blad)"
  if [ -n "$zmiany" ]; then
    echo "niezacommitowane zmiany: $(printf '%s\n' "$zmiany" | wc -l | tr -d ' ')"
    return 0
  fi
  g="$(git -C "$kat" symbolic-ref --short -q HEAD || true)"
  n="$(git -C "$kat" rev-list --count "origin/${g:-main}..HEAD" 2>/dev/null || echo 1)"
  [ "$n" -eq 0 ] || echo "niewypchnięte commity: $n"
}

# ok, albo opis różnicy. Bez fetch, żeby doctor niczego nie zapisywał.
obsidian_stan() {
  local kat="$1" zmiany g lok zdal
  zmiany="$(git -C "$kat" status --porcelain 2>/dev/null || echo blad)"
  if [ -n "$zmiany" ]; then
    echo "niezacommitowane zmiany: $(printf '%s\n' "$zmiany" | wc -l | tr -d ' ')"
    return 0
  fi
  g="$(git -C "$kat" symbolic-ref --short -q HEAD || true)"
  lok="$(git -C "$kat" rev-parse HEAD 2>/dev/null || true)"
  zdal="$(git_gh -t 20 -C "$kat" ls-remote origin "refs/heads/${g:-main}" 2>/dev/null | cut -f1 || true)"
  if [ -z "$zdal" ]; then
    echo "origin niedostępny"
  elif [ "$zdal" = "$lok" ]; then
    echo ok
  else
    echo "różni się od origin"
  fi
}

# --- Skrzynka na materiały (shctl skrzynka) ----------------------------------------------------

# Zwykły folder w vaulcie, nie repo: właściciel wrzuca tu materiały, a obsidian-sync.sh go nie dotyka
# (synchronizuje tylko klony w SH_OBSIDIAN_DIR i klon sh-system). Domyślnie SH/Skrzynka obok Projekty.
skrzynka_kat_glowny() {
  if [ -n "${SH_SKRZYNKA_DIR:-}" ]; then
    printf '%s' "$SH_SKRZYNKA_DIR"
  elif [ -n "${SH_OBSIDIAN_DIR:-}" ]; then
    printf '%s/Skrzynka' "$(dirname "$SH_OBSIDIAN_DIR")"
  fi
}

skrzynka_kat() {
  local g
  g="$(skrzynka_kat_glowny)"
  [ -n "$g" ] || return 0
  printf '%s/%s' "$g" "$1"
}

# Wypisuje 1, gdy założono folder, 0, gdy już był albo skrzynka nie jest skonfigurowana.
skrzynka_utworz() {
  local kat
  kat="$(skrzynka_kat "$1")"
  [ -n "$kat" ] || { echo 0; return 0; }
  [ ! -d "$kat" ] || { echo 0; return 0; }
  [ ! -e "$kat" ] || die "$E_ODMOWA" "$kat istnieje i nie jest folderem"
  [ "$DRY" -eq 1 ] || mkdir -p "$kat" || die "$E_WYKONANIE" "nie można utworzyć $kat"
  echo 1
}
