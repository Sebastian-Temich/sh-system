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

## Bramy i ryzyka
- Security:
- RODO / AI Act:
- UX / dostepnosc:
- FinOps:
- Decyzje ISKT:

## Kryteria ukonczenia etapu
-

## Checklista gotowosci do startu
- [ ] Cel i zakres zaakceptowane.
- [ ] Poza zakresem zapisane.
- [ ] ADR-y i kontrakty gotowe albo jawnie oznaczone jako decyzja.
- [ ] Zaleznosci z poprzednich etapow sa spelnione.
- [ ] Repozytorium, branch i CI sa dostepne albo nie dotyczy.
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

## Checklista odbioru i przejscia dalej
- [ ] DoD etapu jest spelnione.
- [ ] Znane wyjatki sa zapisane i zaakceptowane przez ISKT, gdy wymagane.
- [ ] Roadmapa kolejnego etapu jest zweryfikowana.
- [ ] Wnioski i zmiany zakresu sa zapisane.
- [ ] Stan Obsidian jest zaktualizowany; Airtable zaktualizowany jesli jest wymagany i polaczenie zweryfikowane.
- [ ] Jest jedna rekomendacja kolejnego kroku.
- [ ] Sprawdzono ważną zgodę na nazwany następny etap i spełnienie warunków przejścia z delivery 2.2; jeśli jej brak, wskazano decyzję ISKT.
```

## Stan realizacji projektu

```markdown
# Stan realizacji projektu

## Teraz
- Data aktualizacji / zrodlo statusu Paperclip:
- Ostatnio odebrany etap:
- Aktywny etap (brak jesli zakonczony):
- Status:
- Czy wymaga decyzji ISKT:
- Jedno rekomendowane nastepne dzialanie:
- Wlasciciel nastepnego dzialania:
- Bloker:

## Etapy
| Etap | Status | Gotowosc | Bloker | Nastepne dzialanie | Zadanie Paperclip |
|---|---|---:|---|---|---|
```

Gotowosc oznacza odsetek ukonczonych pozycji z checklisty odpowiedniej dla
biezacego statusu. Nie uzywaj jej jako substytutu dowodow lub decyzji o odbiorze.

## Rejestr autoryzacji i pomiaru (2.2)
Źródła i rewizje: …
Zgoda: osoba / link / data / nazwane etapy / zakres / budżet / uprawnienia / ważność / ograniczenia.
Rozmiar S/M/L i uzasadnienie: …
Flagi ryzyka, bramki i właściciele: …
Autonomia allowed/limited/not allowed; konkretne blokady: …
Preflight środowiska: dowód / data / zakres / wynik / właściciel braków.
UTC requested_at / implementation_started_at / implementation_done_at / accepted_at: …
Oczekiwanie: blocker_started_at / ended_at / human|infra|dependency / właściciel.
Liczba runów / cykli poprawek: …
Docs delta / dowody / następny krok i właściciel: …
