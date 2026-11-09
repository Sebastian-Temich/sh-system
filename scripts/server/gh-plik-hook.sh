#!/usr/bin/env bash
# /Users/Shared/sh/bin/gh-plik-hook.sh - hook PreToolUse (Bash) orkiestratora i workera: pliki tresci gh.
#
#   gh-plik-hook.sh     (JSON hooka na stdin, matcher "Bash")
#
# gh dziala poza sandboxem (token w pęku kluczy), wiec plik podany jako tresc PR, issue, komentarza albo
# wydania (--body-file, -F, --notes-file, takze w formie --opcja=PLIK) moglby wyslac na GitHub plik spoza
# SH. Dozwolone: stdin ("-") i sciezki, ktore po rozwinieciu ~, wzgledem cwd hooka, po ".." i
# dowiazaniach leza w /Users/Shared/sh/ (SH_DIR). Kazda inna: "deny". Dotyczy gh pr, gh issue i
# gh release (gh api -F to pole, blokuje je lista deny). Komenda dzielona jak w powloce (shlex), takze
# czesci laczone ; && || |. Fail-closed: brak jq albo python3, bledny JSON: kod 2.
set -uo pipefail

SH_DIR="${SH_DIR:-/Users/Shared/sh}"
blad() { printf 'gh-plik-hook.sh: %s; narzedzie zablokowane\n' "$1" >&2; exit 2; }
command -v jq >/dev/null || blad 'brak jq'
command -v python3 >/dev/null || blad 'brak python3'
WEJSCIE="$(cat)"
printf '%s' "$WEJSCIE" | jq -e 'type == "object"' >/dev/null 2>&1 || blad 'wejscie hooka nie jest obiektem JSON'
[ "$(printf '%s' "$WEJSCIE" | jq -r '.tool_name // ""')" = Bash ] || exit 0
KOMENDA="$(printf '%s' "$WEJSCIE" | jq -r '.tool_input.command // ""')"
CWD="$(printf '%s' "$WEJSCIE" | jq -r '.cwd // ""')"
case "$KOMENDA" in *gh*) ;; *) exit 0 ;; esac

ZLA="$(SH_DIR="$SH_DIR" CWD="$CWD" KOMENDA="$KOMENDA" python3 -I -c '
import os, shlex, sys
sh = os.path.realpath(os.environ["SH_DIR"]) + "/"
cwd = os.environ["CWD"] or "/"
try:
    lex = shlex.shlex(os.environ["KOMENDA"], posix=True, punctuation_chars=";&|()<>")
    lex.whitespace_split = True
    slowa = list(lex)
except ValueError:
    print("<nie da sie sparsowac komendy>"); sys.exit(0)
czesci, b = [], []
for s in slowa:
    if s and all(c in ";&|()<>" for c in s):
        czesci.append(b); b = []
    else:
        b.append(s)
czesci.append(b)
OPCJE = ("--body-file", "-F", "--notes-file")
for c in czesci:
    while c and "=" in c[0] and not c[0].startswith("-"):
        c = c[1:]
    if len(c) < 2 or os.path.basename(c[0]) != "gh" or c[1] not in ("pr", "issue", "release"):
        continue
    i = 2
    while i < len(c):
        s, w = c[i], None
        if s in OPCJE and i + 1 < len(c):
            w = c[i + 1]; i += 1
        else:
            for o in ("--body-file=", "--notes-file=", "-F="):
                if s.startswith(o):
                    w = s[len(o):]
            if w is None and s.startswith("-F") and len(s) > 2 and not s.startswith("--"):
                w = s[2:]
        i += 1
        if w is None or w == "-":
            continue
        p = os.path.realpath(os.path.join(cwd, os.path.expanduser(w)))
        if not p.startswith(sh):
            print(w); sys.exit(0)
')" || blad 'blad analizy komendy'

[ -z "$ZLA" ] && exit 0
jq -nc --arg p "Plik tresci gh poza /Users/Shared/sh: $ZLA. gh dziala poza sandboxem; tresc PR, issue i komentarzy bierz z pliku w repo albo worktree (albo z stdin: --body-file -)." \
  '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:$p}}'
exit 0
