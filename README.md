# sh-system

Centralne repozytorium software house'u prowadzonego przez agentów AI.

| Katalog | Zawartość |
|---|---|
| `docs/` | Proces (`proces-v1.md`), decyzje systemu, changelog i opis serwera (`serwer.md`) |
| `docs/podrecznik/` | Podręcznik właściciela (start: `00-start-tutaj.md`) |
| `plugin/` | Plugin Claude Code `software-house`: kontrakt i szablon skilli (`plugin/README.md`) |
| `.claude-plugin/` | Lokalny marketplace `sh-system` z pluginem `software-house` |
| `codex/` | Profil Codexa `reviewer.config.toml` dla `shctl review run` |
| `templates/` | Wspólne szablony, m.in. format wyniku review (`review.md`) |
| `scripts/server/` | Skrypty serwera (m.in. strażnik orkiestratora `sh-watchdog.sh` i `obsidian-sync.sh`), plisty LaunchAgentów i Brewfile |
| `scripts/shctl/` | Narzędzie `shctl` |
| `scripts/plugin/` | `sprawdz-skille.sh`: zgodność skilli z kontraktem |
| `scripts/docs/` | `sprawdz-podrecznik.sh`: komendy `shctl` i skille z podręcznika istnieją (CI) |
| `scripts/ci/` | `zakres.sh`: które testy uruchamia CI (oszczędność minut, `docs/serwer.md`, „CI i minuty GitHub Actions”) |

Repo jest źródłem plików serwera. `scripts/server/install.sh` zakłada symlinki `/Users/Shared/sh/bin` i
`/Users/Shared/sh/Brewfile`, a plisty kopiuje do `~/Library/LaunchAgents` przy różnicy i przeładowuje agenta.

Plugin `software-house` instaluje się z lokalnego marketplace tego repo:

```sh
claude plugin marketplace add /Users/Shared/sh/sh-system
claude plugin install software-house@sh-system --scope user
```

Aktualizacja i kontrola listy skilli: `docs/serwer.md`, sekcja „Plugin software-house”.
