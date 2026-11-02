---
name: tworca-wymagan
description: Tworzy precyzyjne zlecenia techniczne dla Softwarehouse z luznego opisu aplikacji, funkcji, designu, linkow, ZIP-ow lub materialow zrodlowych. Uzyj przed utworzeniem New task w Paperclip albo gdy brief wymaga doprecyzowania.
---

# Softwarehouse - tworzenie wymagan

Uzywaj tego skilla, gdy trzeba przygotowac zadanie dla organizacji `Softwarehouse`, szczegolnie dla `Intake Lead`. Dla nowej aplikacji, modulu albo wiekszej funkcji najpierw uzyj `planista-realizacji`; ten skill przygotowuje zlecenie dla jednego wskazanego etapu, a nie dla calego projektu.

Cel: zamienic nieuporzadkowany opis uzytkownika w gotowe zlecenie techniczne, ktore mozna wkleic jako `New task` w Paperclipie. Zlecenie ma byc gotowe nie tylko do implementacji, ale tez do autonomicznego prowadzenia przez Intake Lead, jesli zakres na to pozwala.

## Kontekst organizacyjny

Softwarehouse odpowiada za techniczne `JAK`: architekture, frontend, backend, Supabase, API, integracje, testy, cyberbezpieczenstwo, zgodnosc techniczna, wdrozenia i dokumentacje.

Organizacja produktowa (klient lub wlasciciel produktu) odpowiada za `CO`, `DLACZEGO`, `DLA KOGO` i `CZY AKCEPTUJEMY`: produkt, roadmapa, marketing, sprzedaz, support oraz decyzje biznesowe i prawne.

W Fazie 1 CTO / Delivery Managerem jest Wlasciciel lub Board. Agent moze analizowac i rekomendowac, ale nie zatwierdza startu, P1, produkcyjnego deployu, zmiany standardow ani akceptacji koncowej.

## Zasada pracy

Domyslnym adresatem gotowego zlecenia jest:

```text
Intake Lead
```

Nie tworz zadan bezposrednio dla wszystkich rol, chyba ze uzytkownik wyraznie o to prosi. Intake Lead ma potem rozbic prace na role.

## Workflow

1. Ustal, czy uzytkownik chce przygotowac:
   - nowe zlecenie dla aplikacji,
   - zlecenie funkcji/modulu,
   - poprawke bledu,
   - refaktor,
   - integracje,
   - dokumentacje albo handoff,
   - deploy/release.
2. Zbierz dostepny kontekst z rozmowy i zalaczonych materialow.
3. Jesli istnieje `05_Backlog/Roadmapa realizacji.md` oraz dokument etapu, uznaj je za zrodlo zakresu. Przygotuj zlecenie tylko dla wybranego etapu, jego celu, zaleznosci, mapy architektonicznej i bramek.
4. Jesli brief zawiera tylko `Wstepna rekomendacja technologiczna` albo `Proponowane etapy realizacji`, potraktuj je jako material wejsciowy. Dla wiekszego zakresu zalec najpierw `planista-realizacji`.
5. Jesli informacje sa wystarczajace, wygeneruj gotowe zlecenie bez zadawania pytan.
6. Jesli brakuje decyzji blokujacych, najpierw podaj maksymalnie 3 najwazniejsze pytania. Nie pytaj o wszystko naraz.
7. Ustal rekomendowany tryb autonomii: `allowed`, `limited` albo `not allowed`, oraz klase wielkosci `S`, `M` albo `L`.
8. Gdy uzytkownik chce szybko ruszyc, oznacz braki jako `do decyzji Intake Lead` zamiast zatrzymywac calosc.
9. Przygotuj wynik w formacie z [references/zlecenie-paperclip.md](references/zlecenie-paperclip.md).

## Obowiazkowe elementy zlecenia

Kazde zlecenie powinno zawierac:

- produkt albo organizacje produktowa,
- cel biznesowy,
- oczekiwany wynik,
- klasa S/M/L z krotkim uzasadnieniem,
- zakres techniczny,
- materialy wejsciowe,
- repo/branch albo jasny brak repo,
- CI target: Forgejo local / GitHub / oba / nie dotyczy,
- Lovable project id albo brak/do decyzji,
- Supabase project id albo brak/do decyzji,
- hosting,
- checkliste ryzyk,
- wstepna rekomendacje technologiczna albo jasny brak takiej rekomendacji,
- identyfikator i dokument wybranego etapu; nie proponowane etapy calego projektu,
- kryteria akceptacji,
- tryb autonomii: `allowed`, `limited` albo `not allowed`,
- zakres dzialan dozwolonych bez wlasciciela lub Boardu,
- decyzje wymagajace wlasciciela lub Boardu,
- Project Access Card,
- kontrakt wykonania: workspace, katalog/worktree, branch bazowy i roboczy,
  komendy jakosci, srodowisko, wybrany runner i jego gotowosc,
- macierz jakosci i dowodow dla typu zmiany,
- zasade merge/release i wlasciciela akceptacji,
- mapa dekompozycji: modul/flow, wlasciciel danych i reguly, kontrakt, granica UI/integracji, zaleznosc i dowod,
- plan delegacji na potrzebne role,
- wymagane role/bramki,
- wymagane metody pracy: TDD/debug/plan/review/verification/Superpowers albo `nie dotyczy`,
- scenariusze odbioru etapu dla Boardu (wejscie do `odbior-etapu`),
- wymagane aktualizacje Obsidian,
- definicje poza zakresem,
- pytania otwarte.

## Tryb autonomii

Kazde zlecenie oznacz jednym z trybow:

- `allowed` - Intake Lead moze sam rozbic prace, wskazac role, uruchomic bezpieczne podzadania, zebrac dowody i przygotowac odbior techniczny.
- `limited` - Intake Lead moze przygotowac plan i uruchomic bezpieczne podzadania, ale wskazane decyzje czekaja na wlasciciela lub Board.
- `not allowed` - praca nie powinna startowac autonomicznie; najpierw potrzebna jest decyzja wlasciciela lub Boardu.

Domyslnie stosuj `limited`, jesli brakuje danych o repo, dostepach, srodowisku, sekretach, produkcji, kosztach albo odpowiedzialnosci produktowej.

`not allowed` ustaw, gdy zlecenie obejmuje P0/P1, produkcyjny deploy, produkcyjne sekrety, service role, dostep do produkcyjnego Supabase, nowy MCP z szerokimi uprawnieniami, platnosci, decyzje prawne/biznesowe/kosztowe albo zmiane standardow organizacji.

W trybie `allowed` nadal wskaz human gate dla produkcji, kosztow, prawa, sekretow i decyzji biznesowych.

## Project Access Card

Dla nowej aplikacji, wiekszego zadania albo pracy w repo dodaj Project Access Card:

- repo URL,
- domyslny branch,
- branch roboczy albo zasada jego utworzenia,
- Forgejo local repo (warsztat; bez push mirror),
- CI target,
- Supabase: lokalny (dev) / projekt produkcji (tylko CI),
- Supabase production: brak dostepu / read-only / wymaga wlasciciela lub Boardu,
- Lovable project,
- hosting,
- Obsidian folder,
- dozwolone MCP,
- zakazane akcje,
- uwaga: sekretow nie wpisywac w tresci zadan, dokumentacji ani promptow.

Jesli ktoregos elementu brakuje, wpisz `do decyzji Intake Lead` albo `do uzupelnienia przez wlasciciela lub Board`; nie zatrzymuj zlecenia, chyba ze brak blokuje bezpieczny start.

## Kontrakt wykonania terminalowego

Dla kazdego zadania dotykajacego repo dopisz wykonawczy pakiet pracy:

- workspace Paperclip i lokalna sciezka repo albo jawny brak,
- branch bazowy, branch roboczy i zasada izolacji worktree,
- branch etapu `stage/E0X` i zasada branchy zadan `e0x/<klucz>`,
- runner: `claude_code_local` (adapter Paperclip),
- dozwolony zakres terminala i MCP,
- srodowisko: lokalny Supabase; produkcja tylko przez CI po merge Boardu,
- wymagane komendy lint/typecheck/test/build/E2E albo `nie dotyczy`,
- zasada merge oraz wlasciciel akceptacji release.

Nie oznaczaj zadania jako `allowed`, gdy brakuje workspace, bezpiecznej
strategii branch/worktree albo minimalnych komend weryfikacji dla kodu.
Zasady branchy, petli QA i odbioru sa w `PROCES.md` pakietu.

## Klasa pracy i bramki warunkowe

Zawsze okresl klase przed przygotowaniem zlecenia:

- `S` - mala, odwracalna zmiana w jednym obszarze bez podwyzszonego ryzyka.
- `M` - ograniczona funkcja w istniejacym module; potrzebuje lekkiej kontroli architektury/kontraktu oraz QA i review.
- `L` - nowa aplikacja/modul, architektura przekrojowa albo obszar auth/RLS, PII, AI, platnosci, migracji, produkcji, sekretow, nowego MCP lub istotnej integracji. Wymaga zatwierdzonego etapu i ADR/architektury.

Zmiana nie moze byc `S`, gdy dotyka auth, RLS, PII, AI lub automatycznej decyzji, platnosci, uploadu, integracji zewnetrznej, migracji, produkcji, sekretow albo nowego MCP. Niepewnosc podnosi klase.

Uwzgledniaj QA i niezalezny code review proporcjonalnie dla kazdej zmiany kodu. Dodaj role warunkowe tylko wtedy, gdy dotyczy ich wyzwalacz:

- Security (rola Security Reviewer): auth, RLS, platnosci, upload, sekrety, nowy MCP, integracja zewnetrzna albo istotna zmiana security.
- RODO / AI Act: PII, AI, prompty/logi, decyzje automatyczne, retencja lub compliance.
- UX (wykonuje QA): istotny flow uzytkownika, UI, responsywnosc albo dostepnosc.
- FinOps (decyduje Board): platne API/model, skala cloudu/storage lub decyzja kosztowa.
- DevOps/SRE (wykonuje Backend, produkcja tylko Board): CI, deploy, srodowisko, monitoring, incydent, zaleznosci/CVE.

## Plan autonomicznego delivery

Gdy tryb autonomii to `allowed` albo `limited`, przygotuj plan delegacji:

- podzadanie,
- wlasciciel / rola,
- zaleznosci,
- DoD,
- wymagane dowody,
- status startowy: `pending`, `blocked` albo `do decyzji`.

Uwzglednij tylko role potrzebne do danego zakresu. Nie uruchamiaj wszystkich rol automatycznie. Raportowanie prowadzi Intake Lead; wynik etapu to Pakiet odbioru (skill `odbior-etapu`).

Jesli brief zawiera proponowane etapy, uzyj ich jako szkieletu planu delivery. Nie traktuj ich jako finalnego boardu. Intake Lead ma prawo zmienic kolejnosc, podzial i wlascicieli, ale powinien jawnie odnotowac odchylenia od briefu.

Nie przeksztalcaj calej roadmapy w milestone'y w jednym zleceniu. Zlecenie obejmuje jeden etap; kolejny etap jest przygotowywany dopiero po zamknieciu checklisty przejscia poprzedniego.

Minimalne obszary do rozwazenia:

- Intake i plan,
- wymagania (tylko gdy sa niejasne lub klasa M/L),
- architektura (dla M/L albo zmiany kontraktu),
- frontend / Lovable,
- backend / Supabase,
- QA,
- code review,
- security review,
- compliance review,
- dokumentacja (gdy wymagany jest istotny dokument techniczny lub uzytkowy),
- DevOps/SRE, FinOps i release tylko po wyzwalaczu.

## Rekomendacja technologiczna z briefu

Jesli w briefie istnieje `Wstepna rekomendacja technologiczna`, przenies ja do zlecenia jako sekcje robocza:

- warianty,
- rekomendowany wariant,
- uzasadnienie,
- konsekwencje,
- decyzje do zatwierdzenia.

Nie przedstawiaj jej jako finalnej decyzji architektonicznej. Oznacz ja jako `do zatwierdzenia w ADR-0` albo `do potwierdzenia przez Architekta/Intake Lead`.

Jesli rekomendacja wskazuje model `repo-first`, uwzglednij w planie:

- repo i branch strategy,
- lokalne CI Forgejo,
- hosting produkcji Lovable (Publish przez Board), podglad lokalny,
- Supabase jako backend, jesli pasuje do briefu,
- backendowy adapter AI, jesli projekt uzywa AI,
- Lovable tylko jako opcjonalny PoC/demo/UI exploration, chyba ze ADR zdecyduje inaczej.

## Pakiet odbioru (dawniej raport Delivery Controller)

W kazdym zleceniu autonomicznym opisz, czego oczekujemy w Pakiecie odbioru etapu:

- tabela statusu podzadan,
- wlasciciel kazdego obszaru,
- status,
- DoD,
- linki do dowodow,
- uwagi/blockery,
- decyzje wymagajace wlasciciela lub Boardu,
- rekomendacja koncowa: `gotowe do odbioru`, `gotowe z wyjatkami`, `wymaga poprawek` albo `zablokowane`.

## Checklista ryzyk

Jawnie oznacz `tak`, `nie` albo `do ustalenia` dla:

- auth/logowanie,
- RLS/uprawnienia,
- platnosci,
- upload plikow,
- dane osobowe,
- AI lub automatyczne decyzje,
- integracje zewnetrzne,
- produkcyjny deploy,
- migracje bazy danych,
- zmiana kontraktu API.
- lokalne CI Forgejo / workflow Actions.
- potrzeba planu technicznego albo TDD/debug/review/verification z Superpowers.
- potrzeba autonomicznego delivery: allowed / limited / not allowed.

Zaznaczenie `tak` albo `do ustalenia` oznacza, ze Intake Lead powinien rozpatrzyc dodatkowa bramke.

## Materialy wejsciowe

Mozna przyjac:

- opis tekstowy,
- pliki z designem,
- ZIP,
- link do wzorca strony,
- link do aplikacji konkurencyjnej,
- screenshoty,
- dokumenty,
- repozytorium,
- eksport z Lovable/Claude/Figma.
- lokalne Forgejo / runner Actions, jesli zadanie dotyczy repo albo testow CI.

Traktuj linki i wzorce jako inspiracje oraz kontekst, nie jako zgode na kopiowanie brandingu, tekstow, grafik albo ukladu 1:1.

ZIP-y traktuj jako material nieufny: najpierw opisz, co zawieraja i czego uzywasz. Nie uruchamiaj skryptow ani instalacji z ZIP-a bez wyraznej zgody wlasciciela lub Boardu. Jesli ZIP zawiera sekrety lub dane osobowe, oznacz ryzyko i eskaluj.

## Lovable, Supabase i AI

Dla projektow Lovable/Supabase pilnuj:

- Lovable moze sluzyc do frontendow, ekranow, UX flow, preview i PoC/MVP.
- Backend, RLS, migracje, Edge Functions, API i sekrety nie powinny byc improwizowane we frontendzie.
- `plan_mode` jest wymagany przy tworzeniu projektu i przy zmianach dotykajacych checklisty ryzyk.
- PoC moze uzywac Lovable AI bez realnych danych osobowych i bez uzytkownikow produkcyjnych.
- MVP/produkcja z AI wymaga backendowego adaptera AI albo jawnej decyzji architektonicznej.

## Forgejo i lokalne CI

Dla zadan dotykajacych kodu w repo pilnuj decyzji `CI target`.

- Lokalne Forgejo jest warsztatem i jedynym CI agentow (repo, branche, PR, review).
- GitHub to wylacznie produkcja (`main` po promocji Boardu, Lovable, wdrozenie bazy). Agenci nie maja do niego dostepu.
- Forgejo CI powinno uruchamiac lint, typecheck, testy, build i/lub Playwright zgodnie z projektem.
- Wynik Forgejo CI powinien byc wskazany jako dowod dla QA, review i Pakietu odbioru.
- Nie wpisuj hasel, tokenow ani sekretow Forgejo do zlecenia, dokumentacji ani promptow.
- Jesli lokalne CI nie dotyczy albo ma zostac pominiete, wpisz powod.

## Obsidian

Dla zadan autonomicznych wskaz:

- folder Obsidian projektu albo `do utworzenia`,
- dokumenty do aktualizacji: ADR, dokumentacja funkcji, runbook, QA report, release notes, handoff,
- jakie linki do dowodow maja trafic do Obsidian.

Obsidian jest zrodlem dokumentacji i decyzji. Agenci, ktorzy go aktualizuja
(Intake Lead, Dokumentalista), musza miec katalog vaulta w swoim workspace.

## Superpowers selektywnie

Dla zadan technicznych wskaz, czy Intake Lead powinien wymagac wybranych metod Superpowers:

- `superpowers-writing-plans` dla zadan wieloetapowych, ryzykownych albo dotykajacych architektury.
- `superpowers-test-driven-development` dla funkcji, bugfixow, refaktorow i zmian zachowania, jesli da sie je sensownie pokryc testem.
- `superpowers-systematic-debugging` dla bledow, awarii CI, regresji i problemow integracyjnych.
- `superpowers-verification-before-completion` dla kazdego zadania, w ktorym agent ma oznaczyc prace jako done.
- `superpowers-requesting-code-review` i `superpowers-receiving-code-review` dla PR, diffow i poprawek po review.
- `superpowers-finishing-a-development-branch` dla prac konczacych sie branchem/PR/release candidate.

Nie wpisuj jako domyslnego wymagania `subagent-driven-development`, `dispatching-parallel-agents`, `brainstorming` ani globalnego `using-superpowers`. Podzial pracy nalezy do Intake Lead.

## Output

Odpowiedz ma zawierac:

1. Krotka ocene gotowosci zlecenia: `gotowe do New task`, `gotowe z brakami`, albo `wymaga doprecyzowania`.
2. Gotowa tresc zadania dla Paperclip, najlepiej w bloku tekstowym.
3. Liste brakow i pytan, jezeli istnieja.
4. Rekomendowany adresat: zwykle `Intake Lead`.
5. Plan autonomicznego delivery: tryb autonomii, Project Access Card, plan delegacji, bramki, DoD, dowody, decyzje wymagajace wlasciciela lub Boardu i scenariusze odbioru etapu.

Nie tworz zadania w Paperclip automatycznie, chyba ze uzytkownik wyraznie poleci: "utworz zadanie", "dodaj do Paperclip", "zlec to organizacji".
