# sh-system

Centralne repozytorium software house'u prowadzonego przez agentów AI.

| Katalog | Zawartość |
|---|---|
| `docs/` | Proces (`proces-v1.md`), decyzje systemu, changelog i opis serwera (`serwer.md`) |
| `plugin/` | Plugin Claude Code `software-house`: kontrakt i szablon skilli (`plugin/README.md`) |
| `.claude-plugin/` | Lokalny marketplace `sh-system` z pluginem `software-house` |
| `codex/` | Konfiguracja i prompty Codex; `sh-review.md` generuje `scripts/sync-codex.sh` ze skilla `sh-review` |
| `templates/` | Wspólne szablony, m.in. format wyniku review (`review.md`) |
| `scripts/server/` | Skrypty serwera, plist LaunchAgenta i Brewfile |
| `scripts/shctl/` | Narzędzie `shctl` |
| `scripts/plugin/` | `sprawdz-skille.sh`: zgodność skilli z kontraktem |
| `scripts/sync-codex.sh` | Prompty Codexa ze skilli; `--check` w CI (`scripts/tests/sync-codex.bats`) |
| `zrodla/skille-istniejace/` | Istniejące skille jako materiał źródłowy |

Repo jest źródłem plików serwera. `scripts/server/install.sh` zakłada symlinki `~/sh/bin` i
`~/sh/Brewfile`, a plisty kopiuje do `~/Library/LaunchAgents` przy różnicy i przeładowuje agenta.

Plugin `software-house` instaluje się z lokalnego marketplace tego repo:

```sh
claude plugin marketplace add ~/sh/sh-system
claude plugin install software-house@sh-system
```
