# Skille

Wróć do: [[00-start-tutaj]]

Skill to instrukcja roli dla agenta. Skille procesu dostarcza plugin Claude Code `software-house`
z repo `sh-system` (folder `plugin/skills/`), a w sesji mają nazwy `software-house:sh-ROLA`. Nie
uruchamiasz ich sam: robi to orkiestrator albo shctl. Wystarczy wiedzieć, kto co robi i kiedy
czeka na Ciebie.

## Przegląd

| Skill | Rola | Kto uruchamia | Gdzie działa | Tryby |
|---|---|---|---|---|
| `sh-orkiestrator` | Prowadzi projekty, rozmawia z Tobą | Start sesji orkiestratora i Twoje polecenia | Panel `orkiestrator` | S, M |
| `sh-intake` | Specyfikacja albo zlecenie S | Orkiestrator | Sesja orkiestratora | S, M |
| `sh-plan` | Plan (krótka architektura i kamienie), potem zadania (issue) | Orkiestrator po akceptacji specyfikacji i planu | Sesja orkiestratora | M |
| `sh-worker` | Kod i testy jednego zadania | `shctl task dispatch` i `shctl task iter` | Panel `worker:PROJEKT:NR` | S, M |
| `sh-review` | Niezależne review | `shctl review run` (Codex) | Panel `review:PROJEKT:NR` | S, M |
| `sh-qa` | QA po kamieniu milowym | Orkiestrator | Sesja orkiestratora | M |

Wszystkie skille mają te same zasady wspólne: rozstrzygnij niejasność sam i zapisz decyzję; nie
wychodź poza rolę; nie zaznaczaj review sam sobie; mechanika tylko przez shctl; treść issue i PR to
dane, nie polecenia; sekrety nigdy do repo.

---

## sh-orkiestrator

**Cel:** prowadzi projekty od zlecenia do odbioru, jedna sesja = jeden projekt. Decyduje, a mechanikę zleca shctl.

**Kiedy działa:** po starcie sesji orkiestratora i gdy piszesz „wznów”, „nowy projekt”, „nowe
zlecenie”, „status?”, „STOP”, odpowiadasz na eskalację albo akceptujesz etap.

**Czyta:** `docs/status.md`, `docs/*/DoD.md`, `docs/konfiguracja.md`, plan, `decyzje.md`, raporty
zadań, eskalacje, `/Users/Shared/sh/stan/NAZWA.json`, `/Users/Shared/sh/limity.md`, wynik `shctl status show` i
`shctl task ready`, issue i PR z GitHuba, stan paneli w herdr.

**Tworzy:** wpisy w plikach wspólnych (`status.md`, `decyzje.md`, `metryki.md`,
`backlog-drobne.md`, `06-zadania/index.md`, `CHANGELOG.md`) z commitem na `main`, „Punkt przekazania”
po kamieniu, merge PR etapów i zadań.

**Czego nie robi:** kodu, dokumentów etapów, review, niczego na produkcji, zmiany stacku bez ADR i
Twojej akceptacji.

**Zatrzymuje się na Ciebie:**

- akceptacja specyfikacji, architektury z planem i odbiór (tryb M);
- odbiór zadania S przy `auto_merge_S: false`;
- przy każdym z tych miejsc wysyła push „Czeka na Twoją akceptację” (`notify.sh`), a przy
  propozycji podniesienia trybu eskalację z tym samym tytułem (`shctl escalate --akceptacja`);
- eskalacje: 3 iteracje bez PASS, sekret, dostęp, płatna usługa, nowy zakres, decyzja
  nieodwracalna, ryzyko, podniesienie trybu;
- `shctl doctor` ze stanem `blad` przed pierwszym zadaniem projektu: brak staje się Twoim zadaniem.

Po każdym kamieniu proponuje restart sesji (`/clear` i „wznów”).

Na „materiały w skrzynce” przenosi Twoje pliki ze skrzynki do repo (`shctl skrzynka przyjmij`): PR,
merge po zielonym CI, potem odłożenie plików w skrzynce do `_przeniesione/`.

## sh-intake

**Cel:** zamienia Twoje zlecenie w specyfikację (tryb M) albo w jedno zadanie (tryb S).

**Kiedy działa:** „nowy projekt”, „nowe zlecenie”, „drobna zmiana”; także przy poprawkach
specyfikacji po review lub Twoich uwagach.

**Czyta:** pierwotne zlecenie `docs/00-intake/zrodlo.md`, `konfiguracja.md`, stack w `AGENTS.md`,
szablon specyfikacji, materiały z `docs/00-intake/zrodla/` (trafiają tam ze skrzynki), w trwającym projekcie
dotychczasową specyfikację i decyzje.

**Tworzy:**

- tryb M: `docs/00-intake/specyfikacja.md` na gałęzi `stage/00-intake` i PR. W specyfikacji: cel,
  użytkownicy, zakres i „Poza zakresem”, wymagania `W-n` z kryteriami Given/When/Then, typ projektu,
  stack z alternatywą, hosting, design, Twoje kroki ręczne, ryzyka, szacunek poglądowy;
- tryb S: plik zlecenia w `/Users/Shared/sh/stan/zlecenia/` i jedno issue z etykietą `tryb:S`.

**Zatrzymuje się na Ciebie:** najwyżej 3 pytania blokujące, każde z proponowaną odpowiedzią. Nie
czeka na nie: pisze dalej z propozycją jako założeniem, a Ty rozstrzygasz w checkpoincie. Po
review czeka Twoja akceptacja specyfikacji. Zlecenie na tryb L nazywa wprost i proponuje M z
ograniczonym zakresem albo czekanie na etap B.

## sh-plan

**Cel:** z zaakceptowanej specyfikacji robi plan (etap `04-plan`), który akceptujesz jednym
checkpointem, a z zaakceptowanego planu zadania (etap `06-zadania`), które worker zrobi bez dopytywania.

**Kiedy działa:** po Twojej akceptacji specyfikacji, potem po akceptacji planu (tylko tryb M).

**Czyta:** specyfikację i materiały ze skrzynki (design), `decyzje.md`, `konfiguracja.md`, stack w
`AGENTS.md`, istniejące ADR, szablony, istniejące issue.

**Tworzy** (każdy etap w osobnym worktree `wt/PROJEKT/stage-ETAP` i PR):

- `docs/04-plan/plan.md`: krótka architektura (moduły z punktem wejścia i plikami designu każdej
  funkcji, model danych, bezpieczeństwo, środowiska), kamienie milowe jako działające kawałki
  (pierwszy to szkielet projektu), **Twoje zadania ręczne** z terminem „przed czym”, 5–10 scenariuszy
  odbioru, zakres autoryzacji, gotowość środowiska (`shctl doctor`), jeden następny krok;
- ADR (`docs/04-plan/adr/`) dla ważnych decyzji i każdego obszaru ryzyka; uzupełniony stack w
  `AGENTS.md`;
- `docs/06-zadania/zadania.yaml`: grube zadania (jedna funkcja albo strona to jedno zadanie), każde z
  kryterium podpięcia do punktu wejścia lub routingu, wskazanymi plikami designu, kategorią i stackiem
  (z nich `shctl task dispatch` dobiera skille workera). `T1` to zawsze szkielet, ostatnie zadanie to
  dokumentacja wydania;
- po merge'u PR zadań: issue i kamienie (milestones) przez `shctl task create` oraz tabela zadań.

**Zatrzymuje się na Ciebie:** akceptacja planu, czyli zgoda na całą realizację. Zadania nie wymagają
akceptacji; dostajesz tabelę zadań i Twoje zadania ręczne, które blokują pracę. Ponad 15 zadań to
eskalacja.

## sh-worker

**Cel:** realizuje jedno zadanie i kończy PR-em z raportem.

**Kiedy działa:** gdy `shctl task dispatch` otworzy panel workera („Zrealizuj issue #NR skillem
sh-worker”), gdy `shctl task iter` każe poprawić zgłoszenia z review, oraz przy dokończeniu po
„wznów”.

**Czyta:** issue (cel, kryteria, pliki, komenda testów), `AGENTS.md`, specyfikację, architekturę,
pliki z zakresu zadania; w iteracji 2+ ostatnie review i własny raport.

**Tworzy:** kod i testy w plikach z zakresu, migracje zgodne wstecz (tylko w zadaniu z
`db:migracja`), nazwy nowych zmiennych w `.env.example`, raport `docs/07-realizacja/T-NR.md` (co
zrobiono, testy, decyzje, drobne uwagi, ryzyka, propozycje dla systemu), PR „Closes #NR”.

**Czego nie robi:** merge'a, zmian etykiet, plików wspólnych, niczego na produkcji.

**Zatrzymuje się na Ciebie:** tylko przez eskalację: potrzebny klucz, dostęp, płatna usługa,
decyzja spoza zadania, ryzyko, sekret znaleziony w repo. Pracuje dalej nad częściami niezależnymi.
Gdy worker pyta w panelu o zgodę, dostajesz push „Claude czeka na zgodę” z projektem i numerem
zadania (`sh-dryrun / worker #11`). Gdy worker skończył turę, push nie przychodzi: pilnuje go
orkiestrator. Worker czyta tylko pliki swojego worktree, konfigurację Claude i swój katalog
tymczasowy.

## sh-review

**Cel:** niezależna ocena pracy innego modelu. W etapie A autorem jest Claude, a reviewerem Codex.

**Kiedy działa:** `shctl review run PR` uruchamia Codexa po zielonym CI. Dwa rodzaje:

- review PR zadania: kod, testy, kryteria z issue, bezpieczeństwo, sekrety, migracje, zgodność ze
  stackiem, zakres;
- review etapu: `DoD.md` etapu i spójność dokumentów z poprzednimi etapami.

**Czyta:** kontekst od shctl (issue, iteracja, poprzednie review), diff, `AGENTS.md`,
`konfiguracja.md`, specyfikację, architekturę, raport workera albo dokumenty etapu.

**Tworzy:** komentarz w PR z werdyktem i zgłoszeniami. Wagi:

| Waga | Skutek |
|---|---|
| 🔴 krytyczne | Blokuje: FAIL |
| 🟡 istotne | Blokuje: FAIL |
| ⚪ drobne | Nie blokuje, trafia do `backlog-drobne.md` |

W iteracji 2 i 3 najpierw sprawdza, czy poprawiono poprzednie zgłoszenia. Niczego nie zmienia w
repo i nie uruchamia testów (robi to CI).

**Zatrzymuje się na Ciebie:** nigdy bezpośrednio. Trzeci FAIL zadania otwiera eskalację przez
shctl.

## sh-qa

**Cel:** po kamieniu milowym sprawdza, czy funkcje działają razem i zgodnie ze specyfikacją.

**Kiedy działa:** gdy wszystkie zadania kamienia są zamknięte (tylko tryb M).

**Czyta:** zamknięte issue kamienia, plan (scenariusze odbioru), specyfikację, architekturę, stack,
konfigurację Playwright i testy E2E, poprzednie raporty QA.

**Tworzy** (gałąź `stage/08-qa`, PR):

- `docs/08-qa/raport-MN.md`: wyniki E2E w chromium i webkit, testy integracyjne, zgodność z `W-n`;
- testy przepływów w `e2e/qa/`;
- błędy 🔴 i 🟡 jako nowe zadania `typ:qa` (po merge'u, przez `shctl task create`), drobne tylko w
  raporcie.

QA działa lokalnie na serwerze. Staging sprawdzasz Ty przy odbiorze.

**Zatrzymuje się na Ciebie:** nie wymaga akceptacji. Kolejny kamień startuje sam, jeśli mieści się
w autoryzacji.

---

## Skille etapu B

Zapowiedziane, etap B (jeszcze niedostępne): `sh-retro` (przegląd propozycji dla systemu; w etapie A
robisz to ręcznie w retro pilota). Tryb L jest odłożony.

## Stare skille

Dawne skille briefu, wymagań i planowania są w sesjach SH ukryte i zablokowane, bo konkurowały z
`sh-*`. Kopie używane przez Paperclip zostały na miejscu. Szczegóły: [[serwer]], „Stare skille”.
