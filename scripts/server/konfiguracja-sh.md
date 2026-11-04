---
max_local: 2
---

# Konfiguracja Maca

Plik wspólny dla wszystkich projektów w `/Users/Shared/sh`. Czyta go shctl (`task ready`, `task dispatch`).
Kopię zakłada `scripts/server/install.sh`, gdy jej brak; zmiany robi właściciel tutaj, nie w repo.

| Pole | Znaczenie |
|---|---|
| `max_local` | Limit lokalnych workerów na tym Macu, wspólny dla wszystkich projektów (domyślnie 2, pomiar sh-dryrun 2026-11-04). Projekt może go tylko obniżyć polem `max_local` w `docs/konfiguracja.md` |
