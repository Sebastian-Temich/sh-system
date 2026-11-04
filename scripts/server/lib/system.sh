# Wspólne funkcje skryptów serwera i shctl: PATH pod launchd i kontrola orkiestratora.
# Źródło dla sh-start.sh, sh-watchdog.sh i shctl (doctor). Jedno miejsce, jedna definicja.
#
# Orkiestrator działa, gdy w panelu z etykietą „orkiestrator” w workspace „sh” działa proces
# claude remote-control z katalogiem roboczym $SH_DIR. Panel, argv, cwd i PID daje herdr
# (pane process-info), więc wynik nie zależy od tego, kto pyta. Bez pgrep: pgrep na macOS
# pomija przodków wywołującego, więc shctl doctor uruchomiony z sesji orkiestratora (potomka
# claude remote-control) nie widział go wcale.
#
# Wymaga herdr, jq i perl. Każde wywołanie herdr ma limit SH_HERDR_TIMEOUT (domyślnie 30 s).
# Bash 3.2, działa pod set -Eeuo pipefail i bez niego (funkcje nie kończą się błędem).
# shellcheck shell=bash

ORK_WS="${SH_ORK_WS:-sh}"
ORK_ETYKIETA=orkiestrator

# launchd daje minimalny PATH (/usr/bin:/bin). Brakujące katalogi narzędzi dopisujemy na końcu,
# więc PATH wywołującego (np. atrapy w testach) zachowuje pierwszeństwo.
sh_uzupelnij_path() {
  local d
  for d in "${SH_DIR:-$HOME/sh}/bin" "$HOME/.local/bin" /opt/homebrew/bin /usr/local/bin \
    "$HOME/.docker/bin" /usr/bin /bin /usr/sbin /sbin; do
    case ":${PATH:-}:" in
      *":$d:"*) ;;
      *) if [ -d "$d" ]; then PATH="${PATH:+$PATH:}$d"; fi ;;
    esac
  done
  export PATH
}

ork_herdr() {
  perl -e 'alarm shift; exec @ARGV or exit 127' "${SH_HERDR_TIMEOUT:-30}" herdr "$@"
}

# $SH_DIR w postaci fizycznej (bez dowiązań); lsof i herdr podają cwd po rozwiązaniu.
ork_katalog_fizyczny() {
  (cd "$SH_DIR" 2>/dev/null && pwd -P) || printf '%s' "$SH_DIR"
}

# ID panelu orkiestratora. Pusto, gdy herdr nie odpowiada albo nie ma workspace lub panelu.
ork_panel() {
  local ws
  ws="$(ork_herdr workspace list 2>/dev/null | jq -r --arg l "${1:-$ORK_WS}" \
    '[.result.workspaces[]? | select(.label == $l)][0].workspace_id // empty' 2>/dev/null)" || ws=""
  [ -n "$ws" ] || return 0
  ork_herdr pane list --workspace "$ws" 2>/dev/null | jq -r --arg l "$ORK_ETYKIETA" \
    '[.result.panes[]? | select(.label == $l)][0].pane_id // empty' 2>/dev/null || true
}

# PID orkiestratora albo pusto. Argument: ID panelu; bez niego panel szuka ork_panel.
orkiestrator_pid() {
  local panel="${1:-}"
  [ -n "$panel" ] || panel="$(ork_panel)"
  [ -n "$panel" ] || return 0
  ork_herdr pane process-info --pane "$panel" 2>/dev/null |
    jq -r --arg d "$SH_DIR" --arg p "$(ork_katalog_fizyczny)" '
      [.result.process_info.foreground_processes[]?
       | select((.argv // (.cmdline // "" | split(" "))) as $a
           | ($a | length) > 1
             and ($a[0] | test("(^|/)claude$"))
             and any($a[1:][]; . == "remote-control"))
       | select(.cwd == $d or .cwd == $p)
       | .pid // empty][0] // empty' 2>/dev/null || true
}

orkiestrator_dziala() {
  [ -n "$(orkiestrator_pid "${1:-}")" ]
}

# PID claude remote-control z cwd $SH_DIR spoza panelu orkiestratora (pusto, gdy brak). Taki proces
# blokuje start drugiej instancji. ps -ax zamiast pgrep: obejmuje też przodków wywołującego.
# Argument: PID do pominięcia (orkiestrator z panelu).
ork_pid_poza_panelem() {
  local pomin="${1:-}" pid cwd d p
  command -v lsof >/dev/null 2>&1 || return 0
  d="$SH_DIR"
  p="$(ork_katalog_fizyczny)"
  for pid in $(ps -axo pid=,args= 2>/dev/null |
    awk '$2 ~ /(^|\/)claude$/ && $3 == "remote-control" { print $1 }' || true); do
    [ "$pid" != "$pomin" ] || continue
    cwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' || true)"
    if [ "$cwd" = "$d" ] || [ "$cwd" = "$p" ]; then
      printf '%s' "$pid"
      return 0
    fi
  done
  return 0
}

# PATH z początkowego środowiska procesu (ps eww, ten sam użytkownik). Wartość kończy się przed
# następnym „ NAZWA=”, więc katalogi ze spacją zostają całe. Powłoka logowania (-zsh) środowiska
# nie pokazuje, dlatego czytamy proces orkiestratora, a nie powłokę panelu.
ork_path_procesu() {
  ps eww -o command= -p "$1" 2>/dev/null | head -n 1 |
    sed -n 's/.* PATH=//p' | sed 's/ [A-Za-z_][A-Za-z0-9_]*=.*//' || true
}
