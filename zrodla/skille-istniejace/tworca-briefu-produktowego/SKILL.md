---
name: tworca-briefu-produktowego
description: Tworzy produktowy brief aplikacji lub funkcji przed przekazaniem pracy do Softwarehouse. Uzyj przy nowej aplikacji, nowym module, istotnej funkcji albo gdy pomysl trzeba uporzadkowac w Obsidianie przed zleceniem technicznym.
---

# Softwarehouse - tworca briefu produktowego

Uzywaj tego skilla jako pierwszego kroku przed `planista-realizacji` i
`tworca-wymagan`.

Cel: zamienic luzny pomysl, opis biznesowy, design, materialy zrodlowe, linki, ZIP-y albo notatki na komplet dokumentow produktowych w Obsidianie, ktore moga pozniej posluzyc do przygotowania technicznego zlecenia dla `Softwarehouse`.

Ten skill odpowiada za `CO`, `DLACZEGO`, `DLA KOGO`, `JAKI ZAKRES` i `JAK POZNAMY, ZE DZIALA`. Nie przesadza samodzielnie o finalnej architekturze, produkcyjnym deployu, kosztach, prawie ani o dostepach.

## Kiedy uzywac

Uzyj skilla, gdy uzytkownik:

- zaczyna nowa aplikacje od zera,
- opisuje pomysl na produkt, MVP, SaaS, narzedzie albo modul,
- chce dodac wieksza funkcjonalnosc do istniejacego projektu,
- ma design, ZIP, link do wzorca, brief z Claude/Figma/Lovable albo materialy biznesowe,
- pyta, jak przejsc od pomyslu do zlecenia w Paperclip,
- potrzebuje przygotowac dokumentacje wejscia dla Software House.

Nie uzywaj go do samej implementacji, code review, debugowania, testow albo migracji. Do tego sluza skille techniczne i organizacja `Softwarehouse`.

## Zrodlo prawdy

Domyslnym zrodlem prawdy dla briefu jest Obsidian:

```text
<Obsidian Vault>/Softwarehouse/Projekty/<Nazwa projektu>/
```

Nowe projekty Softwarehouse zawsze zakladaj pod `Softwarehouse/Projekty`, a nie w globalnym katalogu `Obsidian Vault/Projekty`. Jesli uzytkownik wskaze istniejacy folder projektu albo organizacji, uzyj wskazanej sciezki. Dla dokumentacji samej organizacji Software House uzywaj:

```text
<Obsidian Vault>/Softwarehouse/
```

Nie wpisuj sekretow, tokenow, hasel ani prywatnych kluczy do Obsidiana, Paperclipa ani promptow.

## Tryby pracy

Rozpoznaj jeden z trybow:

- `nowy projekt` - aplikacja lub produkt od zera,
- `nowa funkcja` - funkcjonalnosc w istniejacym projekcie,
- `zmiana produktu` - istotna zmiana zakresu, rynku, modelu biznesowego lub ryzyk,
- `discovery` - uzytkownik chce uporzadkowac pomysl bez startu developmentu.

Jesli tryb nie jest jawny, przyjmij najbezpieczniejszy tryb na podstawie tresci i nazwij zalozenie.

## Workflow

1. Ustal produkt, organizacje produktowa i cel pracy.
2. Zbierz kontekst z rozmowy, zalacznikow, linkow, designu i istniejacej dokumentacji.
3. Jesli brakuje informacji blokujacych, zadaj maksymalnie 3 pytania. W pozostalych miejscach zapisz zalozenia.
4. Okresl tryb pracy: `nowy projekt`, `nowa funkcja`, `zmiana produktu` albo `discovery`.
5. Utworz albo zaktualizuj strukture Obsidian zgodnie z [references/struktura-obsidian-projektu.md](references/struktura-obsidian-projektu.md).
6. Wypelnij dokumenty produktowe zgodnie z [references/szablony-dokumentow.md](references/szablony-dokumentow.md).
7. Przygotuj wstepna rekomendacje technologiczna i proponowane etapy realizacji.
8. Wykonaj checkliste gotowosci projektu przed Software House. Jest to jedna,
   prowadzona przez ten skill checklista startowa projektu, a nie jednorazowy
   raport. Na koncu przedstaw jej wersje do odhaczenia przez wlasciciela lub Board i uzupelnij
   pola po kazdej odpowiedzi uzytkownika.
9. Oznacz decyzje, ryzyka, pytania otwarte i elementy wymagajace human gate.
10. Przygotuj sekcje `Input dla Software House`: zwiezly wsad do pozniejszego uzycia przez `tworca-wymagan`.
11. Na koncu wskaz nastepny krok: doprecyzowanie, plan realizacji przez
    `planista-realizacji` albo brak gotowosci. Dla nowej aplikacji albo
    wiekszej funkcji nie przekazuj od razu calego projektu do Paperclip.

## Minimalny wynik dla nowego projektu

Dla nowego projektu utworz lub zaktualizuj co najmniej:

- `00_Brief/Brief produktowy.md`,
- `00_Brief/Problem i cel.md`,
- `00_Brief/Grupy uzytkownikow.md`,
- `00_Brief/Zakres MVP.md`,
- `01_Wymagania/Funkcje MVP.md`,
- `01_Wymagania/Role i uprawnienia.md`,
- `01_Wymagania/Wymagania niefunkcjonalne.md`,
- `03_Decyzje/Rejestr decyzji produktowych.md`,
- `03_Decyzje/Otwarte pytania.md`,
- `04_Ryzyka/RODO i dane osobowe.md`,
- `04_Ryzyka/Bezpieczenstwo.md`,
- `05_Backlog/Epiki MVP.md`,
- `05_Backlog/Proponowane etapy realizacji.md`,
- `06_Delivery/Checklist gotowosci projektu.md`,
- `06_Delivery/Input dla Software House.md`,
- `06_Delivery/Project Access Card.md`,
- `07_Techniczne/ADR-0 - Stack i hosting.md` jako szkic decyzji technicznej,
- `08_Jakosc/Rejestr testow.md` (pusta tabela z szablonu `quality-engineering`).

## Wstepna rekomendacja technologiczna

Dla nowego projektu i wiekszej funkcji przygotuj robocza rekomendacje technologiczna. To nie jest finalna decyzja architektoniczna.

W rekomendacji pokaz:

- 2-3 sensowne warianty stacku,
- wariant rekomendowany,
- uzasadnienie wyboru,
- konsekwencje dla kosztow, utrzymania, security, RODO/AI Act, testow i CI,
- decyzje wymagajace wlasciciela lub Boardu albo Architekta/Intake Lead.

Domyslnie dla dojrzalych aplikacji SaaS preferuj model `repo-first`, jesli brief nie wskazuje inaczej:

```text
Frontend: React/Next/Vite do decyzji w ADR-0
Hosting: Lovable (Publish przez Board), podglad etapow lokalnie
Backend: Supabase lokalny (dev/test) + Supabase Cloud (produkcja przez CI) + kontrolowane API/Edge Functions/RPC
AI: backendowy adapter do modelu, nie AI zaszyte w frontendzie
CI: lokalne Forgejo jako pierwsza bramka, GitHub opcjonalnie
Dokumentacja: Obsidian
Delivery: Paperclip
```

Domyslny profil: `templates/ADR-0-profil-lovable-supabase.md` pakietu. Lovable sluzy do hostingu produkcji i malych, swiadomych zmian Boardu; kod powstaje w repo.

## Proponowane etapy realizacji

Dla nowego projektu i wiekszej funkcji zaproponuj etapowanie pracy produktowo-technicznej.

Etapy maja pomoc Intake Lead, ale nie zastepuja jego finalnego podzialu na zadania. Nie tworz finalnego boardu zadan.

Typowy podzial:

- `Etap 0 - przygotowanie`: foldery, repo, dostepy, ADR-0, Project Access Card, CI baseline.
- `Etap 1 - fundamenty`: auth, role, model danych, RLS, layout aplikacji, podstawowa nawigacja.
- `Etap 2 - core flow MVP`: najwazniejszy przeplyw uzytkownika end-to-end.
- `Etap 3 - jakosc i bezpieczenstwo`: testy, QA, security review, compliance, dokumentacja.
- `Etap R01 - wydanie`: przeglad bezpieczenstwa, backup, rollback, monitoring, runbook, decyzja produkcyjna (skill `etap-wydania`).

Kazdy etap opisz przez cel, zakres, zaleznosci, ryzyka i kryterium zakonczenia.

## Checklista gotowosci projektu

Przed przekazaniem pracy do `tworca-wymagan` sprawdz, czy Software House ma minimalny komplet materialow i ustalen.

Checklistę zapisz w:

```text
06_Delivery/Checklist gotowosci projektu.md
```

Sprawdz i oznacz `gotowe`, `brak`, `do ustalenia` albo `nie dotyczy` dla:

- folder Obsidian projektu,
- lokalny folder projektu na dysku,
- folder materialow zrodlowych,
- folder designu / screenshotow / ZIP-ow,
- folder repo albo plan utworzenia repo,
- remote git / Forgejo / GitHub,
- opis produktu,
- zakres MVP,
- podstawowe funkcje,
- uzytkownicy i role,
- kryteria akceptacji,
- materialy wejsciowe,
- decyzja, czy ZIP-y sa tylko referencja czy materialem do wykorzystania,
- ADR-0 / szkic decyzji technologicznej,
- checklista ryzyk,
- Project Access Card,
- decyzje wymagajace wlasciciela lub Boardu.

Jesli brakuje informacji, pytaj punktowo i aktualizuj dokumenty po odpowiedzi uzytkownika. Przyklad: jesli brakuje lokalnego folderu projektu, zapytaj o sciezke; po odpowiedzi wpisz ja do `Project Access Card.md` i checklisty.

Nie zakladaj samodzielnie folderu roboczego, repo, MCP, Supabase, Lovable ani hostingu, chyba ze uzytkownik wyraznie zleci taka akcje.

### Checklista dla wlasciciela lub Boardu

Na koncu kazdej sesji w trybie `nowy projekt` przedstaw krotka, wykonawcza
wersje checklisty dla wlasciciela lub Boardu. Ma zawierac tylko otwarte elementy, wlasciciela,
konkretny nastepny ruch i pole na wartosc do wpisania, np. pelna sciezke,
URL repo albo nazwe workspace.

Po odpowiedzi wlasciciela lub Boardu aktualizuj w Obsidianie zawsze te same dokumenty:

- `06_Delivery/Checklist gotowosci projektu.md` jako zrodlo statusu,
- `06_Delivery/Project Access Card.md` dla sciezek, repo, CI i dostepow,
- odpowiedni ADR, rejestr decyzji albo dokument ryzyk, jezeli odpowiedz
  zmienia technologie, ryzyko lub decyzje.

Nie tworz drugiej checklisty startowej. `planista-realizacji` jedynie
weryfikuje jej stan i dopisuje wymagania konkretnego etapu.

Minimalne pozycje checklisty startowej to: folder Obsidian, lokalny folder
projektu, materialy i design, repo/remote, workspace Paperclip, CI target,
srodowiska (Supabase lokalny, produkcja Lovable + Supabase Cloud), wlasciciel produktu/odbioru, ryzyka,
ADR-0 oraz Project Access Card. Sekrety oznaczaj wylacznie jako "skonfigurowane
w magazynie sekretow"; nigdy nie pros o ich wartosci.

## Minimalny wynik dla nowej funkcji

Dla nowej funkcji nie tworz pelnej struktury od zera, jesli projekt juz istnieje. Zaktualizuj:

- dokument funkcji w `01_Wymagania/` albo `05_Backlog/`,
- rejestr decyzji, jesli pojawila sie decyzja produktowa,
- ryzyka, jesli funkcja dotyka danych, AI, platnosci, uploadu, auth, RLS albo prawa,
- `06_Delivery/Input dla Software House.md` albo osobny plik handoffu funkcji.

## ADR-0 i technologia

Technologia jest ustalana po briefie produktowym, ale przed implementacja.

W tym skillu tworzysz szkic `ADR-0 - Stack i hosting.md`, ktory zawiera:

- potrzeby produktu,
- ograniczenia biznesowe i prawne,
- warianty stacku,
- rekomendacje robocza,
- decyzje wymagajace wlasciciela lub Boardu,
- konsekwencje dla developmentu, testow, kosztow i utrzymania.

Finalna decyzja techniczna nalezy do Wlasciciel lub Boarda oraz Architekta/Intake Lead w organizacji Software House. Oznacz ADR-0 jako `Szkic / Do decyzji`, dopoki nie zostanie zatwierdzony.

## Checklista ryzyk

Kazdy brief oznacz `tak`, `nie` albo `do ustalenia` dla:

- dane osobowe,
- dane wrazliwe albo wysokiego ryzyka,
- AI lub automatyczne decyzje,
- AI Act,
- RODO,
- platnosci,
- upload plikow,
- auth i role uzytkownikow,
- RLS i dostepy do danych,
- integracje zewnetrzne,
- marketplace, handel, rozliczenia albo instrumenty regulowane,
- aplikacja mobilna,
- produkcyjny deploy,
- koszty infrastruktury albo narzedzi,
- potrzeba konsultacji prawnej, compliance albo security.

Jesli `tak` albo `do ustalenia`, zapisz to jako bramke przed wdrozeniem technicznym.

## Granice autonomii

Skill moze samodzielnie:

- porzadkowac pomysl,
- tworzyc dokumenty i szablony w Obsidianie,
- tworzyc albo aktualizowac folder projektu w Obsidianie,
- uzupelniac checklistę gotowosci i Project Access Card na podstawie odpowiedzi uzytkownika,
- proponowac zakres MVP,
- proponowac robocze warianty technologiczne i rekomendowany wariant,
- proponowac etapy realizacji MVP,
- proponowac pytania do decyzji,
- przygotowac wsad dla Software House.

Skill nie moze samodzielnie:

- uruchamiac projektu w Paperclip,
- zakladac lokalnego folderu roboczego bez jawnej zgody,
- zakladac repo, MCP, Supabase, Lovable ani hostingu,
- zatwierdzac kosztow, produkcji, prawa albo ryzyk regulacyjnych,
- wybierac finalnej architektury bez ADR i akceptacji wlasciciela lub Boardu,
- wpisywac sekretow do dokumentacji.

## Output

Odpowiedz powinna zawierac:

1. Status: `gotowe do zlecenia technicznego`, `gotowe z brakami`, `discovery`, albo `zablokowane`.
2. Liste utworzonych albo zaktualizowanych plikow Obsidian.
3. Najwazniejsze decyzje i zalozenia.
4. Wstepna rekomendacje technologiczna: warianty, rekomendacja, decyzje do zatwierdzenia.
5. Proponowane etapy realizacji: etapy, cel, zakres, zaleznosci i kryteria zakonczenia.
6. Checklistę gotowosci projektu: co jest gotowe, czego brakuje, co blokuje przekazanie do Software House.
7. Pytania otwarte, maksymalnie 5.
8. Rekomendowany nastepny krok:
   - uzyc `planista-realizacji` dla nowego projektu, modulu albo wiekszej funkcji,
   - uzyc `tworca-wymagan` bezposrednio tylko dla malej,
     dobrze ograniczonej zmiany,
   - przygotowac ADR-0,
   - dopelnic discovery,
   - zatrzymac prace do decyzji wlasciciela lub Boardu.
