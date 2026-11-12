---
name: sh-kat-refaktoryzacja
description: Skill techniczny kategorii refaktoryzacja. Lista kontrolna zmian struktury kodu bez zmiany zachowania - najpierw testy obecnego zachowania (charakteryzujące), potem małe kroki z zielonymi testami po każdym, zakaz zmiany zachowania bez karty funkcji z sekcją było → ma być, bez mieszania refaktoryzacji z nową funkcją. Użyj, gdy zadanie ma kategorię refaktoryzacja, porządkuje, wydziela, przenosi albo upraszcza kod (cleanup, higiena, dług techniczny), i w review takiego PR.
---

# Kategoria refaktoryzacja

## Zakres

Zadania z `kategoria: refaktoryzacja`: zmiana struktury kodu (wydzielenie, przeniesienie, zmiana
nazw, usunięcie duplikacji, aktualizacja wzorca), po której użytkownik, API i baza zachowują się tak
samo. Testy i TDD w ogóle: `sh-tdd-testy`; ten skill dodaje reguły „zachowanie bez zmian”. Zmiana
schematu bazy w refaktoryzacji to nadal migracja expand/contract z `sh-kat-baza`.

## Lista kontrolna

1. 🔴 Zanim zmienisz kod, zachowanie obszaru jest pokryte testami, które przechodzą na kodzie sprzed
   zmiany (testy charakteryzujące: wejście → obecne wyjście, także błędy i przypadki brzegowe). Brak
   testów obszaru to pierwszy commit zadania, osobno od zmian.
2. 🔴 Zachowanie się nie zmienia: te same odpowiedzi, kody, komunikaty, adresy, stany ekranu, dane w
   bazie. Zmiana zachowania tylko wtedy, gdy issue wskazuje kartę funkcji
   (`docs/00-intake/funkcje/W-NN.md`) z sekcją „było → ma być”; bez niej to pytanie
   (`shctl escalate --typ pytanie`), a nie decyzja workera.
3. 🔴 Testy charakteryzujące nie są zmieniane razem z kodem tak, żeby przeszły: zmiana asercji to
   zmiana zachowania (punkt 2). Wolno zmienić tylko sposób dojścia (np. import po przeniesieniu pliku).
4. 🟡 Małe kroki: każdy commit to jedna transformacja (przeniesienie, zmiana nazwy, wydzielenie) z
   zielonym `pnpm test` i `pnpm typecheck`; bez commita „refactor all”, który zmienia kilkadziesiąt
   plików różnymi rodzajami zmian.
5. 🟡 Bez mieszania z nową funkcją i poprawką błędu. Znaleziony błąd zapisujesz w raporcie
   („Drobne uwagi” albo „Propozycje”), a nie poprawiasz po cichu: poprawka zmienia zachowanie.
6. 🟡 Publiczne API (eksporty, endpointy, nazwy tras, nazwy zdarzeń analityki, klucze `localStorage`,
   kolumny bazy) zostaje albo dostaje warstwę zgodności na okres przejściowy.
7. 🟡 Nazwy testów zgodne z tym, co testy faktycznie sprawdzają; test, który obiecuje więcej, niż
   asertuje, poprawiasz w nazwie albo w asercji (wtedy punkt 1: najpierw ma przejść na starym kodzie).
8. ⚪ Usunięty martwy kod jest naprawdę martwy (grep po nazwie, dynamiczne importy, konfiguracja,
   szablony); w raporcie lista usuniętych elementów.
9. ⚪ Diff czytelny dla review: przeniesienie pliku osobnym commitem (`git mv`), bez zmian formatowania
   poza obszarem zadania.

## Weryfikacja: lokalnie i w CI

- Lokalnie przed zmianą: `pnpm test` na kodzie sprzed zmiany z nowymi testami charakteryzującymi
  (zielone), potem po każdym kroku `pnpm test` i `pnpm typecheck`, na końcu `pnpm lint` i
  `pnpm build`; każde w osobnym wywołaniu.
- Zachowanie widoczne w przeglądarce (stany ekranu, nawigacja, dostępność) pilnuje E2E w CI;
  refaktoryzacja nie zmienia asercji E2E. Czerwony job: `gh pr checks PR`, potem
  `gh run view RUN --log-failed`.
- W raporcie: które testy pilnują zachowania (nowe charakteryzujące i istniejące) i wynik ich
  przebiegu na kodzie przed zmianą.

## Przykłady

Przebieg wydzielenia wspólnej funkcji z trzech komponentów:

1. Commit 1: test charakteryzujący dla każdego z trzech miejsc (obecny wynik, także pusty i błędny
   przypadek); `pnpm test` zielony na starym kodzie.
2. Commit 2: nowa funkcja `formatujKwote` z testem jednostkowym, jeszcze nieużywana.
3. Commity 3–5: po jednym komponencie przełączonym na funkcję, `pnpm test` zielony po każdym.
4. Commit 6: usunięcie starych kopii; raport z listą usuniętych elementów.

Karta funkcji przy zmianie zachowania (`docs/00-intake/funkcje/W-07.md`):

```markdown
### Było → ma być
- Było: kwota bez separatora tysięcy („12500 zł”).
- Ma być: separator spacją niełamliwą („12 500 zł”), test charakteryzujący zmienia się w tym zadaniu.
```

## Błędy z naszych projektów

- **iskt-www T-45 (PR #48), wspólna klasa `.visually-hidden`.** Trzy lokalne kopie zastąpiono jedną
  klasą bez zmiany wyglądu i nazw dostępnych; dowodem były istniejące E2E (nazwy linków, region
  tabeli, axe), uruchomione bez zmiany asercji. Wniosek: punkty 1 i 3 jako wzorzec.
- **iskt-www T-6 i T-45, nazwa testu obiecywała więcej.** Test „/404 bez ukośnika przekierowuje na
  /404/” nie sprawdzał przekierowania, tylko ustawienie `trailingSlash`; T-45 zmienił nazwę zgodnie z
  asercją. Test z mylącą nazwą daje fałszywe poczucie, że zachowanie jest pilnowane. Wniosek: punkt 7.
- **iskt-www T-45 (PR #48, iteracja 2), zakres porządków.** Port Playwright ze zmiennej wymagał wpisu
  w `.env.example`, czego issue nie przewidziało; review 🟡, zakres rozszerzał orkiestrator. Wniosek:
  punkt 6 (konfiguracja to też publiczne API) i zapis takich skutków w raporcie przed review.
