# Słownik

Wróć do: [[00-start-tutaj]]

| Pojęcie | Znaczenie |
|---|---|
| **ADR** | Architecture Decision Record: krótki dokument jednej ważnej decyzji technicznej (opcje, wybór, konsekwencje). Leży w `docs/04-plan/adr/` |
| **Autoryzacja (rejestr autoryzacji)** | Twoja zgoda na realizację planu zapisana w `decyzje.md`: na co, w jakim zakresie, do kiedy, jak cofnąć. Powstaje przy akceptacji planu |
| **Backlog drobnych** | `docs/backlog-drobne.md`: drobne uwagi z review i QA, odłożone na później |
| **CI** | Automatyczne kontrole na GitHubie przy każdym PR: lint, testy, build, szukanie sekretów. Zielone CI to warunek review i merge'a |
| **Checkpoint** | Punkt, w którym praca czeka na Twoją akceptację. Tryb M: specyfikacja, architektura z planem, odbiór. Tryb S: odbiór. Przychodzi jako push „Czeka na Twoją akceptację” |
| **Codex** | Model OpenAI w Codex CLI. W etapie A wyłącznie reviewer |
| **DoD** | Definition of Done: lista warunków „gotowe”. Każdy etap ma `DoD.md`, zadanie ma DoD w issue i checkliście PR |
| **Dispatch** | Start zadania: kopia robocza, panel i worker (`shctl task dispatch`) |
| **Eskalacja** | Prośba o Twoją decyzję: plik `E-NNN.md` i push. Tylko w sytuacjach, których agent nie może rozstrzygnąć sam |
| **Etap (procesu)** | Krok trybu M: specyfikacja, architektura i plan, realizacja, QA, odbiór. Każdy ma folder w `docs/` |
| **Etap A / etap B** | Etap wdrożenia systemu. A to pilot (dziś). B to model docelowy (jeszcze niedostępne) |
| **Herdr** | Program z panelami terminala, w którym działają agenci na serwerze |
| **Issue** | Zadanie na GitHubie: cel, kryteria akceptacji, pliki, komenda testów |
| **Iteracja** | Jedna runda poprawek po FAIL review. Maksymalnie 3, potem eskalacja. Licznik to etykieta `iter:N`. Przerwanie przez limit nie jest iteracją |
| **Kamień milowy** | Grupa zadań dająca działający kawałek produktu do sprawdzenia, np. „M2 Podstrony i treści”. Na GitHubie jako Milestone. Po każdym jest QA |
| **Kryteria akceptacji** | Sprawdzalne warunki spełnienia wymagania lub zadania, często w formie Given/When/Then („Mając…, gdy…, wtedy…”) |
| **Limit** | Wyczerpany limit subskrypcji Claude lub ChatGPT. Praca tego wykonawcy czeka do odnowienia |
| **Merge** | Włączenie zmian z PR do gałęzi `main` |
| **Migracja (zgodna wstecz)** | Zmiana schematu bazy, po której poprzednia wersja aplikacji nadal działa. Usuwanie kolumn dopiero w kolejnym wydaniu |
| **ntfy** | Usługa powiadomień push na telefon |
| **Obsidian** | Aplikacja do czytania dokumentów. Folder `SH/` w vaulcie to kopie `docs/` z GitHuba |
| **Orkiestrator** | Agent, z którym rozmawiasz. Prowadzi projekty i rozdziela pracę |
| **PASS / FAIL** | Werdykt review. FAIL, gdy jest choć jedno zgłoszenie 🔴 krytyczne albo 🟡 istotne |
| **Pliki wspólne** | `status.md`, `decyzje.md`, `metryki.md`, `backlog-drobne.md`, `06-zadania/index.md`, `CHANGELOG.md`. Zmienia je tylko orkiestrator |
| **PR** | Pull request: propozycja zmian na GitHubie, z review i CI, przed merge'em |
| **Preview (podgląd)** | Wdrożenie PR w Vercel do obejrzenia przed merge'em |
| **Produkcja (prod)** | Wersja dla użytkowników. Wdraża wyłącznie właściciel. W etapie A jej nie ma |
| **Punkt przekazania** | Sekcja w `status.md` po każdym kamieniu: stan potrzebny do wznowienia po restarcie sesji |
| **QA zbiorcze** | Testy całego kamienia po jego zakończeniu (`sh-qa`): E2E, przepływy, zgodność ze specyfikacją |
| **Remote Control** | Połączenie sesji Claude Code na serwerze z aplikacją Claude na telefonie i w przeglądarce |
| **Review** | Niezależna ocena pracy przez inny model (Codex). Review PR dla zadań, review etapu dla dokumentów |
| **Skrzynka** | Folder `SH/Skrzynka/NAZWA` w vaulcie na Twoje materiały. Orkiestrator przenosi je do repo przez PR (`shctl skrzynka przyjmij`) |
| **Skill** | Instrukcja roli agenta, np. `sh-worker`. Dostarcza je plugin `software-house` |
| **Specyfikacja** | `docs/00-intake/specyfikacja.md`: cel, zakres, wymagania `W-n`, stack, hosting, ryzyka |
| **Staging** | Wdrożenie gałęzi `main` pod stałym adresem i osobna baza testowa. Tu robisz odbiór |
| **shctl** | Program z mechaniką procesu, wywoływany przez agentów |
| **Strażnik limitów** | Skrypt bez AI, który co 5 minut wykrywa limity i wysyła powiadomienia |
| **Szkielet** | Pierwsze zadanie projektu (`T1`): struktura repo, CI, testy, baza lokalna. Do jego zamknięcia nic innego nie startuje |
| **Tryb S / M / L** | Skala procesu: S szybki (1–3 zadania), M średni (4–15 zadań), L pełny (etap B, jeszcze niedostępne) |
| **W-n** | Numer wymagania w specyfikacji, np. `W-3` |
| **Worker** | Agent realizujący jedno zadanie w osobnej kopii roboczej |
| **Worktree (kopia robocza)** | Osobny katalog z kopią repo na jednej gałęzi, np. `/Users/Shared/sh/wt/PROJEKT/12`. Dzięki temu workerzy sobie nie przeszkadzają |
| **Zadanie właściciela** | Krok ręczny z planu dla Ciebie: konto, domena, klucz, płatna usługa |
