# Analiza projektu: NAZWA

Repo: OWNER/REPO · Analiza: RRRR-MM-DDTHH:MMZ – RRRR-MM-DDTHH:MMZ (UTC) · Limit: N min

# Dla właściciela

## Stan w jednym akapicie

(Czym jest aplikacja, dla kogo, w jakim jest stanie i co z tego wynika. Prosty język, bez nazw
plików i kodów.)

## Co działa

- (funkcja i dowód: test, ręczne sprawdzenie, wdrożona wersja)

## Czego brakuje

- (brakujące funkcje, testy, dokumentacja, kopie zapasowe)

## Ryzyka

| Ryzyko | Waga | Co proponujemy |
|---|---|---|
| (np. klucz administratora bazy w repo) | 🔴 | (np. unieważnić klucz w panelu dostawcy, nowy tylko w zmiennych środowiska) |

## Pytania do Ciebie

Odpowiedz numerem albo „zdecyduj sam” (wtedy obowiązuje propozycja).

1. (pytanie) Propozycja: (odpowiedź). Skutek: (jedno zdanie).

## Proponowany pierwszy kamień milowy

(Cel, zakres w punktach, czego nie obejmuje, szacunek poglądowy.)

## Decyzja

Napisz orkiestratorowi „akceptuję analizę i kierunek” albo co zmienić. Do akceptacji nic w kodzie
aplikacji się nie zmienia, a repo zostaje w obecnej widoczności.

# Dla wykonawcy

## Stack i zależności

| Pakiet | Wersja | Najnowsza | Stan |
|---|---|---|---|
| (react) | (18.2.0) | (19.x) | przestarzały / podatny (CVE, źródło) / aktualny |

Menedżer pakietów, wersja Node, skrypty `package.json`.

## Architektura obecna

(Moduły, punkty wejścia, routing, przepływ danych, gdzie żyje logika biznesowa.)

## Mapa funkcji

| Karta | Funkcja | Punkt wejścia | Testy | Stan |
|---|---|---|---|---|
| [F-01](funkcje/F-01.md) | (logowanie) | (`/login`) | (brak) | działa / częściowo / nie działa |

## Testy i CI

Stan wyjściowy (`main` z dnia analizy): komendy, wynik, ostatni bieg CI. Ta lista jest kontraktem
„testy zielone w stanie wyjściowym zostają zielone”.

## Wdrożenie

(Hosting, sposób wdrożenia, środowiska, kto ma dostęp. Agenci nie mają dostępu do produkcji.)

## Integracje

(Usługi zewnętrzne, webhooki, e-mail, płatności.)

## Zmienne środowiskowe

Tylko nazwy, bez wartości: (z `wykryj.sh`, pole `zmienne`).

## Lovable i Supabase

- Lovable: (pliki, synchronizacja z GitHubem: aktywna, ostatni commit z Lovable)
- Klient Supabase: (plik, klucz w kodzie czy w env, rola klucza)
- Katalog `supabase/`: migracje (liczba, pierwsza, ostatnia), edge functions, seed
- RLS (`sh-kat-baza`): tabela → polityki, zgłoszenia z wagą
- Schemat w chmurze: (pytanie o zrzut `supabase db dump --schema-only` od właściciela albo wynik
  porównania; przy rozjeździe migracja wyrównująca i zasada: źródłem prawdy są migracje w repo)

## Dług techniczny

| Obszar | Problem | Waga | Propozycja |
|---|---|---|---|

## Nie przeanalizowano

(Tylko gdy skończył się limit czasu: co zostało i dlaczego.)
