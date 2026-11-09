# Sesje Claude Code w /Users/Shared/sh

Plik z repo `sh-system` (`scripts/server/CLAUDE-sh.md`), dowiązany przez `scripts/server/install.sh`
jako `/Users/Shared/sh/CLAUDE.md`. Zmiany tylko w repo, przez PR.

Ładuje go każda sesja z katalogiem startowym `/Users/Shared/sh`: orkiestrator (skill `sh-orkiestrator`)
i sesja buildera, która rozwija `sh-system` i `sh-template-projekt`.

## Komendy Bash

Sesja działa w sandboxie (`/Users/Shared/sh/.claude/settings.json`). Wyjątek sandboxa
(`sandbox.excludedCommands`: `gh`, `git push|fetch|pull`, `git worktree add|remove|prune`, `shctl`,
`herdr`, `notify.sh`) dostaje tylko prosta komenda pasująca do wzorca. Komenda złożona działa w całości
w sandboxie, bez tokenu GitHuba z pęku kluczy: `git push` pyta o login, `gh` daje HTTP 401.

- Jedna prosta komenda na jedno wywołanie: bez `&&`, `||`, `;`, potoków (`|`) i zmiennych przed komendą
  (`X=1 git push`).
- Przekierowanie do pliku (`komenda > plik`, `>>`, `2>`) też odbiera wyjątek sandboxa: `gh … > plik`
  kończy się HTTP 401. Wynik zawężasz przez `-q`/`--json` i czytasz z odpowiedzi; gdy musi trafić do
  pliku, zapisujesz go narzędziem Write.
- `cd KATALOG` to osobne wywołanie; Claude Code pamięta katalog do następnego. Potem zwykłe
  `git …` albo `gh …`, bez `git -C` przy zapisie i sieci (`git -C` tylko do lokalnego odczytu).
- Wynik filtrujesz flagą komendy (`gh … --json pola -q '.wyrażenie'`, `shctl … --json`), a nie potokiem.
- Niezależne komendy wysyłasz jako kilka wywołań w jednej odpowiedzi.

| Zamiast | Tak (osobne wywołania) |
|---|---|
| `cd /Users/Shared/sh/wt-system/x && git push` | `cd /Users/Shared/sh/wt-system/x` · `git push` |
| `gh issue view 54 --json body \| jq -r .body` | `gh issue view 54 -R Sebastian-Temich/sh-system --json body -q .body` |
| `GIT_TERMINAL_PROMPT=0 git push` | `git push` |
| `gh pr view 5 --json body > opis.md` | `gh pr view 5 --json body -q .body`, potem Write `opis.md` |
