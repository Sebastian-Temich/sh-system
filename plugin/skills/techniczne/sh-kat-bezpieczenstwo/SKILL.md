---
name: sh-kat-bezpieczenstwo
description: Skill techniczny kategorii bezpieczeństwo. Lista kontrolna nagłówków (CSP bez unsafe-inline i unsafe-eval, frame-ancestors, Referrer-Policy), walidacji na granicy zaufania, endpointów (metoda, Origin, typ, rozmiar, rate limit), danych osobowych w URL i logach, sekretów i zależności. Użyj, gdy zadanie ma kategorię bezpieczenstwo albo dotyka nagłówków, formularzy z danymi osobowymi, endpointów, auth lub sekretów, i w review takiego PR.
---

# Kategoria bezpieczeństwo

## Zakres

Zadania z `kategoria: bezpieczenstwo` i fragmenty innych zadań dotykające granicy zaufania. PR tej
kategorii idzie do review na poziomie `ryzyko`. Wymagania bezpieczeństwa z architektury
(`docs/04-plan/plan.md`, „Bezpieczeństwo”) są minimum; skill ich nie osłabia. RLS i migracje:
`sh-kat-baza`.

## Lista kontrolna

1. 🔴 Każdy nagłówek bezpieczeństwa z architektury jest na wdrożeniu (CSP, `X-Content-Type-Options`,
   `Referrer-Policy`, `Permissions-Policy`, `frame-ancestors`) i ma test.
2. 🔴 CSP bez `'unsafe-inline'` i `'unsafe-eval'`; bez hashy, które zmieniają się z każdym buildem.
   Biblioteka wymagająca `eval` dostaje tryb bez JIT albo zamiennik, nie wyjątek w CSP.
3. 🔴 Walidacja wejścia po stronie serwera (schemat, długość, typ), niezależnie od walidacji w
   przeglądarce.
4. 🔴 Dane osobowe nie trafiają do URL (GET z formularza), logów, komunikatów błędów ani analityki.
5. 🔴 Brak sekretów w kodzie, testach, fixture'ach, raporcie i PR; nowe zmienne tylko w `.env.example`
   bez wartości; klucz po stronie przeglądarki tylko publiczny (`PUBLIC_`).
6. 🟡 Endpoint: tylko dozwolone metody (405), sprawdzenie `Origin`, `Content-Type` (415), limit
   rozmiaru (413), rate limit (429), timeout usług zewnętrznych, honeypot przy formularzu publicznym.
7. 🟡 Błędy dla klienta bez szczegółów wewnętrznych (stack, nazwy usług, treść odpowiedzi dostawcy).
8. 🟡 Nowa zależność: znana, utrzymywana, w lockfile; bez skryptów instalacyjnych bez potrzeby.
9. ⚪ `rel="noopener noreferrer"` przy `target="_blank"`; `autocomplete` zgodne z polem.

## Weryfikacja: lokalnie i w CI

- Lokalnie: `pnpm lint`, `pnpm typecheck`, `pnpm test` (testy endpointu z mockiem usług: każdy kod
  odpowiedzi), `pnpm build`, `gitleaks git --redact --no-banner .`; każde w osobnym wywołaniu.
- Nagłówki z `vercel.json` nie działają w `astro preview`: test E2E dokleja nagłówek przez
  `page.route` i słucha `securitypolicyviolation`; uruchamia go CI (`gh run view RUN --log-failed`).
- Nagłówki na wdrożeniu (`curl -sI` stagingu) sprawdza QA albo orkiestrator po merge'u; worker
  wpisuje to w raporcie jako „do sprawdzenia na stagingu”.

## Przykłady

CSP dla strony statycznej z jednym endpointem (`vercel.json`):

```json
{ "key": "Content-Security-Policy",
  "value": "default-src 'self'; img-src 'self' data:; font-src 'self'; style-src 'self'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none'" }
```

Test E2E: `page.route('**/*', …)` dodaje nagłówek z `vercel.json`, `page.on('console')` i
nasłuch `securitypolicyviolation` zbierają naruszenia; oczekiwane 0 na każdej stronie.

## Błędy z naszych projektów

- **iskt-www QA M1 (#23), brak CSP.** Architektura wymagała CSP, ale M1 wyszedł bez nagłówka; wykrył
  to dopiero QA na stagingu (`curl -sI`). Wniosek: punkt 1 w zadaniu szkieletu, z testem od początku.
- **iskt-www #23 (PR #24), CSP z hashami.** Hashe stylów inline w `vercel.json` różniły się między
  buildem lokalnym, CI i Vercel. Poprawka: CSS w plikach, `style-src 'self'`; walidacja Zod w trybie
  `jitless`, żeby nie dodawać `'unsafe-eval'`. Wniosek: punkt 2.
- **iskt-www T-8, statyczny formularz.** Formularz bez `action` z przyciskiem `submit` wysłałby
  imię, e-mail i wiadomość GET-em w URL. Wniosek: punkt 4.
