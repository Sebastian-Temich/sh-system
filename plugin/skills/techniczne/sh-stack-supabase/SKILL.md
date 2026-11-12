---
name: sh-stack-supabase
description: Skill techniczny stacku Supabase. Pułapki bezpieczeństwa Supabase (RLS w schemacie public, polityki TO authenticated z predykatem własności, user_metadata, widoki security_invoker, SECURITY DEFINER, klucz service_role, Storage), wydajność polityk ((select auth.uid()), indeksy) i weryfikacja - migracje i pgTAP na lokalnej bazie przez shctl db, job CI baza (lint, advisors) jako drugie sprawdzenie. Użyj, gdy zadanie ma stack supabase albo dotyka supabase/, klienta supabase-js, auth, Storage lub Edge Functions, i w review takiego PR.
---
<!-- źródło: https://github.com/supabase/agent-skills/tree/c9be0e931b7930f7d02126d04774d904c381e7d7/skills, wersja: c9be0e931b7930f7d02126d04774d904c381e7d7, skopiowano: 2026-11-12, licencja: MIT -->

# Stack Supabase

## Zakres

Projekty i zadania ze `stack: supabase`. Warstwa stacku: przy sprzeczności wygrywa z `sh-kat-baza`,
`sh-kat-backend` i `sh-kat-bezpieczenstwo`, ustępuje skillom projektu. Ogólne zasady migracji, RLS,
indeksów i testów są w `sh-kat-baza`; tu tylko to, co specyficzne dla Supabase. Fragmenty
oznaczone [S] i [P] pochodzą z oficjalnych skilli Supabase (adnotacja pod frontmatterem):
[S] `skills/supabase/SKILL.md` 0.1.2, [P] `skills/supabase-postgres-best-practices` 1.1.1
(`references/security-rls-performance.md`, `schema-foreign-key-indexes.md`); skrócone i
przetłumaczone.

## Lista kontrolna

1. 🔴 RLS na każdej tabeli w schemacie wystawionym przez Data API (`public` domyślnie): tabela tam
   jest osiągalna z przeglądarki, gdy `anon` albo `authenticated` ma `grant`. `grant` dla tych ról
   tylko razem z RLS. [S]
2. 🔴 Polityka ma `to authenticated` (albo `to anon`) i predykat własności w `using`. Samo
   `to authenticated` to uwierzytelnienie bez autoryzacji (BOLA, IDOR). Bez `auth.role()`
   (przestarzałe, przepuszcza użytkowników anonimowych). [S]
3. 🔴 Autoryzacja nie korzysta z `user_metadata` (`raw_user_meta_data`): użytkownik zmienia je sam.
   Role i uprawnienia w `app_metadata` albo w tabeli z RLS. [S]
4. 🔴 Widok na tabelach z RLS ma `with (security_invoker = true)`; bez tego widok omija RLS. [S]
5. 🔴 `security definer` nie służy do obejścia błędu uprawnień. Gdy konieczny: schemat niewystawiony
   (np. `private`), `set search_path = ''`, sprawdzenie `auth.uid()` w treści, `revoke execute ... from
   public, anon, authenticated`. Funkcja w `public` jest domyślnie wywoływalna przez `anon`. [S] [P]
6. 🔴 Klucz `service_role` (secret) nigdy w kodzie przeglądarki ani w zmiennej `PUBLIC_` lub
   `NEXT_PUBLIC_`; w przeglądarce tylko klucz publiczny (publishable albo `anon`). [S]
7. 🟡 Polityka `update` ma obok siebie politykę `select` dla tych samych wierszy: bez niej `update`
   zwraca 0 wierszy bez błędu. [S]
8. 🟡 W politykach `(select auth.uid())` zamiast `auth.uid()` (jedno wywołanie na zapytanie, nie na
   wiersz) i indeks na kolumnie z polityki. [P]
9. 🟡 Storage: `upsert` pliku wymaga polityk `insert`, `select` i `update` na `storage.objects`. [S]
10. 🟡 Pakiety `@supabase/*` w dokładnej wersji z lockfile. [S]
11. 🟡 Migracje imperatywne w `supabase/migrations/RRRRMMDDGGMMSS_nazwa.sql`, nazwa z bieżącym czasem UTC
    i większa od ostatniej; bez `supabase/schemas/` (schemat deklaratywny wymaga `supabase db diff`,
    którego `shctl db` nie udostępnia).
12. ⚪ Typy bazy (`database.types.ts`) zaktualizowane ręcznie zgodnie z migracją w tym samym PR;
    w raporcie, że `supabase gen types` nie był uruchamiany.

## Weryfikacja: lokalnie i w CI

- Surowe Supabase CLI w sandboxie workera nie działa (`EPERM` przy zapisie `~/.supabase`, test B1) i
  go nie uruchamiasz ani nie obchodzisz sandboxa (`HOME`, inne ustawienia). Lokalną bazę daje
  `shctl db` (poza sandboxem, tylko lokalnie, porty z bloku projektu w `porty.md`), wywoływane z
  worktree zadania, każde w osobnym wywołaniu:
  `shctl db start --projekt NAZWA`, `shctl db reset --projekt NAZWA` (migracje i `seed.sql` od zera),
  `shctl db test --projekt NAZWA` (pgTAP z `supabase/tests/`), `shctl db status --projekt NAZWA`
  (adres API i lokalne klucze do testów integracyjnych), na koniec `shctl db stop --projekt NAZWA`.
- Kod 4 z `shctl db` (np. działa stack innego projektu, `supabase/` powiązany z chmurą) to odmowa:
  nie obchodzisz jej, zapisujesz w „Ryzykach”, a bazę sprawdza wtedy tylko CI.
- Lokalnie też: `pnpm lint`, `pnpm typecheck`, `pnpm test`, `pnpm build`; każde w osobnym wywołaniu.
- Job CI `baza` (zmiany w `supabase/`) to drugie sprawdzenie: `supabase start` (migracje i `seed.sql`
  na czystej bazie), `supabase test db`, `supabase db lint --local`, `supabase db advisors --local`.
  Advisors poziomu `ERROR` (np. tabela w `public` bez RLS) czerwienią job; `WARN` i `INFO` (np.
  funkcja z ruchomym `search_path`, klucz obcy bez indeksu) są tylko w logu.
  Czerwony job: `gh pr checks PR`, potem `gh run view RUN --log-failed`.
- Ostrzeżenia advisors (`WARN`, `INFO`) z logu joba wpisujesz w raporcie: poprawione albo z powodem.

## Przykłady

```sql
-- [P] funkcja pomocnicza polityki: schemat niewystawiony, pusty search_path, auth.uid() w treści
create or replace function private.czy_czlonek_zespolu(p_zespol bigint)
returns boolean language sql security definer set search_path = '' as $$
  select exists (select 1 from public.czlonkowie_zespolu
                 where zespol_id = p_zespol and user_id = (select auth.uid()));
$$;
revoke execute on function private.czy_czlonek_zespolu(bigint) from public, anon, authenticated;
create policy zadania_select on public.zadania for select to authenticated
  using ((select private.czy_czlonek_zespolu(zespol_id)));

-- [S] widok respektujący RLS wywołującego
create view public.moje_notatki with (security_invoker = true) as
  select id, tresc from public.notatki;
```

## Błędy z naszych projektów

- **sh-dryrun #64 (test review F6), polityki bez `to authenticated` i z `auth.uid()` per wiersz.**
  Review z ówczesną listą bazy zgłosił `with check` i indeks, ale nie to, że polityki obejmowały też
  rolę `anon` i wołały `auth.uid()` dla każdego wiersza: lista tych pułapek nie miała. Wniosek:
  punkty 2 i 8.
- **SH-lite B1, Supabase CLI w sandboxie workera.** `supabase init`, `start`, `status` i `stop` w
  profilu workera kończyły się `EPERM` na `~/.supabase`, zanim CLI sięgnął do Dockera. Wniosek:
  job `baza` w CI, a od B1 krok 3 lokalna baza przez `shctl db` poza sandboxem (sekcja Weryfikacja).
