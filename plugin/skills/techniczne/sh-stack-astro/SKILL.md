---
name: sh-stack-astro
description: Skill techniczny stacku Astro (5, SSG z endpointem serverless na Vercel). Konfiguracja astro.config.mjs bez zdublowanych kluczy, trailingSlash i adresy w testach, CSS w plikach pod CSP, astro:assets dla obrazów, prerender=false dla endpointu, astro preview bez nagłówków Vercel. Użyj, gdy zadanie ma stack astro albo zmienia astro.config.mjs, strony w src/pages, obrazy, style lub endpoint, i w review takiego PR.
---

# Stack Astro

## Zakres

Projekty z `stack: [astro]`: Astro 5 + TypeScript strict, `output: 'static'`, adapter
`@astrojs/vercel`, endpointy z `export const prerender = false`. Ma pierwszeństwo przed kategorią i
bazowymi; ustępuje skillom projektu (`.claude/skills`) i ADR projektu.

## Lista kontrolna

1. 🔴 `astro.config.mjs`: każdy klucz najwyżej raz (`build`, `vite`, `integrations`); po merge'u z
   main sprawdzone `pnpm lint` (`no-dupe-keys`) i `pnpm typecheck` (TS1117).
2. 🔴 Adresy w testach w konwencji `trailingSlash` projektu (`'always'`: `/404/`, `/kontakt/`);
   adres bez ukośnika testowany osobno jako przekierowanie.
3. 🔴 Przy CSP `style-src 'self'`: `build.inlineStylesheets: 'never'` i `vite.build.assetsInlineLimit:
   0`; zmiana tej opcji to decyzja w raporcie i test braku `<style>` w HTML.
4. 🟡 Obrazy przez `astro:assets` (`<Image>`, `<Picture>`) z `widths` i `sizes`; obraz LCP z
   `loading="eager"` i `fetchpriority="high"`.
5. 🟡 Endpoint: `prerender = false`, `export const POST` i `ALL` (405 dla reszty), zmienne przez
   `astro:env` albo `import.meta.env`, sekrety tylko serwerowe.
6. 🟡 Skrypty klienta jako moduły (`<script>` przetwarzany przez Astro trafia do `/_astro/`), bez
   `is:inline` z kodem przy CSP.
7. 🟡 Komponenty `.astro` z typowanymi `Props`; treści w jednym pliku danych (np. `src/content/site.ts`).
8. ⚪ `@astrojs/sitemap` i `site` w konfiguracji zgodne z adresem stagingu i produkcji.

## Weryfikacja: lokalnie i w CI

- Lokalnie, każde w osobnym wywołaniu: `pnpm lint`, `pnpm typecheck` (`astro check`), `pnpm test`,
  `pnpm build`. Wynik buildu w `dist/` albo `.vercel/output/static/` sprawdzasz narzędziem Grep.
- `pnpm dev` i `astro preview` wymagają portu: w sandboxie nie działają. E2E (`astro build` +
  `astro preview`) uruchamia CI; błąd: `gh run view RUN --log-failed`.
- `@astrojs/vercel` nie obsługuje `astro preview` dla buildu z `prerender = false`; E2E z endpointem
  używa adaptera `@astrojs/node` przez zmienną (np. `ASTRO_ADAPTER=node` w skrypcie `build:e2e`).
- `astro preview` nie czyta `vercel.json`: nagłówki i przekierowania Vercel sprawdzasz w E2E przez
  `page.route` albo na stagingu.

## Przykłady

Jeden klucz `build` z powodem:

```js
export default defineConfig({
  output: 'static',
  trailingSlash: 'always',
  adapter: process.env.ASTRO_ADAPTER === 'node' ? node({ mode: 'standalone' }) : vercel(),
  // CSS w plikach /_astro/: CSP style-src 'self' bez 'unsafe-inline' (ADR, #23).
  build: { inlineStylesheets: 'never' },
  vite: { build: { assetsInlineLimit: 0 } },
});
```

## Błędy z naszych projektów

- **iskt-www #29 (PR #30), zdublowany klucz `build`.** #22 (`inlineStylesheets: 'always'`, pod
  Lighthouse) i #23 (`'never'`, pod CSP) zmieniły ten sam klucz w osobnych PR. Po merge'ach plik miał
  dwa `build`; lint, typy i E2E czerwone na main. Wniosek: punkt 1 i punkt 3.
- **iskt-www T-6, test omijający `/404`.** Przy `trailingSlash: 'always'` `astro preview` odrzuca
  `/404`, więc test przeszedł na `/nie-ma-takiej-strony/`. Poprawka: `/404/` i test przekierowania
  na Vercel. Wniosek: punkt 2.
- **iskt-www #22, Lighthouse 87–89.** `<Image densities>` dla logo w hero dawało 640w WebP 223 KB na
  mobile. Poprawka: `<Picture>` AVIF z `widths` i `sizes` (74 KB). Wniosek: punkt 4.
- **iskt-www T-11, endpoint w E2E.** `astro preview` z adapterem Vercel nie serwuje
  `prerender = false`; rozwiązanie: adapter node tylko dla E2E. Wniosek: sekcja „Weryfikacja”.
