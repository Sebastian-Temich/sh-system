#!/usr/bin/env bash
# ~/sh/bin/backup-config.sh - archiwum konfiguracji agentow, bez sesji, cache i tokenow.
#
#   backup-config.sh [katalog_docelowy]     domyslnie ~/sh/backups
#
# Zawiera: ~/.claude (ustawienia, skille, lista pluginow, pamiec projektow),
# ~/.codex/config.toml, ~/.config/sh, ~/sh/bin, ~/sh/porty.md.
# Pomija: auth.json, .credentials.json, ~/.claude.json i jego kopie (backups/), historie,
# sesje, cache. Gdy gitleaks znajdzie sekret, archiwum jest kasowane (kod wyjscia 1).
set -euo pipefail

DEST=${1:-$HOME/sh/backups}
STAMP=$(date +%Y%m%d-%H%M%S)
ARCHIVE="$DEST/config-$STAMP.tar.gz"

log() { printf 'backup-config: %s\n' "$*"; }
die() { printf 'backup-config: BLAD: %s\n' "$*" >&2; exit 1; }

# Archiwum zawiera m.in. temat ntfy, wiec tylko dla wlasciciela.
umask 077
command -v gitleaks >/dev/null || die 'brak gitleaks w PATH (nie da sie sprawdzic archiwum)'
mkdir -p "$DEST"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
LIST="$WORK/lista"

cd "$HOME"
find .claude \( \
    -path .claude/backups -o -path .claude/bridge-spawn -o -path .claude/cache \
    -o -path .claude/chrome -o -path .claude/downloads -o -path .claude/file-history \
    -o -path .claude/paste-cache -o -path .claude/projects -o -path .claude/session-env \
    -o -path .claude/sessions -o -path .claude/shell-snapshots -o -path .claude/state \
    -o -path .claude/plugins/.trash -o -path .claude/plugins/cache \
    -o -path .claude/plugins/data -o -path .claude/plugins/marketplaces \
    -o -path .claude/plugins/store -o -path .claude/plugins/synced \
    -o -name node_modules -o -name .git \
  \) -prune -o \( -type f -o -type l \) \
  ! -name history.jsonl ! -name mcp-needs-auth-cache.json \
  ! -name plugin-directory-cache-v2.json ! -name .DS_Store -print >"$LIST"

# Z projektow tylko pamiec, bez transkryptow sesji.
find .claude/projects -type f -path '*/memory/*' -print >>"$LIST" 2>/dev/null || true

for path in .codex/config.toml .config/sh sh/bin sh/porty.md; do
  [ -e "$path" ] || { log "UWAGA: brak $path, pomijam"; continue; }
  find "$path" \( -type f -o -type l \) ! -name .DS_Store -print >>"$LIST"
done

# Bezpiecznik na pliki z poswiadczeniami, takze gdyby pojawily sie w nowych miejscach.
SKIP='(^|/)(auth\.json|\.credentials\.json|\.claude\.json[^/]*|credentials[^/]*|id_[^/]*|\.env[^/]*|[^/]*\.(pem|key|p12|pfx))$'
grep -Ev "$SKIP" "$LIST" >"$LIST.ok" || die 'pusta lista plikow'

tar -czf "$ARCHIVE" -T "$LIST.ok"

mkdir "$WORK/spr"
tar -xzf "$ARCHIVE" -C "$WORK/spr"
if ! gitleaks dir "$WORK/spr" --no-banner --redact --log-level error --exit-code 2 \
  --report-format json --report-path "$WORK/raport.json"; then
  jq -r '.[] | "  \(.RuleID): \(.File | sub("^.*/spr/"; ""))"' "$WORK/raport.json" >&2 || true
  rm -f "$ARCHIVE"
  die 'gitleaks znalazl sekrety, archiwum skasowane'
fi

log "$ARCHIVE ($(wc -l <"$LIST.ok" | tr -d ' ') plikow, $(du -h "$ARCHIVE" | cut -f1))"
