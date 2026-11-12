---
name: sh-kat-backend
description: Skill techniczny kategorii backend. Lista kontrolna endpointów, RPC i Edge Functions - kontrakt API (wejście, wyjście, kody), walidacja po stronie serwera, spójny format błędów, autoryzacja przy każdym endpoincie, idempotencja zapisów, timeouty usług zewnętrznych, logi bez danych osobowych. Użyj, gdy zadanie ma kategorię backend albo dodaje lub zmienia endpoint, route handler, server action, RPC, Edge Function lub webhook, i w review takiego PR.
---

# Kategoria backend

## Zakres

Zadania z `kategoria: backend` i fragmenty innych zadań, które dodają albo zmieniają kod po stronie
serwera: endpoint (`src/pages/api/`, `app/api/`), server action, funkcja RPC, Edge Function, webhook.
Nagłówki, sekrety, CSP i ochrona formularzy publicznych: `sh-kat-bezpieczenstwo`. Schemat, RLS i
zapytania SQL: `sh-kat-baza`. Klient Supabase i Edge Functions: `sh-stack-supabase` (wygrywa przy
sprzeczności). Backend z autoryzacją w issue idzie do review na poziomie `ryzyko`.

## Lista kontrolna

1. 🟡 Kontrakt API zapisany przed kodem: metoda, ścieżka, schemat wejścia i wyjścia, kody odpowiedzi
   (sukces i każdy błąd), w karcie funkcji, w planie albo w typach współdzielonych z klientem (jeden
   schemat, np. Zod, dla formularza i endpointu). Kod zgodny z kontraktem.
2. 🔴 Walidacja po stronie serwera każdego wejścia (ciało, parametry, nagłówki, pliki): schemat, typ,
   długość, zakres; walidacja w przeglądarce jej nie zastępuje. Nieznane pola odrzucone albo pominięte.
3. 🔴 Autoryzacja przy każdym endpoincie i każdej operacji: kto wywołuje (sesja z serwera, nie z
   ciała żądania) i czy może dotknąć tego zasobu (właściciel, rola, organizacja). Sam fakt
   zalogowania to nie autoryzacja. Brak sprawdzenia własności zasobu (IDOR) to 🔴.
4. 🔴 Klucz `service_role` (i inne omijające RLS) tylko po stronie serwera, tylko gdy konieczny, z
   jawnym sprawdzeniem uprawnień w kodzie przed użyciem; domyślnie klient z sesją użytkownika.
5. 🟡 Spójny format błędów w całym API (np. `{ "error": "kod", "fields": {…} }`), właściwe kody HTTP
   (400 walidacja, 401 brak sesji, 403 brak uprawnień, 404, 409 konflikt, 429, 5xx), bez stack trace,
   SQL i treści odpowiedzi dostawcy w odpowiedzi.
6. 🟡 Idempotencja zapisów, które klient albo dostawca może powtórzyć (ponowny submit, retry,
   webhook): klucz idempotencji albo ograniczenie `unique` i `on conflict`; drugi taki sam request nie
   tworzy duplikatu ani drugiej płatności lub wysyłki.
7. 🟡 Wywołanie usługi zewnętrznej ma timeout, obsługę błędu (502/503 z naszym kodem błędu) i nie
   trzyma transakcji bazy w trakcie.
8. 🔴 Logi i metryki bez danych osobowych (imię, e-mail, telefon, treść, adres IP w jawnej postaci) i
   bez sekretów: logujesz zdarzenie, kod, status i identyfikator żądania z listy dozwolonych pól.
9. 🟡 Webhook weryfikuje podpis dostawcy przed jakimkolwiek działaniem i odpowiada szybko (ciężka praca
   asynchronicznie albo idempotentnie).
10. 🟡 Testy endpointu dla każdego kodu z kontraktu (sukces, walidacja, brak sesji, cudzy zasób,
    konflikt, błąd usługi), z mockiem usług zewnętrznych; logika w funkcji z wstrzykiwanymi
    zależnościami, testowalna bez serwera.
11. ⚪ Lista dozwolonych `Origin` i adresów zwrotnych z konfiguracji środowiska, z kompletem aliasów
    (np. `www`), a nie z jednej zmiennej wpisanej na sztywno.

## Weryfikacja: lokalnie i w CI

- Lokalnie: `pnpm lint`, `pnpm typecheck`, `pnpm test` (testy jednostkowe handlera z mockami: każdy kod
  odpowiedzi z kontraktu), `pnpm build`; każde w osobnym wywołaniu.
- Endpoint na żywym serwerze sprawdza E2E w CI (bezpośrednie żądania `request.post` w Playwright);
  czerwony job: `gh pr checks PR`, potem `gh run view RUN --log-failed`.
- Endpoint czytający bazę: polityki i zapytania testuje job CI `baza` (`sh-kat-baza`); lokalnej bazy
  w sandboxie nie ma.
- Czego worker nie sprawdzi (reguła WAF, limit u dostawcy, domena produkcyjna): wpis w „Ryzykach”
  raportu jako „do sprawdzenia na stagingu”.

## Przykłady

```ts
// src/pages/api/notatki/[id].ts — autoryzacja, walidacja, spójny błąd, log bez danych osobowych
export const PATCH: APIRoute = async ({ params, request, locals }) => {
  const user = await locals.supabase.auth.getUser();
  if (!user.data.user) return blad(401, 'unauthorized');
  const wejscie = NotatkaPatch.safeParse(await request.json().catch(() => null));
  if (!wejscie.success) return blad(400, 'invalid', pola(wejscie.error));
  const { data, error } = await locals.supabase.from('notatki')
    .update(wejscie.data).eq('id', params.id).select('id').maybeSingle(); // RLS: tylko własne
  if (error) { log.error({ event: 'notatka_update', code: error.code, requestId }); return blad(500, 'internal'); }
  if (!data) return blad(404, 'not_found'); // cudza i nieistniejąca wyglądają tak samo
  return json(200, data);
};
```

## Błędy z naszych projektów

- **iskt-www T-16 (PR #37), `Origin` a domena `www`.** Endpoint formularza (T-11) odrzucał 403 każdy
  `Origin` inny niż `PUBLIC_SITE_URL`. Wyszło dopiero przy dokumentacji wydania: formularz pod
  `www.iskt.pl` nie zadziałałby; obejście to przekierowanie `www` w krokach wydania. Wniosek: punkt 11.
- **iskt-www T-11 (PR #26), rate limit niesprawdzalny przez workera.** Limit 429 zależał od reguły
  WAF w panelu Vercel, do którego worker nie ma dostępu; kryterium „6. POST z jednego IP → 429”
  zostało ryzykiem do decyzji właściciela. Wniosek: sekcja Weryfikacja, „Czego worker nie sprawdzi”,
  i test limitera w kodzie z mockiem.
- **iskt-www T-11 (PR #26), logi z listą dozwolonych pól.** Logger zapisywał tylko `event`, `status`,
  `code`, `requestId`, a test przepuszczał wszystkie ścieżki endpointu i sprawdzał, że żadna linia nie
  zawiera imienia, e-maila, treści ani IP. Review PASS bez uwag do logów. Wniosek: wzorzec dla punktu 8.
