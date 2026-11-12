# Sesje Claude Code w /Users/Shared/sh

Plik z repo `sh-system` (`scripts/server/CLAUDE-sh.md`), dowiązany przez `scripts/server/install.sh`
jako `/Users/Shared/sh/CLAUDE.md`. Zmiany tylko w repo, przez PR.

Ładuje go każda sesja z katalogiem startowym `/Users/Shared/sh`: orkiestrator (skill `sh-orkiestrator`)
i sesja buildera, która rozwija `sh-system` i `sh-template-projekt`.

## Komendy Bash

Sesja działa w sandboxie (`/Users/Shared/sh/.claude/settings.json`). Wyjątek sandboxa
(`sandbox.excludedCommands`: `gh`, `git push|fetch|pull`, `git worktree add|remove|prune` (także add bez `-b`), `shctl`,
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
| `git -C repo worktree add /Users/Shared/sh/wt-system/x x` | `cd repo` · `git worktree add /Users/Shared/sh/wt-system/x x` |

## Szkice opisów PR i komentarzy

Szkic opisu PR, issue albo komentarza piszesz w scratchpadzie sesji. `gh` działa poza sandboxem i
hook przyjmuje `--body-file` tylko spod `/Users/Shared/sh`, a wieloliniowe `--body` wypada z wyjątku
sandboxa (HTTP 401). Do wysłania kopiujesz szkic do `/Users/Shared/sh/wt-system/` (obok worktree, nie
do niego, żeby nie trafił do commita), wołasz `gh … --body-file` i **zaraz potem** usuwasz plik (`rm`).
W `wt-system/` i `wt/` zostają same worktree, bez luźnych `*.md`.

## Worktree

Worktree zakładasz zwykłym `git worktree add` z katalogu repo, tylko w `/Users/Shared/sh/wt/` i
`/Users/Shared/sh/wt-system/`. Obie formy działają poza sandboxem (wyjątek `git worktree add *`) i są
na liście dozwolonych:

- nowa gałąź: `git worktree add --no-track -b GAŁĄŹ /Users/Shared/sh/wt-system/x origin/main`;
- istniejąca gałąź (bez `-b`), np. po przerwanej próbie, która zdążyła założyć gałąź:
  `git worktree add /Users/Shared/sh/wt-system/x GAŁĄŹ`.

`--force`, `-f`, `-B` i `..` w ścieżce są zabronione. Gdy `git worktree add` mimo to kończy się
„Operation not permitted” na `.git/worktrees`, sesja nie ma wyjątku sandboxa: zatrzymaj się i podaj
właścicielowi komendę do uruchomienia w Terminalu (niżej), zamiast klonować repo obok.

## Komendy dla właściciela

Komenda z `!` w oknie sesji (np. `! git worktree add …`) działa w sandboxie tej sesji, z tymi samymi
ograniczeniami co Bash agenta. Polecenie, które potrzebuje pełnych uprawnień (`install.sh`, `sudo`,
`git worktree add` przy braku wyjątku, usunięcie repo), właściciel uruchamia w osobnym oknie Terminala.
Podajesz je jako gotowy blok z `cd` i komendą, bez `!`.

## Testy (bats) w sandboxie

`bats --recursive scripts` (albo jeden plik) uruchamiasz wprost, bez nakładek i obejść: bats bierze
katalog tymczasowy z `TMPDIR` (`BATS_TMPDIR`), który sandbox ustawia na dozwolony katalog
(`/tmp/claude-UID`). Nie ustawiaj `TMPDIR` ani `BATS_TMPDIR` ręcznie.

- W skryptach i testach plik tymczasowy zawsze z jawnym szablonem:
  `mktemp -d "${TMPDIR:-/tmp}/nazwa.XXXXXX"`. Samo `mktemp -d` na macOS ignoruje `TMPDIR`, pisze do
  `/var/folders` i w sandboxie kończy się „Operation not permitted”.
- Bez `<(...)` przekazywanego zewnętrznemu programowi (`diff <(…)`): `/dev/fd` jest w sandboxie
  niedostępne. Zapisz wynik do pliku tymczasowego.
- Testy nie wołają prawdziwego `claude`, `codex`, `gh` ani sieci: atrapy w `scripts/shctl/tests/atrapy/`
  i w `$T/mock` testu. `new-project-szablon.bats` w sandboxie jest pomijany, sprawdza go CI.
- Wynik testu w tle czytasz z pliku wyjścia po zakończeniu; długi zestaw dziel na pliki.
