# shctl

CLI z mechaniką procesu (`proces-v1.md`, „Automatyzacja: CLI shctl”). Agent decyduje i pisze treść,
a shctl wykonuje operacje na plikach, GitHubie i panelach herdr. Część 1: komendy projektu i etapów,
część 2: `task`, `review run`, `reset-dryrun`, `template update` i `sprzataj` (sekcja „Zadania”).

Źródło: `scripts/shctl/` (`shctl`, `cmd/` z podkomendami, `lib/`, `tests/`). `install.sh` zakłada
symlink `/Users/Shared/sh/bin/shctl`. Zależności: bash 3.2+, gh, jq, yq (mikefarah), git, herdr.

## Zasady wspólne

| Opcja | Działanie |
|---|---|
| `--dry-run` | Pokazuje, co by się stało. Nie zapisuje plików, nie zmienia GitHuba, nie zamyka paneli, nie powiadamia |
| `--json` | Na stdout dokładnie jeden dokument JSON, także przy błędzie |
| `--projekt NAZWA` | Projekt z `/Users/Shared/sh/projekty/NAZWA`; bez opcji projekt z bieżącego katalogu, także z worktree |

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
{"ok":false,"komenda":"stage","kod":4,"blad":"stage done niedozwolone dla 04-plan w statusie todo"}
```

Komunikaty błędów i ostrzeżenia idą na stderr. Każde wywołanie dopisuje linię do
`/Users/Shared/sh/logs/shctl.log` (czas, kod, `dry`, projekt, komenda i argumenty ucięte do 400 znaków).

shctl commituje na main projektu tylko w `new-project` i `template update`; `skrzynka przyjmij`
merguje własny PR. Pozostałe komendy zostawiają zmiany w drzewie
roboczym, a commit na main robi orkiestrator. Wyjątki poza plikami projektu: `task close` dopisuje
propozycje jako komentarz do issue miesiąca „Propozycje RRRR-MM” (etykieta `propozycja`) w
`sh-system`, a `reset-dryrun` przestawia main `sh-dryrun` na
tag (force push). Komendy zmieniające pliki wspólne ostrzegają poza gałęzią `main`.

Zmienne środowiska (dla testów i innego układu):

| Zmienna | Domyślnie |
|---|---|
| `SH_DIR` | `/Users/Shared/sh` |
| `SH_GH_OWNER` | `Sebastian-Temich` |
| `SH_TEMPLATE` | `sh-template-projekt` |
| `SH_NOTIFY_CMD` | `$SH_DIR/bin/notify.sh` |
| `SH_CONFIG` | `~/.config/sh/config` |
| `SH_OBSIDIAN_DIR` | Z `SH_CONFIG`; bez wartości `new-project` pomija klon w vaulcie |
| `SH_SKRZYNKA_DIR` | `Skrzynka` obok `SH_OBSIDIAN_DIR` (`Obsidian Vault/SH/Skrzynka`); skrzynki na materiały |
| `SH_SYSTEM_DIR` | `$SH_DIR/sh-system`; repo, do którego `task close` wysyła propozycje |
| `SH_WARSTWY_SKILLI` | `sh-system/plugin/warstwy-skilli.yaml`; mapa warstw skilli workera (`task dispatch`) |
| `SH_SKILLE_PLUGINU` | `sh-system/plugin/skills`; gdzie `task dispatch` sprawdza skille pluginu |
| `SHCTL_REVIEW_TIMEOUT` | `3600`; limit czekania `review run` na Codexa, w sekundach |
| `SHCTL_TEST_TIMEOUT` | `1800`; limit testów w `task resume-check`, w sekundach |
| `SHCTL_READY_PAUZA` | `30`; odstęp sprawdzania blokad w `task ready --czekaj`, w sekundach |
| `SHCTL_FNM_LIMIT` | `300`; limit `fnm install` w `task dispatch`, w sekundach |
| `SHCTL_DRYRUN_NAZWA` | `sh-dryrun`; jedyny projekt, na którym działa `reset-dryrun` |
| `CODEX_HOME` | `~/.codex`; tu `review run` szuka profilu `reviewer.config.toml` |
| `SH_CLAUDE_JSON` | `~/.claude.json`; tu `task dispatch` zapisuje zaufanie folderu projektu |

Plik `~/.config/sh/config` jest poza repo. shctl czyta z niego linię
`SH_OBSIDIAN_DIR="/ścieżka/do/vaulta/SH/Projekty"` jako dane, bez `source`. Zmienna środowiska ma pierwszeństwo.

## new-project

```sh
shctl new-project NAZWA --opis "krótki opis repo" [--zlecenie "..."] [--tryb S|M] [--prywatny]
```

Kolejno (SH-lite F5): repo `SH_GH_OWNER/NAZWA` jako zwykłe repo, bez „generated from” (`gh repo create`
bez `--template`), domyślnie publiczne; pliki szablonu `SH_TEMPLATE` (płytki klon, bez historii) w
`/Users/Shared/sh/projekty/NAZWA` jako pierwszy commit „Projekt NAZWA z sh-template-projekt@SHA”, z
nazwą i opisem w `README.md`; opis, temat `sh-projekt` i usuwanie gałęzi po merge'u jednym
`gh repo edit` (`lib/repo.sh`), `setup-labels.sh`,
frontmatter `konfiguracja.md` (`tryb_procesu`, `etap_wdrozenia: A`, `data`,
`blok_portow`), blok portów w `porty.md` (zwalnia się ręcznie), `supabase/config.toml`, jeśli
istnieje, `pominiety` dla wszystkich etapów w trybie S, widok `docs/Projekt.md` (`sync-status.sh`), zlecenie w
`docs/00-intake/zrodlo.md`, `check-dod.sh`, commit, `gitleaks git` (sekret: kod 4, bez pushu) i push
na main, ruleset `sh-ochrona-galezi` (zakaz usuwania i force push na `main` i `production`; w repo
prywatnym bez GitHub Pro tylko ostrzeżenie). Na
końcu zakłada lekki klon `docs/` w `SH_OBSIDIAN_DIR/NAZWA` (sekcja „obsidian”) i skrzynkę na
materiały `SH_SKRZYNKA_DIR/NAZWA` (sekcja „skrzynka”). Klon aktualizuje serwer
(`obsidian-sync.sh`, `docs/serwer.md`, „Synchronizacja Obsidiana”); w Obsidianie nic nie trzeba włączać.

| Argument | Znaczenie |
|---|---|
| `--tryb` | Domyślnie M. S działa z ostrzeżeniem, bo proces zaczyna nowy projekt od M. L daje kod 2 (tryb odłożony) |
| `--opis` | Wymagany: opis repo na GitHubie, do 350 znaków (dłuższy: kod 2) |
| `--zlecenie` | Treść zlecenia, trafia do `docs/00-intake/zrodlo.md` |
| `--prywatny` | Repo prywatne, tylko na wyraźne polecenie właściciela: zmienna repo `SH_RUNS_ON` = `["self-hosted","sh-imac"]`, więc CI czeka na runner serwera (`serwer.md`, „Runner dla repo prywatnych”) |
| `--public` | Przestarzałe: publiczne jest domyślne (ostrzeżenie) |

Odmawia (kod 4), gdy repo istnieje i nie jest projektem SH (bez tematu `sh-projekt`, nie z szablonu i
niepuste), katalog jest klonem innego repo, `gitleaks` znajdzie sekret albo `--tryb`
różni się od trybu istniejącego projektu. Powtórka commituje tylko pliki, które sama zmienia.

```sh
shctl new-project sklep --opis "Sklep z kawą: zamówienia online i płatność kartą" --zlecenie "Klienci zamawiają kawę online i płacą kartą" --json
```

```json
{"ok":true,"komenda":"new-project","dry_run":false,"wynik":{
  "repo":"Sebastian-Temich/sklep","katalog":"/Users/.../sh/projekty/sklep","tryb":"M",
  "kroki":["utwórz repo ...","sklonuj do ..."],
  "porty":{"projekt":"sklep","baza":"551","zakres":"55121-55129","api":"55121","db":"55122",
    "studio":"55123","mail":"55124","inspector":"55125","dev":"55126","analytics":"55127",
    "shadow":"55128","pooler":"55129"},
  "obsidian":{"katalog":"/Users/.../Obsidian Vault/SH/Projekty/sklep","utworzono":true,
    "skrzynka":{"katalog":"/Users/.../Obsidian Vault/SH/Skrzynka/sklep","utworzono":true}}}}
```

Przy `--dry-run` pole `porty` to sam zakres, np. `"55121-55129"`.

## stage

```sh
shctl stage start|review|iter|done|escalate ETAP [--notatka "..."]
```

Jedna komenda etapu z akcjami; `iter` nie przyjmuje `--notatka`. `ETAP` to nazwa folderu, np.
`00-intake`, `04-plan`, `wydanie`. Zestaw etapów zależy od `wersja_procesu` w `docs/konfiguracja.md`
projektu: `2` to `00-intake`, `04-plan`, `06-zadania`, `08-qa`, `wydanie`; brak pola (wersja 1,
projekty sprzed migracji) to `04-architektura` i `05-plan` zamiast `04-plan`. Etap spoza wersji
projektu to kod 2. Mapowanie etapów trybu M:
`proces-v1.md`, „Definition of Done”. Komenda zmienia `status` w `DoD.md`, sekcję „Bieżący etap” i
„Dziennik etapów” w `Projekt.md`.

| Akcja | Dozwolone z | Wynik |
|---|---|---|
| `start` | `todo`, `review`, `escalated`, `in-progress` | `in-progress` |
| `review` | `in-progress`, `review` | `review` |
| `done` | `review`, `done` | `done`, po zielonym `check-dod.sh` |
| `escalate` | `todo`, `in-progress`, `review`, `escalated` | `escalated` |

`done` uruchamia `check-dod.sh` na repo i na kopii `docs/` ze statusem `done`; przy brakach kończy
się kodem 4, a status zostaje. Komendy pominięcia nie ma: orkiestrator zapisuje decyzję
(`decision add`) i ustawia w `DoD.md` na `main` `status: pominiety` oraz `decyzja: "..."`;
`check-dod.sh` odrzuca `pominiety` bez decyzji, a `stage` nie zmienia statusu `pominiety`. Etapy z
`DoD.md` według wersji procesu (wyżej) (tryb L z
etapami `01`–`03` jest odłożony, `07-realizacja` nie ma `DoD.md`). `stage escalate`
zmienia tylko status: eskalację z plikiem i powiadomieniem otwiera `shctl escalate`. Etap czekający
na coś zewnętrznego to `stage start ETAP --notatka "czeka na ..."`.

```sh
shctl stage review 04-plan --notatka "gotowe do review" --json
```

```json
{"ok":true,"komenda":"stage","dry_run":false,"wynik":{
  "projekt":"sklep","etap":"04-plan","poprzedni":"in-progress","status":"review","zmiana":true}}
```

### stage iter

Po FAIL review etapu: podbija `iteracja` w `docs/ETAP/DoD.md` i ustawia `in-progress`, oba pola na
main (`proces-v1.md`, „Pliki wspólne i konflikty”). Gałąź `stage/ETAP` frontmattera nie zmienia, więc
PR etapu nie ma konfliktu z main. Wymaga otwartego PR z gałęzi `stage/ETAP` i wyniku `review run` FAIL
dla jego bieżącego commita (inaczej kod 4). Iteracja 0 liczy się jak 1. Powtórka dla tego samego
review nic nie zmienia (`.etapy[ETAP].iter_review` w `/Users/Shared/sh/stan/NAZWA.json`). Limit
iteracji: etapy dokumentowe `00-intake`, `04-plan` (v1: `04-architektura`, `05-plan`) i `06-zadania` mają najwyżej
jedną iterację poprawek, więc FAIL w iteracji 2 otwiera eskalację przez `shctl escalate` zamiast
podbicia (review w iteracji 2 daje istotne uwagi jako ⚪ „(do decyzje.md)”, więc FAIL oznacza 🔴).
Etap `wydanie`: eskalacja po FAIL w iteracji 3. `08-qa` nie ma review etapu: `stage iter 08-qa` to
kod 4.

```json
{"ok":true,"komenda":"stage","dry_run":false,"wynik":{"etap":"wydanie","pr":35,"iteracja":2,"eskalowano":false,"zmiana":true}}
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

## repo opis

```sh
shctl repo opis [--opis "..."] [--topics "a,b"] [--website https://…] [--dry-run] [--json]
```

Opis (do 350 znaków), tematy (zawsze z `sh-projekt`) i strona repo projektu przez `gh repo edit`.
Orkiestrator wywołuje ją na checkpointach specyfikacji, planu i odbioru: najpierw `--dry-run`, który
wypisuje dokładną komendę `gh repo edit …` do pokazania właścicielowi, potem po jego zgodzie bez
`--dry-run`. JSON: `repo`, `komenda`, `opis`, `tematy`, `strona`. `gh repo edit` poza shctl jest w
procesie zabronione.

## escalate

```sh
shctl escalate --dotyczy "#NR|ETAP" --powod "..." --potrzebne "..." [--opcje "A;B"] [--priorytet high] [--akceptacja]
                [--typ blokada|pytanie]
shctl escalate close E-NNN --odpowiedz "..."
```

Otwarcie: tworzy `docs/07-realizacja/escalations/E-NNN.md`, ustawia etykietę `status:escalated` na
issue albo status `escalated` etapu, zapisuje `otwarto` (UTC), odświeża widok `docs/Projekt.md`
(`sync-status.sh`: „Czeka na Ciebie”, „Eskalacje i pytania”) i woła
`notify.sh` (domyślnie `high`). Plik ma frontmatter ze stanem: `status`, `dotyczy`, `powod`,
`priorytet`, `poprzedni_status`, `powiadomiono`.

`--akceptacja` oznacza decyzję do akceptacji właściciela, dziś propozycję podniesienia trybu
(`proces-v1.md`, „Zasady” trybów). Plik, etykieta i status są takie same, a powiadomienie ma tytuł
„Czeka na Twoją akceptację: NAZWA / podniesienie trybu” i treść `E-NNN, DOTYCZY: POWÓD`.

`--typ pytanie` (SH-lite F4) to pytanie workera o UX albo regułę biznesową, której nie rozstrzyga karta
funkcji ani issue (`sh-worker`, „Pytania”). Plik ma `typ: pytanie`, a komenda nie zmienia etykiety
issue ani statusu etapu, nie zwalnia slotu i nie wymaga `poprzedni_status`. Powiadomienie: „Pytanie
E-NNN: NAZWA”, domyślnie `default`. W `Projekt.md` wpis ma rodzaj „pytanie”,
w `status show --json` pole `typ`. `task close` liczy pytania osobno („pytania: N” w „Uwagach”
metryk), nie w kolumnie „Eskalacje”. Zamknięcie pytania nie rusza etykiet. `--akceptacja` z pytaniem
to błąd użycia (kod 2). Domyślny typ to `blokada` (dotychczasowe zachowanie).

Powtórka z tym samym `--dotyczy` i `--powod` dotyczy tej samej otwartej eskalacji. Nieudane
powiadomienie daje kod 1, a ponowienie komendy wysyła je jeszcze raz.

Wywołanie z worktree (worker, skill etapu) zapisuje plik i `Projekt.md` w głównej kopii projektu
(`/Users/Shared/sh/projekty/NAZWA`), która musi stać na main (inaczej kod 4); worktree zostaje
nietknięty, a commit robi orkiestrator. Numer E-NNN przydziela się pod blokadą w `.git` projektu, więc
numeracja jest jedna dla projektu.

Eskalacja zadania zwalnia slot workera: panel `worker:NAZWA:NR` dostaje etykietę `eskalacja:NAZWA:NR`
i przestaje liczyć się do `max_local`. Panel zostaje (worker może dokończyć raport, właściciel czyta
kontekst). Po rozstrzygnięciu `task dispatch NR` sprawdza wolny slot i przywraca etykietę workera.

Zamknięcie: zapisuje odpowiedź w „Rozstrzygnięcie”, przywraca poprzedni status issue lub etapu i
usuwa wpis z `Projekt.md`. Gdy na to samo zadanie czeka inna otwarta eskalacja, etykieta zostaje.
Błąd gh zostawia eskalację otwartą. Powtórka z tą samą odpowiedzią nic nie zmienia, a z inną kończy
się kodem 4.

```sh
shctl escalate --dotyczy "#12" --powod "brak klucza Stripe" --potrzebne "klucz testowy" --opcje "czekać;mock" --json
```

```json
{"ok":true,"komenda":"escalate","dry_run":false,"wynik":{
  "id":"E-001","typ":"blokada","dotyczy":"#12","plik":"docs/07-realizacja/escalations/E-001.md",
  "katalog":"/Users/Shared/sh/projekty/sklep","z_worktree":false,"nowa":true,"slot_zwolniony":true,"panel":"w1:p7"}}
```

## status show

```sh
shctl status show
```

Krótkie podsumowanie dla właściciela: etap, zadania według statusu, otwarte eskalacje, wstrzymania z
`/Users/Shared/sh/limity.md`. Zadania pochodzą z GitHuba, a gdy jest niedostępny, z liczników `Projekt.md`
(`zrodlo_zadan`). Z `limity.md` bierze pozycje list i wiersze tabeli bez nagłówka (sekcja „Format
/Users/Shared/sh/limity.md”). Komenda tylko czyta.

```json
{"ok":true,"komenda":"status","dry_run":false,"wynik":{
  "projekt":"sklep","tryb":"M","etap":"- `04-plan`: in-progress",
  "zadania":{"todo":3,"in_progress":1,"review":0,"blocked":0,"escalated":0,"done":2,"anulowane":0},
  "zrodlo_zadan":"github","eskalacje":[],"wstrzymania":[]}}
```

## stop-all

```sh
shctl stop-all [--projekt NAZWA]
```

Zamyka panele herdr, zachowuje worktree, zapisuje `/Users/Shared/sh/stan/NAZWA.json` i wysyła `notify.sh high`.
shctl nie wznawia pracy sam (`proces-v1.md`, „Awaryjny stop”).

| Panel | Bez `--projekt` | Z `--projekt NAZWA` |
|---|---|---|
| `worker:NAZWA:NR`, `review:NAZWA:NR`, `qa:NAZWA:NR` | zamykany | tylko tego projektu |
| Agent z katalogiem w `/Users/Shared/sh/projekty/NAZWA` | zamykany | tylko tego projektu |
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
vaulcie. Źródłem prawdy pozostaje repo w `/Users/Shared/sh/projekty`.

`link` zakłada dla projektu założonego wcześniej to samo, co `new-project`: klon
`git clone --filter=blob:none --sparse` i `git sparse-checkout set --no-cone /docs/`. Klon ma tylko
`docs/`, bez kodu, `node_modules` i plików z katalogu głównego; tryb cone zostawiłby te ostatnie.
Aktualizuje go serwer (sekcja „Synchronizacja”), a w Obsidianie nie trzeba niczego włączać. Powtórka nic nie zmienia, a
katalog będący czymś innym niż klon tego repo daje kod 4.

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

`link` zakłada też skrzynkę na materiały, jeśli jej brak (sekcja „skrzynka”); wynik ma pole
`skrzynka` jak w `new-project`. `unlink` skrzynki nie usuwa i zwraca `{"katalog":"...","usunieto":true}`.

### Synchronizacja

Komendy `obsidian sync` już nie ma (SH-lite F3b). Klony aktualizuje skrypt serwera
`scripts/server/obsidian-sync.sh`, uruchamiany przez LaunchAgent `pl.iskt.softwarehouse.obsidian-sync`
co 5 minut (`docs/serwer.md`, „Synchronizacja Obsidiana”). W każdym klonie w `SH_OBSIDIAN_DIR` i w
klonie `sh-system` robi zwykłe `git pull --ff-only`. Bez merge'a, resetu, pliku stanu i powiadomień.
Nieudany pull to wpis w `/Users/Shared/sh/logs/obsidian-sync.log`. Klon z problemem naprawia
właściciel albo orkiestrator (np. usunięcie i `shctl obsidian link`).

## skrzynka

```sh
shctl skrzynka przyjmij NAZWA
```

Skrzynka to zwykły folder w vaulcie, `SH_SKRZYNKA_DIR/NAZWA` (domyślnie
`Obsidian Vault/SH/Skrzynka/NAZWA`), do którego właściciel wrzuca materiały: makiety i eksport z Claude
Design, logo, teksty. Nie jest repo git i synchronizacja Obsidiana go nie dotyka. Zakłada go
`new-project` albo `obsidian link`.

`przyjmij` robi wszystko w jednym wywołaniu:

1. kopiuje pliki ze skrzynki do `docs/00-intake/zrodla` z zachowaniem podkatalogów i prawami 644;
   pomija pliki i katalogi ukryte, `_przeniesione`, `__MACOSX` i dowiązania symboliczne;
2. na nowej gałęzi `skrzynka/RRRRMMDD-HHMMSS` (worktree w `/Users/Shared/sh/wt/NAZWA`, baza `origin/main`)
   robi commit „00-intake: materiały ze skrzynki”, push i PR do `main`;
3. czeka na CI (`pr check --czekaj`);
4. przy zielonym CI merguje PR (squash, usunięcie gałęzi) i opróżnia skrzynkę: usuwa skopiowane pliki
   i puste katalogi.

Czerwone CI: kod 4, PR zostaje otwarty, skrzynka bez zmian. Pusta skrzynka: `stan: pusto`. Brak
skrzynki: kod 3. `--dry-run` tylko wypisuje pliki (`stan: do_przyjecia`). Pliki to dane nieufne:
komenda ich nie uruchamia ani nie rozpakowuje. Nie ma już `--etap`, folderu `_przeniesione/`,
filtrowania plików wykonywalnych i ZIP ani pliku stanu `stan/skrzynka/`.

```sh
shctl skrzynka przyjmij sklep --json
```

```json
{"ok":true,"komenda":"skrzynka","dry_run":false,"wynik":{"stan":"przyjeto","pr":7,
  "url":"https://github.com/Sebastian-Temich/sklep/pull/7","pliki":["logo.png","makiety/strona.png"]}}
```

## doctor

```sh
shctl doctor [--test-notify]
```

Sprawdza narzędzia, logowania gh, codex i claude, Docker, serwer herdr, orkiestratora
(`orkiestrator`: w panelu `orkiestrator` workspace `sh` działa proces `claude remote-control` z
katalogiem roboczym `/Users/Shared/sh`, ta sama kontrola co `sh-start.sh` i strażnik, `scripts/server/lib/system.sh`;
`blad`, gdy go nie ma, z PID, gdy taki proces działa poza panelem; `PATH panelu herdr`: `/Users/Shared/sh/bin` w
PATH procesu orkiestratora, brak to `blad`, a gdy orkiestrator nie działa, `uwaga` bez sprawdzenia),
`logowanie git` (git dostaje token dla github.com bez pytania, helper z `install.sh`; brak to `blad`),
`notify.sh` i temat ntfy,
globalny `core.hooksPath`, lokalny `core.hooksPath` w repo z `/Users/Shared/sh/projekty`, wolne miejsce,
`porty.md`, klony w `SH_OBSIDIAN_DIR` (czy są czyste i zgodne z origin, przez `git ls-remote`, bez
pobierania; różnica to `uwaga`) oraz repo z `/Users/Shared/sh/stan/do-usuniecia.md` (`uwaga`, gdy są).
Kontroli „Obsidian sync” już nie ma: synchronizacja nie zapisuje stanu.

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

Cykl zadania w etapie A: `task create` → `task ready` → `task dispatch` → praca workera (`task wait`
do PR z raportem) → `pr check --czekaj` → `review run` → przy FAIL `task iter` i znów `review run` →
`task close`. Po kilku zadaniach `sprzataj` usuwa worktree i gałęzie scalonych PR. Każde zadanie ma `runner:local` i `wykonawca:claude`, a review robi Codex. Po przerwie:
`task resume-check`. Rezygnacja z zadania: `task close --anuluj`.

### Pliki, panele, stan

| Rzecz | Miejsce |
|---|---|
| Worktree workera | `/Users/Shared/sh/wt/NAZWA/NR`, gałąź `task/NR-slug` |
| Worktree review | `/Users/Shared/sh/wt/NAZWA/review-NR`, odłączony HEAD na commicie PR, bez plików env |
| Panel workera | Karta herdr w workspace `sh` z panelem `worker:NAZWA:NR`; po eskalacji `eskalacja:NAZWA:NR` |
| Panel review | Karta z panelem `review:NAZWA:NR`, zamykana po review |
| Mapa NR → panel | `/Users/Shared/sh/stan/NAZWA.json`, klucz `zadania` (`stop-all` go zachowuje) |
| Wynik review | Komentarz w PR ze znacznikiem `<!-- shctl:review head=SHA werdykt=... -->` |

Każdy projekt ma własny katalog `/Users/Shared/sh/wt/NAZWA`, więc te same numery issue w różnych projektach się
nie zderzają. Gdy katalog worktree istnieje, ale nie jest worktree tego repo, komenda odmawia (kod 4) i
niczego nie nadpisuje. `stop-all` traktuje agenta z katalogiem w `/Users/Shared/sh/wt/NAZWA` jak workera projektu
`NAZWA`, także bez etykiety.

Slug gałęzi to tytuł issue z transliteracją polskich znaków, małe litery, do 40 znaków:
„Zażółć gęślą jaźń: Łódź” daje `task/12-zazolc-gesla-jazn-lodz`. Istniejąca gałąź `task/NR-*` ma
pierwszeństwo, więc zmiana tytułu nie zakłada nowej.

Limit workerów Maca: `max_local` we frontmatterze `/Users/Shared/sh/konfiguracja.md` (domyślnie 2,
plik zakłada `install.sh`), liczony z paneli `worker:*` wszystkich projektów. Panele `eskalacja:*`
się nie liczą.

Z `docs/konfiguracja.md` (frontmatter) zadania czytają:

| Pole | Domyślnie | Użycie |
|---|---|---|
| `max_local` | brak | Obniża limit Maca dla projektu; liczy panele `worker:NAZWA:*` tego projektu |
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
    kategoria: baza            # frontend, backend, baza, integracje, bezpieczenstwo, testy, ci, ai-dane, refaktoryzacja
    stack: [supabase]          # nazwa albo lista nazw (małe litery, cyfry, . _ : -)
    skille: [projekt-db]       # dodatkowe skille workera spoza warstw
```

Etykiety: `status:todo`, `runner:local`, `wykonawca:claude`, `typ:X`, opcjonalnie `tryb:X`,
`db:migracja` i `sev:X`. Treść issue ma sekcje formularza (Cel, Kryteria akceptacji, Zakres, Komenda testów, Typ,
Zależności, Baza danych), przy kategorii, stacku albo skillach sekcję „Warstwy skilli” ze znacznikiem
`<!-- shctl:warstwy BASE64 -->` (czyta go `task dispatch`) i znacznik `<!-- shctl:id=T1 -->`. Issue powstają w kolejności zależności, więc
zależności mają już numery. Brakujące milestone'y komenda zakłada.

Na końcu dopisuje mapę do sekcji „Mapa zadań z planu” w `docs/06-zadania/index.md` (znaczniki
`shctl:mapa`, poza tabelą `sync-status`) i uruchamia `scripts/sync-status.sh`.

Powtórka rozpoznaje issue po znaczniku i niczego nie dubluje; przerwane tworzenie dokańcza. Nieznane
pole, nieznana zależność, cykl, zły typ, tryb, waga, kategoria, stack lub skille (także `typ: qa` bez wagi `krytyczne` albo `istotne`) dają kod 2 przed jakąkolwiek zmianą. ID użyte już
przez issue o innym tytule daje kod 4.

```json
{"ok":true,"komenda":"task","dry_run":false,"wynik":{
  "mapa":{"T1":12,"T2":13},"utworzone":["T1","T2"],"istniejace":[],
  "milestone_utworzone":["M1 Szkielet"],"indeks":"docs/06-zadania/index.md"}}
```

### task ready

```sh
shctl task ready [--czekaj] [--timeout SEKUNDY]
```

Tylko czyta. `kandydaci` to otwarte issue `status:todo`, których wszystkie zależności z sekcji
„Zależności” są zamknięte jako wykonane. Zależność otwarta, anulowana lub nieistniejąca trafia do
`zablokowane` z powodem. Z kilku zadań `db:migracja` kandydatem jest tylko pierwsze, a żadne, gdy w
projekcie trwa już takie zadanie (status inny niż `todo`).

Blokady całego dispatchu (`blokady`): brak wolnego slotu `max_local` (limit Maca albo niższy limit
projektu), wolne miejsce poniżej
`min_wolne_gb`, kolejka review pełna (`max_review_queue`), wstrzymanie Claude w `/Users/Shared/sh/limity.md`,
niekompletna lista startowa (`lista_startowa`: pole `- [ ]` poza blokiem kodu w
`docs/00-intake/lista-startowa.md` na main; brak pliku nie blokuje).
`gotowe` to kandydaci, gdy blokad nie ma, inaczej pusta lista.

Z `limity.md` liczą się pozycje list i wiersze tabel (bez nagłówka); wpis „brak” nie jest
wstrzymaniem. Wpis ze słowem „codex” wstrzymuje tylko review, każdy inny wstrzymuje workerów Claude.
Brak miejsca wysyła `notify.sh high` raz dziennie (znacznik `/Users/Shared/sh/stan/dysk-alarm`, kasowany, gdy
miejsce wróci).

`--czekaj` zastępuje pętlę odpytywania po stronie orkiestratora: gdy są kandydaci, a dispatch
wstrzymuje blokada (slot, kolejka review, dysk, limit), komenda sprawdza ją co `SHCTL_READY_PAUZA`
(30 s) do zejścia blokady albo do `--timeout` (domyślnie 1800 s). Bez kandydatów wraca od razu, bo
zależności zamyka orkiestrator. Wynik ma `czekano_s` i `limit_czasu` (`true`, gdy blokada nie zeszła
przed limitem).

```json
{"ok":true,"komenda":"task","dry_run":false,"wynik":{
  "gotowe":[{"nr":12,"tytul":"Schemat bazy","db_migracja":true}],"kandydaci":[...],
  "zablokowane":[{"nr":13,"tytul":"Logowanie","db_migracja":false,"powody":["zależność #12 otwarta"]}],
  "blokady":[],"sloty":{"max_local":2,"max_local_globalny":2,"max_local_projektu":null,"aktywne":1,
    "aktywne_projektu":0,"wolne":1},"kolejka_review":{"max":3,"czeka":0},
  "wolne_gb":25,"min_wolne_gb":15,"mozna_dispatch":true,"czekano_s":0,"limit_czasu":false}}
```

### task dispatch

```sh
shctl task dispatch NR
```

Przy `status:todo` sprawdza te same warunki co `ready` (własny panel nie zajmuje slotu) i przy
niespełnionym odmawia kodem 4 z powodem. Potem:

1. worktree `/Users/Shared/sh/wt/NAZWA/NR` na gałęzi `task/NR-slug`: istniejąca gałąź lokalna, zdalna albo nowa od
   `origin/main`;
2. kopia `.env.local` i `env_files` z repo głównego do worktree (prawa `go-rwx`); brak pliku to
   ostrzeżenie;
3. zaufanie folderu Claude Code dla repo projektu (sekcja „Zaufanie folderu”);
4. lista skilli workera według warstw (sekcja „Warstwy skilli”);
   przy `.nvmrc` albo `.node-version` w worktree także `fnm install` bez pytań (limit
   `SHCTL_FNM_LIMIT`, 300 s), żeby `fnm --use-on-cd` w panelu nie pytał o brakującą wersję Node;
   błąd to ostrzeżenie;
5. karta herdr z panelem `worker:NAZWA:NR` i w nim
   `claude --settings .claude/roles/worker/settings.json --model MODEL 'Zrealizuj issue #NR skillem sh-worker. Przed pracą wczytaj skille: A, B.'`
   (bez skilli zdanie o skillach odpada);
6. etykiety `status:in-progress` i `iter:1`;
7. wpis w `/Users/Shared/sh/stan/NAZWA.json`: panel, etykieta, worktree, gałąź, start, iteracja, a po
   starcie claude `polecenie` (czas UTC) i `tura: false` dla `task wait`.

Przy `status:in-progress` dokańcza brakujące kroki bez bramek; agenta, który już działa w panelu, nie
uruchamia drugi raz. Inny status to kod 4. Brak `.claude/roles/worker/settings.json` to kod 3.

```json
{"ok":true,"komenda":"task","dry_run":false,"wynik":{
  "nr":12,"galaz":"task/12-schemat-bazy","worktree":"/Users/.../sh/wt/sklep/12","panel":"w1:p7",
  "label":"worker:sklep:12","env":[".env.local"],"uruchomiono":true,"polecenie":"cd ... && claude ...",
  "skille":["sh-kat-baza"],"skille_brak":["sh-stack-supabase"],
  "zaufanie_dopisane":false,"zmiana":true,"kroki":["worktree ...","env: .env.local","skille: sh-kat-baza (brak: sh-stack-supabase)","panel worker:sklep:12 i start claude (model opus)"]}}
```

### Warstwy skilli

Lista skilli do wczytania przez workera składa się z warstw, w tej kolejności i bez powtórzeń:

1. bazowe: `bazowe` z `sh-system/plugin/warstwy-skilli.yaml`;
2. kategoria: `kategoria.NAZWA` z tego pliku (bez wpisu: `sh-kat-NAZWA`);
3. stack: `stack.NAZWA` z tego pliku dla każdej pozycji stacku (bez wpisu: `sh-stack-NAZWA`);
4. `skille` z zadania;
5. projekt, zawsze: każdy `.claude/skills/*/SKILL.md` w worktree zadania.

Kategoria, stack i skille pochodzą ze znacznika `shctl:warstwy` w treści issue (`task create`); issue bez
niego (np. zlecenie S) dostaje tylko warstwy bazowe i projektu. Skill istnieje, gdy ma `SKILL.md` w
`sh-system/plugin/skills`, w `.claude/skills` worktree albo w `~/.claude/skills`. Brakujący skill to
ostrzeżenie i wpis w `skille_brak`; dispatch idzie dalej bez niego. `task iter` przekazuje tę samą
listę, gdy otwiera nowy panel.

### Zaufanie folderu

Interaktywny `claude` w nieznanym katalogu pyta o zaufanie i czeka na odpowiedź, co zatrzymałoby
workera. Dokumentacja Claude Code (<https://code.claude.com/docs/en/permissions>, „Project allow rules
and workspace trust” i „What runs before you trust a folder”) mówi, że:

- w repo zaufanie dotyczy katalogu głównego repo, a w worktree katalogu głównego głównej kopii;
- zaufanie można nadać ręcznie: `projects["<katalog główny repo>"].hasTrustDialogAccepted = true` w
  `~/.claude.json`;
- zaufanie samego katalogu nadrzędnego (np. `/Users/Shared/sh/wt`) nie wystarcza dla repo w środku.

Dlatego `task dispatch` (i `task iter`, gdy otwiera nowy panel) dopisuje ten wpis dla
`/Users/Shared/sh/projekty/NAZWA`, jeśli go nie ma. Pozostałe pola pliku zostają, zapis jest atomowy z prawami
600, a plik, który nie jest poprawnym JSON, daje kod 1 bez zmian. Pole wyniku `zaufanie_dopisane` mówi,
czy wpis powstał.

Do sprawdzenia w pierwszym prawdziwym dispatchu: czy worker w `/Users/Shared/sh/wt/NAZWA/NR` startuje bez pytania.
Dokumentacja nazywa `~/.claude.json` plikiem, który Claude Code zapisuje sam, więc działająca sesja może
nadpisać wpis starszą kopią; kolejny dispatch dopisze go ponownie. Zaufanie włącza też ustawienia z
repo (hooki, `env`, pomocnicze komendy), a repo projektów powstają z naszego szablonu.

### Format /Users/Shared/sh/limity.md

Plik prowadzi ręcznie właściciel albo orkiestrator (od SH-lite F3b strażnik nie śledzi limitów,
`docs/serwer.md`, „Strażnik orkiestratora”), a `task ready`, `task dispatch` i `review run` go czytają. Jedna
aktywna blokada to jedna pozycja listy albo jeden wiersz tabeli; nagłówek tabeli i jej separator się
nie liczą. Inne linie (tytuł, akapity, komentarze) są ignorowane.

```markdown
# Limity

| Wykonawca | Od | Do | Źródło |
|---|---|---|---|
| claude | 2026-11-02 14:05 | 2026-11-02 19:00 | orkiestrator |
| codex | 2026-11-02 15:30 | 2026-11-02 20:30 | właściciel |
```

- Wpis zawierający słowo `codex` (wielkość liter bez znaczenia) wstrzymuje tylko `review run`: PR
  czeka w `status:review`, a dispatch działa dalej.
- Każdy inny wpis wstrzymuje workerów Claude: `task ready` zgłasza blokadę `limit`, a `task dispatch`
  odmawia (kod 4). Nazwę `claude` warto więc wpisywać jawnie.
- Brak wstrzymań to plik bez pozycji i wierszy albo jedna pozycja `brak` (także `- (brak)`, `*brak*`,
  `| brak |`). Brak pliku też oznacza brak wstrzymań.
- Po odnowieniu limitu wpis usuwa ten, kto go dopisał. Godzina „Do” jest dla ludzi; shctl jej nie
  interpretuje.

`status show` pokazuje te same wpisy jako „Wstrzymania”.

### task wait

```sh
shctl task wait NR [--timeout SEKUNDY]
```

Czekanie na workera z limitem czasu (domyślnie 600 s) zamiast gołego `herdr agent wait`, który na
panelu `idle` wraca od razu, a na panelu bez agenta kończy się błędem.

Liczy się nowa tura. `task dispatch` (przy starcie claude) i `task iter` (przy wysłaniu polecenia
poprawek) zapisują w `/Users/Shared/sh/stan/NAZWA.json` czas `polecenie` (UTC) i `tura: false`. Tura
zaczyna się, gdy agent przejdzie w `working` (zapis `tura: true`), i kończy, gdy wróci do `idle`. Za
nową pracę liczy się też commit w PR nowszy niż polecenie (`nowy_commit`). Raport z poprzedniej
iteracji ani panel `idle`, zanim agent podejmie polecenie, nie kończą czekania. Zadanie bez pola
`polecenie` (stan sprzed F3b) działa jak dawniej.

| Stan | Kiedy |
|---|---|
| `gotowe` | PR z `Closes #NR` ma raport `docs/07-realizacja/T-NR.md` i commit po poleceniu |
| `idle` | Agent skończył turę (albo jest nowy commit), a PR z raportem nie ma |
| `blocked`, `brak_agenta`, `brak_panelu` | Od razu |
| `pracuje` | Limit czasu, agent w trakcie tury |
| `bez_tury` | Limit czasu, agent nie podjął polecenia |

Przed turą sprawdza stan co `SHCTL_WAIT_PAUZA` (5 s). W turze czeka porcjami (`herdr agent wait` z
limitem, `SHCTL_WAIT_KROK`, domyślnie 60 s) i po każdej sprawdza stan znowu. `limit_czasu` jest `true`
przy `pracuje` i `bez_tury`. Pole `nastepny_krok` podpowiada dalszy krok.

```json
{"ok":true,"komenda":"task","dry_run":false,"wynik":{"nr":12,"stan":"bez_tury","pr":20,"raport":true,
  "czekano_s":600,"polecenie":"2026-11-09T10:15:00Z","nowy_commit":false,"limit_czasu":true,
  "nastepny_krok":"agent nie podjął polecenia: herdr agent read; gdy czeka na wejście, herdr agent prompt"}}
```

### pr check

```sh
shctl pr check PR [--czekaj] [--timeout SEKUNDY]
```

Stan PR przed czekaniem na CI. Najpierw `mergeable` z GitHuba (UNKNOWN ponawia kilka razy): przy
`CONFLICTING` GitHub nie uruchamia workflowów `pull_request`, więc komenda kończy się kodem 4 z
komunikatem o konflikcie, zamiast czekać. Potem CI (`pass`, `fail`, `pending`, `brak`); z `--czekaj`
czeka, aż CI się rozstrzygnie (domyślnie do 1800 s, przy `brak` do `SHCTL_CI_BRAK`, 180 s), i w każdym
obiegu znów sprawdza konflikt.

Dla PR zadania liczy czerwone commity (`.zadania[NR].ci_czerwone` w stanie). Pierwszy czerwony to
wynik pracy, kolejne to nieudane naprawy: przy 2 (`MAKS_NAPRAW_CI`) zwraca `"limit_napraw_ci":true` i
krok „review albo eskalacja” (`proces-v1.md`, „Review, QA, pętla poprawek”). Commit, który względem
poprzedniego czerwonego zmienia tylko raport `docs/07-realizacja/T-NR.md`, nie jest próbą naprawy
(`.zadania[NR].ci_tylko_raport` w stanie); limit 2 napraw bez zmian.

```json
{"ok":true,"komenda":"pr","dry_run":false,"wynik":{"pr":20,"nr":12,"head":"...","mergeable":"MERGEABLE",
  "konflikt":false,"ci":"fail","czerwone_commity":3,"nieudane_naprawy_ci":2,"maks_napraw_ci":2,
  "limit_napraw_ci":true,"nastepny_krok":"limit napraw CI: review albo eskalacja (proces-v1.md, „Czerwone CI”)"}}
```

`task close` przy CI innym niż `pass` też sprawdza konflikt i zgłasza go wprost.

### review run

```sh
shctl review run PR [--timeout SEKUNDY]
```

Jedno review naraz dla PR: blokada `/Users/Shared/sh/stan/review/NAZWA-prPR.lock` z PID. Drugie
wywołanie w trakcie kończy się kodem 4 („review PR #N już trwa”); blokada po martwym procesie jest
przejmowana. Iteracja review etapu pochodzi z `DoD.md` na main (`stage iter`). PR z gałęzi
`stage/08-qa` (raport QA) to kod 4: raport QA nie ma review etapu, merge idzie po zielonym CI.

Zadanie wynika z `Closes #NR` albo gałęzi `task/NR-` (review PR). PR z gałęzi `stage/ETAP` bez
`Closes` to review etapu: wymaga `docs/ETAP/DoD.md`, nie ma issue ani etykiet, a worktree, panel i
pliki robocze mają w nazwie `ETAP` zamiast `NR`. Kolejno:

1. etykieta `status:review` na issue (tylko review PR), na czas oczekiwania;
2. przy wstrzymaniu Codexa w `limity.md` koniec z kodem 4: PR czeka w kolejce;
3. czysty worktree `/Users/Shared/sh/wt/NAZWA/review-NR` na commicie PR (`git fetch origin pull/PR/head`), bez plików
   env; plik `.env*` (poza `.env.example`) w samym PR daje kod 4;
4. karta z panelem `review:NAZWA:NR` otwarta w `/Users/Shared/sh/wt/NAZWA` (nie w worktree PR) i w nim
   `codex exec -C WORKTREE -p reviewer -s read-only -m MODEL --output-schema codex/sh-review.schema.json -o ... - < prompt`;
   bez `cd` do worktree, więc `fnm --use-on-cd` nie pyta o wersję Node z `.nvmrc` (retro iskt-www:
   panel stał około 50 minut na #44);
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

Pliki robocze: `/Users/Shared/sh/stan/review/NAZWA-NR/` (prompt, wynik, `codex.log` z wyjściem panelu). Błąd
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
`/Users/Shared/sh/wt/NAZWA/NR` i uruchamia claude z tym poleceniem. Zapisuje `polecenie` i `tura: false`
w stanie zadania, więc następne `task wait` czeka na nową turę.

Powtórka dla tego samego review nie podbija licznika i nie wysyła polecenia drugi raz (stan w
`/Users/Shared/sh/stan/NAZWA.json`). FAIL w iteracji 3 wywołuje `shctl escalate --dotyczy "#NR" --powod "3 iteracje
bez PASS"`: wynik ma `"eskalowano":true` i numer eskalacji, a etykieta `iter:3` zostaje.

### task close

```sh
shctl task close NR
```

Działa w repo głównym na `main` (inaczej kod 4). Przy otwartym PR merguje (squash,
`--match-head-commit`) wyłącznie, gdy CI jest zielone (`pass`; `pending`, `fail` i brak kontroli to
kod 4) i komentarz review dla bieżącego commita ma PASS. Odmawia też, gdy `/Users/Shared/sh/wt/NAZWA/NR` ma
niezacommitowane zmiany albo commity spoza PR. Potem, na main po `git pull --ff-only`:

| Źródło | Cel |
|---|---|
| „Decyzje” z `docs/07-realizacja/T-NR.md` | `docs/decyzje.md`; `pytanie → decyzja` dzieli kolumny, inaczej Pytanie to `-` |
| „Drobne uwagi” z raportu | `docs/backlog-drobne.md`, stan `otwarta` |
| Zgłoszenia ⚪ z ostatniego review (komentarz w PR) | `docs/backlog-drobne.md`, źródło `review PR #N` |
| Czas od dispatchu, iteracje, eskalacje | Wiersz `| #NR tytuł | tryb | czas | 1 | iteracje | eskalacje | PR #N |` na końcu ostatniej tabeli `docs/metryki.md` (w `sh-dryrun`: tabela bieżącego przebiegu); pytania (`escalate --typ pytanie`) nie wchodzą do „Eskalacji”, tylko jako „, pytania: N” w ostatniej kolumnie |
| Przyczyny uwag review | Wiersz `| review PR #N (#NR tytuł) | wymaganie | kod | test | design | bez przyczyny |` w tabeli „Przyczyny uwag” `docs/metryki.md`: zgłoszenia ze wszystkich review PR (ostatni komentarz dla każdego commita); bez zgłoszeń wiersza nie ma. Projekt bez tej tabeli dostaje sekcję pod ostatnią tabelą metryk |
| Tytuł i PR | `- #NR: tytuł (PR #N)` w sekcji „Niewydane” `CHANGELOG.md` |
| „Propozycje dla systemu” | Komentarz z treścią i znacznikiem `<!-- propozycje:NAZWA:T-NR -->` w otwartym issue miesiąca w `sh-system` (etykieta `propozycja`, tytuł „Propozycje RRRR-MM”); brak otwartego issue: nowe; wynik `propozycje` to link do issue |

Pozycje sekcji to punkty listy (z kontynuacją) albo akapity; „brak” jest pomijane. Na końcu usuwa
worktree, gałąź `task/NR-*` i panel (także `eskalacja:NAZWA:NR`), zamyka issue, zdejmuje etykiety `status:*`, uruchamia
`scripts/sync-status.sh` i kasuje wpis zadania w stanie. Zmian w plikach wspólnych nie commituje.

Powtórka po merge'u pomija gotowe kroki: wiersze nie są dopisywane drugi raz, a komentarz ze znacznikiem
zadania nie powstaje ponownie. Nieudany krok poboczny (komentarz propozycji, panel, sync-status) daje
kod 1 po wykonaniu pozostałych; powtórka go dokańcza.

### task resume-check

```sh
shctl task resume-check NR [--testy "..."] [--bez-testow]
```

Stan po przerwie, do decyzji orkiestratora (kontynuuj, rebase i kontynuuj, iteracja od nowa).
Zwraca: status i iterację z etykiet, panel, a dla `/Users/Shared/sh/wt/NAZWA/NR` gałąź, HEAD, listę niezacommitowanych
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

### task close --anuluj

```sh
shctl task close NR --anuluj [--powod "..."]
```

Dawniej `task cancel NR`: stara nazwa działa jako alias z ostrzeżeniem do następnej wersji.
`--anuluj` poza `task close` to kod 2. Anulowanie zadania: zamyka PR z usunięciem gałęzi, zamyka
panele `worker:`, `eskalacja:` i `review:`
zadania, usuwa worktree `NR` i `review-NR` (bez zachowania zmian) i gałąź lokalną, zamyka issue jako
„not planned” z komentarzem (powód), zdejmuje etykiety `status:*`, usuwa wpis z `/Users/Shared/sh/stan/NAZWA.json`
i uruchamia `sync-status.sh`. Zwalnia slot. Scalony PR to kod 4. Powtórka nic nie zmienia
(`"zmiana":false`).

### reset-dryrun

```sh
shctl reset-dryrun
```

Przywraca projekt wzorcowy `sh-dryrun` do tagu baseline (`proces-v1.md`, „Projekt wzorcowy”): z pola
`baseline_tag` we frontmatterze `docs/konfiguracja.md` `sh-dryrun`, a bez niego najnowszego z
`baseline-*` i dawnego `baseline` według daty commita. Tagów nie przesuwa. Inny
projekt to kod 4, brak tagu albo pliku zadań w tagu to kod 3, a tag z artefaktami przebiegu (raporty
`T-NR.md`, `escalations/E-NNN.md`, `08-qa/raport-*.md`, mapa zadań w `06-zadania/index.md`, wpisy
`CHANGELOG.md`, `DoD.md` poza `todo`/`pominiety` albo z iteracją) to kod 4 z listą.

Kolejno: zapamiętuje `docs/metryki.md` (kopia robocza main albo `origin/main`), zamyka panele projektu,
usuwa jego worktree, zamyka otwarte PR (z usunięciem gałęzi), w każdym issue ze znacznikiem
`shctl:id`, także zamkniętym, zmienia go na `shctl:archiwum-id`, a otwarte zamyka jako „not planned”,
resetuje main do tagu i wypycha go (`--force-with-lease`), usuwa lokalne gałęzie `task/*` i `stage/*`,
czyści mapę zadań w stanie i odtwarza issue przez `task create` z `zadania.yaml` albo
`docs/06-zadania/zadania.yaml` z tagu. Potem przywraca metryki z nową sekcją „Przebieg dryrun N” (z
tabelą, do której `task close` dopisuje wiersze), commituje metryki, mapę zadań i `Projekt.md`
(„reset-dryrun: przebieg N od baseline SHA”) i wypycha main. Na końcu usuwa klon `docs/` w vaulcie
Obsidiana (po force push ma starą historię) i zakłada go od nowa; klon z niezacommitowanymi zmianami
zostaje, a wynik `obsidian` to „pominiety: …”.

Gdy drzewo main poza `metryki.md`, `06-zadania/index.md` i `Projekt.md` jest równe tagowi, nie ma
otwartych PR, paneli, worktree ani gałęzi `task/*`/`stage/*`, a issue ze znacznikiem to dokładnie
otwarte zadania z pliku w `status:todo` bez iteracji, komenda nic nie robi (`"zmiana":false`).

```json
{"ok":true,"komenda":"reset-dryrun","dry_run":false,"wynik":{"baseline":"0ea967b...","tag":"baseline-20261109","zamkniete_pr":[35],
  "zamkniete_issue":[36],"zarchiwizowane":[23,24,25,26,27,28,36],"plik_zadan":"docs/06-zadania/zadania.yaml",
  "mapa":{"T1":38,"T2":39},"przebieg":3,"obsidian":"odtworzony","zmiana":true}}
```

### template update

```sh
shctl template update [--projekt NAZWA] [--baseline] [--force] [--dry-run]
```

Zastępuje `profile update` (usunięte). Aktualizuje pliki zarządzane przez szablon `SH_TEMPLATE`
(`scripts/`, `.github/workflows/`, `.claude/roles/`, `AGENTS.md`, `docs/_szablony/`) z `main` szablonu.

| Plik w projekcie | Akcja |
|---|---|
| Równy bieżącej wersji szablonu | nic |
| Równy którejś wersji z historii szablonu (treść szablonu) | `aktualizacja` |
| Zmieniony w projekcie | `pominiety`, z `--force` `nadpisany` |
| Brak w projekcie | `nowy` |
| Usunięty z szablonu | zostaje |

Klon projektu musi stać na `main`: komenda nie przełącza gałęzi, inna gałąź to kod 4. Lokalne commity
spoza `origin/main` albo niezacommitowane zmiany w plikach zarządzanych to kod 4. Zmiany trafiają do
commita „szablon: pliki z SH_TEMPLATE SHA” na `main` i push.

`--baseline` (projekt wzorcowy): to samo na najnowszym baseline (`baseline_tag` albo najnowszy tag,
jak w `reset-dryrun`), przez osobny indeks, bez dotykania katalogu roboczego. Wynik to **nowy** tag
`baseline-RRRRMMDD` (drugi tego dnia: `-2`, `-3`), wypchnięty bez force. Żaden tag nie jest
przesuwany; force push tagów jest zablokowany i tak zostaje.

`--dry-run` tylko porównuje i wypisuje akcje. Zadania w toku mają stare pliki do czasu rebase'u ich
gałęzi na `main`.

```json
{"ok":true,"komenda":"template","dry_run":false,"wynik":{"szablon":"7aa9c64...",
 "main":{"po":"9b1e0d2...","pliki":[{"akcja":"aktualizacja","plik":"scripts/check-dod.sh"},
   {"akcja":"pominiety","plik":"AGENTS.md"}]},
 "baseline":{"z":"baseline-20261104","przed":"0ea967b...","tag":"baseline-20261109","po":"5c3a8f1...","pliki":[...]},
 "zmiana":true}}
```

### sprzataj

```sh
shctl sprzataj [--dry-run]
```

Sprzątanie po builderze i orkiestratorze. Usuwa worktree w `/Users/Shared/sh/wt-system/` i
`/Users/Shared/sh/wt/` oraz lokalne gałęzie repo w `/Users/Shared/sh` i `/Users/Shared/sh/projekty`
wyłącznie wtedy, gdy PR gałęzi ma stan `MERGED` albo `CLOSED` (`gh pr list`). Nigdy z `--force`:

| Co zostaje | Powód w `pominiete` |
|---|---|
| Gałąź bez PR albo z otwartym PR | `brak PR`, `PR OPEN` |
| Worktree z niezacommitowanymi zmianami | `niezacommitowane zmiany` |
| Gałąź z commitami spoza head PR | `lokalne commity spoza PR` |
| Gałąź wybrana w worktree | `gałąź w worktree` |
| `main` i gałąź bieżąca | pomijane bez wpisu |

Gałęzie usuwa skrypt przez `git branch -D`, bo po squash merge `-d` odmawia. Agent tego nie robi
sam. `--dry-run` wypisuje, co by usunął.

```json
{"ok":true,"komenda":"sprzataj","dry_run":false,"wynik":{
  "worktree":["/Users/Shared/sh/wt-system/f3a"],"galezie":["/Users/Shared/sh/sh-system:sh-lite-f3a"],
  "pominiete":[{"co":"/Users/Shared/sh/wt/sklep/12","powod":"PR gałęzi task/12-schemat-bazy: OPEN"}]}}
```

## Testy

```sh
bats scripts/shctl/tests
```

Testy używają atrap `gh`, `herdr`, `notify`, `ps` i `lsof` oraz projektu w katalogu tymczasowym.
`launchd.bats` uruchamia shctl przez `env -i` z PATH=/usr/bin:/bin, jak LaunchAgent. Testy zadań
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
`/Users/Shared/sh/stan/do-usuniecia.md`. Repo usuwa właściciel (`gh repo delete` wymaga zakresu `delete_repo`), a
wiersz z listy zdejmuje kolejny `shctl doctor`.
