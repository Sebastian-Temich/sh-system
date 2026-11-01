# shctl

CLI z mechaniką procesu (`proces-v1.md`, „Automatyzacja: CLI shctl”). Agent decyduje i pisze treść,
a shctl wykonuje operacje na plikach, GitHubie i panelach herdr. To część 1: bez `task`, `review` i
`reset-dryrun`.

Źródło: `scripts/shctl/` (`shctl`, `cmd/` z podkomendami, `lib/`, `tests/`). `install.sh` zakłada
symlink `~/sh/bin/shctl`. Zależności: bash 3.2+, gh, jq, yq (mikefarah), git, herdr.

## Zasady wspólne

| Opcja | Działanie |
|---|---|
| `--dry-run` | Pokazuje, co by się stało. Nie zapisuje plików, nie zmienia GitHuba, nie zamyka paneli, nie powiadamia |
| `--json` | Na stdout dokładnie jeden dokument JSON, także przy błędzie |
| `--projekt NAZWA` | Projekt z `~/sh/projekty/NAZWA`; bez opcji projekt z bieżącego katalogu, także z worktree |

Opcje wolno podać w dowolnym miejscu po nazwie komendy. Nazwa projektu to litery, cyfry, `-` i `_`.

Każda komenda jest idempotentna: powtórka z tymi samymi argumentami niczego nie dubluje, a przerwaną
operację dokańcza.

| Kod wyjścia | Znaczenie |
|---|---|
| 0 | Sukces, także gdy nie było nic do zmiany |
| 1 | Błąd wykonania: gh, git, sieć, powiadomienie, kontrola `doctor` |
| 2 | Błędne użycie |
| 3 | Brak projektu, pliku lub narzędzia |
| 4 | Odmowa według reguł procesu (DoD, tryb, status, wyczerpana pula) |

Format `--json`:

```json
{"ok":true,"komenda":"stage","dry_run":false,"wynik":{}}
{"ok":false,"komenda":"stage","kod":4,"blad":"stage done niedozwolone dla 05-plan w statusie todo"}
```

Komunikaty błędów i ostrzeżenia idą na stderr. Każde wywołanie dopisuje linię do
`~/sh/logs/shctl.log` (czas, kod, `dry`, projekt, komenda i argumenty ucięte do 400 znaków).

shctl commituje tylko w `new-project`. Pozostałe komendy zostawiają zmiany w drzewie roboczym, a
commit na main robi orkiestrator. Komendy zmieniające pliki wspólne ostrzegają poza gałęzią `main`.

Zmienne środowiska (dla testów i innego układu):

| Zmienna | Domyślnie |
|---|---|
| `SH_DIR` | `~/sh` |
| `SH_GH_OWNER` | `Sebastian-Temich` |
| `SH_TEMPLATE` | `sh-template-projekt` |
| `SH_NOTIFY_CMD` | `$SH_DIR/bin/notify.sh` |
| `SH_CONFIG` | `~/.config/sh/config` |
| `SH_OBSIDIAN_DIR` | Z `SH_CONFIG`; bez wartości `new-project` pomija klon w vaulcie |

Plik `~/.config/sh/config` jest poza repo. shctl czyta z niego linię
`SH_OBSIDIAN_DIR="/ścieżka/do/vaulta/SH/Projekty"` jako dane, bez `source`. Zmienna środowiska ma pierwszeństwo.

## new-project

```sh
shctl new-project NAZWA [--tryb S|M] [--public] [--opis "..."]
```

Kolejno: repo `SH_GH_OWNER/NAZWA` z szablonu (domyślnie prywatne), klon do `~/sh/projekty/NAZWA`,
usuwanie gałęzi po merge'u (`gh repo edit --delete-branch-on-merge`), `setup-labels.sh`,
frontmatter `konfiguracja.md` (`tryb_procesu`, `etap_wdrozenia: A`, `data`,
`blok_portow`), blok portów, `supabase/config.toml`, jeśli istnieje, `pominiety` dla etapów spoza
trybu, `status.md`, opis w `docs/00-intake/zrodlo.md`, `check-dod.sh`, commit i push na main. Na
końcu zakłada lekki klon `docs/` w `SH_OBSIDIAN_DIR/NAZWA` (sekcja „obsidian”) i informuje, że w
Obsidianie wystarczy włączyć Obsidian Git dla tego folderu.

| Argument | Znaczenie |
|---|---|
| `--tryb` | Domyślnie M. S działa z ostrzeżeniem, bo proces zaczyna nowy projekt od M lub L. L daje kod 2 (etap B) |
| `--public` | Repo publiczne |
| `--opis` | Trafia do `zrodlo.md` i, ucięty, do opisu repo |

Odmawia (kod 4), gdy repo nie powstało z szablonu, katalog jest klonem innego repo albo `--tryb`
różni się od trybu istniejącego projektu. Powtórka commituje tylko pliki, które sama zmienia.

```sh
shctl new-project sklep --opis "Sklep z kawą" --json
```

```json
{"ok":true,"komenda":"new-project","dry_run":false,"wynik":{
  "repo":"Sebastian-Temich/sklep","katalog":"/Users/.../sh/projekty/sklep","tryb":"M",
  "kroki":["utwórz repo ...","sklonuj do ..."],
  "porty":{"projekt":"sklep","baza":"551","zakres":"55121-55129","api":"55121","db":"55122",
    "studio":"55123","mail":"55124","inspector":"55125","dev":"55126","analytics":"55127",
    "shadow":"55128","pooler":"55129"},
  "obsidian":{"katalog":"/Users/.../Obsidian Vault/SH/Projekty/sklep","utworzono":true}}}
```

Przy `--dry-run` pole `porty` to sam zakres, np. `"55121-55129"`.

## stage

```sh
shctl stage start|review|done|skip|escalate ETAP [--notatka "..."]
```

`ETAP` to nazwa folderu, np. `00-intake`, `04-architektura`, `wydanie`. Mapowanie etapów trybu M:
`proces-v1.md`, „Definition of Done”. Komenda zmienia `status` w `DoD.md`, sekcję „Bieżący etap” i
„Dziennik etapów” w `status.md`.

| Akcja | Dozwolone z | Wynik |
|---|---|---|
| `start` | `todo`, `review`, `escalated`, `in-progress` | `in-progress` |
| `review` | `in-progress`, `review` | `review` |
| `done` | `review`, `done` | `done`, po zielonym `check-dod.sh` |
| `skip` | `todo`, `pominiety`, tylko etap spoza trybu | `pominiety` |
| `escalate` | `todo`, `in-progress`, `review`, `escalated` | `escalated` |

`done` uruchamia `check-dod.sh` na repo i na kopii `docs/` ze statusem `done`; przy brakach kończy
się kodem 4, a status zostaje. Licznika `iteracja` shctl nie podbija w tej części. `stage escalate`
zmienia tylko status: eskalację z plikiem i powiadomieniem otwiera `shctl escalate`. Etap czekający
na coś zewnętrznego to `stage start ETAP --notatka "czeka na ..."`.

```sh
shctl stage review 04-architektura --notatka "gotowe do review" --json
```

```json
{"ok":true,"komenda":"stage","dry_run":false,"wynik":{
  "projekt":"sklep","etap":"04-architektura","poprzedni":"in-progress","status":"review","zmiana":true}}
```

## doc new

```sh
shctl doc new ETAP TYP [--tytul "..."] [--rola ROLA] [--nr NR]
```

Tworzy dokument z `docs/_szablony/TYP.md` z frontmatterem `projekt`, `etap`, `data`, `rola`.
Istniejącego pliku nie nadpisuje. Domyślna rola wynika z etapu: intake, architekt, zadania, worker,
qa, orkiestrator.

| TYP | ETAP | Plik | Wymaga |
|---|---|---|---|
| `specyfikacja` | `00-intake` | `specyfikacja.md` | |
| `architektura` | `04-architektura` | `architektura.md` | |
| `adr` | `04-architektura` | `adr/ADR-NNN-slug.md` | `--tytul` |
| `plan` | `05-plan` | `plan.md` | |
| `raport-zadania` | `07-realizacja` | `T-NR.md` | `--nr` |
| `raport-qa` | `08-qa` | `raport-qa-slug.md` | `--tytul` |
| `wydanie-techniczna` | `wydanie` | `techniczna/techniczna.md` | |
| `wydanie-produktowa` | `wydanie` | `produktowa/produktowa.md` | |

Numer ADR to najwyższy istniejący plus jeden. Powtórka z tym samym tytułem zwraca ten sam ADR.
Inne szablony trafiają do `docs/ETAP/TYP.md`. Typów `eskalacja` i `decyzja` nie obsługuje: służą do
tego `escalate` i `decision add`.

```sh
shctl doc new 04-architektura adr --tytul "Wybór bazy" --json
```

```json
{"ok":true,"komenda":"doc","dry_run":false,"wynik":{
  "plik":"docs/04-architektura/adr/ADR-001-wybor-bazy.md","utworzono":true,"rola":"architekt","adr":"ADR-001"}}
```

## decision add

```sh
shctl decision add --co "..." --dlaczego "..." --cofniecie "..." [--rola ROLA]
```

Dopisuje wiersz do `docs/decyzje.md`. Tabela ma kolumny Data, Źródło, Pytanie, Decyzja, więc:
Źródło to `--rola` (domyślnie `orkiestrator`), Pytanie to `--co`, a Decyzja to
`DLACZEGO. Cofnięcie: COFNIECIE`. Ta sama decyzja nie zostanie dopisana drugi raz, także innego dnia.

```sh
shctl decision add --co "Postgres zamiast SQLite" --dlaczego "potrzebne RLS" --cofniecie "migracja danych" --json
```

```json
{"ok":true,"komenda":"decision","dry_run":false,"wynik":{
  "wiersz":"| 2026-11-01 | orkiestrator | Postgres zamiast SQLite | potrzebne RLS. Cofnięcie: migracja danych |","dodano":true}}
```

## escalate

```sh
shctl escalate --dotyczy "#NR|ETAP" --powod "..." --potrzebne "..." [--opcje "A;B"] [--priorytet high]
shctl escalate close E-NNN --odpowiedz "..."
```

Otwarcie: tworzy `docs/07-realizacja/escalations/E-NNN.md`, ustawia etykietę `status:escalated` na
issue albo status `escalated` etapu, aktualizuje sekcję „Otwarte eskalacje” w `status.md` i woła
`notify.sh` (domyślnie `high`). Plik ma frontmatter ze stanem: `status`, `dotyczy`, `powod`,
`priorytet`, `poprzedni_status`, `powiadomiono`.

Powtórka z tym samym `--dotyczy` i `--powod` dotyczy tej samej otwartej eskalacji. Nieudane
powiadomienie daje kod 1, a ponowienie komendy wysyła je jeszcze raz.

Zamknięcie: zapisuje odpowiedź w „Rozstrzygnięcie”, przywraca poprzedni status issue lub etapu i
usuwa wpis ze `status.md`. Gdy na to samo zadanie czeka inna otwarta eskalacja, etykieta zostaje.
Błąd gh zostawia eskalację otwartą. Powtórka z tą samą odpowiedzią nic nie zmienia, a z inną kończy
się kodem 4.

```sh
shctl escalate --dotyczy "#12" --powod "brak klucza Stripe" --potrzebne "klucz testowy" --opcje "czekać;mock" --json
```

```json
{"ok":true,"komenda":"escalate","dry_run":false,"wynik":{
  "id":"E-001","dotyczy":"#12","plik":"docs/07-realizacja/escalations/E-001.md","nowa":true}}
```

## ports

```sh
shctl ports reserve|release|list [--zakres 55|56]
```

Rejestr to tabela „Projekty Supabase” w `~/sh/porty.md`. `reserve` i `release` działają na projekcie
z `--projekt` albo z bieżącego katalogu, a zapis chroni blokada `porty.md.lock`.

- `reserve` bierze pierwszy wolny blok bez zajętych portów (`lsof`). Istniejącą rezerwację zwraca bez
  zmian. W projekcie z `supabase/config.toml` ustawia wszystkie porty i `project_id`.
- Po wyczerpaniu puli 55 kończy się kodem 4: najpierw zwalniamy bloki archiwalne, a dopiero potem
  `--zakres 56`. Bloki tego zakresu mają w tabeli etykietę `56:X`.
- `release` przywraca wiersz `*wolny*`. Nie zmienia `config.toml` i nie zatrzymuje stacku.

```sh
shctl ports list --json
```

```json
{"ok":true,"komenda":"ports","dry_run":false,"wynik":[
  {"x":"1","projekt":"sklep","katalog":"`~/sh/projekty/sklep`","api":"55121","db":"55122","studio":"55123",
   "mail":"55124","analytics":"55127","shadow":"55128","pooler":"55129","inspector":"55125","stan":"zarezerwowany 2026-11-01"}]}
```

`reserve` zwraca obiekt jak pole `porty` w `new-project`, a `release` `{"projekt":"sklep","zwolniono":true}`.

## status show

```sh
shctl status show
```

Krótkie podsumowanie dla właściciela: etap, zadania według statusu, otwarte eskalacje, wstrzymania z
`~/sh/limity.md`. Zadania pochodzą z GitHuba, a gdy jest niedostępny, z liczników `status.md`
(`zrodlo_zadan`). Z `limity.md` bierze pozycje list i wiersze tabeli bez nagłówka; format ustali
strażnik limitów. Komenda tylko czyta.

```json
{"ok":true,"komenda":"status","dry_run":false,"wynik":{
  "projekt":"sklep","tryb":"M","etap":"- `05-plan`: in-progress",
  "zadania":{"todo":3,"in_progress":1,"review":0,"blocked":0,"escalated":0,"done":2,"anulowane":0},
  "zrodlo_zadan":"github","eskalacje":[],"wstrzymania":[]}}
```

## stop-all

```sh
shctl stop-all [--projekt NAZWA]
```

Zamyka panele herdr, zachowuje worktree, zapisuje `~/sh/stan/NAZWA.json` i wysyła `notify.sh high`.
shctl nie wznawia pracy sam (`proces-v1.md`, „Awaryjny stop”).

| Panel | Bez `--projekt` | Z `--projekt NAZWA` |
|---|---|---|
| `worker:NAZWA:NR`, `review:NAZWA:NR`, `qa:NAZWA:NR` | zamykany | tylko tego projektu |
| Agent z katalogiem w `~/sh/projekty/NAZWA` | zamykany | tylko tego projektu |
| `orkiestrator:NAZWA` | zamykany | tylko tego projektu |
| `orkiestrator` (wspólny) | zamykany | zostaje, bo obsługuje inne projekty |
| `powloka`, panele bez agenta | zostają | zostają |

Etykiety `worker:NAZWA:NR` i pokrewne to konwencja, której musi trzymać się `shctl task dispatch`.

Kolejność: stan, workerzy, powiadomienie, wynik, potem orkiestrator, a na samym końcu panel, z
którego działa shctl, bo po jego zamknięciu proces już nie żyje. `--dry-run` wypisuje tę kolejność
(pole `kolejnosc`). Powtórka bez paneli zachowuje zapisany stan. Stan
zawiera panele, etap, gałąź, HEAD, liczbę niezacommitowanych plików i listę worktree.

```json
{"ok":true,"komenda":"stop-all","dry_run":false,"wynik":{
  "panele":[{"pane_id":"w1:p3","label":"worker:sklep:12","cwd":"/Users/.../wt/12","agent":"claude",
    "agent_status":"working","rodzaj":"worker","projekt":"sklep"}],
  "stan":["/Users/.../sh/stan/sklep.json"]}}
```

## obsidian

```sh
shctl obsidian link NAZWA
shctl obsidian unlink NAZWA
```

Obsidian działa na tym samym Macu i służy **głównie do czytania** dokumentacji. Odpowiedzi na
eskalacje idą przez czat z orkiestratorem i `shctl escalate close`, a nie przez edycję plików w
vaulcie. Źródłem prawdy pozostaje repo w `~/sh/projekty`.

`link` zakłada dla projektu założonego wcześniej to samo, co `new-project`: klon
`git clone --filter=blob:none --sparse` i `git sparse-checkout set --no-cone /docs/`. Klon ma tylko
`docs/`, bez kodu, `node_modules` i plików z katalogu głównego; tryb cone zostawiłby te ostatnie. W
Obsidianie wystarczy włączyć Obsidian Git dla tego folderu. Powtórka nic nie zmienia, a katalog
będący czymś innym niż klon tego repo daje kod 4.

`unlink` usuwa klon przy archiwizacji. Odmawia (kod 4) przy niezacommitowanych zmianach, plikach
nieśledzonych i niewypchniętych commitach oraz gdy katalog nie jest klonem tego repo. Brak klonu to
sukces bez zmian.

```sh
shctl obsidian link sklep --json
```

```json
{"ok":true,"komenda":"obsidian","dry_run":false,"wynik":{
  "katalog":"/Users/.../Obsidian Vault/SH/Projekty/sklep","utworzono":true}}
```

`unlink` zwraca `{"katalog":"...","usunieto":true}`.

## doctor

```sh
shctl doctor [--test-notify]
```

Sprawdza narzędzia, logowania gh, codex i claude, Docker, serwer herdr, `notify.sh` i temat ntfy,
globalny `core.hooksPath`, lokalny `core.hooksPath` w repo z `~/sh/projekty`, wolne miejsce,
`porty.md`, klony w `SH_OBSIDIAN_DIR` (czy są czyste i zgodne z origin, przez `git ls-remote`, bez
pobierania; różnica to `uwaga`) oraz repo z `~/sh/stan/do-usuniecia.md` (`uwaga`, gdy są).

Repo z listy `doctor` sprawdza przez `gh repo view` i zdejmuje wiersze tych, których już nie ma. To
jego jedyny zapis; przy `--dry-run` tylko je wskazuje. Błąd sieci lub logowania niczego nie zdejmuje
(`niesprawdzone`). Stany: `ok`, `uwaga`, `blad`; tylko `blad` daje kod 1. Domyślnie nic nie wysyła, a
`--test-notify` wysyła prawdziwe powiadomienie.

```json
{"ok":true,"komenda":"doctor","dry_run":false,"wynik":{"bledy":0,"kontrole":[
  {"nazwa":"logowanie gh","stan":"ok","szczegoly":"zalogowany"},
  {"nazwa":"hooki sklep","stan":"uwaga","szczegoly":"lokalny core.hooksPath (.husky) wyłącza globalny pre-push"}]}}
```

## Testy

```sh
bats scripts/shctl/tests
```

Testy używają atrap `gh`, `herdr`, `notify` i `lsof` oraz projektu w katalogu tymczasowym. Pełny test
na GitHubie jest domyślnie pomijany. Uruchamiamy go wyłącznie po wyraźnej zgodzie właściciela w danej
rozmowie (`serwer.md`, „Praca nad systemem”):

```sh
SHCTL_E2E=1 bats scripts/shctl/tests/new-project-e2e.bats
```

Test zakłada prywatne repo `sh-test-RRRRMMDD-HHMM` i przed utworzeniem dopisuje je do
`~/sh/stan/do-usuniecia.md`. Repo usuwa właściciel (`gh repo delete` wymaga zakresu `delete_repo`), a
wiersz z listy zdejmuje kolejny `shctl doctor`.
