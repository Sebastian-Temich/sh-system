# Szablony dokumentow

## Brief produktowy

```markdown
# Brief produktowy

## Cel

## Dla kogo

## Problem

## Proponowane rozwiazanie

## Zakres MVP

## Poza zakresem

## Mierniki sukcesu

## Wstepna rekomendacja technologiczna

## Proponowane etapy realizacji

## Ograniczenia

## Decyzje wymagane od wlasciciela lub Boardu
```

## Funkcja MVP

```markdown
# Funkcja - <nazwa>

## Cel uzytkownika

## Uzytkownicy i role

## Przeplyw

## Kryteria akceptacji

## Dane

## Ryzyka

## Poza zakresem

## Input dla Software House
```

## ADR-0 - Stack i hosting

```markdown
# ADR-0 - Stack i hosting

## Status
Szkic / Do decyzji / Zaakceptowane

## Kontekst produktowy

## Wymagania techniczne

## Warianty

| Wariant | Stack | Kiedy ma sens | Ryzyka / koszt | Ocena |
| --- | --- | --- | --- | --- |
| A |  |  |  |  |
| B |  |  |  |  |
| C |  |  |  |  |

## Rekomendacja

To jest rekomendacja robocza. Finalna decyzja wymaga akceptacji wlasciciela lub Boardu oraz Architekta/Intake Lead.

## Konsekwencje

## Decyzje wymagane od wlasciciela lub Boardu
```

## Proponowane etapy realizacji

```markdown
# Proponowane etapy realizacji

Ten dokument jest robocza propozycja dla Intake Lead. Nie jest finalnym boardem zadan.

| Etap | Cel | Zakres | Zaleznosci | Ryzyka | Kryterium zakonczenia |
| --- | --- | --- | --- | --- | --- |
| Etap 0 - przygotowanie |  |  |  |  |  |
| Etap 1 - fundamenty |  |  |  |  |  |
| Etap 2 - core flow MVP |  |  |  |  |  |
| Etap 3 - jakosc i bezpieczenstwo |  |  |  |  |  |
| Etap 4 - handoff/release |  |  |  |  |  |

## Decyzje wymagane przed startem

## Co moze rozstrzygnac Intake Lead
```

## Input dla Software House

```markdown
# Input dla Software House

## Produkt

## Cel techniczny

## Zakres do zbudowania

## Materialy wejściowe

## Folder Obsidian

## Repo / Lovable / Supabase / hosting

## Wstepna rekomendacja technologiczna

## Proponowane etapy realizacji

## Checklista ryzyk

## Kryteria akceptacji

## Pytania otwarte

## Rekomendowany nastepny skill
`tworca-wymagan`
```

## Checklist gotowosci projektu

```markdown
# Checklist gotowosci projektu

Ta checklista jest jedynym zrodlem prawdy o gotowosci startowej projektu.
Planista realizacji moze ja walidowac, ale nie tworzy jej kopii.

## Status
Gotowe / Gotowe z brakami / Zablokowane / Discovery

## Sciezki

| Element | Status | Sciezka / decyzja | Uwagi |
| --- | --- | --- | --- |
| Folder Obsidian projektu | do ustalenia |  |  |
| Lokalny folder projektu | do ustalenia |  |  |
| Folder materialow | do ustalenia |  |  |
| Folder designu | do ustalenia |  |  |
| Folder repo | do ustalenia |  |  |
| Remote git / Forgejo / GitHub | do ustalenia |  |  |
| Workspace Paperclip | do ustalenia |  |  |
| Srodowiska: Supabase lokalny / produkcja Lovable + Supabase Cloud | do ustalenia |  |  |
| CI target i komendy jakosci | do ustalenia |  |  |

## Materialy i ustalenia

| Element | Status | Uwagi |
| --- | --- | --- |
| Opis produktu | do ustalenia |  |
| Cel biznesowy | do ustalenia |  |
| Uzytkownicy i role | do ustalenia |  |
| Zakres MVP | do ustalenia |  |
| Funkcje podstawowe | do ustalenia |  |
| Kryteria akceptacji | do ustalenia |  |
| Materialy wejsciowe | do ustalenia |  |
| ZIP-y zindeksowane | nie dotyczy |  |
| ADR-0 / technologia | do ustalenia |  |
| Checklista ryzyk | do ustalenia |  |
| Project Access Card | do ustalenia |  |
| Wlasciciel produktu i odbioru | do ustalenia |  |
| Klasyfikacja danych / retencja | do ustalenia |  |
| Monitoring, rollback i utrzymanie | do ustalenia |  |

## Braki blokujace

## Pytania do wlasciciela lub Boardu

## Checklista dla wlasciciela lub Boardu - otwarte dzialania

| Co trzeba zrobic | Status | Wlasciciel | Wartosc / dowod do wpisania |
| --- | --- | --- | --- |
| Utworzyc lub wskazac lokalny folder projektu | do wykonania | wlasciciel lub Board | pelna sciezka |
| Wlozyc materialy zrodlowe i design | do wykonania | wlasciciel lub Board | sciezka folderu |
| Utworzyc lub wskazac repo i remote | do wykonania | wlasciciel lub Board | URL repo |
| Dodac workspace Paperclip | do wykonania | wlasciciel lub Board | nazwa workspace |
| Ustalic CI target | do ustalenia | wlasciciel lub Board | Forgejo / GitHub / oba |
| Zalozyc projekt Supabase produkcji i Lovable, ustalic wlasciciela odbioru | do ustalenia | wlasciciel lub Board | decyzja / link |
```

## Project Access Card

```markdown
# Project Access Card

## Lokalny folder projektu

Sciezka:
`do ustalenia`

## Folder synchronizacji git / repo

Sciezka:
`do ustalenia`

Remote:
`do ustalenia`

Domyslny branch:
`do ustalenia`

Zasada branch / worktree:
`do ustalenia`

Workspace Paperclip:
`do ustalenia`

CI target i komendy jakosci:
`do ustalenia`

## Materialy zrodlowe

Sciezka:
`do ustalenia`

## Design / ZIP / screenshoty

Sciezka:
`do ustalenia`

## Obsidian

Sciezka:
`do ustalenia`

## Paperclip

Organizacja:
`Softwarehouse`

Adresat:
`Intake Lead`

## Srodowiska i delivery

Local:
`do ustalenia`

Podglad etapow:
`lokalnie - scripts/podglad.sh`

Production:
`wymaga wlasciciela lub Boardu`

Tryb wykonania:
`claude_code_local (adapter Paperclip)`

Wlasciciel produktu i odbioru:
`do ustalenia`

## Uwagi bezpieczeństwa

- Nie wpisywac sekretow do dokumentacji.
- ZIP-y najpierw indeksowac.
- Nie uruchamiac skryptow z materialow bez zgody wlasciciela lub Boardu.
```
