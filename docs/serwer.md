# Serwer software house'u

iMac13,2 (2012), Intel i5-3470S, 4 rdzenie, 24 GB RAM, macOS 14 przez OpenCore Legacy Patcher.
Narzędzia, przeglądarki i testy działają natywnie; Docker tylko dla usług (Supabase).

| Co | Gdzie |
|---|---|
| Katalog SH | `/Users/Shared/sh`, uprawnienia 700 (sekcja „Katalog SH”) |
| Skrypty, Brewfile, plisty, ustawienia sesji | Repo `sh-system`, symlinki zakłada `install.sh` (sekcja „Skrypty serwera”) |
| Zmiany w systemie | Gałąź, worktree i PR (sekcja „Praca nad systemem”) |
| Toolchain | `/Users/Shared/sh/bin/setup-toolchain.sh` (idempotentny, bez sudo), `/Users/Shared/sh/Brewfile` |
| Porty baz projektów | `/Users/Shared/sh/porty.md` |
| Konfiguracja Maca dla shctl | `/Users/Shared/sh/konfiguracja.md` (`max_local`, `review`) |
| Usługi w tle | `sh-start`, `sh-watchdog`, `obsidian-sync`, `przypomnienia` (LaunchAgenty) |

## Katalog SH

Cały katalog roboczy (`sh-system`, `sh-template-projekt`, `projekty`, `wt`, `wt-system`, `stan`,
`logs`, `bin`, `porty.md`, `limity.md`, `konfiguracja.md`, `Brewfile`, `archiwum`) leży w
`/Users/Shared/sh`, właściciel `sebastiant.`, uprawnienia 700.

Powód: katalog domowy `/Users/sebastiant.` kończy się kropką, a Claude Code odrzuca Write i Edit pod
taką ścieżką („suspicious Windows path pattern”). `~/sh` to tylko dowiązanie dla zgodności wstecz;
skrypty, plisty, ustawienia i dokumentacja używają `/Users/Shared/sh` wprost. Pod `~` zostają
`~/.claude`, `~/.codex`, `~/.config/sh`, `~/.local/bin` i vault Obsidiana. `shctl doctor` (kontrola
`katalog SH`): `blad` przy segmencie z kropką, `uwaga` przy dowiązaniu albo prawach innych niż 700.

## Skrypty serwera

`/Users/Shared/sh/bin` zawiera symlinki do `scripts/server/*.sh` i `scripts/shctl/shctl`, a
`/Users/Shared/sh/Brewfile` do `scripts/server/Brewfile`. Zmiana w repo działa od razu.

```sh
/Users/Shared/sh/sh-system/scripts/server/install.sh
```

`install.sh` (idempotentny, uruchamia go właściciel, bo `launchctl` i zapis poza `/Users/Shared/sh` są
poza sandboxem sesji):

- symlinki w `/Users/Shared/sh/bin`; plik różny od repo kończy się błędem bez nadpisania, martwe
  dowiązania do usuniętych plików usuwa;
- `/Users/Shared/sh/.claude/settings.json` → `scripts/server/orkiestrator-settings.json`,
  `/Users/Shared/sh/CLAUDE.md` → `scripts/server/CLAUDE-sh.md`, profil Codexa
  `~/.codex/reviewer.config.toml` → `codex/reviewer.config.toml`, kopia `konfiguracja.md`, gdy brak;
- LaunchAgenty z `scripts/server/*.plist`: kopia przy różnicy i przeładowanie, załadowanie
  niezaładowanych (poza wyłączonymi flagą); nieudany `bootstrap` daje kod błędu, komendę do ręcznego
  załadowania i push „install.sh: agent niezaladowany”;
- globalny hook git i helper logowania git przez `gh auth git-credential`.

| LaunchAgent | Skrypt | Kiedy | Log |
|---|---|---|---|
| `pl.iskt.softwarehouse.sh-start` | `sh-start.sh --autostart` | Przy logowaniu | `logs/sh-start.log` |
| `pl.iskt.softwarehouse.sh-watchdog` | `sh-watchdog.sh` | Co 5 min | `logs/watchdog.log` |
| `pl.iskt.softwarehouse.obsidian-sync` | `obsidian-sync.sh` | Co 5 min | `logs/obsidian-sync.log` |
| `pl.iskt.softwarehouse.przypomnienia` | `przypomnienia.sh` | Co 15 min | `logs/przypomnienia.log` |

Flagi w `/Users/Shared/sh/stan/` (`autostart.off`, `obsidian-sync.off`, `przypomnienia.off`)
przetrwają restart i kolejne `install.sh`.

## Plugin software-house

Skille `sh-*` dostarcza plugin `software-house` z lokalnego marketplace `sh-system`
(`.claude-plugin/marketplace.json`, plugin w `plugin/`). Instalacja jednorazowa:

```sh
claude plugin marketplace add /Users/Shared/sh/sh-system
claude plugin install software-house@sh-system --scope user
```

Marketplace jest typu katalog: Claude Code czyta plugin wprost z `/Users/Shared/sh/sh-system/plugin`,
czyli z `main`. Po merge'u zmian skilli: `git pull --ff-only` w `/Users/Shared/sh/sh-system`, potem
nowa sesja albo `/reload-plugins`; działające sesje widzą stare skille do restartu. Zmiana
`marketplace.json` wymaga `claude plugin marketplace update sh-system`. Skille techniczne
(`plugin/skills/techniczne/`) nie są ładowane jako skille: `task dispatch` podaje workerowi ich ścieżki.

### Stare skille

Dawne skille briefu, wymagań i planowania są przeniesione do `/Users/Shared/sh/archiwum/skille-20261102/`,
a kopie używane przez Paperclip zostały w `~/.claude/skills` i `~/.codex/skills`. Sesje SH ich nie widzą:
`skillOverrides: "off"` i `permissions.deny` `Skill(NAZWA)` w ustawieniach orkiestratora i profilu
workera (zmiana listy: oba pliki naraz, test `profile-skille.bats` w szablonie).

## Praca nad systemem

Zmiany w `sh-system` i `sh-template-projekt` idą przez gałąź i PR, w osobnym worktree
`/Users/Shared/sh/wt-system/NAZWA` (`git worktree add`). W `/Users/Shared/sh/sh-system` nigdy nie
przełączamy gałęzi: `bin`, plisty i ustawienia sesji to dowiązania do tego katalogu. Po zielonym CI
builder merguje PR sam; wyjątek: zmiana bezpieczeństwa, dostępów albo produkcji czeka na zgodę
właściciela. Po merge'u `git pull --ff-only` w `/Users/Shared/sh/sh-system`, a przy zmianie skryptów,
plist albo ustawień właściciel uruchamia `install.sh`. Worktree i gałęzie scalonych PR usuwa
`shctl sprzataj`; gałąź bez PR usuwa właściciel.

Dokumentacja w tym samym PR co zmiana:

- `docs/podrecznik/` (trzy pliki: `01-start`, `02-codzienna-praca`, `03-gdy-cos-nie-dziala`) opisuje
  tylko stan faktyczny, zapowiedzi oznacza „etap B (jeszcze niedostępne)”. CI:
  `scripts/docs/sprawdz-podrecznik.sh` (komendy `shctl` i skille istnieją, każdy skill roli jest w
  `01-start.md`, wikilinki i nagłówki istnieją).
- `docs/shctl.md` jest generowany z pomocy: zmiana komendy to zmiana `scripts/shctl/pomoc/KOMENDA.txt`
  i `bash scripts/docs/shctl-md.sh`. CI: `shctl-md.sh --sprawdz`.
- Skille: `scripts/plugin/sprawdz-skille.sh` (kontrakt `plugin/skills/_kontrakt.md`).
- `docs/changelog.md` i, przy decyzji, `docs/decyzje-systemu.md`.

**Testy** (`bats --recursive scripts`) działają w sesji buildera w sandboxie bez nakładek: bats
bierze katalog tymczasowy z `TMPDIR`, który sandbox ustawia na dozwolony katalog. Skrypty tworzą
pliki tymczasowe zawsze z jawnym szablonem `mktemp -d "${TMPDIR:-/tmp}/nazwa.XXXXXX"`, bo `mktemp`
macOS bez szablonu ignoruje `TMPDIR` i pisze do `/var/folders`, czego sandbox zabrania. Bez
procesów `<(...)` przekazywanych do zewnętrznych programów (`diff <(…)`): w sandboxie `/dev/fd` jest
niedostępne. Testy używają atrap `gh`, `herdr`, `claude`, `codex`, `notify`; `new-project-szablon.bats`
w sandboxie jest pomijany (sprawdza CI). Testy na prawdziwym GitHubie (`SHCTL_E2E=1`) tylko po
wyraźnej zgodzie właściciela; repo testowe `sh-test-RRRRMMDD-HHMM` trafia do
`/Users/Shared/sh/stan/do-usuniecia.md`, a usuwa je właściciel.

## Polityka instalacji

1. Zależności projektowe agenci instalują sami (pnpm, uv).
2. Narzędzia z brew agenci instalują sami i dopisują do `Brewfile` (commit w `sh-system`) i do
   „Dziennika narzędzi”.
3. sudo, ustawienia systemu i Docker Desktop zmienia wyłącznie właściciel.

### Ograniczenia tej maszyny

- Homebrew wymaga gita >= 2.30 (jest 2.39.5 z CLT 16.2).
- Przed `brew install` sprawdź butelkę (`curl -fsS https://formulae.brew.sh/api/formula/NAZWA.json`,
  tag `sonoma` albo `all`); bez niej użyj oficjalnej binarki `darwin-x86_64` w `~/.local/bin` z
  przypiętą wersją i SHA-256 w `setup-toolchain.sh`.
- Playwright przypięty do 1.61.1 (od 1.62 WebKit na macOS 14 Intel pada). E2E i tak działa tylko w CI.
- Wolne miejsce: poniżej 15 GB dispatch staje (`min_wolne_gb`).

## Limity pracy równoległej

Maksymalnie `max_local` workerów (2) dla wszystkich projektów, jeden ciężki job naraz, jeden stack
Supabase projektów SH (limit Dockera 7,75 GiB, stack ok. 2 GiB). `supabase-local` to stary system
poza limitem.

## Herdr

Herdr 0.9.5 to dom agentów. Workspace `sh`: panel `orkiestrator` z `claude remote-control --name
sh-orkiestrator --permission-mode auto` w `/Users/Shared/sh` i panel `powloka`; workery i review w
osobnych kartach z etykietami `worker:NAZWA:NR`, `review:NAZWA:NR`. Skrypty szukają paneli po
etykiecie. `--permission-mode auto` sprawia, że każda sesja z Remote Control startuje w trybie Auto.

**Uruchomienie.** `sh-start.sh` (LaunchAgent przy logowaniu przez `zsh -lic`) czeka na Docker Desktop
(300 s) i sieć (120 s), uzupełnia PATH (`~/.local/bin`, `/Users/Shared/sh/bin`, Homebrew,
`~/.docker/bin`) i przekazuje go jawnie orkiestratorowi. Uruchamia tylko to, co nie działa; drugiej
instancji `claude remote-control` w `/Users/Shared/sh` nie startuje. Kontrola „czy orkiestrator
działa” jest jedna (`scripts/server/lib/system.sh`, `orkiestrator_pid`) dla `sh-start.sh`, strażnika
i `doctor`: proces `claude remote-control` z cwd `/Users/Shared/sh` w panelu `orkiestrator`
(`herdr pane process-info`). Plisty `sh-start` i `sh-watchdog` mają `AbandonProcessGroup`, a serwer
herdr startuje we własnej sesji, więc orkiestrator przeżywa koniec przebiegu launchd.

Log `logs/sh-start.log`: każdy przebieg kończy jeden wpis `gotowe … (kod 0)`, `UWAGA: … (kod 0)` albo
`BLAD: …, krok: ETAP … (kod N)`. Kod 142 to herdr bez odpowiedzi w 30 s, 143/129/130 to sygnały.

```sh
/Users/Shared/sh/bin/sh-start.sh              # przygotowuje i podłącza
/Users/Shared/sh/bin/sh-start.sh --no-attach  # tylko przygotowuje
herdr server stop                              # kończy wszystkie panele; nie w trakcie pracy
launchctl kickstart gui/$(id -u)/pl.iskt.softwarehouse.sh-start
```

Odłączenie bez zabijania sesji: `ctrl+b`, potem `q`. Wyłączenie autostartu: flaga
`stan/autostart.off` i `launchctl bootout`; ręczne `sh-start.sh` działa także przy fladze. SSH
(port 22, hasła dozwolone, bez kluczy w `authorized_keys`) nie było testowane.

Ściąga (z wnętrza herdr, ID czytaj z JSON): `herdr workspace list`, `herdr pane list --workspace w1`,
`herdr pane process-info --pane ID`, `herdr pane read ID --source recent-unwrapped --lines 20`,
`herdr agent list`, `herdr agent wait ID --until idle --timeout 15000`. `pane run` tylko kolejkuje
komendę, a `pane close` nie pyta o potwierdzenie.

## CI i minuty GitHub Actions

Repo projektów są publiczne (minuty bez limitu), `sh-system` i szablon mają plan Free (2000 minut
miesięcznie dla repo prywatnych, każdy job zaokrąglony w górę do minuty). Nie płacimy za minuty, więc
zasady oszczędzania obowiązują wszędzie (`sh-system`, `ci.yml` i `staging.yml` szablonu):

- `concurrency` z `cancel-in-progress` tylko dla PR;
- zakres zmian liczy `scripts/ci/zakres.sh` (w szablonie `scripts/ci-zakres.sh`) w pierwszym lekkim
  jobie; ciężkie joby przez `needs` i `if`, bez filtra `paths` workflow (PR bez checków `shctl` uznałby
  za „brak CI”); pominięty job (`SKIPPED`) liczy się jak zaliczony;
- po merge'u na `main` tylko smoke; noc (`schedule`) pełne testy tylko po świeżych commitach;
  `workflow_dispatch` ręcznie;
- `timeout-minutes` w każdym jobie (testy `scripts/ci/tests/workflow.bats`, w szablonie
  `scripts/tests/ci-workflow.bats`);
- E2E (`e2e` na PR z kodem aplikacji, `qa-staging` dla `stage/08-qa`) z cache przeglądarek; staging
  tylko przy zmianie `supabase/migrations/`.

| Repo | PR z kodem | PR z samą dokumentacją | Push na main |
|---|---|---|---|
| sh-system | `szybkie` (podręcznik, `shctl.md`, skille) + `bats` | `szybkie` | `szybkie` |
| projekt | `check-dod`, `gitleaks`, `lint`, `test`, `e2e` | `check-dod`, `gitleaks` | `check-dod` z gitleaks |

### Repo prywatne

Tylko na wyraźne polecenie właściciela (`shctl new-project --prywatny`): zmienna repo
`SH_RUNS_ON = ["self-hosted","sh-imac"]` kieruje joby na runner serwera. Do zrobienia przez właściciela
przed pierwszym takim repo: zarejestrować runner z etykietą `sh-imac` i sprawdzić joby szablonu na
macOS (kroki zakładają Linuksa). Ruleset `sh-ochrona-galezi` w repo prywatnym wymaga GitHub Pro.

## Powiadomienia push

`/Users/Shared/sh/bin/notify.sh <min|default|high|urgent> <tytuł> <treść> [url] [tagi]` wysyła push
przez ntfy.sh. Temat leży w `~/.config/sh/ntfy-topic` (działa jak hasło, poza repo). Kody: 0 wysłano,
1 błąd wysyłki, 2 złe argumenty, 3 brak tematu. Hooków `Notification` Claude Code nie ma: workerów
pilnuje orkiestrator (`shctl task wait`).

## Synchronizacja Obsidiana

Vault `~/Documents/Obsidian Vault` ma w `SH/` klony `docs/`: `SH/sh-system` i `SH/Projekty/NAZWA`
(zakłada `shctl new-project` albo `obsidian link`), zwykłe foldery `SH/Skrzynka/NAZWA` i plik
`SH/Wszystkie projekty.md`. `obsidian-sync.sh` co 5 minut robi `git pull --ff-only` w każdym klonie
(bez merge'a, resetu i powiadomień; nieudany pull to `POMINIĘTY KATALOG: powód` w logu), potem
zapisuje `Wszystkie projekty.md`: tabelę z frontmattera `docs/Projekt.md` każdego klonu (projekty z
czymś czekającym na właściciela najpierw, potem w toku, potem zakończone). `Projekt.md` generuje
`scripts/sync-status.sh` projektu przy każdej zmianie stanu w shctl. Pod launchd brak tokenu kończy
pull błędem (`GIT_TERMINAL_PROMPT=0`); token daje helper `gh auth git-credential` z `install.sh`.
Jedyna wtyczka vaulta to Dataview (stare dashboardy v1); Obsidian Git nie jest instalowany.

## Przypomnienia o czekaniu na właściciela

`przypomnienia.sh` co 15 minut czyta `/Users/Shared/sh/stan/czeka/NAZWA.json` (pozycje „Czeka na
Ciebie” z czasem, zapisuje je `sync-status.sh`) i wysyła jeden push na projekt, gdy coś czeka dłużej
niż 4 h (`SH_PRZYPOMNIENIE_PROG`, 14400 s), tylko w godzinach 8–22. Ta sama pozycja wraca najwcześniej
po 4 h. Stan: `stan/przypomnienia.json`, wyłączenie: `stan/przypomnienia.off`.

## Strażnik orkiestratora

`sh-watchdog.sh` (bez AI) co 5 minut sprawdza orkiestratora (kontrola z „Herdr”). Gdy nie działa,
uruchamia `sh-start.sh --no-attach`, czeka do 15 s i wysyła „Orkiestrator uruchomiony ponownie”
(high); gdy nie wstanie, raz „Orkiestrator nie wstał po restarcie” (urgent). Proces poza panelem to
`UWAGA` bez restartu. Flaga `stan/autostart.off` wyłącza restart. Limitów subskrypcji nie śledzi:
`/Users/Shared/sh/limity.md` prowadzi właściciel albo orkiestrator. Log `logs/watchdog.log` (rotacja
przy 1 MB).

## Izolacja agentów

Trzy warstwy: reguły uprawnień Claude Code, hooki `PreToolUse` i sandbox Claude Code dla Basha w
sesjach SH. Chronią przed pomyłką agenta i obejściem reguł przez interpretery. Granicą bezpieczeństwa
jest brak poświadczeń produkcyjnych na serwerze.

### Claude Code

`~/.claude/settings.json` ma `deny` dla `Read` i `Edit`: `~/Pictures`, `~/Movies`, `~/Music`,
`~/.gnupg`, `~/.ssh/id_*`, `Keychains`, `Safari`, `Messages`, `Mail` i profili wszystkich przeglądarek
w `~/Library/Application Support` (nową przeglądarkę dopisujemy przy instalacji). `~/Documents`,
`~/Desktop`, `~/Downloads` i iCloud blokują tylko ustawienia sesji SH.

### Sandbox sesji SH

Profil workera (`.claude/roles/worker/settings.json` szablonu) i ustawienia orkiestratora
(`scripts/server/orkiestrator-settings.json`, także sesja buildera w `/Users/Shared/sh`) mają
`sandbox.enabled` i `allowUnsandboxedCommands: false`.

| | Worker | Orkiestrator i builder |
|---|---|---|
| Poza sandboxem (`excludedCommands`) | `git push|fetch|pull`, `gh`, `shctl escalate`, `brew install` | `shctl`, `herdr`, `gh`, `git push|fetch|pull`, `git worktree add|remove|prune`, `notify.sh` |
| Zapis | worktree, `$TMPDIR`, cache pnpm/npm, blokady pnpm w `/tmp/pnpm-*` | `/Users/Shared/sh`, `$TMPDIR` |
| Sieć | GitHub, npm, pobieranie Playwrighta, gniazdo Dockera | GitHub, ntfy.sh |

Ustalenia (testy w `sh-dryrun`, 2026-11-09):

- Wyjątek dostaje tylko prosta komenda pasująca do wzorca. Komenda złożona (`&&`, `;`, potok,
  przekierowanie do pliku, zmienna przed komendą) działa w sandboxie bez tokenu: `git push` pyta o
  login, `gh` daje 401. Stąd zasada jednej komendy na wywołanie (`CLAUDE-sh.md`, skille).
- `git -C KATALOG` zawsze działa w sandboxie; zapis i sieć przez `cd KATALOG`, potem `git …`.
- Przeglądarki nie startują w sandboxie: E2E i Lighthouse tylko w CI, lokalnie lint, typy, testy
  jednostkowe i build.
- `mktemp` bez szablonu i `/dev/fd` nie działają (sekcja „Praca nad systemem”).
- `gh` jest poza sandboxem, więc hook `gh-plik-hook.sh` przepuszcza w `--body-file`, `-F` i
  `--notes-file` tylko stdin i pliki z `/Users/Shared/sh/`. Deny obejmuje `git --no-index`,
  `git config`, `blame --contents`, `git -C` poza `/Users/Shared/sh`.
- Pliki ustawień sesji i skille w `/Users/Shared/sh/.claude` są chronione przed zapisem agenta.

### Uprawnienia sesji SH

- **Zakres odczytu:** hook `odczyt-hook.sh` (`Read|Glob|Grep`, fail-closed) dopuszcza katalog projektu
  sesji (worker: jego worktree, orkiestrator: `/Users/Shared/sh`), `~/.claude`, `sh-system/plugin` i
  katalog tymczasowy sesji. Reguły `allow` ze ścieżką z kropką (`/Users/sebastiant.`) nie działają,
  dlatego hook.
- **Pliki env:** `env-hook.sh` w profilu workera blokuje każdy `.env*` poza `.env.example`.
- **Orkiestrator** ma `allow` na rutynę (`shctl`, `notify.sh`, odczyt i sterowanie agentami w
  `herdr`, `gh pr|issue|run|repo view`, git do odczytu i zapisu po `cd`, `git worktree add|remove`
  tylko w `wt/` i `wt-system/`) i `deny` na: `git push --force|--delete|--mirror` i na `production`,
  refspec z `+`, `git reset --hard`, `git clean`, `git switch|checkout`, usuwanie gałęzi, `git -c`,
  `--exec`, `gh api` z metodą lub polami, `gh repo delete`, `gh secret`, `gh auth`, `gh workflow`
  (test `scripts/server/tests/orkiestrator-settings.bats`).

### Codex

`~/.codex/config.toml`: `sandbox_mode = "workspace-write"` bez dodatkowych katalogów zapisu. Profil
`reviewer` to `~/.codex/reviewer.config.toml` (symlink do `codex/reviewer.config.toml`): `model`
`gpt-6-astra`, `model_reasoning_effort` `high`, `sandbox_mode` `read-only`, `approval_policy` `never`.
`shctl review run` podaje zawsze `-m`, effort z `/Users/Shared/sh/konfiguracja.md` i `-s read-only`.
Codex nie blokuje odczytu poza katalogiem roboczym (znane ograniczenie, `proces.md`). Reviewer Claude
nie ma profilu na serwerze: `claude -p` z `.claude/roles/reviewer/settings.json` z `main` projektu.

## Globalny hook git

`install.sh` ustawia globalny `core.hooksPath` na `scripts/server/git-hooks/`. `pre-push` odrzuca push
na `production`; pozostałe wrappery wołają tylko `.git/hooks` i lokalny `core.hooksPath` repo, nigdy
hooków śledzonych w repo. Lokalny `core.hooksPath` (np. husky) wyłącza hook globalny: ostrzegają
`install.sh` i `shctl doctor`.

## Dziennik narzędzi

| Data | Narzędzie | Źródło | Po co |
|---|---|---|---|
| 2026-11-01 | yq, gitleaks, uv, fnm, bats-core | oficjalne wydania, `~/.local` | bazowy toolchain |
| 2026-11-01 | Node 26.13.0, pnpm 12.16.1 | fnm, corepack | bazowy toolchain |
| 2026-11-01 | Playwright 1.61.1, Chrome for Testing | npx | testy E2E |
| 2026-11-01 | herdr 0.9.5 | oficjalny instalator, `~/.local/bin` | multiplekser agentów |
