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
