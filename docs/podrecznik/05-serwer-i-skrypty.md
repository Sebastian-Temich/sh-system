# Serwer i skrypty

Wróć do: [[00-start-tutaj]]

Serwer to iMac 2012 (Intel, 4 rdzenie, 24 GB RAM, macOS 14 przez OpenCore). Działa bez przerwy,
a usługi startują same po zalogowaniu. Pełny opis techniczny: [[serwer]].

## Skąd biorą się skrypty

Źródłem wszystkich skryptów jest repo `sh-system` w `~/sh/sh-system`. Katalog `~/sh/bin` zawiera
tylko odnośniki (symlinki) do repo, więc zmiana w repo działa od razu. Zmiany w systemie idą przez
gałąź i PR, nigdy wprost na serwerze.

## Usługi w tle (LaunchAgenty)

| Usługa | Co robi | Kiedy | Log |
|---|---|---|---|
| `pl.iskt.softwarehouse.sh-start` | Uruchamia herdr i orkiestratora | Przy logowaniu | `~/sh/logs/sh-start.log` |
| `pl.iskt.softwarehouse.sh-watchdog` | Strażnik limitów subskrypcji | Co 5 minut i przy logowaniu | `~/sh/logs/watchdog.log` |
| `pl.iskt.softwarehouse.obsidian-sync` | Aktualizuje kopie dokumentów w Obsidianie | Co 5 minut i przy logowaniu | `~/sh/logs/obsidian-sync.log` |

Instaluje je `install.sh`. Ręczna zmiana w `~/Library/LaunchAgents` zostanie nadpisana przy
następnym `install.sh`.

## Flagi wyłączania

| Co wyłączasz | Jak | Jak włączyć z powrotem |
|---|---|---|
| Autostart herdr i orkiestratora | `touch ~/sh/stan/autostart.off` i `launchctl bootout gui/$(id -u)/pl.iskt.softwarehouse.sh-start` | `rm ~/sh/stan/autostart.off` i `~/sh/sh-system/scripts/server/install.sh` |
| Synchronizacja Obsidiana | `touch ~/sh/stan/obsidian-sync.off` (zatrzymanie od razu: `launchctl bootout gui/$(id -u)/pl.iskt.softwarehouse.obsidian-sync`) | `rm ~/sh/stan/obsidian-sync.off` i `install.sh` |
| Strażnik limitów | `launchctl bootout gui/$(id -u)/pl.iskt.softwarehouse.sh-watchdog`; bez flagi, więc działa tylko do następnego `install.sh` | `install.sh` |

Flagi przetrwają restart Maca i kolejne `install.sh`. Ręczne `sh-start.sh` i ręczne
`shctl obsidian sync` działają także przy fladze.

## Izolacja agentów

Izolacja jest lekka: chroni przed pomyłką agenta, nie przed celowym obejściem. Na serwerze nie ma
ważnych danych. Pełny opis i stan z 2026-11-03: [[serwer]], „Izolacja agentów”.

| Narzędzie | Ochrona | Gdzie |
|---|---|---|
| Claude Code | Blokada odczytu i edycji: Zdjęcia, Filmy, Muzyka, pęk kluczy, Safari, profile przeglądarek, Wiadomości, Mail, klucze SSH, `~/.gnupg`. `~/Documents`, `~/Desktop` i `~/Downloads` są dostępne | `~/.claude/settings.json`, `permissions.deny` |
| Codex | Zapis tylko w katalogu roboczym (bez `/tmp`); reviewer tylko odczyt | `~/.codex/config.toml`, `~/.codex/reviewer.config.toml` |

Blokady Claude Code działają też w profilach ról: profil projektu nie może ich odblokować. Sprawdzenie:
w sesji Claude poproś o `ls ~/Pictures`. Powinna być odmowa.

Do zrobienia przez Ciebie (wymaga sudo albo decyzji):

- SSH przyjmuje hasła, a `authorized_keys` jest pusty. Przejście na same klucze: najpierw dodaj swój
  klucz (`ssh-copy-id`), potem komendy z [[serwer]]. Jeśli SSH jest zbędne: `sudo systemsetup
  -setremotelogin off`.
- Dostęp produkcyjny agentów to głównie logowanie `gh` (pełne prawa do repo konta) i konektory
  claude.ai (np. Supabase). W plikach nie ma kluczy produkcyjnych aplikacji.

## Skrypty serwera

### sh-start.sh

Przygotowuje workspace `sh` w herdr: panel `orkiestrator` z `SH_NOTIFY=1 claude remote-control --name
sh-orkiestrator` i panel `powloka`. Uruchamia tylko to, co nie działa, więc można go wywoływać
wielokrotnie.

```sh
~/sh/bin/sh-start.sh              # przygotowuje i podłącza terminal
~/sh/bin/sh-start.sh --no-attach  # tylko przygotowuje
```

Przy autostarcie czeka na Docker Desktop (do 5 minut) i sieć (do 2 minut). Docker Desktop ma
wyłączony własny autostart, a skrypt tylko go otwiera.

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

1. usuwa z `~/sh/limity.md` limity, których godzina minęła, i wysyła push „Limit X odnowiony”;
2. czyta ostatnie linie paneli workspace `sh` i szuka komunikatów o limicie Claude Code i Codexa;
3. nowy limit zapisuje w `~/sh/limity.md` i wysyła push „Limit X do HH:MM”.

W etapie A **nie wznawia pracy**: wznawiasz Ty, pisząc „wznów”. Automatyczne wznowienie to etap B
(jeszcze niedostępne).

Wzorce komunikatów: `~/sh/watchdog-wzorce.txt` (kopia robocza, źródło w repo). Limit Claude
wstrzymuje nowe zadania, limit Codexa tylko review: PR czekają w kolejce.

```sh
launchctl kickstart gui/$(id -u)/pl.iskt.softwarehouse.sh-watchdog   # przebieg teraz
tail -f ~/sh/logs/watchdog.log
```

### Synchronizacja Obsidiana

Usługa `obsidian-sync` uruchamia co 5 minut `shctl obsidian sync --agent`. W każdej kopii w
`SH/` robi tylko `git pull --ff-only`. Skrzynek (`SH/Skrzynka/`) nie dotyka, bo nie są kopiami repo. Kopię z lokalnymi zmianami albo
rozjechaną pomija; gdy problem
powtórzy się w dwóch przebiegach, wysyła jeden push „Obsidian: klon bez synchronizacji”. Nigdy nie
nadpisuje Twoich zmian.

Stan: `~/sh/stan/obsidian-sync.json`, a data ostatniej udanej synchronizacji jest w `shctl doctor`.

### backup-config.sh

Archiwum konfiguracji agentów: ustawienia i skille Claude Code, konfiguracja Codexa, `~/.config/sh`,
`~/sh/bin`, `~/sh/porty.md`. Bez sesji, historii i tokenów logowania. Po spakowaniu sprawdza je
gitleaks i kasuje archiwum przy znalezionym sekrecie.

```sh
backup-config.sh              # do ~/sh/backups
backup-config.sh /Volumes/X   # na wskazany dysk
```

Archiwum zawiera temat ntfy, więc traktuj je jak dane poufne. Skrypty nie są w archiwum: odtwarza je
klon `sh-system` i `install.sh`. Dlatego skrypt ostrzega, gdy `sh-system` ma niezapisane w GitHubie
zmiany (log `~/sh/logs/backup-config.log`).

### install.sh

Instaluje pliki serwera z repo. Bezpieczny do powtarzania.

```sh
~/sh/sh-system/scripts/server/install.sh
```

Robi:

- symlinki skryptów do `~/sh/bin` i `~/sh/Brewfile`;
- profil reviewera Codex (`~/.codex/reviewer.config.toml`) i ustawienia sesji orkiestratora
  (`~/sh/.claude/settings.json`);
- kopię wzorców strażnika, gdy jej brak;
- LaunchAgenty: kopiuje przy zmianie i przeładowuje, ładuje niezaładowane (z wyjątkiem wyłączonych
  flagą);
- globalny hook git (niżej).

Plik w `~/sh/bin` różny od repo kończy się błędem i niczego nie nadpisuje. Nieudane załadowanie
usługi daje push „install.sh: agent niezaladowany” z komendą do ręcznego załadowania.

**Kiedy uruchamiać:** po merge'u zmiany w skryptach lub plistach, po włączeniu flagi z powrotem.

### setup-toolchain.sh

Instaluje brakujące narzędzia serwera z przypiętymi wersjami (yq, gitleaks, uv, fnm, bats, herdr,
Node, pnpm, Playwright 1.61.1). Bez sudo, bezpieczny do powtarzania.

```sh
~/sh/bin/setup-toolchain.sh
```

Playwright jest celowo przypięty do 1.61.1: nowsze wersje nie działają z WebKit na macOS 14 Intel.

### test-herdr.sh

Test działania herdr. Uruchamiaj w panelu herdr (np. `powloka`).

```sh
~/sh/bin/test-herdr.sh
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
| `~/sh/logs/shctl.log` | Każde wywołanie shctl: czas, kod, projekt, komenda |
| `~/sh/logs/sh-start.log` | Start herdr i orkiestratora |
| `~/sh/logs/watchdog.log` | Przebiegi strażnika limitów (bez treści komunikatów) |
| `~/sh/logs/obsidian-sync.log` | Synchronizacja kopii, pominięte kopie z powodem |
| `~/sh/logs/backup-config.log` | Ostrzeżenia kopii konfiguracji |
| `~/sh/logs/herdr-server.log` | Serwer herdr uruchomiony przez `sh-start.sh` |
| `~/sh/stan/review/PROJEKT-NR/codex.log` | Wyjście Codexa z review |

## Ważne pliki stanu

| Plik | Zawartość |
|---|---|
| `~/sh/limity.md` | Aktywne limity subskrypcji |
| `~/sh/porty.md` | Bloki portów baz projektów |
| `~/sh/stan/NAZWA.json` | Mapa zadań projektu na panele, stan po STOP |
| `~/sh/stan/do-usuniecia.md` | Repo testowe do usunięcia przez Ciebie |
| `~/sh/stan/obsidian-sync.json` | Ostatnia synchronizacja Obsidiana i problemy |
| `~/sh/stan/checkpointy/NAZWA` | Wysłane powiadomienia „Czeka na Twoją akceptację” (cel i commit) |
| `~/sh/stan/skrzynka/NAZWA.json` | Partia materiałów ze skrzynki czekająca na merge PR |
