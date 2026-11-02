# Standard delivery 2.2 — 2026-10-25

## Trzy niezależne decyzje Intake

Rozmiar S/M/L opisuje wyłącznie nakład, zależności i koordynację: S to mała izolowana zmiana, M to kilka powiązanych zmian w znanym wzorcu, L to duży zakres albo wiele zależnych strumieni. Uzasadnij rozmiar. Nowy projekt może być L, a jego taski S lub M.

Osobno zapisz flagi ryzyka: auth/RLS, PII, AI, płatności, upload, integracje, migracje, sekrety, produkcja, nowy MCP; nieznane ryzyko wymaga rozpoznania. Flaga nie podnosi automatycznie rozmiaru do L. S z flagą ryzyka nie korzysta z uproszczonych zabezpieczeń. Auth/RLS wymaga niezależnego security review i testów uprawnień/izolacji; PII i AI wymagają przeglądu technicznej zgodności, retencji i danych; płatności wymagają testów sandbox i idempotencji; migracje wymagają planu odtworzenia i sprawdzenia kompatybilności; integracje/upload/sekrety/MCP wymagają walidacji wejścia, uprawnień i bezpiecznych testów. Przy wysokim lub nieznanym ryzyku Intake wyznacza właściciela rozpoznania przed ryzykowną operacją.

Osobno zapisz autonomię allowed / limited / not allowed oraz konkretne dozwolone działania i blokady. Limited zatrzymuje tylko działania wymagające decyzji; niezależna, autoryzowana praca trwa dalej. Rozmiar nigdy nie nadaje uprawnień.

## Jeden przepływ informacji

Brief określa produkt, odbiorcę, zakres i kryteria sukcesu. Planista wskazuje kolejność pionowych etapów, zależności, kontrakty i kryteria przejścia. Twórca wymagań przygotowuje wyłącznie pakiet wykonawczy jednego etapu. Intake jest jedynym właścicielem finalnego grafu tasków i natywnych zależności w Paperclip.

Każdy handoff zawiera ścieżkę/ID źródła i rewizję lub datę, zatwierdzone decyzje, tylko nowe ustalenia oraz otwarte pytania z właścicielami. Nie kopiuj pełnego briefu do planu i zlecenia, nie powtarzaj zatwierdzonych pytań. Czytaj właściwe fragmenty i zmiany, nie cały vault. Mała izolowana zmiana w znanym kontekście może przejść bez nowego briefu i roadmapy; flagi ryzyka nadal obowiązują.

## Etapy i zgoda

Plan zawiera rejestr autoryzacji: kto i gdzie zatwierdził, data/rewizja, nazwane etapy objęte zgodą, zakres, budżet/limit kosztu, narzędzia/uprawnienia, ograniczenia, termin ważności lub brak terminu i warunki cofnięcia. Samo istnienie planu nie jest zgodą. Gdy zgody brakuje, przedstaw konkretny plan do jednej decyzji obejmującej wskazane etapy.

Intake automatycznie uruchamia następny objęty zgodą etap, gdy poprzedni odebrano, checklisty i zależności są spełnione, nie ma blockerów ani zmiany zakresu, kosztu, uprawnień lub ryzyka wymagającej nowej decyzji. Jeden aktywny etap; równolegle mogą działać niezależne taski tego etapu. Nie żądaj ponownego zatwierdzenia tej samej autoryzowanej pracy. Wymóg request_confirmation w kontrakcie dotyczy decyzji jeszcze niezatwierdzonych, nie każdego przejścia etapu.

Zachowaj human gates dla produkcji, merge do main/default branch, tagów/release, decyzji prawnych/właścicielskich, nowych kosztów/uprawnień i operacji na rzeczywistych odbiorcach. Szczegółowe ograniczenia connectorów nadal obowiązują. Plan etapów nie zastępuje wymaganej zgody na te operacje. Po odbiorze zapisz dowody, aktualny etap i dokładnie jeden następny krok z właścicielem. stage-complete nie oznacza prod-deployed.

## Uruchamianie ról

Katalog kompetencji nie oznacza udziału wszystkich agentów. Intake wykorzystuje istniejący kontekst i uruchamia tylko potrzebnych wykonawców. Analityk jest potrzebny przy lukach lub sprzecznościach wymagań, Architekt przy nowych granicach/kontraktach/ADR; nie muszą ponownie analizować każdego taska. Review musi być niezależne od autora. QA dobiera testy do skutków i ryzyka. Knowledge Manager aktualizuje dokumentację różnicowo na odbiorze, bez obowiązkowej rozmowy z każdym wykonawcą. Delivery Controller tylko przy złożonych zależnościach lub release; Security, Compliance, UX, FinOps, DevOps i Lovable według rzeczywistych flag.

Docelowa hipoteza do pierwszego projektu: małe zadanie zwykle 3 role (Intake, wykonawca, niezależna weryfikacja), typowa funkcja 4–6. To liczba uczestników, nie limit bezpieczeństwa ani wymóg równoczesnego uruchomienia. Flagi ryzyka mogą wymagać dodatkowych specjalistów. Nie redukuj wymaganej weryfikacji dla osiągnięcia limitu.

## Gotowość i pomiar

Przed pierwszą implementacją projektu DevOps/Intake zapisuje dowód dostępu do repo i brancha, komendy lint/test/build, endpoint CI i dostępny runner ze smoke job, potrzebne środowiska testowe oraz możliwość zapisu dokumentacji. Sam działający serwer Forgejo nie dowodzi działania CI. Preflight sprawdza tylko usługi wymagane projektem, zapisuje czas, zakres i wynik; ponów po istotnej zmianie lub wygaśnięciu dostępu. Brak konta/tokena/runnera ma konkretnego właściciela i blokuje zależne taski, bez udawania sukcesu.

Na tasku zapisuj UTC: requested_at, implementation_started_at, implementation_done_at, accepted_at; blocker_started_at/ended_at z przyczyną human/infra/dependency, liczbę uruchomień agentów i cykli poprawek. Intake zbiera dane z historii Paperclip, nie zgaduje czasu pracy. Raportuj osobno czas kalendarzowy, oczekiwanie i dostępny czas aktywnych runów; nie sumuj równoległych runów jako czasu kalendarzowego. Po pierwszym projekcie porównaj medianę i p90 czasu oraz rework dla podobnych zadań; mała próbka nie daje wiarygodnego p90. Instrumentacja jest kontraktem pracy agentów, nie nową automatyzacją serwera.

Paperclip jest źródłem statusów zadań, Obsidian wiedzy i decyzji, Airtable dashboardem gdy połączony. Jeden Knowledge Manager prowadzi dokumentację produktową i techniczną. Aktualizuje istniejące strony; release ma jeden zapis z sekcjami użytkową i techniczną, commit/tag, wynikami QA/CI, ograniczeniami i linkami. Screenshoty tylko gdy pomagają i bez danych wrażliwych. Nie twórz dwóch pełnych dokumentacji przy każdym wydaniu. Superpowers stosuj selektywnie w natywnym przepływie Paperclip, bez drugiego frameworka orkiestracji.
