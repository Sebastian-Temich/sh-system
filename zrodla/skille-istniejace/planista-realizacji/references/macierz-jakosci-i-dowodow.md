# Macierz jakosci i dowodow

Zapisz wersje dopasowana do projektu jako:

```text
07_Techniczne/Strategia jakosci, release i utrzymania.md
```

Kazdy wiersz oznacz jako wymagany, nie dotyczy albo wymaga decyzji wlasciciela lub Boardu.

| Typ zmiany | Minimalne dowody | Dodatkowa bramka |
| --- | --- | --- |
| Kazda zmiana kodu | CI `quality` (lint, typecheck, test, build) + `security` (gitleaks, semgrep, osv/npm audit) | review QA |
| UI / flow | lint, typecheck, test UI lub E2E, widok mobilny | UX przy istotnym flow lub dostepnosci |
| API / RPC | test kontraktu, walidacja bledow, test integracyjny | review backendu |
| Auth / RLS | testy pozytywne i negatywne dla rol, audit gdy dotyczy | Security |
| Migracja | `supabase db reset` od zera, testy pgTAP, zgodnosc wstecz (job `migracje-zgodne-wstecz`) | Security przy danych/uprawnieniach |
| AI | test scenariusza, kontrola PII w logach, limit kosztu | RODO/AI Act i FinOps |
| Integracja zewnetrzna | test sandbox/staging, obsluga bledow i timeoutow | Security, FinOps gdy platna |
| Deploy / config | CI, smoke test, plan rollbacku | DevOps/SRE i human gate produkcji |

Wynik testu, PR/commit, raport QA i decyzja o wyjatku musza byc podlinkowane
w zadaniu Paperclip i w dokumencie etapu. Wyzwalacze Security Reviewera:
`PROCES.md` sekcja 6; checklisty: skill `secure-delivery`.
