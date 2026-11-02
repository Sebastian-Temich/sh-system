# Plan etapow i checklisty przejsc

Stosuj ten format do tworzenia roadmapy i dokumentow etapow. Dostosuj go do
projektu; nie dodawaj pustych sekcji, ktore nie maja znaczenia.

## Pliki

```text
05_Backlog/Roadmapa realizacji.md
05_Backlog/Etapy/E00 - Fundamenty.md
05_Backlog/Etapy/E01 - <Nazwa etapu>.md
06_Delivery/Stan realizacji projektu.md
06_Delivery/Rejestr decyzji i zmian zakresu.md
07_Techniczne/Kontrakt wykonania projektu.md
07_Techniczne/Strategia jakosci, release i utrzymania.md
```

## Roadmapa realizacji

```markdown
# Roadmapa realizacji

## Cel MVP
<jednoznaczny rezultat biznesowy>

## Mapa architektoniczna
| Modul / flow | Wlasciciel danych i reguly | Kontrakt | UI / integracja | Zaleznosci |
|---|---|---|---|---|

## Etapy
| Etap | Cel odbioru | Status | Zaleznosci | Ryzyko / bramka | Dokument |
|---|---|---|---|---|---|
| E00 |  | planowany |  |  | [[Etapy/E00 - Fundamenty]] |
| R01 | Wydanie v1.0 na produkcje | planowany | etapy MVP |  przeglad security, rollback | [[Etapy/R01 - Wydanie v1.0]] |
```

## Dokument etapu

```markdown
# E0X - Nazwa etapu

## Stan
- Status: planowany / gotowy do startu / w realizacji / zablokowany / do odbioru / zakonczony / wstrzymany
- Cel odbioru:
- Wlasciciel etapu:
- Zadanie Paperclip:
- Data rozpoczecia:
- Data odbioru:
- Nastepne dzialanie:

## Zakres
Wchodzi:
-

Poza zakresem:
-

## Mapa techniczna
| Modul / flow | Dane i wlasciciel reguly | Kontrakt API/RPC | UI / integracja | Zaleznosc |
|---|---|---|---|---|

## Kontrakt wykonania
- Workspace / repo:
- Branch etapu: stage/E0X (z main)
- Branche zadan: e0x/<klucz> + worktree
- Runner: `claude_code_local` (jedyny w v2; tryb cloud poza zakresem v2).
- Srodowisko:
- CI i komendy jakosci:
- Merge / release:

## Bramy i ryzyka
- Security:
- RODO / AI Act:
- UX / dostepnosc:
- FinOps:
- Decyzje wlasciciela lub Boardu:

## Kryteria ukonczenia etapu
-

## Scenariusze odbioru dla Boardu
| # | Scenariusz | Kroki | Oczekiwany wynik |
|---|---|---|---|
| 1 |  |  |  |

## Checklista gotowosci do startu
- [ ] Cel i zakres zaakceptowane.
- [ ] Poza zakresem zapisane.
- [ ] ADR-y i kontrakty gotowe albo jawnie oznaczone jako decyzja.
- [ ] Zaleznosci z poprzednich etapow sa spelnione.
- [ ] Repozytorium, branch i CI sa dostepne albo nie dotyczy.
- [ ] Kontrakt wykonania terminalowego jest aktualny albo nie dotyczy.
- [ ] `CLAUDE.md` repo zawiera zweryfikowane komendy albo etap zawiera zadanie `toolchain-projektu`.
- [ ] Ochrona branchy `main` i `stage/**` oraz blokady Claude Code sa skonfigurowane (`templates/ochrona-repo.md`).
- [ ] Macierz jakosci i dowodow wskazuje wymagane testy.
- [ ] Wymagane srodowisko i dostepy sa gotowe bez ujawniania sekretow.
- [ ] Ryzyka i wymagane bramki sa ustalone.
- [ ] Material do zlecenia Paperclip jest gotowy.

## Checklista realizacji
- [ ] Intake Lead rozbil etap na zadania i przypisal wlascicieli.
- [ ] Wymagane implementacje sa ukonczone.
- [ ] Kontrakty, migracje i RLS sa zgodne z decyzjami, jesli dotyczy.
- [ ] Testy adekwatne do ryzyka sa zielone.
- [ ] QA i code review zakonczone.
- [ ] Bramy warunkowe wykonane albo oznaczone jako nie dotyczy.
- [ ] Dokumentacja techniczna i produktowa jest aktualna.
- [ ] Dowody sa podlinkowane.
- [ ] Raporty QA/Security etapu zapisane w `08_Jakosc/` i w `Rejestr testow.md`.
- [ ] Powiazania etap -> zadanie -> branch/PR -> CI sa zapisane.
- [ ] Wszystkie zadania zintegrowane do `stage/E0X` przez QA; CI na `stage/E0X` zielone.
- [ ] Security review etapu wykonane albo jawnie nie dotyczy (PROCES.md sekcja 6).

## Checklista odbioru i przejscia dalej
- [ ] DoD etapu jest spelnione.
- [ ] Znane wyjatki sa zapisane i zaakceptowane przez wlasciciela lub Board, gdy wymagane.
- [ ] Roadmapa kolejnego etapu jest zweryfikowana.
- [ ] Wnioski i zmiany zakresu sa zapisane.
- [ ] Stan Obsidian jest zaktualizowany.
- [ ] Pakiet odbioru (dokument `odbior`) przekazany Boardowi.
- [ ] Board zaakceptowal etap i zmergowal `stage/E0X -> main`.
- [ ] Dla release/produkcji: monitoring, rollback i wlasciciel utrzymania sa gotowe.
- [ ] Jest jedna rekomendacja kolejnego kroku.
- [ ] Wlasciciel lub Board zdecydowal: rozpoczac kolejny etap / wstrzymac / zmienic roadmape.
```

## Stan realizacji projektu

```markdown
# Stan realizacji projektu

## Teraz
- Aktywny etap:
- Status:
- Czy wymaga decyzji wlasciciela lub Boardu:
- Jedno rekomendowane nastepne dzialanie:
- Wlasciciel nastepnego dzialania:
- Bloker:

## Etapy
| Etap | Status | Gotowosc | Bloker | Nastepne dzialanie | Zadanie Paperclip |
|---|---|---:|---|---|---|
```

Gotowosc oznacza odsetek ukonczonych pozycji z checklisty odpowiedniej dla
biezacego statusu. Nie uzywaj jej jako substytutu dowodow lub decyzji o odbiorze.
