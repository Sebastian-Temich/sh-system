#!/usr/bin/env bash
# /Users/Shared/sh/bin/setup-toolchain.sh - idempotentna instalacja toolchainu serwera (macOS Intel).
#
# Doinstalowuje tylko to, czego brakuje. Nie uzywa sudo. Nie dotyka Claude Code, Codex CLI,
# Docker Desktop, Supabase ani nvm. Bezpieczny do wielokrotnego uruchamiania.
# Wersje i sumy SHA-256 sa przypiete; zmiana wersji = zmiana tej tabeli.
set -euo pipefail

YQ_VERSION=4.54.1
YQ_SHA256=3a812fce205a4d67014fb71b7fa297092210e580df3d8f52dddc2cf3a599c22b
GITLEAKS_VERSION=8.30.1
GITLEAKS_SHA256=dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709
UV_VERSION=0.13.6
UV_SHA256=63ba17fdda55ad1a230d4b37fc6017ffa10c23688c83818bd3bfdf914c652a02
FNM_VERSION=1.39.0
FNM_SHA256=f046483e85c53b3278efe49a3620c8680f22efa58a8dabfd03eafc6b59b31a25
BATS_VERSION=1.14.0
BATS_SHA256=bb537b70b15b732f6d8827dd6578e3d8ce166636ce1f18ea9a074184fcce9177
HERDR_VERSION=0.9.5
HERDR_SHA256=5fb0a908ec7f6745e3e245738b06bfad56c46391c391ab3c0955fbead01f1369
PNPM_VERSION=12.16.1
COREPACK_VERSION=0.36.0
PLAYWRIGHT_VERSION=1.61.1  # NIE podnosic: WebKit dla mac14 jest zamrozony, >=1.62 pada na PushAPIEnabled
PUPPETEER_BROWSERS_VERSION=3.2.6
MIN_GIT=2.30.0

SH_DIR="/Users/Shared/sh"
BIN_DIR="$HOME/.local/bin"
BROWSERS_DIR="$SH_DIR/browsers"
ZSHRC="$HOME/.zshrc"
FNM_MARK_BEGIN='# >>> fnm (~/sh toolchain) >>>'
FNM_MARK_END='# <<< fnm (~/sh toolchain) <<<'

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'UWAGA: %s\n' "$*" >&2; }

[[ "$(uname -s)" == Darwin ]] || { echo 'Tylko macOS.' >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || { echo 'Nie uruchamiaj jako root.' >&2; exit 1; }

mkdir -p "$BIN_DIR" "$BROWSERS_DIR"
export PATH="$BIN_DIR:$PATH"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# download URL SHA256 CEL - pobiera i weryfikuje sume, przy niezgodnosci przerywa.
download() {
  curl -fsSL --retry 3 -o "$3" "$1"
  echo "$2  $3" | shasum -a 256 -c --status || { echo "Zla suma SHA-256: $1" >&2; exit 1; }
}

need() { ! command -v "$1" >/dev/null 2>&1; }

install_yq() {
  need yq || { log "yq jest: $(yq --version)"; return 0; }
  log "Instaluje yq $YQ_VERSION"
  download "https://github.com/mikefarah/yq/releases/download/v$YQ_VERSION/yq_darwin_amd64" \
    "$YQ_SHA256" "$WORK/yq"
  install -m 755 "$WORK/yq" "$BIN_DIR/yq"
}

install_gitleaks() {
  need gitleaks || { log "gitleaks jest: $(gitleaks version)"; return 0; }
  log "Instaluje gitleaks $GITLEAKS_VERSION"
  local d="$WORK/gitleaks"; mkdir -p "$d"
  download "https://github.com/gitleaks/gitleaks/releases/download/v$GITLEAKS_VERSION/gitleaks_${GITLEAKS_VERSION}_darwin_x64.tar.gz" \
    "$GITLEAKS_SHA256" "$d/a.tgz"
  tar -xzf "$d/a.tgz" -C "$d" gitleaks
  install -m 755 "$d/gitleaks" "$BIN_DIR/gitleaks"
}

install_uv() {
  need uv || { log "uv jest: $(uv --version)"; return 0; }
  log "Instaluje uv $UV_VERSION"
  local d="$WORK/uv"; mkdir -p "$d"
  download "https://github.com/astral-sh/uv/releases/download/$UV_VERSION/uv-x86_64-apple-darwin.tar.gz" \
    "$UV_SHA256" "$d/a.tgz"
  tar -xzf "$d/a.tgz" -C "$d" --strip-components=1
  install -m 755 "$d/uv" "$d/uvx" "$BIN_DIR/"
}

install_fnm() {
  need fnm || { log "fnm jest: $(fnm --version)"; return 0; }
  log "Instaluje fnm $FNM_VERSION"
  local d="$WORK/fnm"; mkdir -p "$d"
  download "https://github.com/Schniz/fnm/releases/download/v$FNM_VERSION/fnm-macos.zip" \
    "$FNM_SHA256" "$d/a.zip"
  unzip -q -o "$d/a.zip" -d "$d"
  install -m 755 "$d/fnm" "$BIN_DIR/fnm"
}

install_bats() {
  need bats || { log "bats jest: $(bats --version)"; return 0; }
  log "Instaluje bats-core $BATS_VERSION"
  local d="$WORK/bats"; mkdir -p "$d"
  download "https://github.com/bats-core/bats-core/archive/refs/tags/v$BATS_VERSION.tar.gz" \
    "$BATS_SHA256" "$d/a.tgz"
  tar -xzf "$d/a.tgz" -C "$d" --strip-components=1
  bash "$d/install.sh" "$HOME/.local" >/dev/null
}

install_herdr() {
  need herdr || { log "herdr jest: $(herdr --version)"; return 0; }
  log "Instaluje herdr $HERDR_VERSION"
  download "https://github.com/herdrdev/herdr/releases/download/v$HERDR_VERSION/herdr-macos-x86_64" \
    "$HERDR_SHA256" "$WORK/herdr"
  install -m 755 "$WORK/herdr" "$BIN_DIR/herdr"
}

configure_zshrc() {
  if grep -qF "$FNM_MARK_BEGIN" "$ZSHRC" 2>/dev/null; then
    log 'Blok fnm w ~/.zshrc jest'
    return 0
  fi
  log 'Dopisuje blok fnm do ~/.zshrc (kopia: ~/.zshrc.bak-toolchain)'
  [[ -e "$HOME/.zshrc.bak-toolchain" ]] || cp "$ZSHRC" "$HOME/.zshrc.bak-toolchain"
  cat >>"$ZSHRC" <<EOF

$FNM_MARK_BEGIN
# Na koncu pliku, zeby wygrac z nvm w nowych powlokach. nvm zostaje dla uslug na Node 24.
if command -v fnm >/dev/null 2>&1; then
  eval "\$(fnm env --use-on-cd --version-file-strategy=recursive --shell zsh)"
fi
$FNM_MARK_END
EOF
}

install_node() {
  eval "$(fnm env --shell bash)"
  # `fnm install --lts` pobiera tylko brakujaca wersje.
  fnm install --lts
  fnm default lts-latest
  fnm use default >/dev/null
  log "Node $(node --version), npm $(npm --version)"

  # Node 26 nie ma corepacka w dystrybucji. Szukamy go TYLKO obok aktywnego node;
  # `command -v` znalazloby kopie z nvm i shimy trafilyby do Node 24.
  local node_bin
  node_bin="$(dirname "$(command -v node)")"
  [[ -x "$node_bin/corepack" ]] || npm install -g "corepack@$COREPACK_VERSION"
  "$node_bin/corepack" enable --install-directory "$node_bin"
  if [[ "$(COREPACK_ENABLE_DOWNLOAD_PROMPT=0 pnpm --version 2>/dev/null)" != "$PNPM_VERSION" ]]; then
    COREPACK_ENABLE_DOWNLOAD_PROMPT=0 corepack prepare "pnpm@$PNPM_VERSION" --activate
  fi
  log "pnpm $(COREPACK_ENABLE_DOWNLOAD_PROMPT=0 pnpm --version)"
}

install_browsers() {
  log 'Przegladarki Playwrighta: chromium, webkit, firefox'
  (cd "$WORK" && npx --yes "playwright@$PLAYWRIGHT_VERSION" install chromium webkit firefox)

  if compgen -G "$BROWSERS_DIR/chrome/*/*/*Chrome*for*Testing.app" >/dev/null; then
    log 'Chrome for Testing jest'
  else
    log 'Chrome for Testing'
    (cd "$WORK" && npx --yes "@puppeteer/browsers@$PUPPETEER_BROWSERS_VERSION" install chrome@stable --path "$BROWSERS_DIR")
  fi
}

check_system() {
  local git_v
  git_v="$(git --version | awk '{print $3}')"
  if [[ "$(printf '%s\n%s\n' "$MIN_GIT" "$git_v" | sort -V | head -1)" != "$MIN_GIT" ]]; then
    warn "git $git_v < $MIN_GIT: pomijam Homebrew (kazde polecenie brew budowaloby gita ze zrodel)."
    warn 'Wlasciciel musi zaktualizowac CLT: patrz docs/serwer.md, „Ograniczenia tej maszyny”.'
    return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    log 'Sprawdzam Brewfile'
    HOMEBREW_NO_AUTO_UPDATE=1 brew bundle check --file "$SH_DIR/Brewfile" --no-upgrade ||
      warn 'Brewfile niespelniony: brew bundle install --file /Users/Shared/sh/Brewfile --no-upgrade'
  fi
}

check_system
install_yq
install_gitleaks
install_uv
install_fnm
install_bats
install_herdr
configure_zshrc
install_node
install_browsers
log 'Gotowe.'
