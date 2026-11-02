# Codzienna praca

Wróć do: [[00-start-tutaj]]

## Rozmowa z orkiestratorem

Orkiestrator działa na serwerze w panelu herdr i jest połączony przez **Remote Control** jako sesja
`sh-orkiestrator`. Startuje sam po zalogowaniu na serwerze ([[05-serwer-i-skrypty#sh-start.sh]]).

| Skąd | Jak |
|---|---|
| Telefon | Aplikacja Claude → zakładka Code → sesja `sh-orkiestrator` |
| Laptop | Ta sama sesja na liście sesji Claude Code w przeglądarce (claude.ai/code) |
| Terminal serwera | `~/sh/bin/sh-start.sh` podłącza herdr; odłączenie: `ctrl+b`, potem `q` |
| Laptop przez SSH | `ssh` na serwer, potem `~/sh/bin/sh-start.sh`; ścieżka jeszcze nietestowana |

To jedna rozmowa, niezależnie od urządzenia. Orkiestrator obsługuje wszystkie projekty naraz, więc
w poleceniu warto podać nazwę projektu.

W panelu orkiestratora nie wpisuj `exit`. Zamyka sesję i trzeba ją uruchomić ponownie
([[07-gdy-cos-nie-dziala#Orkiestrator nie odpowiada]]).

## Polecenia w czacie

Piszesz zwykłym językiem. Te sformułowania orkiestrator rozpoznaje wprost:

| Piszesz | Co się dzieje |
|---|---|
| „status?” (albo „co się dzieje”, „co czeka na mnie”) | Krótki status każdego projektu z pracą, bez zmian w niczym |
| „nowy projekt NAZWA: opis” | Zakłada repo z szablonu i uruchamia intake (tryb M) |
| „nowe zlecenie dla NAZWA: opis” | Intake: specyfikacja (M) albo jedno zadanie (S) |
| „akceptuję specyfikację” / „akceptuję plan” | Zapis Twojej decyzji, merge, przejście do następnego etapu |
| „odbieram” (przy odbiorze) | Zapis odbioru, merge, zamknięcie etapu wydania albo zadania S |
| Odpowiedź na eskalację, np. „E-002: opcja mock” | Zapis odpowiedzi, powrót do zadania |
| „wznów” | Odtworzenie stanu z plików i GitHuba, dalsza praca; po limicie sprawdzenie przerwanych zadań |
| „STOP” | Odpowiedź „Zatrzymuję wszystko” i natychmiastowe zatrzymanie wszystkich agentów |

### Jak wygląda status

```text
sklep (M, 07-realizacja, kamień M2 4/6)
Zrobione: 6 zadań, ostatnie #15 katalog
W toku: #16 płatność (in-progress), #14 w review (PR #31), CI czerwone na PR #33
Czeka na Ciebie: E-002 klucz testowy Stripe
Eskalacje: 1 (E-002); wstrzymań brak
```

Najważniejsza linia to **„Czeka na Ciebie”**. Gdy jest pusta, nic nie musisz robić.

### Akceptacje

Orkiestrator zgłasza w czacie, że etap czeka na Ciebie: podaje numer PR, tryb, ryzyka, otwarte
pytania i zakres zgody. Checkpoint **nie wysyła powiadomienia push**, więc zaglądaj do czatu albo
pytaj „status?”.

Dokument do akceptacji jest w PR na GitHubie (gałąź `stage/…`). W Obsidianie pojawi się dopiero po
merge'u, bo synchronizacja pobiera gałąź `main`.

Możesz:

- zaakceptować: „akceptuję specyfikację”, „akceptuję plan”;
- zaakceptować z poprawką: „akceptuję, ale hosting Netlify zamiast Vercel”; zmiana wraca do review;
- poprosić o zmiany: „w specyfikacji dodaj wersję angielską”; skill poprawia dokument, review
  powtarza się.

### Odpowiedź na eskalację

Przychodzi push „Eskalacja E-NNN: PROJEKT”. Treść jest w czacie (status) i w Obsidianie
(`docs/07-realizacja/escalations/E-NNN.md`, po synchronizacji). Odpowiadasz w czacie, z numerem:

```text
E-003: zgoda na Resend, darmowy plan, do odbioru projektu
```

Orkiestrator zapisuje odpowiedź w pliku eskalacji, przywraca poprzedni status zadania i działa
dalej. Zgodę na dostęp, koszt albo zakres zapisuje też w `docs/decyzje.md`.

**Sekretów nie wpisuj do czatu.** Klucz testowy wpisujesz sam do `.env.local` w repo projektu na
serwerze (`~/sh/projekty/NAZWA/.env.local`), a w czacie piszesz tylko „klucz jest w .env.local”.

## Powiadomienia ntfy

Wszystkie wysyła `notify.sh` przez ntfy.sh na Twój telefon.

| Tytuł | Priorytet | Co znaczy | Co robisz |
|---|---|---|---|
| Eskalacja E-NNN: PROJEKT | wysoki | Agent potrzebuje Twojej decyzji | Odpowiedz w czacie |
| Limit claude / Limit codex | wysoki | Wyczerpany limit subskrypcji, praca tego wykonawcy stoi do podanej godziny | Nic, czekasz |
| Limit X odnowiony | zwykły | Limit wrócił | Napisz „wznów” |
| STOP | wysoki | Zadziałał awaryjny stop | Gdy chcesz wrócić do pracy: „wznów” |
| Brak miejsca | wysoki | Za mało miejsca na dysku, nowe zadania nie startują | Zwolnij miejsce ([[07-gdy-cos-nie-dziala#Brak miejsca na dysku]]) |
| Claude czeka na Ciebie | zwykły | Worker zatrzymał się i czeka (np. na zgodę); w treści numer zadania | Zapytaj orkiestratora albo zajrzyj do panelu |
| Obsidian: klon bez synchronizacji | zwykły | Kopia w vaulcie ma lokalne zmiany albo rozjechała się z GitHubem | [[07-gdy-cos-nie-dziala#Obsidian się nie aktualizuje]] |
| install.sh: agent niezaladowany | wysoki | Usługa serwera nie wystartowała po instalacji | [[05-serwer-i-skrypty#install.sh]] |

Ta sama eskalacja albo ten sam limit nie przyjdzie drugi raz. Powiadomienie o odnowieniu limitu
przychodzi z opóźnieniem do 5 minut.

## Obsidian

Obsidian na serwerze pokazuje dokumenty, nie kod. Vault `~/Documents/Obsidian Vault`:

| Folder | Zawartość |
|---|---|
| `SH/Projekty/NAZWA/docs/` | Dokumenty projektu NAZWA |
| `SH/sh-system/docs/` | Dokumenty systemu, w tym ten podręcznik |

Kopie aktualizuje serwer co 5 minut. Nowy dokument pojawia się najpóźniej 5 minut po merge'u.
Jedyna potrzebna wtyczka to **Dataview**.

### Dashboard projektu

Otwórz `SH/Projekty/NAZWA/docs/_dashboard.md`. Pokazuje:

| Sekcja | Co widzisz |
|---|---|
| Czeka na Ciebie | Otwarte eskalacje i etapy w review czekające na Twoją akceptację |
| Etapy | Status i iteracja każdego etapu |
| Zadania | Liczniki: todo, w toku, review, zablokowane, eskalowane, zrobione; PR otwarte, czerwone CI |
| Wstrzymania z limitów | Aktywne limity |
| Otwarte eskalacje | Lista z datą |
| Ostatnie decyzje | 5 najnowszych wpisów z `decyzje.md` |

Liczniki pochodzą z chwili ostatniej synchronizacji statusu przez orkiestratora (kolumna
„Synchronizacja”). Najświeższy stan daje zawsze „status?”.

### Ważne dokumenty projektu

| Plik | Po co zaglądać |
|---|---|
| `docs/status.md` | Bieżący etap i „Punkt przekazania” po kamieniu |
| `docs/00-intake/specyfikacja.md` | Co budujemy: wymagania `W-n` |
| `docs/05-plan/plan.md` | Kamienie, scenariusze odbioru, Twoje zadania ręczne |
| `docs/decyzje.md` | Wszystkie decyzje, także Twoje zgody |
| `docs/06-zadania/index.md` | Lista zadań i ich stan |
| `docs/07-realizacja/T-NR.md` | Raport workera z zadania |
| `docs/08-qa/raport-MN.md` | Wynik QA kamienia |
| `docs/backlog-drobne.md` | Drobne uwagi odłożone na później |
| `docs/metryki.md` | Czas, iteracje i eskalacje zadań |

### Zasady

- W `SH/` **tylko czytasz**. Zapis w Obsidianie zatrzymuje synchronizację tej kopii i nie trafia
  do repo.
- Własne notatki trzymaj poza `SH/`, np. w nowym folderze w katalogu głównym vaulta.

## Codzienna rutyna

**Rano (5 minut):**

1. „status?” w czacie.
2. Odpowiedz na eskalacje z „Czeka na Ciebie”.
3. Przejrzyj powiadomienia z nocy: limit odnowiony → „wznów”.

**W ciągu dnia:**

- Reaguj na push o eskalacji. Praca niezależna i tak trwa, ale zablokowane zadanie czeka.
- Gdy orkiestrator zgłosi checkpoint, przeczytaj PR i zaakceptuj albo poproś o zmiany.
- Po kamieniu orkiestrator proponuje restart sesji (`/clear` i „wznów”). Zgódź się: stan jest w
  plikach, a świeża sesja pracuje lepiej.

**Raz w tygodniu:**

- Dashboard każdego projektu: etapy, liczniki, decyzje.
- `docs/backlog-drobne.md`: czy coś warto zlecić jako tryb S.
- Na serwerze `shctl doctor`: czy wszystko jest zdrowe ([[04-shctl#doctor]]).
- Kopia konfiguracji: `backup-config.sh` ([[05-serwer-i-skrypty#backup-config.sh]]).
