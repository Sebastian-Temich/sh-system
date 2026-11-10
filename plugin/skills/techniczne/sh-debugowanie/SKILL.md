---
name: sh-debugowanie
description: Skill techniczny bazowy. Systematyczne szukanie przyczyny błędu - odtworzenie, jedna hipoteza na raz, różnice między środowiskami (lokalnie, CI, Vercel), log CI zamiast zgadywania, poprawka przyczyny z testem regresji. Użyj, gdy test, build albo job CI jest czerwony, wynik różni się między środowiskami, review zgłasza błąd albo poprawka nie działa za drugim razem.
---

# Debugowanie

## Zakres

Warstwa bazowa: każdy worker. Najpierw przyczyna, potem poprawka. Nie zmieniasz kodu „na próbę”
w kilku miejscach naraz. Po dwóch nieudanych poprawkach tej samej rzeczy wracasz do odtworzenia.

## Lista kontrolna

1. 🔴 Poprawka usuwa przyczynę opisaną w raporcie, nie objaw (np. nie wyłącza testu, nie podnosi
   limitu czasu, nie dodaje `'unsafe-inline'` do CSP).
2. 🔴 Test regresji, który pada przed poprawką i przechodzi po niej.
3. 🟡 Odtworzenie zapisane: komenda, środowisko (lokalnie, CI run, staging), wynik przed i po.
4. 🟡 Różnica środowisk nazwana wprost, gdy błąd jest tylko w CI albo tylko na Vercel (wersja Node,
   adapter, nagłówki, zmienne, kolejność plików, sieć).
5. 🟡 Jedna hipoteza na raz: zmiana, uruchomienie, wniosek; wnioski w „Decyzjach” raportu.
6. ⚪ Wynik niestabilny (raz zielony, raz czerwony) mierzony kilka razy i opisany jako niestabilny.

## Weryfikacja: lokalnie i w CI

Kolejność odczytu, każda komenda w osobnym wywołaniu:

```sh
gh pr checks PR
gh run view RUN --log-failed
pnpm typecheck
pnpm test src/modul.test.ts
pnpm build
```

- Log CI czytasz przez `gh run view RUN --log-failed`; nie odtwarzasz E2E lokalnie (sandbox bez
  przeglądarek i portów).
- Błąd tylko w E2E: szukasz przyczyny w buildzie (`pnpm build`, zawartość `dist/`) i w teście
  (selektor, adres, czekanie), potem push i kolejny run.
- Zbyt długi log: zawężasz do joba (`gh run list --json` z `databaseId`, potem
  `gh run view RUN --job JOB --log-failed`), nie potokiem.

## Przykłady

```text
Objaw: e2e/csp.spec.ts czerwony tylko w CI.
Odtworzenie: gh run view 456 --log-failed → „Refused to apply inline style”, hash sha256-AbC…
Hipoteza 1: hash stylów inline zależy od buildu. Sprawdzenie: pnpm build dwa razy z inną zmianą CSS
→ inne hashe. Potwierdzona.
Przyczyna: CSP z hashami w vercel.json nie nadąża za buildem.
Poprawka: CSS w plikach (inlineStylesheets: 'never'), style-src 'self' bez hashy; test zostaje.
```

## Błędy z naszych projektów

- **iskt-www #23 (PR #24), brak CSP i hashe.** Pierwsza wersja CSP miała hashe stylów inline w
  `vercel.json`. W CI hashe były inne niż lokalnie, a każde inne zadanie zmieniające style psuło je
  znowu (#9). Przyczyna: hashe zależne od buildu. Poprawka: CSS w plikach, `style-src 'self'`
  (punkt 1, punkt 4).
- **iskt-www #29, zdublowany klucz `build`.** Strona działała, bo w obiekcie JS wygrywa ostatni
  klucz, więc objaw był tylko w lint i typach. Przyczyna: dwa merge'e z rozwiązanym „na ślepo”
  konfliktem. Wniosek: czerwony lint po merge'u to błąd, nie szum.
- **iskt-www #22, Lighthouse 87–89.** Lokalny Lighthouse był bimodalny (raz 89, raz 100) zależnie od
  tego, czy FCP wypadł przed fontami. Wniosek: punkt 6, co najmniej 3 przebiegi, mediana w raporcie.
