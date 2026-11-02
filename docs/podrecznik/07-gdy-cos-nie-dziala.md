# Gdy coś nie działa

Wróć do: [[00-start-tutaj]]

Zasada ogólna: najpierw zapytaj orkiestratora „status?”. Gdy nie odpowiada, sprawdź serwer
(`shctl doctor`) i logi.

## Limit subskrypcji

**Objaw:** push „Limit claude” albo „Limit codex” z godziną odnowienia.

| Limit | Skutek |
|---|---|
| Claude | Nowe zadania nie startują, przerwany worker stoi |
| Codex | Review czeka, PR zostają w kolejce; nowe zadania startują, dopóki kolejka review nie ma 3 PR |

**Co robisz:**

1. Nic, do godziny odnowienia. Pracy nie przenosimy na inny model.
2. Push „Limit X odnowiony, możesz wznowić” przychodzi do 5 minut po tej godzinie.
3. Piszesz „wznów”. Orkiestrator sprawdza każde przerwane zadanie i decyduje, jak kontynuować.

Godzina z dopiskiem „(szacunek)” znaczy, że komunikat nie podał godziny: strażnik przyjął 5 godzin.
Aktywne limity: `~/sh/limity.md` albo „Wstrzymania” w statusie.

Automatyczne wznowienie po limicie to etap B (jeszcze niedostępne).

## Zawieszony worker

**Objaw:** zadanie długo „w toku”, brak postępu w statusie, albo push „Claude czeka na Ciebie” z
numerem zadania w treści.

**Co robisz:**

1. Napisz „status?” albo „co z zadaniem #12?”. Orkiestrator sprawdza panel i PR:
   - panel bez agenta, brak PR: sprawdza stan (`shctl task resume-check`) i uruchamia workera
     ponownie (`shctl task dispatch`);
   - agent bezczynny bez PR: wysyła mu polecenie dokończenia.
2. Push „Claude czeka na Ciebie” zwykle oznacza pytanie o zgodę w panelu workera. Możesz zajrzeć do
   panelu `worker:PROJEKT:NR` w herdr (na serwerze albo przez SSH: `~/sh/bin/sh-start.sh`) i
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
3. Orkiestrator zamyka eskalację Twoją odpowiedzią i działa według niej.

## Czerwone CI

**Objaw:** w statusie „CI czerwone na PR #N”, w dashboardzie licznik „CI fail”.

Review nie startuje bez zielonego CI. Czerwone CI naprawia worker. Po dwóch nieudanych próbach
orkiestrator sprawdza stan zadania i decyduje o dalszym kroku. Ty zwykle nic nie robisz.

Gdy CI pada na brakującym sekrecie (np. `STAGING_DB_URL`), to Twoje zadanie ręczne z planu:
orkiestrator zgłosi je w „Czeka na Ciebie” albo eskalacją.

## Obsidian się nie aktualizuje

**Objaw:** push „Obsidian: klon bez synchronizacji” albo stare dokumenty w vaulcie.

**Przyczyna zwykle:** zmiana zapisana w pliku w `SH/`. Synchronizacja nie nadpisuje lokalnych zmian,
więc pomija tę kopię.

**Co robisz:**

1. Cofnij zmianę w Obsidianie (albo poproś orkiestratora: „uporządkuj klon Obsidiana projektu
   NAZWA”).
2. Sprawdź: `shctl doctor` pokazuje datę ostatniej udanej synchronizacji (uwaga, gdy starsza niż 30
   minut). Szczegóły: `~/sh/logs/obsidian-sync.log`.
3. Synchronizacja teraz, bez czekania: `shctl obsidian sync`.
4. Czy nie jest wyłączona: plik `~/sh/stan/obsidian-sync.off`.

## Restart Maca

Po restarcie i zalogowaniu usługa `sh-start` czeka na Docker Desktop i sieć, potem uruchamia herdr i
orkiestratora. Strażnik limitów i synchronizacja Obsidiana startują same.

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

1. Na serwerze (albo przez SSH): `~/sh/bin/sh-start.sh`. Uruchamia orkiestratora tylko wtedy, gdy
   nie działa, i podłącza Cię do herdr.
2. Sprawdź `~/sh/logs/sh-start.log`. Wpis „autostart wyłączony przez właściciela” oznacza flagę
   `~/sh/stan/autostart.off`.
3. W nowej sesji napisz „wznów”.

Odłączenie od herdr bez zabijania sesji: `ctrl+b`, potem `q`.

## Awaryjny STOP

**Kiedy:** agent robi coś, czego nie chcesz, albo musisz natychmiast wstrzymać pracę.

**Jak:**

- w czacie: „STOP”; orkiestrator odpowiada „Zatrzymuję wszystko” i wywołuje `shctl stop-all`;
- bez czatu, na serwerze: `shctl stop-all` (albo `shctl stop-all --projekt NAZWA` dla jednego
  projektu).

Zamknięte zostają panele workerów, reviewerów i orkiestratora. Kopie robocze i niezapisane zmiany
zostają na dysku, a stan trafia do `~/sh/stan/NAZWA.json`. Przychodzi push „STOP”.

**Wznowienie:** nic nie wznawia się samo. Uruchom orkiestratora (`~/sh/bin/sh-start.sh` albo
`claude` w panelu) i napisz „wznów”. Orkiestrator odtwarza stan ze `status.md` i
`~/sh/stan/NAZWA.json`.

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
| Co robił shctl | `~/sh/logs/shctl.log` |
| Start orkiestratora | `~/sh/logs/sh-start.log`, `~/sh/logs/herdr-server.log` |
| Limity | `~/sh/logs/watchdog.log`, `~/sh/limity.md` |
| Obsidian | `~/sh/logs/obsidian-sync.log`, `~/sh/stan/obsidian-sync.json` |
| Review Codexa | `~/sh/stan/review/PROJEKT-NR/codex.log` |
| Stan po STOP | `~/sh/stan/NAZWA.json` |
| Ogólne zdrowie | `shctl doctor` |

Szczegóły: [[05-serwer-i-skrypty#Logi]].
