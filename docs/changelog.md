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
