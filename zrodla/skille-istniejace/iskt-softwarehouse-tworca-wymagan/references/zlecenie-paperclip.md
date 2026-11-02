# Format zlecenia do Paperclip — delivery 2.0

Dobierz dlugosc do klasy. Pomin nieistotne pola; nie generuj pustych milestone'ow. Adresat: Koordynator Techniczny / Intake Lead. Plan skilla jest propozycja; finalne taski i zaleznosci tworzy Intake.

## S — krotkie zlecenie

```text
Produkt / projekt:
Cel i zakres / poza zakresem:
Klasa: S — uzasadnienie:
Flagi ryzyka i wymagane bramki (niezależne od rozmiaru S/M/L):
Autonomia: allowed / limited / not allowed — co wymaga ISKT:
Repo/branch lub dokument; istniejaca Project Access Card:
Materialy:
Kryteria akceptacji i DoD:
Wykonawca:
Niezalezna weryfikacja: Code Reviewer albo QA smoke; dowod:
Kontrole/CI adekwatne do zmiany:
Dokumentacja / screenshoty / handoff: tak / nie z powodem:
Raport: Intake — wynik, dowod, blokery i decyzje.
```

## M/L — zlecenie z planem

```text
Zlecenie dla ISKT Software House / Intake Lead

1. Produkt, organizacja zlecajaca, priorytet i cel
ID etapu i dokument Obsidian (jedno zlecenie = jeden etap):
Roadmapa / stan projektu / gotowosc startu etapu:
Oczekiwany wynik:
Zakres i poza zakresem:
Kryteria akceptacji:

2. Routing
Klasa: M / L
Uzasadnienie i flagi ryzyka:
Autonomia: allowed / limited / not allowed
Dozwolone dzialania:
Nazwane decyzje ISKT i wstrzymane dzialania:
Warunki podniesienia klasy:

3. Materialy i decyzje
Brief, design, ZIP/indeks, dokumenty:
Wstepna rekomendacja technologiczna i warianty:
Status stacku: roboczy / do ADR-0 / zatwierdzony
ADR / decyzje do uzupelnienia:
Etapy produktowe z briefu i proponowane milestone'y:

4. Project Access Card (lub link do aktualnej)
Lokalny folder projektu / repo:
Repo URL / branch / commit:
CI target i zweryfikowana dostepnosc runnera:
Srodowiska / Supabase staging / zasady produkcji:
Hosting / Lovable jesli dotyczy:
Obsidian folder:
Airtable tylko gdy wymagany raport:
Dozwolone MCP i zakazane akcje:
Sekrety: tylko nazwy, bez wartosci

5. Ryzyka — tak / nie / do ustalenia
Auth / RLS i role / PII / AI i automatyczne decyzje:
Platnosci / upload / integracje / migracje / kontrakt API:
Sekrety / nowy MCP / produkcja / koszty:
Istotna zmiana UI/flow/dostepnosci / infrastruktura i CI:

6. Plan czterech faz (tylko potrzebne taski)
| Task / faza | Wlasciciel | Poprzednicy | Warunek startu | DoD | Dowody / bramki |
|---|---|---|---|---|---|

Intake tworzy finalne dzieci i zaleznosci Paperclip, sprawdza brak cykli i duplikatow.
Frontend i backend moga isc rownolegle po kontrakcie. Wspolne zapisy wymagaja izolacji.

7. Weryfikacja i dokumentacja
QA i Code Reviewer dla M/L z kodem:
Security / Compliance / FinOps / UX / DevOps-SRE — wyzwalacz i zakres:
Kontrole: testy / lint / typecheck / build / skany / CI:
Dokumentacja produktowa / techniczna / screenshoty / handoff — tak/nie z powodem:
Dokumenty repo/Obsidian i wlasciciel aktualizacji:

8. Raport i odbior
Aktualizacja roadmapy, dokumentu etapu i Stan realizacji projektu.md:
Nastepny krok, wlasciciel i ewentualna decyzja ISKT:
Wlasciciel raportu: Intake / Delivery Controller (uzasadnij osobnego kontrolera)
Task / agent / status / zaleznosci / DoD / dowod / blocker z wlascicielem:
Brakujace bramki i decyzje ISKT:
Rekomendacja: gotowe / wymaga poprawek / zablokowane
Produkcja: oddzielna zgoda ISKT; gotowy PR nie oznacza wdrozenia.

9. Braki i pytania
Tylko blokujace decyzje zatrzymuja zalezne dzialania.
```

Nie przypisuj nowej pracy do zastapionych kont Dokumentalista Produktowy i Operator Wydan / Handoff. Dokumentacja / Knowledge Manager laczy docs produktowe/techniczne; DevOps / SRE Engineer obejmuje wydania i utrzymanie. Delivery Controller i Lovable sa warunkowi.

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
