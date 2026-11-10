# Przykład od zera: strona firmowa z formularzem kontaktowym

Wróć do: [[00-start-tutaj]]

Przykład pokazuje cały przebieg trybu M. Odpowiedzi orkiestratora są przykładowe: prawdziwe
brzmienie będzie inne, ale kolejność kroków, pliki i powiadomienia są takie, jak w systemie.
Projekt nazywa się `strona-firmowa`. Numery PR i issue są umowne.

## 0. Przygotowanie materiałów

Projekt graficzny robisz w Claude Design i eksportujesz go (np. ZIP z makietami i zrzutami ekranów).
Teksty, logo i dane firmy przygotuj obok.

Dostarczanie projektu z Claude Design wprost do repo (tryb Storybook albo Lovable) to etap B (jeszcze
niedostępne). Dziś materiały idą przez skrzynkę w Obsidianie.

## 1. Zlecenie i materiały

**Ty (w czacie `sh-orkiestrator`):**

```text
Nowy projekt strona-firmowa: strona firmowa ISKT, 5 podstron (start, oferta, realizacje,
o nas, kontakt) i formularz kontaktowy, który wysyła zgłoszenie na nasz e-mail.
```

**Orkiestrator:** `shctl new-project strona-firmowa --opis "…" --zlecenie "…"`: repo publiczne (bez
„generated from”, z opisem, tematem `sh-projekt` i ochroną `main`), klon w
`/Users/Shared/sh/projekty/strona-firmowa`, blok portów bazy, kopia `docs/` w Obsidianie i pusta skrzynka
`SH/Skrzynka/strona-firmowa/`. Odpowiada, że skrzynka czeka na materiały.

**Ty:** przeciągasz do `SH/Skrzynka/strona-firmowa/` eksport `makiety.zip`, `logo.svg` i folder
`teksty/` z opisami podstron, potem piszesz:

```text
Materiały w skrzynce.
```

**Orkiestrator:** `shctl skrzynka przyjmij strona-firmowa`. Pliki trafiają bez zmian (ZIP bez
rozpakowania) do `docs/00-intake/zrodla/`. Powstaje PR #1 z gałęzi `skrzynka/20261103-101500`. Ta
sama komenda czeka na CI, po zielonym merguje PR i opróżnia skrzynkę.

```text
Materiały przyjęte (PR #1): makiety.zip, logo.svg, teksty/ (5 plików). Skrzynka pusta.
```

Skrzynka jest teraz pusta, a pliki są w repo i w Obsidianie, po synchronizacji, w
`SH/Projekty/strona-firmowa/docs/00-intake/zrodla/`. Następnie orkiestrator uruchamia `sh-intake`,
który czyta materiały jako dane.

**Orkiestrator odpowiada (przykład):**

```text
Intake pisze specyfikację na podstawie zlecenia i materiałów.
Tryb M: nowy projekt, a formularz zbiera dane osobowe (imię, e-mail, treść).
Pytania (piszę dalej z propozycjami jako założeniami):
1. Gdzie trafiają zgłoszenia? Propozycja: e-mail przez Resend i kopia w bazie Supabase.
2. Wersja angielska? Propozycja: poza zakresem.
3. Zgoda RODO pod formularzem? Propozycja: checkbox z linkiem do polityki prywatności.
```

**W Obsidianie:** po kilku minutach pojawia się `SH/Projekty/strona-firmowa/docs/` z pustymi
szablonami. Specyfikacji jeszcze nie ma: powstaje na gałęzi
`stage/00-intake`.

## 2. Specyfikacja i pierwszy checkpoint

Intake pisze `docs/00-intake/specyfikacja.md` i otwiera PR. Codex robi review etapu. Przy FAIL
intake poprawia i review się powtarza (maks. 3 razy, potem eskalacja).

**Orkiestrator (po PASS):**

```text
strona-firmowa: specyfikacja czeka na Twoją akceptację, PR #2.
Tryb M. Ryzyka na „tak”: dane osobowe (formularz).
Hosting: Vercel + Supabase Cloud UE na kontach firmy.
Otwarte pytania: 3, z propozycjami jak wyżej.
Szacunek poglądowy: 9 zadań, ok. tydzień, ok. 2 godziny Twojego czasu.
```

Jednocześnie przychodzi push (`notify.sh`):

```text
Czeka na Twoją akceptację: strona-firmowa / 00-intake
Specyfikacja, PR #2
```

Kliknięcie otwiera PR. Etap widać też w „status?” w „Czeka na Ciebie”.

**Ty:** czytasz PR #2 na GitHubie (wymagania `W-01`…`W-06` z kryteriami Given/When/Then).

```text
Akceptuję specyfikację. Odpowiedzi na pytania: zgodnie z propozycjami.
```

**Orkiestrator:** zapisuje akceptację w `decyzje.md` (rola `wlasciciel`), intake wpisuje stack do
`AGENTS.md` (nowy commit wraca do review; po nowym PASS przychodzi drugi push dla tego samego
etapu), potem merge. Etap `00-intake` ma `done`.

**W Obsidianie:** `docs/00-intake/specyfikacja.md`, a w `decyzje.md` Twoja akceptacja.

## 3. Plan, drugi checkpoint

`sh-plan` pisze w worktree etapu na gałęzi `stage/04-plan`:

- `plan.md`, sekcja „Architektura”: moduły z punktami wejścia (strony `/`, `/oferta`, `/kontakt`,
  formularz, wysyłka e-mail) i plikami designu, tabela zgłoszeń z RLS, środowiska;
- ADR „Dane osobowe w formularzu kontaktowym”: retencja, brak danych w logach, testy uprawnień;
- w tym samym `plan.md` kamienie, Twoje zadania ręczne i scenariusze odbioru.

**Orkiestrator (po PASS):**

```text
strona-firmowa: plan czeka na akceptację, PR #3.
Kamienie: M1 Szkielet, M2 Podstrony i treści, M3 Formularz kontaktowy, M4 Dokumentacja wydania.
Twoje zadania ręczne:
- podłączenie repo do Vercel, przed pierwszym PR z podglądem,
- projekt Supabase staging i sekret STAGING_DB_URL w GitHub, przed pierwszą migracją na main,
- konto Resend i klucz testowy w .env.local, przed formularzem (M3),
- domena i DNS, przed odbiorem.
Zakres autoryzacji: M1–M4, Resend plan darmowy, do odbioru zlecenia.
shctl doctor 2026-11-03T09:12Z: wszystko ok.
```

Push: „Czeka na Twoją akceptację: strona-firmowa / 04-plan” z linkiem do PR #3.

**Ty:**

```text
Akceptuję plan.
```

**Orkiestrator:** zapisuje rejestr autoryzacji w `decyzje.md`. Od teraz kamienie M1–M4 startują
bez pytania, jeśli mieszczą się w tej zgodzie.

## 4. Zadania

`sh-plan` pisze `docs/06-zadania/zadania.yaml` (jedna strona albo funkcja to jedno zadanie, z
kategorią, stackiem i kryterium podpięcia do routingu), Codex robi review, orkiestrator merguje.
Potem `shctl task create` zakłada issue na GitHubie.

**Orkiestrator:**

```text
| ID | Issue | Tytuł                       | Kamień | Zależności |
| T1 | #5    | Szkielet projektu           | M1     | -          |
| T2 | #6    | Układ strony i nawigacja    | M2     | T1         |
| …  |       |                             |        |            |
| T6 | #10   | Formularz: wysyłka Resend   | M3     | T5         |
| T9 | #13   | Dokumentacja wydania        | M4     | wszystkie  |
Blokuje pracę: klucz testowy Resend przed T6.
```

**W Obsidianie:** `docs/06-zadania/index.md` z mapą zadań, a w „status?” liczniki „todo”.

## 5. Realizacja

Orkiestrator uruchamia `shctl doctor`, potem `shctl task dispatch 5` (szkielet idzie sam, przed
wszystkim innym). Worker w panelu `worker:strona-firmowa:5` pisze kod i testy, otwiera PR z
`Closes #5` i raportem `T-5.md`. Po zielonym CI orkiestrator wywołuje `shctl review run`:

- **PASS:** `shctl task close 5`: merge, wpis w `CHANGELOG.md`, decyzje z raportu do `decyzje.md`,
  czas do `metryki.md`;
- **FAIL:** `shctl task iter 5`: worker poprawia wyłącznie zgłoszenia 🔴 i 🟡.

Naraz pracują najwyżej dwaj workerzy na całym Macu (`max_local: 2` w `/Users/Shared/sh/konfiguracja.md`). Nic tu od Ciebie nie zależy.

### Powiadomienia, które mogą przyjść

**Limit:** push o limicie nie przychodzi. Orkiestrator pisze w czacie, że skończył się limit
Claude do 19:00, i wpisuje go do `/Users/Shared/sh/limity.md`. Praca workera stoi. Po odnowieniu
piszesz „wznów”. Orkiestrator sprawdza przerwane zadanie (`shctl task resume-check`) i decyduje: kontynuuj,
rebase albo iteracja od nowa. Przerwanie przez limit nie liczy się jako iteracja.

**Eskalacja:** worker dochodzi do formularza, a klucza testowego Resend nie ma.

```text
Eskalacja E-001: strona-firmowa
#10: brak klucza testowego Resend
```

W Obsidianie: `docs/07-realizacja/escalations/E-001.md`, a w „status?” w „Czeka na Ciebie”.
Zakładasz konto Resend, wpisujesz klucz testowy do `/Users/Shared/sh/projekty/strona-firmowa/.env.local` na
serwerze i piszesz w czacie (bez klucza):

```text
E-001: klucz testowy Resend jest w .env.local
```

Orkiestrator zamyka eskalację tą odpowiedzią i wraca do zadania. W tym czasie inne zadania szły
dalej.

## 6. Kamień milowy

Po zamknięciu zadań M2 orkiestrator uruchamia `sh-qa`: E2E w chromium i webkit, przepływy między
stronami, scenariusze odbioru kamienia. Raport `docs/08-qa/raport-M2.md` przechodzi review.
Błędy 🔴 i 🟡 stają się nowymi zadaniami `typ:qa`, drobne trafiają do `backlog-drobne.md`.

**Orkiestrator:**

```text
strona-firmowa: M2 zakończony. QA: PASS w chromium, 1 błąd istotny w webkit (menu mobilne),
zadanie #15. Startuję M3 (mieści się w autoryzacji).
Punkt przekazania zapisany. Proponuję /clear i „wznów”.
```

**Ty:** wpisujesz `/clear`, potem „wznów”. Orkiestrator odtwarza stan z plików.

**W Obsidianie:** raport QA, „Punkt przekazania” w `historia.md`, zaktualizowany `Projekt.md`.

## 7. Odbiór na stagingu

Po ostatnim kamieniu orkiestrator otwiera PR etapu `wydanie` (review jak
wcześniej). Staging to wdrożenie gałęzi `main` w Vercel pod stałym aliasem i osobny projekt
Supabase, migrowany przez CI.

**Orkiestrator:**

```text
strona-firmowa: gotowe do odbioru. Staging: https://strona-firmowa-staging.vercel.app
Scenariusze do sprawdzenia (z planu):
1. Gość otwiera każdą z 5 podstron na telefonie i komputerze (W-01, W-02).
2. Gość wysyła formularz z poprawnymi danymi: widzi potwierdzenie, e-mail dochodzi (W-04).
3. Formularz bez zgody RODO: nie da się wysłać (W-05).
…
Decyzje do przejrzenia: 7 w decyzje.md. Drobne uwagi w backlogu: 4.
```

Push: „Czeka na Twoją akceptację: strona-firmowa / wydanie” z linkiem do PR etapu `wydanie`.

**Ty:** przechodzisz scenariusze na stagingu.

```text
Odbieram.
```

Albo: „Scenariusz 2: e-mail nie doszedł”. Wtedy powstaje nowe zadanie i odbiór czeka.

**Orkiestrator:** zapisuje odbiór w `decyzje.md`, merguje i zamyka etap `wydanie`.

W etapie A na tym koniec: wdrożenia produkcyjnego nie ma. Po pilocie wdrażasz Ty, ze swojego
urządzenia, skryptem `scripts/deploy-prod.sh vX.Y.Z` z repo projektu ([[proces-v1]], „Droga na
produkcję”).

**W Obsidianie:** `docs/wydanie/techniczna/` i `docs/wydanie/produktowa/`, komplet decyzji i metryk.

## Przykład trybu S

Projekt działa, chcesz drobnej zmiany.

**Ty:**

```text
Nowe zlecenie dla strona-firmowa: dodaj link do LinkedIn w stopce.
```

**Orkiestrator:** `sh-intake` rozpoznaje tryb S (jedna zmiana, bez danych i ryzyk), zapisuje plik
zlecenia i zakłada jedno issue z etykietą `tryb:S`. Nie ma specyfikacji ani checkpointów etapów.

```text
strona-firmowa: zlecenie S, issue #20 „Link LinkedIn w stopce”. Startuję.
```

Worker, CI i review jak w trybie M. Potem, przy `odbior_S: reczny`:

```text
strona-firmowa: #20 gotowe do odbioru, PR #21, review PASS, CI zielone.
Podgląd: link do wdrożenia preview z PR.
```

Na telefon przychodzi „Czeka na Twoją akceptację: strona-firmowa / #20” z treścią „Odbiór zadania #20
(tryb S), PR #21”.

**Ty:**

```text
Odbieram #20.
```

Orkiestrator wywołuje `shctl task close 20`: merge, wpis w `CHANGELOG.md`, zamknięcie issue.

Gdyby zmiana okazała się większa (np. nowe pole w bazie), orkiestrator zaproponuje podniesienie
trybu do M. Przyjdzie wtedy push „Czeka na Twoją akceptację: strona-firmowa / podniesienie trybu”
z numerem eskalacji. Decyzja należy do Ciebie.
