# Codzienna praca

Wróć do: [[01-start]]

## Rozmowa z orkiestratorem

Orkiestrator działa w panelu herdr na serwerze i jest połączony przez **Remote Control** jako sesja
`sh-orkiestrator`. Startuje sam po zalogowaniu na serwerze.

| Skąd | Jak |
|---|---|
| Telefon | Aplikacja Claude → zakładka Code → sesja `sh-orkiestrator` |
| Laptop | Ta sama sesja na claude.ai/code |
| Terminal serwera | `/Users/Shared/sh/bin/sh-start.sh` podłącza herdr; odłączenie: `ctrl+b`, potem `q` |

Każda sesja z Remote Control startuje w trybie **Auto**: rutyna idzie bez pytania, o zgodę orkiestrator
prosi w czacie tylko przy ryzykownych krokach. **Jedna sesja prowadzi jeden projekt:** podaj nazwę w
pierwszym poleceniu („wznów sklep”). Drugi projekt to osobna sesja. W panelu orkiestratora nie
wpisuj `exit`.

| Piszesz | Co się dzieje |
|---|---|
| „status?” | „Gdzie jesteśmy” i „Czeka na Ciebie” każdego projektu, bez zmian |
| „nowy projekt NAZWA: opis” | Repo z szablonu (publiczne), intake w trybie M |
| „nowe zlecenie dla NAZWA: opis” | Intake: specyfikacja (M) albo jedno zadanie (S) |
| odpowiedź na paczkę pytań | Odpowiedzi trafiają do kart funkcji |
| „akceptuję specyfikację” / „akceptuję plan” | Zapis decyzji, merge, następny etap |
| „odbieram” / „odbieram #NR” | Odbiór etapu `wydanie` albo zlecenia S |
| „E-002: …” | Odpowiedź na eskalację albo pytanie workera |
| „materiały w skrzynce dla NAZWA” | Pliki ze skrzynki trafiają do repo przez PR |
| „wznów” | Odtworzenie stanu z plików i GitHuba, sprawdzenie przerwanych zadań |
| „STOP” | Natychmiastowe zatrzymanie wszystkich agentów |

## Jak czytać stan projektu

**`SH/Wszystkie projekty.md`** w Obsidianie to jedna tabela wszystkich projektów:

| Kolumna | Znaczenie |
|---|---|
| Projekt | Nazwa repo |
| Etap | Etap słownie, np. „Specyfikacja”, „Realizacja”, „Odbiór” |
| Postęp | „Etapy X/Y · Zadania A/B” |
| Czeka na Ciebie | Liczba rzeczy do zrobienia przez Ciebie |
| Eskalacje | Otwarte eskalacje i pytania |
| Następny krok | Co stanie się dalej albo co masz napisać |
| Widok | Link do `docs/Projekt.md` |

Kolejność: najpierw projekty, w których coś czeka na Ciebie, potem w toku, na końcu zakończone.
Tabelę odświeża serwer co 5 minut.

**`docs/Projekt.md`** to widok jednego projektu (to samo co „status?”), czysty Markdown, generowany
przy każdej zmianie stanu. Nie edytuj go.

| Sekcja | Co w niej jest |
|---|---|
| Gdzie jesteśmy | Etap, postęp, co się dzieje (worker, review, iteracja, czas), następny krok, szacowany czas |
| Czeka na Ciebie | Każda pozycja z **dokładnym tekstem do wpisania w czacie**: eskalacje, pytania, braki listy startowej, akceptacja etapu, odbiór S. „Nic. Agenci pracują sami.” = nic nie robisz |
| Zadania | W realizacji, gotowe do startu, zaplanowane, zrobione w bieżącym zleceniu, anulowane |
| Eskalacje i pytania | Otwarte `E-NNN` z tym, czego potrzeba |
| Dokumenty | Linki do specyfikacji, kart funkcji, planu, decyzji, raportów QA, historii |

Inne pliki projektu: `historia.md` (punkt przekazania, dziennik etapów, wszystkie zadania),
`decyzje.md` (wszystkie decyzje i Twoje zgody), `07-realizacja/T-NR.md` (raport workera),
`08-qa/raport-MN.md` (wynik QA kamienia), `backlog-drobne.md` (drobne uwagi na później).

Dokument czekający na akceptację jest w PR na GitHubie (gałąź `stage/…`); w Obsidianie pojawi się
po merge'u.

## Pytania intake i karty funkcji

Po zleceniu intake wysyła **brief** (cel, zakres, lista funkcji, tryb) do zatwierdzenia i **listę
startową**: konta, dostępy, domeny, klucze testowe i materiały, każda pozycja z instrukcją. Realizacja
nie wystartuje, dopóki lista nie jest kompletna.

Potem przychodzą **pytania tylko o luki w kartach funkcji**, paczkami po 5–7 (w trybie S najwyżej 3),
od najważniejszych dla architektury. Każde ma numer, kartę, proponowaną odpowiedź i skutek:

```text
Q1 W-03: zamówienie gościa bez konta? Propozycja: tak, e-mail wymagany; skutek: brak kont w M1.
```

Jak odpowiadać:

- krótko z numerem: „Q1 tak. Q2 nie, tylko PL. Q3 jak proponujesz.”;
- „zdecyduj sam” (dla pytania albo całej paczki): propozycja staje się założeniem do potwierdzenia;
- zmiana zakresu w odpowiedzi („Q4: dodaj też eksport CSV”) wraca do kart.

**Karta funkcji** (`docs/00-intake/funkcje/W-NN.md`) ma dwie części. Ty czytasz tylko górną, „Dla
właściciela”: opis, przebieg krok po kroku, stany ekranu z tekstami, reguły, poza zakresem i „Do
potwierdzenia” (założenia z proponowanymi odpowiedziami). Dolna część jest dla wykonawcy. W
checkpoincie specyfikacji dostajesz części „Dla właściciela” i zbiorczą listę „Do potwierdzenia”:
potwierdź albo popraw każde założenie.

## Checkpointy

Gdy praca czeka na akceptację, przychodzi push **„Czeka na Twoją akceptację: PROJEKT / ETAP”**.
Kliknięcie otwiera PR. Push przychodzi dopiero po review PASS, a po poprawkach ponownie.

| ETAP w tytule | Co akceptujesz |
|---|---|
| `00-intake` | Specyfikację z kartami funkcji i listą „Do potwierdzenia” |
| `04-plan` | Plan, czyli zgodę na realizację (zapis w `decyzje.md`: na co, zakres, do kiedy, jak cofnąć) |
| `wydanie` | Odbiór na stagingu według scenariuszy z planu |
| `#NR` | Odbiór zlecenia S |
| `podniesienie trybu` | Zmianę trybu, np. S na M (eskalacja z numerem `E-NNN`) |

Możesz zaakceptować („akceptuję plan”), zaakceptować z poprawką („akceptuję, ale hosting Netlify”;
zmiana wraca do review) albo poprosić o zmiany. Przy checkpoincie orkiestrator może zaproponować opis
repo na GitHubie: pokazuje dokładną komendę i czeka na Twoją zgodę.

Kolejne kamienie po akceptacji planu startują same, jeśli mieszczą się w zgodzie. Nowy zakres, płatna
usługa, dostęp albo podniesienie trybu przychodzi jako eskalacja.

## Odbiór zlecenia S

1. Push „Czeka na Twoją akceptację: PROJEKT / #NR” z linkiem do PR (review PASS, CI zielone).
2. Sprawdzasz zmianę (opis PR, podgląd wdrożenia, jeśli jest).
3. Piszesz „odbieram #NR”. Orkiestrator merguje, dopisuje `CHANGELOG.md` i zamyka issue.
   Albo opisujesz, co poprawić: worker dostaje nowe polecenie.

Ustawienie `odbior_S` w `docs/konfiguracja.md` projektu ma domyślnie `reczny`. Przy
`auto_bez_zmian_widocznych` zlecenie bez zmian widocznych dla użytkownika (etykieta `widoczne:nie`,
np. aktualizacja zależności) zamyka się samo po PASS i zielonym CI, a Ty dostajesz powiadomienie.

## Eskalacje i pytania workerów

**Eskalacja** („Eskalacja E-NNN: PROJEKT”) blokuje zadanie: 3 nieudane review, potrzebny sekret,
dostęp albo płatna usługa, decyzja nieodwracalna, sprzeczne wymagania, ryzyko. Inne zadania trwają.
**Pytanie** („Pytanie E-NNN: PROJEKT”) to wątpliwość workera o zachowanie dla użytkownika albo regułę
biznesową; worker w tym czasie robi resztę zadania.

Odpowiadasz w czacie z numerem:

```text
E-003: zgoda na Resend, darmowy plan, do odbioru projektu
```

Orkiestrator zamyka eskalację Twoją odpowiedzią i zapisuje zgodę w `decyzje.md`. **Sekretów nie
wpisuj do czatu:** klucz testowy wpisujesz sam do `/Users/Shared/sh/projekty/NAZWA/.env.local`, a w
czacie piszesz „klucz jest w .env.local”.

## Powiadomienia ntfy

| Tytuł | Co robisz |
|---|---|
| Czeka na Twoją akceptację: PROJEKT / ETAP | Otwórz PR i odpowiedz w czacie |
| Eskalacja E-NNN: PROJEKT | Odpowiedz w czacie z numerem |
| Pytanie E-NNN: PROJEKT | Odpowiedz, gdy możesz; praca trwa |
| Czeka na Ciebie od N h: PROJEKT | Przypomnienie: zajrzyj do „Czeka na Ciebie” w `Projekt.md` |
| Limit Claude / Limit Codex | Nic do godziny odnowienia, potem „wznów” |
| STOP | Gdy chcesz wrócić do pracy: „wznów” |
| Brak miejsca | Zwolnij miejsce ([[03-gdy-cos-nie-dziala#Brak miejsca na dysku]]) |
| Orkiestrator uruchomiony ponownie | Napisz „wznów” |
| Orkiestrator nie wstał po restarcie | [[03-gdy-cos-nie-dziala#Orkiestrator nie odpowiada]] |
| install.sh: agent niezaladowany | [[03-gdy-cos-nie-dziala#Co wykonujesz Ty]] |

**Przypomnienia:** gdy pozycja z „Czeka na Ciebie” czeka dłużej niż 4 godziny, serwer przypomina
jednym pushem na projekt, tylko w godzinach 8–22. Ta sama pozycja wraca najwcześniej po kolejnych
4 godzinach. Wyłączenie: `touch /Users/Shared/sh/stan/przypomnienia.off`. Ta sama eskalacja ani
akceptacja dla tego samego commita nie przyjdzie drugi raz.

## Skrzynka na materiały

Folder **`SH/Skrzynka/NAZWA/`** w vaulcie to jedyne miejsce w `SH/`, do którego zapisujesz. Wrzuć tam
eksport z Claude Design, logo, zdjęcia, teksty, dokumenty od klienta (także w podfolderach albo jako
ZIP) i napisz „materiały w skrzynce dla NAZWA”. Pliki trafią przez PR do `docs/00-intake/zrodla/`;
po zielonym CI orkiestrator merguje PR sam i opróżnia skrzynkę. Nic nie jest uruchamiane ani
rozpakowywane. Pliki ukryte, `__MACOSX` i skróty są pomijane.

## Obsidian

| Folder | Zawartość |
|---|---|
| `SH/Wszystkie projekty.md` | Tabela projektów |
| `SH/Projekty/NAZWA/docs/` | Dokumenty projektu (tylko czytasz) |
| `SH/sh-system/docs/` | Dokumenty systemu, w tym ten podręcznik (tylko czytasz) |
| `SH/Skrzynka/NAZWA/` | Twoje materiały do projektu |

Zapis w `SH/Projekty` albo `SH/sh-system` zatrzymuje synchronizację tej kopii i nie trafia do repo:
poprawki zlecasz orkiestratorowi. Własne notatki trzymaj poza `SH/`.

## Rutyna

- **Rano:** `SH/Wszystkie projekty.md` albo „status?”; odpowiedz na wszystko z „Czeka na Ciebie”; po
  nocnym limicie napisz „wznów”.
- **W ciągu dnia:** reaguj na pushe akceptacji, eskalacji i pytań. Po kamieniu orkiestrator proponuje
  restart sesji (`/clear` i „wznów”): zgódź się, stan jest w plikach.
- **Raz w tygodniu:** `docs/backlog-drobne.md` (co zlecić jako tryb S), issue „Propozycje RRRR-MM” w
  `sh-system` (propozycje agentów do Twojej decyzji), `shctl doctor` na serwerze.
