# Decyzje systemu

Decyzje dotyczące całego software house'u: data, pytanie, decyzja.

| Data | Pytanie | Decyzja |
|---|---|---|
| 2026-11-01 | Organizacja GitHub: gdzie powstają projekty? | Wszystko (sh-system, szablon, projekty) na koncie Sebastian-Temich. |
| 2026-11-01 | Czy `supabase-local` wlicza się do limitu stacków? | `supabase-local` to stary system i nie wlicza się do limitu. Limit: 1 stack projektów SH naraz. Właściciel może zatrzymać `supabase-local` na czas pilota. |
| 2026-11-01 | Co po wyczerpaniu puli bloków portów? | Najpierw zwalniamy bloki projektów archiwalnych (`shctl ports release`); po wyczerpaniu puli kolejny zakres 56X21–56X29. |
| 2026-11-01 | Które miejsce jest źródłem skryptów i jak trafiają na serwer? | Źródłem jest repo sh-system. `~/sh/bin` zawiera symlinki do `scripts/server/` i `scripts/shctl/`, zakładane przez `scripts/server/install.sh`. |
| 2026-11-01 | Czy izolacja obowiązuje także Codexa? | Tak. Brak blokady odczytu w Codexie to znane ograniczenie, akceptowane w etapie A (Codex tylko robi review). |
| 2026-11-01 | Czy blokada profili dotyczy innych przeglądarek niż Chrome i Safari? | Obejmuje profile wszystkich zainstalowanych przeglądarek; brakujące ścieżki są w deny w `~/.claude/settings.json`. |
| 2026-11-01 | Kto i kiedy potwierdza brak kluczy produkcyjnych w zasięgu agentów? | Właściciel z agentem w zadaniu A1.6 (krok 4). To warunek startu A5.1. |
| 2026-11-01 | Czy agent review ma widzieć `.env.local` w worktree? | Nie. Główną ochroną jest czysty worktree bez plików env; profil reviewer Claude ma deny na `.env*` jako dodatkową warstwę. `.env.local` zawiera tylko klucze testowe. |
| 2026-11-01 | Jaka jest domyślna wartość `auto_merge_S` i czy działa w etapie A? | Domyślnie `false`. Działa w etapie A; włączamy go po kilku udanych zleceniach S. |
| 2026-11-01 | Co z gotowymi PR po wyczerpaniu limitu Codexa? | PR czekają w `status:review`, Claude bierze kolejne zadania, ale dispatch staje, gdy na review czeka `max_review_queue` PR (domyślnie 3, w `konfiguracja.md`). |
| 2026-11-01 | Czy „iteracja od nowa” po limicie podbija licznik? | Nie. Przerwanie przez limit nie podbija licznika iteracji; podbija go tylko FAIL review. |
| 2026-11-01 | Kto daje PASS w `DoD.md` etapów dokumentowych? | Dokumenty etapu powstają na gałęzi `stage/ETAP` i przez PR; review robi Codex (`sh-review`, tryb etapu), akceptację w checkpointach daje właściciel; potem merge. |
| 2026-11-01 | Która numeracja trafia do pola `etap` i gdzie zapisywać etapy trybów? | Pole `etap` = nazwa folderu. Tryb M: Specyfikacja → `00-intake`; Architektura i plan → `04-architektura`, `05-plan`, `06-zadania`; Realizacja → `07-realizacja`; QA → `08-qa`; Odbiór i dokumentacja → `wydanie`. Tryb S nie ma DoD etapów (DoD to issue i checklista PR). |
| 2026-11-01 | Gdzie jest changelog projektu i kto go aktualizuje? | `CHANGELOG.md` w katalogu głównym repo; plik wspólny aktualizowany przez orkiestratora w `shctl task close`. |
| 2026-11-01 | Kiedy używać `status:blocked`? | Gdy zadanie czeka na coś zewnętrznego, co nie jest eskalacją (limit, zablokowana zależność, brak miejsca na dysku). `done` = zamknięte issue bez etykiety. W DoD etapu nie używamy `blocked` (`in-progress` + notatka). |
| 2026-11-01 | Kto i jak zapisuje propozycje zmian systemu? | Worker zapisuje je w raporcie (sekcja „Propozycje dla systemu”); orkiestrator zbiera je do `sh-system/docs/propozycje.md` przez PR do sh-system; retro decyduje. |
| 2026-11-01 | Czy Claude Code czyta `AGENTS.md`, czy projekt ma też `CLAUDE.md`? | Jeden plik `AGENTS.md`; `CLAUDE.md` tylko importuje `AGENTS.md` i dodaje krótkie wskazówki dla Claude. |
| 2026-11-01 | Jak reviewer ma pracować bez sekretów, skoro Codex nie ma blokady odczytu? | `shctl review run` tworzy osobny, czysty worktree `../wt/review-NR` bez plików env. Reviewer (Codex) pracuje tylko na kodzie i diffie, testy uruchamia CI. To główna ochrona; deny na `.env*` dla Claude zostaje jako dodatkowa warstwa. |
| 2026-11-01 | Jak potwierdzamy gotowość do pilota, skoro A1.6 i A5.1 nie są nigdzie zdefiniowane? | Sekcja „Warunki startu pilota” w `proces-v1.md`: lista kontrolna, którą właściciel potwierdza przed pierwszym uruchomieniem projektu wzorcowego. Zastępuje odwołania do A1.6 i A5.1. |
| 2026-11-01 | Kto przegląda propozycje z `docs/propozycje.md`, skoro retro jako skill jest w etapie B? | W etapie A właściciel w retro pilota (prompt ręczny), od etapu B skill `sh-retro`. |
| 2026-11-01 | Co jest źródłem `Brewfile` i plist LaunchAgentów? | Repo sh-system. `~/sh/Brewfile` to symlink; `install.sh` kopiuje plisty do `~/Library/LaunchAgents` tylko przy różnicy i przeładowuje agenta. |
| 2026-11-01 | Co odbiera „wznów” po STOP? | Nowa sesja orkiestratora: właściciel uruchamia ją (`sh-start.sh` albo `claude` w panelu) i pisze „wznów”; orkiestrator odtwarza stan ze `status.md` i `~/sh/stan/NAZWA.json`. shctl nie wznawia sam. |
| 2026-11-01 | Jak chronić produkcję, skoro GitHub nie oferuje wymaganej akceptacji w repo prywatnych bez Enterprise, a agenci używają tokenu właściciela? | Na serwerze i w GitHub Secrets nie ma poświadczeń produkcyjnych. Wdrożenie prod wykonuje wyłącznie właściciel ze swojego urządzenia (`scripts/deploy-prod.sh`), a `deploy-prod.yml` jest zablokowany. W pilocie nie ma deployów prod. |
