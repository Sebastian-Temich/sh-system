# Plugin software-house

Skille procesu AI Software House (`docs/proces.md`) dla Claude Code. Mechanikę wykonuje
`shctl` (`docs/shctl.md`), a skille decydują i piszą treść.

| Plik | Zawartość |
|---|---|
| `.claude-plugin/plugin.json` | Manifest pluginu |
| `skills/_kontrakt.md` | Obowiązkowe sekcje każdego `SKILL.md` |
| `skills/sh-*/SKILL.md` | Skille ról |
| `skills/techniczne/sh-*/SKILL.md` | Skille techniczne workera i review (bazowe, kategorie, stacki) |
| `warstwy-skilli.yaml` | Mapa warstw: które skille techniczne dostaje worker zadania |

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
./plugin` przechodzą.

## Nowy skill

1. Skopiuj katalog podobnego skilla do `skills/sh-ROLA/`.
2. Wypełnij według `skills/_kontrakt.md`.
3. Uruchom `scripts/plugin/sprawdz-skille.sh` (działa też w CI).
4. `sh-review` jest też promptem `shctl review run` dla Claude i Codexa: shctl czyta skill przy każdym
   review (bez generowanej kopii), więc zmiana skilla działa od razu po `git pull`.
   Skill pisz bez funkcji jednego narzędzia: czytanie plików, `git`, `gh`.

Skill techniczny: kopia podobnego z `skills/techniczne/`, kontrakt w `_kontrakt.md` („Skille
techniczne”: do 150 linii, lista kontrolna z wagami, sandbox, błędy z projektów), wpis w
`warstwy-skilli.yaml`, gdy nazwa nie wynika z konwencji `sh-kat-KATEGORIA` albo `sh-stack-STACK`.

`_kontrakt.md` nie jest skillem, bo nie leży w osobnym katalogu (Claude Code ładuje tylko
`skills/NAZWA/SKILL.md`).
