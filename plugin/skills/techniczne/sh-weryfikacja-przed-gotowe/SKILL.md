---
name: sh-weryfikacja-przed-gotowe
description: Skill techniczny bazowy. Dowody przed słowem „gotowe” - każde kryterium issue sprawdzone komendą albo testem, lint, typy, testy jednostkowe i build lokalnie po scaleniu z main, E2E i Lighthouse w CI odczytane z logów. Użyj, gdy kończysz zadanie, zanim napiszesz raport, otworzysz PR albo odpowiesz „zrobione”, oraz po merge'u origin/main do gałęzi zadania.
---

# Weryfikacja przed „gotowe”

## Zakres

Warstwa bazowa: każdy worker, każde zadanie. Stwierdzenie „działa”, „zielone”, „spełnione” w
raporcie albo PR pada dopiero po komendzie, której wynik to potwierdza. Bez wyniku piszesz
„niesprawdzone” i powód. Reguły projektu (`AGENTS.md`, `.claude/skills`) mają pierwszeństwo.

## Lista kontrolna

1. 🔴 Każde kryterium z issue ma dowód: nazwę testu albo komendę z wynikiem w raporcie `T-NR.md`.
2. 🔴 Test sprawdza dokładnie to, co mówi kryterium: ten sam adres, ten sam element, ta sama
   wartość progu. Zamiennik (inny URL, inny selektor, luźniejszy próg) to kryterium niespełnione.
3. 🔴 Po `git merge origin/main` lint, typy, testy jednostkowe i build uruchomione ponownie;
   konflikt w pliku konfiguracji rozwiązany semantycznie, nie przez zostawienie obu wersji.
4. 🟡 Lokalnie zielone: lint, typy, testy jednostkowe, build (komendy z „Stack (kontrakt)”).
5. 🟡 E2E i Lighthouse: wynik z CI (job i numer runu), nie z założenia. Czerwony job przeczytany
   przez `gh run view RUN --log-failed` i opisany w raporcie.
6. 🟡 Raport nie twierdzi niczego, czego nie widać w diffie albo w wyniku komendy (np. „bez
   zmian w X”, gdy X jest w diffie).
7. ⚪ Wynik pomiaru (Lighthouse, rozmiar paczki) podany z wersją narzędzia, profilem i liczbą przebiegów.

## Weryfikacja: lokalnie i w CI

Sesja działa w sandboxie: przeglądarki nie startują, porty lokalne są zablokowane, sieć tylko przez
proxy. Jedna prosta komenda na wywołanie, bez `&&`, `;`, potoków i przekierowań do pliku.

| Gdzie | Co | Jak |
|---|---|---|
| Lokalnie | lint | `pnpm lint` |
| Lokalnie | typy | `pnpm typecheck` |
| Lokalnie | testy jednostkowe | `pnpm test` |
| Lokalnie | build | `pnpm build` |
| CI | E2E (chromium, webkit) | job `e2e` na PR |
| CI / staging | Lighthouse | job `qa-staging` u QA albo pomiar orkiestratora po merge'u |

Odczyt CI, każde w osobnym wywołaniu:

```sh
gh pr checks PR
gh run list --branch task/NR-slug --limit 3 --json databaseId,name,conclusion
gh run view RUN --log-failed
```

Wynik zawężasz flagą (`--json`, `-q`), nie potokiem.

## Przykłady

Dobrze (raport):

```text
- W-09/K1 „/404 w layoucie”: e2e/layout.spec.ts „/404 to strona 404.astro w layoucie”, CI e2e run 123 zielony.
- Po merge'u origin/main: pnpm lint, pnpm typecheck, pnpm test (128), pnpm build zielone.
- Lighthouse: niesprawdzone lokalnie (sandbox); pomiar na stagingu po merge'u (QA).
```

Źle: „Wszystkie testy przechodzą” bez nazwy komendy; „Lighthouse ≥ 90” bez przebiegu.

## Błędy z naszych projektów

- **iskt-www #29 (PR #30), zdublowany klucz `build`.** #22 dodało `build.inlineStylesheets:
  'always'`, #23 `'never'`; po obu merge'ach `astro.config.mjs` miał dwa klucze `build`. Lint
  (`no-dupe-keys`), typy (TS1117) i E2E czerwone na main. Wniosek: po scaleniu z main ponów lint i
  typy przed pushem (punkt 3).
- **iskt-www T-6, test omijający `/404`.** Kryterium mówiło o `/404`, test otwierał
  `/nie-ma-takiej-strony/`, raport pisał „spełnione”. Review: 🔴. Wniosek: punkt 2.
- **iskt-www QA M1 (#22), Lighthouse 87–89.** Wydajność mobile mierzona dopiero na stagingu dała
  87/89/89 przy progu 90. Wniosek: nie piszesz „W-10 spełnione” bez pomiaru; wpisujesz
  „niesprawdzone, pomiar w QA” (punkt 5).
