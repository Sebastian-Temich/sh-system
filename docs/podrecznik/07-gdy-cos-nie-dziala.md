# Gdy coś nie działa

Wróć do: [[00-start-tutaj]]

Zasada ogólna: najpierw zapytaj orkiestratora „status?”. Gdy nie odpowiada, sprawdź serwer
(`shctl doctor`) i logi.

## Limit subskrypcji

**Objaw:** orkiestrator pisze w czacie o limicie Claude albo Codexa z godziną odnowienia. Pushu o
limicie nie ma: strażnik już ich nie śledzi.

| Limit | Skutek |
|---|---|
| Claude | Nowe zadania nie startują, przerwany worker stoi |
| Codex | Review czeka, PR zostają w kolejce; nowe zadania startują, dopóki kolejka review nie ma 3 PR |

**Co robisz:**

1. Nic, do godziny odnowienia. Pracy nie przenosimy na inny model.
2. Po tej godzinie piszesz „wznów”. Orkiestrator usuwa wpis z `limity.md`, sprawdza każde przerwane
   zadanie i decyduje, jak kontynuować.

Aktywne limity: `/Users/Shared/sh/limity.md` albo „Wstrzymania” w statusie. Limit zauważony przez
Ciebie możesz wpisać tam sam albo zgłosić orkiestratorowi.

Automatyczne wznowienie po limicie to etap B (jeszcze niedostępne).

## Zawieszony worker

**Objaw:** zadanie długo „w toku”, brak postępu w statusie.

**Co robisz:**

1. Napisz „status?” albo „co z zadaniem #12?”. Orkiestrator sprawdza panel i PR:
   - panel bez agenta, brak PR: sprawdza stan (`shctl task resume-check`) i uruchamia workera
     ponownie (`shctl task dispatch`);
   - agent bezczynny bez PR: wysyła mu polecenie dokończenia;
   - worker nie podjął polecenia (`shctl task wait` zwraca `bez_tury`): czyta panel i ponawia
     polecenie.
2. Pushu „Claude czeka na zgodę” już nie ma. Pytanie o zgodę i bezczynnego workera wykrywa
   orkiestrator. Możesz zajrzeć do
   panelu `worker:PROJEKT:NR` w herdr (na serwerze albo przez SSH: `/Users/Shared/sh/bin/sh-start.sh`) i
   odpowiedzieć.
3. Sam możesz sprawdzić blokady: `shctl task ready --projekt NAZWA`.

## Eskalacja po 3 iteracjach

**Objaw:** push „Eskalacja E-NNN: PROJEKT” z treścią „#NR: 3 iteracje bez PASS”.

Zadanie trzy razy nie przeszło review. Etykieta `iter:3` zostaje, a zadania niezależne trwają.

**Co robisz:**

1. Przeczytaj ostatni komentarz review w PR i raport `docs/07-realizacja/T-NR.md`
   („Ryzyka”, „Decyzje”).
2. Odpowiedz w czacie z numerem eskalacji i decyzją, np.:
   - „E-004: zgłoszenie o walidacji jest słuszne, popraw tylko je”;
   - „E-004: podziel zadanie na dwa mniejsze”;
   - „E-004: wytnij funkcję eksportu z zakresu, przenieś do backlogu”.
3. Orkiestrator zamyka eskalację Twoją odpowiedzią i działa według niej. Odpowiedź „zadanie
   niewykonalne” albo „rezygnujemy” kończy zadanie przez `shctl task close --anuluj` (issue „not planned”).

Eskalowane zadanie nie zajmuje miejsca workera: w tym czasie startują inne zadania. Jego panel w herdr
ma etykietę `eskalacja:PROJEKT:NR` i możesz go przeczytać.

## PR bez CI, „konflikt z main”

**Objaw:** PR długo bez wyniku CI, w statusie „konflikt z main”.

GitHub nie uruchamia CI dla PR z konfliktem. Orkiestrator sprawdza to przed czekaniem na CI
(`shctl pr check`) i zleca autorowi gałęzi rozwiązanie konfliktu (`git merge origin/main`). Nic nie
robisz, chyba że konflikt wraca: wtedy orkiestrator eskaluje.

## Czerwone CI mimo poprawek

**Objaw:** zadanie wraca do review z czerwonym CI albo przychodzi eskalacja „czerwone CI”.

Worker naprawia czerwone CI najwyżej 2 razy. Potem orkiestrator decyduje: przyczyna w kodzie zadania
idzie do review (i zwykłych iteracji), przyczyna poza zadaniem (środowisko, sekret, CI szablonu) do
eskalacji. Merge nadal wymaga zielonego CI.

## Czerwone CI

**Objaw:** w statusie „CI czerwone na PR #N”.

Review nie startuje bez zielonego CI. Czerwone CI naprawia worker. Commit z samym raportem zadania
nie liczy się jako próba. Po dwóch nieudanych próbach
orkiestrator sprawdza stan zadania i decyduje o dalszym kroku. Ty zwykle nic nie robisz.

Gdy CI pada na brakującym sekrecie (np. `STAGING_DB_URL`), to Twoje zadanie ręczne z planu:
orkiestrator zgłosi je w „Czeka na Ciebie” albo eskalacją.

## Obsidian się nie aktualizuje

**Objaw:** stare dokumenty w vaulcie. Pushu o tym nie ma.

**Przyczyna zwykle:** zmiana zapisana w pliku w `SH/Projekty` albo `SH/sh-system`. Synchronizacja
nie nadpisuje lokalnych zmian, więc pomija tę kopię. Skrzynki (`SH/Skrzynka`) to nie dotyczy.

**Gdy log mówi „could not read Username” albo „Authentication failed”:** serwer nie może się
zalogować do GitHuba. Sprawdź `gh auth status` i wiersz `logowanie git` w `shctl doctor`; przy
błędzie uruchom `/Users/Shared/sh/sh-system/scripts/server/install.sh` (ustawia logowanie git przez gh).

**Co robisz:**

1. Cofnij zmianę w Obsidianie (albo poproś orkiestratora: „uporządkuj klon Obsidiana projektu
   NAZWA”).
2. Sprawdź: `shctl doctor` (wiersz „Obsidian”: czy kopie są czyste i zgodne z GitHubem) i
   `/Users/Shared/sh/logs/obsidian-sync.log` (wpisy `POMINIĘTY` z powodem).
3. Synchronizacja teraz, bez czekania:
   `launchctl kickstart gui/$(id -u)/pl.iskt.softwarehouse.obsidian-sync`.
4. Czy nie jest wyłączona: plik `/Users/Shared/sh/stan/obsidian-sync.off`.

## Skrzynka: plik nie trafił do repo

**Objaw:** plik dalej leży w skrzynce.

| Przyczyna | Co robisz |
|---|---|
| Czerwone CI w PR ze skrzynki | PR zostaje otwarty, skrzynka bez zmian. Orkiestrator sprawdza CI (np. za duży plik) i decyduje; po poprawce przyjmuje skrzynkę jeszcze raz |
| Plik ukryty (nazwa od kropki), `__MACOSX`, skrót (dowiązanie) | Te są zawsze pomijane. Zmień nazwę albo wrzuć sam plik |

Stan skrzynki sprawdzisz sam: `shctl skrzynka przyjmij NAZWA --dry-run` (niczego nie zmienia).

## Claude pyta o zgodę przy każdej edycji

**Objaw:** worker stoi na zapisie pliku albo sesja pyta przy każdej edycji z komunikatem
„suspicious Windows path pattern that requires manual approval”.

Przyczyna: plik leży pod ścieżką z segmentem zakończonym kropką, np. w katalogu domowym
`/Users/sebastiant.`. Dlatego cały katalog SH jest w `/Users/Shared/sh`. `~/sh` to tylko dowiązanie:
nie obchodzi blokady.

**Co robisz:**

1. `shctl doctor`: kontrola `katalog SH` musi być `OK`.
2. Sprawdź, czy sesja lub panel nie startuje w `~/sh`; powinien w `/Users/Shared/sh`.
3. Gdy coś nadal wskazuje starą ścieżkę: zgłoś orkiestratorowi albo zobacz `serwer.md`, „Katalog SH”.

## Restart Maca

Po restarcie i zalogowaniu usługa `sh-start` czeka na Docker Desktop i sieć, potem uruchamia herdr i
orkiestratora. Strażnik orkiestratora i synchronizacja Obsidiana startują same.

**Co robisz:**

1. Sprawdź w aplikacji Claude, czy sesja `sh-orkiestrator` jest dostępna.
2. Napisz „wznów”. Workerzy nie wracają sami: orkiestrator sprawdza przerwane zadania i uruchamia
   je ponownie.
3. Gdy sesji nie ma: [[#Orkiestrator nie odpowiada]].

Restart serwera herdr bez restartu Maca:

```sh
herdr server stop
launchctl kickstart gui/$(id -u)/pl.iskt.softwarehouse.sh-start
```

`herdr server stop` kończy wszystkie procesy w panelach, więc nie używaj go w trakcie pracy.

## Orkiestrator nie odpowiada

1. Na serwerze (albo przez SSH): `/Users/Shared/sh/bin/sh-start.sh`. Uruchamia orkiestratora tylko wtedy, gdy
   nie działa, i podłącza Cię do herdr.
2. Sprawdź `/Users/Shared/sh/logs/sh-start.log`. Ostatni wpis przebiegu ma kod wyjścia:
   - `gotowe (kod 0)`: skrypt uruchomił orkiestratora. Jeśli mimo to go nie ma, zginął później;
     sprawdź `/Users/Shared/sh/logs/herdr-server.log` (np. `server shutdown initiated reason=SIGTERM`);
   - `UWAGA (kod 0)`: treść mówi, co poszło nie tak, np. druga instancja w `/Users/Shared/sh`;
   - `BLAD …, krok: ETAP (kod N)`: miejsce zatrzymania; kod 142 to herdr bez odpowiedzi;
   - wpis „autostart wyłączony przez właściciela” oznacza flagę `/Users/Shared/sh/stan/autostart.off`.
3. W nowej sesji napisz „wznów”.

Odłączenie od herdr bez zabijania sesji: `ctrl+b`, potem `q`.

## Awaryjny STOP

**Kiedy:** agent robi coś, czego nie chcesz, albo musisz natychmiast wstrzymać pracę.

**Jak:**

- w czacie: „STOP”; orkiestrator odpowiada „Zatrzymuję wszystko” i wywołuje `shctl stop-all`;
- bez czatu, na serwerze: `shctl stop-all` (albo `shctl stop-all --projekt NAZWA` dla jednego
  projektu).

Zamknięte zostają panele workerów, reviewerów i orkiestratora. Kopie robocze i niezapisane zmiany
zostają na dysku, a stan trafia do `/Users/Shared/sh/stan/NAZWA.json`. Przychodzi push „STOP”.

**Wznowienie:** nic nie wznawia się samo. Uruchom orkiestratora (`/Users/Shared/sh/bin/sh-start.sh` albo
`claude` w panelu) i napisz „wznów”. Orkiestrator odtwarza stan z `Projekt.md` i
`/Users/Shared/sh/stan/NAZWA.json`.

## Brak miejsca na dysku

**Objaw:** push „Brak miejsca: Wolne X GB, minimum 15 GB: dispatch wstrzymany” (raz dziennie).

Nowe zadania nie startują, trwające pracują dalej. Zwolnij miejsce według [[serwer]], „Obciążenie i
dysk”. Część kroków wymaga Twojej decyzji i backupu, więc nie kasuj niczego na ślepo. Po zwolnieniu
miejsca praca rusza przy kolejnym kroku orkiestratora.

## Usługa nie wystartowała po install.sh

**Objaw:** push „install.sh: agent niezaladowany”.

`install.sh` wypisuje komendę do ręcznego załadowania, np.:

```sh
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/pl.iskt.softwarehouse.sh-watchdog.plist
```

Stan usługi:

```sh
launchctl print gui/$(id -u)/pl.iskt.softwarehouse.sh-watchdog | grep -E 'state|last exit'
```

## Logi

| Problem | Gdzie patrzeć |
|---|---|
| Co robił shctl | `/Users/Shared/sh/logs/shctl.log` |
| Start orkiestratora | `/Users/Shared/sh/logs/sh-start.log`, `/Users/Shared/sh/logs/herdr-server.log` |
| Limity | `/Users/Shared/sh/limity.md` |
| Restart orkiestratora | `/Users/Shared/sh/logs/watchdog.log` |
| Obsidian | `/Users/Shared/sh/logs/obsidian-sync.log` |
| Review Codexa | `/Users/Shared/sh/stan/review/PROJEKT-NR/codex.log` |
| Stan po STOP | `/Users/Shared/sh/stan/NAZWA.json` |
| Ogólne zdrowie | `shctl doctor` |

Szczegóły: [[05-serwer-i-skrypty#Logi]].
