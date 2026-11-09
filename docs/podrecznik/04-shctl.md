# shctl

Wróć do: [[00-start-tutaj]]

`shctl` to program z mechaniką procesu: zakłada projekty, zadania, kopie robocze, panele, wpisy w
dokumentach. Na co dzień wywołuje go orkiestrator. Ty używasz go głównie do **sprawdzania**.
Pełny opis techniczny: [[shctl|docs/shctl.md]]. Lista komend: `shctl --help`.

## Jak uruchamiać

Na serwerze, w panelu `powloka` w herdr albo w zwykłym terminalu. Komendy dotyczące projektu
wymagają nazwy: `--projekt NAZWA` albo uruchomienia w katalogu projektu (`/Users/Shared/sh/projekty/NAZWA`).

| Opcja | Działanie |
|---|---|
| `--projekt NAZWA` | Wybiera projekt z `/Users/Shared/sh/projekty/NAZWA` |
| `--dry-run` | Pokazuje, co by się stało, niczego nie zmienia |
| `--json` | Wynik jako JSON (dla agentów) |

Każde wywołanie trafia do logu `/Users/Shared/sh/logs/shctl.log`. Komenda powtórzona z tymi samymi argumentami
niczego nie dubluje.

**Zasada bezpieczeństwa:** komendy zmieniające pliki projektu zostawiają zmiany do commitu przez
orkiestratora. Jeśli sam uruchomisz taką komendę, powiedz mu o tym w czacie. Bezpieczne w każdej
chwili są komendy tylko do odczytu, oznaczone w tabelach „czyta”.

| Kod wyjścia | Znaczenie |
|---|---|
| 0 | Sukces |
| 1 | Błąd wykonania (sieć, GitHub, git) |
| 2 | Błędne użycie |
| 3 | Brak projektu, pliku lub narzędzia |
| 4 | Odmowa według reguł procesu, z podanym powodem |

## Stan i diagnostyka

### status show

**Czyta.** Krótki stan projektu: etap, zadania według statusu, otwarte eskalacje, wstrzymania z
limitów. To samo, co dostaje orkiestrator przy „status?”.

```sh
shctl status show --projekt strona-firmowa
```

**Kiedy samemu:** gdy nie masz pod ręką czatu, a chcesz szybko zobaczyć stan.

### doctor

**Czyta** (jedyny zapis: zdejmuje z listy do usunięcia repo testowe, których już nie ma). Sprawdza
zdrowie serwera: narzędzia, logowania gh, codex i claude, logowanie git do GitHuba, Docker, herdr,
czy w panelu `orkiestrator` działa orkiestrator (ta sama kontrola co przy starcie i w strażniku)
i czy ma `/Users/Shared/sh/bin` w PATH, powiadomienia, hook git,
wolne miejsce, porty, kopie w Obsidianie (czy są aktualne), repo testowe do usunięcia.
Stany: `ok`, `uwaga`, `blad`.

```sh
shctl doctor
shctl doctor --test-notify   # dodatkowo wysyła prawdziwe powiadomienie testowe
```

**Kiedy samemu:** raz w tygodniu, po restarcie serwera, po zmianach w systemie, gdy coś nie działa.
Orkiestrator uruchamia go przed pierwszym zadaniem każdego projektu.

### task ready

**Czyta.** Pokazuje zadania gotowe do startu i blokady: brak wolnego miejsca na workera, za mało
miejsca na dysku, pełna kolejka review, limit Claude.

```sh
shctl task ready --projekt strona-firmowa
shctl task ready --czekaj --projekt strona-firmowa   # czeka, aż blokada zejdzie (do 30 minut)
```

Z `--czekaj` komenda sama czeka na wolne miejsce, kolejkę review, dysk albo koniec limitu, gdy są
zadania do startu. Bez takich zadań wraca od razu.

**Kiedy samemu:** gdy praca stoi, a nie wiesz dlaczego. Bez `--czekaj`.

### task resume-check

**Czyta** (uruchamia tylko testy zadania). Stan przerwanego zadania: gałąź, niezacommitowane pliki,
różnica z `main`, wynik testów, panel, podpowiedź: kontynuuj, rebase albo iteracja od nowa.

```sh
shctl task resume-check 12 --projekt strona-firmowa
shctl task resume-check 12 --bez-testow --projekt strona-firmowa
```

**Kiedy samemu:** rzadko. Orkiestrator używa go po „wznów”.

## Projekt

### new-project

Zakłada projekt: repo z szablonu (domyślnie prywatne), klon w `/Users/Shared/sh/projekty/NAZWA`, etykiety, blok
portów bazy, konfigurację, kopię `docs/` w Obsidianie, skrzynkę na materiały
`SH/Skrzynka/NAZWA`, commit i push.

```sh
shctl new-project strona-firmowa --opis "Strona firmowa z formularzem kontaktowym"
```

| Opcja | Znaczenie |
|---|---|
| `--tryb S\|M` | Domyślnie M. Tryb L to etap B (jeszcze niedostępne) |
| `--public` | Repo publiczne |
| `--opis` | Treść zlecenia, trafia do `docs/00-intake/zrodlo.md` |

**Kiedy samemu:** nie trzeba. Napisz orkiestratorowi „nowy projekt …”, a on zrobi to i uruchomi
intake.

### obsidian

Kopie dokumentów w vaulcie Obsidiana.

```sh
shctl obsidian link stary-projekt      # kopia docs/ i skrzynka dla projektu założonego wcześniej
shctl obsidian unlink stary-projekt    # usunięcie kopii przy archiwizacji
```

Kopie aktualizuje sam serwer co 5 minut (`obsidian-sync.sh`, zwykłe `git pull --ff-only`); osobnej
komendy do synchronizacji nie ma. `unlink` odmawia, gdy kopia ma niezapisane zmiany.

**Kiedy samemu:** `link` i `unlink` przy archiwizacji albo przy projekcie bez kopii lub skrzynki.
`unlink` skrzynki nie usuwa.

### skrzynka

Przenosi Twoje materiały ze skrzynki `SH/Skrzynka/NAZWA` do repo projektu.

```sh
shctl skrzynka przyjmij strona-firmowa              # do docs/00-intake/zrodla
shctl skrzynka przyjmij strona-firmowa --dry-run    # tylko wypisuje pliki
```

Jedno wywołanie robi wszystko: kopiuje pliki do `docs/00-intake/zrodla` na nowej gałęzi, otwiera PR,
czeka na CI, po zielonym CI merguje PR i opróżnia skrzynkę. Przy czerwonym CI PR zostaje otwarty, a
skrzynka bez zmian. Pliki ukryte, `__MACOSX` i skróty (dowiązania) są pomijane. Nic nie jest
uruchamiane ani rozpakowywane.

**Kiedy samemu:** `--dry-run`, gdy chcesz sprawdzić, co zostanie przyjęte. Resztę robi orkiestrator na
„materiały w skrzynce”.

## Etapy, dokumenty, decyzje

Te komendy wywołują skille i orkiestrator. Opis dla zrozumienia, co widzisz w logach i dokumentach.

### stage

Jedna komenda etapu: zmienia status etapu w `DoD.md` i w `status.md`, a po FAIL review podbija
iterację. Projekty sprzed migracji (bez `wersja_procesu` w `konfiguracja.md`) mają etapy
`04-architektura` i `05-plan` zamiast `04-plan`.

```sh
shctl stage start 04-plan --projekt strona-firmowa
shctl stage review 04-plan --projekt strona-firmowa
shctl stage iter 04-plan --projekt strona-firmowa
shctl stage done 04-plan --projekt strona-firmowa
shctl stage escalate 04-plan --projekt strona-firmowa
```

`done` przechodzi tylko przy kompletnym `DoD.md`; pole bez zastosowania ma postać
`- [-] ... (nie dotyczy: powód)`. Pominięcie etapu to decyzja (`decision add`) i w `DoD.md` `status: pominiety` z polem `decyzja`;
osobnej komendy nie ma. `iter` po
nieudanym review etapu podbija iterację i wraca do pracy, a po trzeciej eskaluje. Status i iteracja
etapu zmieniają się tylko na `main`, więc PR etapu nie ma z nimi konfliktu.

### decision add

Dopisuje decyzję do `docs/decyzje.md`: co, dlaczego, jak cofnąć, kto (rola). Tak zapisuje się też
Twoje akceptacje (rola `wlasciciel`).

```sh
shctl decision add --co "Hosting Vercel" --dlaczego "akceptacja właściciela" --cofniecie "zmiana hostingu przed odbiorem" --rola wlasciciel --projekt strona-firmowa
```

### escalate

Otwiera eskalację: plik `E-NNN.md`, status zadania lub etapu, wpis w `status.md`, powiadomienie push.

```sh
shctl escalate --dotyczy "#9" --powod "brak klucza testowego Resend" --potrzebne "klucz w .env.local" --opcje "czekać;mock" --projekt strona-firmowa
```

Z `--akceptacja` to propozycja do Twojej akceptacji (dziś: podniesienie trybu), a push ma tytuł
„Czeka na Twoją akceptację: PROJEKT / podniesienie trybu” zamiast „Eskalacja”.

### escalate close

Zamyka eskalację Twoją odpowiedzią i przywraca poprzedni status.

```sh
shctl escalate close E-001 --odpowiedz "klucz testowy jest w .env.local" --projekt strona-firmowa
```

**Kiedy samemu:** nie trzeba. Odpowiedz w czacie, orkiestrator zamknie eskalację i zrobi commit.

## Zadania i review

Pętla realizacji. Wywołuje ją orkiestrator.

| Komenda | Co robi |
|---|---|
| `shctl task create --plik zadania.yaml` | Zakłada issue i kamienie z pliku YAML |
| `shctl task ready` | Czyta: zadania gotowe do startu i blokady; z `--czekaj` czeka, aż blokada zejdzie |
| `shctl task dispatch NR` | Kopia robocza, panel `worker:PROJEKT:NR`, start workera z listą skilli (bazowe, kategoria, stack, projekt) |
| `shctl task wait NR` | Czeka na nową turę workera po poleceniu, z limitem czasu; stan: gotowe, idle, blocked, pracuje, bez_tury (worker nie podjął polecenia) |
| `shctl pr check PR` | Konflikt z `main` i wynik CI; z `--czekaj` czeka na CI, liczy nieudane naprawy (commit z samym raportem się nie liczy) |
| `shctl review run PR` | Review Codexa w czystej kopii, komentarz z werdyktem w PR; jedno naraz na PR |
| `shctl task iter NR` | Po FAIL: kolejna iteracja poprawek; po 3. FAIL eskalacja |
| `shctl task close NR` | Merge (tylko zielone CI i PASS), wpisy w plikach wspólnych, propozycje do issue miesiąca, sprzątanie |
| `shctl task close NR --anuluj` | Anuluje zadanie: issue „not planned”, PR, kopia robocza, panel, stan (dawniej `task cancel`) |
| `shctl task resume-check NR` | Czyta: stan zadania po przerwie |

```sh
shctl task dispatch 12 --projekt strona-firmowa
shctl review run 15 --projekt strona-firmowa
shctl task close 12 --projekt strona-firmowa
```

`task dispatch` odmawia, gdy brak wolnego miejsca na workera (`max_local` w
`/Users/Shared/sh/konfiguracja.md`, domyślnie 2 na cały Mac; projekt może go obniżyć w swoim
`konfiguracja.md`), mniej niż 15 GB na dysku, pełna kolejka review albo aktywny limit Claude.
Eskalowane zadanie nie zajmuje miejsca. `task close` odmawia bez zielonego CI i bez PASS dla
bieżącego commita. `pr check` przy konflikcie z `main` mówi to wprost: CI wtedy nie startuje.

**Kiedy samemu:** nie uruchamiaj ich równolegle z orkiestratorem. Wyjątek to `task ready`,
`task resume-check` i `pr check` bez `--czekaj`, bo tylko czytają.

## Awaryjne

### stop-all

Zatrzymuje workerów, reviewerów i orkiestratora (zamyka ich panele), zachowuje kopie robocze, zapisuje
stan w `/Users/Shared/sh/stan/NAZWA.json` i wysyła push „STOP”. Panel `powloka` zostaje.

```sh
shctl stop-all                            # wszystko
shctl stop-all --projekt strona-firmowa   # tylko ten projekt; wspólny orkiestrator zostaje
```

**Kiedy samemu:** gdy nie możesz napisać „STOP” w czacie, a trzeba zatrzymać pracę. Wznowienie
opisuje [[07-gdy-cos-nie-dziala#Awaryjny STOP]].

## Testowe

### reset-dryrun

Przywraca projekt wzorcowy `sh-dryrun` do stanu wyjściowego (tag z `baseline_tag` w
`konfiguracja.md` albo najnowszy `baseline-DATA`), żeby po zmianach w systemie przejść go
ponownie i porównać czas, iteracje i eskalacje. Działa wyłącznie na tym projekcie. `metryki.md`
zostaje: każdy przebieg dostaje w nim nową sekcję „Przebieg dryrun N”. Klon `docs/` w vaulcie
Obsidiana powstaje od nowa.

```sh
shctl reset-dryrun
```

**Kiedy samemu:** tylko przy teście regresji systemu.

## Utrzymanie projektów

### template update

Przenosi do istniejącego projektu aktualne pliki szablonu: `scripts/`, workflowy CI, profile
uprawnień agentów, `AGENTS.md`, `docs/_szablony/`. Commit na `main` projektu, bez przełączania gałęzi.
Plik zmieniony w projekcie zostaje (`pominiety`), chyba że dodasz `--force`. Brakujące pliki dochodzą.
Z `--baseline` (projekt wzorcowy) robi to samo na najnowszym baseline i zapisuje wynik jako nowy tag
`baseline-DATA`; żaden tag nie jest przesuwany. `--dry-run` pokazuje, co się zmieni.

```sh
shctl template update --projekt sh-dryrun --baseline --dry-run
shctl template update --projekt sh-dryrun --baseline
```

**Kiedy samemu:** po zmianach w szablonie, zwykle robi to agent pracujący nad systemem. Zadania w
toku dostają nowe pliki dopiero po rebase'ie na `main`.

### sprzataj

Usuwa kopie robocze (worktree) w `/Users/Shared/sh/wt` i `/Users/Shared/sh/wt-system` oraz lokalne
gałęzie, ale tylko te, których PR jest scalony albo zamknięty. Kopii z niezapisanymi zmianami, gałęzi
z commitami spoza PR i `main` nie rusza; pokazuje je jako pominięte z powodem.

```sh
shctl sprzataj --dry-run   # co by usunął
shctl sprzataj
```

**Kiedy samemu:** gdy kopii roboczych i gałęzi przybywa. Usuwa tylko to, co już scalone albo zamknięte.

## Czego `shctl` nie ma

Tych operacji nie ma jeszcze komendą: merge PR etapu, przypomnienie bezczynnemu workerowi, wpis
drobnych uwag z QA do backlogu. Orkiestrator robi je ręcznie, a propozycje trafiają jako
komentarze do issue miesiąca „Propozycje RRRR-MM” w `sh-system`.

Zapowiedziane komendy:

- `shctl cykl new`: nowy cykl etapów w trwającym projekcie, etap B (jeszcze niedostępne).
