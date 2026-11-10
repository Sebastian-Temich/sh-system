# Gdy coś nie działa

Wróć do: [[01-start]]

Zasada ogólna: najpierw „status?” w czacie albo `docs/Projekt.md`. Gdy orkiestrator nie odpowiada,
sprawdź serwer (`shctl doctor`) i logi.

## Co wykonujesz Ty

Agenci działają w sandboxie (sesje SH) i z listą zakazanych komend. Kilku rzeczy nie zrobią, nawet
gdy chcą: wtedy wypisują komendę i czekają, aż uruchomisz ją Ty w terminalu serwera (panel
`powloka` w herdr albo zwykły Terminal), a potem piszesz w czacie, że gotowe.

| Co | Dlaczego nie agent | Komenda |
|---|---|---|
| `install.sh` po merge'u zmian w `sh-system` (symlinki, LaunchAgenty, ustawienia sesji, hook git) | `launchctl` i zapis w `~/Library/LaunchAgents`, `~/.claude`, `~/.codex` są poza sandboxem | `/Users/Shared/sh/sh-system/scripts/server/install.sh` |
| Ręczne załadowanie usługi po pushu „install.sh: agent niezaladowany” | `launchctl` | Komenda z wyjścia `install.sh`, np. `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/pl.iskt.softwarehouse.sh-watchdog.plist` |
| Usunięcie gałęzi bez PR (np. porzuconej) | Agentom nie wolno usuwać gałęzi; `shctl sprzataj` usuwa tylko gałęzie scalonych i zamkniętych PR | `cd /Users/Shared/sh/projekty/NAZWA`, potem `git branch -D GAŁĄŹ`; zdalna: `git push origin --delete GAŁĄŹ` |
| Usunięcie repo testowych z `/Users/Shared/sh/stan/do-usuniecia.md` | `gh repo delete` wymaga zakresu `delete_repo` | `gh repo delete Sebastian-Temich/NAZWA` |
| Sekret albo klucz testowy | Sekretów nie podaje się w czacie | Wpisz do `/Users/Shared/sh/projekty/NAZWA/.env.local` |
| `sudo`, ustawienia systemu, Docker Desktop, logowania (`gh auth login`, `claude auth login`, `codex login`) | Wymagają hasła albo przeglądarki | Według komunikatu agenta |
| Zmiana ustawień sandboxa i uprawnień sesji | Pliki ustawień są chronione przed agentem | Zmiana w repo `sh-system` przez PR, potem `install.sh` |
| Restart serwera herdr | Kończy wszystkie sesje, także orkiestratora | Niżej, „Restart Maca” |

Po każdym merge'u PR w `sh-system`, który zmienia skrypty serwera, plisty albo ustawienia, builder
podaje Ci komendę `install.sh`. Uruchom ją; `install.sh` jest bezpieczny do powtarzania i niczego nie
nadpisuje bez zgodności z repo.

## Sam sprawdzasz

| Komenda | Co pokazuje (niczego nie zmienia) |
|---|---|
| `shctl status show --projekt NAZWA` | To samo co „status?” |
| `shctl doctor` | Zdrowie serwera: narzędzia, logowania, orkiestrator, Docker, dysk, Obsidian, repo do usunięcia |
| `shctl doctor --test-notify` | To samo i prawdziwy push testowy |
| `shctl task ready --projekt NAZWA` | Które zadania mogą wystartować i co blokuje resztę |
| `shctl skrzynka przyjmij NAZWA --dry-run` | Co jest w skrzynce |
| `shctl KOMENDA --help` | Opis dowolnej komendy; pełna lista w [[shctl]] |

Komendy zmieniające pliki projektu zostawiają zmiany do commitu przez orkiestratora; jeśli sam
uruchomisz taką komendę, powiedz mu o tym w czacie.

## Limit subskrypcji

**Objaw:** push „Limit Claude” albo „Limit Codex” z godziną odnowienia, wpis w statusie
„Wstrzymania”. Limit Claude zatrzymuje nowe zadania; limit Codexa tylko review zmian z ryzykiem (PR
czeka w kolejce albo review robi drugi silnik, według `review.gdy_limit`).

**Co robisz:** nic do godziny odnowienia, potem „wznów”. Orkiestrator usuwa wpis z
`/Users/Shared/sh/limity.md` i sprawdza każde przerwane zadanie. Limit zauważony przez Ciebie możesz
wpisać tam sam.

## Zawieszony worker

**Objaw:** zadanie długo „w toku” bez postępu. Napisz „co z zadaniem #12?”. Orkiestrator sprawdza panel
i PR: uruchamia workera ponownie, wysyła mu polecenie dokończenia albo czyta, na co czeka. Możesz
zajrzeć do panelu `worker:PROJEKT:NR` w herdr i odpowiedzieć sam.

## Eskalacja po 3 iteracjach

**Objaw:** „Eskalacja E-NNN: PROJEKT” z „#NR: 3 iteracje bez PASS”. Przeczytaj ostatni komentarz
review w PR i raport `docs/07-realizacja/T-NR.md`, potem odpowiedz, np.:

- „E-004: zgłoszenie o walidacji jest słuszne, popraw tylko je”;
- „E-004: podziel zadanie na dwa mniejsze”;
- „E-004: wytnij eksport z zakresu, przenieś do backlogu”;
- „E-004: rezygnujemy”: zadanie zamyka się jako „not planned”.

## Czerwone CI i konflikty

- **Czerwone CI:** naprawia je worker, najwyżej 2 próby. Potem orkiestrator: błąd w kodzie zadania
  idzie do review, przyczyna poza zadaniem (środowisko, sekret, CI szablonu) do eskalacji. Zwykle nic
  nie robisz. Brakujący sekret CI (np. `STAGING_DB_URL`) to Twoje zadanie ręczne z planu.
- **„Konflikt z main”:** GitHub nie uruchamia CI dla PR z konfliktem. Orkiestrator zleca go autorowi
  gałęzi; eskaluje dopiero, gdy konflikt wraca.
- Joby `lint`, `test`, `e2e` ze statusem „Skipped” na PR z samą dokumentacją to nie błąd.
- E2E i Lighthouse nie działają lokalnie (przeglądarki nie startują w sandboxie): ich wynik jest tylko
  w CI. Agent czyta go przez `gh run view RUN --log-failed`.

## Obsidian się nie aktualizuje

**Przyczyna zwykle:** zapis w pliku w `SH/Projekty` albo `SH/sh-system`; synchronizacja pomija taką
kopię. **Co robisz:**

1. Cofnij zmianę w Obsidianie albo napisz „uporządkuj klon Obsidiana projektu NAZWA”.
2. Sprawdź `shctl doctor` (wiersz „Obsidian”) i `/Users/Shared/sh/logs/obsidian-sync.log` (wpisy
   `POMINIĘTY` z powodem).
3. Synchronizacja teraz: `launchctl kickstart gui/$(id -u)/pl.iskt.softwarehouse.obsidian-sync`.
4. Czy nie jest wyłączona: plik `/Users/Shared/sh/stan/obsidian-sync.off`.

Log „could not read Username” albo „Authentication failed”: sprawdź `gh auth status` i wiersz
`logowanie git` w `shctl doctor`; przy błędzie uruchom `install.sh`.

## Skrzynka: plik nie trafił do repo

Czerwone CI w PR ze skrzynki: PR zostaje otwarty, skrzynka bez zmian, orkiestrator mówi, co poszło
nie tak (np. za duży plik). Pliki ukryte, `__MACOSX` i skróty są zawsze pomijane: zmień nazwę albo
wrzuć sam plik.

## Agent pyta o zgodę przy każdej edycji

**Objaw:** „suspicious Windows path pattern that requires manual approval”. Plik leży pod ścieżką z
segmentem zakończonym kropką (katalog domowy `/Users/sebastiant.`). Wszystko SH jest w
`/Users/Shared/sh`; `~/sh` to tylko dowiązanie. Sprawdź `shctl doctor` (kontrola `katalog SH`) i czy
sesja nie startuje w `~/sh`.

## Restart Maca

Po zalogowaniu usługa `sh-start` czeka na Docker Desktop i sieć, potem uruchamia herdr i
orkiestratora; strażnik i synchronizacja Obsidiana startują same. Sprawdź w aplikacji Claude sesję
`sh-orkiestrator` i napisz „wznów”. Workerzy nie wracają sami: orkiestrator uruchamia przerwane zadania.

Restart samego herdr (kończy wszystkie procesy w panelach, nie w trakcie pracy):

```sh
herdr server stop
launchctl kickstart gui/$(id -u)/pl.iskt.softwarehouse.sh-start
```

## Orkiestrator nie odpowiada

1. Na serwerze: `/Users/Shared/sh/bin/sh-start.sh`. Uruchamia orkiestratora tylko, gdy nie działa,
   i podłącza Cię do herdr.
2. Sprawdź ostatni wpis w `/Users/Shared/sh/logs/sh-start.log`:
   - `gotowe (kod 0)`: uruchomiony; jeśli go nie ma, sprawdź `/Users/Shared/sh/logs/herdr-server.log`;
   - `UWAGA (kod 0)`: treść mówi, co nie tak, np. druga instancja w `/Users/Shared/sh`;
   - `BLAD …, krok: ETAP (kod N)`: miejsce zatrzymania; kod 142 to herdr bez odpowiedzi;
   - „autostart wyłączony przez właściciela”: flaga `/Users/Shared/sh/stan/autostart.off`.
3. W nowej sesji napisz „wznów”.

## Awaryjny STOP

W czacie „STOP” albo na serwerze `shctl stop-all` (jeden projekt: `--projekt NAZWA`). Panele agentów
zostają zamknięte, kopie robocze i stan (`/Users/Shared/sh/stan/NAZWA.json`) zostają, przychodzi push
„STOP”. Nic nie wznawia się samo: uruchom orkiestratora (`sh-start.sh`) i napisz „wznów”.

## Brak miejsca na dysku

**Objaw:** push „Brak miejsca: Wolne X GB, minimum 15 GB: dispatch wstrzymany” (raz dziennie). Nowe
zadania nie startują, trwające pracują dalej. Zwolnij miejsce: cache (`npm cache clean --force`,
`brew cleanup -s`), nieużywane obrazy Dockera, worktree scalonych PR (`shctl sprzataj`). Nie kasuj
niczego na ślepo i nie ruszaj migawek Time Machine przed backupem.

## Wyłączanie usług

| Co | Wyłączenie | Włączenie |
|---|---|---|
| Autostart herdr i orkiestratora | `touch /Users/Shared/sh/stan/autostart.off` i `launchctl bootout gui/$(id -u)/pl.iskt.softwarehouse.sh-start` | `rm` flagi i `install.sh` |
| Synchronizacja Obsidiana | `touch /Users/Shared/sh/stan/obsidian-sync.off` | `rm` flagi i `install.sh` |
| Przypomnienia | `touch /Users/Shared/sh/stan/przypomnienia.off` | `rm` flagi |
| Strażnik orkiestratora | `launchctl bootout gui/$(id -u)/pl.iskt.softwarehouse.sh-watchdog` (do następnego `install.sh`) | `install.sh` |

## Logi

| Problem | Gdzie patrzeć |
|---|---|
| Co robił `shctl` | `/Users/Shared/sh/logs/shctl.log` |
| Start orkiestratora | `/Users/Shared/sh/logs/sh-start.log`, `/Users/Shared/sh/logs/herdr-server.log` |
| Restart orkiestratora | `/Users/Shared/sh/logs/watchdog.log` |
| Obsidian | `/Users/Shared/sh/logs/obsidian-sync.log` |
| Przypomnienia | `/Users/Shared/sh/logs/przypomnienia.log` |
| Review | `/Users/Shared/sh/stan/review/PROJEKT-NR/` (prompt, wynik, `silnik.log`) |
| Limity | `/Users/Shared/sh/limity.md` |
| Stan po STOP | `/Users/Shared/sh/stan/NAZWA.json` |
