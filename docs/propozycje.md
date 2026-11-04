# Propozycje dla systemu

Zbiera `shctl task close` z raportów zadań (sekcja „Propozycje dla systemu”). Decyzję podejmuje retro.

## sh-system (2026-11-02): shctl cykl new, etap B

Drugie zlecenie M w trwającym projekcie nie ma dziś mechaniki: etapy `00-intake`, `04-architektura`,
`05-plan`, `06-zadania`, `07-realizacja`, `08-qa` i `wydanie` mają po pierwszym zleceniu status `done`,
a `shctl stage start` nie przyjmuje statusu `done`. Specyfikacja i plan są pojedynczymi plikami.

Propozycja na etap B: `shctl cykl new SLUG`, który otwiera nowy cykl zlecenia M w tym samym repo:
archiwizuje dokumenty poprzedniego cyklu (np. `docs/cykle/NN-slug/`), zeruje `DoD.md` etapów trybu M
do `todo` z `iteracja: 0`, zapisuje cykl w `status.md` i w `metryki.md` oraz zostawia `decyzje.md`,
`CHANGELOG.md` i `AGENTS.md` bez zmian.

Do tego czasu `sh-intake` proponuje właścicielowi podział na zlecenia S albo osobny projekt.

## sh-system (2026-11-02): drobne uwagi z raportu QA do backlogu

`shctl task close` przenosi „Drobne uwagi” z `T-NR.md` do `docs/backlog-drobne.md`, ale raport QA
`docs/08-qa/raport-MN.md` nie ma takiej komendy, więc orkiestrator dopisuje wiersze ręcznie.

Propozycja: `shctl qa close MN` (albo krok w `stage`), który czyta „Drobne uwagi” z
`raport-MN.md` tym samym parserem co `task close` i dopisuje `| DATA | QA MN | uwaga | otwarta |`
bez dublowania.


## sh-system (2026-11-02): komendy dla orkiestratora

`sh-orkiestrator` wykonuje dziś ręcznie operacje, których shctl nie ma:

- merge PR etapu (`gh pr merge PR --squash --match-head-commit SHA`) po zielonym CI, PASS i
  akceptacji właściciela; propozycja: `shctl stage merge PR` z tymi samymi bramkami co `task close`;
- pola Checkpointu w `DoD.md` na `main` (review z komentarza PASS, akceptacja z wiersza `wlasciciel`
  w `decyzje.md`), podbicie `iteracja` etapu po FAIL i zgłoszenia ⚪ z review etapu do
  `backlog-drobne.md`; propozycja: kroki w `stage merge` i `stage iter ETAP`;
- polecenie dla działającego workera (dokończenie zadania, iteracja od nowa po limicie) przez
  `herdr agent prompt`; propozycja: `shctl task nudge NR --powod kontynuuj|od-nowa`;
- wpis „Punktu przekazania” w `status.md`; propozycja: `shctl handoff` z danymi `status show`,
  wynikiem `doctor` i wierszem autoryzacji.

## sh-dryrun T-25 (2026-11-04)

<!-- propozycje:sh-dryrun:T-25 -->
- Issue wskazuje specyfikację i architekturę z „Wejścia” skilla, których w projekcie typu biblioteka nie ma; warto, żeby `sh-zadania` wpisywał w issue „brak specyfikacji/architektury”, a skill nie wymagał ich czytania.
