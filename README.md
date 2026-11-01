# sh-system

Centralne repozytorium software house'u prowadzonego przez agentów AI.

| Katalog | Zawartość |
|---|---|
| `docs/` | Proces (`proces-v1.md`), decyzje systemu, changelog i opis serwera (`serwer.md`) |
| `plugin/` | Przyszły plugin Claude Code `software-house` |
| `codex/` | Konfiguracja i prompty Codex |
| `templates/` | Wspólne szablony |
| `scripts/server/` | Skrypty serwera, plist LaunchAgenta i Brewfile |
| `scripts/shctl/` | Narzędzie `shctl` |
| `zrodla/skille-istniejace/` | Istniejące skille jako materiał źródłowy |

Repo jest źródłem skryptów: `~/sh/bin` zawiera symlinki do `scripts/server/` i `scripts/shctl/`,
zakładane przez `scripts/server/install.sh`. `Brewfile` i plist LaunchAgenta to kopie plików z `~/sh`
i `~/Library/LaunchAgents`, bez automatycznej synchronizacji.
