# Serwer i skrypty

Wróć do: [[00-start-tutaj]]

Serwer to iMac 2012 (Intel, 4 rdzenie, 24 GB RAM, macOS 14 przez OpenCore). Działa bez przerwy,
a usługi startują same po zalogowaniu. Pełny opis techniczny: [[serwer]].

## Skąd biorą się skrypty

Źródłem wszystkich skryptów jest repo `sh-system` w `/Users/Shared/sh/sh-system`. Katalog `/Users/Shared/sh/bin` zawiera
tylko odnośniki (symlinki) do repo, więc zmiana w repo działa od razu. Zmiany w systemie idą przez
gałąź i PR, nigdy wprost na serwerze.

## Usługi w tle (LaunchAgenty)

| Usługa | Co robi | Kiedy | Log |
|---|---|---|---|
| `pl.iskt.softwarehouse.sh-start` | Uruchamia herdr i orkiestratora | Przy logowaniu | `/Users/Shared/sh/logs/sh-start.log` |
| `pl.iskt.softwarehouse.sh-watchdog` | Strażnik limitów subskrypcji | Co 5 minut i przy logowaniu | `/Users/Shared/sh/logs/watchdog.log` |
| `pl.iskt.softwarehouse.obsidian-sync` | Aktualizuje kopie dokumentów w Obsidianie | Co 5 minut i przy logowaniu | `/Users/Shared/sh/logs/obsidian-sync.log` |

Instaluje je `install.sh`. Ręczna zmiana w `~/Library/LaunchAgents` zostanie nadpisana przy
następnym `install.sh`.

## Flagi wyłączania

| Co wyłączasz | Jak | Jak włączyć z powrotem |
|---|---|---|
| Autostart herdr i orkiestratora | `touch /Users/Shared/sh/stan/autostart.off` i `launchctl bootout gui/$(id -u)/pl.iskt.softwarehouse.sh-start` | `rm /Users/Shared/sh/stan/autostart.off` i `/Users/Shared/sh/sh-system/scripts/server/install.sh` |
| Synchronizacja Obsidiana | `touch /Users/Shared/sh/stan/obsidian-sync.off` (zatrzymanie od razu: `launchctl bootout gui/$(id -u)/pl.iskt.softwarehouse.obsidian-sync`) | `rm /Users/Shared/sh/stan/obsidian-sync.off` i `install.sh` |
| Strażnik limitów | `launchctl bootout gui/$(id -u)/pl.iskt.softwarehouse.sh-watchdog`; bez flagi, więc działa tylko do następnego `install.sh` | `install.sh` |

Flagi przetrwają restart Maca i kolejne `install.sh`. Ręczne `sh-start.sh` i ręczne
`shctl obsidian sync` działają także przy fladze.

## Skrypty serwera

### sh-start.sh

Przygotowuje workspace `sh` w herdr: panel `orkiestrator` z `SH_NOTIFY=1 claude remote-control --name
sh-orkiestrator` i panel `powloka`. Uruchamia tylko to, co nie działa, więc można go wywoływać
wielokrotnie.

```sh
/Users/Shared/sh/bin/sh-start.sh              # przygotowuje i podłącza terminal
/Users/Shared/sh/bin/sh-start.sh --no-attach  # tylko przygotowuje
```

Przy autostarcie czeka na Docker Desktop (do 5 minut) i sieć (do 2 minut). Docker Desktop ma
wyłączony własny autostart, a skrypt tylko go otwiera.

`claude remote-control` to serwer sesji: każda nowa sesja startuje w `/Users/Shared/sh` z jego PATH. Dlatego
skrypt uzupełnia PATH o katalogi narzędzi (`~/.local/bin`, `/Users/Shared/sh/bin`, `~/.softwarehouse/bin`,
Homebrew, `~/.docker/bin`) i podaje go jawnie w komendzie orkiestratora. Gdy `/Users/Shared/sh` obsługuje
już inna instancja (proces `claude remote-control` z katalogiem `/Users/Shared/sh` poza panelem albo komunikat
„This folder is already served by a terminal claude remote-control”), skrypt zapisuje to w logu
i nie uruchamia drugiej.

Każdy przebieg kończy się w `/Users/Shared/sh/logs/sh-start.log` jednym wpisem z kodem wyjścia: `gotowe (kod 0)`,
`UWAGA (kod 0)` albo `BLAD …, krok: ETAP (kod N)`. Szczegóły i znaczenie kodów:
`docs/serwer.md`, sekcja „Uruchomienie”.

Uwaga: wraca sam orkiestrator. Workerzy po restarcie nie wracają sami; po „wznów” orkiestrator
sprawdza przerwane zadania i uruchamia je ponownie.

### notify.sh

Wysyła powiadomienie push przez ntfy.sh. Temat (działa jak hasło) leży w `~/.config/sh/ntfy-topic`,
poza repo.

```sh
notify.sh default "Test SH" "Działa"
notify.sh high "Tytuł" "Treść" https://link-po-kliknieciu warning
```

Priorytety: `min`, `default`, `high`, `urgent`. Używają go shctl, strażnik limitów i `install.sh`.
Hook Claude Code wysyła „Claude czeka na zgodę” (pytanie o zgodę) i „Claude czeka na Ciebie”
(Claude skończył i czeka na wiadomość). Działa tylko w procesie uruchomionym z `SH_NOTIFY=1`, a tak
startuje każdy worker z `shctl task dispatch` i orkiestrator z `sh-start.sh`.

Test: `shctl doctor --test-notify` albo wywołanie jak wyżej.

### sh-watchdog.sh

Strażnik limitów, bez AI. Co 5 minut:

1. usuwa z `/Users/Shared/sh/limity.md` limity, których godzina minęła, i wysyła push „Limit X odnowiony”;
2. czyta ostatnie linie paneli workspace `sh` i szuka komunikatów o limicie Claude Code i Codexa;
3. nowy limit zapisuje w `/Users/Shared/sh/limity.md` i wysyła push „Limit X do HH:MM”;
4. sprawdza, czy działa orkiestrator (`claude remote-control` w `/Users/Shared/sh`); gdy nie, uruchamia go
   przez `sh-start.sh` i wysyła push „Orkiestrator uruchomiony ponownie”. Flaga
   `/Users/Shared/sh/stan/autostart.off` wyłącza ten restart. Orkiestrator przeżywa koniec przebiegu
   strażnika (`AbandonProcessGroup` w pliście).

W etapie A **nie wznawia pracy**: wznawiasz Ty, pisząc „wznów”. Automatyczne wznowienie to etap B
(jeszcze niedostępne).

Wzorce komunikatów: `/Users/Shared/sh/watchdog-wzorce.txt` (kopia robocza, źródło w repo). Limit Claude
wstrzymuje nowe zadania, limit Codexa tylko review: PR czekają w kolejce.

```sh
launchctl kickstart gui/$(id -u)/pl.iskt.softwarehouse.sh-watchdog   # przebieg teraz
tail -f /Users/Shared/sh/logs/watchdog.log
```

### Synchronizacja Obsidiana

Usługa `obsidian-sync` uruchamia co 5 minut `shctl obsidian sync --agent`. W każdej kopii w
`SH/` robi tylko `git pull --ff-only`. Skrzynek (`SH/Skrzynka/`) nie dotyka, bo nie są kopiami repo. Kopię z lokalnymi zmianami albo
rozjechaną pomija; gdy problem
powtórzy się w dwóch przebiegach, wysyła jeden push „Obsidian: klon bez synchronizacji”. Nigdy nie
nadpisuje Twoich zmian.

Stan: `/Users/Shared/sh/stan/obsidian-sync.json`, a data ostatniej udanej synchronizacji jest w `shctl doctor`.

### backup-config.sh

Archiwum konfiguracji agentów: ustawienia i skille Claude Code, konfiguracja Codexa, `~/.config/sh`,
`/Users/Shared/sh/bin`, `/Users/Shared/sh/porty.md`. Bez sesji, historii i tokenów logowania. Po spakowaniu sprawdza je
gitleaks i kasuje archiwum przy znalezionym sekrecie.

```sh
backup-config.sh              # do /Users/Shared/sh/backups
backup-config.sh /Volumes/X   # na wskazany dysk
```

Archiwum zawiera temat ntfy, więc traktuj je jak dane poufne. Skrypty nie są w archiwum: odtwarza je
klon `sh-system` i `install.sh`. Dlatego skrypt ostrzega, gdy `sh-system` ma niezapisane w GitHubie
zmiany (log `/Users/Shared/sh/logs/backup-config.log`).

### install.sh

Instaluje pliki serwera z repo. Bezpieczny do powtarzania.

```sh
/Users/Shared/sh/sh-system/scripts/server/install.sh
```

Robi:

- symlinki skryptów do `/Users/Shared/sh/bin` i `/Users/Shared/sh/Brewfile`;
- profil reviewera Codex (`~/.codex/reviewer.config.toml`) i ustawienia sesji orkiestratora
  (`/Users/Shared/sh/.claude/settings.json`);
- kopię wzorców strażnika, gdy jej brak;
- LaunchAgenty: kopiuje przy zmianie i przeładowuje, ładuje niezaładowane (z wyjątkiem wyłączonych
  flagą);
- globalny hook git (niżej).

Plik w `/Users/Shared/sh/bin` różny od repo kończy się błędem i niczego nie nadpisuje. Nieudane załadowanie
usługi daje push „install.sh: agent niezaladowany” z komendą do ręcznego załadowania.

**Kiedy uruchamiać:** po merge'u zmiany w skryptach lub plistach, po włączeniu flagi z powrotem.

### setup-toolchain.sh

Instaluje brakujące narzędzia serwera z przypiętymi wersjami (yq, gitleaks, uv, fnm, bats, herdr,
Node, pnpm, Playwright 1.61.1). Bez sudo, bezpieczny do powtarzania.

```sh
/Users/Shared/sh/bin/setup-toolchain.sh
```

Playwright jest celowo przypięty do 1.61.1: nowsze wersje nie działają z WebKit na macOS 14 Intel.

### test-herdr.sh

Test działania herdr. Uruchamiaj w panelu herdr (np. `powloka`).

```sh
/Users/Shared/sh/bin/test-herdr.sh
```

## Hooki git

`install.sh` ustawia globalny `core.hooksPath` na `scripts/server/git-hooks/`. Jedyna reguła:
`pre-push` odrzuca push na gałąź `production` („Push na production wykonuje wyłącznie właściciel z
własnego urządzenia”). Pozostałe hooki tylko przekazują wywołanie do hooków lokalnych repo.

Repo z własnym `core.hooksPath` (np. husky) wyłącza ten hook. `install.sh` i `shctl doctor`
ostrzegają o takich repo. Projekty SH nie używają hooków git: kontrole robi CI.

## Skrypty repozytorium sh-system

Do pracy nad samym systemem, uruchamiane też w CI:

| Skrypt | Co sprawdza |
|---|---|
| `scripts/plugin/sprawdz-skille.sh` | Każdy skill ma sekcje i zasady z kontraktu |
| `scripts/sync-codex.sh` | Prompt Codexa `codex/sh-review.md` jest zgodny ze skillem `sh-review` |
| `scripts/docs/sprawdz-podrecznik.sh` | Każda komenda `shctl` i każdy skill wymieniony w tym podręczniku istnieje |

Zmiana w shctl, skillach lub skryptach serwera wymaga aktualizacji tego podręcznika w tym samym PR
([[serwer]], „Praca nad systemem”).

## Logi

| Log | Co zawiera |
|---|---|
| `/Users/Shared/sh/logs/shctl.log` | Każde wywołanie shctl: czas, kod, projekt, komenda |
| `/Users/Shared/sh/logs/sh-start.log` | Start herdr i orkiestratora |
| `/Users/Shared/sh/logs/watchdog.log` | Przebiegi strażnika limitów (bez treści komunikatów) |
| `/Users/Shared/sh/logs/obsidian-sync.log` | Synchronizacja kopii, pominięte kopie z powodem |
| `/Users/Shared/sh/logs/backup-config.log` | Ostrzeżenia kopii konfiguracji |
| `/Users/Shared/sh/logs/herdr-server.log` | Serwer herdr uruchomiony przez `sh-start.sh` |
| `/Users/Shared/sh/stan/review/PROJEKT-NR/codex.log` | Wyjście Codexa z review |

## Ważne pliki stanu

| Plik | Zawartość |
|---|---|
| `/Users/Shared/sh/limity.md` | Aktywne limity subskrypcji |
| `/Users/Shared/sh/porty.md` | Bloki portów baz projektów |
| `/Users/Shared/sh/stan/NAZWA.json` | Mapa zadań projektu na panele, stan po STOP |
| `/Users/Shared/sh/stan/do-usuniecia.md` | Repo testowe do usunięcia przez Ciebie |
| `/Users/Shared/sh/stan/obsidian-sync.json` | Ostatnia synchronizacja Obsidiana i problemy |
| `/Users/Shared/sh/stan/checkpointy/NAZWA` | Wysłane powiadomienia „Czeka na Twoją akceptację” (cel i commit) |
| `/Users/Shared/sh/stan/skrzynka/NAZWA.json` | Partia materiałów ze skrzynki czekająca na merge PR |
