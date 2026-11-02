# shctl

CLI z mechaniką procesu (`proces-v1.md`, „Automatyzacja: CLI shctl”). Agent decyduje i pisze treść,
a shctl wykonuje operacje na plikach, GitHubie i panelach herdr. Część 1: komendy projektu i etapów,
część 2: `task`, `review run` i `reset-dryrun` (sekcja „Zadania”).

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

shctl commituje w projekcie tylko w `new-project`. Pozostałe komendy zostawiają zmiany w drzewie
roboczym, a commit na main robi orkiestrator. Wyjątki poza plikami projektu: `task close` commituje
propozycje w osobnej gałęzi `sh-system` i otwiera PR, a `reset-dryrun` przestawia main `sh-dryrun` na
tag (force push). Komendy zmieniające pliki wspólne ostrzegają poza gałęzią `main`.

Zmienne środowiska (dla testów i innego układu):

| Zmienna | Domyślnie |
|---|---|
| `SH_DIR` | `~/sh` |
| `SH_GH_OWNER` | `Sebastian-Temich` |
| `SH_TEMPLATE` | `sh-template-projekt` |
| `SH_NOTIFY_CMD` | `$SH_DIR/bin/notify.sh` |
| `SH_CONFIG` | `~/.config/sh/config` |
| `SH_OBSIDIAN_DIR` | Z `SH_CONFIG`; bez wartości `new-project` pomija klon w vaulcie |
| `SH_SYSTEM_DIR` | `$SH_DIR/sh-system`; repo, do którego `task close` wysyła propozycje |
| `SHCTL_REVIEW_TIMEOUT` | `3600`; limit czekania `review run` na Codexa, w sekundach |
| `SHCTL_TEST_TIMEOUT` | `1800`; limit testów w `task resume-check`, w sekundach |
| `SHCTL_DRYRUN_NAZWA` | `sh-dryrun`; jedyny projekt, na którym działa `reset-dryrun` |
| `CODEX_HOME` | `~/.codex`; tu `review run` szuka profilu `reviewer.config.toml` |
| `SH_CLAUDE_JSON` | `~/.claude.json`; tu `task dispatch` zapisuje zaufanie folderu projektu |

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
| `raport-qa` | `08-qa` | `raport-MN.md` | `--tytul` zaczynający się od kamienia, np. `"M1 Szkielet"` |
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
  "panele":[{"pane_id":"w1:p3","label":"worker:sklep:12","cwd":"/Users/.../sh/wt/sklep/12","agent":"claude",
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

## Zadania

Cykl zadania w etapie A: `task create` → `task ready` → `task dispatch` → praca workera (PR) →
`review run` → przy FAIL `task iter` i znów `review run` → `task close`. Każde zadanie ma `runner:local`
i `wykonawca:claude`, a review robi Codex. Po przerwie: `task resume-check`.

### Pliki, panele, stan

| Rzecz | Miejsce |
|---|---|
| Worktree workera | `~/sh/wt/NAZWA/NR`, gałąź `task/NR-slug` |
| Worktree review | `~/sh/wt/NAZWA/review-NR`, odłączony HEAD na commicie PR, bez plików env |
| Worktree propozycji | `~/sh/wt/NAZWA/sys-propozycje-NR`, gałąź w `sh-system`, usuwany po PR |
| Panel workera | Karta herdr w workspace `sh` z panelem `worker:NAZWA:NR` |
| Panel review | Karta z panelem `review:NAZWA:NR`, zamykana po review |
| Mapa NR → panel | `~/sh/stan/NAZWA.json`, klucz `zadania` (`stop-all` go zachowuje) |
| Wynik review | Komentarz w PR ze znacznikiem `<!-- shctl:review head=SHA werdykt=... -->` |

Każdy projekt ma własny katalog `~/sh/wt/NAZWA`, więc te same numery issue w różnych projektach się
nie zderzają. Gdy katalog worktree istnieje, ale nie jest worktree tego repo, komenda odmawia (kod 4) i
niczego nie nadpisuje. `stop-all` traktuje agenta z katalogiem w `~/sh/wt/NAZWA` jak workera projektu
`NAZWA`, także bez etykiety.

Slug gałęzi to tytuł issue z transliteracją polskich znaków, małe litery, do 40 znaków:
„Zażółć gęślą jaźń: Łódź” daje `task/12-zazolc-gesla-jazn-lodz`. Istniejąca gałąź `task/NR-*` ma
pierwszeństwo, więc zmiana tytułu nie zakłada nowej.

Z `docs/konfiguracja.md` (frontmatter) zadania czytają:

| Pole | Domyślnie | Użycie |
|---|---|---|
| `max_local` | 1 | Limit workerów, liczony z paneli `worker:*` we wszystkich projektach |
| `max_review_queue` | 3 | Tyle otwartych issue w `status:review` zatrzymuje dispatch |
| `min_wolne_gb` | 15 | Mniej wolnego miejsca na dysku projektu zatrzymuje dispatch |
| `env_files` | brak | Lista dodatkowych plików env (ścieżki względne, bez `..`) dla workera |
| `modele.worker` | `opus` | `claude --model`; `domyslny` pomija opcję |
| `modele.reviewer.model` | `domyslny` | `codex exec -m`; „GPT-6.1 Terra” staje się `gpt-6.1-terra` |
| `modele.reviewer.rozumowanie` | brak | `-c model_reasoning_effort="..."` |

### task create

```sh
shctl task create --plik zadania.yaml
```

Hurtowo zakłada issue z pliku YAML: lista zadań albo mapa z kluczem `zadania`.

```yaml
zadania:
  - id: T1                     # wymagane, unikalne w projekcie
    tytul: Schemat bazy        # wymagane
    cel: Tabela users.         # wymagane
    kryteria: [migracja tworzy tabelę]   # wymagane, niepusta lista
    pliki: [supabase/migrations/]
    testy: pnpm test db
    zaleznosci: [T0, "#40"]    # ID z pliku albo numer istniejącego issue
    typ: feature               # feature (domyślnie), bug, qa, docs, cr
    tryb: M                    # S albo M; bez pola brak etykiety tryb:
    db_migracja: true          # etykieta db:migracja
    milestone: M1 Szkielet
    waga: istotne              # krytyczne, istotne, drobne; etykieta sev:X; typ qa: tylko krytyczne albo istotne
```

Etykiety: `status:todo`, `runner:local`, `wykonawca:claude`, `typ:X`, opcjonalnie `tryb:X`,
`db:migracja` i `sev:X`. Treść issue ma sekcje formularza (Cel, Kryteria akceptacji, Zakres, Komenda testów, Typ,
Zależności, Baza danych) i znacznik `<!-- shctl:id=T1 -->`. Issue powstają w kolejności zależności, więc
zależności mają już numery. Brakujące milestone'y komenda zakłada.

Na końcu dopisuje mapę do sekcji „Mapa zadań z planu” w `docs/06-zadania/index.md` (znaczniki
`shctl:mapa`, poza tabelą `sync-status`) i uruchamia `scripts/sync-status.sh`.

Powtórka rozpoznaje issue po znaczniku i niczego nie dubluje; przerwane tworzenie dokańcza. Nieznane
pole, nieznana zależność, cykl, zły typ, tryb lub waga (także `typ: qa` bez wagi `krytyczne` albo `istotne`) dają kod 2 przed jakąkolwiek zmianą. ID użyte już
przez issue o innym tytule daje kod 4.

```json
{"ok":true,"komenda":"task","dry_run":false,"wynik":{
  "mapa":{"T1":12,"T2":13},"utworzone":["T1","T2"],"istniejace":[],
  "milestone_utworzone":["M1 Szkielet"],"indeks":"docs/06-zadania/index.md"}}
```

### task ready

```sh
shctl task ready
```

Tylko czyta. `kandydaci` to otwarte issue `status:todo`, których wszystkie zależności z sekcji
„Zależności” są zamknięte jako wykonane. Zależność otwarta, anulowana lub nieistniejąca trafia do
`zablokowane` z powodem. Z kilku zadań `db:migracja` kandydatem jest tylko pierwsze, a żadne, gdy w
projekcie trwa już takie zadanie (status inny niż `todo`).

Blokady całego dispatchu (`blokady`): brak wolnego slotu `max_local`, wolne miejsce poniżej
`min_wolne_gb`, kolejka review pełna (`max_review_queue`), wstrzymanie Claude w `~/sh/limity.md`.
`gotowe` to kandydaci, gdy blokad nie ma, inaczej pusta lista.

Z `limity.md` liczą się pozycje list i wiersze tabel (bez nagłówka); wpis „brak” nie jest
wstrzymaniem. Wpis ze słowem „codex” wstrzymuje tylko review, każdy inny wstrzymuje workerów Claude.
Brak miejsca wysyła `notify.sh high` raz dziennie (znacznik `~/sh/stan/dysk-alarm`, kasowany, gdy
miejsce wróci).

```json
{"ok":true,"komenda":"task","dry_run":false,"wynik":{
  "gotowe":[{"nr":12,"tytul":"Schemat bazy","db_migracja":true}],"kandydaci":[...],
  "zablokowane":[{"nr":13,"tytul":"Logowanie","db_migracja":false,"powody":["zależność #12 otwarta"]}],
  "blokady":[],"sloty":{"max_local":1,"aktywne":0,"wolne":1},"kolejka_review":{"max":3,"czeka":0},
  "wolne_gb":25,"min_wolne_gb":15,"mozna_dispatch":true}}
```

### task dispatch

```sh
shctl task dispatch NR
```

Przy `status:todo` sprawdza te same warunki co `ready` (własny panel nie zajmuje slotu) i przy
niespełnionym odmawia kodem 4 z powodem. Potem:

1. worktree `~/sh/wt/NAZWA/NR` na gałęzi `task/NR-slug`: istniejąca gałąź lokalna, zdalna albo nowa od
   `origin/main`;
2. kopia `.env.local` i `env_files` z repo głównego do worktree (prawa `go-rwx`); brak pliku to
   ostrzeżenie;
3. zaufanie folderu Claude Code dla repo projektu (sekcja „Zaufanie folderu”);
4. karta herdr z panelem `worker:NAZWA:NR` i w nim
   `SH_NOTIFY=1 claude --settings .claude/roles/worker/settings.json --model MODEL 'Zrealizuj issue #NR skillem sh-worker.'`;
5. etykiety `status:in-progress` i `iter:1`;
6. wpis w `~/sh/stan/NAZWA.json`: panel, etykieta, worktree, gałąź, start, iteracja.

Przy `status:in-progress` dokańcza brakujące kroki bez bramek; agenta, który już działa w panelu, nie
uruchamia drugi raz. Inny status to kod 4. Brak `.claude/roles/worker/settings.json` to kod 3.

```json
{"ok":true,"komenda":"task","dry_run":false,"wynik":{
  "nr":12,"galaz":"task/12-schemat-bazy","worktree":"/Users/.../sh/wt/sklep/12","panel":"w1:p7",
  "label":"worker:sklep:12","env":[".env.local"],"uruchomiono":true,"polecenie":"cd ... && SH_NOTIFY=1 claude ...",
  "zaufanie_dopisane":false,"zmiana":true,"kroki":["worktree ...","env: .env.local","panel worker:sklep:12 i start claude (model opus)"]}}
```

### Zaufanie folderu

Interaktywny `claude` w nieznanym katalogu pyta o zaufanie i czeka na odpowiedź, co zatrzymałoby
workera. Dokumentacja Claude Code (<https://code.claude.com/docs/en/permissions>, „Project allow rules
and workspace trust” i „What runs before you trust a folder”) mówi, że:

- w repo zaufanie dotyczy katalogu głównego repo, a w worktree katalogu głównego głównej kopii;
- zaufanie można nadać ręcznie: `projects["<katalog główny repo>"].hasTrustDialogAccepted = true` w
  `~/.claude.json`;
- zaufanie samego katalogu nadrzędnego (np. `~/sh/wt`) nie wystarcza dla repo w środku.

Dlatego `task dispatch` (i `task iter`, gdy otwiera nowy panel) dopisuje ten wpis dla
`~/sh/projekty/NAZWA`, jeśli go nie ma. Pozostałe pola pliku zostają, zapis jest atomowy z prawami
600, a plik, który nie jest poprawnym JSON, daje kod 1 bez zmian. Pole wyniku `zaufanie_dopisane` mówi,
czy wpis powstał.

Do sprawdzenia w pierwszym prawdziwym dispatchu: czy worker w `~/sh/wt/NAZWA/NR` startuje bez pytania.
Dokumentacja nazywa `~/.claude.json` plikiem, który Claude Code zapisuje sam, więc działająca sesja może
nadpisać wpis starszą kopią; kolejny dispatch dopisze go ponownie. Zaufanie włącza też ustawienia z
repo (hooki, `env`, pomocnicze komendy), a repo projektów powstają z naszego szablonu.

### Format ~/sh/limity.md

Plik prowadzi strażnik limitów `~/sh/bin/sh-watchdog.sh` (A3.7, `docs/serwer.md`, „Strażnik limitów”), a `task ready`, `task dispatch` i `review run` go czytają. Jedna
aktywna blokada to jedna pozycja listy albo jeden wiersz tabeli; nagłówek tabeli i jej separator się
nie liczą. Inne linie (tytuł, akapity, komentarze) są ignorowane.

```markdown
# Limity

| Wykonawca | Od | Do | Źródło |
|---|---|---|---|
| claude | 2026-11-02 14:05 | 2026-11-02 19:00 | panel worker:sklep:12 |
| codex | 2026-11-02 15:30 | 2026-11-02 20:30 | review:sklep:14 |
```

- Wpis zawierający słowo `codex` (wielkość liter bez znaczenia) wstrzymuje tylko `review run`: PR
  czeka w `status:review`, a dispatch działa dalej.
- Każdy inny wpis wstrzymuje workerów Claude: `task ready` zgłasza blokadę `limit`, a `task dispatch`
  odmawia (kod 4). Nazwę `claude` warto więc wpisywać jawnie.
- Brak wstrzymań to plik bez pozycji i wierszy albo jedna pozycja `brak` (także `- (brak)`, `*brak*`,
  `| brak |`). Brak pliku też oznacza brak wstrzymań.
- Po odnowieniu limitu strażnik usuwa wpis. Godzina „Do” jest dla ludzi; shctl jej nie interpretuje.
- Strażnik zapisuje „Od” i „Do” jako `RRRR-MM-DD GG:MM` w czasie lokalnym, a „Źródło” jako
  `panel ETYKIETA (ID)`. Godzinę szacowaną (komunikat bez godziny) oznacza dopiskiem „(szacunek)”.
  Ręcznie dopisane pozycje listy i wiersze tabeli zostawia bez zmian; wiersz w formacie strażnika
  usuwa, gdy jego „Do” minie.

`status show` pokazuje te same wpisy jako „Wstrzymania”.

### review run

```sh
shctl review run PR [--timeout SEKUNDY]
```

Zadanie wynika z `Closes #NR` albo gałęzi `task/NR-` (review PR). PR z gałęzi `stage/ETAP` bez
`Closes` to review etapu: wymaga `docs/ETAP/DoD.md`, nie ma issue ani etykiet, a worktree, panel i
pliki robocze mają w nazwie `ETAP` zamiast `NR`. Kolejno:

1. etykieta `status:review` na issue (tylko review PR), na czas oczekiwania;
2. przy wstrzymaniu Codexa w `limity.md` koniec z kodem 4: PR czeka w kolejce;
3. czysty worktree `~/sh/wt/NAZWA/review-NR` na commicie PR (`git fetch origin pull/PR/head`), bez plików
   env; plik `.env*` (poza `.env.example`) w samym PR daje kod 4;
4. karta z panelem `review:NAZWA:NR` i w nim
   `codex exec -p reviewer -s read-only -m MODEL --output-schema codex/sh-review.schema.json -o ... - < prompt`;
5. czekanie na wynik (limit `--timeout`, domyślnie `SHCTL_REVIEW_TIMEOUT`);
6. komentarz w PR z werdyktem i zgłoszeniami;
7. usunięcie worktree review i zamknięcie panelu, także po błędzie.

Prompt to `codex/sh-review.md`, generowany ze skilla `sh-review` przez `scripts/sync-codex.sh`
(brak pliku to kod 3), z dopisanym kontekstem: repo, tryb review (PR albo
etap), PR i gałąź, zadanie albo etap z `DoD.md`, iteracja, zakres diffu, treść issue jako dane i
poprzednie review jako dane. Iteracja pochodzi z etykiety `iter:N` issue albo z pola `iteracja` w
`docs/ETAP/DoD.md` na commicie PR. Poprzednie review to ostatni komentarz review w PR dla innego
commita (bez ukrytej linii danych); w pierwszej iteracji „Brak.”. Profil
`$CODEX_HOME/reviewer.config.toml` (źródło `codex/reviewer.config.toml`, `serwer.md`, „Codex”) ustawia
tylko odczyt i model reviewera; bez niego komenda ostrzega i działa na konfiguracji bazowej.
`-s read-only` jest podawane zawsze.

Format komentarza opisuje `templates/review.md`. Wynik czytany przez `task iter` i `task close`
pochodzi z ukrytej linii danych, którą dopisuje `review run`, a gdy jej nie ma (komentarz napisany
przez skill albo ręcznie), z treści komentarza w tym formacie. Werdykt liczy shctl ze zgłoszeń: FAIL, gdy jest choć jedno `krytyczne` albo `istotne`, inaczej PASS.
Rozbieżny werdykt modelu jest odnotowany w komentarzu. Kod wyjścia 0 przy obu werdyktach. Powtórka dla
tego samego commita nie woła Codexa i zwraca wynik z komentarza (`"ponownie":true`). Nowy commit w PR
wymaga nowego review.

W review etapu `nr` jest `null`, a `etap` to nazwa folderu. `task iter` i `task close` dotyczą tylko
zadań: iterację etapu podbija orkiestrator w `DoD.md`, a status zmienia `shctl stage`.

Pliki robocze: `~/sh/stan/review/NAZWA-NR/` (prompt, wynik, `codex.log` z wyjściem panelu). Błąd
Codexa (np. limit) daje kod 1, a issue zostaje w `status:review`.

```json
{"ok":true,"komenda":"review","dry_run":false,"wynik":{
  "pr":20,"nr":12,"etap":null,"head":"68373f5...","werdykt":"FAIL","podsumowanie":"...",
  "zgloszenia":[{"waga":"istotne","plik":"src/a.ts","linia":4,"opis":"brak walidacji"}],
  "blokujace":1,"ponownie":false}}
```

### task iter

```sh
shctl task iter NR
```

Tylko po FAIL review dla bieżącego commita otwartego PR; bez takiego wyniku albo przy PASS kod 4.
Podbija `iter:N` na `iter:N+1`, ustawia `status:in-progress` i wysyła do panelu `worker:NAZWA:NR`
polecenie: popraw wyłącznie zgłoszenia 🔴 i 🟡 z ostatniego review. Bez panelu otwiera go w
`~/sh/wt/NAZWA/NR` i uruchamia claude z tym poleceniem.

Powtórka dla tego samego review nie podbija licznika i nie wysyła polecenia drugi raz (stan w
`~/sh/stan/NAZWA.json`). FAIL w iteracji 3 wywołuje `shctl escalate --dotyczy "#NR" --powod "3 iteracje
bez PASS"`: wynik ma `"eskalowano":true` i numer eskalacji, a etykieta `iter:3` zostaje.

### task close

```sh
shctl task close NR
```

Działa w repo głównym na `main` (inaczej kod 4). Przy otwartym PR merguje (squash,
`--match-head-commit`) wyłącznie, gdy CI jest zielone (`pass`; `pending`, `fail` i brak kontroli to
kod 4) i komentarz review dla bieżącego commita ma PASS. Odmawia też, gdy `~/sh/wt/NAZWA/NR` ma
niezacommitowane zmiany albo commity spoza PR. Potem, na main po `git pull --ff-only`:

| Źródło | Cel |
|---|---|
| „Decyzje” z `docs/07-realizacja/T-NR.md` | `docs/decyzje.md`; `pytanie → decyzja` dzieli kolumny, inaczej Pytanie to `-` |
| „Drobne uwagi” z raportu | `docs/backlog-drobne.md`, stan `otwarta` |
| Zgłoszenia ⚪ z ostatniego review (komentarz w PR) | `docs/backlog-drobne.md`, źródło `review PR #N` |
| Czas od dispatchu, iteracje, eskalacje | Wiersz `| #NR tytuł | tryb | czas | 1 | iteracje | eskalacje | PR #N |` w `docs/metryki.md` |
| Tytuł i PR | `- #NR: tytuł (PR #N)` w sekcji „Niewydane” `CHANGELOG.md` |
| „Propozycje dla systemu” | PR do `sh-system`: gałąź `propozycje/NAZWA-T-NR`, wpis w `docs/propozycje.md` |

Pozycje sekcji to punkty listy (z kontynuacją) albo akapity; „brak” jest pomijane. Na końcu usuwa
worktree, gałąź `task/NR-*` i panel, zamyka issue, zdejmuje etykiety `status:*`, uruchamia
`scripts/sync-status.sh` i kasuje wpis zadania w stanie. Zmian w plikach wspólnych nie commituje.

Powtórka po merge'u pomija gotowe kroki: wiersze nie są dopisywane drugi raz, a istniejący PR propozycji
(także scalony) nie powstaje ponownie. Nieudany krok poboczny (PR propozycji, panel, sync-status) daje
kod 1 po wykonaniu pozostałych; powtórka go dokańcza.

### task resume-check

```sh
shctl task resume-check NR [--testy "..."] [--bez-testow]
```

Stan po przerwie, do decyzji orkiestratora (kontynuuj, rebase i kontynuuj, iteracja od nowa).
Zwraca: status i iterację z etykiet, panel, a dla `~/sh/wt/NAZWA/NR` gałąź, HEAD, listę niezacommitowanych
plików, liczbę commitów za i przed `origin/main`, niewypchnięte commity i wynik testów. Komenda testów
pochodzi z sekcji „Komenda testów” issue albo z `--testy`; uruchamia się w worktree z limitem
`SHCTL_TEST_TIMEOUT`. Pole `sugestia` to tylko podpowiedź.

Komenda nie zmienia etykiet: przerwanie przez limit nie podbija iteracji.

```json
{"ok":true,"komenda":"task","dry_run":false,"wynik":{
  "nr":12,"status":"in-progress","iteracja":1,"worktree":"/Users/.../sh/wt/sklep/12","worktree_istnieje":true,
  "git":{"galaz":"task/12-schemat-bazy","head":"...","ostatni_commit":"a1b2c3d #12: ...",
    "niezacommitowane":["?? src/nowy.ts"],"za_main":1,"przed_main":2,"niewypchniete":0},
  "testy":{"komenda":"pnpm test","kod":0,"wynik":"pass","koniec_wyjscia":"..."},
  "panel":{"pane_id":"w1:p7","label":"worker:sklep:12","agent":"claude","agent_status":"idle"},
  "sugestia":"rebase i kontynuuj","uwaga":"przerwanie przez limit nie podbija iteracji"}}
```

### reset-dryrun

```sh
shctl reset-dryrun
```

Przywraca projekt wzorcowy `sh-dryrun` do tagu `baseline` (`proces-v1.md`, „Projekt wzorcowy”). Inny
projekt to kod 4, brak tagu albo pliku zadań w tagu to kod 3. Kolejno: zamyka panele projektu, usuwa
jego worktree i gałęzie `task/*`, zamyka otwarte PR (z usunięciem gałęzi), otwarte issue zamyka jako
„not planned” ze znacznikiem zmienionym na `shctl:archiwum-id`, resetuje main do tagu i wypycha go
(`--force-with-lease`), czyści mapę zadań w stanie i odtwarza issue przez `task create` z
`zadania.yaml` albo `docs/06-zadania/zadania.yaml` z tagu.

Gdy main jest na tagu, nie ma otwartych PR, paneli ani worktree, a otwarte issue to dokładnie zadania z
pliku w `status:todo` bez iteracji, komenda nic nie robi (`"zmiana":false`).

## Testy

```sh
bats scripts/shctl/tests
```

Testy używają atrap `gh`, `herdr`, `notify` i `lsof` oraz projektu w katalogu tymczasowym. Testy zadań
(`task-*.bats`, `review.bats`, `reset-dryrun.bats`) mają stanowe atrapy w `tests/atrapy/`: `gh`
(issue, PR, komentarze, CI, milestone'y; merge to prawdziwy squash na lokalnym repo zdalnym), `herdr`
(panele; `pane run` wykonuje komendę od razu), `codex`, `claude` i `df`.

Pełne testy na GitHubie są domyślnie pomijane. Uruchamiamy je wyłącznie po wyraźnej zgodzie
właściciela w danej rozmowie (`serwer.md`, „Praca nad systemem”):

```sh
SHCTL_E2E=1 bats scripts/shctl/tests/new-project-e2e.bats
SHCTL_E2E=1 bats scripts/shctl/tests/task-e2e.bats
```

`task-e2e.bats` zakłada projekt z szablonu, `task create` z jednym trywialnym zadaniem, `dispatch`, pracę
workera wykonuje sam (commit, push, PR), czeka na CI, uruchamia `review run` z prawdziwym Codexem i
`task close`. herdr i claude są atrapami; `SHCTL_E2E_CODEX=atrapa` zastępuje też Codexa.

Każdy test zakłada prywatne repo `sh-test-RRRRMMDD-HHMM` i przed utworzeniem dopisuje je do
`~/sh/stan/do-usuniecia.md`. Repo usuwa właściciel (`gh repo delete` wymaga zakresu `delete_repo`), a
wiersz z listy zdejmuje kolejny `shctl doctor`.
