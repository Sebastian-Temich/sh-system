# Struktura Obsidian dla projektu aplikacji

Domyslna sciezka:

```text
/Users/sebastiant./Documents/Obsidian Vault/ISKT Software House/Projekty/<Nazwa projektu>/
```

Nowe projekty tworzone dla `ISKT Software House` musza pozostac wewnatrz folderu organizacji:

```text
/Users/sebastiant./Documents/Obsidian Vault/ISKT Software House/Projekty/
```

Nie tworz ich w globalnym katalogu:

```text
/Users/sebastiant./Documents/Obsidian Vault/Projekty/
```

## Nowy projekt

```text
00_Brief/
  Brief produktowy.md
  Problem i cel.md
  Grupy uzytkownikow.md
  Zakres MVP.md
  Poza zakresem.md

01_Wymagania/
  Funkcje MVP.md
  Role i uprawnienia.md
  Procesy uzytkownikow.md
  Model domenowy.md
  Wymagania niefunkcjonalne.md

02_Design/
  Materialy wejsciowe.md
  Wzorce i inspiracje.md
  Ekrany i flow.md

03_Decyzje/
  Rejestr decyzji produktowych.md
  Otwarte pytania.md

04_Ryzyka/
  Ryzyka produktowe.md
  RODO i dane osobowe.md
  AI Act.md
  Bezpieczenstwo.md

05_Backlog/
  Epiki MVP.md
  Funkcje po MVP.md
  Proponowane etapy realizacji.md
  Roadmapa realizacji.md
  Etapy/
    E00 - Fundamenty.md
    E01 - <Nazwa etapu>.md

06_Delivery/
  Checklist gotowosci projektu.md
  Input dla Software House.md
  Project Access Card.md
  Handoff do Intake Lead.md
  Stan realizacji projektu.md
  Rejestr decyzji i zmian zakresu.md

07_Techniczne/
  ADR-0 - Stack i hosting.md
  Architektura.md
  Supabase.md
  API.md
  Testy.md
  Release.md
```

## Istniejacy projekt

Nie duplikuj calej struktury. Dopisz nowy dokument funkcji albo aktualizuj istniejace pliki.

Rekomendowany format dokumentu funkcji:

```text
01_Wymagania/Funkcja - <nazwa>.md
```

Jesli funkcja ma znaczny wplyw na delivery, dodaj:

```text
06_Delivery/Handoff - <nazwa funkcji>.md
```

## Materialy wizualne

Screenshoty, makiety, eksporty i obrazy trzymaj w:

```text
02_Design/assets/
```

W dokumentach linkuj je wzglednie z Obsidiana. Nie zapisuj tam sekretow ani danych osobowych z produkcji.

## Lokalny folder projektu

Obsidian ma przechowywac sciezke i indeks, ale nie musi przechowywac wszystkich ciezkich plikow.

Rekomendowana struktura folderu roboczego na dysku:

```text
/Users/sebastiant./Projects/<Nazwa projektu>/
  00_inbox/
  01_materialy/
  02_design/
  03_repo/
  04_exports/
  05_tests/
  06_handoff/
```

Sciezki do tych folderow zapisz w:

```text
06_Delivery/Project Access Card.md
06_Delivery/Checklist gotowosci projektu.md
```

Nie zakladaj folderu roboczego bez jawnego polecenia uzytkownika. Jesli sciezki brakuje, zapytaj o nia i po odpowiedzi zaktualizuj Obsidian.
