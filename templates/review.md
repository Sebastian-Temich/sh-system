# Wynik review

Format komentarza z wynikiem review w PR. Taki komentarz pisze `shctl review run` (z odpowiedzi Codexa
według `codex/sh-review.schema.json`), a skill `sh-review` albo człowiek może napisać go ręcznie.
`shctl task iter` i `shctl task close` czytają z niego werdykt i zgłoszenia. Format jest ścisły:
odstępstwo sprawia, że shctl nie znajdzie wyniku albo pominie zgłoszenie.

## Format

```markdown
## Review REVIEWER: WERDYKT

<!-- shctl:review head=SHA werdykt=WERDYKT -->
Commit `SHA7`, model MODEL, iteracja N.

PODSUMOWANIE

### Zgłoszenia

- 🔴 krytyczne `ŚCIEŻKA:LINIA`: OPIS
- 🟡 istotne `ŚCIEŻKA`: OPIS
- ⚪ drobne: OPIS
```

| Element | Reguła |
|---|---|
| `REVIEWER` | Kto robi review, np. `Codex` |
| `WERDYKT` | `PASS` albo `FAIL`, ten sam w nagłówku i w znaczniku |
| Znacznik | Jedna linia `<!-- shctl:review head=SHA werdykt=WERDYKT -->`, `SHA` to pełny (40 znaków) commit PR, którego dotyczy review |
| Linia `Commit` | Skrót commita, model reviewera, iteracja z etykiety `iter:N`; informacyjna |
| `PODSUMOWANIE` | 1–3 zdania po polsku |
| `### Zgłoszenia` | Każde zgłoszenie w jednej linii; bez zgłoszeń jedna linia `Brak.` |

Zgłoszenie: `- IKONA WAGA` i opcjonalnie miejsce w backtickach, potem `: ` i opis w jednej linii.

| Ikona | Waga | Skutek |
|---|---|---|
| 🔴 | `krytyczne` | Blokuje: sekret, bezpieczeństwo, utrata danych, niespełnione kryterium |
| 🟡 | `istotne` | Blokuje: błąd logiki, brak testu kryterium, migracja niezgodna wstecz |
| ⚪ | `drobne` | Nie blokuje, `task close` przenosi je do `backlog-drobne.md` |

Miejsce: `` `ścieżka` `` albo `` `ścieżka:linia` ``; bez miejsca od razu `: OPIS`.

## Reguły dla shctl

- Werdykt dotyczy tylko commita ze znacznika. Nowy commit w PR wymaga nowego review.
- shctl liczy werdykt ze zgłoszeń: `FAIL`, gdy jest choć jedno 🔴 albo 🟡, inaczej `PASS`. Przy
  rozbieżności z nagłówkiem obowiązuje wynik ze zgłoszeń.
- O wadze decyduje słowo (`krytyczne`, `istotne`, `drobne`); ikona służy ludziom.
- Linie poza formatem zgłoszenia (np. akapity, listy bez ikony) shctl pomija.
- Przy kilku komentarzach dla tego samego commita obowiązuje ostatni.
- `shctl review run` dopisuje na końcu ukrytą linię `<!-- shctl:review-dane BASE64 -->` z pełnym JSON
  wyniku. Gdy jest, shctl czyta ją zamiast tekstu; komentarz pisany ręcznie jej nie potrzebuje.

## Przykład

Test `scripts/shctl/tests/review-format.bats` parsuje ten przykład, podstawiając commit PR za zera.

<!-- przyklad:start -->
## Review Codex: FAIL

<!-- shctl:review head=0000000000000000000000000000000000000000 werdykt=FAIL -->
Commit `0000000`, model GPT-6.1 Terra, iteracja 1.

Formularz działa, ale hasło trafia do logów, a walidacja e-maila nie ma testu.

### Zgłoszenia

- 🔴 krytyczne `src/auth/login.ts:42`: hasło trafia do logu; usuń je z komunikatu.
- 🟡 istotne `src/auth/login.test.ts`: brak testu dla błędnego e-maila z kryterium 2.
- ⚪ drobne: nazwa `x` w `validate` mało czytelna.
<!-- przyklad:end -->
