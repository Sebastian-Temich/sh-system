---
name: sh-kat-baza
description: Skill techniczny kategorii baza. Lista kontrolna migracji i zapytań Postgres/Supabase - migracje expand/contract, RLS z USING i WITH CHECK, testy polityk dla właściciela i obcego, indeksy pod zapytania i polityki, EXPLAIN przed i po, N+1, transakcje, seedy zamiast danych produkcyjnych. Migracje i pgTAP lokalnie przez shctl db, job CI baza jako drugie sprawdzenie. Użyj, gdy zadanie ma kategorię baza albo etykietę db:migracja, zmienia supabase/, i w review PR z migracjami.
---

# Kategoria baza

## Zakres

Zadania z `kategoria: baza` i każdy PR ze zmienionymi plikami migracji (`shctl review run` dołącza
wtedy tę listę także przy innej kategorii). Migracje tylko z etykietą `db:migracja`, według „Migracji”
w `sh-worker` i `AGENTS.md`. Szczegóły Supabase (role `anon` i `authenticated`, widoki, `security
definer`, CLI): `sh-stack-supabase`, który przy sprzeczności wygrywa.

## Lista kontrolna

1. 🔴 RLS włączone (`enable row level security`) na każdej nowej tabeli w schemacie wystawionym przez
   API (`public`) i na każdej tabeli z danymi użytkowników.
2. 🔴 Każda polityka `insert` ma `with check`, a `with check` w `update` nie jest luźniejsze niż
   `using` (np. `true` albo warunek pozwalający przepisać wiersz na cudzy `user_id`).
3. 🟡 Polityka `update` ma jawne `with check` równe `using`. Brak przy poprawnym `using` to tylko 🟡:
   PostgreSQL stosuje wtedy `using` także do nowego wiersza, więc to wymóg jawności, nie luka.
4. 🔴 Brak polityk `using (true)` i `with check (true)` bez uzasadnienia w ADR albo raporcie.
5. 🟡 Testy pgTAP polityk dla właściciela wiersza i dla obcego użytkownika, pozytywne i negatywne,
   dla każdej operacji z polityką, w tym próba przepisania `user_id` na cudzy. Test tylko istnienia
   tabeli albo flagi RLS to brak testu. Gdy test polityk jest kryterium issue, brak to 🔴.
6. 🔴 Migracja zgodna wstecz (expand/contract): najpierw dodajesz (kolumna, tabela, kopia danych),
   potem aplikacja przechodzi na nowe, a usuwasz i zmieniasz typ dopiero w kolejnym wydaniu. Nowa
   kolumna `not null` tylko z wartością domyślną; bez zmian w istniejących plikach migracji.
7. 🟡 Indeks na kolumnach z filtrów polityk (np. `user_id`), kluczach obcych (Postgres ich nie
   indeksuje sam) i w `where`, `join`, `order by` nowych zapytań aplikacji.
8. 🟡 Nowe albo zmienione zapytanie na tabeli, która urośnie, ma w raporcie `explain` przed i po
   zmianie (plan, użyty indeks, koszt); `Seq Scan` na dużej tabeli tylko z uzasadnieniem.
9. 🟡 Bez N+1: lista z danymi powiązanymi to jedno zapytanie (`join`, `in (...)`, zagnieżdżony
   select PostgREST), nie zapytanie w pętli na każdy wiersz.
10. 🟡 Operacja zmieniająca kilka tabel albo wierszy, która musi przejść w całości, działa w jednej
    transakcji (funkcja SQL albo RPC), krótkiej, bez wywołań sieciowych w środku.
11. 🔴 Seed (`supabase/seed.sql`) i fixture'y mają wyłącznie dane fikcyjne; bez zrzutów i kopii danych
    produkcyjnych ani stagingu, bez prawdziwych e-maili i telefonów.
12. ⚪ Nazwy małymi literami z `_`, ograniczenia (`check`, `not null`, `unique`) w schemacie, a nie
    tylko w aplikacji; nowa migracja przez `supabase migration new NAZWA`.

## Weryfikacja: lokalnie i w CI

- Lokalna baza przez `shctl db` z worktree zadania (Supabase CLI w sandboxie kończy się `EPERM`,
  `shctl` działa poza nim, tylko na bazie lokalnej): `shctl db start --projekt NAZWA`, potem
  `shctl db reset --projekt NAZWA` (migracje od zera i seed) i `shctl db test --projekt NAZWA`
  (pgTAP z `supabase/tests/`); na koniec `shctl db stop --projekt NAZWA`. `supabase` ani `psql`
  wprost nie uruchamiasz. Wynik obu komend wpisujesz w „Testach” raportu.
- Odmowa `shctl db` (kod 4, np. działa stack innego projektu) to nie powód do obejścia: zapisujesz
  ją w „Ryzykach”, a migracje sprawdza wtedy tylko CI.
- Lokalnie też: `pnpm lint`, `pnpm typecheck`, `pnpm test`, `pnpm build`, każde w osobnym wywołaniu.
- Job CI `baza` (tylko przy zmianach w `supabase/`) to drugie sprawdzenie: migracje na czystej
  bazie i seed (`supabase start`), `supabase test db`, `supabase db lint` i `supabase db advisors`
  (błąd = czerwony job, np. tabela w `public` bez RLS). Czerwony job: `gh pr checks PR`, potem
  `gh run view RUN --log-failed`. W raporcie podajesz też numer runu CI.
- `explain` z punktu 8: z testu pgTAP albo pliku `supabase/tests/` przez `explain (analyze, buffers)`,
  w wyjściu `shctl db test` albo w logu CI; przy braku danych opisujesz oczekiwany plan i indeks.
- Staging migruje CI po merge'u na main (`STAGING_DB_URL`); worker nie łączy się ze stagingiem.

## Przykłady

```sql
-- migracja: tabela z RLS, polityki z to authenticated, indeks pod politykę i klucz obcy
create table public.notatki (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  tresc text not null check (char_length(tresc) <= 2000)
);
create index notatki_user_id_idx on public.notatki (user_id);
alter table public.notatki enable row level security;
create policy notatki_update on public.notatki for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
```

```sql
-- supabase/tests/notatki.test.sql: obcy nie zmienia cudzego wiersza ani nie przepisuje swojego
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"UUID_A","role":"authenticated"}', true);
select is_empty($$update public.notatki set tresc = 'x' where user_id = 'UUID_B' returning id$$,
  'A nie zmienia notatki B');
select throws_ok($$update public.notatki set user_id = 'UUID_B' where user_id = 'UUID_A'$$,
  '42501', null, 'A nie przepisuje swojej notatki na B');
```

Expand/contract zmiany nazwy kolumny: wydanie 1 dodaje `nazwa_nowa` i kopiuje dane, wydanie 2
przenosi odczyt i zapis w aplikacji, wydanie 3 usuwa `nazwa`.

## Błędy z naszych projektów

- **sh-dryrun #63 (test review F6), testy bez polityk.** Kryterium „test pgTAP pozytywny i
  negatywny” spełniał plik, który sprawdzał tylko istnienie tabeli i flagę RLS; przeszedłby przy
  polityce wpuszczającej cudze notatki. Review 🔴. Wniosek: punkt 5.
- **sh-dryrun #64 (test review F6), indeks `user_id`.** Wszystkie polityki filtrowały po `user_id`,
  który był też kluczem obcym, bez indeksu (klucz główny `id` go nie pokrywa). Review 🟡. Wniosek:
  punkt 7.
- **sh-dryrun #64, waga `with check` w `update`.** Brak jawnego `with check` przy poprawnym `using`
  reviewer ocenił na 🔴, bo lista miała go w punkcie oznaczonym 🔴, a wyjątek 🟡 w treści. Wniosek:
  osobne punkty 2 i 3, każdy z jedną wagą.
