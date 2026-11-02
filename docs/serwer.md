# Serwer software house'u

iMac13,2 (2012), Intel i5-3470S, 4 rdzenie bez HT, 24 GB RAM, macOS 14.8.9 przez OpenCore
Legacy Patcher. Narzędzia, przeglądarki i testy działają natywnie. Docker służy do usług.

- Skrypty, Brewfile, plisty: źródłem jest repo `sh-system` (sekcja „Skrypty serwera”)
- Zmiany w systemie: gałąź i PR (sekcja „Praca nad systemem”)
- Toolchain: `~/sh/bin/setup-toolchain.sh` (idempotentny, bez sudo)
- Homebrew: `~/sh/Brewfile` (symlink do `scripts/server/Brewfile`)
- Porty: `~/sh/porty.md`
- Chrome for Testing: `~/sh/browsers`

## Skrypty serwera

Źródłem skryptów jest repo `sh-system`. `~/sh/bin` zawiera symlinki do `scripts/server/*.sh` i
plików wykonywalnych z `scripts/shctl/`. Zmiany wprowadzamy w repo, a na serwerze działają od razu.

```sh
~/sh/sh-system/scripts/server/install.sh
```

Skrypt jest idempotentny i uruchamiamy go po dodaniu nowego skryptu. Zwykły plik w `~/sh/bin`
zastępuje tylko, gdy jest identyczny z repo; przy różnicy kończy się błędem i niczego nie nadpisuje,
więc zmiany trzeba najpierw przenieść do repo. Plik spoza repo zgłasza ostrzeżeniem.

`~/sh/Brewfile` to także symlink, do `scripts/server/Brewfile`, na tych samych zasadach. Dopisane
narzędzie trzeba więc zacommitować w `sh-system`.

Plisty LaunchAgentów mają źródło w `scripts/server/*.plist`. `install.sh` kopiuje je tylko przy
różnicy, a potem przeładowuje agenta (`launchctl bootout` i `bootstrap`). Agenta niezaładowanego
(`launchctl print`) ładuje przy każdym uruchomieniu, także bez zmiany plisty, chyba że
`~/sh/stan/autostart.off` wyłącza `sh-start`. Nieudany `bootstrap`
kończy się kodem błędu, komendą do ręcznego załadowania i powiadomieniem `notify.sh high`. Agent z `RunAtLoad` startuje wtedy od razu: dla
`sh-start` jest to bezpieczne, bo skrypt uruchamia tylko to, co nie działa. Ręczna zmiana w
`~/Library/LaunchAgents` zostanie nadpisana przy następnym `install.sh`.

## Praca nad systemem

Zmiany w `sh-system` i `sh-template-projekt` idą przez gałąź i PR, bez bezpośrednich commitów na
`main`. Po zielonym CI agent merguje PR sam, bez pytania właściciela.

Wyjątek: zmiana dotycząca bezpieczeństwa, dostępów albo produkcji czeka na zgodę właściciela także
po zielonym CI.

Test na prawdziwym GitHubie uruchamiamy wyłącznie po wyraźnej zgodzie właściciela w danej rozmowie,
tak jak zmiany dotyczące bezpieczeństwa. Dotyczy to `SHCTL_E2E=1` i każdego ręcznego wywołania, które
może założyć repo lub zmienić je na GitHubie. Odczyt stanu repo zgody nie wymaga.

Repo testowe ma unikalną nazwę `sh-test-RRRRMMDD-HHMM` i przed utworzeniem trafia do
`~/sh/stan/do-usuniecia.md` (nazwa, data, po co). Repo usuwa właściciel. `shctl doctor` pokazuje, ile
repo czeka na usunięcie, i zdejmuje z listy te, których już nie ma.

## Polityka instalacji

1. **Zależności projektowe** agenci instalują sami (pnpm, uv itp.).
2. **Narzędzia z brew** agenci instalują sami, ale każde dopisują do `~/sh/Brewfile` (commit w
   `sh-system`)
   i do sekcji „Dziennik narzędzi” poniżej.
3. **sudo, ustawienia systemu i Docker Desktop** zmienia wyłącznie właściciel.
   Agent wypisuje potrzebną komendę i czeka.

### Ograniczenia tej maszyny

- **Homebrew wymaga gita >= 2.30.** Dziś jest 2.39.5 z CLT 16.2. Poniżej tej wersji każde
  polecenie, nawet `brew config`, próbuje budować gita ze źródeł.
- **Przed `brew install` sprawdź butelkę:**
  `curl -fsS https://formulae.brew.sh/api/formula/NAZWA.json | jq '.bottle.stable.files|keys'`.
  Wymagany jest tag `sonoma` albo `all`. Bez niego formuła kompiluje się lokalnie, co na tym
  CPU może trwać godziny. Wtedy użyj oficjalnej binarki `darwin-x86_64` w `~/.local/bin`,
  z przypiętą wersją i SHA-256 w `setup-toolchain.sh`.
- **Playwright jest przypięty do 1.61.1.** Dokładnie tę wersję wpisuj w projektach, bez `^`.
  Od 1.62 WebKit dla macOS 14 pada z błędem `Unknown setting: PushAPIEnabled`. Build jest
  zamrożony, więc testuje starszy silnik niż aktualne Safari.
- **Wolne miejsce to ok. 25 GB.** Poniżej 15 GB nie uruchamiaj nowych worktree ani stacków.

## Limity pracy równoległej

- Maksymalnie **2 workery lokalne**.
- **Jeden** ciężki job naraz (build, E2E, CI) i `workers: 1` w Playwright.
- Maksymalnie **jeden stack Supabase projektów SH** przy limicie Docker 7,75 GiB. `supabase-local`
  to stary system i nie wlicza się do limitu; właściciel może go zatrzymać na czas pilota.
  Stack zużywa ok. 2 GiB; w nowych projektach wyłączaj `analytics` i `studio`, jeśli nie są
  potrzebne (ok. 0,9 GiB mniej).

## Do zrobienia przez właściciela

Aktualizacja CLT do 16.2 wykonana 2026-11-01 (git 2.39.5, Homebrew działa).

Pełna lista profili na poziomie systemu:

```sh
sudo profiles list -all
```

## Node

- Nowe powłoki zsh: fnm, Node 26 LTS, pnpm przez corepack.
- Paperclip (launchd): nvm, Node 24, bez fnm i bez pnpm. Działające usługi tego nie zauważą.
- Projekt na innej wersji Node ma `.node-version`; fnm przełącza się przy `cd`.
- Kopia sprzed zmian: `~/.zshrc.bak-toolchain`.

## Herdr

Herdr 0.9.5 (repo przeniesione na `herdrdev/herdr`) to dom orkiestratora. Workspace `sh`:
panel `orkiestrator` (w1:p1) z `claude remote-control --name sh-orkiestrator` w `~/sh`,
panel `powloka` (w1:p2). ID mogą się zmienić, dlatego skrypty szukają paneli po etykiecie.

- Skrypt: `~/sh/bin/sh-start.sh`, test CLI: `~/sh/bin/test-herdr.sh`
- Autostart: `~/Library/LaunchAgents/pl.iskt.softwarehouse.sh-start.plist`
- Konfiguracja: `~/.config/herdr/config.toml`
- Logi: `~/sh/logs/`, `~/.config/herdr/herdr-server.log`
- Skill: `~/.claude/skills/herdr/SKILL.md`

### Uruchomienie

Po zalogowaniu LaunchAgent uruchamia `zsh -lic`, czeka na Docker Desktop (do 300 s) i sieć
(do 120 s), po czym startuje serwer, układ i orkiestratora. Samo `zsh -l` nie czyta `.zshrc`,
stąd `-i`. Docker Desktop ma wyłączony AutoStart, więc skrypt tylko go otwiera, bez zmiany ustawień.

Ręcznie z terminala:

```sh
~/sh/bin/sh-start.sh              # przygotowuje i podlacza
~/sh/bin/sh-start.sh --no-attach  # tylko przygotowuje
```

Orkiestrator z telefonu: aplikacja Claude, zakładka Code, sesja `sh-orkiestrator`.

### SSH

Stan z 2026-11-01: Zdalne logowanie jest włączone (port 22 słucha), hasła są dozwolone, a
`~/.ssh/authorized_keys` nie istnieje. Włączenie i wyłączenie: Ustawienia systemowe → Ogólne →
Udostępnianie → Zdalne logowanie albo `sudo systemsetup -setremotelogin on|off`. Przejście na
same klucze opisuje sekcja „Izolacja agentów”.

Połączenie (ta ścieżka nie była jeszcze testowana):

```sh
ssh sebastiant.@192.168.0.245
~/sh/bin/sh-start.sh
```

### Odłączenie bez zabijania sesji

`ctrl+b`, potem `q`. Klient się kończy, serwer i panele działają dalej. Powrót: `herdr` albo
`~/sh/bin/sh-start.sh`. Zamknięcie terminala też nie zatrzymuje serwera.

Nie używaj `exit` w panelu orkiestratora i `herdr server stop` w trakcie pracy: to drugie
kończy wszystkie procesy w panelach.

### Restart

```sh
herdr server stop
launchctl kickstart gui/$(id -u)/pl.iskt.softwarehouse.sh-start
```

Po restarcie serwera wraca układ, ale nie procesy. Skrypt uruchamia orkiestratora ponownie
tylko wtedy, gdy nie działa, więc można go wywoływać wielokrotnie. Sesje agentów w innych
panelach trzeba wznowić ręcznie: integracja `herdr integration install claude` nie jest
zainstalowana, bo zmienia konfigurację Claude Code.

Wyłączenie autostartu:

```sh
mkdir -p ~/sh/stan
touch ~/sh/stan/autostart.off
launchctl bootout gui/$(id -u)/pl.iskt.softwarehouse.sh-start
```

Sam `bootout` nie wystarczy, bo kolejny `install.sh` załadowałby agenta z powrotem. Przy fladze
`install.sh` wypisuje „autostart wyłączony przez właściciela” i nie ładuje `sh-start`. Zmienioną
plistę nadal kopiuje, ale nie dotyka `launchd`.

Wyłączenie przetrwa restart. `launchd` przy logowaniu wczyta plistę i uruchomi
`sh-start.sh --autostart`, ale skrypt przy fladze od razu kończy pracę z kodem 0 i zapisuje ten sam
komunikat w `~/sh/logs/sh-start.log`, bez Dockera, herdr i orkiestratora. Ręczne `sh-start.sh` bez
`--autostart` działa zawsze, także przy fladze. Testy używają atrap; samego restartu maszyny nie
testowano.

Włączenie z powrotem:

```sh
rm ~/sh/stan/autostart.off
~/sh/sh-system/scripts/server/install.sh
```

### Ściąga CLI herdr

Wszystkie komendy wykonano na tej maszynie (herdr 0.9.5). Sterowanie panelami uruchamiaj
z wnętrza herdr (`HERDR_ENV=1`). ID czytaj z JSON, nie zgaduj ich.

```sh
# Stan
herdr --version
herdr status server
herdr workspace list
herdr pane list --workspace w1
herdr pane get w1:p1
herdr pane process-info --pane w1:p1
herdr agent list

# Praca w panelu
herdr pane split --current --direction down --cwd "$PWD" --no-focus   # .result.pane.pane_id
herdr pane split w1:p1 --direction right --cwd ~/sh --no-focus
herdr pane rename w1:p3 nazwa
herdr pane run w1:p3 'echo test-herdr'
herdr pane wait-output w1:p3 --regex '(?m)^test-herdr$' --source recent-unwrapped --timeout 15000
herdr pane read w1:p3 --source recent-unwrapped --lines 20
herdr pane send-keys w1:p3 Enter
herdr pane close w1:p3

# Agent
herdr agent wait w1:p1 --until idle --timeout 15000

# Workspace i serwer
herdr workspace create --cwd ~/sh --label sh --no-focus
herdr workspace focus w1
herdr server reload-config
herdr server stop
herdr --default-config
```

- `pane wait-output --match tekst` dopasuje też echo wpisanej komendy; użyj regexu całej linii.
- `pane run` tylko kolejkuje komendę; wynik potwierdza dopiero `wait-output`.
- `pane close` nie pyta o potwierdzenie.

## Obciążenie i dysk

Diagnoza z 2026-11-01, 16:05–16:16. Niczego nie zatrzymano ani nie usunięto.

### Wnioski

- **Stałe tło maszyny jest umiarkowane.** Po aktualizacji CLT load 1-min spadł z 16 do 4,8
  w 3 minuty, a CPU miało 55% wolnego. Wysoki load był więc chwilowy, nie stały.
- **Skoki load pochodzą z obciążeń chwilowych.** W tej diagnozie: aktualizacja CLT (70% rdzenia),
  a po niej Spotlight (58%). Przyczyny wartości 40–59 z 15:32, sprzed aktualizacji, nie ustalono.
  Mogły to być buildy lub joby CI, ale tego nie zmierzono.
- **RAM jest zapasem na granicy.** Wolne 0,1–0,8 GB, swap 7,8–9,2 GB. Swap nie wyjaśnia
  jednak load: spadł on mimo prawie pełnego swapu. Skoków wciąż trzeba się spodziewać przy pracy.
- **Klony Chrome nie zwolnią miejsca.** `com.google.Chrome.code_sign_clone` pokazuje w `du`
  51,9 GB, ale to 37 klonów APFS współdzielących bloki z aktywnym Chrome. Fizyczny odzysk
  to ok. 0 GB (test po pierwszym bloku pliku). Nie ruszać; jeden klon jest w użyciu.
- **Time Machine nie działa.** Dyski HDD1T i Time_Machine_iMac nie są podłączone, a jedyną
  kopią jest 20 lokalnych migawek. Ich usunięcie przed backupem oznacza brak kopii.

### Procesy (średnia z 8 próbek w 3 min)

%CPU liczony względem jednego rdzenia; maszyna ma 4 rdzenie, czyli 400%. Tabele pochodzą z pomiaru
w trakcie aktualizacji CLT. Pomiar bez niej (16:17–16:20): Spotlight 58% (chwilowo), VM Docker 33%,
WindowServer 7%, Paperclip 6%, Claude 6%, Chrome 1%, kernel_task 3%. Kontenery po ok. 5% lub mniej.

| # | Proces | Usługa | %CPU | RAM | Charakter |
|---|---|---|---|---|---|
| 1 | system_installd + softwareupdated | aktualizacja CLT | 71 | 140 MB | chwilowy |
| 2 | VM Virtualization | Docker (wszystkie kontenery) | 35 | 7,8 GB | stały |
| 3 | Chrome (43 procesy) | inne | 20 | 6,0 GB | stały, gdy otwarty |
| 4 | kernel_task | system | 15 | nd. | stały, rośnie przy swapie |
| 5 | WindowServer | system | 11 | 480 MB | stały |
| 6 | node + postgres | Paperclip | 5 | 1,0 GB | stały (launchd) |
| 7 | backupd-helper | Time Machine | 4 | nd. | chwilowy, tylko 1 próbka |
| 8 | Claude Desktop i sesje | inne | 1 | 1,9 GB | stały, gdy otwarty |
| 9 | ChatGPT/Codex (18 procesów) | inne | <1 | 1,3 GB | stały, gdy otwarty |
| 10 | Claude Code CLI | inne | <1 | 410 MB | na czas sesji |

Kontenery wewnątrz VM (`docker stats`, wartości tylko do porównania między sobą):

| Grupa | %CPU | RAM | Charakter |
|---|---|---|---|
| Supabase (11 kontenerów) | 38 | 2,0 GB | stały RAM; CPU chwilowe, w tle ok. 15% |
| Runner release + dind | 18 | 240 MB | stały RAM; CPU chwilowe, w tle ok. 2% |
| Forgejo | 13 | 295 MB | stały RAM; CPU chwilowe, w tle ok. 2% |
| Runner CI + dind | <1 | 360 MB | skokowy, limit 4 GiB przy jobach |

### Dysk

Stan: wolne 25 GB. Wolumen danych zużywa 195,6 GB, z czego ok. 13,6 GB to migawki.

| Pozycja | Fizycznie | Bezpieczne usunięcie? |
|---|---|---|
| Klony Chrome w `/var/folders/.../X` | ~0 (`du`: 51,9 GB) | **Nie ruszać**, zero zysku |
| Docker: obrazy Supabase, Forgejo, CI | 10,5 GB | Nie, działają |
| Docker: dind CI, obrazy w środku | 7,7 GB | Tak, 6 GB; CI pobierze je ponownie |
| Docker: dind release, obrazy w środku | 1,7 GB | Tak; pobranie przy wydaniu |
| Docker: build cache | 2,2 GB | Tak; wolniejszy rebuild `ci-dind` |
| Docker: wolumen `supabase_db` | 0,6 GB | **Nie**, dane |
| Migawki Time Machine | ~13,6 GB | **Dopiero po backupie** |
| `~/Documents/HDD_Dokumenty/Pendrive` | 24 GB | Przenieść, nie kasować |
| Outlook, lokalne dane | 9,3 GB | Zależy od konta; do decyzji |
| Claude `vm_bundles` | 10 GB | Prawdopodobnie tak; pobieranie przy użyciu |
| Chrome, profil Default | 5,8 GB | Nie |
| Chrome `OptGuideOnDeviceModel` | 2,7 GB | Tak, po wyłączeniu AI na urządzeniu |
| npm `_cacache` i `_npx` | 4,1 GB | Tak |
| `Caches/com.openai.codex` | 1,9 GB | Tak, po zamknięciu aplikacji |
| `Caches/Google` | 1,8 GB | Tak, po zamknięciu Chrome |
| `.cache/codex-runtimes` | 1,6 GB | Prawdopodobnie tak |
| Playwright | 1,2 GB | Nie, przypięty toolchain |
| `puccinialin`, Homebrew, node-gyp | 1,1 GB | Tak |
| `.work` w iskt-szkolenia (9× node_modules) | 2,3 GB | Tylko node_modules; `isk52/drzewo` ma niezacommitowane zmiany |
| Worktree E00-01 i review-E00-01 | 0,6 GB | Czyste; po potwierdzeniu scalenia |
| Worktree E00-02, E00-03, podglad | 1,2 GB | Nie: podgląd, niezacommitowane zmiany |
| Paperclip `data/backups` | 2,6 GB | Nie, brak sprawdzonej kopii gdzie indziej |
| Paperclip logi i run-logs | 0,4 GB | Nie warto |
| Logi `~/Library/Logs`, `/var/log` | 0,1 GB | Nie warto |
| Swap (wolumen VM) | 9,7 GB | Wraca po restarcie; nie liczyć jako trwałe |
| pnpm, uv | <0,1 GB | Nie warto |

### Plan odzyskania 50 GB

**Sam cache nie wystarczy: bez przeniesienia `Pendrive` plan daje ok. 49 GB.** Dysk zewnętrzny
jest potrzebny do backupu i do przeniesienia danych. Kolejność ma znaczenie, bo pliki usunięte
przed kasowaniem migawek nie zwalniają miejsca, dopóki migawki istnieją.

Kroki czekają na akceptację.

| Etap | Działanie | Zysk | Skumulowanie |
|---|---|---|---|
| 0 | Podłącz dysk, wykonaj backup | 0 | 0 |
| 1 | Cache | 8,9 GB | 8,9 GB |
| 2 | Docker | 9,7 GB | 18,6 GB |
| 3 | Claude, Chrome, Codex | 14,3 GB | 32,9 GB |
| 4 | Zamknięte worktree | 2,9 GB | 35,8 GB |
| 5 | Przeniesienie `Pendrive` | 24 GB | 59,8 GB |
| 6 | Migawki | 13,6 GB | 73,4 GB |

Zapobiegawczo, bo macOS pobiera aktualizacje sam, a Tahoe ma 17,9 GB:

```sh
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false
```

```sh
# Etap 0: backup (po podlaczeniu dysku Time Machine)
tmutil startbackup --block
tmutil latestbackup

# Etap 1: cache (zamknij Chrome i ChatGPT)
npm cache clean --force
rm -rf ~/.npm/_npx ~/Library/Caches/Google ~/Library/Caches/com.openai.codex \
  ~/Library/Caches/puccinialin ~/Library/Caches/node-gyp
brew cleanup -s

# Etap 2: Docker
docker exec softwarehouse-ci-dind docker image prune -a -f
docker exec softwarehouse-release-dind docker image prune -a -f
docker builder prune -a -f
docker run --rm --privileged --pid=host docker/desktop-reclaim-space

# Etap 3: wylacz wczesniej AI na urzadzeniu w chrome://settings/system, zamknij Claude i Chrome
rm -rf ~/Library/"Application Support"/Claude/vm_bundles
rm -rf ~/Library/"Application Support"/Google/Chrome/OptGuideOnDeviceModel
rm -rf ~/.cache/codex-runtimes

# Etap 4: po potwierdzeniu, ze etapy sa zamkniete
# Tylko node_modules: .work/isk52/drzewo ma niezacommitowane zmiany, calego .work NIE kasowac
find ~/Documents/ISKT_Greennovation/Aplikacje/szkolenia_iskt_pl/iskt-szkolenia/.work \
  -type d -name node_modules -prune -exec rm -rf {} +
git -C ~/Projects/strona-iskt/worktrees/E00-01 worktree remove "$HOME/Projects/strona-iskt/worktrees/review-E00-01"
git -C ~/Projects/strona-iskt/worktrees/podglad worktree remove "$HOME/Projects/strona-iskt/worktrees/E00-01"

# Etap 5: wstaw nazwe dysku; kasowanie tylko, gdy diff nic nie wypisze
DST=/Volumes/DYSK/Archiwum-iMac
mkdir -p "$DST"
rsync -aE ~/Documents/HDD_Dokumenty/Pendrive "$DST"/
diff -rq ~/Documents/HDD_Dokumenty/Pendrive "$DST"/Pendrive && \
  rm -rf ~/Documents/HDD_Dokumenty/Pendrive

# Etap 6: tylko po udanym etapie 0
sudo tmutil deletelocalsnapshots /
df -h /System/Volumes/Data
```

Etap 2 obejmuje `desktop-reclaim-space`; działanie sprawdzić, porównując `du -h` pliku
`Docker.raw` przed i po. Etap 3 zgłosić, jeśli Claude nie pobierze `vm_bundles` przy użyciu.

### Usługi na czas pilota

Przed pilotem zrestartuj maszynę: czyści swap i chwilowo oddaje ok. 8–10 GB dysku. Sprawdź wcześniej,
czy Paperclip nie ma aktywnych zadań.

| Usługa | Zalecenie | Zysk | Uzasadnienie |
|---|---|---|---|
| Runner release + dind | **Wstrzymać** | 240 MB | Pilot nie robi wydań; zysk jest mały, ale bez kosztu |
| Chrome | **Zamknąć** na czas pracy agentów | 6 GB | Największy zysk RAM |
| ChatGPT/Codex Desktop | **Zamknąć** na czas pracy agentów | 1,3 GB | Worker używa Codex CLI |
| Claude Desktop | **Zamknąć** na czas pracy agentów | 1,9 GB | Worker używa Claude Code |
| Runner CI + dind | Zostawić; wstrzymać przy dużym obciążeniu | do 4 GiB | Bez niego PR nie dostaną kontroli |
| Forgejo | Zostawić | nd. | Bez niego nie ma repo i review |
| Paperclip | Zostawić, jeśli pilot na nim działa | 1 GB | Inaczej wstrzymać (komenda niżej) |
| Hermes | Bez zmian | 200 MB | Znikomy zysk |
| Supabase `supabase-local` | Decyduje właściciel | ok. 2 GB | Stary system, poza limitem stacków; analytics to 0,6 GB |

Kontenery mają `restart: unless-stopped`, więc po `docker stop` wrócą dopiero po `docker start`,
także po restarcie Dockera. Paperclip ma `KeepAlive`, dlatego `kill` nie wystarczy.
Przed jego wstrzymaniem upewnij się, że nie ma aktywnych zadań, bo przerwie agentów.

```sh
# Wstrzymanie runnera release
docker stop softwarehouse-release-runner softwarehouse-release-dind
# Wznowienie
docker start softwarehouse-release-dind softwarehouse-release-runner

# Wstrzymanie runnera CI
docker stop softwarehouse-ci-runner softwarehouse-ci-dind
# Wznowienie
docker start softwarehouse-ci-dind softwarehouse-ci-runner

# Wstrzymanie Paperclipa (z wbudowanym Postgresem)
launchctl bootout gui/$(id -u)/ing.paperclip.paperclipai
# Wznowienie
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/ing.paperclip.paperclipai.plist
```

## Powiadomienia push

`~/sh/bin/notify.sh` wysyła push przez ntfy.sh. Katalog `~/sh/bin` jest w `PATH` (`~/.zshrc`).

```sh
notify.sh <min|default|high|urgent> <tytuł> <treść> [url] [tagi]

notify.sh default "Test SH" "Działa"
notify.sh high "Backup" "Nieudany" https://example.com/log warning,floppy_disk
notify.sh min "Build" "Gotowy" "" white_check_mark   # tagi bez URL-a
```

- Temat leży w `~/.config/sh/ntfy-topic`. Bez pliku skrypt kończy się czytelnym błędem.
- `url` trafia do nagłówka `Click`, a `tagi` to lista po przecinku.
- Kody wyjścia: 0 wysłano, 1 błąd wysyłki, 2 złe argumenty, 3 brak lub zły temat.
- Temat na ntfy.sh działa jak hasło: kto go zna, ten czyta i wysyła wiadomości. Nie zapisuj
  go w repozytorium i nie wysyłaj w powiadomieniach sekretów.

### Hook Claude Code

Hook `Notification` w `~/.claude/settings.json` wysyła push z tytułem „Claude czeka na Ciebie”
i nazwą katalogu sesji w treści. Działa tylko, gdy proces Claude Code ma `SH_NOTIFY=1`:

```sh
SH_NOTIFY=1 claude
```

Hook dziedziczy środowisko procesu Claude Code, więc zmienną trzeba ustawić przed jego
startem; zmiana w działającej sesji nic nie da. Domyślnie nic jej nie ustawia, również
`sh-start.sh`.

Bez `matcher` hook reaguje na każdy typ powiadomienia, także `auth_success` czy
`agent_completed`. Żeby zostawić tylko oczekiwanie na człowieka, dodaj obok `"hooks"`:

```json
"matcher": "permission_prompt|idle_prompt"
```

Format hooków: <https://code.claude.com/docs/en/hooks>. Hook jest asynchroniczny (`async`),
więc nie blokuje Claude'a, a błąd wysyłki nie pojawia się w sesji. Diagnoza:
`claude --debug` albo ręczne uruchomienie `notify.sh`.

## Izolacja agentów

Agenci pracują autonomicznie w `~/sh`. Na maszynie nie ma ważnych danych, więc izolacja jest
lekka: chroni przed pomyłką agenta, nie przed celowym obejściem.

### Stan systemu (2026-11-01)

| Obszar | Stan | Uwagi |
|---|---|---|
| FileVault | wyłączony | |
| Firewall | włączony | bez trybu ukrycia; podpisane aplikacje przepuszczane |
| Zdalne logowanie | włączone | hasła dozwolone, brak `authorized_keys` |
| pmset | `sleep 0`, `disksleep 0`, `autorestart 1`, `womp 1` | ekran gaśnie po 15 min, działa `caffeinate` |
| Docker Desktop | `AutoStart: false` | uruchamia go `sh-start.sh` |

Komendy do wykonania przez właściciela (wymagają sudo):

```sh
# Tryb ukrycia firewalla (opcjonalnie)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

# Jeśli SSH nie jest potrzebne
sudo systemsetup -setremotelogin off
```

Same klucze SSH, dopiero gdy klucz jest w `authorized_keys` i logowanie nim działa, a stara
sesja SSH pozostaje otwarta:

```sh
# 1. Na komputerze klienckim
ssh-copy-id sebastiant.@192.168.0.245
ssh -o PasswordAuthentication=no sebastiant.@192.168.0.245 true

# 2. Na serwerze
printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\n' |
  sudo tee /etc/ssh/sshd_config.d/050-tylko-klucze.conf
sudo sshd -t && sudo launchctl kickstart -k system/com.openssh.sshd
```

FileVault włącza `sudo fdesetup enable`, ale na tym serwerze nie jest zalecany: po restarcie
Mac czeka na hasło, więc `autorestart` i autostart usług przestają działać bez człowieka. To
także Mac z OpenCore Legacy Patcher, więc przed włączeniem trzeba sprawdzić zgodność.

### Claude Code

`~/.claude/settings.json` ma w `permissions.deny` reguły `Read` i `Edit` dla: `~/Pictures`
(z biblioteką Zdjęć), `~/Movies`, `~/Music`, `~/.gnupg`, `~/.ssh/id_*` oraz katalogów
`Keychains`, `Safari`, `Containers/com.apple.Safari*`, `Application Support/Google`, `Messages` i
`Mail` w `~/Library`. `~/Documents`, `~/Desktop` i `~/Downloads` celowo zostają dostępne.

Profile przeglądarek: w `/Applications` są tylko Chrome i Safari (stan z 2026-11-01), ale reguły
obejmują też pozostałe katalogi w `Application Support`: `Firefox` i `Mozilla` (60 MB profili po
odinstalowanej przeglądarce) oraz puste zaczątki `Arc`, `BraveSoftware`, `Chromium`,
`Microsoft Edge`, `Vivaldi` i `com.operasoftware.Opera`. Nową przeglądarkę dopisujemy do `deny` przy
instalacji.

Składnia `~/` oznacza katalog domowy, `/**` zawartość katalogu. Pojedynczy `/` nie jest ścieżką
bezwzględną, do tego służy `//`. Format: <https://code.claude.com/docs/en/permissions>.

Test z 2026-11-01: `ls ~/Pictures`, `cat`, `find` i narzędzie Read są blokowane, zaś
`~/Documents` działa. Narzędzie Read jest też blokowane w `Application Support/Firefox`.

Ograniczenia:

- Reguły obejmują narzędzia Claude'a i rozpoznawane polecenia powłoki. Według dokumentacji nie
  obejmują podprocesów, które same otwierają pliki (np. skrypt w Pythonie), ani poleceń bez
  nazwy pliku (`grep -r` uruchomiony w chronionym katalogu).
- Reguły nie dotyczą Codexa ani innych narzędzi.
- Ochronę na poziomie systemu daje `sandbox.enabled`. Jest wyłączony, bo ogranicza też sieć i
  zapis wszystkich poleceń Bash, a izolacja ma być lekka.

### Codex

`~/.codex/config.toml` ustawia `sandbox_mode = "workspace-write"`, a w
`[sandbox_workspace_write]` pustą listę `writable_roots` oraz `exclude_slash_tmp` i
`exclude_tmpdir_env_var`. Kopia sprzed zmiany: `~/.codex/config.toml.bak-sandbox`.

Test przez `codex exec`, uruchomiony w `~/sh`: zapis w katalogu roboczym działa, a `/tmp`,
`$TMPDIR` i `~` zwracają „Operation not permitted”.

- `codex sandbox -- <komenda>` nie czyta `sandbox_mode`, więc nie nadaje się do tego testu.
- Narzędzia wymagające katalogu tymczasowego mogą nie działać w Codexie. Wtedy usuń
  `exclude_tmpdir_env_var` i `exclude_slash_tmp`.
- Sandbox ogranicza zapis, nie odczyt spoza katalogu roboczego. Zasada izolacji obowiązuje też
  Codexa, a brak blokady odczytu to znane ograniczenie, akceptowane w etapie A (Codex tylko robi
  review).
- Ten sam plik czyta aplikacja ChatGPT, nie była testowana po zmianie.

#### Profil reviewer

`shctl review run` uruchamia `codex exec -p reviewer`. Profil to `~/.codex/reviewer.config.toml`,
symlink zakładany przez `install.sh` do `sh-system/codex/reviewer.config.toml`. Nakłada się na
`config.toml`:

| Klucz | Wartość | Po co |
|---|---|---|
| `model` | `gpt-6.1-terra` | Model reviewera z `konfiguracja.md` szablonu („GPT-6.1 Terra”) |
| `model_reasoning_effort` | `high` | Jak `modele.reviewer.rozumowanie` w szablonie |
| `sandbox_mode` | `read-only` | Reviewer niczego nie zapisuje, testy uruchamia CI |
| `approval_policy` | `never` | `codex exec` działa bez człowieka |

shctl podaje też `-m` i `model_reasoning_effort` z `konfiguracja.md` projektu (wygrywają z profilem) i
zawsze `-s read-only`. Test z 2026-11-02: nagłówek `codex exec -p reviewer` pokazał
`model: gpt-6.1-terra`, `sandbox: read-only`, `approval: never`, `reasoning effort: high`, a `touch`
w katalogu roboczym został zablokowany. Profil nie blokuje odczytu poza katalogiem roboczym (znane
ograniczenie wyżej). Zmiana modelu: plik w repo i PR, tak jak `konfiguracja.md` szablonu.

### Poświadczenia w zasięgu agentów

Przegląd z 2026-11-01 objął tylko ścieżki i nazwy zmiennych, bez otwierania plików, do głębokości
7 katalogów od `~`. Nie ustala więc, które klucze są produkcyjne.

| Lokalizacja | Pliki |
|---|---|
| `~/Documents/Carbon_footprint` | `.env.dev`, `.env.local`, `.env.staging` w 3 backendach |
| `~/.hermes`, `~/hermes-config-backup-20261022` | `.env` |
| `~/.paperclip/instances/default` | `.env` |
| `~/forgejo/data/gitea` | `jwt/private.pem`, `actions_id_token/private.pem` |
| `~/Downloads` | 2 certyfikaty `.p12` |
| `~` | `.codex/auth.json`, `.claude.json`, `.docker/config.json`, `.config/gh`, `.supabase`, `.softwarehouse` |

Te ścieżki nie są objęte regułami deny.

### Backup konfiguracji

```sh
backup-config.sh              # do ~/sh/backups
backup-config.sh /Volumes/X   # do wskazanego katalogu
```

Archiwum `config-<data>.tar.gz` (tylko dla właściciela) zawiera `~/.claude`, `~/.codex/config.toml`,
`~/.config/sh`, `~/sh/bin` i `~/sh/porty.md`. `~/sh/bin` trafia tam jako symlinki, więc treści
skryptów nie ma w archiwum: odtwarza je klon `sh-system` i `install.sh`. Gdy `~/sh/sh-system` ma
niezacommitowane lub niewypchnięte zmiany, skrypt ostrzega i dopisuje wpis do
`~/sh/logs/backup-config.log`, ale archiwum powstaje. Z `~/.claude` trafiają tylko ustawienia, skille, lista
pluginów i pamięć projektów. Nie ma w nim sesji, historii, cache, `auth.json`, `.credentials.json`
ani `.claude.json`. Po spakowaniu sprawdza je gitleaks; przy trafieniu archiwum jest kasowane.
Archiwum zawiera temat ntfy, więc traktuj je jak dane poufne.

## Globalny hook git

`install.sh` ustawia `git config --global core.hooksPath` na `scripts/server/git-hooks/`. Tylko na
serwerze: `pre-push` odrzuca push na gałąź `production`.

Globalny `core.hooksPath` wyłącza `.git/hooks`, dlatego katalog zawiera wrapper każdego typu hooka.
Wrapper wywołuje hook projektu z `core.hooksPath` zapisanego w repo albo z `.git/hooks`. Nie ma
wrapperów `push-to-checkout` i `proc-receive`, bo ich obecność zmienia zachowanie gita.

Hooków śledzonych w repo, np. `.githooks/`, wrapper celowo nie wywołuje (`proces-v1.md`, „Znane
ograniczenia”).

Lokalny `core.hooksPath` wygrywa z globalnym, więc w takim repo, np. z husky, hook globalny się nie
uruchamia i nie blokuje pusha. `install.sh` ostrzega o takich repo w `~/sh` i
`~/sh/projekty`. Narzędzie `pre-commit`
odmawia `pre-commit install` przy ustawionym `core.hooksPath`. Forgejo działa w kontenerze z własną
konfiguracją gita, więc tego ustawienia nie widzi.

## Dziennik narzędzi

| Data | Narzędzie | Źródło | Kto | Po co |
|---|---|---|---|---|
| 2026-11-01 | yq, gitleaks, uv, fnm, bats-core | oficjalne wydania, `~/.local` | setup | bazowy toolchain |
| 2026-11-01 | Node 26.13.0, pnpm 12.16.1 | fnm, corepack | setup | bazowy toolchain |
| 2026-11-01 | Playwright 1.61.1, Chrome for Testing | npx | setup | testy E2E |
| 2026-11-01 | herdr 0.9.5 | oficjalny instalator, `~/.local/bin` | setup | multiplekser agentów |
