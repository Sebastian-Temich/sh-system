---
name: sh-kat-baza
description: Skill techniczny kategorii baza (szkielet, pełna wersja w B1). Lista kontrolna migracji Supabase/Postgres - RLS na nowych tabelach, with check zgodne z using, bez using (true) bez uzasadnienia, testy polityk dla właściciela i obcego, zgodność wstecz (expand/contract), indeksy. Użyj, gdy zadanie ma kategorię baza albo etykietę db:migracja, zmienia supabase/migrations, i w review PR z migracjami.
---

# Kategoria baza (szkielet)

## Zakres

Zadania z `kategoria: baza` i każdy PR ze zmienionymi plikami migracji (`shctl review run` dołącza
wtedy tę listę także przy innej kategorii). Migracje tylko z etykietą `db:migracja`, według „Migracji”
w `sh-worker` i `AGENTS.md`. Szkielet: lista kontrolna jest pełna (przeniesiona z `sh-review`, faza
6), przykłady i błędy uzupełnia faza B1.

## Lista kontrolna

1. 🔴 RLS włączone (`enable row level security`) na każdej nowej tabeli z danymi użytkowników.
2. 🔴 Każda polityka `insert` i `update` ma jawne `with check` zgodne z `using`. `with check`
   luźniejsze niż `using` (np. `true` albo inny warunek, który pozwala przepisać wiersz na cudzy
   `user_id`) albo `insert` bez `with check` to 🔴. Brak jawnego `with check` w `update` przy poprawnym
   `using` to 🟡: PostgreSQL stosuje wtedy `using` także do nowego wiersza, więc to wymóg jawności, nie
   luka.
3. 🔴 Brak polityk `using (true)` i `with check (true)` bez uzasadnienia w ADR albo raporcie.
4. 🟡 Testy polityk dla właściciela wiersza i dla obcego użytkownika (pozytywne i negatywne, dla
   każdej operacji z polityką); gdy test polityk jest kryterium issue, brak to 🔴 (niespełnione
   kryterium).
5. 🔴 Migracja zgodna wstecz (expand/contract): bez usuwania i zmiany typu kolumn używanych przez
   poprzednią wersję, nowe kolumny `not null` tylko z wartością domyślną, bez zmian w istniejących
   migracjach.
6. 🟡 Indeksy pod nowe zapytania: kolumny w filtrach polityk (np. `user_id`), kluczach obcych i nowych
   zapytaniach aplikacji mają indeks.

## Weryfikacja: lokalnie i w CI

- Lokalnie: `pnpm lint`, `pnpm typecheck`, `pnpm test`, `pnpm build`, każde w osobnym wywołaniu.
  Baza lokalna (Supabase CLI, Docker) i testy polityk na żywej bazie w sandboxie nie działają bez
  portów; testy RLS uruchamia CI.
- Czerwony job: `gh pr checks PR`, potem `gh run view RUN --log-failed`.
- Staging migruje CI po merge'u na main (`STAGING_DB_URL`); worker nie łączy się ze stagingiem.

## Przykłady

```sql
alter table public.notatki enable row level security;
create policy notatki_update on public.notatki for update
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create index notatki_user_id_idx on public.notatki (user_id);
```

## Błędy z naszych projektów

- Brak przypadków: pilot iskt-www nie miał bazy (ADR-002). Pierwsze przypadki dopisuje faza B1 z
  projektu z Supabase.
