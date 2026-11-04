# Plugin software-house

Skille procesu AI Software House v1 (`docs/proces-v1.md`) dla Claude Code. Mechanikę wykonuje
`shctl` (`docs/shctl.md`), a skille decydują i piszą treść.

| Plik | Zawartość |
|---|---|
| `.claude-plugin/plugin.json` | Manifest pluginu |
| `skills/_kontrakt.md` | Obowiązkowe sekcje każdego `SKILL.md` |
| `skills/_szablon/SKILL.md` | Szablon nowego skilla, zablokowany do wywołania |
| `skills/sh-*/SKILL.md` | Skille ról (powstają w kolejnych zadaniach) |

## Instalacja lokalna

Marketplace `sh-system` to plik `.claude-plugin/marketplace.json` w katalogu głównym repo:

```sh
claude plugin marketplace add /Users/Shared/sh/sh-system
claude plugin install software-house@sh-system
```

Marketplace dodany ze ścieżki lokalnej czyta pliki pluginu wprost z repo, więc zmiany działają od
następnej sesji albo po `/reload-plugins`, bez zmiany `version`. Skille wywołuje się jako
`/software-house:sh-ROLA`.

Sprawdzenie (2026-11-02, Claude Code 2.1.316): `claude plugin validate .` i `claude plugin validate
./plugin` przechodzą. Instalacja w odizolowanym `CLAUDE_CONFIG_DIR` pokazała 1 skill, `_szablon`.

## Nowy skill

1. Skopiuj `skills/_szablon/` do `skills/sh-ROLA/`.
2. Wypełnij według `skills/_kontrakt.md`; usuń z frontmattera dwie linie blokujące i komentarze HTML.
3. Uruchom `scripts/plugin/sprawdz-skille.sh` (działa też w CI).
4. Skill z promptem Codexa (dziś `sh-review`) po każdej zmianie: `scripts/sync-codex.sh`, a wynik
   `codex/sh-review.md` commituj razem ze skillem. CI sprawdza zgodność (`sync-codex.sh --check`).
   Skill pisz bez funkcji jednego narzędzia: czytanie plików, `git`, `gh`.

Claude Code ładuje każdy katalog `skills/NAZWA/SKILL.md`, także `_szablon`. Szablon ma
`disable-model-invocation: true` i `user-invocable: false`, więc nie uruchomi go ani model, ani
`/software-house:_szablon`, ale jego nazwa kosztuje ok. 40 tokenów w każdej sesji (`claude plugin
details software-house`). `_kontrakt.md` nie jest skillem, bo nie leży w osobnym katalogu.
