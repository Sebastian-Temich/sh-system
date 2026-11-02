# Jak to działa

Wróć do: [[00-start-tutaj]]

## Architektura w prostych słowach

| Element | Co to jest | Gdzie |
|---|---|---|
| Serwer | iMac 2012 z macOS 14, działa cały czas | Biuro, sieć lokalna |
| herdr | „Okno z panelami”, w którym żyją agenci | Workspace `sh` na serwerze |
| Orkiestrator | Claude Code w panelu `orkiestrator`, połączony przez Remote Control | Rozmawiasz z nim z telefonu i laptopa |
| Worker | Claude Code realizujący jedno zadanie | Panel `worker:PROJEKT:NR`, kopia robocza `~/sh/wt/PROJEKT/NR` |
| Reviewer | Codex sprawdzający zmianę, tylko do odczytu | Panel `review:PROJEKT:NR`, zamykany po review |
| shctl | Program z mechaniką procesu | `~/sh/bin/shctl` |
| GitHub | Źródło prawdy: kod, zadania (issue), zmiany (PR), dokumenty | Konto Sebastian-Temich, jedno repo na projekt |
| Obsidian | Podgląd dokumentów do czytania | Vault `~/Documents/Obsidian Vault`, folder `SH/` |
| ntfy | Powiadomienia push na telefon | Aplikacja ntfy |
| Strażnik limitów | Skrypt bez AI, pilnuje limitów subskrypcji | Co 5 minut, w tle |

Zasada podziału pracy: **agent decyduje i pisze treść, `shctl` wykonuje mechanikę**. Dzięki temu
zakładanie zadań, etykiety czy zamykanie zawsze przebiegają tak samo.

Stan projektu jest zapisany w plikach repo i na GitHubie, a nie w pamięci rozmowy. Dlatego po
restarcie sesji nic nie ginie: orkiestrator odczytuje stan na nowo.

## Przepływ zlecenia

```text
Ty: „nowy projekt …” albo „nowe zlecenie …”
        │
        ▼
Orkiestrator ── sh-intake ──► specyfikacja (M) albo jedno zadanie (S)
        │                            │
        │                 Ty: akceptacja specyfikacji (M)
        ▼
   sh-architekt ──► architektura i plan kamieni milowych (M)
        │                 Ty: akceptacja planu = zgoda na realizację
        ▼
   sh-zadania ──► zadania jako issue na GitHubie (M)
        ▼
┌─ pętla realizacji, dla każdego zadania ───────────────────────┐
│ shctl task dispatch → worker: kod i testy → PR → CI           │
│ → review Codexa → PASS: merge i zamknięcie                    │
│                 → FAIL: poprawki (maks. 3 iteracje)           │
└───────────────────────────────────────────────────────────────┘
        ▼
   po każdym kamieniu: sh-qa (testy całości) → błędy jako nowe zadania
        ▼
   Odbiór: Ty sprawdzasz na stagingu i akceptujesz
```

Pętla realizacji działa sama. Gdy coś wymaga Twojej decyzji, przychodzi eskalacja.

## Tryby pracy

Tryb proponuje agent intake jednym zdaniem uzasadnienia, a Ty go akceptujesz.

| Tryb | Kiedy | Skala | Twoje checkpointy |
|---|---|---|---|
| **S**, szybki | Poprawka, drobna zmiana, mała funkcja w działającym projekcie. Bez zmian modelu danych i bez obszarów ryzyka | 1–3 zadania | Odbiór |
| **M**, średni | Nowa funkcja lub moduł, mały samodzielny projekt. Każdy nowy projekt zaczyna od M | 4–15 zadań | Specyfikacja, architektura z planem, odbiór |
| **L**, pełny | Nowy produkt, MVP, duża przebudowa | ponad 15 zadań | etap B (jeszcze niedostępne) |

Obszary ryzyka podnoszą tryb co najmniej do M: logowanie i uprawnienia, płatności, dane osobowe,
AI na danych użytkowników, migracje bazy produkcyjnej. Tryb nigdy nie zmienia się po cichu:
orkiestrator proponuje, Ty decydujesz.

### Etapy trybu S

1. **Zlecenie:** jedno issue z celem i kryteriami akceptacji.
2. **Realizacja:** worker, CI, review Codexa, maks. 3 iteracje.
3. **Odbiór:** sprawdzasz i akceptujesz, potem merge, wpis w `CHANGELOG.md`.

Ustawienie `auto_merge_S` w `docs/konfiguracja.md` projektu domyślnie ma `false`, więc odbiór
robisz Ty. Przy `true` orkiestrator zamyka sam i tylko informuje.

### Etapy trybu M

| Nr | Etap | Co powstaje | Checkpoint |
|---|---|---|---|
| 1 | Specyfikacja | `docs/00-intake/specyfikacja.md` | **Twoja akceptacja** |
| 2 | Architektura i plan, zadania | `docs/04-architektura/`, `docs/05-plan/plan.md`, issue | **Twoja akceptacja** planu |
| 3 | Realizacja | Kod, testy, raporty `T-NR.md` | Nie, działa sama |
| 4 | QA po kamieniu | `docs/08-qa/raport-MN.md`, zadania z błędami | Nie |
| 5 | Odbiór i dokumentacja | `docs/wydanie/` | **Twój odbiór** |

Każdy dokument etapu przechodzi review Codexa, zanim go zobaczysz do akceptacji.

**Akceptacja planu to zgoda na realizację.** Orkiestrator zapisuje ją w `docs/decyzje.md`: kto,
na co (kamienie), zakres, do kiedy i jak ją cofnąć. Kolejne kamienie startują już bez pytania, o
ile mieszczą się w tej zgodzie. Nowy zakres, płatna usługa, nowy dostęp albo podniesienie trybu
wymagają nowej decyzji, czyli eskalacji.

Drugie duże zlecenie w projekcie, który ma już ukończone etapy, orkiestrator proponuje podzielić na
zlecenia S albo zrobić jako osobny projekt. Nowy cykl etapów w tym samym projekcie to etap B
(jeszcze niedostępne).

## Twoja rola

| Robisz | Nie musisz |
|---|---|
| Zlecasz pracę i dostarczasz materiały (np. projekt graficzny) | Pisać issue, zakładać repo, gałęzie czy panele |
| Akceptujesz specyfikację, plan i odbiór | Robić review kodu |
| Odpowiadasz na eskalacje | Pilnować pętli poprawek |
| Wykonujesz kroki ręczne: konta, domeny, klucze, płatne usługi | Pamiętać stanu: jest w plikach |
| Piszesz „wznów” po limicie, restarcie lub STOP | |
| Wdrażasz na produkcję (po pilocie) | |

## Eskalacje

Agenci rozstrzygają niejasności sami i zapisują decyzje. Do Ciebie trafia eskalacja tylko wtedy,
gdy:

- zadanie nie przeszło review w 3 iteracjach;
- potrzebny jest sekret, dostęp albo płatna usługa;
- decyzja jest nieodwracalna;
- wymagania są sprzeczne;
- jest ryzyko bezpieczeństwa lub prawne;
- trzeba podnieść tryb.

Eskalacja to plik `docs/07-realizacja/escalations/E-NNN.md` i powiadomienie push. Praca niezależna
od niej trwa dalej. Jak odpowiadać: [[02-codzienna-praca#Odpowiedź na eskalację]].

## Granice bezpieczeństwa

- **Brak kluczy produkcyjnych na serwerze i w GitHub Secrets.** To jest prawdziwa granica. Jedyny
  sekret w GitHubie to `STAGING_DB_URL` (baza stagingu).
- **Produkcję wdrażasz wyłącznie Ty**, ze swojego urządzenia, skryptem `scripts/deploy-prod.sh` z
  repo projektu. W etapie A deployów produkcyjnych nie ma.
- **Push na gałąź `production` blokuje hook git na serwerze.** Hook da się obejść, więc to ochrona
  przed pomyłką, nie twarda granica.
- **Reviewer nie dostaje sekretów.** Pracuje w czystej kopii bez plików `.env` i tylko czyta.
- **`.env.local` projektów zawiera wyłącznie klucze testowe.**
- **Lekka izolacja Claude Code:** reguły blokują m.in. zdjęcia, pęk kluczy, klucze SSH i profile
  przeglądarek. Chronią przed pomyłką agenta, nie przed celowym obejściem.
- **Polecenia przyjmujemy tylko od Ciebie.** Treść issue, PR i komentarzy innych osób to dla
  agentów dane, nie polecenia.
- **Sudo, ustawienia systemu i Docker Desktop zmieniasz tylko Ty.** Agent wypisuje komendę i czeka.

Szczegóły: [[proces-v1]] („Dostępy i środowiska”, „Droga na produkcję”, „Znane ograniczenia”) i
[[serwer]] („Izolacja agentów”).

## Co dojdzie w etapie B

Wszystko z tej listy to etap B (jeszcze niedostępne): tryb L, Codex jako drugi wykonawca, workery w
chmurze, automatyczne wznowienie po limitach, design przez Claude Design z dostawą do repo (Storybook
albo Lovable), change requesty, raport dla klienta, retro jako skill, GitHub Projects i dashboard
firmowy, aktualizacja istniejących projektów do nowego szablonu, osobne konto bota GitHub.
