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
