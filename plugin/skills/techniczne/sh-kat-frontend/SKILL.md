---
name: sh-kat-frontend
description: Skill techniczny kategorii frontend. Lista kontrolna stron i komponentów - podpięcie do routingu, stany ekranu, formularze z prawdziwą wysyłką albo jawną blokadą, dostępność (axe, fokus, cele 24 px), responsywność 375/768/1440, wydajność (LCP, obrazy, CSS blokujący render) i zgodność z CSP. Użyj, gdy zadanie ma kategorię frontend, buduje stronę, komponent albo formularz, i w review takiego PR.
---

# Kategoria frontend

## Zakres

Zadania z `kategoria: frontend`: strony, komponenty, formularze, style. Ta sama lista trafia do
workera (`shctl task dispatch`) i do review (`shctl review run`). Stack (np. `sh-stack-astro`) i
skille projektu mają pierwszeństwo; bezpieczeństwo nagłówków szczegółowo: `sh-kat-bezpieczenstwo`.

## Lista kontrolna

1. 🔴 Każda nowa strona i komponent są podpięte do routingu albo layoutu i używane; test wchodzi od
   trasy (brak komponentów martwych).
2. 🔴 Formularz albo wysyła dane metodą z architektury (`method="post"`, `fetch` na endpoint), albo
   jest jawnie zablokowany (`preventDefault`, `hidden` + `<noscript>`). Przycisk `submit` bez
   `action` i bez obsługi to GET na bieżący adres z danymi w URL.
3. 🔴 Bez stylów i skryptów inline, gdy architektura ma CSP bez `'unsafe-inline'`: brak `style=""`,
   `<style>` i `<script>` z kodem w HTML; warianty przez klasy.
4. 🟡 Stany ekranu z karty funkcji: ładowanie, pusty, błąd, sukces, wyłączony przycisk przy wysyłce.
5. 🟡 Dostępność: etykiety powiązane z polami, `aria-describedby` dla błędów, widoczny fokus,
   kolejność Tab, SkipLink, cele kliknięcia ≥ 24 px, axe bez serious i critical (E2E w CI).
6. 🟡 Responsywność 375, 768, 1440 px bez poziomego przewijania; zgodność z plikiem designu z issue.
7. 🟡 Wydajność: obraz LCP z `fetchpriority="high"`, `loading="eager"`, `sizes` i formatami
   AVIF/WebP; pozostałe obrazy `loading="lazy"`; fonty z `font-display: swap` i podzbiorem znaków.
8. 🟡 `prefers-reduced-motion` wyłącza animacje i przejścia.
9. ⚪ Teksty z pliku treści (np. `site.ts`), nie wpisane w komponent; bez nieużywanych zależności JS.

## Weryfikacja: lokalnie i w CI

- Lokalnie: `pnpm lint`, `pnpm typecheck`, `pnpm test`, `pnpm build`, każda w osobnym wywołaniu.
  Zawartość `dist/` sprawdzasz narzędziem Grep (np. brak `<style>`, brak `style=`).
- CI: E2E (chromium, webkit, axe, 375/768/1440) w jobie `e2e`; wynik przez `gh pr checks PR`, błąd
  przez `gh run view RUN --log-failed`.
- Lighthouse tylko w CI albo na stagingu (`qa-staging`, QA kamienia). W raporcie: „Lighthouse:
  pomiar w QA”, nie wynik z pamięci.

## Przykłady

Formularz przed podpięciem endpointu (osobne zadanie):

```html
<form method="post" hidden data-form-kontakt>
  <label for="email">E-mail *</label>
  <input id="email" name="email" type="email" required aria-describedby="email-blad" />
  <p id="email-blad" class="pole__blad" hidden></p>
  <button type="submit">Wyślij</button>
</form>
<noscript><p>Formularz wymaga JavaScriptu. Napisz na adres z sekcji kontakt.</p></noscript>
```

Skrypt w pliku modułu odkrywa formularz i blokuje `submit` do czasu wysyłki `fetch`.

Obraz LCP: `<Picture src={logo} formats={['avif','webp']} widths={[240,320,480,640]}
sizes="(min-width: 712px) 320px, 78vw" loading="eager" fetchpriority="high" alt="ISKT" />`.

## Błędy z naszych projektów

- **iskt-www T-8 i T-45, statyczny formularz.** Formularz w M1 nie miał `action`, a przycisk
  `submit` wysłałby GET na `/` z danymi w URL (dane osobowe w logach i historii). Poprawka w
  iteracji 2: `method="post"`, `hidden`, `<noscript>`, blokada `submit`. Wniosek: punkt 2.
- **iskt-www #22, Lighthouse 87–89.** Mobile na stagingu 87/89/89: LCP 3,5 s na logo w hero, trzy
  pliki CSS blokujące render, obrazy za duże o ~84 KiB, pełne fonty latin-ext. Poprawka:
  `<Picture>` AVIF z `sizes` i `fetchpriority`, podzbiór polskich liter w fontach; wynik 97–99.
  Wniosek: punkt 7 przy pierwszej wersji strony, nie po QA.
- **iskt-www #23 i T-43, CSP a style.** Po włączeniu `style-src 'self'` atrybut `style` z szerokością
  leadu przestał działać; poprawka: wariant klasy. Wniosek: punkt 3.
- **iskt-www T-6, test omijający `/404`.** Testy layoutu otwierały inny adres niż `/404`. Wniosek:
  punkt 1, test wchodzi od trasy z kryterium.
