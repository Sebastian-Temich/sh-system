---
max_local: 2
review:
  zwykle:
    silnik: claude
    model: opus
    effort: medium
  ryzyko:
    silnik: codex
    model: gpt-6-astra
    effort: high
  gdy_limit: czekaj
  prog_linii: 400
---

# Konfiguracja Maca

Plik wspólny dla wszystkich projektów w `/Users/Shared/sh`. Czyta go shctl (`task ready`, `task dispatch`,
`review run`). Kopię zakłada `scripts/server/install.sh`, gdy jej brak; zmiany robi właściciel tutaj,
nie w repo.

| Pole | Znaczenie |
|---|---|
| `max_local` | Limit lokalnych workerów na tym Macu, wspólny dla wszystkich projektów (domyślnie 2, pomiar sh-dryrun 2026-11-04). Projekt może go tylko obniżyć polem `max_local` w `docs/konfiguracja.md` |
| `review.zwykle` | Reviewer PR bez ryzyka: `silnik` (`claude` albo `codex`), `model`, `effort`. Domyślnie Claude `opus`, `medium` |
| `review.ryzyko` | Reviewer PR z ryzykiem (kategoria `baza`, `bezpieczenstwo`, `backend` z autoryzacją; pliki auth, migracji, sekretów, CI, uprawnień; diff powyżej `prog_linii`). Domyślnie Codex `gpt-6-astra`, `high` |
| `review.gdy_limit` | Limit silnika review: `czekaj` (PR zostaje w `status:review`) albo `drugi_silnik` (review robi drugi silnik). Push z godziną odnowienia w obu przypadkach |
| `review.prog_linii` | Diff PR powyżej tylu linii (dodane + usunięte) to ryzyko. Domyślnie 400 |

Projekt może nadpisać każde pole `review` w swoim `docs/konfiguracja.md`. Modele: Claude `opus`,
`sonnet`, `haiku`, `fable` albo pełny identyfikator; effort `low`, `medium`, `high`, `xhigh`, `max`.
Codex: identyfikator z `~/.codex/models_cache.json` (np. `gpt-6-astra`, `gpt-6.1-terra`); effort
dodatkowo `ultra`. Szczegóły: `sh-system/docs/shctl.md`, „review”.
