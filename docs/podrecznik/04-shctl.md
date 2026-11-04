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
wolne miejsce, porty, kopie w Obsidianie i datę ostatniej synchronizacji, repo testowe do usunięcia.
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
```

**Kiedy samemu:** gdy praca stoi, a nie wiesz dlaczego.

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

### ports

Rejestr portów lokalnych baz Supabase w `/Users/Shared/sh/porty.md`. Każdy projekt ma własny blok.

```sh
shctl ports list                              # czyta
shctl ports reserve --projekt strona-firmowa
shctl ports release --projekt stary-projekt   # przy archiwizacji projektu
```

**Kiedy samemu:** `list`, gdy chcesz zobaczyć zajęte bloki. `release` przy archiwizacji projektu,
gdy pula portów się kończy.

### obsidian

Kopie dokumentów w vaulcie Obsidiana.

```sh
shctl obsidian sync                    # aktualizacja wszystkich kopii teraz
shctl obsidian link stary-projekt      # kopia docs/ i skrzynka dla projektu założonego wcześniej
shctl obsidian unlink stary-projekt    # usunięcie kopii przy archiwizacji
```

`sync` robi tylko `git pull --ff-only`. Kopię z lokalnymi zmianami pomija i zgłasza, nigdy niczego
nie nadpisuje. Serwer uruchamia go sam co 5 minut. `unlink` odmawia, gdy kopia ma niezapisane
zmiany.

**Kiedy samemu:** `sync`, gdy nie chcesz czekać 5 minut. `link` i `unlink` przy archiwizacji albo
przy projekcie bez kopii lub skrzynki. `unlink` skrzynki nie usuwa.

### skrzynka

Przenosi Twoje materiały ze skrzynki `SH/Skrzynka/NAZWA` do repo projektu.

```sh
shctl skrzynka przyjmij strona-firmowa                          # do docs/02-design/zrodla
shctl skrzynka przyjmij strona-firmowa --etap 00-intake/zrodla  # inne miejsce
shctl skrzynka przyjmij strona-firmowa --dry-run                # tylko sprawdza pliki
```

Działa w dwóch krokach:

1. Sprawdza pliki, kopiuje przyjęte do `docs/ETAP/KATALOG` na gałęzi `stage/ETAP` i otwiera PR. Pliki
   zostają w skrzynce.
2. Po merge'u PR kolejne wywołanie przenosi je w skrzynce do `_przeniesione/RRRRMMDD/` i od razu
   bierze nowe pliki, jeśli są.

Programy, skrypty, skróty i pliki powyżej 50 MB są odrzucane i zostają w skrzynce. ZIP jest
rozpakowywany tylko po kontroli ścieżek; programy z archiwum są pomijane. Nic nie jest uruchamiane.

**Kiedy samemu:** `--dry-run`, gdy chcesz sprawdzić, co zostanie przyjęte. Resztę robi orkiestrator na
„materiały w skrzynce”.

## Etapy, dokumenty, decyzje

Te komendy wywołują skille i orkiestrator. Opis dla zrozumienia, co widzisz w logach i dokumentach.

### stage

Zmienia status etapu w `DoD.md` i w `status.md`.

```sh
shctl stage start 04-architektura --projekt strona-firmowa
shctl stage review 04-architektura --projekt strona-firmowa
shctl stage done 04-architektura --projekt strona-firmowa
shctl stage skip 01-brief --projekt strona-firmowa
shctl stage skip 08-qa --notatka "biblioteka bez UI" --projekt strona-firmowa
shctl stage escalate 04-architektura --projekt strona-firmowa
shctl stage iter 04-architektura --projekt strona-firmowa
```

`done` przechodzi tylko przy kompletnym `DoD.md`; pole bez zastosowania ma postać
`- [-] ... (nie dotyczy: powód)`. `skip` etapu z trybu wymaga `--notatka` z uzasadnieniem. `iter` po
nieudanym review etapu podbija iterację i wraca do pracy, a po trzeciej eskaluje. Status i iteracja
etapu zmieniają się tylko na `main`, więc PR etapu nie ma z nimi konfliktu.

### doc new

Tworzy dokument z szablonu: specyfikację, architekturę, ADR, plan, raport zadania, raport QA,
dokumentację wydania. Nie nadpisuje istniejącego.

```sh
shctl doc new 04-architektura adr --tytul "Dane osobowe w formularzu" --projekt strona-firmowa
```

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

### checkpoint

Wysyła Ci push „Czeka na Twoją akceptację: PROJEKT / ETAP” z linkiem do PR (kliknięcie otwiera PR).
Działa tylko, gdy review dało PASS dla bieżącego commita PR. Dla tego samego commita nie wysyła drugi
raz.

```sh
shctl checkpoint 00-intake --projekt strona-firmowa         # specyfikacja
shctl checkpoint 04-architektura --projekt strona-firmowa   # architektura i plan
shctl checkpoint wydanie --projekt strona-firmowa           # odbiór
shctl checkpoint "#20" --projekt strona-firmowa             # odbiór zadania S
```

**Kiedy samemu:** nie trzeba, wywołuje go orkiestrator. Odmowa (kod 4) znaczy, że PR nie ma jeszcze
PASS albo nie istnieje.

## Zadania i review

Pętla realizacji. Wywołuje ją orkiestrator.

| Komenda | Co robi |
|---|---|
| `shctl task create --plik zadania.yaml` | Zakłada issue i kamienie z pliku YAML |
| `shctl task ready` | Czyta: zadania gotowe do startu i blokady |
| `shctl task dispatch NR` | Kopia robocza, panel `worker:PROJEKT:NR`, start workera |
| `shctl task wait NR` | Czeka na workera z limitem czasu; zwraca stan: gotowe, idle, blocked, pracuje |
| `shctl pr check PR` | Konflikt z `main` i wynik CI; z `--czekaj` czeka na CI, liczy nieudane naprawy |
| `shctl review run PR` | Review Codexa w czystej kopii, komentarz z werdyktem w PR; jedno naraz na PR |
| `shctl task iter NR` | Po FAIL: kolejna iteracja poprawek; po 3. FAIL eskalacja |
| `shctl task close NR` | Merge (tylko zielone CI i PASS), wpisy w plikach wspólnych, sprzątanie |
| `shctl task cancel NR` | Anuluje zadanie: issue „not planned”, PR, kopia robocza, panel, stan |
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

Przywraca projekt wzorcowy `sh-dryrun` do stanu wyjściowego, żeby po zmianach w systemie przejść go
ponownie i porównać czas, iteracje i eskalacje. Działa wyłącznie na tym projekcie. `metryki.md`
zostaje: każdy przebieg dostaje w nim nową sekcję „Przebieg dryrun N”. Klon `docs/` w vaulcie
Obsidiana powstaje od nowa.

```sh
shctl reset-dryrun
```

**Kiedy samemu:** tylko przy teście regresji systemu.

## Czego `shctl` nie ma

Tych operacji nie ma jeszcze komendą: merge PR etapu, przypomnienie bezczynnemu workerowi, wpis
drobnych uwag z QA do backlogu. Orkiestrator robi je ręcznie i zapisuje propozycje w
`docs/propozycje.md`.

Zapowiedziane komendy:

- `shctl upgrade`: aktualizacja projektów do nowego szablonu, etap B (jeszcze niedostępne);
- `shctl cykl new`: nowy cykl etapów w trwającym projekcie, etap B (jeszcze niedostępne).
