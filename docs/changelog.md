# Changelog

## 2026-11-02

- Skille `sh-zadania` (plik `docs/06-zadania/zadania.yaml` na `stage/06-zadania`, review etapu, potem `shctl task create` na `main` i tabela dla właściciela; szkielet jako `T1`) i `sh-worker` (jedno issue w `~/sh/wt/NAZWA/NR`, testy, PR „Closes #NR”, raport `T-NR.md` z sekcją „Ryzyka”, iteracja 2+ tylko zgłoszenia z review). `docs/propozycje.md`: luki profilu workera (`.env.example`, `supabase init`).
- `sh-intake`: historyjki z Given/When/Then i priorytetem, typy projektu z konsekwencjami, stack z alternatywą, szacunek poglądowy, zlecenie na tryb L, stack w `AGENTS.md` po akceptacji. `sh-architekt`: środowiska i droga na produkcję, migracje zgodne wstecz, zadania właściciela (konta, DNS, `STAGING_DB_URL`, zmienne prod), dokumentacja wydania jako ostatnie zadanie. `docs/propozycje.md`: „shctl cykl new” na etap B.
- Skille `sh-intake` (specyfikacja trybu M, zlecenie trybu S przez `shctl task create`) i `sh-architekt` (architektura, ADR, plan kamieni jako pionowych przekrojów, scenariusze odbioru, zakres autoryzacji, `shctl doctor`); źródła: skille briefu, wymagań i planowania z `zrodla/skille-istniejace/`.
- `proces-v1.md`: rejestr autoryzacji w `decyzje.md` (`shctl decision add --rola wlasciciel`), automatyczny start kolejnego kamienia milowego z zatwierdzonego planu, `shctl doctor` przed pierwszym dispatchem projektu, AI przetwarzające dane i RLS wśród obszarów ryzyka.
- Plugin `software-house` (`plugin/`) z lokalnym marketplace `sh-system` (`.claude-plugin/marketplace.json`), kontrakt `SKILL.md`, szablon skilla i `scripts/plugin/sprawdz-skille.sh` w CI.
- `templates/review.md`: format wyniku review z wagami 🔴🟡⚪; shctl czyta też komentarze review pisane ręcznie.
- `shctl` część 2: `task create|ready|dispatch|iter|close|resume-check`, `review run`, `reset-dryrun`, testy bats ze stanowymi atrapami, test e2e `task-e2e.bats`.
- Tymczasowy prompt review `codex/sh-review-tymczasowy.md` i schemat odpowiedzi `codex/sh-review.schema.json`.
- `stop-all` zachowuje mapę zadań w `~/sh/stan/NAZWA.json`.
- Worktree w `~/sh/wt/NAZWA/` (osobno dla projektu), zaufanie folderu Claude Code w `task dispatch`, profil Codex `reviewer` linkowany przez `install.sh`, opis formatu `~/sh/limity.md`.

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
- Test na GitHubie tylko za zgodą właściciela, repo `sh-test-RRRRMMDD-HHMM`, lista `~/sh/stan/do-usuniecia.md` w `shctl doctor`.
- `shctl doctor` sprawdza repo z `do-usuniecia.md` i zdejmuje te, których już nie ma.
