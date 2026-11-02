---
name: planista-realizacji
description: Projektuje zatwierdzalny plan etapow realizacji aplikacji lub wiekszej funkcji dla Softwarehouse. Uzyj po briefie, a przed tworzeniem zlecen Paperclip, aby zaplanowac architekture, etapy, checklisty przejsc i nastepny krok w Obsidianie.
---

# Softwarehouse - planista realizacji

Uzywaj tego skilla po `tworca-briefu-produktowego`, a przed
`tworca-wymagan` dla nowej aplikacji, nowego modulu albo
wiekszej funkcji. Nie zastępuje briefu produktowego, architektury szczegolowej
ani rozbicia pojedynczego etapu na zadania w Paperclip.

Cel: przeksztalcic zaakceptowany brief w kontrolowany plan realizacji. Plan ma
dzielic projekt na male, odbieralne etapy, wskazywac ich zaleznosci i umozliwiac
jednoznaczna odpowiedz na pytanie: `co robimy teraz?`.

## Granice odpowiedzialnosci

- Brief okresla `CO`, `DLACZEGO`, `DLA KOGO` i rezultat biznesowy.
- Ten skill okresla `W JAKIEJ KOLEJNOSCI` dostarczamy zakres oraz jakie
  fundamenty i kontrakty sa potrzebne.
- `tworca-wymagan` przygotowuje zlecenie Paperclip dla
  jednego wybranego etapu.
- Intake Lead dzieli etap na wykonawcze zadania S/M/L i przypisuje role.
- Wlasciciel lub Board zatwierdza ADR-y, koszty, ryzyka wysokie, produkcje i
  zmiany zakresu, ktore wychodza poza zaakceptowany plan.

## Zrodlo prawdy

Pracuj w katalogu projektu:

```text
<Obsidian Vault>/Softwarehouse/Projekty/<Nazwa projektu>/
```

Obsidian jest zrodlem prawdy dla roadmapy, checklist, decyzji i dowodow.
Paperclip jest zrodlem prawdy dla statusu konkretnych zadan. Zasady procesu
(role, branche, statusy, odbior) sa w `PROCES.md` pakietu.

Nie wpisuj sekretow, tokenow, hasel ani kluczy do zadnych dokumentow lub
promptow.

## Wejscie

Przed rozpoczeciem przeczytaj, jesli istnieja:

- `00_Brief/Brief produktowy.md`, `01_Wymagania/` i `02_Design/`,
- `03_Decyzje/` i `04_Ryzyka/`,
- `05_Backlog/Epiki MVP.md` oraz proponowane etapy z briefu,
- szkic `07_Techniczne/ADR-0 - Stack i hosting.md`,
- `06_Delivery/Checklist gotowosci projektu.md` i `Project Access Card.md`.

Traktuj `Checklist gotowosci projektu.md` jako jedyne zrodlo gotowosci
startowej. Nie tworz jej kopii: zweryfikuj ja i dopisz tylko wymagania
konkretnego etapu.

Jesli brakuje informacji blokujacych, zadaj maksymalnie 3 pytania. Reszte
zapisz jako zalozenia albo decyzje do podjecia przed odpowiednim etapem.

## Workflow

1. Potwierdz granice MVP, kryterium sukcesu i elementy poza zakresem.
2. Zweryfikuj szkic ADR-0. Dla nowego lub istotnie zmienianego systemu
   przygotuj decyzje do zatwierdzenia, a nie samodzielna finalna architekture.
3. Zbuduj mape realizacji: moduly domenowe, wlasciciele danych, role/RLS,
   kontrakty API/RPC, granice frontend-backend, integracje i zaleznosci.
4. Zaplanuj etapy jako odbieralne pionowe przekroje. Etap ma dostarczyc
   dzialajacy rezultat, a nie tylko warstwe techniczna.
5. Wydziel etap fundamentow tylko dla wspolnych elementow, ktore musza
   poprzedzac pierwszy przekroj: repo/CI, model tenancy, auth/RLS, wspolny
   kontrakt, design system albo observability. Nie zamieniaj go w budowe
   calego backendu.
6. Dla kazdego etapu utworz lub zaktualizuj dokument, checkliste gotowosci,
   checklistę realizacji i checklistę odbioru wedlug
   [references/plan-etapow.md](references/plan-etapow.md).
   Dla etapu obejmujacego kod uzupelnij kontrakt wykonania terminalowego,
   macierz jakosci i dowodow oraz, gdy dotyczy, plan release i utrzymania.
   Dla kazdego etapu zapisz 5-10 scenariuszy odbioru dla Boardu (wejscie do
   skilla `odbior-etapu`).
7. Zaktualizuj centralny `06_Delivery/Stan realizacji projektu.md` oraz
   `05_Backlog/Roadmapa realizacji.md`.
8. Wskaz dokladnie jeden rekomendowany nastepny krok: decyzje do podjecia,
   przygotowanie zlecenia dla wskazanego etapu albo praca przy juz otwartym
   etapie.

## Zasady etapowania

- Nie planuj etapow jako `najpierw backend, potem frontend`. Preferuj kompletne
  przeplywy od danych do UI, testow i dokumentacji.
- Kazdy etap ma jeden cel, ograniczony zakres, jawne `poza zakresem`, DoD,
  dowody oraz warunki przejscia dalej.
- Nie wpisuj do jednego etapu funkcji, ktore nie maja wspolnego celu odbioru.
- Dla niepewnych lub wysokiego ryzyka obszarow zaplanuj wczesny spike/PoC z
  wyraznym kryterium decyzji, zamiast ukrywac ryzyko w duzym etapie.
- Kolejne etapy sa planem zyjacym: aktualizuj je po odbiorze poprzedniego
  etapu i zapisuj uzasadnienie zmiany w rejestrze decyzji.
- Nie tworz automatycznie zadan Paperclip ani repozytoriow. Przygotuj dane,
  ktore pozwalaja uzyc `tworca-wymagan` dla jednego etapu.
- Etap z kodem nie jest gotowy do startu bez wskazania workspace, branch
  strategy, CI targetu i minimalnych dowodow jakosci albo jawnej decyzji wlasciciela lub Boardu,
  dlaczego sa niedostepne.
- Etap z kodem jest realizowany na branchu `stage/E0X` tworzonym z `main`
  przez Intake Leada; zadania trafiaja do niego przez PR po akceptacji QA,
  a Board merguje `stage/E0X -> main` przy odbiorze (PROCES.md sekcja 4).
- Runner: `claude_code_local` przez adapter Paperclip. Tryb cloud jest poza
  zakresem v2.
- Pierwszy etap projektu z kodem zawiera zadanie `toolchain-projektu`
  (komendy w `CLAUDE.md`) oraz CI z bramkami bezpieczenstwa z `templates/forgejo/workflows/ci.yml` (Forgejo).
- Przed pierwszym wdrozeniem produkcyjnym i przed kazdym kolejnym wydaniem
  zaplanuj etap wydania `R0X` (skill `etap-wydania`, PROCES.md sekcja 12).
  Wdrozenie produkcyjne nigdy nie jest czescia zwyklego etapu `E0X`.
- Wyniki testow i odbiorow trafiaja do `08_Jakosc/` (PROCES.md sekcja 13).

## Statusy i pytanie "co robimy teraz?"

Uzywaj tylko statusow: `planowany`, `gotowy do startu`, `w realizacji`,
`zablokowany`, `do odbioru`, `zakonczony`, `wstrzymany`. Mapowanie na statusy
Paperclip: `PROCES.md` sekcja 5.

Na pytanie `co robimy teraz?` przeczytaj centralny stan projektu i odpowiedz
w tej kolejnosci:

1. status aktywnego albo ostatnio zakonczonego etapu,
2. czy checklista odbioru jest zamknieta,
3. najblizszy etap gotowy do startu albo konkretny bloker,
4. jedno zalecane dzialanie wraz z wlascicielem,
5. czy wymaga decyzji wlasciciela lub Boardu.

Nie zalecaj tworzenia zlecenia dla kolejnego etapu, dopoki jego checklista
gotowosci nie jest kompletna. Gdy jest kompletna, podaj gotowy prompt dla
`tworca-wymagan` ograniczony do identyfikatora etapu.

## Output

Po wykonaniu pracy przedstaw:

1. status gotowosci planu: `gotowy do akceptacji`, `gotowy z zalozeniami` albo
   `wymaga decyzji`,
2. mape architektoniczna na poziomie modulow i kontraktow,
3. tabele etapow z celem, zakresem, zaleznosciami, ryzykami i DoD,
4. utworzone lub zaktualizowane pliki Obsidian,
5. dokladnie jeden rekomendowany nastepny krok.
