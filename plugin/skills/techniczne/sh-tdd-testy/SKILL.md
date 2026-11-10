---
name: sh-tdd-testy
description: Skill techniczny bazowy. Test przed kodem dla każdego kryterium issue, testy jednostkowe uruchamiane lokalnie, E2E pisane lokalnie i uruchamiane w CI, nazwy testów zgodne z tym, co sprawdzają, bez skip i only. Użyj, gdy piszesz kod zadania, poprawiasz błąd albo zgłoszenie z review i gdy dobierasz rodzaj testu do kryterium.
---

# TDD i testy

## Zakres

Warstwa bazowa: każdy worker. Dla każdego kryterium najpierw test, który pada, potem kod, który go
naprawia. Rodzaj testu dobierasz do kryterium, nie do wygody uruchomienia w sandboxie. Konwencje
testów projektu (`AGENTS.md`, „Stack (kontrakt)”) mają pierwszeństwo.

## Lista kontrolna

1. 🔴 Każde kryterium issue ma test, który pada bez zmiany i przechodzi z nią.
2. 🔴 Test wchodzi od punktu wejścia z kryterium (trasa, nawigacja, eksport), nie od wewnętrznej
   funkcji, gdy kryterium mówi o zachowaniu dla użytkownika.
3. 🔴 Brak `test.skip`, `test.only`, `describe.only`, `it.todo` w miejscu kryterium. `test.fail` tylko
   dla znanego błędu z issue i z odnośnikiem do niego.
4. 🟡 Nazwa testu mówi, co sprawdza („formularz bez atrybutu action”), nie co zakłada („bez wysyłki”).
5. 🟡 Przypadki brzegowe z karty funkcji (`W-NN`): puste, za długie, błąd sieci, podwójne kliknięcie.
6. 🟡 E2E w chromium i webkit, bez stałych `waitForTimeout`; czekasz na stan (`toBeVisible`, `waitForURL`).
7. 🟡 Test regresji dla każdego naprawionego błędu, z numerem issue w nazwie albo komentarzu.
8. ⚪ Dane testowe bez prawdziwych adresów e-mail, nazw klientów i kluczy.

## Weryfikacja: lokalnie i w CI

- Lokalnie (sandbox): testy jednostkowe `pnpm test` i pojedynczy plik `pnpm test src/x.test.ts`;
  każda komenda w osobnym wywołaniu.
- E2E piszesz i sprawdzasz typami (`pnpm typecheck`), uruchamia je CI (job `e2e` na PR). Przeglądarki
  w sandboxie nie startują, więc „zielone lokalnie” dla E2E nie istnieje.
- Czerwony E2E: `gh pr checks PR`, potem `gh run view RUN --log-failed`; poprawka, push, kolejny run.
- Gdy zachowanie zależy od serwera, którego lokalnie nie ma (nagłówki Vercel, funkcja serverless),
  test w E2E odtwarza je jawnie (np. `page.route` z nagłówkiem z `vercel.json`) i opisuje to w nazwie.

## Przykłady

Cykl dla kryterium „POST /api/contact z pustym polem e-mail zwraca 400 z `fields.email`”:

1. Test jednostkowy endpointu z mockiem mailera: oczekuje 400 i `fields.email`; `pnpm test` pada.
2. Walidacja w endpoincie; `pnpm test` zielone.
3. E2E: wysłanie pustego formularza pokazuje komunikat przy polu; uruchomi CI.

Nazwa testu: `kontakt: pusty e-mail daje 400 z błędem pola` zamiast `walidacja działa`.

## Błędy z naszych projektów

- **iskt-www T-6, test omijający `/404`.** Kryterium dotyczyło `/404`, ale `astro preview` przy
  `trailingSlash: 'always'` odrzucał adres bez ukośnika, więc test przeszedł na
  `/nie-ma-takiej-strony/`. Review: 🔴. Poprawka: test na `/404/` (kanoniczny adres) i osobny test
  przekierowania `/404` → `/404/`. Wniosek: punkt 2; gdy narzędzie blokuje adres z kryterium, testujesz
  postać kanoniczną i zapisujesz decyzję, a nie inny adres.
- **iskt-www T-8 i T-45, statyczny formularz.** Formularz w M1 był „statyczny” (bez `action`), a test
  nazywał się „bez wysyłki”, choć sprawdzał tylko brak atrybutu; przycisk `submit` bez `action`
  wysłałby GET na `/` z danymi w URL. Wniosek: punkt 4 i test, że submit nie wysyła danych.
- **iskt-www QA M1, brak CSP.** Test QA-M1-2 z `test.fail` utrwalił znany brak nagłówka CSP i
  wskazywał issue #23; po poprawce `test.fail` zniknął. Wniosek: `test.fail` tylko z issue (punkt 3).
