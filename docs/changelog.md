# Changelog

## 2026-11-03

- `shctl checkpoint 00-intake|04-architektura|wydanie|#NR`: po PASS review dla bieżącego commita `notify.sh high` „Czeka na Twoją akceptację: PROJEKT / ETAP” z linkiem do PR w `Click`; jedno powiadomienie na commit (`~/sh/stan/checkpointy/NAZWA`). `shctl escalate --akceptacja`: ten sam tytuł dla propozycji podniesienia trybu. `sh-orkiestrator` wywołuje je przy każdym checkpoincie właściciela (specyfikacja, architektura i plan, odbiór, odbiór S, podniesienie trybu).
- Skrzynka na materiały `Obsidian Vault/SH/Skrzynka/NAZWA` (zwykły folder, `obsidian sync` go nie dotyka), zakładana przez `new-project` i `obsidian link`. `shctl skrzynka przyjmij NAZWA [--etap ETAP/KATALOG]`: kontrola plików (bez dowiązań, pakietów aplikacji i plików wykonywalnych według rozszerzenia i nagłówka, do 50 MB), ZIP rozpakowany tylko po kontroli ścieżek, dowiązań i rozmiaru, commit w odłączonym worktree na `stage/ETAP`, PR, a po merge'u przeniesienie do `_przeniesione/RRRRMMDD/`. `sh-orkiestrator`: polecenie „materiały w skrzynce”.
- Podręcznik: powiadomienia o akceptacjach i skrzynka zamiast opisu obu luk.
- Decyzja właściciela (`decyzje-systemu.md`): PR ze skrzynki orkiestrator merguje po zielonym CI bez review Codexa i bez akceptacji właściciela; `sh-orkiestrator` i podręcznik (02) to zapisują.

- Podręcznik właściciela `docs/podrecznik/` (9 plików, linki Obsidiana): start, jak to działa, codzienna praca, skille, shctl, serwer i skrypty, przykład od zera (strona firmowa w trybie M i zlecenie S), gdy coś nie działa, słownik. Tylko stan etapu A; funkcje zapowiedziane jako „etap B (jeszcze niedostępne)”.
- `scripts/docs/sprawdz-podrecznik.sh` z testem `scripts/docs/tests/sprawdz-podrecznik.bats` (CI): każda komenda `shctl` i każdy skill `sh-*` z podręcznika istnieje, `03-skille.md` i `04-shctl.md` są kompletne. `docs/serwer.md`, „Praca nad systemem”: zmiana shctl, skilli lub skryptów serwera aktualizuje podręcznik w tym samym PR.

## 2026-11-02

- `shctl obsidian sync`: `git pull --ff-only` we wszystkich klonach `docs/` w vaulcie (`SH_OBSIDIAN_DIR` i `SH/sh-system`), bez merge'a i resetu; klony z lokalnymi zmianami, niewypchniętymi commitami albo rozjechane pomija i zapisuje w `~/sh/logs/obsidian-sync.log`, przy powtórce `notify.sh`. LaunchAgent `pl.iskt.softwarehouse.obsidian-sync` co 5 minut z flagą `~/sh/stan/obsidian-sync.off`, instalowany przez `install.sh`. `shctl doctor`: data ostatniej udanej synchronizacji. Zamiast wtyczki Obsidian Git; w Obsidianie tylko Dataview.
- Stare skille zostawione dla Paperclipa (`tworca-wymagan`, `iskt-softwarehouse-tworca-wymagan`, `iskt-planista-realizacji`) ukryte i zablokowane w sesjach SH: `skillOverrides: "off"` i deny `Skill(NAZWA)` w `scripts/server/orkiestrator-settings.json` (`install.sh` linkuje go do `~/sh/.claude/settings.json`) i w profilach ról szablonu (`sh-template-projekt#8`). `sh-orkiestrator`: tylko skille `software-house:*`.
- Plugin `software-house` zainstalowany na serwerze w zakresie użytkownika. `docs/serwer.md`, sekcja „Plugin software-house”: instalacja, aktualizacja (katalog czytany wprost z checkoutu, nowa sesja albo `/reload-plugins`), kontrola listy skilli w świeżej sesji, archiwizacja starych skilli do `~/sh/archiwum/skille-20261102/` z wyjątkiem kopii używanych przez Paperclip.
- Reviewer Codex: `gpt-6-astra` z rozumowaniem `high` (decyzja właściciela; szablon `konfiguracja.md` w `sh-template-projekt#7`). Profil `codex/reviewer.config.toml`: opis formatu z Codex 0.134+ i wskazanie promptu `codex/sh-review.md`. Test `shctl review run` na `sh-test-20261102-2232`: FAIL z 🔴.
- Strażnik limitów `scripts/server/sh-watchdog.sh` (bez AI) i LaunchAgent `pl.iskt.softwarehouse.sh-watchdog` co 5 minut: komunikaty o limicie Claude Code i Codexa w panelach workspace `sh` według `~/sh/watchdog-wzorce.txt`, wiersze w `~/sh/limity.md` w formacie z `docs/shctl.md`, powiadomienie przy wykryciu i przy odnowieniu, bez wznawiania pracy (etap A). `install.sh` kopiuje domyślne wzorce, gdy ich brak. Testy `sh-watchdog.bats`; `install.bats` liczy wywołania `launchctl` tylko dla `sh-start`.

- Skille `sh-orkiestrator` (panel herdr w `~/sh`, Remote Control; stan zawsze z plików i GitHuba; etapy S i M, pętla realizacji `task ready` → `dispatch` → monitoring → `review run` → `close` albo `iter`, szkielet sam przed resztą, `shctl doctor` przed pierwszym dispatchem, QA po kamieniu, punkt przekazania, odbiór, rejestr autoryzacji, limity i „wznów”, „STOP”, podniesienie trybu; commit plików wspólnych na `main` po każdej operacji shctl) i `sh-status` (tylko odczyt: `shctl status show` i liczby z GitHuba). `docs/propozycje.md`: brakujące komendy orkiestratora.
- `sh-qa`: issue tylko dla 🔴 i 🟡; ⚪ w sekcji „Drobne uwagi” raportu, orkiestrator przenosi je do `backlog-drobne.md`. `shctl task create` odrzuca `typ: qa` bez wagi `krytyczne` albo `istotne`. `sh-review` sprawdza to w review etapu `08-qa`.
- Skille `sh-review` (review PR i review etapu, wynik w formacie `templates/review.md`, w iteracji N najpierw zgłoszenia z N-1, w iteracji 3 nowe istotne jako drobne; działa w Codex przez `shctl review run` i w Claude Code) i `sh-qa` (QA zbiorcze kamienia: E2E chromium + webkit, przepływy między funkcjami, zgodność z `W-n`, raport `docs/08-qa/raport-MN.md`, błędy `typ:qa` z wagą przez `shctl task create`).
- `codex/sh-review.md` generowany ze skilla przez `scripts/sync-codex.sh` (`--check` w CI); prompt tymczasowy usunięty.
- `shctl review run`: review etapu dla PR z gałęzi `stage/ETAP` (iteracja z `DoD.md`), w kontekście promptu tryb, iteracja i poprzednie review. `shctl task create`: pole `waga` (etykieta `sev:X`). `shctl doc new 08-qa raport-qa`: plik `raport-MN.md`.
- Profil workera w szablonie: edycja `.env.example` i `supabase/`, `supabase init`; porty `supabase/config.toml` bez zmian (🟡 w review); sekcja „Ryzyka” w szablonie raportu. `sh-worker`, `sh-zadania` i prompt review dostosowane, propozycja z `docs/propozycje.md` zdjęta.
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
