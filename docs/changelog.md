# Changelog

## 2026-11-01

- Utworzenie repozytorium i struktury katalogów.
- Import skryptów serwera, Brewfile i dokumentacji serwera z `~/sh`.
- Rozstrzygnięcie 18 otwartych pytań procesu v1 (`decyzje-systemu.md`).
- `~/sh/bin` jako symlinki do repo, `scripts/server/install.sh`.
- Review w czystym worktree bez plików env, warunki startu pilota, retro propozycji w etapie A.
- Flaga `~/sh/stan/autostart.off` wstrzymuje ładowanie `sh-start` w `install.sh` i start przez
  launchd w `sh-start.sh --autostart`.
- `install.sh` ładuje niezaładowanych agentów; test `scripts/server/tests/install.bats`.
- Repo jako źródło `Brewfile` i plist, ostrzeżenie w `backup-config.sh` o zmianach w `sh-system`.
- Produkcja bez poświadczeń na serwerze i w GitHub Secrets; wdraża wyłącznie właściciel.
- Warunki startu pilota: wylogowane Supabase CLI i Vercel CLI, deny jako zabezpieczenie przed pomyłką.
- Bloki `tylko-tryb:L` w DoD, czysty worktree jako główna ochrona `.env*`, nowe punkty etapu B.
- Sekcja „Droga na produkcję”, punkt „migracje zgodne wstecz” w DoD zadania, środowisko STAGING.
- Gałąź produkcyjna `production`, granica bezpieczeństwa, ponowienie wydania z `--tylko-aplikacja`.
- Globalny hook `pre-push` blokuje push na `production`, wrappery zachowują hooki projektów.
- Workflow `test.yml` uruchamia testy bats na ubuntu-24.04, testy z `plutil` są pomijane poza macOS.
- Wrapper hooków wywołuje też `.githooks/`, `SH_BEZ_HOOKOW_REPO` pomija je przy nieprzejrzanym kodzie.
- Wymagania `shctl doctor` i `shctl review run`, ostrzeżenie `install.sh` obejmuje `~/sh/projekty`.
- Projekty SH bez hooków git: wrapper nie woła `.githooks/`, `SH_BEZ_HOOKOW_REPO` usunięte, kontrole w CI.
- `shctl` część 1 (`scripts/shctl/`, `docs/shctl.md`): new-project, stage, doc, decision, escalate, ports, status, stop-all, doctor, testy bats.
- `shctl obsidian link|unlink`, lekki klon `docs/` w vaulcie, kontrola klonów w `doctor`, `~/.config/sh/config`, kolejność w `stop-all --dry-run`.
- Model reviewera Codex: `proces-v1.md` odsyła do `docs/konfiguracja.md`, wartość ustawia szablon.
- Zasada pracy nad systemem: gałąź i PR, merge po zielonym CI, zgoda właściciela przy bezpieczeństwie, dostępach i produkcji.
- `shctl new-project` włącza usuwanie gałęzi po merge'u.
