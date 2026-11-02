# Format zlecenia do Paperclip

Uzyj tego formatu jako bazowego outputu, gdy uzytkownik chce przygotowac zlecenie dla Softwarehouse.

```text
Zlecenie dla Softwarehouse / Intake Lead

1. Dane zlecenia

Organizacja zlecajaca:
Produkt / aplikacja:
Etap realizacji: E0X - <nazwa>; zlecenie nie obejmuje innych etapow
Dokument etapu w Obsidianie:
Klasa pracy: S / M / L
Uzasadnienie klasy:
Kontakt po stronie produktu:
Priorytet: P0 / P1 / P2 / P3
Oczekiwany termin:

2. Cel biznesowy

Problem do rozwiazania:
Dlaczego teraz:
Jak poznamy, ze praca jest zakonczona:

3. Zakres techniczny

Typ pracy:
Opis zakresu:
Poza zakresem:

4. Tryb autonomii

Tryb: allowed / limited / not allowed
Uzasadnienie:

Dozwolone bez wlasciciela lub Boardu:
- tworzenie podzadan:
- przypisanie agentow:
- praca na branchu:
- testy / CI / QA / review:
- aktualizacja Obsidian:
- przygotowanie PR / handoff:

Wymaga wlasciciela lub Boardu:
- produkcyjny deploy:
- dostep do produkcyjnych sekretow:
- nowy MCP lub nowe uprawnienia:
- decyzja prawna / biznesowa / kosztowa:
- P0/P1:
- zmiana standardow:

5. Project Access Card

Repo URL:
Domyslny branch:
Branch roboczy:
Forgejo local repo (warsztat):
CI target: Forgejo local / GitHub / oba / nie dotyczy
Supabase lokalny (dev): tak
Supabase production: brak dostepu / read-only / wymaga wlasciciela lub Boardu
Lovable project:
Hosting:
Obsidian folder:
Dozwolone MCP:
Zakazane akcje:
Sekrety: nie wpisywac w tresci zadan, dokumentacji ani promptow

5a. Kontrakt wykonania terminalowego

Workspace Paperclip:
Lokalna sciezka repo / worktree:
Branch bazowy: main
Branch etapu: stage/E0X
Branche zadan: e0x/<klucz> (worktree ../worktrees/<klucz>)
Runner: claude_code_local (adapter Paperclip)
Srodowisko: lokalny Supabase; produkcja tylko CI po merge Boardu
Dozwolone narzedzia i MCP:
Zakazane akcje:
Komendy jakosci: lint / typecheck / test / build / E2E / nie dotyczy
Merge zadania do stage/E0X: QA po accepted i zielonym CI
Merge stage/E0X -> main: Board przy odbiorze
Release: Board

6. Materialy wejsciowe

Brief produktowy:
Roadmapa realizacji / mapa architektoniczna:
Checklista gotowosci etapu:
Design / makiety:
Materialy zrodlowe:
ZIP / zalaczniki:
Linki referencyjne:
Repozytorium:
Branch / commit startowy:
Forgejo local repo (warsztat):
CI target: Forgejo local / GitHub / oba / nie dotyczy
Lovable project id:
Supabase project id:
Hosting:

7. Decyzje technologiczne

Status rekomendacji: robocza / do zatwierdzenia w ADR-0 / zatwierdzona
Frontend:
Backend:
Baza danych:
Auth:
Storage:
AI:
Platnosci:
Email / powiadomienia:
Analityka:
ADR wymagane:

Warianty technologiczne z briefu:
- Wariant A:
- Wariant B:
- Wariant C:

Rekomendowany wariant:
Uzasadnienie:
Decyzje wymagajace wlasciciela, Architekta lub Intake Leada:

8. Mapa dekompozycji etapu

| Modul / flow | Dane i reguly | Kontrakt API/RPC | UI / integracja | Zaleznosc | Wlasciciel | Dowod |
|---|---|---|---|---|---|---|

9. Checklista ryzyk intake

Auth / logowanie:
RLS / uprawnienia:
Platnosci:
Upload plikow:
Dane osobowe:
AI / automatyczne decyzje:
Integracje zewnetrzne:
Produkcyjny deploy:
Migracje bazy danych:
Zmiana kontraktu API:
Lokalne CI Forgejo / workflow Actions:
Autonomiczne delivery: allowed / limited / not allowed
Plan techniczny / TDD / debug / review / verification:

10. Plan delegacji

| Podzadanie | Wlasciciel / rola | Zaleznosci | DoD | Wymagane dowody | Status startowy |
|---|---|---|---|---|---|
| Intake i plan | Intake Lead | brak | Dokument `plan`, branch stage/E0X | dokument/zadanie | pending |
| <tylko potrzebne podzadanie> | <jedna rola> |  |  |  | pending / blocked / do decyzji |
| E0X-SEC Security review | Security Reviewer | implementacja | raport `security` bez krytycznych/wysokich | raport | tylko gdy wyzwalacz |
| E0X-DOC Dokumentacja | Dokumentalista | implementacja | dokumenty zaktualizowane | lista plikow | pending |
| E0X-QA Weryfikacja etapu | QA | wszystkie powyzej | CI stage zielone, scenariusze przeszly | raport | pending |

11. Kryteria akceptacji

Funkcjonalne:
-

Techniczne:
- kod jest w repo albo zmiana jest opisana jako praca w Lovable
- kontrakt Lovable - Supabase jest aktualny albo oznaczony jako do utworzenia
- brak sekretow w frontendzie, repo, promptach i komentarzach
- testy adekwatne do ryzyka zostaly wykonane
- jesli zadanie dotyczy repo, Forgejo CI przeszlo albo pominiecie zostalo uzasadnione
- dokumentacja/handoff zostaly zaktualizowane
- dowody sa podlinkowane do zadania, etapu i dokumentacji projektu
- typ testu odpowiada ryzyku zgodnie z macierza jakosci projektu

12. Rekomendowane role i bramki

Role:
Bramki:
Security review:
Compliance review:
QA:
Forgejo CI:
Dokumentacja:
DevOps/SRE:
Deploy: tylko gdy wyzwalacz i human gate

13. Pakiet odbioru etapu (skill odbior-etapu)

Scenariusze odbioru dla Boardu:
- 

Pakiet ma zawierac:
- status kazdego podzadania
- wlasciciela
- linki do dowodow
- niespelnione elementy DoD
- decyzje wymagajace wlasciciela lub Boardu
- rekomendacje: gotowe do odbioru / gotowe z wyjatkami / wymaga poprawek / zablokowane

13a. Powiazania i dowody

Etap Obsidian:
Zadania Paperclip:
Branch / worktree:
PR / commit:
Wynik CI:
Raport QA / review:
Dokumentacja / ADR / runbook:

14. Pytania otwarte / braki

- 
```

## Skrocony wariant

Gdy uzytkownik chce szybko utworzyc zadanie i nie ma pelnego kontekstu, uzyj wariantu skroconego:

```text
Zlecenie dla Softwarehouse / Intake Lead

Produkt:
Cel:
Co ma powstac:
Materialy:
Repo/branch:
Forgejo/CI:
Lovable:
Supabase:
Hosting:
Rekomendacja technologiczna:
Etap realizacji i dokument etapu:
Klasa S/M/L:
Tryb autonomii: allowed / limited / not allowed
Dozwolone bez wlasciciela lub Boardu:
Wymaga wlasciciela lub Boardu:
Plan delegacji:
Project Access Card:
Workspace / branch etapu stage/E0X / worktree:
Komendy jakosci:
Merge i release:
Ryzyka: auth / RLS / platnosci / upload / dane osobowe / AI / integracje / deploy / migracje / API
Scenariusze odbioru:
Kryteria akceptacji:
Braki do ustalenia:
```
