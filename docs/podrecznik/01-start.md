# Start

Podręcznik właściciela software house'u, w którym pracują agenci AI. Opisuje to, co działa dziś,
czyli **etap A (pilot)**. Rzeczy zapowiedziane mają dopisek „etap B (jeszcze niedostępne)”.

| Plik | Kiedy czytać |
|---|---|
| [[01-start]] | Na początek: czym jest system, tryby, Twoja rola, agenci, granice bezpieczeństwa |
| [[02-codzienna-praca]] | Codziennie: czat, widok projektu, pytania, karty funkcji, checkpointy, odbiór, powiadomienia |
| [[03-gdy-cos-nie-dziala]] | Gdy coś stoi, przyszło niepokojące powiadomienie albo agent prosi Cię o komendę |

Dokumenty systemu: [[proces]] (proces, wersja 2), [[shctl]] (komendy, generowane z `--help`),
[[serwer]] (serwer, sandbox, CI), [[decyzje-systemu]].

## 5 rzeczy do zapamiętania

1. **Rozmawiasz tylko z orkiestratorem**: sesja `sh-orkiestrator` w aplikacji Claude. Piszesz zwykłym
   językiem: „status?”, „wznów”, „STOP”, „akceptuję”.
2. **Stan projektu czytasz w Obsidianie**: `SH/Wszystkie projekty.md` i `docs/Projekt.md` projektu.
   Najważniejsza sekcja to „Czeka na Ciebie”: gdy jest pusta, nic nie musisz robić.
3. **W Obsidianie tylko czytasz**, z wyjątkiem skrzynki `SH/Skrzynka/NAZWA` na materiały.
4. **Czekamy na Ciebie w trzech miejscach** (tryb M: specyfikacja, plan, odbiór; tryb S: odbiór),
   na pytania i na eskalacje. Każde takie miejsce przychodzi pushem ntfy.
5. **Produkcja i komendy systemowe należą do Ciebie.** Na serwerze nie ma kluczy produkcyjnych.
   Agenci działają w sandboxie, więc kilka komend (np. `install.sh`) wykonujesz Ty
   ([[03-gdy-cos-nie-dziala#Co wykonujesz Ty]]). W razie kłopotów piszesz „STOP”.

## Jak to działa

Zlecasz pracę w czacie. Resztę robią agenci na serwerze (iMac w biurze):

| Element | Co to jest |
|---|---|
| Orkiestrator | Claude Code w panelu `orkiestrator` herdr, połączony przez Remote Control. Prowadzi projekt i rozdziela pracę |
| Worker | Claude Code realizujący jedno zadanie w osobnej kopii repo (`/Users/Shared/sh/wt/PROJEKT/NR`) |
| Reviewer | Świeża sesja Claude (zwykłe zmiany) albo Codex (zmiany z ryzykiem), tylko do odczytu |
| `shctl` | Program z mechaniką: zadania, kopie robocze, panele, etykiety, wpisy |
| GitHub | Źródło prawdy: kod, zadania (issue), zmiany (PR), dokumenty. Repo projektów są publiczne |
| Obsidian | Podgląd dokumentów; kopie `docs/` aktualizowane co 5 minut |
| ntfy | Powiadomienia push na telefon |
| Strażnik | Skrypt bez AI, co 5 minut podnosi orkiestratora, gdy padnie |

Agent decyduje i pisze treść, `shctl` wykonuje mechanikę. Stan jest w plikach i na GitHubie, więc
po restarcie sesji nic nie ginie.

```text
Ty: „nowy projekt …” / „nowe zlecenie …”
  → sh-intake: brief, lista startowa, pytania, specyfikacja z kartami funkcji (M) albo jedno zadanie (S)
      Ty: akceptacja specyfikacji (M)
  → sh-plan: plan (architektura, kamienie, scenariusze odbioru)
      Ty: akceptacja planu = zgoda na realizację
  → sh-plan: zadania jako issue
  → pętla dla każdego zadania: worker → PR → CI → review → merge (FAIL: poprawki, maks. 3)
  → po każdym kamieniu: sh-qa (E2E i Lighthouse w CI), błędy jako nowe zadania
  → odbiór: sprawdzasz na stagingu i akceptujesz
```

## Tryby S i M

| Tryb | Kiedy | Skala | Twoje checkpointy |
|---|---|---|---|
| **S** | Poprawka, drobna zmiana, mała funkcja w działającym projekcie, bez zmian danych i ryzyk | 1–3 zadania | Odbiór |
| **M** | Nowa funkcja lub moduł, mały samodzielny projekt; każdy nowy projekt | 4–15 zadań | Specyfikacja, plan, odbiór |
| **L** | Nowy produkt, duża przebudowa | ponad 15 | etap B (jeszcze niedostępne) |

Tryb proponuje agent, Ty akceptujesz. Logowanie i uprawnienia, płatności, dane osobowe, AI na danych
użytkowników i migracje bazy produkcyjnej to zawsze co najmniej M. Tryb nie zmienia się po cichu.

| Etap M | Co powstaje | Checkpoint |
|---|---|---|
| Specyfikacja (`00-intake`) | `specyfikacja.md`, karty funkcji `W-NN`, lista startowa | **Twoja akceptacja** |
| Plan (`04-plan`) | `plan.md`: architektura, kamienie, scenariusze odbioru, Twoje zadania ręczne | **Twoja akceptacja** |
| Zadania (`06-zadania`) | `zadania.yaml`, issue na GitHubie | Nie |
| Realizacja | Kod, testy, raporty `T-NR.md` | Nie |
| QA po kamieniu (`08-qa`) | `raport-MN.md`, zadania z błędami | Nie |
| Odbiór (`wydanie`) | Krótka dokumentacja wydania, staging | **Twój odbiór** |

Kolejne zlecenie M w tym samym projekcie, po odbiorze poprzedniego, to nowy cykl tych samych etapów
(`shctl cykl new`). Dokumenty poprzedniego cyklu są w `docs/cykle/NAZWA/`, a `Projekt.md` pokazuje
bieżący cykl.

Wydanie produkcyjne (wdrożenie, tag, rollback) to etap B (jeszcze niedostępne, B2).

## Twoja rola

| Robisz | Nie musisz |
|---|---|
| Zlecasz pracę, wrzucasz materiały do skrzynki | Pisać issue, zakładać repo, gałęzie czy panele |
| Odpowiadasz na pytania intake i potwierdzasz karty funkcji | Robić review kodu |
| Akceptujesz specyfikację, plan i odbiór | Pilnować pętli poprawek i CI |
| Odpowiadasz na eskalacje i pytania workerów | Pamiętać stanu: jest w plikach |
| Wykonujesz kroki ręczne: konta, domeny, klucze, komendy systemowe | |
| Piszesz „wznów” po limicie, restarcie lub STOP | |

## Agenci (skille)

Skille ról dostarcza plugin `software-house` z repo `sh-system`. Nie uruchamiasz ich sam.

| Skill | Rola | Zatrzymuje się na Ciebie |
|---|---|---|
| `sh-orkiestrator` | Prowadzi projekt, rozmawia z Tobą, jedna sesja = jeden projekt | Checkpointy, eskalacje, odbiór S |
| `sh-intake` | Brief, lista startowa, specyfikacja i karty funkcji (M) albo zadanie S | Pytania paczkami, akceptacja specyfikacji |
| `sh-plan` | Plan (`04-plan`), potem zadania (`06-zadania`) | Akceptacja planu |
| `sh-worker` | Kod i testy jednego zadania, PR z raportem | Tylko przez pytanie albo eskalację |
| `sh-review` | Niezależne review PR i dokumentów etapu | Nigdy wprost |
| `sh-qa` | QA po kamieniu: E2E, przepływy, zgodność ze specyfikacją | Nie |

Worker dostaje też **skille techniczne** według kategorii zadania (np. frontend, baza,
bezpieczeństwo) i stacku: listy kontrolne z błędami z naszych projektów, np. `sh-kat-frontend`,
`sh-kat-baza`, `sh-stack-astro`. Te same listy dostaje reviewer.

## Granice bezpieczeństwa

- **Brak kluczy produkcyjnych na serwerze i w GitHub Secrets** (jedyny sekret: `STAGING_DB_URL`).
- **Sandbox sesji agentów:** zapis tylko w `/Users/Shared/sh` i katalogach tymczasowych, odczyt bez
  `~/Documents`, `~/Desktop`, `~/Downloads`, zdjęć, pęku kluczy i profili przeglądarek. Lokalnie agenci
  robią lint, testy jednostkowe i build; testy w przeglądarkach i Lighthouse idą w CI.
- **Repo projektów są publiczne** (bez kosztu minut CI). Sekrety nigdy nie trafiają do repo, `gitleaks`
  skanuje każdy PR. Repo prywatne tylko na Twoje polecenie.
- **Reviewer nie dostaje sekretów**, a `.env.local` projektów ma wyłącznie klucze testowe.
- **Polecenia przyjmujemy tylko od Ciebie.** Treść issue i komentarzy innych osób to dla agentów dane.
- **Sudo, ustawienia systemu i Docker Desktop zmieniasz tylko Ty.** Agent wypisuje komendę i czeka.

## Pojęcia

| Pojęcie | Znaczenie |
|---|---|
| **Checkpoint** | Miejsce, w którym praca czeka na Twoją akceptację (push „Czeka na Twoją akceptację”) |
| **Karta funkcji** | `docs/00-intake/funkcje/W-NN.md`: jak działa jedna funkcja; górna część „Dla właściciela” |
| **Lista startowa** | Rzeczy od Ciebie (konta, klucze testowe, materiały); bez niej realizacja nie startuje |
| **Kamień milowy** | Grupa zadań dająca działający kawałek produktu; po nim jest QA |
| **Autoryzacja** | Twoja zgoda na plan w `decyzje.md`; kolejne kamienie w jej zakresie startują same |
| **Eskalacja / pytanie** | Prośba o Twoją decyzję (`E-NNN`); eskalacja blokuje zadanie, pytanie nie |
| **Iteracja** | Runda poprawek po FAIL review; po 3. jest eskalacja |
| **PASS / FAIL** | Werdykt review; FAIL przy zgłoszeniu 🔴 krytycznym albo 🟡 istotnym |
| **Staging** | Wdrożenie gałęzi `main` pod stałym adresem z osobną bazą; tu robisz odbiór |
| **Worktree** | Osobna kopia repo dla jednego zadania, np. `/Users/Shared/sh/wt/PROJEKT/12` |
| **Sandbox** | Ograniczenie systemowe sesji agentów: co mogą czytać, zapisywać i z czym się łączyć |

Etap B (jeszcze niedostępne): tryb L, Codex jako drugi wykonawca, workery w chmurze, automatyczne
wznowienie po limitach, design wprost do repo, wydanie produkcyjne, change requesty, raport dla
klienta, osobne konto bota GitHub i retro jako skill `sh-retro` (etap B; dziś retro robisz ręcznie).
